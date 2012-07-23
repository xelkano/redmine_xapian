module SearchStrategies::SearchLogic
  def search_in_container(search_data, container_type, search_joins_query)
    find_options = search_options(search_data, container_type, search_joins_query)

    scope = search_data.scope.scoped(find_options)
    
    results_count = scope.count(:all)
    results = scope.find(:all, search_data.limit_options)

    [results, results_count]
  end

  def search_in_projects_container(search_data, container_type, search_joins_query)
    find_options = search_options(search_data, container_type, search_joins_query)

    conditions = {:conditions => search_data.project_conditions}
    scope = search_data.scope.scoped(conditions).scoped(find_options)
    results_count = scope.count(:all)
    results = scope.find(:all, search_data.limit_options)

    [results, results_count]
  end

  private
    def search_options(search_data, container_type, search_joins_query)
      search_options_tmp = search_data.find_options.clone

      search_options_tmp[:conditions] = merge_conditions(
        search_options_tmp[:conditions],
        :container_type => container_type
      )
      search_options_tmp[:joins] = search_joins_query

      search_options_tmp
    end
end
