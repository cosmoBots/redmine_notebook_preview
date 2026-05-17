require File.expand_path('../../test_helper', __FILE__)

class NotebookPreviewsControllerTest < ActionController::TestCase
  include RedmineNotebookPreview

  fixtures :users, :projects, :roles, :members, :member_roles,
           :issues, :trackers, :issue_statuses, :enumerations

  def setup
    @tmp_dir = Dir.mktmpdir('notebook_preview_ctrl_test')
    Setting.plugin_redmine_notebook_preview = {
      'jupyter_bin' => '/usr/bin/false',
      'cache_dir'   => @tmp_dir
    }
    @request.session[:user_id] = 2 # jsmith — has edit_issues on project 1
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  # ---------------------------------------------------------------------------
  # regenerate
  # ---------------------------------------------------------------------------
  test 'regenerate redirects to login when not logged in' do
    @request.session[:user_id] = nil
    post :regenerate, params: { attachment_id: stub_attachment.id }
    assert_response :redirect
    assert_match /\/login/, response.location
  end

  test 'regenerate returns 404 for unknown attachment' do
    post :regenerate, params: { attachment_id: 99999999 }
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # purge_all
  # ---------------------------------------------------------------------------
  test 'purge_all requires admin' do
    @request.session[:user_id] = 2 # regular user
    post :purge_all
    assert_response :forbidden
  end

  test 'purge_all succeeds for admin and redirects to settings' do
    @request.session[:user_id] = 1 # admin
    File.write(File.join(@tmp_dir, '1.html'), '<p>cached</p>')

    post :purge_all
    assert_redirected_to plugin_settings_path(:redmine_notebook_preview)
    assert_empty Dir.glob(File.join(@tmp_dir, '*.html'))
  end

  test 'purge_all sets flash notice' do
    @request.session[:user_id] = 1
    post :purge_all
    assert_not_nil flash[:notice]
  end

  private

  def stub_attachment
    # Use a real attachment record if fixtures provide one, otherwise skip
    Attachment.first || skip('No attachment fixtures available')
  end
end