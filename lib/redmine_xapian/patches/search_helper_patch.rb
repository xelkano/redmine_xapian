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

module RedmineXapian
  module Patches
    # Search helper
    module SearchHelperPatch
      ##################################################################################################################
      # New methods
      def link_to_container(attachment)
        case attachment.container_type
        when 'Message'
          link_to "#{l(:label_message)}: #{attachment.container.subject}".truncate(255),
                  board_message_path(attachment.container.board, attachment.container)
        when 'WikiPage'
          link_to "#{l(:label_wiki)}: #{attachment.container.title}".truncate(255),
                  wiki_page_path(attachment.container)
        when 'Issue'
          link_to "#{l(:label_issue)}: #{attachment.container.subject}".truncate(255),
                  issue_path(attachment.container)
        when 'Project'
          link_to l(:label_file_plural), project_files_path(attachment.container)
        end
      end
    end
  end
end

SearchController.helper RedmineXapian::Patches::SearchHelperPatch
