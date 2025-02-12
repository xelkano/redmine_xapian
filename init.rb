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

require 'redmine'
require "#{File.dirname(__FILE__)}/lib/redmine_xapian"

Redmine::Plugin.register :redmine_xapian do
  name 'Xapian search plugin'
  author 'Xabier Elkano/Karel Pičman'
  url 'https://www.redmine.org/plugins/xapian_search'
  author_url 'https://github.com/xelkano/redmine_xapian/graphs/contributors'

  description 'With this plugin you will be able to do searches by file name and by strings inside your documents'
  version '4.0.2'
  requires_redmine version_or_higher: '6.0.0'

  settings partial: 'settings/redmine_xapian_settings',
           default: {
             'enable' => '1',
             'index_database' => File.expand_path('file_index', Rails.root),
             'stemming_lang' => 'english',
             'stemming_strategy' => 'STEM_SOME',
             'stem_langs' => ['english'],
             'save_search_scope' => '0',
             'enable_cjk_ngrams' => '0'
           }
end

Redmine::Search.map do |search|
  search.register :attachments
  search.register :repofiles
end
