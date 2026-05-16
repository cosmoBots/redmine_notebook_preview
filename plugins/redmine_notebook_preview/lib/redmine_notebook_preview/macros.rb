Redmine::WikiFormatting::Macros.register do

  desc <<~DESC
    Renders an inline preview of a Jupyter notebook attached to the current page.
    The argument is the filename of the attachment.
    Example:
      {{notebook_preview(analysis.ipynb)}}
  DESC

  macro :notebook_preview do |obj, args|
    filename = args.first.to_s.strip

    raise 'Please provide a notebook filename. Example: {{notebook_preview(analysis.ipynb)}}' if filename.blank?

    # obj is the wiki page, issue, document etc. — must respond to attachments
    unless obj.respond_to?(:attachments)
      raise "{{notebook_preview}} cannot be used in this context."
    end

    attachment = obj.attachments.detect { |a| a.filename == filename }

    unless attachment
      raise "No attachment named '#{filename}' found on this page."
    end

    unless RedmineNotebookPreview::NbconvertService.notebook?(attachment)
      raise "'#{filename}' is not a Jupyter notebook."
    end

    # Lazy conversion: trigger if not yet cached
    if RedmineNotebookPreview::NbconvertService.cache_status(attachment.id) == :none
      RedmineNotebookPreview::NbconvertService.convert(attachment)
    end

    render partial: 'notebook_previews/preview', locals: { attachment: attachment }
  end

end