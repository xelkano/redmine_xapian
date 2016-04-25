# encoding: utf-8
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright (C) 2015-16  Karel Pičman <karel.picman@kontron.com>
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

desc <<-END_DESC
Xapian set repository identifiers task
  * Set a default identifier for repositories that haven't got it

Available options:
  *identifier - A text to be set as the identifier
  *dry_run - test, no changes to the database

Example:
  bundle exec rake redmine:xapian_set_identifiers RAILS_ENV="production"
  bundle exec rake redmine:xapian_set_identifiers identifier='main' RAILS_ENV="production"
  bundle exec rake redmine:xapian_set_identifiers identifier='main' dry_run=1 RAILS_ENV="production"
END_DESC

namespace :redmine do
  task :xapian_set_identifiers => :environment do
    m = XapianRepositoryIdentifier.new
    m.set_identifier
  end
end

class XapianRepositoryIdentifier

  def initialize
    @dry_run = ENV['dry_run']
    @identifier = ENV['identifier'].blank? ? 'main' : ENV['identifier']
  end

  def set_identifier
    repositories = Repository.where('identifier IS NULL').all
    count = repositories.count
    n = 0
    repositories.each_with_index do |rep, i|
      rep.identifier = @identifier
      rep.save unless @dry_run
      n += 1
      # Progress bar
      print "\r#{i * 100 / count}%"
    end
    print "\r100%\n"
    # Result
    puts "#{n}/#{Repository.count} repositories updated."
  end

end
