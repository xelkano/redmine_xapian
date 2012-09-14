require 'simplecov'

SimpleCov.start do
  redmine_xapian_base = File.expand_path(File.dirname(__FILE__) + '/../')
  root redmine_xapian_base
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Views", "app/views"
  add_group "Lib", "lib"
end

# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')
