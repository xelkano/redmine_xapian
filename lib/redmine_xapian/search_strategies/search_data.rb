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

module RedmineXapian
  module SearchStrategies
    class SearchData
      attr_reader :tokens, :projects, :options,
        :find_options, :limit_options, :columns,
        :project_conditions, :user, :element

      def initialize(context, tokens, projects, options, user, element)
        @context = context
        @tokens = tokens        
        if projects.is_a? Project || projects.nil?
          @projects = [] << projects
        else
          @projects = projects
        end
        @options = options
        @columns = searchable_options[:columns]        
        @user = user
        @element = element
        
        init_find_options(@options)
        init_limit_options(@options)
        init_scope_and_projects_conditions(@projects)        
      end

      private
        def init_limit_options(options)
          limit_options = {}
          limit_options[:limit] = options[:limit] if options[:limit]
          if options[:offset]
            limit_options[:conditions] = "(#{searchable_options[:date_column]} " + (options[:before] ? '<' : '>') + "'#{connection.quoted_date(options[:offset])}')"
          end

          @limit_options = limit_options
        end

        def init_scope_and_projects_conditions(projects)          
          project_conditions = []          
          project_conditions << "projects.id IN (#{projects.collect(&:id).join(',')})" if projects
          project_conditions = project_conditions.empty? ? nil : project_conditions.join(' AND ')          
          @project_conditions = project_conditions                   
        end

        def init_find_options(options)
          find_options = {:include => searchable_options[:include]}
          find_options[:order] = "#{searchable_options[:order_column]} " + (options[:before] ? 'DESC' : 'ASC')
          @find_options = find_options
        end

        def searchable_options
          @context.searchable_options
        end

        def connection
          @context.connection
        end
    end
  end
end
