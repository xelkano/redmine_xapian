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
require File.expand_path(File.dirname(__FILE__) + '/../../lib/redmine_xapian')

class AttachmentTest < ActiveSupport::TestCase
  fixtures :users, :projects, :issues, :issue_statuses, :documents, :attachments, 
    :roles

  def setup    
    @admin = User.active.where(admin: true).first
    @projects_to_search = Project.active.all    
  end

  def test_plugin
    begin
      plugin = Plugin.find('redmine_xapian')
    rescue => e
      assert false, "#{e.message}; pwd = '#{Dir.pwd}'; ls = '#{Dir.entries('.').join('\n')}'"
    end
  end

  
  def test_attachment_search
    Attachment.search_result_ranks_and_ids(
      ['xyz'], 
      @admin, 
      @projects_to_search, 
      { all_words: true,
        titles_only: '',
        offset: nil,
        before: false,
        user_stem_lang: '',
        user_stem_strategy: ''})
    assert true
  end
      
end