class NotebookPreviewsController < ApplicationController
  before_action :require_login
  before_action :find_attachment, only: [:regenerate]
  before_action :require_admin,   only: [:purge_all]

  # POST /notebook_previews/:attachment_id/regenerate
  def regenerate
    unless @attachment.visible?(User.current) && can_edit_attachment?(@attachment)
      deny_access
      return
    end

    result = RedmineNotebookPreview::NbconvertService.convert(@attachment)

    respond_to do |format|
      format.html do
        if result == :ok
          flash[:notice] = l(:notice_notebook_preview_regenerated)
        else
          flash[:error] = l(:error_notebook_preview_failed)
        end
        redirect_to_referer_or safe_container_url(@attachment)
      end
      format.js do
        if result == :ok
          @html    = RedmineNotebookPreview::NbconvertService.cached_html(@attachment.id)
          @dynamic = RedmineNotebookPreview::NbconvertService.notebook_dynamic?(@attachment.id)
          render :regenerate_success
        else
          @error = RedmineNotebookPreview::NbconvertService.cached_error(@attachment.id)
          render :regenerate_error
        end
      end
    end
  end

  # POST /notebook_previews/purge_all
  def purge_all
    RedmineNotebookPreview::NbconvertService.purge_all

    respond_to do |format|
      format.html do
        flash[:notice] = l(:notice_notebook_preview_cache_purged)
        redirect_to plugin_settings_path(:redmine_notebook_preview)
      end
      format.js { head :ok }
    end
  end

  private

  def find_attachment
    @attachment = Attachment.find(params[:attachment_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Returns true if the current user has edit rights over the attachment's container.
  # Falls back to checking author ownership for container types without
  # a specific permission.
  def can_edit_attachment?(attachment)
    container = attachment.container
    return true if User.current.admin?

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
      # For Version, Message, etc. — fall back to author check
      attachment.author == User.current
    end
  end

  # Safe fallback URL for redirect after regenerate.
  # url_for(@attachment.container) raises for some container types
  # (WikiPage, Document, Version) — handle each explicitly.
  def safe_container_url(attachment)
    container = attachment.container
    case container
    when Issue
      issue_url(container)
    when WikiPage
      project_wiki_page_url(container.project, container.title)
    when Document
      document_url(container)
    when Project
      project_url(container)
    when Version
      version_url(container)
    else
      home_url
    end
  end

end