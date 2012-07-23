acts_as_searchable_path = '/../../acts_as_searchable/lib/acts_as_searchable'
require File.dirname(__FILE__) + acts_as_searchable_path

module Redmine
  module Acts
    module Searchable
      module InstanceMethods
        module ClassMethods
          include SearchStrategies::SearchLogic

          def search_with_attachments(tokens, projects = nil, options = {})
            unless name == "Attachment"
              return search_without_attachments(tokens, projects, options)
            end

            search_data = SearchStrategies::SearchData.new(self, tokens, projects, options)

            search_results = []

            if Redmine::Search.available_search_types.include?("articles")
              search_results += [ search_for_articles_attachments(search_data) ]
            end

            search_results += [
              search_for_documents(search_data),
              search_for_issues_attachments(search_data),
              search_for_message_attachments(search_data),
              search_for_wiki_page_attachments(search_data)
            ]

            values = search_results.map(&:first).flatten
            values_count = search_results.map(&:last).inject(0, :+)

            if !options[:titles_only]
              xapian_values, xapian_values_count = SearchStrategies::XapianAttachmentsSearchService.search(search_data)
              values = (values | xapian_values).sort_by { |x| x[:created_on] }
              values_count += xapian_values_count
            end

            [values, values_count]
          end

          alias_method_chain :search, :attachments

          private
            def search_for_articles_attachments(search_data)
              query = "INNER JOIN kb_articles ON kb_articles.id = container_id"
              search_in_container(search_data, "Article", query)
            end

            def search_for_documents(search_data)
              query = <<-sql
                INNER JOIN #{Document.table_name} 
                  ON #{Document.table_name}.id=container_id 
                LEFT JOIN #{Project.table_name}
                  ON #{Document.table_name}.project_id=#{Project.table_name}.id
              sql
              search_in_projects_container(search_data, "Document", query)
            end

            def search_for_issues_attachments(search_data)
              query = <<-sql
                INNER JOIN #{Issue.table_name} 
                  ON #{Issue.table_name}.id=container_id 
                LEFT JOIN #{Project.table_name} 
                  ON #{Issue.table_name}.project_id = #{Project.table_name}.id
              sql
              search_in_projects_container(search_data, "Issue", query)
            end

            def search_for_message_attachments(search_data)
              query = <<-sql
                INNER JOIN #{Message.table_name} 
                  ON #{Message.table_name}.id=container_id  
                INNER JOIN #{Board.table_name}
                  ON #{Board.table_name}.id=#{Message.table_name}.board_id
                INNER JOIN #{Project.table_name} 
                  ON #{Board.table_name}.project_id=#{Project.table_name}.id
              sql
              search_in_projects_container(search_data, "Message", query)
            end

            def search_for_wiki_page_attachments(search_data)
              query = <<-sql
                INNER JOIN #{WikiPage.table_name} 
                  ON #{WikiPage.table_name}.id=container_id  
                INNER JOIN #{Wiki.table_name} 
                  ON #{Wiki.table_name}.id=#{WikiPage.table_name}.wiki_id
                INNER JOIN #{Project.table_name} 
                  ON #{Wiki.table_name}.project_id=#{Project.table_name}.id 
              sql
              search_in_projects_container(search_data, "WikiPage", query)
            end
        end
      end
    end
  end
end
