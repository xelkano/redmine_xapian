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
        tokens_condition(search_data),
        :container_type => container_type,
      )

      search_options_tmp[:joins] = search_joins_query

      search_options_tmp
    end

    def tokens_condition(search_data)
      options = search_data.find_options
      columns = search_data.columns
      tokens = search_data.tokens

      columns = columns[0..0] if options[:titles_only]
      
      token_clauses = columns.collect {|column| "(LOWER(#{column}) LIKE ?)"}
      sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')
      [sql, * (tokens.collect {|w| "%#{w.downcase}%"} * token_clauses.size).sort]
    end
end
