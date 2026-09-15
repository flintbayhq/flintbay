# Bindings — Connecting Widgets to Data

A connection carries data between an endpoint field and a widget port. For the ordinary path, use
Connection Studio: pick the field in **Data**, pick the port in **Widgets**, and choose **Connect**.
Flintbay creates or reuses the underlying Binding Group and Mapping for you.

## Connect a Field to a Port

1. Open the dashboard page that contains the widget, then open **Connection Studio**.
2. In **Data**, expand a Source and Endpoint and select the field you want to use.
3. In **Widgets**, expand the widget and select its destination port.
4. Review the proposed direction and choose **Connect**.

Connection Studio can also start from the widget port and then ask for a field. When you expand a
readable Endpoint with no stored payload, Connection Studio starts a short preview and waits for its
first frame. Publish or fetch a sample while that Endpoint is expanded; its nested JSON fields appear
as soon as the frame arrives. If the preview times out or the connector fails, use the Endpoint's
refresh action to try again.

For example, after an Endpoint observes `{"temperature": 23.5}`, connect its `temperature` field to
a Gauge's `value` port. Advanced editors remain available when you need to control grouping,
payload paths, transforms, triggers, delivery policy, history, or acknowledgement.

## Architecture

```
Source → Endpoint → Binding Group → Binding Mapping → Widget Port
                                         ↕
                                    Transform (optional)
```

## Binding Groups

A binding group connects **one endpoint** to **one or more widget ports**. It defines the overall
direction of data flow. Connection Studio creates or reuses a suitable group for a normal
field-to-port connection; edit the group directly for advanced behavior.

### Directions

| Direction | Data Flow | Use Case |
|-----------|-----------|----------|
| **in** | Endpoint → Widget | Display sensor readings, status |
| **out** | Widget → Endpoint | Send commands, set values |
| **bidir** | Both directions | Control + feedback (e.g., slider that shows current position) |

### Advanced Group Editing

Use the Binding Group editor when the automatic Connection Studio path is not enough. Select the
endpoint and direction, configure policy or trigger behavior, then add or edit its Mappings. This is
an advanced configuration surface, not a prerequisite for connecting one observed field to one port.

## Binding Mappings

Each Mapping connects a specific **widget port** to a **payload path** within the Endpoint's data.

### Payload Path

The payload path extracts a specific value from the Endpoint's JSON payload using dot notation:

| Payload | Path | Extracted Value |
|---------|------|-----------------|
| `23.5` | *(empty)* | `23.5` |
| `{"temperature": 23.5}` | `temperature` | `23.5` |
| `{"data": {"sensors": [{"temp": 23.5}]}}` | `data.sensors.0.temp` | `23.5` |
| `{"x": 0.5, "y": -0.3}` | `x` | `0.5` |

- Leave path **empty** to use the entire payload as-is (for raw numeric/string values)
- Use **dot notation** for nested objects: `data.temperature`
- Use **numeric indices** for arrays: `sensors.0.value`

### Multiple Mappings per Group

One Binding Group can have multiple Mappings. This is useful when a single Endpoint publishes a JSON
object with multiple fields:

```
Endpoint: sensors/esp32 → {"temperature": 23.5, "humidity": 45.2}

Binding Group: "ESP32 Readings" (direction: in)
├── Mapping 1: WGauge (temp)    → port: value → path: temperature
├── Mapping 2: WGauge (humid)   → port: value → path: humidity
└── Mapping 3: WChart (history) → port: value → path: temperature
```

## Endpoint Configuration

### history_size — Time-Series Buffer

Set `history_size` in Endpoint config to enable server-side ring-buffer storage. This is essential for
chart widgets.

```json
{"history_size": 60}
```

**What it does:**
- Stores the last N payloads in a Redis ring-buffer
- New clients receive **backfill** on subscribe (chart immediately shows history)
- Keeps the Endpoint collecting at full speed even with no viewer
- Ideal for WChart, WSparkline, WBarChart

**Without history_size:** Charts only show data received after the page loads.
**With history_size: 60:** Charts immediately display the last 60 data points.

### Protocol-Specific Config

**REST endpoints:**
```json
{
  "method": "GET",
  "poll_interval_ms": 3000,
  "response_path": "data"
}
```
- `poll_interval_ms`: How often to poll (100–3600000 ms)
- `response_path`: Extract nested data from HTTP response before processing

**MQTT endpoints:**
```json
{
  "qos": 1,
  "retain": false,
  "payload_format": "json"
}
```

**ROS 2 endpoints:**
```json
{
  "message_type": "geometry_msgs/Twist",
  "queue_size": 10
}
```

**WebSocket endpoints:**
```json
{
  "message_type": "telemetry",
  "message_path": "type"
}
```

## Demand-Aware Activity

Flintbay reduces connector work when no browser is using an Endpoint, but idle behavior depends on
the protocol and deployment configuration:

- **REST** continues polling. With no UI subscriber, its configured interval is clamped to the
  background minimum rather than stopped. The product default minimum is 1000 ms; the public
  all-in-one image's default `edge` profile uses a 5000 ms floor.
- **MQTT, WebSocket, and ROS 2** background subscriptions are configuration-dependent. With their
  background setting `off`, they suspend at zero demand and resume when a browser needs them; with
  it `on`, they stay subscribed. The `edge` profile uses `off`, while `balanced` uses `on`.
- An Endpoint with `history_size > 0` stays active at its configured rate in either profile so it can
  collect time-series backfill.

To keep push subscriptions active at zero demand explicitly:

```yaml
environment:
  FLINTBAY_MQTT_BACKGROUND_ENABLED: "on"   # Keep MQTT subscribed
  FLINTBAY_WS_BACKGROUND_ENABLED: "on"     # Keep WebSocket subscribed
  FLINTBAY_ROS2_BACKGROUND_ENABLED: "on"   # Keep ROS 2 subscribed
```

## Outbound Bindings (Commands)

For `out` and `bidir` bindings, widget events are sent to the Endpoint.

### Trigger Modes

Control **when** a command fires:

| Trigger | Behavior |
|---------|----------|
| **any_change** | Fire when any mapped port changes (default) |
| **all_change** | Fire only when all mapped ports have new values |
| **debounce_all** | Wait for all ports, then debounce before firing |
| **on_ports** | Fire only when specific named ports change |

### Policies

| Policy | Effect |
|--------|--------|
| **throttle** | Limit send rate (e.g., max 10 msgs/sec for joystick) |
| **send_on_change** | Only send if value actually changed |

### Payload Building

For outbound bindings with multiple Mappings, the system builds a JSON payload from all port values:

```
Widget: WJoystick → port "position" = {x: 0.5, y: -0.3}

Binding Mapping:
  port: position.x → payload_path: linear.x
  port: position.y → payload_path: angular.z

Result payload sent to endpoint:
  {"linear": {"x": 0.5}, "angular": {"z": -0.3}}
```

## Acknowledged Commands

Keep two concerns separate: widget interaction controls **when the widget emits a value**, while the
Binding Group's delivery policy controls **how that command is acknowledged**. Widget submit behavior,
described in [Submit Modes](./widgets.md#submit-modes), is not a list of Binding ACK modes.

### Binding ACK Modes

| Mode | Confirmation |
|------|--------------|
| **Transport** | The connector accepted the command, such as a successful HTTP response or accepted connector write. This does not prove the hardware executed it. |
| **Execution** | Later incoming telemetry matched the configured device-state criteria. |

### How Execution Confirmation Works

```
User changes a control
    → Widget emits a value
    → Binding sends the command
    → Connector accepts the write
    → Device publishes new telemetry
    → Flintbay matches the configured state field and expected value
    → Command is confirmed
```

Execution confirmation selects a field path in the incoming state and an expected value. The
expected value may be fixed or reference the value sent from a widget port with `PORT:<port>`.
Configure timeout and the desired failure, revert, and retry behavior in the Binding policy. If no
matching telemetry arrives before the timeout, Flintbay reports failure according to that policy.

A transport-level acknowledgement—including MQTT delivery acknowledgement—only says the transport
or connector accepted the message. It is not evidence that the device carried out the command; use
Execution confirmation when reported hardware state is the required proof.

## Transforms on Bindings

Each Mapping can have a transform applied. See [Data Transforms](./transforms.md) for the full list.

Transforms are applied **per Mapping**, so different widgets connected to the same Endpoint can show
different scales:

```
Endpoint: motor/speed → raw value 0–4095

Mapping 1: WGauge (RPM)     → transform: map_range [0,4095] → [0,3000]
Mapping 2: WProgressBar (%) → transform: map_range [0,4095] → [0,100]
```

## Tips

- **One endpoint, many widgets**: Use multiple Mappings in one Binding Group
- **Same widget, multiple endpoints**: Create separate Binding Groups for each Endpoint
- **Charts need history**: Set `history_size` on Endpoints feeding WChart/WSparkline
- **Joystick → ROS 2**: Use `throttle` policy to limit message rate and a `deadzone` transform to eliminate drift
- **Toggle feedback**: Use `bidir` direction so the switch reflects actual device state, not just what you clicked
- **Debugging**: Expand the Endpoint in **Data** to inspect observed fields before connecting one to a port
