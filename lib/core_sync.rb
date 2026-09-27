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

# Frative: pushes the state of a Canvas user within one root account to
# miaula-core-backend (POST /internal/canvas-sync/users), which mirrors every
# organization's Canvas users as `member` rows. Triggered from after_commit hooks on
# Pseudonym, AccountUser and User, so it covers every creation path (UI, API, SIS,
# self-registration). The job reads the *current* state when it runs, so coalescing or
# replaying it is harmless; usage-tracker's hourly reconciliation catches anything lost.
module CoreSync
  MAX_ATTEMPTS = 8

  class DeliveryError < StandardError; end

  class << self
    def enabled?
      ENV["CORE_BASE_URL"].present? && ENV["INTERNAL_PROVISIONING_TOKEN"].present?
    end

    def enqueue(root_account_id, user_id)
      return unless enabled? && root_account_id && user_id

      delay_if_production(
        singleton: "core_sync:#{root_account_id}:#{user_id}",
        max_attempts: MAX_ATTEMPTS
      ).sync_user(root_account_id, user_id)
    end

    def sync_user(root_account_id, user_id)
      root_account = Account.find_by(id: root_account_id)
      return unless root_account&.root_account?

      payload = {
        canvas_account_id: root_account.id.to_s,
        users: [user_state(root_account, user_id)]
      }
      deliver("/internal/canvas-sync/users", payload)
    end

    def user_state(root_account, user_id)
      user = User.find_by(id: user_id)
      pseudonym = if user && user.workflow_state != "deleted"
                    Pseudonym.where(account_id: root_account.id, user_id:)
                             .where(workflow_state: %w[active suspended])
                             .order(:id)
                             .first
                  end
      status = if pseudonym.nil?
                 "deleted"
               elsif pseudonym.workflow_state == "suspended"
                 "suspended"
               else
                 "active"
               end
      {
        canvas_user_id: user_id,
        email: pseudonym&.unique_id&.downcase,
        name: user&.name,
        is_admin: AccountUser.active.where(user_id:, root_account_id: root_account.id).exists?,
        status:
      }
    end

    private

    def deliver(path, payload)
      response = CanvasHttp.post(
        "#{ENV["CORE_BASE_URL"].chomp("/")}#{path}",
        { "Authorization" => "Bearer #{ENV["INTERNAL_PROVISIONING_TOKEN"]}" },
        body: payload.to_json,
        content_type: "application/json"
      )
      # Raising makes the delayed job retry (up to MAX_ATTEMPTS, with backoff).
      raise DeliveryError, "core sync failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    end
  end
end
