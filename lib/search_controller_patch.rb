
require_dependency 'search_controller'

module SearchControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :index, :xapian
      def get_user_xapian_settings
        [@user_stem_lang, @user_stem_strategy]
      end
    end
  end
  
  module InstanceMethods
    def index_with_xapian
	@user_stem_lang=params[:user_stem_lang] ? params[:user_stem_lang] : Setting.plugin_redmine_xapian['stemming_lang']
        @user_stem_strategy=params[:user_stem_strategy] ? params[:user_stem_strategy] : Setting.plugin_redmine_xapian['stemming_strategy']
	Rails.logger.debug "DEBUG: params[:user_stem_lang]" + params[:user_stem_lang].inspect + @user_stem_lang.inspect
	Rails.logger.debug "DEBUG: params[:user_stem_strategy]" + params[:user_stem_strategy].inspect + @user_stem_strategy.inspect
	index_without_xapian
    end
    def get_user_xapian_settings
        [@user_stem_lang, @user_stem_strategy]
    end
  end
end

