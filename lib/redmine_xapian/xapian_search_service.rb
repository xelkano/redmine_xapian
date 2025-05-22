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
  # Xapian search service
  class XapianSearchService
    extend RedmineXapian::XapianSearch

    class << self
      def search(search_data)
        Rails.logger.debug 'XapianSearch::search'
        xapian_search search_data.tokens, search_data.projects, search_data.options[:all_words], search_data.user,
                      search_data.element, search_data.options[:params][:xapian_stem_langs]
      end
    end
  end
end
