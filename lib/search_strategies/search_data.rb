# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

# @see acts_as_searchable/lib/acts_as_searchable.rb
class SearchStrategies::SearchData
  attr_reader :tokens, :projects, :options,
    :find_options, :limit_options, :columns,
    :scope, :project_conditions

  def initialize(context, tokens, projects, options)
    @context = context

    @tokens = tokens
    @projects = [] << projects unless projects.nil? || projects.is_a?(Array)
    @options = options
    @columns = searchable_options[:columns]

    init_find_options(@options)
    init_limit_options(@options)
    init_scope_and_projects_conditions(@context, @projects)
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

    def init_scope_and_projects_conditions(context, projects)
      scope = context

      user = User.current

      project_conditions = []
      if searchable_options.has_key?(:permission)
        project_conditions << Project.allowed_to_condition(user, searchable_options[:permission] || :view_project)
      elsif respond_to?(:visible)
        scope = scope.visible(user)
      else
        ActiveSupport::Deprecation.warn "acts_as_searchable with implicit :permission option is deprecated. Add a visible scope to the #{context.name} model or use explicit :permission option."
        project_conditions << Project.allowed_to_condition(user, "view_#{context.name.underscore.pluralize}".to_sym)
      end

      # TODO: use visible scope options instead
      project_conditions << "#{searchable_options[:project_key]} IN (#{projects.collect(&:id).join(',')})" unless projects.nil?
      project_conditions = project_conditions.empty? ? nil : project_conditions.join(' AND ')

      @scope = scope
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
end
