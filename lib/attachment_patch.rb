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
    def container_url
	if container.is_a?(Issue)
          container_url = "/issues/"+  container[:id].to_s
        elsif container.is_a?(WikiPage)
          container_url = "/projects/"+container.project.identifier.to_s+"/wiki/"+ container[:title]
        elsif container.is_a?(Document)
          container_url = "/documents/"+ container[:id].to_s
        elsif container.is_a?(Message)
          container_url = "/boards/" + container[:board_id].to_s + "/topics/" + container[:parent_id].to_s + "\#message-" + container[:id].to_s
        end
        container_url
    end
    def container_name
	container_name = ": "
	if container.is_a?(Issue)
          container_name += container[:subject]
        elsif container.is_a?(WikiPage)
          container_name += container[:title].to_s
        elsif container.is_a?(Document)
          container_name += container[:title].to_s
        elsif container.is_a?(Message)
          container_name += container[:subject]
        end
        container_name
    end
    def container_type
	if container.is_a?(Issue)
          container_type = "Issue"
        elsif container.is_a?(WikiPage)
          container_type = "WikiPage"
        elsif container.is_a?(Document)
          container_type = "Document"
        elsif container.is_a?(Message)
          container_type = "Message"
        end
        container_type
    end
  end
end

