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

# Attachment unit test
class AttachmentTest < ActiveSupport::TestCase

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
