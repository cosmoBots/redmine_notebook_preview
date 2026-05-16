class NotebookPreviewsController < ApplicationController
  before_action :require_login
  before_action :find_attachment, only: [:regenerate]
  before_action :require_admin,   only: [:purge_all]

  # POST /notebook_previews/:attachment_id/regenerate
  def regenerate
    unless @attachment.visible?(User.current)
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
        redirect_to_referer_or url_for(@attachment.container)
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

end