module RedmineNotebookPreview
  module AttachmentHooks

    def self.included(base)
      base.after_commit :purge_notebook_preview, on: :destroy
    end

    private

    def purge_notebook_preview
      return unless RedmineNotebookPreview::NbconvertService.notebook?(self)
      RedmineNotebookPreview::NbconvertService.purge(id)
    end

  end
end