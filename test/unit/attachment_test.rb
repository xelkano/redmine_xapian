require File.dirname(__FILE__) + '/../test_helper'

class AttachmentTest < ActiveSupport::TestCase
  fixtures :users, :projects, :issues, :issue_statuses, :documents, :attachments, :roles

  def setup
    Mailer.stubs(:deliver_mail)

    @some_user = User.generate!(:admin => false)
    @admin = User.find(:first, :conditions => ["admin = ?", true])

    User.stubs(:current).returns(@admin)

    @projects_to_search = [
      Project.generate!(:identifier => "pr1", :is_public => false),
      Project.generate!(:identifier => "pr2", :is_public => false),
      Project.generate!(:identifier => "pr3", :is_public => false),
      Project.generate!(:identifier => "pr4", :is_public => true)
    ]

    view_role = Role.generate!(:permissions => [
      :view_documents,
      :view_issues,
      :view_messages,
      :view_wiki_pages,
      :view_files,
    ], :name => "view_role")

    empty_role = Role.generate!(:permissions => [], :name => "empty_role")

    User.add_to_project(@some_user, @projects_to_search[0], [view_role])
    User.add_to_project(@some_user, @projects_to_search[1], [empty_role])

    @tokens = "some_test_tokens"

    some_priority = IssuePriority.create(:name => "some_priority")
    some_document_category = DocumentCategory.create(:name => "some_category")

    @projects_to_search.each do |project|
      project.enable_module!(:documents)
      project.enable_module!(:issue_tracking)
      project.enable_module!(:boards)
      project.enable_module!(:wiki)
      project.enable_module!(:files)
      project.save!
      project.reload

      project.trackers << Tracker.generate!

      # Document
      project.documents << Document.new(:title => "some_document")

      # Issue
      Issue.generate!(:project => project, :priority => some_priority)

      # Message
      project.boards << Board.new(:name => "board#{project.id}", :description => "board")
      project.boards.first.messages << Message.new(:subject => "subject", :content => "content")
      project.reload

      # WikiPage
      project.create_wiki!(:start_page => "test_page")
      project.wiki.pages << WikiPage.new(:title => "some_wiki_page")
      project.reload

      # Version (Project file)
      some_version = Version.generate!
      project.versions << some_version
      project.save

      # Add fake attachment
      add_attachment(project.documents(true).first, @tokens, @tokens)
      add_attachment(project.issues(true).first, @tokens, @tokens)
      add_attachment(project.boards(true).first.messages.first, @tokens, @tokens)
      add_attachment(project.wiki(true).pages.first, @tokens, @tokens)
      add_attachment(project.versions(true).first, @tokens, @tokens)
    end
  end

  def add_attachment(container, filename, description = "")
    container.attachments << Attachment.new(
      :filename => filename,
      :description => description,
      :container_id => container.id,
      :author_id => @admin.id
    )
  end

  def search_results_for(tokens_query, projects_to_search, container_type)
    tokens = tokens_query.split

    RedmineXapian::SearchStrategies::XapianSearchService \
      .stubs(:search) \
      .returns([[], 0])

    results = Attachment.search(
      tokens,
      projects_to_search,
      :all_words => true,
      :titles_only => false,
      :limit => 99999999,
      :offset => nil,
      :before => false,
      :user_stem_lang => "",
      :user_stem_strategy => ""
    )[0]

    results.select {|r| r.container_type == container_type}
  end

  context "some_user" do
    def as_user
      User.stubs(:current).returns(@some_user)
    end

    def test_should_find_visible_documents_attachments
      as_user
      results = search_results_for(@tokens, @projects_to_search, "Document")
      assert_equal 2, results.size
    end

    def test_should_find_visible_issues_attachments
      as_user
      results = search_results_for(@tokens, @projects_to_search, "Issue")
      assert_equal 2, results.size
    end

    def test_should_find_visible_message_attachments
      as_user
      results = search_results_for(@tokens, @projects_to_search, "Message")
      assert_equal 3, results.size
    end

    def test_should_find_visible_wiki_page_attachments
      as_user
      results = search_results_for(@tokens, @projects_to_search, "WikiPage")
      assert_equal 2, results.size
    end

    def test_should_find_visible_project_files
      as_user
      results = search_results_for(@tokens, @projects_to_search, "Version")
      assert_equal 2, results.size
    end
  end

  context "admin" do
    def as_admin
      User.stubs(:current).returns(@admin)
    end

    def test_should_find_all_documents_attachments
      as_admin
      results = search_results_for(@tokens, @projects_to_search, "Document")
      assert_equal 4, results.size
    end

    def test_should_find_all_issues_attachments
      as_admin
      results = search_results_for(@tokens, @projects_to_search, "Issue")
      assert_equal 4, results.size
    end

    def test_should_find_all_message_attachments
      as_admin
      results = search_results_for(@tokens, @projects_to_search, "Message")
      assert_equal 4, results.size
    end

    def test_should_find_all_wiki_page_attachments
      as_admin
      results = search_results_for(@tokens, @projects_to_search, "WikiPage")
      assert_equal 4, results.size
    end

    def test_should_find_all_project_files
      as_admin
      results = search_results_for(@tokens, @projects_to_search, "Version")
      assert_equal 4, results.size
    end
  end
end
