require_dependency 'search_controller'
require File.dirname(__FILE__) + '/../app/controllers/search_controller'

module SearchControllerPatch
  def self.included(base) # :nodoc:
    base.class_eval do
      alias_method_chain :index, :xapian
    end
  end
end
