# Data Transforms

Transforms modify data as it flows between endpoints and widgets. Apply them to binding mappings to scale, filter, convert, or reshape values without changing your device firmware.

## How Transforms Work

```
Endpoint payload → payload_path extraction → Transform → Widget port
```

Transforms are JSON objects with `kind`, `version`, and `params`:

```json
{
  "kind": "scale",
  "version": 1,
  "params": {"factor": 0.01}
}
```

## Available Transforms

### scale

Multiply value by a factor.

```json
{"kind": "scale", "version": 1, "params": {"factor": 0.1}}
```

| Input | Output |
|-------|--------|
| 255 | 25.5 |
| 1000 | 100.0 |

**Use case:** Convert millivolts to volts, raw ADC to percentage.

### offset

Add a constant to the value.

```json
{"kind": "offset", "version": 1, "params": {"value": -273.15}}
```

| Input | Output |
|-------|--------|
| 296.15 | 23.0 |

**Use case:** Convert Kelvin to Celsius, apply calibration offset.

### invert

Flip the sign of a numeric value.

```json
{"kind": "invert", "version": 1, "params": {}}
```

| Input | Output |
|-------|--------|
| 50 | -50 |
| -30 | 30 |

**Use case:** Reverse motor direction, flip axis.

### map_range

Map a value from one range to another (linear interpolation).

```json
{"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [0, 100]}}
```

| Input | Output |
|-------|--------|
| 0 | 0 |
| 2048 | 50.0 |
| 4095 | 100.0 |

**Use case:** ADC to percentage, joystick raw to velocity, sensor range normalization.

### pick

Extract a field from a JSON object.

```json
{"kind": "pick", "version": 1, "params": {"path": "data.temperature"}}
```

| Input | Output |
|-------|--------|
| `{"data": {"temperature": 23.5}}` | 23.5 |

**Use case:** Extract nested fields when payload_path isn't enough.

### round

Round to N decimal places.

```json
{"kind": "round", "version": 1, "params": {"decimals": 1}}
```

| Input | Output |
|-------|--------|
| 23.456 | 23.5 |
| 99.999 | 100.0 |

**Use case:** Clean up floating point noise for display.

### cast

Convert value type.

```json
{"kind": "cast", "version": 1, "params": {"to": "number"}}
```

Supported types: `number`, `string`, `boolean`, `integer`

| Input | To | Output |
|-------|-----|--------|
| "42" | number | 42 |
| 1 | boolean | true |
| 23.5 | string | "23.5" |

**Use case:** String payloads from MQTT that need to be numbers.

### clamp

Constrain value to a min/max range.

```json
{"kind": "clamp", "version": 1, "params": {"min": 0, "max": 100}}
```

| Input | Output |
|-------|--------|
| -5 | 0 |
| 50 | 50 |
| 150 | 100 |

**Use case:** Prevent out-of-range values from breaking gauges.

### wrap

Wrap value around a range (modulo-style).

```json
{"kind": "wrap", "version": 1, "params": {"min": 0, "max": 360}}
```

| Input | Output |
|-------|--------|
| 370 | 10 |
| -10 | 350 |

**Use case:** Compass heading, rotary encoder values.

### deadzone

Ignore values within a threshold of center.

```json
{"kind": "deadzone", "version": 1, "params": {"threshold": 5, "center": 0}}
```

| Input | Output |
|-------|--------|
| 3 | 0 |
| -4 | 0 |
| 10 | 10 |

**Use case:** Joystick drift elimination, noisy analog inputs.

### lowpass

Exponential moving average filter.

```json
{"kind": "lowpass", "version": 1, "params": {"alpha": 0.3}}
```

Alpha range: 0–1. Lower = smoother but slower response.

**Use case:** Smooth noisy sensor readings, reduce jitter on displays.

### map_value

Map discrete values to other values.

```json
{"kind": "map_value", "version": 1, "params": {"map": {"0": "OFF", "1": "ON", "2": "ERROR"}}}
```

| Input | Output |
|-------|--------|
| 0 | "OFF" |
| 1 | "ON" |
| 2 | "ERROR" |

**Use case:** Status codes to human-readable labels, enum conversion.

### chain

Apply multiple transforms in sequence.

```json
{
  "kind": "chain",
  "version": 1,
  "params": {
    "transforms": [
      {"kind": "cast", "version": 1, "params": {"to": "number"}},
      {"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [-10, 50]}},
      {"kind": "round", "version": 1, "params": {"decimals": 1}},
      {"kind": "clamp", "version": 1, "params": {"min": -10, "max": 50}}
    ]
  }
}
```

Transforms execute left-to-right. Output of one feeds into the next.

## Common Recipes

### Raw ADC → Temperature (°C)

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [-40, 125]}},
    {"kind": "round", "version": 1, "params": {"decimals": 1}}
  ]}
}
```

### Joystick → ROS 2 Twist velocity

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "deadzone", "version": 1, "params": {"threshold": 10, "center": 0}},
    {"kind": "map_range", "version": 1, "params": {"from": [-100, 100], "to": [-0.5, 0.5]}}
  ]}
}
```

### String MQTT payload → Gauge value

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "cast", "version": 1, "params": {"to": "number"}},
    {"kind": "clamp", "version": 1, "params": {"min": 0, "max": 100}}
  ]}
}
```

### Noisy sensor → Smooth display

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "lowpass", "version": 1, "params": {"alpha": 0.2}},
    {"kind": "round", "version": 1, "params": {"decimals": 0}}
  ]}
}
```

## Applying Transforms

Transforms are set per binding mapping:

1. Open **Bindings** panel
2. Select a mapping
3. Set the **Transform** field with the JSON object
4. Save

Or via MCP:
```
"Add a map_range transform from [0, 1023] to [0, 100] on the temperature gauge binding"
```

## Tips

- Start simple — add transforms only when raw data doesn't match widget expectations
- Use `chain` to compose multiple simple transforms instead of complex custom logic
- `lowpass` with alpha 0.1–0.3 works well for most noisy sensors
- `deadzone` of 5–15% is standard for joysticks
- Test transforms by publishing known values and checking widget output
