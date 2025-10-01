# frozen_string_literal: true

# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Xabier Elkano, Karel Pičman <karel.picman@kontron.com>
#
# This file is part of Redmine Xapian plugin.
#
# Redmine Xapian plugin is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Redmine Xapian plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
# the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with Redmine Xapian plugin. If not, see
# <https://www.gnu.org/licenses/>.

# Main module
module RedmineXapian
  LANGUAGES = %w[danish dutch english finnish french german german2 hungarian italian kraaij_pohlmann
                 lovins norwegian porter portuguese romanian russian spanish swedish turkish].freeze
  # Settings
  class << self
    def enable?
      value = Setting.plugin_redmine_xapian['enable']
      value.to_i.positive? || value == 'true'
    end

    def index_database
      if Setting.plugin_redmine_xapian['index_database'].present?
        Setting.plugin_redmine_xapian['index_database'].strip
      else
        File.expand_path 'file_index', Rails.root
      end
    end

    def stemming_lang
      if Setting.plugin_redmine_xapian['stemming_lang'].present?
        Setting.plugin_redmine_xapian['stemming_lang'].strip
      else
        'english'
      end
    end

    def stem_langs
      Setting.plugin_redmine_xapian['stem_langs'].presence || ['english']
    end

    def stemming_strategy
      if Setting.plugin_redmine_xapian['stemming_strategy'].present?
        Setting.plugin_redmine_xapian['stemming_strategy'].strip
      else
        'STEM_SOME'
      end
    end

    def languages
      Setting.plugin_redmine_xapian['languages'].presence || LANGUAGES
    end

    def save_search_scope?
      value = Setting.plugin_redmine_xapian['save_search_scope']
      value.to_i.positive? || value == 'true'
    end

    def enable_cjk_ngrams?
      value = Setting.plugin_redmine_xapian['enable_cjk_ngrams']
      value.to_i.positive? || value == 'true'
    end
  end
end

# Libraries
require "#{File.dirname(__FILE__)}/redmine_xapian/search_data"
require "#{File.dirname(__FILE__)}/redmine_xapian/xapian_search"
require "#{File.dirname(__FILE__)}/redmine_xapian/container_type_helper"
require "#{File.dirname(__FILE__)}/redmine_xapian/xapian_search_service"

# Patches
require "#{File.dirname(__FILE__)}/redmine_xapian/patches/attachment_patch"
require "#{File.dirname(__FILE__)}/redmine_xapian/patches/search_controller_patch"
require "#{File.dirname(__FILE__)}/redmine_xapian/patches/search_helper_patch"

# Hooks
# Views
require "#{File.dirname(__FILE__)}/redmine_xapian/hooks/views/base_view_hooks"
require "#{File.dirname(__FILE__)}/redmine_xapian/hooks/views/search_view_hooks"
