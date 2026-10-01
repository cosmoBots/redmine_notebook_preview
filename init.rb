require 'open3'

Redmine::Plugin.register :redmine_notebook_preview do
  name        'Redmine Notebook Preview'
  author      'Miguel Torres'
  description 'Renders Jupyter notebook (.ipynb) previews inline in issues and wiki pages'
  version     '0.1.0'
  url         'https://github.com/cosmobots/redmine_notebook_preview'
  author_url  'https://github.com/cosmobots'

  settings default: {
    'jupyter_bin' => ENV['JUPYTER_BIN'] || 'jupyter',
    'cache_dir'   => ENV['NOTEBOOK_CACHE_DIR'] || File.join(Rails.root, 'notebook_cache')
  }, partial: 'settings/notebook_preview_settings'
end

require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'latex_renderer')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'nbconvert_service')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'attachment_hooks')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'hooks')
require File.join(File.dirname(__FILE__), 'config', 'macros_registration')

# Patch Attachment model after Rails has loaded it
ActiveSupport.on_load(:active_record) do
  Attachment.include RedmineNotebookPreview::AttachmentHooks
end