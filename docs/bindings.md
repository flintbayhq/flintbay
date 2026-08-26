# Bindings — Connecting Widgets to Data

Bindings are the core mechanism that connects your UI widgets to live device data. A binding links a widget port to an endpoint, defining how data flows between your dashboard and your hardware.

## Architecture

```
Source → Endpoint → Binding Group → Binding Mapping → Widget Port
                                         ↕
                                    Transform (optional)
```

## Binding Groups

A binding group connects **one endpoint** to **one or more widget ports**. It defines the overall direction of data flow.

### Directions

| Direction | Data Flow | Use Case |
|-----------|-----------|----------|
| **in** | Endpoint → Widget | Display sensor readings, status |
| **out** | Widget → Endpoint | Send commands, set values |
| **bidir** | Both directions | Control + feedback (e.g., slider that shows current position) |

### Creating a Binding Group

1. Open **Bindings** panel (link icon in sidebar)
2. Click **+ Add Binding Group**
3. Select the endpoint and direction
4. Save, then add mappings inside the group

## Binding Mappings

Each mapping connects a specific **widget port** to a **payload path** within the endpoint's data.

### Payload Path

The payload path extracts a specific value from the endpoint's JSON payload using dot-notation:

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

One binding group can have multiple mappings. This is useful when a single endpoint publishes a JSON object with multiple fields:

```
Endpoint: sensors/esp32 → {"temperature": 23.5, "humidity": 45.2}

Binding Group: "ESP32 Readings" (direction: in)
├── Mapping 1: WGauge (temp)    → port: value → path: temperature
├── Mapping 2: WGauge (humid)   → port: value → path: humidity
└── Mapping 3: WChart (history) → port: value → path: temperature
```

## Endpoint Configuration

### history_size — Time-Series Buffer

Set `history_size` in endpoint config to enable server-side ring-buffer storage. This is essential for chart widgets.

```json
{"history_size": 60}
```

**What it does:**
- Stores the last N payloads in a Redis ring-buffer
- New clients receive **backfill** on subscribe (chart immediately shows history)
- Endpoint runs at full speed (ignores demand-aware throttling)
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

**ROS2 endpoints:**
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

## Demand-Aware Polling

Flintbay is smart about resource usage. When no one is viewing a dashboard:

- **MQTT/WebSocket/ROS2** connectors suspend subscriptions — no messages processed
- **REST** endpoints stop polling entirely
- When a user opens the page, connectors resume instantly

**Override:** Endpoints with `history_size > 0` always run at full speed (they need to collect data even when no one is watching).

**Keep subscriptions active at zero demand:**
```yaml
environment:
  FLINTBAY_MQTT_BACKGROUND_ENABLED: "on"   # Keep MQTT subscribed
  FLINTBAY_WS_BACKGROUND_ENABLED: "on"     # Keep WebSocket subscribed
  FLINTBAY_ROS2_BACKGROUND_ENABLED: "on"   # Keep ROS2 subscribed
```

The default `edge` profile uses `off` and suspends these subscriptions until a
browser needs them. The `balanced` profile uses `on`. Endpoints with
`history_size > 0` remain active in either profile.

## Outbound Bindings (Commands)

For `out` and `bidir` bindings, widget events are sent to the endpoint.

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

For outbound bindings with multiple mappings, the system builds a JSON payload from all port values:

```
Widget: WJoystick → port "position" = {x: 0.5, y: -0.3}

Binding Mapping:
  port: position.x → payload_path: linear.x
  port: position.y → payload_path: angular.z

Result payload sent to endpoint:
  {"linear": {"x": 0.5}, "angular": {"z": -0.3}}
```

## ACK-Confirmed Commands

For critical operations, enable ACK to confirm your hardware actually executed the command.

### ACK Modes

| Mode | Widget Behavior |
|------|-----------------|
| **fire** | Send and forget — widget resets immediately |
| **ack** | Widget shows "pending" until device confirms |
| **submit** | User must confirm before sending |

### How ACK Works

```
User clicks button
    → Widget enters PENDING state (spinner, disabled)
    → Command sent to endpoint
    → Device processes command
    → Device publishes new state
    → Flintbay matches state to expected value
    → Widget enters CONFIRMED state (green flash)
    → Widget returns to IDLE
```

If the device doesn't confirm within the timeout:
```
    → Widget enters FAILED state (red flash)
    → Widget returns to IDLE (re-enabled)
```

### ACK Types

- **Transport ACK**: Endpoint accepted the message (HTTP 2xx, MQTT PUBACK)
- **Execution ACK**: Device state actually matches expected value (state_match)

Configure in widget parameters under `submit_mode` group.

## Transforms on Bindings

Each mapping can have a transform applied. See [Data Transforms](./transforms.md) for the full list.

Transforms are applied **per-mapping**, so different widgets bound to the same endpoint can show different scales:

```
Endpoint: motor/speed → raw value 0–4095

Mapping 1: WGauge (RPM)     → transform: map_range [0,4095] → [0,3000]
Mapping 2: WProgressBar (%) → transform: map_range [0,4095] → [0,100]
```

## Tips

- **One endpoint, many widgets**: Use multiple mappings in one binding group
- **Same widget, multiple endpoints**: Create separate binding groups for each endpoint
- **Charts need history**: Always set `history_size` on endpoints feeding WChart/WSparkline
- **Joystick → ROS2**: Use `throttle` policy to limit message rate, `deadzone` transform to eliminate drift
- **Toggle feedback**: Use `bidir` direction so the switch reflects actual device state, not just what you clicked
- **Debugging**: Use the endpoint's "Last Payload" viewer to see what data is arriving, then set your payload_path accordingly
