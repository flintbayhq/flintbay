# RCH — Realtime Control Hub

**A self-hosted browser control station for robots and connected hardware.**

Put RCH on a Jetson, Raspberry Pi, laptop, or local server. Add live video, a joystick, buttons, setpoints, and telemetry; connect them to ROS 2, MQTT, REST, or WebSocket; then open a browser and control the machine. No separate frontend project required.

**Build the machine, not the control app.** Free to self-host, distributed under the MIT license, and deployed with one Docker command.

🌐 [Live Demo](https://demo.rch.kwaad.cloud) · 🏠 [Website](https://rch.kwaad.cloud) · 💬 [Discord](https://discord.gg/ptCvyXAAnV) · 📝 [Issues](https://github.com/kwaadx/rch/issues)

![RCH Demo](demo.gif)

## From Hardware to a Control Station

A joystick and a video player are easy to prototype. A control station that reconnects, keeps state synchronized, survives long sessions, controls access, and works across devices is a separate software project.

RCH packages that reusable layer:

- **Control + media + telemetry** — joysticks, D-pads, buttons, live streams, gauges, charts, tables, and more in one operator view
- **Runs beside the machine** — AMD64 and ARM64 images for servers, laptops, Jetson, and Raspberry Pi
- **4 protocol connectors** — REST, MQTT, WebSocket, and ROS 2 behind the same widget binding model
- **Visual control-station builder** — arrange 42 reusable widgets for a laptop, tablet, phone, or built-in display
- **Command feedback** — fire-and-forget, transport ACK, or execution confirmation by matching reported state
- **Application plumbing included** — authentication, sessions, workspace RBAC, rate limits, audit logs, reconnect behavior, and persisted layouts
- **AI-assisted configuration (MCP)** — 37 tools for creating sources, endpoints, widgets, and bindings from supported AI clients
- **Local-first** — no cloud service, subscription, or telemetry required

## What You Can Build

**Robot or rover cockpit** — Put a camera, joystick, battery, connection state, and drive controls in one browser view.

**R&D or hardware test bench** — Reuse a panel for actuators, sensors, setpoints, logs, and live measurements instead of writing another throwaway UI.

**Robotics lab interface** — Give a TurtleBot, Jetson project, or classroom robot a control surface that opens on existing laptops and tablets.

**Connected-device controller** — Use the same widgets for lighting, irrigation, home-built automation, or anything exposed through REST, MQTT, or WebSocket.

> RCH is an application-level control interface, not a functional-safety system. Hardware interlocks, watchdogs, command timeouts, and emergency stops belong in the machine or lower-level controller.

## Quick Start

```yaml
# docker-compose.yml
services:
  rch:
    image: ghcr.io/kwaadx/rch:latest        # amd64 (Intel/AMD)
    ports:
      - "19580:19580"
    volumes:
      - rch_data:/var/lib/rch
    environment:
      # Keep localhost for local HTTP; use the real HTTPS origin when remote.
      RCH_PUBLIC_URL: "http://localhost:19580"
    restart: unless-stopped

volumes:
  rch_data:
```

### Platform Images

| Architecture | Image Tag | Devices |
|---|---|---|
| **amd64** (x86_64) | `ghcr.io/kwaadx/rch:latest` | Desktop, server, cloud VMs |
| **arm64** (aarch64) | `ghcr.io/kwaadx/rch:latest-arm64` | Jetson Orin/Nano, Raspberry Pi 4/5 |

> Architecture tags are published independently. Before an ARM64 upgrade,
> verify that the selected tag/release matches the version you intend to run;
> do not assume `latest-arm64` has the same digest or publication time as
> `latest`.

```bash
docker compose up -d
```

Open **http://localhost:19580** — done.

Data is stored in the `rch_data` volume and survives container restarts and image updates.

> Or clone this repo for a ready-made setup:
> ```bash
> git clone https://github.com/kwaadx/rch.git
> cd rch && docker compose up -d
> ```

## Concepts

- **Workspace** — isolated project environment; all resources belong to a workspace
- **Screen** → **Page** → **Widget** — UI hierarchy; screens contain pages, pages contain widgets
- **Widget** — UI control (button, joystick, slider, gauge, video, chart, etc.)
- **Source** → **Endpoint** — device connection; source is the transport (REST / MQTT / ROS 2 / WebSocket), endpoints are individual channels
- **Binding Group** → **Binding Mapping** — links widgets to endpoints for real-time data flow
- **Roles** — `admin`, `editor`, `operator`, `viewer` — workspace-scoped permissions. Observing a
  connection (`telemetry:view`: logs, health, failures) and configuring it (`source:view`, which
  exposes credentials) are separate rights, which is what lets an operator diagnose without
  reading secrets

## Default Credentials

| User | Password |
|------|----------|
| `admin` | `admin` |

> ⚠️ Change passwords after first login.

## Environment Variables

The all-in-one image accepts supported production overrides through the
`RCH_*` namespace. `RCH_PUBLIC_URL` is the primary networking input: it derives
CORS, secure-cookie behavior, and MCP metadata. Explicit container values win
over resource-profile defaults.

| Variable | Default | Description |
|----------|---------|-------------|
| `RCH_PUBLIC_URL` | `http://localhost:19580` | External origin without a path; set the real HTTPS origin for remote access |
| `RCH_RESOURCE_PROFILE` | `edge` | `edge` or `balanced`; individual overrides win |
| `RCH_API_WORKERS` | `1` | Keep `1`; connector/cache/runtime reload state is process-local |
| `RCH_JWT_SECRET_KEY` | *(generated)* | Persisted signing key; explicit production values need at least 32 bytes |
| `RCH_POSTGRES_PASSWORD` | *(generated)* | Embedded PostgreSQL password, persisted in the volume |
| `RCH_REDIS_PASSWORD` | *(generated)* | Embedded Redis password, persisted in the volume |
| `RCH_DATABASE_URL` | *(empty)* | External PostgreSQL URL; disables embedded PostgreSQL |
| `RCH_REDIS_URL` | *(generated local URL)* | Explicit external Redis URL; disables embedded Redis |
| `RCH_CORS_ORIGINS` | `RCH_PUBLIC_URL` | Optional comma-separated browser-origin override |
| `RCH_COOKIE_SECURE` | *(derived)* | `true` for HTTPS `RCH_PUBLIC_URL`, otherwise `false` |
| `RCH_TRUSTED_PROXIES` | *(empty)* | Trusted reverse-proxy IPs/CIDRs |
| `RCH_ALLOW_PRIVATE_HOSTS` | `true` | Allow private-network robot/IoT source URLs |
| `RCH_API_ENABLE_DOCS` | `false` | Enable Swagger UI at `/api/docs` |
| `RCH_LOG_LEVEL` | `WARNING` | API log level |
| `RCH_METRICS_ENABLED` | `true` | Enable Prometheus `/metrics` |
| `RCH_MCP_ENABLE` | `true` | Enable bundled MCP; disabling saves about 43–44 MiB cgroup RAM |
| `RCH_MCP_PUBLIC_URL` | `${RCH_PUBLIC_URL}/mcp` | Optional public MCP resource URL override |
| `RCH_MCP_ISSUER_URL` | `${RCH_PUBLIC_URL}/api` | Optional MCP issuer/API metadata override |
| `RCH_MCP_LOG_LEVEL` | `INFO` | Bundled MCP log level |

See the complete [environment contract](docs/environment.md) for namespaces,
precedence, edge/balanced profile values, advanced settings, and compatibility
aliases. Generic `POSTGRES_*` and `MCP_*` names are internal adapters, not
all-in-one image inputs.

## Monitoring (Prometheus)

RCH exposes a `/metrics` endpoint in Prometheus format on the internal API port (19500). It is **not** exposed publicly — only accessible from within the Docker network.

To scrape metrics from a Prometheus/Grafana stack running in the same Docker network:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: rch
    static_configs:
      - targets: ['rch:19500']
    metrics_path: /metrics
```

Make sure both containers share a Docker network:

```yaml
services:
  rch:
    image: ghcr.io/kwaadx/rch:latest
    networks: [monitoring]
  prometheus:
    image: prom/prometheus
    networks: [monitoring]

networks:
  monitoring:
```

**Available metrics:**
- `rch_realtime_connections_active` — active WebSocket connections
- `rch_realtime_messages_total` — WS messages by direction and type
- `rch_realtime_pipeline_phase_duration_seconds` — latency by bounded realtime phase and outcome
- `rch_realtime_backpressure_events_total` — queue, rejection, coalescing, timeout, and disconnect decisions
- `rch_realtime_backpressure_depth` — aggregate active and pending realtime work
- `rch_source_connector_state` — connector status (1 = connected, 0 = down)
- `rch_auth_login_attempts_total` — login attempts by outcome
- `http_requests_total` — HTTP requests by handler, method, status
- `http_request_duration_seconds` — request latency histogram

Set `RCH_METRICS_ENABLED=false` to disable the endpoint entirely.

## Memory Profiling

RCH ships with an **opt-in** memory profiler for diagnosing slow memory growth
on long-running or resource-constrained deployments (e.g. an edge box). It is
**completely inert unless enabled** — when off, it adds no overhead and exposes
no routes, so it is safe to leave in the production image.

Enable it by setting two environment variables and restarting the container:

| Variable | Default | Description |
|----------|---------|-------------|
| `RCH_MEMPROF_ENABLED` | `false` | `true` / `1` to turn the profiler on |
| `RCH_MEMPROF_TOKEN` | — | Shared secret; required to reach the debug routes in production |

Optional tuning (sensible defaults — change only if needed):

| Variable | Default | Description |
|----------|---------|-------------|
| `RCH_MEMPROF_INTERVAL_S` | `300` | Seconds between automatic samples |
| `RCH_MEMPROF_SINKS` | `stdout,redis` | Where samples are written: `stdout`, `redis`, `file` |
| `RCH_MEMPROF_TOP_N` | `25` | Number of top allocation sites reported |
| `RCH_MEMPROF_HISTORY` | `50` | Recent samples kept in memory for the `/history` route |

Once enabled, the profiler samples periodically (process RSS, GC stats,
internal structure sizes, hot-path activity counters, and top allocation
sites). Read the data via:

| Route | Purpose |
|-------|---------|
| `GET /api/debug/memory/status` | Profiler state + configuration at a glance |
| `GET /api/debug/memory/snapshot` | Take a sample immediately |
| `GET /api/debug/memory/history?limit=N` | Recent samples (newest last) |
| `GET /api/debug/memory/redis?limit=N` | Dump the persisted Redis sample list |
| `GET /api/debug/memory/reset-baseline` | Re-anchor growth tracking to *now* (call after warm-up) |

All routes require `?token=<RCH_MEMPROF_TOKEN>` when a token is configured
(mandatory in production; in `dev`/`test` mode the routes are open if no token
is set).

```bash
# enable in the container env, then restart
RCH_MEMPROF_ENABLED=1
RCH_MEMPROF_TOKEN=<your-secret>

# after warm-up, re-anchor and then watch the trend
curl "http://localhost:19580/api/debug/memory/reset-baseline?token=<your-secret>"
curl "http://localhost:19580/api/debug/memory/history?token=<your-secret>&limit=30"
```

> **Note:** the profiler uses Python's `tracemalloc`, which adds measurable CPU
> overhead while enabled. Use it to diagnose an issue, then set
> `RCH_MEMPROF_ENABLED=0` and restart for full performance in steady state.

## AI Integration (MCP)

RCH ships with a built-in [MCP server](https://modelcontextprotocol.io/) — no separate install, no extra process to run. Generate a key in the UI and paste the config into your AI tool.

**Supported clients:** Kiro CLI, Claude Code, Claude Desktop, Cursor, Windsurf, Continue.dev, VS Code (Copilot Chat).

### Three steps

**1. Generate an API key**

Sidebar → **Administration** → **API Keys** → **Create Key**. Pick a scope (`Dashboard Management` is a good default) and copy the key. It's shown only once.

**2. Paste the config**

The Create Key dialog shows ready-made snippets for every supported client. For Kiro / Cursor / Windsurf / Continue.dev:

```json
{
  "mcpServers": {
    "rch": {
      "url": "http://localhost:19580/mcp",
      "headers": {
        "Authorization": "Bearer rch_pat_..."
      }
    }
  }
}
```

For Claude Code:

```bash
claude mcp add --transport http rch http://localhost:19580/mcp \
  --header "Authorization: Bearer rch_pat_..."
```

For Claude Desktop (uses the [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) shim since Desktop is stdio-only):

```json
{
  "mcpServers": {
    "rch": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:19580/mcp",
        "--header",
        "Authorization:Bearer rch_pat_..."
      ]
    }
  }
}
```

**3. Ask**

> *"Create a temperature gauge bound to my MQTT topic `sensors/temp` on broker `mqtt://192.168.1.100`."*

The AI handles widget creation, source setup, and bindings automatically.

**37 tools** cover workspaces, widgets, sources/endpoints, bindings, payload discovery, and monitoring.

Set `RCH_MCP_ENABLE=false` in `docker-compose.yml` to disable the bundled MCP server.

## Backup & Restore

Create a backup (PostgreSQL dump + Redis snapshot):

```bash
docker exec rch /usr/local/bin/backup.sh
```

Backups are saved to `/var/lib/rch/backups/` (inside the data volume). Old backups are auto-pruned after 7 days.

To restore from a backup:

```bash
docker exec rch bash -c 'gunzip -c /var/lib/rch/backups/pg_YYYYMMDD_HHMMSS.sql.gz | \
  PGPASSWORD=$(cat /var/lib/rch/.postgres_password) \
  /usr/lib/postgresql/17/bin/psql -h localhost -U rch -d rch'
```

## Deployment Administration

Some things belong to the deployment rather than to a workspace: the accounts that
can sign in, the personal access tokens that reach every workspace their owner
belongs to, and the platform's own event log. Workspace roles cannot govern them —
an administrator of one workspace has no claim on accounts or events that concern
the others.

Name the account that administers the deployment, and give it a password:

```yaml
environment:
  RCH_SUPERADMIN_USERNAME: admin
  RCH_SUPERADMIN_PASSWORD: change-me     # defaults to "admin" — change it
```

Both default, so a fresh deployment can be signed into as `admin` / `admin`
without reading anything first. **Change the password before exposing the
deployment beyond a trusted network**: while the default is in force, startup logs
a warning and the Users dialog shows a banner.

The account is reconciled with the environment on every start. It is created if
absent and reactivated if disabled, so deleting or deactivating it survives no
further than the next restart. The password is applied only when the environment
value *changes* — an administrator who sets their own password in the interface
keeps it across restarts, and an upgrade adopts an existing account without
resetting its credential.

That is also the recovery path. Lost the password? Change
`RCH_SUPERADMIN_PASSWORD`, restart, sign in. No shell, and no command-line tool to
learn.

One account, not a list. Everything the authority unlocks is deployment-wide, so a
second holder adds no capability — only a second secret to keep. Teams are served
by the other axis, where four roles divide work per workspace.

There is deliberately no way to grant this from inside the product. Controlling
the deployment *is* the authority, so it lives in the deployment's configuration.
Leave `RCH_SUPERADMIN_USERNAME` empty and nobody administers the deployment: the
surfaces below answer 403 to everyone.

A deployment administrator gets three extra buttons in the sidebar:

| Button | What it covers |
|--------|----------------|
| **API Keys** | Create, rotate and revoke personal access tokens |
| **System Log** | Platform events: rejected content-security policies, rate-limit hits, rejected API keys and expired tokens, scheduler runs, lifecycle changes |
| **Users** | Create accounts, rename, activate/deactivate, reset passwords, delete, and grant workspace access |

The audit trail is on the same footing: **Information → Activity** shows who signed
in, who failed to, and who changed what, and the tab is absent without deployment
authority. Failed sign-ins are recorded there rather than in the platform log,
because an attempt claims an identity from an address — the platform log keeps the
rejections that name nobody, such as an invalid API key.

Two changes are refused, because nothing inside the product could undo them:
deactivating or deleting your own account, and doing either to the account named in
`RCH_SUPERADMIN_USERNAME`.

Creating an account grants no access on its own. Give it a workspace from the same
Users dialog — pick a role per workspace — or let a workspace administrator invite
it, see [Workspace Sharing](docs/workspace-sharing.md). Either way the grant is
explicit and recorded in the audit trail; what differs is only who may make it.

API key management requires a browser session: keys cannot manage keys, and they
cannot reach any of these three surfaces even when their owner is named above.

## User Management

Accounts are managed entirely from the web interface, above — creating,
renaming, resetting passwords, activating, deactivating, deleting, and granting
workspace access. The Users dialog is visible only to the deployment administrator.

There is no command-line equivalent, by design: a second implementation of the
same rules would be a second place for them to drift.

## Supported Languages

Arabic, Chinese (Simplified), English, French, German, Hindi, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Spanish, Ukrainian.

Change language in the sidebar → your name (bottom of the sidebar) → **User Settings**.

## Documentation

- [Environment Variables](docs/environment.md) — production namespaces, precedence, profiles, and operator settings
- [Getting Started](docs/getting-started.md) — zero to live data in 10 minutes
- [Widget Catalog](docs/widgets.md) — all 42 widget types with ports
- [Bindings Guide](docs/bindings.md) — connecting widgets to data (directions, payload_path, history, ACK)
- [Data Transforms](docs/transforms.md) — scale, map, filter incoming data
- [API Keys](docs/api-keys.md) — scopes, creation, rotation
- [Workspace Sharing](docs/workspace-sharing.md) — invite members, assign roles
- [RTSP Stream Proxy](docs/rtsp-proxy.md) — view IP cameras in the browser
- [Realtime Performance Verification](docs/realtime-performance.md) — reproducible load, saturation, fan-out, and soak results
- [Security](docs/security.md) — lockout, password policy, JWT rotation
- [Upgrading](docs/upgrading.md) — how to update to a new version
- [Reverse Proxy](docs/reverse-proxy.md) — HTTPS with Caddy/Nginx/Traefik
- [Push Notifications](docs/push-notifications.md) — alerts when you're away
- **Examples:** [MQTT + ESP32](docs/examples/mqtt-temperature.md) · [ROS2 TurtleBot](docs/examples/ros2-turtlebot.md) · [REST Polling](docs/examples/rest-api-polling.md)

## License

MIT — free for personal and commercial use.

> RCH is actively developed by a solo developer. Feedback and ideas are welcome — open an issue or start a discussion.
> For custom widget development — [let's talk](https://rch.kwaad.cloud/).
