module RedmineNotebookPreview
  class Hooks < Redmine::Hook::ViewListener

    # Inject stylesheets and javascript into <head>
    def view_layouts_base_html_head(context = {})
      output  = stylesheet_link_tag('notebook_preview', plugin: 'redmine_notebook_preview')
      output += stylesheet_link_tag('pygments',         plugin: 'redmine_notebook_preview')
      output += javascript_include_tag('notebook_preview', plugin: 'redmine_notebook_preview')
      output.html_safe
    end

    # Injected inside the issue detail page, below the description
    def view_issues_show_description_bottom(context = {})
      issue = context[:issue]
      return if issue.blank?

      notebooks = issue.attachments.select { |a| RedmineNotebookPreview::NbconvertService.notebook?(a) }
      return if notebooks.blank?

      # Lazy conversion for any uncached notebooks
      notebooks.each do |attachment|
        if RedmineNotebookPreview::NbconvertService.cache_status(attachment.id) == :none
          RedmineNotebookPreview::NbconvertService.convert(attachment)
        end
      end

      context[:controller].view_context.tap { |vc| vc.extend(NotebookPreviewHelper) }.render(
        partial: 'notebook_previews/preview_list',
        locals:  { attachments: notebooks }
      )
    end

  end
end