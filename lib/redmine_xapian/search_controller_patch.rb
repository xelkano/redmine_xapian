require_dependency 'search_controller'
require 'will_paginate/array'

module RedmineXapian
  module SearchControllerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :index, :xapian
        #def get_user_xapian_settings
        #  [@user_stem_lang, @user_stem_strategy]
        #end

        helper ::RedmineXapian::SearchHelper
      end
    end

    module InstanceMethods
      def index_with_xapian
        @question = params[:q] || ""
        @question.strip!
        @all_words = params[:all_words] ? params[:all_words].present? : true
        @titles_only = params[:titles_only] ? params[:titles_only].present? : false

        @user_stem_lang=params[:user_stem_lang] ? params[:user_stem_lang] : Setting.plugin_redmine_xapian['stemming_lang']
        @user_stem_strategy=params[:user_stem_strategy] ? params[:user_stem_strategy] : Setting.plugin_redmine_xapian['stemming_strategy']
        Rails.logger.debug "DEBUG: params[:user_stem_lang]" + params[:user_stem_lang].inspect + @user_stem_lang.inspect
        Rails.logger.debug "DEBUG: params[:user_stem_strategy]" + params[:user_stem_strategy].inspect + @user_stem_strategy.inspect


        projects_to_search =
            case params[:scope]
            when 'all'
              nil
            when 'my_projects'
              User.current.memberships.collect(&:project)
            when 'subprojects'
              @project ? (@project.self_and_descendants.active) : nil
            else
              @project
            end

          offset = nil
          begin; offset = params[:offset].to_time if params[:offset]; rescue; end

          # quick jump to an issue
          if @question.match(/^#?(\d+)$/) && Issue.visible.find_by_id($1.to_i)
            redirect_to :controller => "issues", :action => "show", :id => $1
            return
          end

          @object_types = Redmine::Search.available_search_types.dup
          if projects_to_search.is_a? Project
            # don't search projects
            @object_types.delete('projects')
            # only show what the user is allowed to view
            @object_types = @object_types.select do |o|
              if o == "attachments" || o == "repofiles"
                true
              else
                User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)
              end
            end
          end

          @scope = @object_types.select {|t| params[t]}
          @scope = @object_types if @scope.empty?

          # extract tokens from the question
          # eg. hello "bye bye" => ["hello", "bye bye"]
          @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
          # tokens must be at least 2 characters long
          @tokens = @tokens.uniq.select {|w| w.length > 1 }

          if !@tokens.empty?
            # no more than 5 tokens to search for
            @tokens.slice! 5..-1 if @tokens.size > 5

            @results = []
 	    @rresults = []
            @results_by_type = Hash.new {|h,k| h[k] = 0}

            limit = 10
            Rails.logger.debug "DEBUG: scope " + @scope.inspect
            @scope.each do |s|
        begin
          Rails.logger.debug "DEBUG: element: " + s.inspect
                r, c = s.singularize.camelcase.constantize.search(@tokens, projects_to_search,
                :all_words => @all_words,
                :titles_only => @titles_only,
                :limit => (limit+1),
                :offset => offset,
                :before => params[:previous].nil?,
          	:user_stem_lang => @user_stem_lang,
          	:user_stem_strategy => @user_stem_strategy)
                @rresults += r
                @results_by_type[s] += c
        rescue => error
          flash[:error] = "#{error}: searching model #{s.inspect}"
        end

          end
          @rresults = @rresults.sort {|a,b| b.event_datetime <=> a.event_datetime}
          current_page = params[:page]
          #per_page = params[:per_page] # could be configurable or fixed in your app
          per_page=10
          @results = @rresults.paginate( :page=>current_page, :per_page=>per_page)
        else
          @question = ""
          flash.delete(:error)
        end
        render :layout => false if request.xhr?
      end
      def get_user_xapian_settings
          [@user_stem_lang, @user_stem_strategy]
      end
    end
  end
end
