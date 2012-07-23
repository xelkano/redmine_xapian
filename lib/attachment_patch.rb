#

require_dependency 'attachment'
require_dependency 'search_controller'

# Patches Redmine's Attachments dynamically. Adds method acts_as_searchable
module AttachmentPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      #acts_as_searchable :columns => ['title', "#{table_name}.description"], :include => :project 
      acts_as_searchable :columns => ["#{table_name}.filename", "#{table_name}.description"],
            :date_column => "#{table_name}.created_on",
            :permission => :view_documents
    end
  end

  module InstanceMethods
    def container_url
      if container.is_a?(Issue)
        container_url = {:controller=>"issues", :id=>container[:id], :action=>"show"}
      elsif container.is_a?(WikiPage)
        container_url = {:controller=>"wiki", :project_id=>container.project.identifier, :id=>container[:title], :action=>"show"}
      elsif container.is_a?(Document)
        container_url = {:controller=>"documents", :id=>container[:id], :action=>"show"}
      elsif container.is_a?(Message)
        container_url = {:controller=>"messages", :board_id=>container[:board_id], :id=>container[:id], :action=>"show"}
      elsif container.is_a?(Article)
        container_url = {:controller=>"articles", :id=>container[:id], :action=>"show"}
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
        elsif container.is_a?(Article)
          container_name += container[:title]
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
      elsif ( defined?(Article) == 'constant' )
        if container.is_a?(Article)
               container_type = "Article"
        end
      end
      container_type
    end
  end
end

