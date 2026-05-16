module RedmineNotebookPreview
  module NbconvertService

    # Converts a .ipynb file to an HTML fragment and stores it in the cache.
    # Returns:
    #   :ok     if conversion succeeded
    #   :error  if conversion failed (error message written to .error file)
    def self.convert(attachment)
      return unless notebook?(attachment)

      ipynb_path  = attachment.diskfile
      cache_path  = html_cache_path(attachment.id)
      error_path  = error_cache_path(attachment.id)

      # Clean up any previous cache entries for this attachment
      FileUtils.rm_f([cache_path, error_path])

      # Ensure cache directory exists
      FileUtils.mkdir_p(cache_dir)

      nbconvert_bin = setting('nbconvert_bin')

      unless File.executable?(nbconvert_bin)
        write_error(error_path, "nbconvert binary not found or not executable: #{nbconvert_bin}\n" \
                                "Check plugin settings or NBCONVERT_BIN environment variable.")
        return :error
      end

      # Run nbconvert, capture stdout and stderr
      stdout, stderr, status = Open3.capture3(
        { 'PYTHONIOENCODING' => 'utf-8' },  # force UTF-8
        nbconvert_bin,
        'nbconvert',
        '--to', 'html',
        '--template', 'basic',
        '--stdin',
        '--stdout',
        stdin_data: File.read(ipynb_path, encoding: 'utf-8')
      )

      if status.success? && stdout.present?
        File.write(cache_path, stdout, encoding: 'utf-8')
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
      FileUtils.rm_f([html_cache_path(attachment_id), error_cache_path(attachment_id)])
    end

    # Removes all cached files
    def self.purge_all
      FileUtils.rm_f(Dir.glob(File.join(cache_dir, '*.html')))
      FileUtils.rm_f(Dir.glob(File.join(cache_dir, '*.error')))
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

    def self.notebook?(attachment)
      attachment.filename.to_s.end_with?('.ipynb')
    end

    private

    def self.cache_dir
      setting('cache_dir')
    end

    def self.html_cache_path(attachment_id)
      File.join(cache_dir, "#{attachment_id}.html")
    end

    def self.error_cache_path(attachment_id)
      File.join(cache_dir, "#{attachment_id}.error")
    end

    def self.setting(key)
      Setting.plugin_redmine_notebook_preview[key]
    end

    def self.write_error(path, message)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, message)
    end

  end
end