require_dependency 'acts_as_searchable'

module Redmine
  module Acts
    module Searchable
      module InstanceMethods
        module ClassMethods
          include RedmineXapian::SearchStrategies::SearchLogic

          def search_with_attachments(tokens, projects = nil, options = {})
            unless name == "Attachment" || name == "Repofile"
              return search_without_attachments(tokens, projects, options)
            end
            search_data = RedmineXapian::SearchStrategies::SearchData.new(
              self,
              tokens,
              projects,
              options,
	      name
            )

            search_results = []
	    values = []
	    values_count = 0

            if Redmine::Search.available_search_types.include?("articles")
              search_results += [ search_for_articles_attachments(search_data) ]
            end
	
	    unless name == "Repofile"
	    # Does not have table
              search_results += [
                search_for_documents_attachments(search_data),
                search_for_issues_attachments(search_data),
                search_for_message_attachments(search_data),
                search_for_wiki_page_attachments(search_data),
                search_for_project_files(search_data)
              ]
            
	
              values = search_results.map(&:first).flatten
              values_count = search_results.map(&:last).inject(0, :+)
	    end

            if !options[:titles_only]
	      Rails.logger.debug "DEBUG: call xapian search service for #{name.inspect}"
              xapian_values, xapian_values_count = \
                RedmineXapian::SearchStrategies::XapianSearchService \
                  .search(search_data)
	      Rails.logger.debug "DEBUG: call xapian search service for  #{name.inspect} completed"
              values = (xapian_values | values).sort_by { |x| x[:created_on] }
              values_count += xapian_values_count
            end

            [values, values_count]
          end

          alias_method_chain :search, :attachments

          private
            def search_for_articles_attachments(search_data)
              query = <<-sql
			    INNER JOIN kb_articles 
				  ON kb_articles.id = container_id 
			    INNER JOIN #{Project.table_name} 
				  ON #{KbArticle.table_name}.project_id=#{Project.table_name}.id
			  sql
              search_in_container(search_data, "KbArticle", query)
            end

            def search_for_documents_attachments(search_data)
              query = <<-sql
                INNER JOIN #{Document.table_name}
                  ON #{Document.table_name}.id=container_id
                INNER JOIN #{Project.table_name}
                  ON #{Document.table_name}.project_id=#{Project.table_name}.id
              sql
              search_in_projects_container(search_data, "Document", query)
            end

            def search_for_issues_attachments(search_data)
              if visible_condition = Issue.visible_condition(User.current)
                visible_condition_query = " AND " + visible_condition
              else
                visible_condition_query = ""
              end

              query = <<-sql
                INNER JOIN #{Issue.table_name}
                  ON #{Issue.table_name}.id=container_id
                INNER JOIN #{Project.table_name}
                  ON #{Issue.table_name}.project_id = #{Project.table_name}.id
                  #{visible_condition_query}
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

            def search_for_project_files(search_data)
              query = <<-sql
                INNER JOIN #{Version.table_name}
                  ON #{Version.table_name}.id=container_id
                INNER JOIN #{Project.table_name}
                  ON #{Version.table_name}.project_id=#{Project.table_name}.id
              sql
              search_in_projects_container(search_data, "Version", query)
            end
        end
      end
    end
  end
end
