# encoding: utf-8
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright (C) 2010  Xabier Elkano
# Copyright (C) 2015  Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_dependency 'attachment'

module RedmineXapian  
  module AttachmentPatch    
    include RedmineXapian::SearchStrategies
    
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.extend(InstanceMethods)
      base.class_eval do        
        acts_as_searchable :columns => ["#{Attachment.table_name}.filename", "#{Attachment.table_name}.description"],
          :project_key => 'project_id',
          :date_column => 'created_on'        
        class << self
          alias_method_chain :search_result_ranks_and_ids, :search_result_ranks_and_ids_ext          
        end
     end
    end

    module InstanceMethods
      
      def search_result_ranks_and_ids_with_search_result_ranks_and_ids_ext(tokens, user = User.current, projects = nil, options = {})      
        r = search(tokens, user, projects, options)        
        r.map{ |x| [x[0].to_i, x[1]] }
      end
      
      def event_description
        desc = Redmine::Search.cache_store.fetch("Attachment-#{id}")                  
        if desc
          Redmine::Search.cache_store.delete("Attachment-#{id}")          
        else
          desc = description
        end
        desc.force_encoding('UTF-8') if desc
      end
            
    private
      
      def search(tokens, user, projects = nil, options = {})     
        Rails.logger.debug "Attachment::search"        
        search_data = RedmineXapian::SearchStrategies::SearchData.new(
          self,
          tokens,
          projects,
          options,          
          user,
          name
        )
        search_results = []
        search_results.concat search_for_issues_attachments(user, search_data)
        search_results.concat search_for_message_attachments(user, search_data)
        search_results.concat search_for_wiki_page_attachments(user, search_data)
        search_results.concat search_for_project_files(user, search_data)
        
        if !options[:titles_only]
          Rails.logger.debug "Call xapian search service for #{name}"          
          xapian_results = RedmineXapian::SearchStrategies::XapianSearchService.search(search_data)
          search_results.concat xapian_results unless xapian_results.blank?
          Rails.logger.debug "Call xapian search service for  #{name} completed"          
        end
        
        search_results
      end                                          
      
      def search_for_issues_attachments(user, search_data)
        results = []        
        sql = "#{Attachment.table_name}.container_type = 'Issue' AND #{Project.table_name}.status = ? AND #{Project.allowed_to_condition(user, :view_issues)}"
        sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
        Attachment.joins("JOIN #{Issue.table_name} ON #{Attachment.table_name}.container_id = #{Issue.table_name}.id")
          .joins("JOIN #{Project.table_name} ON #{Issue.table_name}.project_id = #{Project.table_name}.id")
            .where(sql, Project::STATUS_ACTIVE).scoping do             
              where(tokens_condition(search_data)).scoping do                                
                results = where(search_data.limit_options)                  
                  .uniq
                  .pluck(searchable_options[:date_column], :id)                    
              end            
            end
        results
      end

      def search_for_message_attachments(user, search_data)
        results = []        
        sql = "#{Attachment.table_name}.container_type = 'Message' AND #{Project.table_name}.status = ?"
        sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
        Attachment.joins("JOIN #{Message.table_name} ON #{Attachment.table_name}.container_id = #{Message.table_name}.id")
          .joins("JOIN #{Board.table_name} ON #{Board.table_name}.id = #{Message.table_name}.board_id")
            .joins("JOIN #{Project.table_name} ON #{Board.table_name}.project_id = #{Project.table_name}.id")
              .where(sql, Project::STATUS_ACTIVE).scoping do             
                where(tokens_condition(search_data)).scoping do                                
                  results = where(search_data.limit_options)                    
                    .uniq
                    .pluck(searchable_options[:date_column], :id)                    
                end            
              end
        results
      end

      def search_for_wiki_page_attachments(user, search_data)
        results = []        
        sql = "#{Attachment.table_name}.container_type = 'WikiPage' AND #{Project.table_name}.status = ? AND #{Project.allowed_to_condition(user, :view_wiki_pages)}"
        sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
        Attachment.joins("JOIN #{WikiPage.table_name} ON #{Attachment.table_name}.container_id = #{WikiPage.table_name}.id")
          .joins("JOIN #{Wiki.table_name} ON #{Wiki.table_name}.id = #{WikiPage.table_name}.wiki_id")
            .joins("JOIN #{Project.table_name} ON #{Wiki.table_name}.project_id = #{Project.table_name}.id")
              .where(sql, Project::STATUS_ACTIVE).scoping do             
                where(tokens_condition(search_data)).scoping do                                
                  results = where(search_data.limit_options)                    
                    .uniq
                    .pluck(searchable_options[:date_column], :id)                    
                end            
              end
        results
      end

      def search_for_project_files(user, search_data)
        results = []        
        sql = "container_type = 'Project' AND #{Project.table_name}.status = ? AND #{Project.allowed_to_condition(user, :view_files)}"
        sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
        Attachment.joins("JOIN #{Project.table_name} ON #{Project.table_name}.id = container_id")
          .where(sql, Project::STATUS_ACTIVE).scoping do            
              where(tokens_condition(search_data)).scoping do                                
                results = where(search_data.limit_options)                  
                  .uniq
                  .pluck(searchable_options[:date_column], :id)                    
              end
            end                            
        results
      end
            
      def container_url
        if container.is_a? Issue          
          issue_path(:id => container[:id])
        elsif container.is_a? WikiPage          
          wiki_path(:project_id => container.project.identifier, :id => container[:title])        
        elsif container.is_a? Message          
          message_path(:board_id => container[:board_id], :id => container[:id])
        elsif container.is_a? Version          
          attachment_path(:project_id => container[:project_id])        
        end
      end

      def container_name
        container_name = ': '
        if container.is_a? Issue
          container_name += container[:subject].to_s
        elsif container.is_a? WikiPage
          container_name += container[:title].to_s        
        elsif container.is_a? Message
          container_name += container[:subject].to_s
        elsif container.is_a? Version
          container_name += container[:name].to_s        
        end
        container_name
      end           
      
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

Attachment.send(:include, RedmineXapian::AttachmentPatch)