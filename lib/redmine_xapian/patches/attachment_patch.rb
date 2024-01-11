# frozen_string_literal: true

# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Xabier Elkano, Karel Pičman <karel.picman@kontron.com>
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
    # Attachment module patch
    module AttachmentPatch
      def self.included(base)
        base.class_eval do
          Attachment.acts_as_searchable(
            columns: ["#{Attachment.table_name}.filename", "#{Attachment.table_name}.description"],
            project_key: 'project_id',
            date_column: 'created_on'
          )
        end
      end

      def self.prepended(base)
        base.send(:prepend, EventMethods)
        class << base
          prepend SearchMethods
        end
      end

      # Event methods module
      module EventMethods
        def event_description
          desc = Redmine::Search.cache_store.fetch("Attachment-#{id}")
          if desc
            Redmine::Search.cache_store.delete("Attachment-#{id}")
          else
            desc = description
          end
          desc
        end
      end

      # Search methods module
      module SearchMethods
        def search_result_ranks_and_ids(tokens, user = User.current, projects = nil, options = {})
          r = search(tokens, user, projects, options)
          r.map { |x| [x[0].to_i, x[1]] }
        end

        private

        def search(tokens, user, projects = nil, options = {})
          Rails.logger.debug 'Attachment::search'
          search_data = SearchData.new(self, tokens, projects, options, user, name)
          search_results = search_for_issues_attachments(user, search_data)
          search_results.concat search_for_message_attachments(user, search_data)
          search_results.concat search_for_wiki_page_attachments(user, search_data)
          search_results.concat search_for_project_files(user, search_data)
          unless options[:titles_only]
            Rails.logger.debug { "Call xapian search service for #{name}" }
            xapian_results = XapianSearchService.search(search_data)
            search_results.concat(xapian_results) if xapian_results.present?
            Rails.logger.debug { "Call xapian search service for #{name} completed" }
          end
          search_results
        end

        def search_for_issues_attachments(user, search_data)
          results = []
          sql = +%(
            #{Attachment.table_name}.container_type = 'Issue' AND
            #{Project.table_name}.status = ? AND
            #{Project.allowed_to_condition(user, :view_issues)}
          )
          sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
          Attachment.joins("JOIN #{Issue.table_name} ON #{Attachment.table_name}.container_id = #{Issue.table_name}.id")
                    .joins("JOIN #{Project.table_name} ON #{Issue.table_name}.project_id = #{Project.table_name}.id")
                    .where(sql, Project::STATUS_ACTIVE).scoping do
                      where(tokens_condition(search_data)).scoping do
                        results = where(search_data.limit_options).distinct.pluck(searchable_options[:date_column], :id)
                      end
                    end
          results
        end

        def search_for_message_attachments(user, search_data)
          results = []
          sql = +%(
            #{Attachment.table_name}.container_type = 'Message' AND
            #{Project.table_name}.status = ? AND
            #{Project.allowed_to_condition(user, :view_messages)}
          )
          sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
          Attachment
            .joins("JOIN #{Message.table_name} ON #{Attachment.table_name}.container_id = #{Message.table_name}.id")
            .joins("JOIN #{Board.table_name} ON #{Board.table_name}.id = #{Message.table_name}.board_id")
            .joins("JOIN #{Project.table_name} ON #{Board.table_name}.project_id = #{Project.table_name}.id")
            .where(sql, Project::STATUS_ACTIVE).scoping do
              where(tokens_condition(search_data)).scoping do
                results = where(search_data.limit_options).distinct.pluck(searchable_options[:date_column], :id)
              end
            end
          results
        end

        def search_for_wiki_page_attachments(user, search_data)
          results = []
          sql = +%(
            #{Attachment.table_name}.container_type = 'WikiPage' AND
            #{Project.table_name}.status = ? AND
            #{Project.allowed_to_condition(user, :view_wiki_pages)}
          )
          sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
          Attachment
            .joins("JOIN #{WikiPage.table_name} ON #{Attachment.table_name}.container_id = #{WikiPage.table_name}.id")
            .joins("JOIN #{Wiki.table_name} ON #{Wiki.table_name}.id = #{WikiPage.table_name}.wiki_id")
            .joins("JOIN #{Project.table_name} ON #{Wiki.table_name}.project_id = #{Project.table_name}.id")
            .where(sql, Project::STATUS_ACTIVE).scoping do
              where(tokens_condition(search_data)).scoping do
                results = where(search_data.limit_options).distinct.pluck(searchable_options[:date_column], :id)
              end
            end
          results
        end

        def search_for_project_files(user, search_data)
          results = []
          sql = +%(
            container_type = 'Project' AND
            #{Project.table_name}.status = ? AND
            #{Project.allowed_to_condition(user, :view_files)}
          )
          sql << " AND #{search_data.project_conditions}" if search_data.project_conditions
          Attachment.joins("JOIN #{Project.table_name} ON #{Project.table_name}.id = container_id")
                    .where(sql, Project::STATUS_ACTIVE).scoping do
                      where(tokens_condition(search_data)).scoping do
                        results = where(search_data.limit_options).distinct.pluck(searchable_options[:date_column], :id)
                      end
                    end
          results
        end

        def container_url
          case container.is_a?
          when Issue
            issue_path id: container[:id]
          when WikiPage
            wiki_path project_id: container.project.identifier, id: container[:title]
          when Message
            message_path board_id: container[:board_id], id: container[:id]
          when Version
            attachment_path project_id: container[:project_id]
          end
        end

        def container_name
          case container.is_a?
          when Issue, Message
            ": #{container[:subject]}"
          when WikiPage
            ": #{container[:title]}"
          when Version
            ": #{container[:name]}"
          else
            ': '
          end
        end

        def search_options(search_data, search_joins_query)
          search_data.find_options.merge joins: search_joins_query
        end

        def tokens_condition(search_data)
          options = search_data.options
          columns = search_data.columns
          tokens = search_data.tokens
          columns = columns[0..0] if options[:titles_only]
          token_clauses = columns.collect { |column| "(LOWER(#{column}) LIKE ?)" }
          sql = (["(#{token_clauses.join(' OR ')})"] * tokens.size).join(options[:all_words] ? ' AND ' : ' OR ')
          [sql, * (tokens.collect { |w| "%#{w.downcase}%" } * token_clauses.size).sort]
        end
      end
    end
  end
end

Attachment.include RedmineXapian::Patches::AttachmentPatch
Attachment.prepend RedmineXapian::Patches::AttachmentPatch
