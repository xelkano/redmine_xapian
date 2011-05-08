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
    require File.dirname(__FILE__) + '/lib/attachment_patch'
    require File.dirname(__FILE__) + '/lib/acts_as_searchable'
    Attachment.send(:include, AttachmentPatch)
    ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)

    Redmine::Plugin.register :redmine_xapian do
	name 'Xapian search plugin'
	author 'Xabier Elkano'
	description 'This plugin allows searches over attachments'
	version '1.1.3'
	requires_redmine :version_or_higher => '1.0.0'

	settings :partial => 'settings/redmine_xapian_settings',
    		:default => {
      		  'enable' => 'true',
     		  'index_database' => '/var/tmp/',
		  'stemming_lang' => 'english',
		  'stemming_strategy' => 'STEM_NONE'
    	}

	 permission :view_attachments, :public => true
   end

   Redmine::Search.map do |search|
     search.register :attachments
  end
end
