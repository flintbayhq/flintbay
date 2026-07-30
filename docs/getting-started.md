# Getting Started with RCH

Realtime Control Hub — a self-hosted dashboard for robotics and IoT. From zero to live data in 10 minutes.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+

```bash
docker --version
docker compose version
```

## Installation

Create a `docker-compose.yml`:

```yaml
services:
  rch:
    image: ghcr.io/kwaadx/rch:latest
    ports:
      - "19580:19580"
    volumes:
      - rch_data:/var/lib/rch
    environment:
      RCH_PUBLIC_URL: "http://localhost:19580"
    restart: unless-stopped

volumes:
  rch_data:
```

For remote HTTPS access, replace `RCH_PUBLIC_URL` with the exact external
origin. ARM64 users can select `ghcr.io/kwaadx/rch:latest-arm64`, but should
verify that the independently published architecture tag matches the intended
release before upgrading.

Start it:

```bash
docker compose up -d
```

Open **http://localhost:19580** — done.

> Data is stored in the `rch_data` volume and survives container restarts and image updates.

## First Login

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin` |

⚠️ Change the password immediately after first login (Sidebar → **Administration** → **Users** → reset password).

## Create a Workspace

A workspace is an isolated environment — all screens, sources, and bindings live inside one.

1. Click **+ New Workspace** in the sidebar
2. Name it `my-lab`
3. Click **Create**

You're now inside your workspace.

## Add a Data Source

We'll connect to the public Mosquitto MQTT broker as an example.

1. Open **Sources** in the sidebar
2. Click **+ Add Source**
3. Fill in:
   - **Name:** `Test Broker`
   - **Protocol:** MQTT
   - **Host:** `test.mosquitto.org`
   - **Port:** `1883`
4. Click **Save**

The connection indicator turns green when connected.

## Create an Endpoint

An endpoint is a single data channel — for MQTT, that's a topic.

1. Inside your source, click **+ Add Endpoint**
2. Configure:
   - **Name:** `Temperature`
   - **Direction:** In (subscribe)
   - **Topic:** `rch/demo/temperature`
3. Click **Save**

## Build the Dashboard

### Add a Screen and Page

1. Go to **Screens** in the sidebar
2. Click **+ Add Screen**, name it `Monitoring`
3. Inside the screen, a default page is created. Rename it to `Sensors` if you like.

### Place a Widget

1. Open the page in **Edit mode** (pencil icon)
2. Click **+ Add Widget**
3. Choose **WGauge** (under Display category)
4. Configure:
   - **Label:** `Temperature`
   - **Min:** `0`
   - **Max:** `100`
   - **Unit:** `°C`
5. Position and resize as needed

### Create a Binding

Bindings connect widget ports to endpoint data — this is how values flow into your UI.

1. Open the **Bindings** panel (link icon in sidebar)
2. Click **+ Add Binding Group**
3. Configure:
   - **Name:** `Temperature Reading`
   - **Endpoint:** `Test Broker → Temperature`
   - **Direction:** In
4. Click **Save**
5. Add a **Mapping** inside the group:
   - **Widget:** your gauge
   - **Port:** `value`
   - **Payload Path:** leave empty for raw numeric, or `temp` if your payload is `{"temp": 23.5}`

## Test It

Publish a message from any MQTT client:

```bash
# Install: apt install mosquitto-clients (or brew install mosquitto)
mosquitto_pub -h test.mosquitto.org -t "rch/demo/temperature" -m "23.5"
```

Or with JSON payload:

```bash
mosquitto_pub -h test.mosquitto.org -t "rch/demo/temperature" -m '{"temp": 23.5}'
```

The gauge updates in real time. Exit edit mode to see the live dashboard.

## How It All Connects

```
Workspace
├── Screen → Page → Widget (UI)
├── Source → Endpoint (data connection)
└── Binding Group → Mapping (widget port ↔ endpoint)
```

## Next Steps

- [MQTT + ESP32 Example](./examples/mqtt-temperature.md) — full hardware tutorial
- [ROS2 TurtleBot Control](./examples/ros2-turtlebot.md) — joystick + camera
- [REST API Polling](./examples/rest-api-polling.md) — chart with live data
- [Widget Catalog](./widgets.md) — all 42 widget types
- [Data Transforms](./transforms.md) — scale, map, filter incoming data
- [Reverse Proxy Setup](./reverse-proxy.md) — HTTPS with Nginx/Caddy/Traefik
- [Push Notifications](./push-notifications.md) — alerts when you're away
