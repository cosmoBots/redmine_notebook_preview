module RedmineNotebookPreview
  module AttachmentHooks
    extend ActiveSupport::Concern

    included do
      after_commit :purge_notebook_preview, on: :destroy
    end

    private

    def purge_notebook_preview
      return unless RedmineNotebookPreview::NbconvertService.notebook?(self)
      RedmineNotebookPreview::NbconvertService.purge(id)
    end

  end
end