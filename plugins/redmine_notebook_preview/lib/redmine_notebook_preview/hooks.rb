module RedmineNotebookPreview
  class Hooks < Redmine::Hook::ViewListener

    # Inject Pygments stylesheet into <head> when notebooks are present
    def view_layouts_base_html_head(context = {})
      output  = stylesheet_link_tag('notebook_preview', plugin: 'redmine_notebook_preview')
      output += stylesheet_link_tag('pygments',         plugin: 'redmine_notebook_preview')
      output += javascript_include_tag('notebook_preview', plugin: 'redmine_notebook_preview')
      output.html_safe
    end

    # Injected at the bottom of the attachments list
    # Covers: issues, documents, files, wiki pages — anywhere attachments appear
    def view_attachments_show_bottom(context = {})
      attachments = context[:attachments]
      return if attachments.blank?

      notebooks = attachments.select { |a| RedmineNotebookPreview::NbconvertService.notebook?(a) }
      return if notebooks.blank?

      controller = context[:controller]
      controller.send(:render_to_string, {
        partial: 'notebook_previews/preview_list',
        locals:  { attachments: notebooks }
      })
    end

    # Injected inside the issue detail page, below the description
    def view_issues_show_description_bottom(context = {})
      issue = context[:issue]
      return if issue.blank?

      notebooks = issue.attachments.select { |a| RedmineNotebookPreview::NbconvertService.notebook?(a) }
      return if notebooks.blank?

      controller = context[:controller]
      controller.send(:render_to_string, {
        partial: 'notebook_previews/preview_list',
        locals:  { attachments: notebooks }
      })
    end

  end
end