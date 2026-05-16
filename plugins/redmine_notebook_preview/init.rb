require 'open3'

Redmine::Plugin.register :redmine_notebook_preview do
  name        'Redmine Notebook Preview'
  author      'Your Name'
  description 'Renders Jupyter notebook (.ipynb) previews inline in issues and wiki pages'
  version     '0.1.0'
  url         'https://github.com/yourname/redmine_notebook_preview'
  author_url  'https://github.com/yourname'

  settings default: {
    'nbconvert_bin' => ENV['NBCONVERT_BIN']      || 'jupyter',
    'cache_dir'     => ENV['NOTEBOOK_CACHE_DIR'] || File.join(Rails.root, 'notebook_cache')
  }, partial: 'settings/notebook_preview_settings'
end

require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'nbconvert_service')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'attachment_hooks')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'hooks')
require File.join(File.dirname(__FILE__), 'lib', 'redmine_notebook_preview', 'macros')

# Patch Attachment model after Rails has loaded it
ActiveSupport.on_load(:active_record) do
  Attachment.include RedmineNotebookPreview::AttachmentHooks
end