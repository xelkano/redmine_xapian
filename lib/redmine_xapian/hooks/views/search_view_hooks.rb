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
  module Hooks
    module Views
      # Base view's hooks
      class SearchViewHooks < Redmine::Hook::ViewListener
        def view_search_index_options_content_bottom(context = {})
          # If there is just one language configured, there is no need to offer it to the user for selection.
          return if RedmineXapian.stem_langs.size < 2

          context[:controller].send :render_to_string,
                                    { partial: 'hooks/view_search_index_options_content_bottom', locals: context }
        end
      end
    end
  end
end
