module RedmineNotebookPreview
  module AttachmentHooks

    def self.included(base)
      base.after_commit :generate_notebook_preview, on: :create
      base.after_commit :purge_notebook_preview,    on: :destroy
    end

    private

    def generate_notebook_preview
      return unless RedmineNotebookPreview::NbconvertService.notebook?(self)
      RedmineNotebookPreview::NbconvertService.convert(self)
    end

    def purge_notebook_preview
      return unless RedmineNotebookPreview::NbconvertService.notebook?(self)
      RedmineNotebookPreview::NbconvertService.purge(self.id)
    end

  end
end