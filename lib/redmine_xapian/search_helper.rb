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
      when "Article"
        link_to(truncate( l(:label_article)+attachment.container_name, :length => 255), attachment.container_url)
      when "Version"
        link_to(truncate( l(:label_file)+attachment.container_name, :length => 255), attachment.container_url)
      end
    end
  end
end
