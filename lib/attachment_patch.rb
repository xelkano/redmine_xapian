#

require_dependency 'attachment'
require_dependency 'search_controller'

# Patches Redmine's Attachments dynamically. Adds method acts_as_searchable
module AttachmentPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      #acts_as_searchable :columns => ['title', "#{table_name}.description"], :include => :project 
      acts_as_searchable :columns => ["#{table_name}.filename", "#{table_name}.description"],
			#:include => {:board => :project},
                     	:project_key => 'project_id',
			:date_column => "#{table_name}.created_on",
			:permission => :view_documents
    end


  end

  module ClassMethods

  end

  module InstanceMethods

  end
end

