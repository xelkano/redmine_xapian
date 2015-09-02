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
      def xapian_search(tokens, limit_options, projects_to_search, all_words, user, xapian_file)
        Rails.logger.debug 'XapianSearch::xapian_search'
        xpattachments = []
        return nil unless Setting.plugin_redmine_xapian['enable'] == 'true'
        Rails.logger.debug "Global settings dump #{Setting.plugin_redmine_xapian.inspect}"
        stemming_lang = Setting.plugin_redmine_xapian['stemming_lang'].rstrip
        Rails.logger.debug "stemming_lang: #{stemming_lang}"
        stemming_strategy = Setting.plugin_redmine_xapian['stemming_strategy'].rstrip
        Rails.logger.debug "stemming_strategy: #{stemming_strategy}"
        databasepath = get_database_path(xapian_file)
        Rails.logger.debug "databasepath: #{databasepath}"

        begin
          database = Xapian::Database.new(databasepath)
        rescue => error          
          Rails.logger.error "Can't open Xapian database #{$databasepath} - #{error.inspect}"          
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
        Rails.logger.debug "query_string is: #{query_string}"
        Rails.logger.debug "Parsed query is: #{query.description()}"

        # Find the top 100 results for the query.
        enquire.query = query
        matchset = enquire.mset(0, 1000)

        return nil if matchset.nil?

        # Display the results.        
        Rails.logger.debug "Matches 1-#{matchset.size}:\n"
        i = 0

        matchset.matches.each do |m|          
          Rails.logger.debug "m: #{m.document.data.inspect}"
          docdata = m.document.data{url}
          dochash = Hash[*docdata.scan(/(url|sample|modtime|type|size|date)=\/?([^\n\]]+)/).flatten]
          dochash['date'] = Time.at(0).in_time_zone if dochash['date'].blank? # default timestamp
          dochash['url'] = URI.unescape(dochash['url'].to_s)
          if dochash
            Rails.logger.debug "dochash not nil.. #{dochash['url']}"
            Rails.logger.debug "limit_conditions #{limit_options[:limit]}"
            if(xapian_file == 'Repofile')
              Rails.logger.debug 'Searching for repofiles'
              i = i + 1
              if repo_file = process_repo_file(projects_to_search, dochash, user, i)                
                xpattachments << repo_file
              end
            elsif xapian_file == 'Attachment'
              Rails.logger.debug 'Searching for attachments'
              if attachment = process_attachment(projects_to_search, dochash, user)
                xpattachments << attachment
              end
            end
            
          end
        end        
        Rails.logger.debug 'Xapian searched'        
        xpattachments.map{ |a| [a.created_on, a.id] }
      end
      
    private         

      def process_attachment(projects, dochash, user)
        attachment = Attachment.where(:disk_filename => dochash['url'].split('/').last).first
        if attachment
          Rails.logger.debug "Attachment created on #{attachment.created_on}"
          Rails.logger.debug "Attachment's project #{attachment.project}"
          Rails.logger.debug "Attachment's docattach not nil..:  #{attachment}"
          if attachment.container
            Rails.logger.debug 'Adding attachment'            
            project = attachment.container.project
            container_type = attachment[:container_type]
            container_permission = SearchStrategies::ContainerTypeHelper.to_permission(container_type)
            can_view_container = user.allowed_to?(container_permission, project)
            
            if container_type == 'Issue'
              issue = Issue.find_by_id(attachment[:container_id])
              allowed = can_view_container && issue && issue.visible?
            else
              allowed = can_view_container
            end
            
            projects = [] << projects if projects.is_a?(Project)
            project_ids = projects.collect(&:id) if projects
            
            if allowed && (project_ids.blank? || (project_ids.include?(attachment.container.project.id)))
              Redmine::Search.cache_store.write("Attachment-#{attachment.id}", 
                dochash['sample'].force_encoding('UTF-8')) if dochash['sample']  
              return attachment
            else
              Rails.logger.warn 'User without permissions'                  
            end
          end
        end
        return nil
      end
      
      def process_repo_file(projects, dochash, user, id)        
        Rails.logger.debug "Repository file: #{dochash['url']}"
        Rails.logger.debug "Repository date: #{dochash['date']}"
        Rails.logger.debug "Repository sample field: #{dochash['sample']}"        
        repository_attachment = nil
        if dochash['url'] =~ /^projects\/(.+)\/repository\/([\w\.]*).*\/entry\/(.*)$/
          repo_project_identifier = $1
          Rails.logger.debug "Project identifier: #{repo_project_identifier}"
          repo_identifier = $2
          Rails.logger.debug "Repository identifier: #{repo_identifier}"
          repo_filename = $3
          Rails.logger.debug "Repository file: #{repo_filename}"
          project = Project.where(:identifier => repo_project_identifier).first
          if project            
            repository = Repository.where(:project_id => project.id, :identifier => repo_identifier).first if project            
            if repository
              Rails.logger.debug "Repository found #{repository.identifier}"
              projects = [] << projects if projects.is_a?(Project)
              project_ids = projects.collect(&:id) if projects            
              allowed = user.allowed_to?(:browse_repository, repository.project)

              if allowed
                if (project_ids.blank? || (project_ids.include?(project.id)))
                  repository_attachment = Repofile.new
                  repository_attachment.filename = repo_filename
                  repository_attachment.created_on = dochash['date'].to_datetime
                  repository_attachment.project_id = project.id
                  repository_attachment.description = dochash['sample'].force_encoding('UTF-8') if dochash['sample']
                  repository_attachment.repository_id = repository.id
                  repository_attachment.id = id	          
                  h = { :filename => repository_attachment.filename, :created_on => repository_attachment.created_on.to_s, 
                    :project_id => repository_attachment.project_id, :description => repository_attachment.description,
                    :repository_id => repository_attachment.repository_id }                          
                  Redmine::Search.cache_store.write("Repofile-#{repository_attachment.id}", h.to_s)               
                else
                  Rails.logger.warn 'No projects to search in'
                end
              else
                Rails.logger.warn 'User without :browse_repository permissions'
              end
            else
              Rails.logger.error "Repository not found"
            end
          else
            Rails.logger.error "Project #{repo_project_identifier} not found"
          end
        else
          Rails.logger.error 'Wrong format of the URL'
        end
        repository_attachment
      end
           
      def get_database_path(xapian_file)
        if xapian_file == 'Repofile'
          File.join(Setting.plugin_redmine_xapian['index_database'].rstrip, 'repodb')
        else
          File.join(Setting.plugin_redmine_xapian['index_database'].rstrip, 
            Setting.plugin_redmine_xapian['stemming_lang'].rstrip )        
        end
      end
      
    end
  end
end