RedmineApp::Application.routes.draw do

  # Purge all cached previews (admin only)
  # Must be declared before the dynamic :attachment_id route to avoid
  # "purge_all" being matched as an attachment id.
  # POST /notebook_previews/purge_all
  post 'notebook_previews/purge_all',
    to: 'notebook_previews#purge_all',
    as: 'purge_all_notebook_previews'

  # Regenerate preview for a single attachment
  # POST /notebook_previews/:attachment_id/regenerate
  post 'notebook_previews/:attachment_id/regenerate',
    to: 'notebook_previews#regenerate',
    as: 'regenerate_notebook_preview'

end