require_dependency 'attachment'

# Patches Redmine's Attachments dynamically. Adds method acts_as_searchable
module RedmineXapian
  module AttachmentPatch
    def self.included(base) # :nodoc:
      base.send(:include, ExtendedMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        #acts_as_searchable :columns => ['title', "#{table_name}.description"], :include => :project
        acts_as_searchable :columns => ["#{table_name}.filename", "#{table_name}.description"],
          :project_key => 'project_id',
          :date_column => "#{table_name}.created_on"
      end
    end

    module ExtendedMethods
      def container_url
        if container.is_a?(Issue)
          container_url = {:controller=>"issues", :id=>container[:id], :action=>"show"}
        elsif container.is_a?(WikiPage)
          container_url = {:controller=>"wiki", :project_id=>container.project.identifier, :id=>container[:title], :action=>"show"}
        elsif container.is_a?(Document)
          container_url = {:controller=>"documents", :id=>container[:id], :action=>"show"}
        elsif container.is_a?(Message)
          container_url = {:controller=>"messages", :board_id=>container[:board_id], :id=>container[:id], :action=>"show"}
        elsif container.is_a?(Version)
          container_url = {:controller=>"files", :project_id=>container[:project_id], :action=>"index"}
        elsif defined?(KbArticle) && container.is_a?(KbArticle)
          container_url = {:controller=>"articles", :id=>container[:id], :project_id=>container[:project_id], :action=>"show"}
        else
          nil
        end
      end

      def container_name
        container_name = ": "

        if container.is_a?(Issue)
          container_name += container[:subject].to_s
        elsif container.is_a?(WikiPage)
          container_name += container[:title].to_s
        elsif container.is_a?(Document)
          container_name += container[:title].to_s
        elsif container.is_a?(Message)
          container_name += container[:subject].to_s
        elsif container.is_a?(Version)
          container_name += container[:name].to_s
        elsif defined?(KbArticle) && container.is_a?(KbArticle)
          container_name += container[:title].to_s
        end

        container_name
      end
    end
  end
end

