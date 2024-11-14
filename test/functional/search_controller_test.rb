# frozen_string_literal: true

# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Xabier Elkano, Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Load the normal Rails helper
require File.expand_path('../../../../test/test_helper', __dir__)

# Search controller tests
class SearchControllerTest < ActionDispatch::IntegrationTest
  fixtures :attachments, :changesets, :documents, :issues, :messages, :news, :wiki_pages, :projects, :users,
           :email_addresses

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
end
