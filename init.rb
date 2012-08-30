# redmine_xapian/init.rb:
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: init.rb,v 1.1 2008/04/23 13:33:50 francis Exp $


begin
    require 'xapian'
    $xapian_bindings_available = true
rescue LoadError
    Rails.logger.info "REDMAIN_XAPIAN ERROR: No Ruby bindings for Xapian installed !!. PLEASE install Xapian search engine interface for Ruby."
    $xapian_bindings_available = false
else
    #Rails.logger.level = Logger::DEBUG
    require 'redmine'
    require File.dirname(__FILE__) + '/lib/attachment_patch'
    require File.dirname(__FILE__) + '/lib/acts_as_searchable'
    require File.dirname(__FILE__) + '/lib/search_controller_patch'
    require File.dirname(__FILE__) + '/lib/search_helper_patch'
    Attachment.send(:include, AttachmentPatch)
    SearchController.send(:include, SearchControllerPatch)	
    ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)

    Redmine::Plugin.register :redmine_xapian do
	name 'Xapian search plugin'
	author 'Xabier Elkano'
  	url 'http://undefinederror.org/redmine-xapian-search-plugin'
  	author_url 'http://undefinederror.org'

	description 'With this plugin you will be able to do searches by file name and by strings inside your documents'
	version '1.4.0'
	requires_redmine :version_or_higher => '2.0.0'

	settings :partial => 'settings/redmine_xapian_settings',
    		:default => {
      		  'enable' => 'true',
     		  'index_database' => '/var/tmp',
		  'stemming_lang' => 'english',
		  'stemming_strategy' => 'STEM_NONE',
		  'stem_on_search' => 'false',
		  'stem_langs' => ["english", "spanish", "german"]
    	}

   end

   Redmine::Search.map do |search|
     search.register :attachments
  end
end
