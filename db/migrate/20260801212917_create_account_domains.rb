# frozen_string_literal: true

#
# Copyright (C) 2026 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#
class CreateAccountDomains < ActiveRecord::Migration[8.0]
  tag :predeploy

  def change
    create_table :account_domains do |t|
      t.references :root_account, null: false, foreign_key: { to_table: :accounts }
      t.string :domain, null: false, limit: 255
      t.timestamps

      t.replica_identity_index
      t.index :domain, unique: true, name: "index_account_domains_on_domain"
    end
  end
end
