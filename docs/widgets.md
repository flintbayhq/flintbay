# Widget Catalog

Flintbay includes 42 widget types across 6 categories. Every widget exposes **ports** that you bind to endpoints for real-time data flow.

## Port Directions

| Direction | Meaning |
|-----------|---------|
| **in** | Receives data from endpoint → widget displays it |
| **out** | Widget sends data → endpoint (e.g., sensor readings from browser) |
| **bidir** | Both directions — display + control |
| **emit** | Widget fires one-shot events (button click, joystick move) |

## Categories

### 🎮 Control

Widgets that send commands to your devices.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WButton** | Momentary push button | `click` (emit) |
| **WToggleButton** | Toggle with on/off state | `value` (bidir, boolean) |
| **WToggleSwitch** | Switch with on/off state | `value` (bidir, boolean) |
| **WSlider** | Numeric value slider | `value` (bidir), `min`, `max`, `step` |
| **WKnob** | Rotary knob for precise adjustment | `value` (bidir), `min`, `max` |
| **WNumberInput** | Numeric input with +/- buttons | `value` (bidir), `min`, `max`, `step` |
| **WJoystick** | Two-axis directional control | `position` (emit, {x, y}) |
| **WDPad** | Directional pad (up/down/left/right) | `up`, `down`, `left`, `right` (emit) |
| **WEmergencyStop** | Latching E-Stop with confirmation | `trigger` (emit), `active` (in) |
| **WColorPicker** | RGB/LED color control | `color` (bidir), `change` (emit) |
| **WDropdown** | Select from options list | `value` (bidir), `options` (in) |
| **WRadioGroup** | Radio button single-select | `value` (bidir), `options` (in) |
| **WSelectButton** | Button group selection | `active` (bidir), `click` (emit) |
| **WTextInput** | Text input with submit | `value` (bidir), `submit` (emit) |

### 📊 Display

Widgets that show data from your devices.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WGauge** | Arc gauge for numeric values | `value` (in), `min`, `max`, `color` |
| **WValueDisplay** | Large number with unit and trend | `value` (in), `unit`, `label`, `color` |
| **WBattery** | Battery level indicator | `level` (in, 0-100), `charging` (in) |
| **WProgressBar** | Progress bar (or indeterminate) | `value` (in, 0-100) |
| **WIndicator** | Status light (on/off/blink) | `active` (in), `color`, `blink`, `label` |
| **WSemaphore** | Traffic light with N sections | `active_index` (in), `blink` |
| **WCompass** | Heading/direction indicator | `heading` (in, 0-360) |
| **WLevelTank** | Animated tank fill level | `level` (in, 0-100), `color` |
| **WText** | Display text content | `text` (in) |
| **WKeyValue** | Key-value pair list | `data` (in, object) |

### 📈 Chart

Widgets for time-series and data visualization.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WChart** | Real-time line chart | `value` (in), `label`, `clear` |
| **WSparkline** | Compact mini-chart (no axes) | `value` (in), `clear` |
| **WBarChart** | Bar/column chart | `values` (in, array), `labels`, `color` |

### 🎬 Media

Widgets for video, audio, and rich content.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WStream** | Live video (HLS/DASH/WebRTC/MJPEG) | `stream_url` (in), `playing`, `muted` |
| **WVideo** | Video player (YouTube/Vimeo/mp4) | `url` (in), `playing`, `muted` |
| **WAudioPlayer** | Audio playback + streaming | `url` (in), `playing`, `volume` |
| **WAudioCapture** | Microphone capture + stream | `target_url` (in), `active`, `gain` |
| **WImage** | Dynamic image display | `src` (in), `visible` |

### 📋 Data

Widgets for structured data display.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WTable** | Data table with columns | `rows` (in), `columns` (in) |
| **WLog** | Auto-scrolling console output | `message` (in, event), `clear` |
| **WAlarmList** | Active alarms with severity | `alarms` (in), `alarm` (event), `clear` |
| **WTimeline** | Chronological event list | `events` (in), `event` (event), `clear` |
| **WMap** | 2D floorplan with markers | `markers` (in), `position`, `heading` |

### 🧱 Layout

Widgets for visual structure.

| Widget | Description | Key Ports |
|--------|-------------|-----------|
| **WPanel** | Container with title bar | `title` (in) |
| **WDivider** | Horizontal/vertical separator | — |
| **WShape** | Geometric shapes for diagrams | — |
| **WHtml** | Custom HTML content | `content` (in), `data` (in) |
| **WIframe** | Embed external content | `url` (in) |

## System Ports

Every widget has these system ports (hidden by default):

| Port | Direction | Purpose |
|------|-----------|---------|
| `error` | in | Display error state from failed commands |
| `disabled` | in | Disable widget interaction remotely |
| `pending` | in | Show loading state while command is in-flight |

## ACK Modes

Control widgets support acknowledgment modes for reliable command delivery:

| Mode | Behavior |
|------|----------|
| **fire** | Send and forget — widget resets immediately |
| **ack** | Wait for device acknowledgment before resetting |
| **submit** | Require explicit user confirmation before sending |

Configure ACK mode in widget parameters under the `submit_mode` group.

## Example Data

A widget you just dropped on a page has nothing bound yet, so instead of an empty `--` most display,
chart and data widgets render **example data** — a plausible reading, a curve, a few table rows — with
a small diagonal `example` ribbon in the corner.

- It only appears in **edit mode**. In operation mode an unbound widget shows its normal empty state,
  so a number on a live dashboard is always a real number.
- It disappears as soon as you bind **any** port of that widget.
- It is generated in the browser. Nothing is stored, nothing is sent to a device, and no endpoint is
  created for it.

Media widgets (WStream, WVideo, WAudioPlayer, WAudioCapture, WIframe, WImage) never get example
content — a fake source would mean real network requests.

## Widget Sizing

- All positions and sizes snap to a 10px grid
- Minimum size varies by widget type (typically 60×60)
- Widgets are responsive within their allocated space

## Tips

- Use **WPanel** to visually group related widgets
- **WSparkline** is great for compact dashboards — same data as WChart but fits in 100×40px
- **WHtml** with `data` port + template interpolation (`{{field}}`) is powerful for custom displays
- **WStream** auto-detects protocol from URL — just paste any stream URL
- Bind `disabled` port to a condition endpoint to lock controls based on device state
