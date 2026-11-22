module RedmineNotebookPreview
  class Hooks < Redmine::Hook::ViewListener
    # {{notebook_preview(name)}}, not escaped as !{{...}}
    MACRO_PATTERN = /(?<!!)\{\{\s*notebook_preview\s*\(\s*([^)]+?)\s*\)\s*\}\}/

    # Inject stylesheets and javascript into <head>
    def view_layouts_base_html_head(context = {})
      output  = stylesheet_link_tag('notebook_preview', plugin: 'redmine_notebook_preview')
      output += stylesheet_link_tag('pygments',         plugin: 'redmine_notebook_preview')
      output.html_safe
    end

    # Injected inside the issue detail page, below the description
    def view_issues_show_description_bottom(context = {})
      render_issue_notebooks(context)
    end

    # Injected after each item description of the cosmoSys report, so the
    # notebooks shown on the issue page reach the report and its exports too.
    # Only cosmoSys calls this hook; without it the plugin works as before.
    def view_cosmosys_report_item_after_description(context = {})
      render_issue_notebooks(context, export: context[:server_export] ? true : false)
    end

    # Notebooks attached to the issue that its description does not already
    # embed with the macro, which would show them twice.
    def self.automatic_notebooks(issue)
      embedded = issue.description.to_s.scan(MACRO_PATTERN).flatten
      issue.attachments.select do |attachment|
        RedmineNotebookPreview::NbconvertService.notebook?(attachment) &&
          !embedded.include?(attachment.filename)
      end
    end

    private

    def render_issue_notebooks(context, export: nil)
      issue = context[:issue]
      return if issue.blank?

      notebooks = self.class.automatic_notebooks(issue)
      return if notebooks.blank?

      # Lazy conversion for any uncached notebooks
      notebooks.each do |attachment|
        if RedmineNotebookPreview::NbconvertService.cache_status(attachment.id) == :none
          RedmineNotebookPreview::NbconvertService.convert(attachment)
        end
      end

      # formats: the cosmoSys export request has format=pdf, which would look
      # for a PDF partial; the previews are HTML whatever the request asks.
      context[:controller].view_context.tap { |vc| vc.extend(NotebookPreviewHelper) }.render(
        partial: 'notebook_previews/preview_list',
        formats: [:html],
        locals:  { attachments: notebooks, export: export }
      )
    end
  end
end
