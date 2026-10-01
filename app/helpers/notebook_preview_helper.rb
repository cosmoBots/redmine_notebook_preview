module NotebookPreviewHelper

  # Returns the full preview HTML for an attachment, or nil
  # When the page is being exported (report PDF/ODT/DOCX) the HTML is adapted
  # to a static document, e.g. LaTeX formulas become images because exporters
  # cannot run MathJax.
  def notebook_preview_html(attachment)
    html = RedmineNotebookPreview::NbconvertService.cached_html(attachment.id)
    html = RedmineNotebookPreview::NbconvertService.prepare_for_export(html) if html && notebook_preview_export_request?
    html
  end

  # True when the request asks for a static document format instead of a web page
  def notebook_preview_export_request?
    %w[pdf odt docx].include?(params[:format].to_s)
  end

  # Returns the error message for an attachment, or nil
  def notebook_preview_error(attachment)
    RedmineNotebookPreview::NbconvertService.cached_error(attachment.id)
  end

  # Returns :ok, :error or :none
  def notebook_preview_status(attachment)
    RedmineNotebookPreview::NbconvertService.cache_status(attachment.id)
  end

  # Returns true if the cached preview is from a dynamic (JavaScript) notebook
  def notebook_preview_dynamic?(attachment)
    RedmineNotebookPreview::NbconvertService.notebook_dynamic?(attachment.id)
  end

  # Returns a unique DOM id for the preview container of an attachment
  def notebook_preview_container_id(attachment)
    "notebook-preview-#{attachment.id}"
  end

  # Returns a unique DOM id for the error container of an attachment
  def notebook_preview_error_container_id(attachment)
    "notebook-preview-error-#{attachment.id}"
  end

  # Returns true if the current user can regenerate the preview.
  # Mirrors the permission check in NotebookPreviewsController#can_edit_attachment?
  def can_regenerate_notebook_preview?(attachment)
    return false unless User.current.logged?
    return false unless attachment.visible?(User.current)
    return true  if User.current.admin?

    container = attachment.container
    case container
    when Issue
      User.current.allowed_to?(:edit_issues, container.project) ||
        (container.author == User.current &&
          User.current.allowed_to?(:edit_own_issues, container.project))
    when WikiPage
      User.current.allowed_to?(:edit_wiki_pages, container.project)
    when Document
      User.current.allowed_to?(:edit_documents, container.project)
    when Project
      User.current.allowed_to?(:edit_project, container)
    else
      attachment.author == User.current
    end
  end

end