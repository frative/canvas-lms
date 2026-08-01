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

# Frative: not a public Canvas API — internal, bearer-token-protected endpoint.
# The public authentication_providers API accepts a `position` param on create,
# but it's not reliably honored there (params-wrapping quirk); this calls
# AuthenticationProvider#insert_at directly, the same mechanism already
# confirmed working for admin.miaula.app's manual reorder.
module Internal
  class AuthenticationProvidersController < BaseController
    def prioritize
      provider = AuthenticationProvider.active.find(params[:id])
      provider.insert_at(1)
      render json: { id: provider.id, position: provider.reload.position }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "not found" }, status: :not_found
    end
  end
end
