require File.dirname(__FILE__) + '/../test_helper'

class SearchControllerTest < ActionController::TestCase
  fixtures :all

  def setup
    @public_project = Project.first(["is_public=?", true])
    @xapian_data = [Attachment.all, Attachment.all.size]
    @search_everything = {
      :attachments => true,
      :changesets => true,
      :documents => true,
      :issues => true,
      :messages => true,
      :news => true,
      :wiki_pages => true,
      :projects => true,

      :q => @public_project.description,
      :all_words => true,
      :titles_only => false
    }
  end

  def test_can_do_projects_search_with_xapian
    XapianSearch.expects(:search_attachments).returns(@xapian_data).once
    get :index, @search_everything
    assert_response :success
  end

  def test_can_do_projects_search_without_xapian
    XapianSearch.expects(:search_attachments).never
    get :index, @search_everything.merge({:titles_only => true})
    assert_response :success
  end

  def test_can_do_project_search_with_xapian
    XapianSearch.expects(:search_attachments).returns(@xapian_data).once
    get :index, @search_everything.merge({:id => @public_project})
    assert_response :success
  end

  def test_can_do_project_search_without_xapian
    XapianSearch.expects(:search_attachments).never
    get :index, @search_everything.merge({:id => @public_project, :titles_only => true})
    assert_response :success
  end

  def test_can_search_with_offset
    XapianSearch.expects(:search_attachments).returns(@xapian_data).once
    get :index, @search_everything.merge({:id => @public_project, :offset => Date.new})
    assert_response :success
  end
end
