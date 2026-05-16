module RedmineNotebookPreview
  module NbconvertService

    CONVERSION_TIMEOUT = 60 # seconds

    # Converts a .ipynb file to an HTML fragment and stores it in the cache.
    # Returns:
    #   :ok     if conversion succeeded
    #   :error  if conversion failed (error message written to .error file)
    def self.convert(attachment)
      return unless notebook?(attachment)

      ipynb_path   = attachment.diskfile
      cache_path   = html_cache_path(attachment.id)
      error_path   = error_cache_path(attachment.id)
      dynamic_path = dynamic_marker_path(attachment.id)

      # Clean up any previous cache entries for this attachment
      FileUtils.rm_f([cache_path, error_path, dynamic_path])

      # Ensure cache directory exists
      FileUtils.mkdir_p(cache_dir)

      nbconvert_bin = setting('nbconvert_bin')

      unless File.executable?(nbconvert_bin)
        write_error(error_path, "nbconvert binary not found or not executable: #{nbconvert_bin}\n" \
                                "Check plugin settings or NBCONVERT_BIN environment variable.")
        return :error
      end

      stdout, stderr, timed_out = run_nbconvert(nbconvert_bin, ipynb_path)

      if timed_out
        write_error(error_path, "nbconvert timed out after #{CONVERSION_TIMEOUT} seconds.")
        return :error
      end

      if stdout.present?
        if notebook_has_javascript?(ipynb_path)
          # Dynamic notebook: cache raw HTML and write marker file
          File.write(cache_path, stdout, encoding: 'utf-8')
          FileUtils.touch(dynamic_path)
        else
          # Static notebook: sanitize before caching
          File.write(cache_path, sanitize_html(stdout), encoding: 'utf-8')
        end
        :ok
      else
        write_error(error_path, stderr.presence || 'Unknown nbconvert error')
        :error
      end

    rescue => e
      write_error(error_path, e.message)
      :error
    end

    # Removes cached files for a given attachment id
    def self.purge(attachment_id)
      FileUtils.rm_f([html_cache_path(attachment_id), error_cache_path(attachment_id), dynamic_marker_path(attachment_id)])
    end

    # Removes all cached files
    def self.purge_all
      FileUtils.rm_f(Dir.glob(File.join(cache_dir, '*.html')))
      FileUtils.rm_f(Dir.glob(File.join(cache_dir, '*.error')))
      FileUtils.rm_f(Dir.glob(File.join(cache_dir, '*.dynamic')))
    end

    # Returns the cached HTML content or nil
    def self.cached_html(attachment_id)
      path = html_cache_path(attachment_id)
      File.read(path) if File.exist?(path)
    end

    # Returns the cached error message or nil
    def self.cached_error(attachment_id)
      path = error_cache_path(attachment_id)
      File.read(path) if File.exist?(path)
    end

    # Returns :ok, :error or :none depending on cache state
    def self.cache_status(attachment_id)
      if File.exist?(html_cache_path(attachment_id))
        :ok
      elsif File.exist?(error_cache_path(attachment_id))
        :error
      else
        :none
      end
    end

    # Returns true if the cached preview is from a dynamic notebook
    def self.notebook_dynamic?(attachment_id)
      File.exist?(dynamic_marker_path(attachment_id))
    end

    def self.notebook?(attachment)
      attachment.filename.to_s.end_with?('.ipynb')
    end

    private

    # Inspects the raw notebook JSON for JavaScript content.
    # Checks:
    #   - cell outputs with mime type application/javascript
    #   - cell outputs with text/html containing <script> tags
    #   - code cells with %%javascript magic or IPython Javascript display calls
    def self.notebook_has_javascript?(ipynb_path)
      notebook = JSON.parse(File.read(ipynb_path, encoding: 'utf-8'))
      cells = notebook['cells'] || []

      cells.any? do |cell|
        source = Array(cell['source']).join

        # %%javascript magic or IPython Javascript() display call
        next true if source.match?(/\A\s*%%javascript/i)
        next true if source.match?(/Javascript\s*\(/i)

        # Walk cell outputs for JS mime types or HTML with scripts
        outputs = cell['outputs'] || []
        outputs.any? do |output|
          data = output['data'] || {}
          next true if data.key?('application/javascript')

          html_output = Array(data['text/html']).join
          html_output.match?(/<script/i)
        end
      end

    rescue JSON::ParserError
      # If the notebook JSON is malformed we can't classify it safely,
      # so treat it as dynamic to avoid rendering unsanitized content
      true
    end

    # Sanitizes nbconvert HTML output, stripping JavaScript while preserving
    # all structural, presentational and styling content.
    def self.sanitize_html(html)
      scrubber = Loofah::Scrubber.new do |node|
        # Remove <script> tags entirely
        if node.name == 'script'
          node.remove
          next
        end

        # Remove on* event attributes and javascript: hrefs from all elements
        node.attribute_nodes.each do |attr|
          if attr.name.start_with?('on')
            attr.remove
          elsif %w[href src action].include?(attr.name) && attr.value.to_s.strip.downcase.start_with?('javascript:')
            attr.remove
          end
        end
      end

      Loofah.fragment(html).scrub!(scrubber).to_s
    end

    def self.cache_dir
      setting('cache_dir')
    end

    def self.html_cache_path(attachment_id)
      File.join(cache_dir, "#{attachment_id}.html")
    end

    def self.error_cache_path(attachment_id)
      File.join(cache_dir, "#{attachment_id}.error")
    end

    def self.dynamic_marker_path(attachment_id)
      File.join(cache_dir, "#{attachment_id}.dynamic")
    end

    def self.setting(key)
      Setting.plugin_redmine_notebook_preview[key]
    end

    def self.write_error(path, message)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, message)
    end

    private

    # Runs nbconvert with a timeout.
    # Returns [stdout, stderr, timed_out]
    def self.run_nbconvert(nbconvert_bin, ipynb_path)
      stdout = ''.dup
      stderr = ''.dup
      timed_out = false

      Open3.popen3(
        { 'PYTHONIOENCODING' => 'utf-8' },
        nbconvert_bin,
        'nbconvert',
        '--to', 'html',
        '--template', 'basic',
        '--stdin',
        '--stdout'
      ) do |stdin, out, err, wait_thr|
        pid = wait_thr.pid

        # Write notebook JSON to stdin and close it
        begin
          stdin.write(File.read(ipynb_path, encoding: 'utf-8'))
        ensure
          stdin.close
        end

        # Read stdout and stderr in background threads to avoid deadlock
        stdout_thread = Thread.new { out.read }
        stderr_thread = Thread.new { err.read }

        # Wait for process with timeout
        unless wait_thr.join(CONVERSION_TIMEOUT)
          timed_out = true
          begin
            Process.kill('TERM', pid)
            sleep 2
            Process.kill('KILL', pid) rescue nil
          rescue Errno::ESRCH
            # Process already gone
          end
        end

        stdout = stdout_thread.value
        stderr = stderr_thread.value
      end

      [stdout, stderr, timed_out]
    end

  end
end