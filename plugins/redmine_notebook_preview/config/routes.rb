RedmineApp::Application.routes.draw do

  # Regenerate preview for a single attachment
  # POST /notebook_previews/:attachment_id/regenerate
  post 'notebook_previews/:attachment_id/regenerate',
    to: 'notebook_previews#regenerate',
    as: 'regenerate_notebook_preview'

  # Purge all cached previews (admin only)
  # POST /notebook_previews/purge_all
  post 'notebook_previews/purge_all',
    to: 'notebook_previews#purge_all',
    as: 'purge_all_notebook_previews'

end