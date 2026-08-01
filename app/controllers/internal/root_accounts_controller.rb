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

# Frative: not a public Canvas API — internal, bearer-token-protected endpoint
# used only by miaula-core-backend's provisioning Workflow to create a root
# account (with its own domain) per customer.
module Internal
  class RootAccountsController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false

    before_action :require_internal_token

    def create
      name = params[:name].to_s.strip
      domain = params[:domain].to_s.strip.downcase

      if name.blank? || domain.blank?
        return render json: { error: "name and domain are required" }, status: :bad_request
      end

      if AccountDomain.exists?(domain:)
        return render json: { error: "domain already in use" }, status: :conflict
      end

      account = Account.create!(name:, parent_account_id: nil)
      account.account_domains.create!(domain:)

      render json: { id: account.id, uuid: account.uuid, domain: }, status: :created
    end

    private

    def require_internal_token
      expected = ENV["INTERNAL_PROVISIONING_TOKEN"]
      provided = request.headers["Authorization"].to_s.delete_prefix("Bearer ")

      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided)

      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
