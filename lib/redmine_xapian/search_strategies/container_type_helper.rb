module RedmineXapian
  module SearchStrategies
    module ContainerTypeHelper
      class << self
        # Convert container type name to view_permission symbol
        # WikiPage -> :view_wiki_pages
        def to_permission(container_type)
          if container_type == "Version"
            :view_files
          else
            ("view_" + container_type.pluralize.underscore).to_sym
          end
        end
      end
    end
  end
end
