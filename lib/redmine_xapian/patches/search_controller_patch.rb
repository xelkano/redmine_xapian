# encoding: utf-8
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright © 2010   Xabier Elkano
# Copyright © 2015-19 Karel Pičman <karel.picman@kontron.com>
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
  module Patches
    module SearchControllerPatch

      SearchController.helper ::RedmineXapian::SearchHelper

      def index
        @question = params[:q] || ""
        @question.strip!
        # Plugin change do
        #@all_words = params[:all_words] ? params[:all_words].present? : true
        #@titles_only = params[:titles_only] ? params[:titles_only].present? : false
        if Setting.plugin_redmine_xapian['save_search_scope']
          if params[:all_words]
            @all_words = params[:all_words].present?
            @titles_only = params[:titles_only].present?
            preferences = User.current.pref
            preferences[:xapian_search_option] = []
            preferences[:xapian_search_option] << 'all_words' if @all_words
            preferences[:xapian_search_option] << 'titles_only' if @titles_only
            preferences.save!
          else
            pref = User.current.pref[:xapian_search_option]
            @all_words = pref ? pref.include?('all_words') : true
            @titles_only = pref ? pref.include?('titles_only') : false
          end
        else
          @all_words = params[:all_words] ? params[:all_words].present? : true
          @titles_only = params[:titles_only] ? params[:titles_only].present? : false
        end
        # end
        @search_attachments = params[:attachments].presence || '0'
        @open_issues = params[:open_issues] ? params[:open_issues].present? : false

        case params[:format]
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
        else
          @offset = nil
          @limit = Setting.search_results_per_page.to_i
          @limit = 10 if @limit == 0
        end

        # quick jump to an issue
        if (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
          redirect_to issue_path(issue)
          return
        end

        # Plugin change do
        # A hook allowing plugins to implement a quick jump to an object
        ret = call_hook(:controller_search_quick_jump, { :question => @question })
        ret.each do |path|
          if path
            redirect_to path
            return
          end
        end
        # Plugin change end

        projects_to_search =
          case params[:scope]
          when 'all'
            nil
          when 'my_projects'
            User.current.projects
          when 'subprojects'
            @project ? (@project.self_and_descendants.to_a) : nil
          else
            @project
          end

        @object_types = Redmine::Search.available_search_types.dup
        if projects_to_search.is_a? Project
          # don't search projects
          @object_types.delete('projects')
          # only show what the user is allowed to view
          # Plugin change do
          #@object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
          @object_types = @object_types.select do |o|
            case o
            when 'attachments'
              # Files/Attachments option is always visible
              true
            when 'repofiles'
              User.current.allowed_to?('browse_repository'.to_sym, projects_to_search)
            else
              User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)
            end
          end
          # end
        end

        @scope = @object_types.select {|t| params[t]}
        # Plugin change do
        if Setting.plugin_redmine_xapian['save_search_scope']
          if @scope.empty?
            pref = User.current.pref[:xapian_search_scope]
            @scope =  pref & @object_types if pref
          else
            User.current.pref[:xapian_search_scope] = @scope
            User.current.pref.save!
          end
        end
        # end
        @scope = @object_types if @scope.empty?

        fetcher = Redmine::Search::Fetcher.new(
          @question, User.current, @scope, projects_to_search,
          :all_words => @all_words, :titles_only => @titles_only, :attachments => @search_attachments, :open_issues => @open_issues,
          :cache => params[:page].present?, :params => params.to_unsafe_hash
        )

        if fetcher.tokens.present?
          @result_count = fetcher.result_count
          @result_count_by_type = fetcher.result_count_by_type
          @tokens = fetcher.tokens

          @result_pages = Redmine::Pagination::Paginator.new @result_count, @limit, params['page']
          @offset ||= @result_pages.offset
          @results = fetcher.results(@offset, @result_pages.per_page)
        else
          @question = ""
        end
        respond_to do |format|
          format.html { render :layout => false if request.xhr? }
          format.api  { @results ||= []; render :layout => false }
        end
      end

    end
  end
end

SearchController.send(:prepend, RedmineXapian::Patches::SearchControllerPatch)
