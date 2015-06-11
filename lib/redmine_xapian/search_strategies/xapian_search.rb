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

require 'uri'

module RedmineXapian
  module SearchStrategies
    module XapianSearch
      def xapian_search(tokens, limit_options, projects_to_search, all_words, user)
        Rails.logger.debug 'XapianSearch::xapian_search'
        xpattachments = []
        return nil unless Setting.plugin_redmine_xapian['enable'] == 'true'
        Rails.logger.debug "DEBUG: global settings dump #{Setting.plugin_redmine_xapian.inspect}"
        stemming_lang = Setting.plugin_redmine_xapian['stemming_lang'].rstrip
        Rails.logger.debug "DEBUG: stemming_lang: #{stemming_lang}"
        stemming_strategy = Setting.plugin_redmine_xapian['stemming_strategy'].rstrip
        Rails.logger.debug "DEBUG: stemming_strategy: #{stemming_strategy}"
        databasepath = get_database_path
        Rails.logger.debug "DEBUG: databasepath: #{databasepath}"

        begin
          database = Xapian::Database.new(databasepath)
        rescue => error          
          Rails.logger.error "ERROR: xapian database #{$databasepath} cannot be open #{error.inspect}"          
          return nil
        end

        # Start an enquire session.
        enquire = Xapian::Enquire.new(database)

        # Combine the rest of the command line arguments with spaces between
        # them, so that simple queries don't have to be quoted at the shell
        # level.
        #query_string = ARGV[1..-1].join(' ')
        query_string = tokens.map{ |x| !(x[-1,1].eql?'*')? x+'*': x }.join(' ')
        # Parse the query string to produce a Xapian::Query object.
        qp = Xapian::QueryParser.new()
        stemmer = Xapian::Stem.new(stemming_lang)
        qp.stemmer = stemmer
        qp.database = database
        case stemming_strategy
          when 'STEM_NONE' 
            qp.stemming_strategy = Xapian::QueryParser::STEM_NONE
          when 'STEM_SOME' 
            qp.stemming_strategy = Xapian::QueryParser::STEM_SOME
          when 'STEM_ALL' 
            qp.stemming_strategy = Xapian::QueryParser::STEM_ALL
        end
        if all_words
          qp.default_op = Xapian::Query::OP_AND
        else
          qp.default_op = Xapian::Query::OP_OR
        end
	
        query = qp.parse_query(query_string,Xapian::QueryParser::FLAG_WILDCARD)
        Rails.logger.debug "DEBUG query_string is: #{query_string}"
        Rails.logger.debug "DEBUG: Parsed query is: #{query.description()}"

        # Find the top 100 results for the query.
        enquire.query = query
        matchset = enquire.mset(0, 1000)

        return nil if matchset.nil?

        # Display the results.        
        Rails.logger.debug "DEBUG: Matches 1-#{matchset.size}:\n"

        matchset.matches.each do |m|          
          Rails.logger.debug "DEBUG: m: #{m.document.data.inspect}"
          docdata = m.document.data{url}
          dochash = Hash[*docdata.scan(/(url|sample|modtime|type|size|date)=\/?([^\n\]]+)/).flatten]
          dochash['date'] = Time.at(0).in_time_zone  if dochash['date'].nil? # default timestamp
          dochash['url'] = URI.unescape(dochash['url'].to_s)
          if dochash
            Rails.logger.debug 'DEBUG: dochash not nil.. ' + dochash.fetch('url').to_s
            Rails.logger.debug 'DEBUG: limit_conditions ' + limit_options[:limit].inspect            
            Rails.logger.debug "DEBUG: searching for attachments"
            if attachment = process_attachment(projects_to_search, dochash, user)
              xpattachments << attachment
            end            
          end
        end
        xpattachments = xpattachments.sort_by{|x| x[:created_on] }      
        Rails.logger.debug 'DEBUG: xapian searched'        
        xpattachments.map{ |a| [a.created_on, a.id] }
      end
      
    private         

      def process_attachment(projects, dochash, user)
        docattach = Attachment.where(:disk_filename => dochash.fetch('url').split('/').last).first
        if docattach
          Rails.logger.debug "DEBUG: attach event_datetime #{docattach.event_datetime.inspect}"
          Rails.logger.debug "DEBUG: attach project #{docattach.project.inspect}"
          Rails.logger.debug "DEBUG: docattach not nil..:  #{docattach.inspect}"
          if docattach.container
            Rails.logger.debug 'DEBUG: adding attach...'
            
            project = docattach.container.project
            container_type = docattach['container_type']
            container_permission = SearchStrategies::ContainerTypeHelper.to_permission(container_type)
            can_view_container = user.allowed_to?(container_permission, project)

            allowed = case container_type            
            when 'Issue'
              can_view_issue = Issue.find_by_id(docattach[:container_id]).visible?
              can_view_container && can_view_issue
            else
              can_view_container
            end
            
            projects = [] << projects if projects.is_a?(Project)
            project_ids = projects.collect(&:id) if projects
            
            if allowed && (project_ids.empty? || (project_ids.include?(docattach.container.project.id)))              
              Redmine::Search.cache_store.write("Attachment-#{docattach.id}", 
                dochash['sample'].force_encoding('UTF-8')) if dochash['sample']
              docattach
            else
              Rails.logger.debug 'DEBUG: user without permissions'
              nil
            end
          end
        end
      end
           
      def get_database_path
        File.join(Setting.plugin_redmine_xapian['index_database'].rstrip, 
          Setting.plugin_redmine_xapian['stemming_lang'].rstrip )        
      end
    
    end
  end
end