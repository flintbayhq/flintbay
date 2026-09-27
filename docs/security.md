# Security Configuration

Flintbay includes several security features that are enabled by default. This page covers account lockout, password policy, JWT key rotation, and session management.

## Account Lockout

Protects against brute-force login attempts.

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_LOCKOUT_ENABLED` | `true` | Enable/disable lockout |
| `FLINTBAY_LOCKOUT_MAX_ATTEMPTS` | `5` | Failed attempts before lockout |
| `FLINTBAY_LOCKOUT_DURATION_MINUTES` | `15` | How long the account is locked |

After 5 failed login attempts, the account is locked for 15 minutes. The lockout is per-account, not per-IP.

Because it counts per account, anyone who can reach the login page and knows a username can keep
that account locked, including the administrator's. Do not expose the login page to networks you
do not trust, or put a proxy in front of it that limits login attempts per client address.

> **Tip:** If you lock yourself out, wait 15 minutes. A deployment administrator can
> reset another account's password from **Sidebar → Administration → Users**.

## Password Policy

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_PASSWORD_MIN_LENGTH` | `8` | Minimum password length |
| `FLINTBAY_PASSWORD_MAX_LENGTH` | `72` | Maximum length (bcrypt limit) |

Passwords are hashed with bcrypt. The 72-character limit is a bcrypt constraint — characters beyond 72 are silently ignored by the algorithm.

## JWT Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_JWT_SECRET_KEY` | *(auto-generated)* | Signing key for access tokens |
| `FLINTBAY_JWT_TOKEN_EXPIRE_MINUTES` | `30` | Access token lifetime |
| `FLINTBAY_JWT_ALGORITHM` | `HS256` | Signing algorithm |

### Auto-Generated Secret

On first run, Flintbay generates a random JWT secret and persists it in the data volume at `/var/lib/flintbay/.jwt_secret`. This survives container restarts and image updates.

### Key Rotation

To rotate the JWT signing key without invalidating all active sessions:

1. Set `FLINTBAY_JWT_PREVIOUS_SECRET_KEY` to the current key
2. Set `FLINTBAY_JWT_SECRET_KEY` to the new key
3. Restart the container
4. Wait for `token_expire_minutes` (30 min by default) — old tokens expire naturally
5. Remove `FLINTBAY_JWT_PREVIOUS_SECRET_KEY`

During the transition window, Flintbay accepts tokens signed with either key.

Two more things are keyed by the JWT secret, and the previous key covers them too:

- **API keys**: a key issued under the previous secret is accepted and moved to the new one the
  first time it is used; see [API Keys](api-keys.md#rotating-the-jwt-secret).
- **Refresh tokens**, unless `FLINTBAY_SESSION_REFRESH_TOKEN_SECRET` is set: a token issued under the
  previous secret still refreshes, and its successor is stored under the new one.

Both only work while `FLINTBAY_JWT_PREVIOUS_SECRET_KEY` is set. Keep it longer than the 30 minutes
above: until every API key has been used once, and ideally for the refresh token lifetime (30 days).
Anything not used before you remove it stops working.

> **Before 0.1.7**, the previous key covered neither: a JWT rotation broke every API key and signed
> every browser out when its access token next expired.

## Session Management

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_SESSION_MAX_CONCURRENT` | `5` | Max active sessions per user |
| `FLINTBAY_SESSION_REFRESH_TOKEN_EXPIRE_DAYS` | `30` | Refresh token lifetime |
| `FLINTBAY_SESSION_REVOKE_OLD_ON_MAX` | `true` | Auto-revoke oldest session when limit reached |

### How Sessions Work

- Login creates a session with an access token (short-lived) and refresh token (long-lived)
- Access token expires after 30 minutes → client uses refresh token to get a new one
- Refresh token expires after 30 days → user must log in again
- Max 5 concurrent sessions per user — the 6th login revokes the oldest session
- Every refresh replaces the refresh token. Presenting a replaced token again is treated as theft,
  and every session of that account is revoked.

- Of two refreshes presenting the same token at the same moment, only one replaces it. A replaced
  token that arrives within 10 seconds is treated as a second tab of the same browser: it gets an
  access token and no new refresh token, and the event is logged. After that it counts as theft
  (`FLINTBAY_SESSION_REFRESH_REUSE_GRACE_SECONDS`, `0` disables the grace). Before 0.1.7 both
  refreshes succeeded and the theft check did not see it.

### Cookie Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_PUBLIC_URL` | `http://localhost:19580` | External origin; HTTPS derives secure cookies |
| `FLINTBAY_COOKIE_SECURE` | derived | `true` for HTTPS `FLINTBAY_PUBLIC_URL`, otherwise `false` |
| `FLINTBAY_COOKIE_SAMESITE` | `strict` | SameSite attribute |
| `FLINTBAY_COOKIE_DOMAIN` | *(auto)* | Cookie domain |

> Set `FLINTBAY_PUBLIC_URL` to the real HTTPS origin in production. Override the
> individual cookie variables only for an exceptional proxy topology.

## Audit Logging

Sign-in events are logged to the audit log:
- Login attempts (success and failure)
- Logout
- Authentication failures

Events that name no account are written to the platform (system) log instead: rate-limit hits,
rejected API keys and expired tokens. Using a valid API key is not audited per request. The key
records `last_used_at` and `last_used_ip` instead.

There are two views of the trail, on the two authorization axes:

- **Sidebar → Administration → Activity** — the complete trail, for the deployment
  administrator. Authentication events, commands and rows whose workspace has since been
  deleted only exist here, because none of them carries a workspace.
- **Sidebar → Monitor → Activity** — one workspace's own history, for anyone with
  `audit_log:view` in it (admin and editor). Scoped to that workspace and limited to what a
  workspace owns: what was created, changed, deleted or commanded. Sign-in events are not
  part of it.

Either can also be queried via API.

| Setting | Default | Description |
|---------|---------|-------------|
| `FLINTBAY_AUDIT_RETENTION_DAYS` | `90` | Days to keep audit entries |
| `FLINTBAY_AUDIT_LOG_SECURITY_EVENTS` | `true` | Log security events |

## Rate Limiting

Every API endpoint is rate-limited, per client IP, with the limit set on the route
rather than globally. Six distinct limits are in use, from most to least
restrictive:

| Limit | Applies to |
|---|---|
| 5/minute | Rotating an API key, creating a workspace, exporting the audit log, purging connection logs |
| 10/minute | Login, creating and deleting an API key |
| 20/minute | Heavier write paths |
| 30/minute | Most writes; push subscribe and unsubscribe; audit-log reads |
| 60/minute | Most reads; telemetry ingest; `POST /api/push-subscription/notify` |
| 120/minute | Binding and widget reads, which a dashboard makes in bursts |

The realtime WebSocket at `/api/realtime/ws/{workspace_id}` is not covered by these
limits — the limiter counts HTTP requests, and a dashboard opens one long-lived
socket rather than polling. Authentication still applies to the socket, so an
unauthenticated client cannot hold one open.

Exceeding a limit returns **429** as an RFC 7807 problem document with
`"code": "too_many_requests"`, the same shape as every other failure this API
answers with, and the event is written to the platform log.

No `X-RateLimit-*` headers are sent. The limiter can report remaining quota in
response headers, but that is switched off, so a client cannot see how close it is
to a limit and should treat 429 as the signal to back off.

## Deployment Administrators

Workspace roles answer "what may you do in *this* workspace". A few things belong
to no workspace: the accounts that can sign in, personal access tokens (which reach
every workspace their owner belongs to), and the platform's own event log. Those sit
on a second axis, named in the deployment's environment:

```yaml
environment:
  FLINTBAY_SUPERADMIN_USERNAME: admin
  FLINTBAY_SUPERADMIN_PASSWORD: change-me     # defaults to "admin" — change it
```

| Property | Behaviour |
|----------|-----------|
| Default | `admin` / `admin`, so a fresh deployment is enterable without reading a log. Change the password before exposing it beyond a trusted network |
| Default in use | Startup logs a warning, the boot `lifecycle` entry flags it, and the Users dialog shows a banner — reported only to the administrator's own session, never to other accounts |
| Count | One account. The authority is deployment-wide, so a second holder adds capability to nobody and one more secret to keep |
| Matching | Case-insensitive against `user.username`; empty means nobody administers the deployment |
| Self-healing | Created if absent and reactivated if disabled on every start, so deleting or deactivating it lasts only until the next restart. Setting `FLINTBAY_SUPERADMIN_PASSWORD` to an empty value turns this off. The named account keeps its authority, but its credential is left to you |
| Password | Applied only when the environment value changes. A password set in the interface survives restarts; an upgrade adopts an existing account without resetting it |
| Recovery | Change `FLINTBAY_SUPERADMIN_PASSWORD` and restart. No shell access and no command-line tool are involved |
| Granting | Only by changing the environment. There is no route, so the authority cannot be escalated from inside the product |
| Revoking | Takes effect on the next request, not when the access token expires |
| API keys | Refused on these surfaces even when the key's owner is named |
| Visibility | The boot outcome is written to the system log as a `lifecycle` entry on every start |
| Policy | The environment password is not subject to `FLINTBAY_PASSWORD_MIN_LENGTH` — refusing to boot over it would leave no administrator to fix it with. A short value is reported, not refused |

It is not a bypass: a deployment administrator gains nothing on workspace-scoped
routes and cannot act inside a workspace they are not a member of. They can place
*themselves* into a workspace — explicitly, from the Users dialog, and the grant is
audited like any other. What they cannot do is read a workspace's data without a
membership that says so, which is what keeps the audit trail meaning what it says.

Two account changes are refused because nothing inside the product could undo them:
deactivating or deleting your own account, and doing either to the account named in
`FLINTBAY_SUPERADMIN_USERNAME` — that name lives in the environment, which the
application cannot edit. The guard is a courtesy rather than the real protection:
the next restart recreates the account regardless.
