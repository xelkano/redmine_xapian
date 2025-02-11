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
require File.expand_path('../../../../../test/test_helper', __FILE__)

# Attachment unit test
class AttachmentTest < ActiveSupport::TestCase
  fixtures :users, :projects, :issues, :issue_statuses, :documents, :attachments, :roles

  def setup
    @admin = User.active.where(admin: true).first
    @projects_to_search = Project.active.all
  end

  def test_truth
    assert_kind_of User, @admin
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
        user_stem_strategy: '' }
    )
    assert true
  end
end
