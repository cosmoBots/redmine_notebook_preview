require 'base64'
require 'digest'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'open3'

module RedmineNotebookPreview
  # Replaces LaTeX math in notebook HTML with PNG images.
  #
  # On the web page MathJax draws the formulas, but report exporters (PDF, ODT,
  # DOCX) only see static HTML, so there the formulas would appear as raw
  # "$$ ... $$" text. This turns them into images before the HTML is exported.
  # A formula that cannot be rendered is left as the original text.
  module LatexRenderer
    SCRIPT = File.expand_path('../../bin/latex_to_png.py', __dir__)
    DPI = 220
    CSS_DPI = 96.0
    TIMEOUT = 60 # seconds
    CACHE_VERSION = 'v1'.freeze
    SKIP_ELEMENTS = %w[pre code script style textarea].freeze

    # Display math: $$ ... $$ and \[ ... \]. Inline math: \( ... \) and $ ... $.
    # Spaces next to a single $ are allowed, as Jupyter and MathJax do. The
    # closing $ must not be followed by a digit, so prices ("$5 and $6") stay text.
    MATH_PATTERN = /
      \$\$(?<dollars>.+?)\$\$
      | \\\[(?<bracket>.+?)\\\]
      | \\\((?<paren>.+?)\\\)
      | (?<![\\$])\$(?!\$)(?<single>[^$\n]*[^$\s\\][^$\n]*?)(?<!\\)\$(?!\d)
    /mx

    Formula = Struct.new(:tex, :display, :source) do
      def key
        Digest::SHA256.hexdigest([CACHE_VERSION, display ? 'D' : 'I', DPI, tex].join('|'))
      end
    end

    # Splits text into plain strings and Formula objects.
    def self.split_text(text)
      pieces = []
      position = 0
      text.scan(MATH_PATTERN) do
        match = Regexp.last_match
        pieces << text[position...match.begin(0)] if match.begin(0) > position
        tex = match[:dollars] || match[:bracket] || match[:paren] || match[:single]
        display = !(match[:dollars] || match[:bracket]).nil?
        pieces << Formula.new(tex.strip, display, match[0])
        position = match.end(0)
      end
      pieces << text[position..] if position < text.length
      pieces
    end

    # Returns the HTML with every renderable formula replaced by an <img>.
    def self.render_html(html, python_bin:, cache_dir:)
      return html unless html.to_s.match?(/\$|\\\(|\\\[/)
      return html unless File.executable?(python_bin)

      fragment = Nokogiri::HTML5.fragment(html)
      targets = []
      fragment.xpath('.//text()').each do |node|
        next if node.ancestors.any? { |ancestor| SKIP_ELEMENTS.include?(ancestor.name) }

        pieces = split_text(node.text)
        targets << [node, pieces] if pieces.any? { |piece| piece.is_a?(Formula) }
      end
      return html if targets.empty?

      formulas = targets.flat_map { |_, pieces| pieces.grep(Formula) }.uniq(&:key)
      images = render_formulas(formulas, python_bin, cache_dir)
      return html if images.empty?

      targets.each { |node, pieces| replace_text_node(node, pieces, images) }
      fragment.to_html
    end

    # key => PNG bytes, only for the formulas that could be rendered.
    def self.render_formulas(formulas, python_bin, cache_dir)
      store = File.join(cache_dir, 'latex')
      FileUtils.mkdir_p(store)
      images = {}
      missing = []

      formulas.each do |formula|
        path = File.join(store, "#{formula.key}.png")
        if File.exist?(path)
          images[formula.key] = File.binread(path)
        else
          missing << formula
        end
      end

      render_with_python(missing, python_bin, cache_dir).each do |key, png|
        File.binwrite(File.join(store, "#{key}.png"), png)
        images[key] = png
      end
      images
    end

    def self.render_with_python(formulas, python_bin, cache_dir)
      return {} if formulas.empty?

      payload = JSON.generate(formulas.map { |f| { id: f.key, tex: f.tex, display: f.display } })
      stdout, stderr, status = run_python(python_bin, payload, cache_dir)
      unless status&.success?
        Rails.logger.warn("redmine_notebook_preview: LaTeX rendering failed: #{stderr.to_s[0, 500]}")
        return {}
      end
      Rails.logger.info("redmine_notebook_preview: LaTeX warnings: #{stderr[0, 500]}") if stderr.present?

      JSON.parse(stdout).each_with_object({}) do |(key, encoded), result|
        result[key] = Base64.strict_decode64(encoded) if encoded
      end
    rescue JSON::ParserError, ArgumentError => e
      Rails.logger.warn("redmine_notebook_preview: LaTeX rendering returned invalid data: #{e.message}")
      {}
    end

    def self.run_python(python_bin, payload, cache_dir)
      env = { 'PYTHONIOENCODING' => 'utf-8', 'MPLCONFIGDIR' => File.join(cache_dir, 'matplotlib') }
      Open3.popen3(env, python_bin, SCRIPT, '--dpi', DPI.to_s) do |stdin, out, err, wait_thr|
        begin
          stdin.write(payload)
        ensure
          stdin.close
        end
        out_thread = Thread.new { out.read }
        err_thread = Thread.new { err.read }

        unless wait_thr.join(TIMEOUT)
          Process.kill('KILL', wait_thr.pid)
          return [nil, "timed out after #{TIMEOUT} seconds", nil]
        end
        [out_thread.value, err_thread.value, wait_thr.value]
      end
    end

    def self.replace_text_node(node, pieces, images)
      document = node.document
      replacement = Nokogiri::XML::NodeSet.new(document)
      pieces.each do |piece|
        if piece.is_a?(Formula) && (png = images[piece.key])
          replacement << formula_node(document, piece, png)
        else
          replacement << Nokogiri::XML::Text.new(piece.is_a?(Formula) ? piece.source : piece, document)
        end
      end
      node.replace(replacement)
    end

    def self.formula_node(document, formula, png)
      width, height = png.byteslice(16, 8).unpack('NN')
      image = Nokogiri::XML::Node.new('img', document)
      image['src'] = "data:image/png;base64,#{Base64.strict_encode64(png)}"
      image['alt'] = formula.tex
      image['width'] = (width * CSS_DPI / DPI).round.to_s
      image['height'] = (height * CSS_DPI / DPI).round.to_s
      image['style'] = 'vertical-align: middle'
      return image unless formula.display

      block = Nokogiri::XML::Node.new('div', document)
      block['class'] = 'notebook-preview-math'
      block['style'] = 'text-align: center'
      block << image
      block
    end
  end
end
