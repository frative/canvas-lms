# Frative customizations

This fork adds a small amount of Frative-specific functionality on top of stock Canvas OSS, to support [`miaula-core-backend`](https://github.com/frative/miaula-core-backend)'s multi-tenant model: **every customer gets their own Canvas root account, its own domain, and its own OIDC `authentication_provider`** — never shared, never a subaccount.

This exists because of two real limitations of Canvas OSS (not this fork specifically):

1. `authentication_providers` can only be configured on a **root account** (`require_root_account_management`), never a subaccount.
2. Canvas OSS has **no domain-based multi-tenancy** at all — `LoadAccount.default_domain_root_account` always resolves `Account.default`, regardless of the request's `Host` header. (Instructure's own SaaS hosting does this in a proprietary layer outside the open-source app.)

Together, those rule out "one shared Canvas instance with subaccounts + a shared login provider" as a way to give each customer a real, isolated domain — hence: separate root accounts.

## What was added

- **`account_domains` table + `AccountDomain` model** (`app/models/account_domain.rb`) — maps a hostname to the root account it should resolve to. `db/migrate/20260801212917_create_account_domains.rb`.
- **`LoadAccount` patch** (`app/middleware/load_account.rb`) — resolves the root account by the request's `Host` header via `AccountDomain`, falling back to `Account.default` for unmapped hosts (preserves `admin.miaula.app` as the fallback/administrative domain).
- **`HostUrl.context_host` patch** (`lib/host_url.rb`) — generates URLs (emails, links) against a context's own domain when it has one, instead of always the single global `default_host`.
- **Internal API** (`app/controllers/internal/`, see [`internal-api.md`](./internal-api.md) and [`internal-api-openapi.json`](./internal-api-openapi.json)) — two bearer-token-protected endpoints, not part of the public Canvas API, called only by `miaula-core-backend`'s provisioning Workflow.

## SSO-only pseudonyms don't get a native password flow

When a root account has a non-Canvas `authentication_provider` configured (i.e. it's one of
our SSO-managed tenants), any new `Pseudonym` created without an explicit provider — via the
People UI, SIS import, or the public API — is auto-assigned that account's prioritized
provider instead of defaulting to Canvas password auth (`Pseudonym#assign_default_sso_provider`,
`app/models/pseudonym.rb`). Once a pseudonym is SSO-managed (`passwordable?` returns `false`),
`Users::CreationNotifyPolicy#dispatch!` (`app/models/users/creation_notify_policy.rb`) skips
sending the "confirm your registration / set a password" email entirely — that flow (native
password creation, unrelated to OIDC) is meaningless once native login is de-prioritized to
break-glass, and exposing it just invites students to set a password nobody should be using.

This only changes behavior for pseudonyms that would otherwise be SSO-managed; accounts using
native Canvas password auth (no OIDC provider registered) are unaffected — `passwordable?`
stays `true` for them, same as stock Canvas.

Note: a temporary random password hash is still generated and stored for every pseudonym
(`crypted_password` is `NOT NULL` at the schema level, a foundational Canvas column) — this is
inert (nobody knows it, it's never surfaced, and native login remains break-glass-only), so
this doesn't attempt to avoid storing it, only to stop inviting users into a pointless
password-setup flow.

## Why an internal API instead of the public one

`miaula-core-backend` orchestrates provisioning from a Cloudflare Workflow, which can't SSH into `calisto-canvas-puma` to run `bin/rails runner` — every action has to be a plain HTTP call. Two things needed doing that the public Canvas API either can't do at all, or doesn't do reliably:

- **Creating a root account.** The public API only exposes `POST /accounts/:id/sub_accounts` — there's no public endpoint to create a *root* account (`parent_account_id: nil`), that's normally a Site Admin / console operation.
- **Making a newly-registered OIDC provider the default login.** The public `POST /accounts/:id/authentication_providers` endpoint accepts a `position` param, but in practice it wasn't being honored — the provider kept landing at position 2, behind the auto-created native `canvas` provider. `AuthenticationProvider#insert_at`, called directly on the model, is the same mechanism already confirmed to work (used manually to reorder `admin.miaula.app`'s providers) — so the internal endpoint just does that directly, bypassing whatever the public controller's params handling is doing differently.

Both endpoints check a bearer token against `ENV["INTERNAL_PROVISIONING_TOKEN"]` (a secret distinct from `CANVAS_API_TOKEN`, set as a systemd `Environment=` drop-in on `calisto-canvas-puma`, mirrored as a Cloudflare Worker secret on `miaula-core-backend`) — never a public, documented, or rate-limited surface the way the real Canvas API is.
