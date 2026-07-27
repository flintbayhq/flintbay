# Security Configuration

RCH includes several security features that are enabled by default. This page covers account lockout, password policy, JWT key rotation, and session management.

## Account Lockout

Protects against brute-force login attempts.

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_LOCKOUT_ENABLED` | `true` | Enable/disable lockout |
| `RCH_LOCKOUT_MAX_ATTEMPTS` | `5` | Failed attempts before lockout |
| `RCH_LOCKOUT_DURATION_MINUTES` | `15` | How long the account is locked |

After 5 failed login attempts, the account is locked for 15 minutes. The lockout is per-account, not per-IP.

> **Tip:** If you lock yourself out, wait 15 minutes. A deployment administrator can
> reset another account's password from **Sidebar → Users**; if nobody can sign in at
> all, use the CLI:
> ```bash
> docker exec -it -w /app/api rch /opt/rch-api/bin/python -m src.cli reset-password
> ```

## Password Policy

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_PASSWORD_MIN_LENGTH` | `8` | Minimum password length |
| `RCH_PASSWORD_MAX_LENGTH` | `72` | Maximum length (bcrypt limit) |

Passwords are hashed with bcrypt. The 72-character limit is a bcrypt constraint — characters beyond 72 are silently ignored by the algorithm.

## JWT Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_JWT_SECRET_KEY` | *(auto-generated)* | Signing key for access tokens |
| `RCH_JWT_TOKEN_EXPIRE_MINUTES` | `30` | Access token lifetime |
| `RCH_JWT_ALGORITHM` | `HS256` | Signing algorithm |

### Auto-Generated Secret

On first run, RCH generates a random JWT secret and persists it in the data volume at `/var/lib/rch/.jwt_secret`. This survives container restarts and image updates.

### Key Rotation

To rotate the JWT signing key without invalidating all active sessions:

1. Set `RCH_JWT_PREVIOUS_SECRET_KEY` to the current key
2. Set `RCH_JWT_SECRET_KEY` to the new key
3. Restart the container
4. Wait for `token_expire_minutes` (30 min by default) — old tokens expire naturally
5. Remove `RCH_JWT_PREVIOUS_SECRET_KEY`

During the transition window, RCH accepts tokens signed with either key.

## Session Management

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_SESSION_MAX_CONCURRENT` | `5` | Max active sessions per user |
| `RCH_SESSION_REFRESH_TOKEN_EXPIRE_DAYS` | `30` | Refresh token lifetime |
| `RCH_SESSION_REVOKE_OLD_ON_MAX` | `true` | Auto-revoke oldest session when limit reached |

### How Sessions Work

- Login creates a session with an access token (short-lived) and refresh token (long-lived)
- Access token expires after 30 minutes → client uses refresh token to get a new one
- Refresh token expires after 30 days → user must log in again
- Max 5 concurrent sessions per user — the 6th login revokes the oldest session

### Cookie Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_PUBLIC_URL` | `http://localhost:19580` | External origin; HTTPS derives secure cookies |
| `RCH_COOKIE_SECURE` | derived | `true` for HTTPS `RCH_PUBLIC_URL`, otherwise `false` |
| `RCH_COOKIE_SAMESITE` | `strict` | SameSite attribute |
| `RCH_COOKIE_DOMAIN` | *(auto)* | Cookie domain |

> Set `RCH_PUBLIC_URL` to the real HTTPS origin in production. Override the
> individual cookie variables only for an exceptional proxy topology.

## Audit Logging

All security events are logged to the audit log:
- Login attempts (success and failure)
- Logout
- Authentication failures
- Rate limit hits
- API key usage

View audit logs in the sidebar → **Audit Log**, or query via API.

| Setting | Default | Description |
|---------|---------|-------------|
| `RCH_AUDIT_RETENTION_DAYS` | `90` | Days to keep audit entries |
| `RCH_AUDIT_LOG_SECURITY_EVENTS` | `true` | Log security events |

## Rate Limiting

All API endpoints are rate-limited. Limits vary by endpoint sensitivity:

| Endpoint Type | Limit |
|---------------|-------|
| Login | 5/minute |
| API key creation | 10/minute |
| General API (session) | 100/minute |
| General API (key) | 600/minute |
| Push notifications | 60/minute |

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 97
X-RateLimit-Reset: 1716660000
```

## Deployment Administrators

Workspace roles answer "what may you do in *this* workspace". A few things belong
to no workspace: the accounts that can sign in, personal access tokens (which reach
every workspace their owner belongs to), and the platform's own event log. Those sit
on a second axis, named in the deployment's environment:

```yaml
environment:
  RCH_SUPERADMIN_USERNAMES: admin        # comma-separated for several
```

| Property | Behaviour |
|----------|-----------|
| Default | Empty — nobody administers the deployment, and the surfaces answer 403 to everyone |
| Matching | Case-insensitive against `user.username`; an unmatched name grants nothing |
| Granting | Only by changing the environment. There is no route and no CLI command, so the authority cannot be escalated from inside the product |
| Revoking | Takes effect on the next request, not when the access token expires |
| API keys | Refused on these surfaces even when the key's owner is named |
| Visibility | Resolution is written to the system log as a `lifecycle` entry on every start |

It is not a bypass: a deployment administrator gains nothing on workspace-scoped
routes and cannot act inside a workspace they are not a member of, so the audit
trail keeps meaning what it says.

Two account changes are refused because nothing inside the product could undo them:
deactivating or deleting your own account, and doing either to an account named in
`RCH_SUPERADMIN_USERNAMES` — that name lives in the environment, which the
application cannot edit.
