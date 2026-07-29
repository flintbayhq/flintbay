# Environment variables

This page documents the supported environment contract for the RCH all-in-one
image. The image contains the API, Web UI, Caddy, MCP, PostgreSQL, and Redis.
PostgreSQL and Redis are embedded by default and can be replaced independently.

## Contract and precedence

- Public all-in-one runtime settings use `RCH_*` and are passed through Docker
  `environment:`, `docker run -e`, or an orchestrator secret.
- `WEB_PORT` in this repository's Compose file is only a host-side Compose
  input. It is not passed into the container.
- Generic `POSTGRES_*` and `MCP_*` names are internal child-process adapters,
  not supported all-in-one overrides.
- Explicit container values override resource-profile defaults, which override
  application defaults.
- Changing container environment requires recreation (`docker compose up -d`),
  not only `docker restart`.

The image starts with zero required configuration. Embedded services, metrics,
and MCP are enabled; secrets are generated and persisted in `/var/lib/rch`.

## Recommended deployment baseline

```yaml
services:
  rch:
    image: ghcr.io/kwaadx/rch:latest
    ports:
      - "${WEB_PORT:-19580}:19580"
    volumes:
      - rch_data:/var/lib/rch
    environment:
      RCH_PUBLIC_URL: "https://rch.example.com"
      RCH_RESOURCE_PROFILE: "edge"
      RCH_API_WORKERS: "1"
    restart: unless-stopped

volumes:
  rch_data:
```

For localhost HTTP, `RCH_PUBLIC_URL` defaults to `http://localhost:19580`. Set
it to the real HTTPS origin whenever users access RCH through another host.
The value must be an `http://` or `https://` origin without credentials, path,
query, or fragment.

## Common operator settings

| Variable | Default | Purpose |
|---|---|---|
| `RCH_PUBLIC_URL` | `http://localhost:19580` | External origin; derives CORS, cookie security, and MCP metadata. |
| `RCH_RESOURCE_PROFILE` | `edge` | `edge` or `balanced`; explicit individual settings win. |
| `RCH_API_WORKERS` | `1` | Keep `1`; connector/cache/live-reload state is process-local. |
| `RCH_POSTGRES_PASSWORD` | generated | Embedded PostgreSQL password, persisted in the data volume. |
| `RCH_REDIS_PASSWORD` | generated | Embedded Redis password, persisted in the data volume. |
| `RCH_JWT_SECRET_KEY` | generated | Persisted JWT signing key; explicit production values must be at least 32 bytes. |
| `RCH_SUPERADMIN_USERNAME` | `admin` | The single account that administers the deployment: API keys, the platform event log, account management and workspace access. Empty means nobody, and those surfaces answer 403 to everyone. See [Security](security.md#deployment-administrators). |
| `RCH_SUPERADMIN_PASSWORD` | `admin` | Password for that account. Created if absent and reactivated if disabled on every start; the password itself is applied only when this value changes, so one set in the interface survives restarts. Changing it and restarting is the supported recovery path. **Change it before exposing the deployment.** |
| `RCH_JWT_PREVIOUS_SECRET_KEY` | empty | Previous JWT key during a bounded rotation window. |
| `RCH_DATABASE_URL` | empty | External PostgreSQL URL; disables embedded PostgreSQL. |
| `RCH_REDIS_URL` | generated local URL | Explicit external Redis URL; disables embedded Redis. |
| `RCH_CORS_ORIGINS` | `RCH_PUBLIC_URL` | Optional comma-separated override for additional browser origins. |
| `RCH_COOKIE_SECURE` | derived | `true` for HTTPS `RCH_PUBLIC_URL`, otherwise `false`; explicit boolean wins. |
| `RCH_COOKIE_SAMESITE` | `strict` | Cookie SameSite policy. |
| `RCH_COOKIE_DOMAIN` | empty/request host | Optional cookie-domain override. |
| `RCH_TRUSTED_PROXIES` | empty | Comma-separated proxy IPs/CIDRs trusted for forwarded client addresses. |
| `RCH_ALLOW_PRIVATE_HOSTS` | `true` | Allows robot/IoT source URLs on private networks. |
| `RCH_API_ENABLE_DOCS` | `false` | Enables OpenAPI/Swagger routes in production. |
| `RCH_LOG_LEVEL` | `WARNING` | API log level. |
| `RCH_METRICS_ENABLED` | `true` | Enables Prometheus `/metrics`. |
| `RCH_MCP_ENABLE` | `true` | Enables bundled MCP; `false` saves about 43–44 MiB cgroup RAM. |
| `RCH_MCP_PUBLIC_URL` | `${RCH_PUBLIC_URL}/mcp` | Optional public MCP resource URL override. |
| `RCH_MCP_ISSUER_URL` | `${RCH_PUBLIC_URL}/api` | Optional MCP authorization-server/API URL override. |
| `RCH_MCP_LOG_LEVEL` | `INFO` | Bundled MCP log level. |

## Resource profiles

The default `edge` profile minimizes idle resource use. `balanced` keeps the
previous always-on connector behavior and raises pool/concurrency limits.

| Override | `edge` | `balanced` |
|---|---:|---:|
| `RCH_DB_POOL_MIN` / `RCH_DB_POOL_MAX` | `1` / `5` | `5` / `20` |
| `RCH_POSTGRES_SHARED_BUFFERS` | `64MB` | `128MB` |
| `RCH_POSTGRES_MAX_CONNECTIONS` | `20` | `100` |
| `RCH_POSTGRES_WORK_MEM` | `2MB` | `4MB` |
| `RCH_POSTGRES_MAINTENANCE_WORK_MEM` | `32MB` | `64MB` |
| `RCH_POSTGRES_JIT` | `off` | `on` |
| `RCH_REDIS_MAXMEMORY` | `128mb` | `256mb` |
| `RCH_REST_BACKGROUND_MIN_POLL_INTERVAL_MS` | `5000` | `1000` |
| `RCH_MQTT_BACKGROUND_ENABLED` | `off` | `on` |
| `RCH_WS_BACKGROUND_ENABLED` | `off` | `on` |
| `RCH_ROS2_BACKGROUND_ENABLED` | `off` | `on` |
| `RCH_CONNECTOR_SEND_CONCURRENCY` / `RCH_CONNECTOR_SEND_MAX_WAITERS` | `4` / `16` | `8` / `32` |
| `RCH_BINDING_PROCESS_CONCURRENCY` / `RCH_BINDING_PROCESS_MAX_WAITERS` | `2` / `16` | `4` / `32` |
| `RCH_BINDING_INBOUND_ENDPOINT_CONCURRENCY` / `RCH_BINDING_INBOUND_QUEUE_SIZE` | `4` / `16` | `8` / `32` |
| `RCH_REALTIME_OUTBOX_CRITICAL_SIZE` / `RCH_REALTIME_OUTBOX_STATE_KEYS` | `32` / `64` | `64` / `256` |
| `RCH_REALTIME_BROADCAST_CONCURRENCY` | `8` | `16` |
| `RCH_WS_MAX_QUEUE` | `8` | `32` |

With zero UI demand, `edge` suspends MQTT/WebSocket/ROS2 subscriptions and
clamps REST polling. `on` keeps a protocol active at zero demand. Endpoints with
`history_size > 0` remain active in either profile to collect chart history.

`RCH_BINDING_STATE_BACKEND=redis` can share throttle/debounce state, but it does
not distribute connector caches or runtime CRUD reloads. Keep
`RCH_API_WORKERS=1` even when using Redis binding state.

## Push, observability, and diagnostics

| Variables | Purpose |
|---|---|
| `RCH_VAPID_PUBLIC_KEY`, `RCH_VAPID_PRIVATE_KEY`, `RCH_VAPID_CONTACT_EMAIL` | Web Push configuration. |
| `RCH_INTERNAL_API_KEY` | Optional service-to-service key for push notifications. |
| `RCH_SENTRY_DSN`, `RCH_SENTRY_ENVIRONMENT`, `RCH_SENTRY_RELEASE` | Sentry-compatible error reporting. |
| `RCH_SENTRY_TRACES_SAMPLE_RATE`, `RCH_SENTRY_PROFILES_SAMPLE_RATE` | Trace/profile sampling fractions, default `0.0`. |
| `RCH_MEMPROF_ENABLED`, `RCH_MEMPROF_TOKEN` | Opt-in memory diagnostics; disabled by default. |

See [Push Notifications](push-notifications.md), [Security](security.md), and
the main README's memory-profiling section for details.

## Compatibility aliases

Canonical names win when both forms are present. These legacy names remain
accepted for existing deployments:

| Legacy | Canonical |
|---|---|
| `RCH_SESSION_CLEANUP_CLEANUP_INTERVAL_SECONDS` | `RCH_SESSION_CLEANUP_INTERVAL_SECONDS` |
| `RCH_SOURCE_HEALTH_HEALTH_CHECK_INTERVAL_SECONDS` | `RCH_SOURCE_HEALTH_CHECK_INTERVAL_SECONDS` |
| `RCH_SOURCE_HEALTH_HEALTH_CHECK_TIMEOUT_SECONDS` | `RCH_SOURCE_HEALTH_CHECK_TIMEOUT_SECONDS` |
| `RCH_STALE_THRESHOLD_S` | `RCH_ENDPOINT_STATE_STALE_THRESHOLD_S` |

Do not use retired developer-template names such as `MCP_ENABLE`, root
`RCH_API_KEY`, or `VITE_MCP_URL`. They were not production image contracts.
