# Example: ROS 2 TurtleBot Control with Joystick + Camera

Control a TurtleBot3, or any ROS 2 robot that takes `geometry_msgs/Twist` on `cmd_vel`, from Flintbay.
The dashboard has a joystick for movement, a live camera, a battery indicator, a speed readout and a
browser stop command.

> **Safety:** The stop widget below only publishes a zero-velocity command through the application stack. It is not a safety-rated emergency stop. Use controller-level watchdogs, motion timeouts, hardware interlocks, and a physical E-stop wherever failure could cause harm.

## Architecture

```
Flintbay Dashboard ↔ rosbridge_server (WebSocket) ↔ ROS 2 Topics
```

Flintbay connects to ROS 2 via [rosbridge_suite](https://github.com/RobotWebTools/rosbridge_suite), which exposes ROS 2 topics over WebSocket.

## Prerequisites

- ROS 2 Humble/Iron/Jazzy with TurtleBot3 packages
- `rosbridge_server` running
- Flintbay instance ([Getting Started](../getting-started.md))
- For the joystick: Flintbay 0.1.7 or later (see [Joystick → /cmd_vel](#joystick--cmd_vel))

## 1. Launch rosbridge

```bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

Default port: `9090`. Verify it's running:
```bash
# Should return a WebSocket handshake
curl -i http://localhost:9090
```

## 2. Flintbay Source Configuration

1. **Sources** → **+ Add Source**
2. Configure:
   - **Name:** `TurtleBot`
   - **Protocol:** ROS 2
   - **Bridge URL:** `ws://192.168.1.50:9090` (your rosbridge host)
3. **Save**

**Discover** on the Source lists the robot's topics with their types, if rosbridge was launched
with `rosapi` (the default launch file includes it).

## 3. Create Endpoints

| Name | Direction | Topic | Message Type |
|------|-----------|-------|--------------|
| Velocity Command | Out | `/cmd_vel` | `geometry_msgs/Twist` |
| Battery | In | `/battery_state` | `sensor_msgs/BatteryState` |
| Odometry | In | `/odom` | `nav_msgs/Odometry` |

### Endpoint configs

Message types use the two-part `package/Type` form. `geometry_msgs/msg/Twist` is refused.

**Velocity Command:**
```json
{"message_type": "geometry_msgs/Twist", "queue_size": 1}
```

**Battery:**
```json
{"message_type": "sensor_msgs/BatteryState", "throttle_rate_ms": 500}
```

**Odometry:**
```json
{"message_type": "nav_msgs/Odometry", "throttle_rate_ms": 200}
```

The camera does not need an endpoint; see [Camera Stream](#camera-stream).

## 4. Build the Dashboard

Create screen `TurtleBot Control`, page `Main`.

### Widget Layout

| Widget | Type | Size | Purpose |
|--------|------|------|---------|
| Joystick | WJoystick | 200×200 | Movement control |
| Camera Feed | WStream | 400×300 | Live video |
| Battery | WBattery | 80×120 | Battery level |
| E-Stop | WEmergencyStop | 100×100 | Stop command |
| Speed | WValueDisplay | 120×80 | Current forward speed |

## 5. Create Bindings

### Joystick → /cmd_vel

The joystick's **`twist`** port sends a ready `geometry_msgs/Twist`, so no transform is needed:

- stick up drives forward (`linear.x` up to **Max Linear Speed**, m/s)
- stick down reverses
- stick right turns right, stick left turns left (`angular.z` up to **Max Turn Rate**, rad/s,
  with ROS's sign convention: positive is counter-clockwise)
- releasing the stick sends a zero Twist (with **Return to Center** on, the default). With it off,
  the stick stays where it was left and the robot keeps that speed until you move it back or its
  driver's `cmd_vel` timeout stops it. The same happens when the tab loses focus mid-hold

1. Select the joystick and set **Max Linear Speed** and **Max Turn Rate** to what your robot
   tolerates. A TurtleBot3 Burger tops out at about `0.22` m/s and `2.84` rad/s; start lower.
2. In **Connection Studio**, select the joystick's `twist` port and send it to **Velocity Command**.
   Keep the key the studio proposes (`twist`). A `twist` port bound under its own name, or with no
   payload path, is sent as the whole message, not as `{"twist": …}`.

Or, in the Binding Group editor: endpoint `Velocity Command`, direction Out, one mapping from the
joystick's `twist` port with an empty payload path.

The joystick's own settings still apply before the conversion: **Dead Zone** stops drift, **Expo
Curve** softens small movements, **Rate** scales everything down, and **Throttle** limits how often
it sends.

> **Before 0.1.7 there is no `twist` port.** The joystick only emits `position` as `{x, y}` in
> −100…100, and a transform cannot rescale an object's fields, so older versions cannot produce a
> valid, scaled Twist from the joystick. Bindings that apply `map_range` to `position` fail on every
> message. Upgrade for joystick driving; the rest of this example works on 0.1.6 too.

### Battery State

**Binding Group:** `Battery Monitor`
- Endpoint: `Battery`
- Direction: In

**Mappings:**
- Battery → port `level` → payload_path `percentage`, transform
  `{"kind": "scale", "version": 1, "params": {"factor": 100}}`. `BatteryState.percentage` is
  0–1, and the widget shows 0–100.
- Battery → port `charging` → payload_path `power_supply_status`, transform
  `{"kind": "map_value", "version": 1, "params": {"mapping": {"1": true}, "default": false}}`.
  The status is a number, where `1` means charging.

### Speed

**Binding Group:** `Motion`
- Endpoint: `Odometry`
- Direction: In

**Mapping:**
- Speed → port `value` → payload_path `twist.twist.linear.x`, optionally with
  `{"kind": "round", "version": 1, "params": {"mode": "decimal", "decimals": 2}}`

> Heading is not shown here on purpose. Odometry carries orientation as a quaternion, and turning
> one into a compass angle needs trigonometry that transforms do not provide. Publish the heading as
> a number from the robot if you want a compass.

### Camera Stream

Run [web_video_server](https://github.com/RobotWebTools/web_video_server) next to rosbridge. It
turns an image topic into an MJPEG stream that the browser plays directly:

- Widget: WStream
- **URL:** `http://192.168.1.50:8080/stream?topic=/camera/image_raw`
- **Type:** `mjpeg`. Set it by hand: only a path ending in `.mjpg` or `.mjpeg`, or containing
  `/mjpg/`, is recognised automatically.

For an RTSP camera instead, register a media Source; see [RTSP cameras](../rtsp-proxy.md).

## 6. Emergency Stop

**Binding Group:** `Safety`
- Endpoint: `Velocity Command`
- Direction: Out
- **Final Transform:**
```json
{"kind": "wrap", "version": 1, "params": {"template": {"linear": {"x": 0, "y": 0, "z": 0}, "angular": {"x": 0, "y": 0, "z": 0}}}}
```

**Mapping:**
- E-Stop → port `trigger`

The `trigger` port sends a boolean, and the final transform replaces the whole payload with a zero
Twist. A template with no `{{value}}` placeholder ignores its input, so every press sends the same
stop command.

## Testing Without a Robot

Use ROS 2 CLI to simulate:

```bash
# Simulate battery at 75%, charging
ros2 topic pub /battery_state sensor_msgs/msg/BatteryState \
  "{percentage: 0.75, power_supply_status: 1}" --once

# Watch cmd_vel output from the joystick and the stop button
ros2 topic echo /cmd_vel

# Simulate odometry moving forward at 0.15 m/s
ros2 topic pub /odom nav_msgs/msg/Odometry \
  "{twist: {twist: {linear: {x: 0.15}}}}" -r 10
```

## Result

- Drag the joystick → robot moves, and stops when you let go
- Camera feed streams in real time
- Battery level and charging state update automatically
- E-Stop publishes a zero Twist
- Speed shows the robot's forward velocity

## Tips

- Set the joystick's **Dead Zone** to 10–15 to prevent drift commands
- Set the velocity endpoint's `queue_size` to `1`, so only the latest command is kept
- ROS 2 background mode `off` is recommended for high-rate topics like `/scan` — saves bandwidth when not viewing
- Many robot drivers stop on their own when `cmd_vel` goes quiet. Rely on that timeout, not on the
  browser, to stop the robot if the connection drops

## Next Steps

- Add a [WMap](../widgets.md) widget with floorplan for robot position tracking
- Use [WDPad](../widgets.md) as an alternative to joystick for discrete movement
- Set up [Push Notifications](../push-notifications.md) for low battery alerts
