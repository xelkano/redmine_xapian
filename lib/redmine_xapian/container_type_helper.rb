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

module RedmineXapian
  # Container Type Helper module
  module ContainerTypeHelper
    class << self
      # Convert container type name to view_permission symbol
      # WikiPage -> :view_wiki_pages
      def to_permission(container_type)
        case container_type
        when 'Version'
          :view_files
        when 'Project'
          :view_project
        else
          :"view_#{container_type.pluralize.underscore}"
        end
      end
    end
  end
end
