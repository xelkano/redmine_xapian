module RedmineXapian
  module SearchHelper
    def link_to_container(attachment)
      case attachment.container_type
      when "Document"
        link_to(truncate( l(:label_document)+attachment.container_name, :length => 255), attachment.container_url)
      when "Message"
        link_to(truncate( l(:label_message)+attachment.container_name, :length => 255), attachment.container_url)
      when "WikiPage"
        link_to(truncate( l(:label_wiki)+attachment.container_name, :length => 255), attachment.container_url)
      when "Issue"
        link_to(truncate( l(:label_issue)+attachment.container_name, :length => 255), attachment.container_url)
      when "KbArticle"
        link_to(truncate( l(:label_article)+attachment.container_name, :length => 255), attachment.container_url)
      when "Version"
        link_to(truncate( l(:label_file)+attachment.container_name, :length => 255), attachment.container_url)
      end
    end

    def highlight_tokens2(text, tokens)
      Rails.logger.debug "DEBUG: highlight_tokens2 "
      text= h text
      return text unless text && tokens && !tokens.empty?
      re_tokens = tokens.collect {|t| Regexp.escape(t)}
      regexp = Regexp.new "(#{re_tokens.join('|')})", Regexp::IGNORECASE
      result = ''
      text.split(regexp).each_with_index do |words, i|
        if result.length > 3000
          # maximum length of the preview reached
	        Rails.logger.debug "DEBUG: maximum length reached"
          result << '...'
          break
        end
        words = words.mb_chars
        if i.even?
          result << words
        else
          t = (tokens.index(words.downcase) || 0) % 6
          result << content_tag('span', words, :class => "highlight token-#{t}")
        end
      end
      Rails.logger.debug "DEBUG: returning description: " + result.html_safe.inspect
      result.html_safe
    end
  end
end
