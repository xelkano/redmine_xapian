# frozen_string_literal: true

# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Xabier Elkano, Karel Pičman <karel.picman@kontron.com>
#
# This file is part of Redmine Xapian plugin.
#
# Redmine Xapian plugin is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Redmine Xapian plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
# the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with Redmine Xapian plugin. If not, see
# <https://www.gnu.org/licenses/>.

# Load the normal Rails helper
require File.expand_path('../../../../../test/test_helper', __FILE__)

# Search controller tests
class SearchControllerTest < ActionDispatch::IntegrationTest
  def setup
    attachment = Attachment.find_by(id: 1)
    @xapian_data = attachment ? [[attachment.created_on, attachment.id]] : []
    post '/login', params: { username: 'jsmith', password: 'jsmith' }
  end

  def test_search_with_xapian
    RedmineXapian::XapianSearchService.expects(:search).returns(@xapian_data).once
    get '/search', params: { q: 'xyz', attachments: true, titles_only: '' }
    assert_response :success
  end

  def test_search_without_xapian
    RedmineXapian::XapianSearchService.expects(:search).never
    get '/search', params: { q: 'xyz', attachments: true, titles_only: true }
    assert_response :success
  end

  def test_search_index_stem
    with_settings plugin_redmine_xapian: { 'stem_langs' => %w[english german] } do
      get '/search'
      assert_response :success
      assert_select 'select#xapian_stem_langs', id: 'xapian_stem_langs'
    end
  end

  def test_search_index_no_stem
    with_settings plugin_redmine_xapian: { 'stem_langs' => ['english'] } do
      get '/search'
      assert_response :success
      assert_select 'select#xapian_stem_langs', id: 'xapian_stem_langs', count: 0
    end
  end
end
