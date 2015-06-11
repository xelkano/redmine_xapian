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

require_dependency 'search_controller'
require 'will_paginate/array'

module RedmineXapian
  module SearchControllerPatch    
    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :index, :xapian              
        helper ::RedmineXapian::SearchHelper
      end            
    end

    module InstanceMethods
      
      def index_with_xapian
        @question = params[:q] || ""
        @question.strip!
        @all_words = params[:all_words] ? params[:all_words].present? : true
        # Plugin change start
        #@titles_only = params[:titles_only] ? params[:titles_only].present? : false
        @titles_only = params[:titles_only] ? params[:titles_only].present? : true
        # Plugin change end
        @search_attachments = params[:attachments].presence || '0'
        @open_issues = params[:open_issues] ? params[:open_issues].present? : false
        
        # Plugin change start
        flash.now[:warning] = l(:notice_search_tips)
        # Plugin change end

        # quick jump to an issue
        if (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
          redirect_to issue_path(issue)
          return
        end
        
        # Plugin change start
        # A Kontron extension to quick jump to an issue by the identifier
        if @question.match(/^(BUG|FEA)(\d+)$/) && Issue.visible.find_by_id($2.to_i)          
          redirect_to issue_path($2)
          return
        end
        # Plugin change end

        projects_to_search =
          case params[:scope]
          when 'all'
            nil
          when 'my_projects'
            User.current.projects
          when 'subprojects'
            @project ? (@project.self_and_descendants.active.to_a) : nil
          else
            @project
          end

        @object_types = Redmine::Search.available_search_types.dup
        if projects_to_search.is_a? Project
          # don't search projects
          @object_types.delete('projects')
          # only show what the user is allowed to view
          # Plugin change start
          #@object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
          @object_types = @object_types.select do |o| 
            case o
            when 'attachments'
              User.current.allowed_to?('view_files'.to_sym, projects_to_search)
            else
              User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)
            end
          end
          # Plugin change end
        end

        @scope = @object_types.select {|t| params[t]}
        # Plugin change start
        #@scope = @object_types if @scope.empty?
        @scope = %w(projects wiki_pages) if @scope.empty?
        # Plugin change end

        fetcher = Redmine::Search::Fetcher.new(
          @question, User.current, @scope, projects_to_search,
          :all_words => @all_words, :titles_only => @titles_only, :attachments => @search_attachments, :open_issues => @open_issues,
          :cache => params[:page].present?
        )

        if fetcher.tokens.present?
          @result_count = fetcher.result_count
          @result_count_by_type = fetcher.result_count_by_type
          @tokens = fetcher.tokens

          per_page = Setting.search_results_per_page.to_i
          per_page = 10 if per_page == 0
          @result_pages = Redmine::Pagination::Paginator.new @result_count, per_page, params['page']
          @results = fetcher.results(@result_pages.offset, @result_pages.per_page)
        else
          @question = ""
        end
        render :layout => false if request.xhr?  
        end
      end
    
  end
end

SearchController.send(:include, RedmineXapian::SearchControllerPatch)