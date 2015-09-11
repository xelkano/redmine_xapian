# encoding: utf-8
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright (C) 2010  Xabier Elkano
# Copyright (C) 2015  Karel Pičman <karel.picman@kontron.com>
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

begin
  require 'xapian'
  $xapian_bindings_available = true
rescue LoadError
  Rails.logger.info 'REDMAIN_XAPIAN ERROR: No Ruby bindings for Xapian installed !!. PLEASE install Xapian search engine interface for Ruby.'
  $xapian_bindings_available = false
else
  require 'redmine'
  require File.dirname(__FILE__) + '/lib/redmine_xapian/attachment_patch'    
  require File.dirname(__FILE__) + '/lib/redmine_xapian/search_controller_patch'    

  Redmine::Plugin.register :redmine_xapian do
	name 'Xapian search plugin'
	author 'Xabier Elkano/Karel Pičman'
  url 'https://github.com/xelkano/redmine_xapian'
  author_url 'https://github.com/xelkano/redmine_xapian/graphs/contributors'

	description 'With this plugin you will be able to do searches by file name and by strings inside your documents'
	version '1.6.3'
	requires_redmine :version_or_higher => '3.0.0'

	settings :partial => 'redmine_xapian_settings',
    :default => {
      'enable' => 'true',
      'index_database' => '/var/tmp',
      'stemming_lang' => 'english',
      'stemming_strategy' => 'STEM_SOME',
      'stem_on_search' => 'false',
      'stem_langs' => ['english', 'spanish', 'german'] }
   end

   Redmine::Search.map do |search|
     search.register :attachments
     search.register :repofiles
  end
end