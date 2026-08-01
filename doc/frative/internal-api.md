# Internal provisioning API

Not part of the public Canvas API — not versioned, not rate-limited the way `/api/v1` is, not documented anywhere Canvas's own API docs are generated from. Exists solely for `miaula-core-backend`'s `ProvisionCanvasInstance` Workflow (`src/workflows/provision-canvas-instance.ts`) to call over HTTP, since Cloudflare Workflows can't SSH to run `bin/rails runner`.

Machine-readable spec: [`internal-api-openapi.json`](./internal-api-openapi.json).

## Auth

Both endpoints require:

```
Authorization: Bearer <INTERNAL_PROVISIONING_TOKEN>
```

Checked with `ActiveSupport::SecurityUtils.secure_compare` against `ENV["INTERNAL_PROVISIONING_TOKEN"]` (`app/controllers/internal/base_controller.rb`). Missing or wrong token → `401 { "error": "unauthorized" }`.

## `POST /internal/root_accounts`

Creates a new Canvas **root account** (`parent_account_id: nil`) and its `AccountDomain`.

**Idempotent** by `(name, domain)`: if a `canvas_instance` step retries after a transient platform error but the account was actually already created, re-posting the same `name` + `domain` returns the existing account (`200`) instead of erroring — this bit us once in testing (`WorkflowInternalError` → automatic retry → `409` on a domain that had, in fact, already been created).

**Body**

| field | type | notes |
|---|---|---|
| `name` | string | required |
| `domain` | string | required, must be globally unique across `account_domains` |

**Responses**

- `201` — created. `{ id, uuid, domain }`
- `200` — already existed with the same `name` (idempotent replay). Same shape.
- `400` — `name` or `domain` missing
- `409` — `domain` already in use by a *different* `name`
- `401` — bad/missing bearer token

## `POST /internal/authentication_providers/:id/prioritize`

Moves the given `authentication_provider` to position 1 on its account (`AuthenticationProvider#insert_at(1)`), making it that account's default login. Called right after `registerOidcProvider` in the provisioning Workflow — the native `canvas` password login stays active, just no longer the default, reachable at `/login/canvas` as a break-glass fallback.

**Responses**

- `200` — `{ id, position }`
- `404` — no active provider with that id
- `401` — bad/missing bearer token
