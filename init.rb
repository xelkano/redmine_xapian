# redmine_xapian/init.rb:
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: init.rb,v 1.1 2008/04/23 13:33:50 francis Exp $

require 'redmine'
require File.dirname(__FILE__) + '/lib/attachment_patch'
Attachment.send(:include, AttachmentPatch)
require File.dirname(__FILE__) + '/lib/acts_as_searchable'
ActiveRecord::Base.send(:include, Redmine::Acts::Searchable)

Redmine::Plugin.register :redmine_xapian do
	name 'Xapian search plugin'
	author 'Xabier Elkano'
	description 'This plugin allows searches over attachments'
	version '1.0.0'

	settings :partial => 'settings/redmine_xapian_settings',
    		:default => {
      		'enable' => 'true',
     		'index_database' => '/var/tmp/',
		'stemming_lang' => 'english'
    	}

#	 permission :view_attachments, :public => true
end

Redmine::Search.map do |search|
     search.register :attachments
end


