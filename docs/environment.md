# Environment variables

This page documents the supported environment contract for the Flintbay all-in-one
image. The image contains the API, Web UI, Caddy, MCP, PostgreSQL, and Redis.
PostgreSQL and Redis are embedded by default and can be replaced independently.

## Contract and precedence

- Public all-in-one runtime settings use `FLINTBAY_*` and are passed through Docker
  `environment:`, `docker run -e`, or an orchestrator secret.
- `WEB_PORT` in this repository's Compose file is only a host-side Compose
  input. It is not passed into the container.
- `MEDIA_PORT` is a Compose input too, but unlike `WEB_PORT` it is also passed
  in as `FLINTBAY_MEDIA_WEBRTC_PORT`, because the container advertises its own media
  port number in ICE candidates and the two must agree.
- Generic `POSTGRES_*` and `MCP_*` names are internal child-process adapters,
  not supported all-in-one overrides.
- Explicit container values override resource-profile defaults, which override
  application defaults.
- Changing container environment requires recreation (`docker compose up -d`),
  not only `docker restart`.

The image starts with zero required configuration. Embedded services, metrics,
and MCP are enabled; secrets are generated and persisted in `/var/lib/flintbay`.

## Recommended deployment baseline

```yaml
services:
  flintbay:
    image: ghcr.io/flintbayhq/server:latest
    ports:
      - "${WEB_PORT:-19580}:19580"
      - "${MEDIA_PORT:-8189}:${MEDIA_PORT:-8189}/udp"
      - "${MEDIA_PORT:-8189}:${MEDIA_PORT:-8189}/tcp"
    volumes:
      - flintbay_data:/var/lib/flintbay
    environment:
      FLINTBAY_PUBLIC_URL: "https://flintbay.example.com"
      FLINTBAY_RESOURCE_PROFILE: "edge"
      FLINTBAY_API_WORKERS: "1"
      FLINTBAY_MEDIA_WEBRTC_PORT: "${MEDIA_PORT:-8189}"
    restart: unless-stopped

volumes:
  flintbay_data:
```

For localhost HTTP, `FLINTBAY_PUBLIC_URL` defaults to `http://localhost:19580`. Set
it to the real HTTPS origin whenever users access Flintbay through another host.
The value must be an `http://` or `https://` origin without credentials, path,
query, or fragment.

## Common operator settings

| Variable | Default | Purpose |
|---|---|---|
| `FLINTBAY_PUBLIC_URL` | `http://localhost:19580` | External origin; derives CORS, cookie security, and MCP metadata. |
| `FLINTBAY_RESOURCE_PROFILE` | `edge` | `edge` or `balanced`; explicit individual settings win. |
| `FLINTBAY_API_WORKERS` | `1` | Keep `1`; connector/cache/live-reload state is process-local. |
| `FLINTBAY_POSTGRES_PASSWORD` | generated | Embedded PostgreSQL password, persisted in the data volume. |
| `FLINTBAY_REDIS_PASSWORD` | generated | Embedded Redis password, persisted in the data volume. |
| `FLINTBAY_JWT_SECRET_KEY` | generated | Persisted JWT signing key; explicit production values must be at least 32 bytes. |
| `FLINTBAY_SUPERADMIN_USERNAME` | `admin` | The single account that administers the deployment: API keys, the platform event log, account management and workspace access. Empty means nobody, and those surfaces answer 403 to everyone. See [Security](security.md#deployment-administrators). |
| `FLINTBAY_SUPERADMIN_PASSWORD` | `admin` | Password for that account. Created if absent and reactivated if disabled on every start; the password itself is applied only when this value changes, so one set in the interface survives restarts. Changing it and restarting is the supported recovery path. **Change it before exposing the deployment.** |
| `FLINTBAY_JWT_PREVIOUS_SECRET_KEY` | empty | Previous JWT key during a bounded rotation window. |
| `FLINTBAY_DATABASE_URL` | empty | External PostgreSQL URL; disables embedded PostgreSQL. |
| `FLINTBAY_REDIS_URL` | generated local URL | Explicit external Redis URL; disables embedded Redis. |
| `FLINTBAY_CORS_ORIGINS` | `FLINTBAY_PUBLIC_URL` | Optional comma-separated override for additional browser origins. |
| `FLINTBAY_COOKIE_SECURE` | derived | `true` for HTTPS `FLINTBAY_PUBLIC_URL`, otherwise `false`; explicit boolean wins. |
| `FLINTBAY_COOKIE_SAMESITE` | `strict` | Cookie SameSite policy. |
| `FLINTBAY_COOKIE_DOMAIN` | empty/request host | Optional cookie-domain override. |
| `FLINTBAY_TRUSTED_PROXIES` | empty | Comma-separated proxy IPs/CIDRs trusted for forwarded client addresses. |
| `FLINTBAY_ALLOW_PRIVATE_HOSTS` | `true` | Allows robot/IoT source URLs on private networks. |
| `FLINTBAY_API_ENABLE_DOCS` | `false` | Enables OpenAPI/Swagger routes in production. |
| `FLINTBAY_LOG_LEVEL` | `WARNING` | API log level. |
| `FLINTBAY_METRICS_ENABLED` | `true` | Enables Prometheus `/metrics`. |
| `FLINTBAY_MCP_ENABLE` | `true` | Enables bundled MCP; `false` saves about 43–44 MiB cgroup RAM. |
| `FLINTBAY_MCP_PUBLIC_URL` | `${FLINTBAY_PUBLIC_URL}/mcp` | Optional public MCP resource URL override. |
| `FLINTBAY_MCP_ISSUER_URL` | `${FLINTBAY_PUBLIC_URL}/api` | Optional MCP authorization-server/API URL override. |
| `FLINTBAY_MCP_LOG_LEVEL` | `INFO` | Bundled MCP log level. |

## Live video

Camera and stream Sources that speak `rtsp://`, `rtmp://` or `srt://` are pulled
once by the image's media gateway and delivered to every viewer as WebRTC, with
automatic LL-HLS fallback. This is enabled by default and needs no
configuration.

WebRTC media is not HTTP and cannot be multiplexed over `19580`, so it uses one
additional published port. Publish it with equal host and container numbers —
the container advertises its own number in ICE candidates — and open it in the
host firewall or cloud security group for remote access. A closed media port is
not an outage: playback falls back to LL-HLS over `19580`, roughly a second
slower.

You can tell which path a stream took by looking at it: when playback is not on
the preferred low-latency transport, the widget shows the active protocol in the
corner of the video. An `HLS` badge on a camera you expected to be live-fast
means the media port is not reachable from that client. The fallback also moves
work onto the API, which authorizes every media segment, so a deployment serving
many viewers over LL-HLS costs noticeably more than the same viewers over WebRTC.

| Variable | Default | Purpose |
|---|---|---|
| `FLINTBAY_MEDIA_WEBRTC_PORT` | `8189` | WebRTC transport port, served as UDP and as ICE-TCP on the same number for networks that block UDP. |
| `FLINTBAY_MEDIA_WEBRTC_HOST` | derived from `FLINTBAY_PUBLIC_URL` | Host advertised in ICE candidates; set it only when the browser reaches media through a different address than the public origin. |
| `FLINTBAY_MEDIA_GATEWAY_ENABLED` | `true` | Set `false` to drop the gateway process; `rtsp://`, `rtmp://` and `srt://` Sources then stop playing. |
| `FLINTBAY_MEDIA_GATEWAY_MAX_READERS` | `8` on `edge`, `32` on `balanced` | Concurrent viewers sharing one upstream pull, per stream. |
| `FLINTBAY_MEDIA_GATEWAY_SOURCE_CLOSE_AFTER` | `10s` | Idle delay before the shared upstream pull is closed. |

Gateway credentials are generated on first boot and persisted in the data
volume; they are not operator inputs. Media routes are authorized per workspace
on every request, and the gateway accepts no publishers. To rotate the
credentials, delete `.mediamtx_control_password` and `.mediamtx_read_password`
from the volume and restart.

Direct browser-playable URLs (HLS, DASH, WHEP, MJPEG) are unaffected and never
pass through the gateway. Legacy `rtsp://` URLs typed straight into a widget
still use the older ffmpeg proxy described in [RTSP proxy](rtsp-proxy.md).

## Resource profiles

The default `edge` profile minimizes idle resource use. `balanced` keeps the
previous always-on connector behavior and raises pool/concurrency limits.

| Override | `edge` | `balanced` |
|---|---:|---:|
| `FLINTBAY_DB_POOL_MIN` / `FLINTBAY_DB_POOL_MAX` | `1` / `5` | `5` / `20` |
| `FLINTBAY_POSTGRES_SHARED_BUFFERS` | `64MB` | `128MB` |
| `FLINTBAY_POSTGRES_MAX_CONNECTIONS` | `20` | `100` |
| `FLINTBAY_POSTGRES_WORK_MEM` | `2MB` | `4MB` |
| `FLINTBAY_POSTGRES_MAINTENANCE_WORK_MEM` | `32MB` | `64MB` |
| `FLINTBAY_POSTGRES_JIT` | `off` | `on` |
| `FLINTBAY_REDIS_MAXMEMORY` | `128mb` | `256mb` |
| `FLINTBAY_REST_BACKGROUND_MIN_POLL_INTERVAL_MS` | `5000` | `1000` |
| `FLINTBAY_MQTT_BACKGROUND_ENABLED` | `off` | `on` |
| `FLINTBAY_WS_BACKGROUND_ENABLED` | `off` | `on` |
| `FLINTBAY_ROS2_BACKGROUND_ENABLED` | `off` | `on` |
| `FLINTBAY_CONNECTOR_SEND_CONCURRENCY` / `FLINTBAY_CONNECTOR_SEND_MAX_WAITERS` | `4` / `16` | `8` / `32` |
| `FLINTBAY_BINDING_PROCESS_CONCURRENCY` / `FLINTBAY_BINDING_PROCESS_MAX_WAITERS` | `2` / `16` | `4` / `32` |
| `FLINTBAY_BINDING_INBOUND_ENDPOINT_CONCURRENCY` / `FLINTBAY_BINDING_INBOUND_QUEUE_SIZE` | `4` / `16` | `8` / `32` |
| `FLINTBAY_REALTIME_OUTBOX_CRITICAL_SIZE` / `FLINTBAY_REALTIME_OUTBOX_STATE_KEYS` | `32` / `64` | `64` / `256` |
| `FLINTBAY_REALTIME_BROADCAST_CONCURRENCY` | `8` | `16` |
| `FLINTBAY_WS_MAX_QUEUE` | `8` | `32` |

With zero UI demand, `edge` suspends MQTT/WebSocket/ROS2 subscriptions and
clamps REST polling. `on` keeps a protocol active at zero demand. Endpoints with
`history_size > 0` remain active in either profile to collect chart history.

`FLINTBAY_BINDING_STATE_BACKEND=redis` can share throttle/debounce state, but it does
not distribute connector caches or runtime CRUD reloads. Keep
`FLINTBAY_API_WORKERS=1` even when using Redis binding state.

## Push, observability, and diagnostics

| Variables | Purpose |
|---|---|
| `FLINTBAY_VAPID_PUBLIC_KEY`, `FLINTBAY_VAPID_PRIVATE_KEY`, `FLINTBAY_VAPID_CONTACT_EMAIL` | Web Push configuration. |
| `FLINTBAY_INTERNAL_API_KEY` | Optional service-to-service key for push notifications. |
| `FLINTBAY_SENTRY_DSN`, `FLINTBAY_SENTRY_ENVIRONMENT`, `FLINTBAY_SENTRY_RELEASE` | Sentry-compatible error reporting. |
| `FLINTBAY_SENTRY_TRACES_SAMPLE_RATE`, `FLINTBAY_SENTRY_PROFILES_SAMPLE_RATE` | Trace/profile sampling fractions, default `0.0`. |
| `FLINTBAY_MEMPROF_ENABLED`, `FLINTBAY_MEMPROF_TOKEN` | Opt-in memory diagnostics; disabled by default. |

See [Push Notifications](push-notifications.md), [Security](security.md), and
the main README's memory-profiling section for details.

## Compatibility aliases

None. Every setting answers to exactly one name.

Four variables were accepted under a second spelling until the rename: three doubled
a word, because the name was derived from a prefix plus a field, and one predated
the `ENDPOINT_STATE_` namespace. The prefix change forced every variable to be
rewritten by hand anyway, so the aliases guarded nothing and were removed. If you
set one, it is ignored rather than honoured, and the setting keeps its default.

Do not use retired developer-template names such as `MCP_ENABLE`, root
`FLINTBAY_API_KEY`, or `VITE_MCP_URL`. They were not production image contracts.
