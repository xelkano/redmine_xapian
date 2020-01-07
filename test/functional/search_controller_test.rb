# encoding: utf-8
# frozen_string_literal: true
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright © 2010    Xabier Elkano
# Copyright © 2019-20 Karel Pičman <karel.picman@kontron.com>
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

require File.dirname(__FILE__) + '/../test_helper'

class SearchControllerTest < Redmine::ControllerTest
  tests SearchController
  fixtures :attachments, :changesets, :documents, :issues, :messages, :news, 
    :wiki_pages, :projects, :users

  def setup    
    attachment = Attachment.find_by(id: 1)
    @xapian_data = attachment ? [[attachment.created_on, attachment.id]] : []
  end

  def test_search_with_xapian
    # TODO: Doesn't work in GitHub Actions
    #RedmineXapian::XapianSearchService.expects(:search).returns(@xapian_data).once
    get :index, params: { q: 'xyz', attachments: true, titles_only: '' }
    assert_response :success
  end

  def test_search_without_xapian
    RedmineXapian::XapianSearchService.expects(:search).never
    get :index, params: { q: 'xyz', attachments: true, titles_only: true }
    assert_response :success
  end 

end