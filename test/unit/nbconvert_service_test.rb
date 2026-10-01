require File.expand_path('../../test_helper', __FILE__)

class NbconvertServiceTest < ActiveSupport::TestCase
  include RedmineNotebookPreview

  def setup
    @tmp_dir = Dir.mktmpdir('notebook_preview_test')
    Setting.plugin_redmine_notebook_preview = {
      'jupyter_bin' => '/usr/bin/false', # safe default – won't actually run
      'cache_dir'   => @tmp_dir
    }
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  # ---------------------------------------------------------------------------
  # notebook?
  # ---------------------------------------------------------------------------
  test 'notebook? returns true for .ipynb attachments' do
    attachment = stub_attachment('analysis.ipynb')
    assert NbconvertService.notebook?(attachment)
  end

  test 'notebook? returns false for non-notebook attachments' do
    attachment = stub_attachment('report.pdf')
    assert_not NbconvertService.notebook?(attachment)
  end

  # ---------------------------------------------------------------------------
  # cache_status
  # ---------------------------------------------------------------------------
  test 'cache_status returns :none when no cache files exist' do
    assert_equal :none, NbconvertService.cache_status(99999)
  end

  test 'cache_status returns :ok when html file exists' do
    File.write(File.join(@tmp_dir, '1.html'), '<p>hello</p>')
    assert_equal :ok, NbconvertService.cache_status(1)
  end

  test 'cache_status returns :error when error file exists' do
    File.write(File.join(@tmp_dir, '2.error'), 'something went wrong')
    assert_equal :error, NbconvertService.cache_status(2)
  end

  # ---------------------------------------------------------------------------
  # cached_html / cached_error
  # ---------------------------------------------------------------------------
  test 'cached_html returns content when file exists' do
    File.write(File.join(@tmp_dir, '3.html'), '<p>notebook</p>')
    assert_equal '<p>notebook</p>', NbconvertService.cached_html(3)
  end

  test 'cached_html returns nil when file does not exist' do
    assert_nil NbconvertService.cached_html(99999)
  end

  test 'cached_error returns content when file exists' do
    File.write(File.join(@tmp_dir, '4.error'), 'conversion failed')
    assert_equal 'conversion failed', NbconvertService.cached_error(4)
  end

  # ---------------------------------------------------------------------------
  # notebook_dynamic?
  # ---------------------------------------------------------------------------
  test 'notebook_dynamic? returns false when no marker exists' do
    assert_not NbconvertService.notebook_dynamic?(99999)
  end

  test 'notebook_dynamic? returns true when marker file exists' do
    FileUtils.touch(File.join(@tmp_dir, '5.dynamic'))
    assert NbconvertService.notebook_dynamic?(5)
  end

  # ---------------------------------------------------------------------------
  # purge
  # ---------------------------------------------------------------------------
  test 'purge removes all cache files for an attachment' do
    ['.html', '.error', '.dynamic'].each do |ext|
      FileUtils.touch(File.join(@tmp_dir, "6#{ext}"))
    end
    NbconvertService.purge(6)
    assert_equal :none, NbconvertService.cache_status(6)
    assert_not NbconvertService.notebook_dynamic?(6)
  end

  # ---------------------------------------------------------------------------
  # purge_all
  # ---------------------------------------------------------------------------
  test 'purge_all removes all cache files' do
    ['7.html', '8.html', '7.error', '8.dynamic'].each do |f|
      FileUtils.touch(File.join(@tmp_dir, f))
    end
    NbconvertService.purge_all
    assert_empty Dir.glob(File.join(@tmp_dir, '*'))
  end

  # ---------------------------------------------------------------------------
  # convert – error paths (no real jupyter needed)
  # ---------------------------------------------------------------------------
  test 'convert returns :error when jupyter binary is not executable' do
    Setting.plugin_redmine_notebook_preview = {
      'jupyter_bin' => '/nonexistent/jupyter',
      'cache_dir'   => @tmp_dir
    }
    attachment = stub_attachment_with_file('test.ipynb', static_notebook_json)
    result = NbconvertService.convert(attachment)
    assert_equal :error, result
    assert_equal :error, NbconvertService.cache_status(attachment.id)
  end

  test 'convert returns :error when notebook file exceeds size limit' do
    attachment = stub_attachment_with_file('big.ipynb', static_notebook_json)
    File.stubs(:size).returns(NbconvertService::MAX_NOTEBOOK_SIZE + 1)
    result = NbconvertService.convert(attachment)
    assert_equal :error, result
  end

  # ---------------------------------------------------------------------------
  # notebook_has_javascript? (private, tested via convert behaviour)
  # We test it indirectly by checking the dynamic marker.
  # ---------------------------------------------------------------------------
  test 'dynamic notebook json is detected correctly' do
    # Call private method directly for unit clarity
    ipynb = Tempfile.new(['dynamic', '.ipynb'])
    ipynb.write(dynamic_notebook_json)
    ipynb.close
    result = NbconvertService.send(:notebook_has_javascript?, ipynb.path)
    assert result
  ensure
    ipynb&.unlink
  end

  test 'static notebook json is not flagged as dynamic' do
    ipynb = Tempfile.new(['static', '.ipynb'])
    ipynb.write(static_notebook_json)
    ipynb.close
    result = NbconvertService.send(:notebook_has_javascript?, ipynb.path)
    assert_not result
  ensure
    ipynb&.unlink
  end

  test 'malformed notebook json is treated as dynamic' do
    ipynb = Tempfile.new(['broken', '.ipynb'])
    ipynb.write('not valid json {{{')
    ipynb.close
    result = NbconvertService.send(:notebook_has_javascript?, ipynb.path)
    assert result
  ensure
    ipynb&.unlink
  end

  # ---------------------------------------------------------------------------
  # sanitize_html
  # ---------------------------------------------------------------------------
  test 'sanitize_html removes script tags' do
    html = '<p>hello</p><script>alert(1)</script>'
    result = NbconvertService.send(:sanitize_html, html)
    assert_not_includes result, '<script>'
    assert_includes result, '<p>hello</p>'
  end

  test 'sanitize_html removes on* event attributes' do
    html = '<p onclick="alert(1)">click me</p>'
    result = NbconvertService.send(:sanitize_html, html)
    assert_not_includes result, 'onclick'
    assert_includes result, 'click me'
  end

  test 'sanitize_html removes javascript: hrefs' do
    html = '<a href="javascript:alert(1)">link</a>'
    result = NbconvertService.send(:sanitize_html, html)
    assert_not_includes result, 'javascript:'
  end

  test 'sanitize_html preserves safe content' do
    html = '<h1>Title</h1><table><tr><td>data</td></tr></table>'
    result = NbconvertService.send(:sanitize_html, html)
    assert_includes result, '<h1>Title</h1>'
    assert_includes result, '<table>'
  end

  # ---------------------------------------------------------------------------
  # normalize_image_data_uris
  # ---------------------------------------------------------------------------
  test 'normalize_image_data_uris removes a trailing newline inside the data URI' do
    html = %(<img src="data:image/png;base64,iVBORw0KGgo=\n">)
    result = NbconvertService.normalize_image_data_uris(html)
    assert_equal %(<img src="data:image/png;base64,iVBORw0KGgo=">), result
  end

  test 'normalize_image_data_uris removes url-encoded newlines' do
    html = '<img src="data:image/png;base64,iVBORw0KGgo=%0A">'
    result = NbconvertService.normalize_image_data_uris(html)
    assert_equal '<img src="data:image/png;base64,iVBORw0KGgo=">', result
  end

  test 'normalize_image_data_uris joins wrapped base64 lines' do
    html = %(<img src="data:image/jpeg;base64,AAAA\nBBBB\r\nCCCC">)
    result = NbconvertService.normalize_image_data_uris(html)
    assert_equal '<img src="data:image/jpeg;base64,AAAABBBBCCCC">', result
  end

  # ---------------------------------------------------------------------------
  # strip_anchor_links
  # ---------------------------------------------------------------------------
  test 'strip_anchor_links removes the pilcrow links after headings' do
    html = '<h2 id="a">Title<a class="anchor-link" href="#a">¶</a></h2><p><a href="/x">keep</a></p>'
    result = NbconvertService.strip_anchor_links(html)
    assert_not_includes result, 'anchor-link'
    assert_includes result, 'Title'
    assert_includes result, '<a href="/x">keep</a>'
  end

  test 'normalize_image_data_uris leaves other attributes and text untouched' do
    html = %(<p class="a b">text\nmore</p><a href="https://example.org/x?y=1">l</a>)
    assert_equal html, NbconvertService.normalize_image_data_uris(html)
  end

  private

  def stub_attachment(filename)
    a = Attachment.new
    a.define_singleton_method(:filename) { filename }
    a
  end

  def stub_attachment_with_file(filename, content)
    ipynb = Tempfile.new([File.basename(filename, '.*'), '.ipynb'])
    ipynb.write(content)
    ipynb.close

    a = Attachment.new
    a.id = rand(10_000..99_999)
    a.define_singleton_method(:filename) { filename }
    a.define_singleton_method(:diskfile) { ipynb.path }
    # store reference on the object so it's cleaned up with it, not via finalizer
    a.instance_variable_set(:@_tmp_file, ipynb)
    a
  end

  def static_notebook_json
    JSON.generate({
      nbformat: 4,
      nbformat_minor: 5,
      metadata: { kernelspec: { name: 'python3' } },
      cells: [
        {
          cell_type: 'code',
          source: ['print("hello")'],
          outputs: [
            { output_type: 'stream', text: ['hello'] }
          ],
          metadata: {}
        },
        {
          cell_type: 'markdown',
          source: ['# Title'],
          metadata: {}
        }
      ]
    })
  end

  def dynamic_notebook_json
    JSON.generate({
      nbformat: 4,
      nbformat_minor: 5,
      metadata: {},
      cells: [
        {
          cell_type: 'code',
          source: ['%%javascript\nalert("hi")'],
          outputs: [],
          metadata: {}
        }
      ]
    })
  end
end