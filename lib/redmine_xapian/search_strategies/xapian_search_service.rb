module RedmineXapian
  module SearchStrategies
    class XapianSearchService
      extend XapianSearch

      class << self
        def search(search_data)
          xapian_search_data = xapian_search(
            search_data.tokens,
            search_data.limit_options,
            search_data.options[:offset],
            search_data.projects,
            search_data.options[:all_words],
            search_data.options[:user_stem_lang],
            search_data.options[:user_stem_strategy],
	    search_data.element
          )
          xapian_search_data
        end
      end
    end
  end
end
