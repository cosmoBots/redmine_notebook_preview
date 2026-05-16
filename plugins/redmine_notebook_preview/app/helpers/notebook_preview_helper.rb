module NotebookPreviewHelper

  # Returns the full preview HTML for an attachment, or nil
  def notebook_preview_html(attachment)
    RedmineNotebookPreview::NbconvertService.cached_html(attachment.id)
  end

  # Returns the error message for an attachment, or nil
  def notebook_preview_error(attachment)
    RedmineNotebookPreview::NbconvertService.cached_error(attachment.id)
  end

  # Returns :ok, :error or :none
  def notebook_preview_status(attachment)
    RedmineNotebookPreview::NbconvertService.cache_status(attachment.id)
  end

  # Returns a unique DOM id for the preview container of an attachment
  def notebook_preview_container_id(attachment)
    "notebook-preview-#{attachment.id}"
  end

  # Returns a unique DOM id for the error container of an attachment
  def notebook_preview_error_container_id(attachment)
    "notebook-preview-error-#{attachment.id}"
  end

  # Returns true if the current user can regenerate the preview
  # Any logged in user with visibility of the attachment can regenerate
  def can_regenerate_notebook_preview?(attachment)
    User.current.logged? && attachment.visible?(User.current)
  end

end