require File.expand_path('../../test_helper', __FILE__)

class HooksTest < ActiveSupport::TestCase
  Hooks = RedmineNotebookPreview::Hooks
  FakeAttachment = Struct.new(:filename)
  FakeIssue = Struct.new(:description, :attachments)

  def issue(description, *filenames)
    FakeIssue.new(description, filenames.map { |name| FakeAttachment.new(name) })
  end

  def automatic(issue)
    Hooks.automatic_notebooks(issue).map(&:filename)
  end

  test 'automatic_notebooks lists every attached notebook' do
    assert_equal %w[a.ipynb b.ipynb], automatic(issue('text', 'a.ipynb', 'data.csv', 'b.ipynb'))
  end

  test 'automatic_notebooks leaves out notebooks embedded by the macro' do
    description = "Intro\n\n{{notebook_preview(a.ipynb)}}\n\n{{ notebook_preview( c.ipynb ) }}"
    assert_equal %w[b.ipynb], automatic(issue(description, 'a.ipynb', 'b.ipynb', 'c.ipynb'))
  end

  test 'automatic_notebooks keeps notebooks whose macro is escaped' do
    assert_equal %w[a.ipynb], automatic(issue('!{{notebook_preview(a.ipynb)}}', 'a.ipynb'))
  end
end
