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

# Maps a hostname to the root Account that should be resolved for requests
# to that host. Canvas OSS has no built-in domain-based multi-tenancy
# (LoadAccount always resolves Account.default) — this is Frative-specific,
# introduced so each customer can have its own root account with its own
# authentication_provider, reachable at its own domain.
class AccountDomain < ApplicationRecord
  belongs_to :root_account, class_name: "Account"

  validates :domain, presence: true, uniqueness: true, length: { maximum: 255 }
  validate :account_must_be_root_account

  # keep the natural `.account` name available for callers (AccountDomain
  # always points at a root account, so this is just an alias)
  alias_method :account, :root_account

  private

  def account_must_be_root_account
    errors.add(:root_account, "must be a root account") if root_account && !root_account.root_account?
  end
end
