require 'xapian_search'

class SearchStrategies::XapianAttachmentsSearchService
  class << self
    def search(search_data)
      xapian_search_data = XapianSearch.search_attachments(
        search_data.tokens,
        search_data.limit_options, 
        search_data.options[:offset],
        search_data.projects,
        search_data.options[:all_words],
        search_data.options[:user_stem_lang],
        search_data.options[:user_stem_strategy]
      )

      xapian_search_data
    end
  end
end
