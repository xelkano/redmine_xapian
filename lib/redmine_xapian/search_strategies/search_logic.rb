module RedmineXapian
  module SearchStrategies
    module SearchLogic
      def search_in_container(search_data, container_type, search_joins_query)
        scope = search_data.scope \
                  .scoped(search_options(search_data, search_joins_query)) \
                  .scoped(:conditions => tokens_condition(search_data)) \
                  .scoped(:conditions => {:container_type => container_type})

        results_count = scope.count(:all)
        results = scope.find(:all, search_data.limit_options)

        [results, results_count]
      end

      def search_in_projects_container(search_data, container_type, search_joins_query)
        user = User.current
        container_permission = ContainerTypeHelper.to_permission(container_type)
        container_condition = Project.allowed_to_condition(user, container_permission)
        search_conditions = container_condition
        if search_data.project_conditions
          search_conditions += " AND " + search_data.project_conditions
        end

        scope = search_data.scope \
                  .scoped(:conditions => search_conditions) \
                  .scoped(search_options(search_data, search_joins_query)) \
                  .scoped(:conditions => tokens_condition(search_data)) \
                  .scoped(:conditions => {:container_type => container_type})

        results_count = scope.count(:all)
        results = scope.find(:all, search_data.limit_options)

        [results, results_count]
      end

      private
        def search_options(search_data, search_joins_query)
          search_data.find_options.merge(:joins => search_joins_query)
        end

        def tokens_condition(search_data)
          options = search_data.options
          columns = search_data.columns
          tokens = search_data.tokens

          columns = columns[0..0] if options[:titles_only]

          token_clauses = columns.collect {|column| "(LOWER(#{column}) LIKE ?)"}
          sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')
          [sql, * (tokens.collect {|w| "%#{w.downcase}%"} * token_clauses.size).sort]
        end
    end
  end
end
