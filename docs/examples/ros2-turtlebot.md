# Example: ROS2 TurtleBot Control with Joystick + Camera

Control a TurtleBot3 (or any ROS2 robot) from Flintbay — joystick for movement, live camera stream, battery indicator, and a browser stop command.

> **Safety:** The stop widget below only publishes a zero-velocity command through the application stack. It is not a safety-rated emergency stop. Use controller-level watchdogs, motion timeouts, hardware interlocks, and a physical E-stop wherever failure could cause harm.

## Architecture

```
Flintbay Dashboard ↔ rosbridge_server (WebSocket) ↔ ROS2 Topics
```

Flintbay connects to ROS2 via [rosbridge_suite](https://github.com/RobotWebTools/rosbridge_suite), which exposes ROS2 topics over WebSocket.

## Prerequisites

- ROS2 Humble/Iron/Jazzy with TurtleBot3 packages
- `rosbridge_server` running
- Flintbay instance ([Getting Started](../getting-started.md))

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
   - **Protocol:** ROS2
   - **Bridge URL:** `ws://192.168.1.50:9090` (your rosbridge host)
3. **Save**

## 3. Create Endpoints

| Name | Direction | Topic | Message Type |
|------|-----------|-------|--------------|
| Velocity Command | Out | `/cmd_vel` | `geometry_msgs/Twist` |
| Camera | In | `/camera/image_raw/compressed` | `sensor_msgs/CompressedImage` |
| Battery | In | `/battery_state` | `sensor_msgs/BatteryState` |
| Odometry | In | `/odom` | `nav_msgs/Odometry` |

### Endpoint configs:

**Velocity Command:**
```json
{"message_type": "geometry_msgs/msg/Twist", "queue_size": 1}
```

**Camera:**
```json
{"message_type": "sensor_msgs/msg/CompressedImage", "queue_size": 1}
```

**Battery:**
```json
{"message_type": "sensor_msgs/msg/BatteryState", "queue_size": 1}
```

## 4. Build the Dashboard

Create screen `TurtleBot Control`, page `Main`.

### Widget Layout

| Widget | Type | Size | Purpose |
|--------|------|------|---------|
| Joystick | WJoystick | 200×200 | Movement control |
| Camera Feed | WStream | 400×300 | Live video |
| Battery | WBattery | 80×120 | Battery level |
| E-Stop | WEmergencyStop | 100×100 | Emergency stop |
| Speed | WValueDisplay | 120×80 | Current speed |
| Heading | WCompass | 150×150 | Robot heading |

## 5. Create Bindings

### Joystick → /cmd_vel

**Binding Group:** `Movement Control`
- Endpoint: `Velocity Command`
- Direction: Out

**Mapping:**
- Widget: Joystick
- Port: `position`
- Payload Path: (null — use entire payload)
- Transform:
```json
{
  "kind": "chain",
  "version": 1,
  "params": {
    "transforms": [
      {"kind": "map_range", "version": 1, "params": {"from": [-100, 100], "to": [-0.5, 0.5]}}
    ]
  }
}
```

> The joystick outputs `{x: -100..100, y: -100..100}`. The transform maps this to Twist-compatible linear/angular velocities.

### Battery State

**Binding Group:** `Battery Monitor`
- Endpoint: `Battery`
- Direction: In

**Mapping:**
- Widget: Battery → port `level` → payload_path: `percentage`
- Widget: Battery → port `charging` → payload_path: `power_supply_status`

### Camera Stream

For compressed image topics, use the WStream widget with the rosbridge video stream URL:

- Widget: WStream
- Set `stream_url` parameter to: `http://192.168.1.50:8080/stream?topic=/camera/image_raw/compressed`

> This requires [web_video_server](http://wiki.ros.org/web_video_server) running alongside rosbridge.

### Odometry → Compass

**Binding Group:** `Navigation`
- Endpoint: `Odometry`
- Direction: In

**Mapping:**
- Widget: Compass → port `heading` → payload_path: `pose.pose.orientation.z`
- Transform: `map_range` from `[-1, 1]` to `[0, 360]`

## 6. Emergency Stop

**Binding Group:** `Safety`
- Endpoint: `Velocity Command`
- Direction: Out

**Mapping:**
- Widget: E-Stop → port `trigger`
- When triggered, publishes zero velocity:
```json
{"linear": {"x": 0, "y": 0, "z": 0}, "angular": {"x": 0, "y": 0, "z": 0}}
```

## Testing Without a Robot

Use ROS2 CLI to simulate:

```bash
# Simulate battery at 75%
ros2 topic pub /battery_state sensor_msgs/msg/BatteryState \
  "{percentage: 0.75, power_supply_status: 1}" --once

# Watch cmd_vel output from joystick
ros2 topic echo /cmd_vel

# Simulate odometry
ros2 topic pub /odom nav_msgs/msg/Odometry \
  "{pose: {pose: {orientation: {z: 0.5}}}}" -r 10
```

## Result

- Drag the joystick → robot moves
- Camera feed streams in real time
- Battery level updates automatically
- E-Stop immediately halts the robot
- Compass shows current heading

## Tips

- Set joystick `deadzone` param to 10–15% to prevent drift commands
- Use `lowpass` transform on odometry for smoother compass movement
- Set velocity endpoint `queue_size: 1` to always send latest command
- ROS2 background mode `off` is recommended for high-rate topics like `/scan` — saves bandwidth when not viewing

## Next Steps

- Add a [WMap](../widgets.md) widget with floorplan for robot position tracking
- Use [WDPad](../widgets.md) as an alternative to joystick for discrete movement
- Set up [Push Notifications](../push-notifications.md) for low battery alerts
