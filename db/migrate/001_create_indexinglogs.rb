# frozen_string_literal: true
# #
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright © 2010    Xabier Elkano
# Copyright © 2015-23 Karel Pičman <karel.picman@kontron.com>
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

# Create Index log table
class CreateIndexinglogs < ActiveRecord::Migration[4.2]
  def change
    create_table :indexinglogs do |t|
      t.integer :repository_id
      t.integer :changeset_id
      t.integer :status
      t.string :message
      t.datetime :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :updated_at, :timestamp
    end
  end
end
