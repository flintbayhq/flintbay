# Getting Started with Flintbay

Flintbay is a self-hosted browser control station for robotics and connected hardware. This guide
starts with an empty deployment and ends with a live MQTT value on a Gauge.

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
  flintbay:
    image: ghcr.io/flintbayhq/flintbay:latest
    ports:
      - "19580:19580"        # web UI, API, MCP
      - "8189:8189/udp"      # live video (WebRTC)
      - "8189:8189/tcp"      # live video on UDP-blocked networks
    volumes:
      - flintbay_data:/var/lib/flintbay
    environment:
      FLINTBAY_PUBLIC_URL: "http://localhost:19580"
    restart: unless-stopped

volumes:
  flintbay_data:
```

For remote HTTPS access, replace `FLINTBAY_PUBLIC_URL` with the exact external
origin. The tag is one multi-architecture image, so amd64 and arm64 hosts —
including Jetson and Raspberry Pi — pull the same reference and Docker selects
the matching variant.

Port `8189` carries live camera video over WebRTC, which cannot share the HTTP
port. Remote deployments must open it in the firewall or cloud security group
too; if it stays closed, video still plays over `19580` as LL-HLS with about a
second more latency. See [Live video](environment.md#live-video).

Start it:

```bash
docker compose up -d
```

Open **http://localhost:19580** — done.

> Data is stored in the `flintbay_data` volume and survives container restarts and image updates.

## First Login

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `admin` |

⚠️ Change the password immediately: open **Users** in the sidebar, select `admin`, and reset its
password.

## Create the Dashboard

### Create a Workspace

A workspace is an isolated environment — its screens, Sources, widgets, and connections stay separate
from every other workspace.

1. Open the **Workspace** selector's options menu (`⋮`) and choose **Create**.
2. Name the workspace `my-lab` and choose **Create**.

### Create a Screen, Page, and Gauge

1. Open the **Screen** selector's options menu (`⋮`), choose **Create**, and name the screen
   `Monitoring`.
2. Open the **Page** selector's options menu (`⋮`), choose **Create**, and name the page `Sensors`.
3. Open the page in **Edit mode**, choose **Add widget**, and add a **Gauge**.
4. Set its label to `Temperature`, range to `0`–`100`, and unit to `°C`.
5. Keep this page open. Its Gauge will appear in Connection Studio's **Widgets** pane.

## Connect Your First Live Value

We'll use the public Mosquitto MQTT broker and a unique topic so your reading does not collide with
another tutorial user. Choose your own short suffix and use the same topic in the MQTT URI and publish
command; for example, `flintbay/tutorial/alex-a7f3`.

### Add the MQTT Address

1. Open **Connection Studio**.
2. In **Data**, paste the complete URI
   `mqtt://test.mosquitto.org:1883/flintbay/tutorial/alex-a7f3` into **Paste an address, or search**.
   Pasting starts address intake automatically; Enter submits an address that you typed.
3. Review the MQTT Source and Endpoint draft, supply any required details, and choose **Add**.
4. Wait for the new Source and Endpoint to appear in **Data**.
5. Expand the Endpoint. Because it has no stored payload yet, Connection Studio starts a short preview
   and waits for its first message.

### Publish an Observed Field

Install an MQTT client if needed (`apt install mosquitto-clients` or
`brew install mosquitto`), set `TOPIC` to the exact topic in the URI, and publish while the Endpoint is
expanded:

```bash
TOPIC='flintbay/tutorial/alex-a7f3'
mosquitto_pub -h test.mosquitto.org -t "$TOPIC" -m '{"temp": 23.5}'
```

The first payload is stored as the Endpoint's latest snapshot, and the observed `temp` field appears
under it. If the preview times out before the message arrives, choose the Endpoint's refresh action and
publish again. A non-retained MQTT message sent before the preview starts cannot be recovered.

### Connect the Field to the Gauge

1. In **Data**, select the observed `temp` field.
2. In **Widgets**, expand the Gauge and select its `value` port. You may also choose the port first and
   the field second.
3. Review the proposed `temp → Gauge.value` connection and choose **Connect**.
4. Publish the same JSON command again. The Gauge updates to `23.5` in real time.

Exit edit mode to see the live dashboard. Connection Studio creates or reuses the underlying Binding
Group and Mapping; open their advanced editors only when you need policies, transforms, triggers,
history, or acknowledgement behavior.

## How It All Connects

```
Workspace
├── Screen → Page → Widget (UI)
├── Source → Endpoint → observed field (data)
└── Binding Group → Mapping (field ↔ widget port)
```

## Next Steps

- [MQTT + ESP32 Example](./examples/mqtt-temperature.md) — full hardware tutorial
- [ROS 2 TurtleBot Control](./examples/ros2-turtlebot.md) — joystick + camera
- [REST API Polling](./examples/rest-api-polling.md) — chart with live data
- [Widget Catalog](./widgets.md) — all 42 widget types
- [Bindings](./bindings.md) — field-to-port connections and advanced delivery behavior
- [Data Transforms](./transforms.md) — scale, map, filter incoming data
- [Reverse Proxy Setup](./reverse-proxy.md) — HTTPS with Nginx/Caddy/Traefik
- [Push Notifications](./push-notifications.md) — alerts when you're away
