# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

require 'xapian_search'

module Redmine
  module Acts
    module Searchable
      def self.included(base)
        base.extend ClassMethods
      end 

      module ClassMethods
        # Options:
        # * :columns - a column or an array of columns to search
        # * :project_key - project foreign key (default to project_id)
        # * :date_column - name of the datetime column (default to created_on)
        # * :sort_order - name of the column used to sort results (default to :date_column or created_on)
        # * :permission - permission required to search the model (default to :view_"objects")
        def acts_as_searchable(options = {})
	  Rails.logger.debug "DEBUG: wrapped act_as_searchable"
          return if self.included_modules.include?(Redmine::Acts::Searchable::InstanceMethods)
  
          cattr_accessor :searchable_options
          self.searchable_options = options

          if searchable_options[:columns].nil?
            raise 'No searchable column defined.'
          elsif !searchable_options[:columns].is_a?(Array)
            searchable_options[:columns] = [] << searchable_options[:columns]
          end

          searchable_options[:project_key] ||= "#{table_name}.project_id"
          searchable_options[:date_column] ||= "#{table_name}.created_on"
          searchable_options[:order_column] ||= searchable_options[:date_column]
          
          # Permission needed to search this model
	  logger.debug "DEBUG: searchable options on act: " + searchable_options.inspect if self.name == "Attachment"
          searchable_options[:permission] = "view_#{self.name.underscore.pluralize}".to_sym unless searchable_options.has_key?(:permission)
          # Should we search custom fields on this model ?
          searchable_options[:search_custom_fields] = !reflect_on_association(:custom_values).nil?
          send :include, Redmine::Acts::Searchable::InstanceMethods
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          # Searches the model for the given tokens
          # projects argument can be either nil (will search all projects), a project or an array of projects
          # Returns the results and the results count
          def search(tokens, projects=nil, options={})
	    if projects.is_a?(Array) && projects.empty?
              # no results
              return [[], 0]
            end
	     # TODO: make user an argument
            user = User.current
            tokens = [] << tokens unless tokens.is_a?(Array)
            projects = [] << projects unless projects.nil? || projects.is_a?(Array)
            
            find_options = {:include => searchable_options[:include]}
            find_options[:order] = "#{searchable_options[:order_column]} " + (options[:before] ? 'DESC' : 'ASC')
            
            limit_options = {}
            limit_options[:limit] = options[:limit] if options[:limit]
            if options[:offset]
              limit_options[:conditions] = "(#{searchable_options[:date_column]} " + (options[:before] ? '<' : '>') + "'#{connection.quoted_date(options[:offset])}')"
            end
            
            columns = searchable_options[:columns]
            columns = columns[0..0] if options[:titles_only]
            
            token_clauses = columns.collect {|column| "(LOWER(#{column}) LIKE ?)"}
            
            if !options[:titles_only] && searchable_options[:search_custom_fields]
              searchable_custom_field_ids = CustomField.find(:all,
                                                             :select => 'id',
                                                             :conditions => { :type => "#{self.name}CustomField",
                                                                              :searchable => true }).collect(&:id)
              if searchable_custom_field_ids.any?
                custom_field_sql = "#{table_name}.id IN (SELECT customized_id FROM #{CustomValue.table_name}" +
                  " WHERE customized_type='#{self.name}' AND customized_id=#{table_name}.id AND LOWER(value) LIKE ?" +
                  " AND #{CustomValue.table_name}.custom_field_id IN (#{searchable_custom_field_ids.join(',')}))"
                token_clauses << custom_field_sql
              end
            end
            
            sql = (['(' + token_clauses.join(' OR ') + ')'] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')

            find_options[:conditions] = [sql, * (tokens.collect {|w| "%#{w.downcase}%"} * token_clauses.size).sort]
            
	    scope = self
            project_conditions = []
	    if searchable_options.has_key?(:permission)
              project_conditions << Project.allowed_to_condition(user, searchable_options[:permission] || :view_project)
            elsif respond_to?(:visible)
              scope = scope.visible(user)
            else
              ActiveSupport::Deprecation.warn "acts_as_searchable with implicit :permission option is deprecated. Add a visible scope to the #{self.name} model or use explicit :permission option."
              project_conditions << Project.allowed_to_condition(user, "view_#{self.name.underscore.pluralize}".to_sym)
            end
	     # TODO: use visible scope options instead
            project_conditions << "#{searchable_options[:project_key]} IN (#{projects.collect(&:id).join(',')})" unless projects.nil?
            project_conditions = project_conditions.empty? ? nil : project_conditions.join(' AND ')

            results = []
            results_count = 0
	    unless self.name == "Attachment" then
	      scope = scope.scoped({:conditions => project_conditions}).scoped(find_options)
              results_count = scope.count(:all)
              results = scope.find(:all, limit_options)
	    else
		logger.debug "DEBUG: attachment search" 
		#Attahcment on documents
		find_options_tmp=Hash.new
		find_options_tmp=find_options_tmp.merge(find_options)
		scope2 = scope
		results_doc= []
                results_count_doc=0
		find_options_tmp [:joins] =  "INNER JOIN documents ON documents.id=container_id " +  "LEFT JOIN #{Project.table_name} ON #{Document.table_name}.project_id = #{Project.table_name}.id" 
	 	scope2 = scope2.scoped({:conditions => project_conditions}).scoped(find_options_tmp)
                scope2 = scope2.scoped( {:conditions => {  :container_type=>"Document"}} )
                results_count_doc = scope2.count(:all)
                results_doc = scope2.find(:all, limit_options)
		results +=results_doc
                results_count += results_count_doc
		#Attachemnts on WikiPage
		find_options_tmp=Hash.new
		find_options_tmp=find_options_tmp.merge(find_options)
		scope2 = scope
                results_wiki= []
                results_count_wiki=0
		find_options_tmp [:joins] =  "INNER JOIN wiki_pages ON wiki_pages.id=container_id " +  
					"INNER JOIN wikis ON wikis.id=wiki_pages.wiki_id " +
					"INNER JOIN #{Project.table_name} ON #{Wiki.table_name}.project_id = #{Project.table_name}.id" 
		scope2 = scope2.scoped({:conditions => project_conditions}).scoped(find_options_tmp)
                scope2 = scope2.scoped( {:conditions => {  :container_type=>"WikiPage"}} )
                results_count_wiki = scope2.count(:all)
                results_wiki = scope2.find(:all, limit_options)
		results+=results_wiki
		results_count+= results_count_wiki
		#Attachemnts on Message
		find_options_tmp =Hash.new
		find_options_tmp=find_options_tmp.merge(find_options)
		scope2 = scope
                results_message= []
                results_count_message=0
		find_options_tmp [:joins] = "INNER JOIN messages ON messages.id=container_id " +  
					"INNER JOIN boards ON boards.id=messages.board_id " +
					"INNER JOIN #{Project.table_name} ON #{Board.table_name}.project_id = #{Project.table_name}.id" 
		scope2 = scope2.scoped({:conditions => project_conditions}).scoped(find_options_tmp)
                scope2 = scope2.scoped( {:conditions => {  :container_type=>"Message"}} )
                results_count_message = scope2.count(:all)
                results_message = scope2.find(:all, limit_options)
		results+=results_message
		results_count+= results_count_message
		#Attachemnts on Issues
		find_options_tmp =Hash.new
		find_options_tmp=find_options_tmp.merge(find_options)
		scope2 = scope
                results_issue= []
                results_count_issue=0
		find_options_tmp [:joins] = "INNER JOIN issues ON issues.id=container_id " +  "LEFT JOIN #{Project.table_name} ON #{Issue.table_name}.project_id = #{Project.table_name}.id" 
		scope2 = scope2.scoped({:conditions => project_conditions}).scoped(find_options_tmp)	
		scope2 = scope2.scoped( {:conditions => {  :container_type=>"Issue"}} )
                results_count_issue = scope2.count(:all)
                results_issue = scope2.find(:all, limit_options)
		results+=results_issue
		results_count+= results_count_issue
		#Attachments on Articles
		if Redmine::Search.available_search_types.include?("articles")
		  sope2 = scope
		  logger.debug "DEBUG: knowledgebase plugin installed"
		  find_options_tmp=Hash.new
        	  find_options_tmp=find_options_tmp.merge(find_options)
        	  results_article = []
       	 	  results_count_article=0
        	  find_options_tmp [:joins] =  "INNER JOIN kb_articles ON kb_articles.id=container_id "  
		  scope2 = scope2.scoped({:conditions => project_conditions}).scoped(find_options_tmp)
                  scope2 = scope2.scoped( {:conditions => {  :container_type=>"Article"}} )
                  results_count_article = scope2.count(:all)
                  results_article = scope2.find(:all, limit_options)
        	  results +=results_article
        	  results_count += results_count_article
		end
		# Search attachments over xapian
		logger.debug "DEBUG: results count before xapian " + results_count.inspect + results_count_issue.inspect + results_count_message.inspect + results_count_wiki.inspect + results_count_doc.inspect 
		if !options[:titles_only]
		  begin 
		    xapianresults, xapianresults_count = XapianSearch.search_attachments( tokens, limit_options, 
								 options[:offset], projects, options[:all_words], 
								options[:user_stem_lang], options[:user_stem_strategy] )
		  rescue => error
		    logger.debug "DEBUG: error raised on xapiansearch"
		    xapianresults=[]
		    xapianresults_count=0
		    raise error
		  end
		  results_count += xapianresults_count
		  results=(results+xapianresults).uniq.sort_by{|x| x[:created_on] }
		  logger.debug "DEBUG result_count: " + results_count.inspect
		  logger.debug "DEBUG results: " + results.size.to_s
		end
	    end
            [results, results_count]
          end


        end
      end
    end
  end
end

