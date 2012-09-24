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
    require 'redmine'
<<<<<<< HEAD
    Dir::foreach(File.join(File.dirname(__FILE__), 'lib')) do |file|
      next unless /\.rb$/ =~ file
      require File.dirname(__FILE__) + '/lib/' + file
    end
    
    ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)
    SearchController.send(:include, SearchControllerPatch)	
    Attachment.send(:include, AttachmentPatch)
    #SearchHelper.send(:include, RedmineXapian::SearchHelperPatch)
    #unless ApplicationHelper.included_modules.include? (RedmineWikiExtensions::ApplicationHelperPatch)	
    #  ApplicationHelper.send(:include, RedmineWikiExtensions::ApplicationHelperPatch)	
    #end

    Rails.configuration.to_prepare do
      unless ActionView::Base.included_modules.include? (XapianHelper)
        ActionView::Base.send(:include, XapianHelper)
      end
    end
=======
    require 'redmine_xapian/acts_as_searchable_patch'
    SearchController.send(:include, RedmineXapian::SearchControllerPatch)
    Attachment.send(:include, RedmineXapian::AttachmentPatch)
>>>>>>> 93e208ddb01d83bf175395f333440564db3de990

    Redmine::Plugin.register :redmine_xapian do
	name 'Xapian search plugin'
	author 'Xabier Elkano'
  	url 'http://undefinederror.org/redmine-xapian-search-plugin'
  	author_url 'http://undefinederror.org'

	description 'With this plugin you will be able to do searches by file name and by strings inside your documents'
	version '1.5.0_prev1'
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
     search.register :repofiles
  end
end
