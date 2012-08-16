# redmine_xapian/init.rb:
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: init.rb,v 1.1 2008/04/23 13:33:50 francis Exp $

require 'xapian'

require 'redmine'
require File.dirname(__FILE__) + '/lib/attachment_patch'
require File.dirname(__FILE__) + '/lib/acts_as_searchable_patch'
#require File.dirname(__FILE__) + '/lib/search_controller_patch'
Attachment.send(:include, AttachmentPatch)
#SearchController.send(:include, SearchControllerPatch)
ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)

Redmine::Plugin.register :redmine_xapian do
  name 'Xapian search plugin'
  author 'Xabier Elkano'
  url 'http://undefinederror.org/redmine-xapian-search-plugin'
  author_url 'http://undefinederror.org'

  description 'With this plugin you will be able to do searches by file name and by strings inside your documents'
  version '1.3.0'
  requires_redmine :version_or_higher => '1.4.0'

  default_settings = {
    'enable' => 'true',
    'index_database' => '/var/tmp',
    'stemming_lang' => 'english',
    'stemming_strategy' => 'STEM_NONE',
    'stem_on_search' => 'false',
    'stem_langs' => ["english", "spanish", "german"]
  }
  settings(:partial => 'settings/redmine_xapian_settings',
           :default => default_settings)
end

Redmine::Search.map do |search|
   search.register :attachments
end
