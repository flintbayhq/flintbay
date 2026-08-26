# API Keys

API keys (Personal Access Tokens) let you authenticate with the Flintbay API and MCP server without a browser session. Use them for AI integrations, scripts, and automation.

## Who Can Manage Keys

Key management requires a **deployment administrator** session — the account named in
`FLINTBAY_SUPERADMIN_USERNAME`. A key carries no workspace: it authenticates its owner
and therefore reaches every workspace that owner belongs to, so a workspace-scoped
permission would be a narrower gate than the thing it guards. See
[Security](security.md#deployment-administrators).

Keys also cannot manage keys: these routes require a browser session, which keeps a
leaked key from minting more.

## Creating a Key

1. Sidebar → **Administration** → **API Keys**
2. Click **Create Key**
3. Choose a **name**, **scope preset**, and **expiry**
4. Copy the key immediately — it's shown only once

The key format: `flintbay_pat_<random>` (prefix `flintbay_pat_` identifies it as a Flintbay token).

## Scope Presets

| Preset | What It Can Do | Use Case |
|--------|---------------|----------|
| **read-only** | View screens, pages, widgets, bindings, sources, logs | Monitoring dashboards, read-only integrations |
| **dashboard** | Full CRUD on screens, pages, widgets, bindings, sources, endpoints | AI assistants (MCP), automation scripts |
| **full** | Everything including workspace management, user admin, member management | Admin automation, CI/CD |

### Detailed Scopes

**read-only** includes:
`screen:view`, `page:view`, `widget:view`, `binding:view`, `endpoint:view`, `source:view`, `audit_log:view`, `telemetry:view`, `member:view`

**dashboard** adds:
`screen:create/update/delete`, `page:create/update/delete`, `widget:create/update/delete/interact`, `binding:create/update/delete`, `endpoint:create/update/delete`, `source:create/update/delete`

**full** adds:
`workspace:update/delete`, `audit_log:admin`, `user:admin`, `connection_log:admin`, `member:invite/remove/update_role`, `api_key:manage`

> A key never exceeds its owner: a request through it must pass both the key's scopes **and** the
> owner's role in the workspace it addresses. Scopes narrow, they do not grant.

## Allow Destructive

The `allow_destructive` flag controls whether the key can perform delete operations. Even with `dashboard` scope, a key with `allow_destructive: false` cannot delete screens, pages, or widgets — only create and update.

Default: **false** (safe by default).

## Expiry

| Setting | Value |
|---------|-------|
| Default expiry | 90 days |
| Maximum expiry | 365 days |
| Minimum expiry | 1 day |

Expired keys stop working immediately. Create a new key or rotate before expiry.

## Rate Limits

| Limit | Value |
|-------|-------|
| Requests per key | 600/minute |
| Key creation | 10/minute |
| Key listing | 30/minute |
| Key rotation | 5/minute |

## Using a Key

### HTTP API

```bash
curl http://localhost:19580/api/screens \
  -H "Authorization: Bearer flintbay_pat_..."
```

### MCP Server (AI Integration)

```json
{
  "mcpServers": {
    "flintbay": {
      "url": "http://localhost:19580/mcp",
      "headers": {
        "Authorization": "Bearer flintbay_pat_..."
      }
    }
  }
}
```

### WebSocket

The realtime socket is per workspace, so the workspace ID is part of the path:

```javascript
// Preferred: the token travels in the subprotocol, not the URL.
const ws = new WebSocket(
  `ws://localhost:19580/api/realtime/ws/${workspaceId}`,
  ["access_token", "flintbay_pat_..."],
)
```

The server answers with the `access_token` subprotocol. A URL carrying a token is
written to proxy logs and browser history, which is why this is the default path.

```javascript
// Query string, for local development only.
const ws = new WebSocket(
  `ws://localhost:19580/api/realtime/ws/${workspaceId}?token=flintbay_pat_...`,
)
```

> ⚠️ Query-string token auth is disabled by default. Set `FLINTBAY_REALTIME_ALLOW_QUERY_TOKEN=true` to enable (not recommended for production).

## Key Rotation

Rotate a key to get a new secret while keeping the same name and scopes:

1. Sidebar → **Administration** → **API Keys**
2. Click the rotate icon on the key
3. The old key is immediately revoked
4. Copy the new key

Or via API:
```bash
curl -X POST http://localhost:19580/api/api-keys/{key_id}/rotate \
  -H "Cookie: ..."  # requires web session, not API key
```

## Security Notes

- Keys are stored as bcrypt hashes — the plaintext is never stored
- Key management endpoints require **web session auth** — you cannot use an API key to create/revoke other keys (prevents escalation if a key is compromised)
- Keys track `last_used_at` and `last_used_ip` for auditing
- Revocation is immediate and irreversible
- Max 10 keys per user

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLINTBAY_API_KEY_MAX_KEYS_PER_USER` | `10` | Maximum keys per user |
| `FLINTBAY_API_KEY_DEFAULT_EXPIRY_DAYS` | `90` | Default expiry when not specified |
| `FLINTBAY_API_KEY_MAX_EXPIRY_DAYS` | `365` | Maximum allowed expiry |
| `FLINTBAY_API_KEY_RATE_LIMIT_PER_MINUTE` | `600` | Requests per minute per key |
