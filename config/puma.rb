# frozen_string_literal: true

#
# Copyright (C) 2017 - present Instructure, Inc.
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

threads ENV.fetch("PUMA_MIN_THREADS", 0).to_i, ENV.fetch("PUMA_MAX_THREADS", 1).to_i

# Worker count is per-instance (depends on available cores, whether the
# machine also runs jobs/redis, etc), so it's left unset by default and only
# enabled when PUMA_WORKERS is provided via the service's environment.
workers ENV.fetch("PUMA_WORKERS").to_i if ENV["PUMA_WORKERS"]

if ENV["RAILS_ENV"] == "production"
  # preload_app! true: el master bootea Rails una sola vez y los workers se
  # crean con fork(), compartiendo memoria por copy-on-write. Reduce RAM
  # agregada frente a que cada worker booteé la app de cero (medido en
  # frative-apps-prod 2026-08-09: ~750-830MB privados por worker sin esto).
  # Trade-off asumido explícitamente: se pierde "phased restart" (reinicio
  # sin downtime worker-por-worker) — decisión tomada en ventana de
  # mantenimiento, 2026-08-09.
  preload_app! true

  worker_boot_timeout 240 # seconds
end
