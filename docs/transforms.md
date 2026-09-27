# Data Transforms

A transform changes a value on its way between an endpoint and a widget. Use it to scale, filter,
convert or reshape the value without changing your device firmware.

## How Transforms Work

```
Inbound:  Endpoint payload → Final Transform → payload_path → Per-port Transform → Widget port
Outbound: Widget port → Per-port Transform → payload built from all Mappings → Final Transform → Endpoint
```

- **Per-port Transform** is set on a Binding Mapping and applies to one widget port's value.
- **Final Transform** is set on a Binding Group and applies to the whole payload. For example, it
  can wrap the payload in the envelope a device expects.

A transform is a JSON object with `kind`, `version` and `params`:

```json
{"kind": "scale", "version": 1, "params": {"factor": 0.01}}
```

A transform whose params are invalid is rejected when the binding is saved. In 0.1.6 this check
does not reach the steps inside a `chain`: an invalid step is saved, and then fails on every
message. Test a chain with known values before you rely on it. From the next release, a chain is
refused on save and the error names the failing step, e.g. `Invalid chain step 1 (cast)`.

Every example on this page has been run against the transform engine, and the tables show its
actual output.

Most transforms need a number. They accept numeric strings such as `"12"` and convert them, but
reject an object. For example, `map_range` on a joystick's `{x, y}` fails with
`map_range requires numeric input, got dict`. On an inbound binding, use the Mapping's
`payload_path` to select the number first.

## Available Transforms

| Kind | Does | Input |
|---|---|---|
| [`scale`](#scale) | multiply | number |
| [`offset`](#offset) | add | number |
| [`invert`](#invert) | flip sign / boolean | number, boolean |
| [`map_range`](#map_range) | linear range conversion | number |
| [`clamp`](#clamp) | limit to min/max | number |
| [`round`](#round) | round, floor, ceil, truncate | number |
| [`deadzone`](#deadzone) | zero small values on a −1…1 axis | number |
| [`lowpass`](#lowpass) | smooth over time | number |
| [`cast`](#cast) | convert type | any |
| [`map_value`](#map_value) | lookup table | any |
| [`pick`](#pick) | keep selected fields of an object | object |
| [`wrap`](#wrap) | put the value into a JSON template | any |
| [`chain`](#chain) | run several transforms in order | any |

### scale

Multiply the value by `factor`.

```json
{"kind": "scale", "version": 1, "params": {"factor": 0.1}}
```

| Input | Output |
|-------|--------|
| 255 | 25.5 |
| 1000 | 100.0 |

**Use case:** Convert millivolts to volts, raw counts to units.

### offset

Add `value` to the value.

```json
{"kind": "offset", "version": 1, "params": {"value": -273.15}}
```

| Input | Output |
|-------|--------|
| 296.15 | 23.0 |

**Use case:** Convert Kelvin to Celsius, apply a calibration offset.

### invert

Flip the sign of a number, or negate a boolean.

```json
{"kind": "invert", "version": 1, "params": {}}
```

| Input | Output |
|-------|--------|
| 50 | -50.0 |
| -30 | 30.0 |
| true | false |

**Use case:** Reverse motor direction, flip an axis, invert an active-low signal.

### map_range

Map a value from the range `from` to the range `to` by linear interpolation. Values outside `from`
are extrapolated unless `clamp` is `true`. A reversed target range such as `[100, 0]` inverts the
scale.

| Param | Required | Default |
|---|---|---|
| `from` | yes | — `[min, max]` |
| `to` | yes | — `[min, max]` |
| `clamp` | no | `false` |

```json
{"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [0, 100]}}
```

| Input | Output | With `"clamp": true` |
|-------|--------|---|
| 0 | 0.0 | 0.0 |
| 2048 | 50.012… | 50.012… |
| 4095 | 100.0 | 100.0 |
| 5000 | 122.1… | 100.0 |

**Use case:** ADC to percentage, joystick range to velocity, sensor range normalization.

### clamp

Limit the value to `min` and `max`. Either bound can be omitted. `min` greater than `max` is
rejected.

```json
{"kind": "clamp", "version": 1, "params": {"min": 0, "max": 100}}
```

| Input | Output |
|-------|--------|
| -5 | 0.0 |
| 50 | 50.0 |
| 150 | 100.0 |

**Use case:** Stop out-of-range values from breaking gauges or reaching actuators.

### round

Round the value. The default `mode` is `int`, which rounds to the nearest integer. Set `mode` to
`decimal` to keep decimal places: `decimals` has no effect in any other mode.

| `mode` | Does | 3.7 | -3.7 |
|---|---|---|---|
| `int` (default) | nearest integer | 4 | -4 |
| `floor` | round down | 3 | -4 |
| `ceil` | round up | 4 | -3 |
| `truncate` | drop the fraction | 3 | -3 |
| `decimal` | nearest, to `decimals` places | — | — |

```json
{"kind": "round", "version": 1, "params": {"mode": "decimal", "decimals": 1}}
```

| Input | Output |
|-------|--------|
| 23.456 | 23.5 |
| 99.999 | 100.0 |

Exact halves round to the nearest even number: `23.5` → `24`, but `24.5` → `24`.

**Use case:** Clean up floating-point noise for display.

### deadzone

Set values within `threshold` of `center` to zero. The input is treated as an axis from −1 to 1:
larger values are clamped to that range. With `rescale` (the default), values outside the
deadzone are stretched so the output still reaches ±1.

| Param | Required | Default |
|---|---|---|
| `threshold` | yes | — must be at least 0 and less than 1 |
| `center` | no | `0` |
| `rescale` | no | `true` |

```json
{"kind": "deadzone", "version": 1, "params": {"threshold": 0.1}}
```

| Input | Output | With `"rescale": false` |
|-------|--------|---|
| 0.05 | 0.0 | 0.0 |
| -0.08 | 0.0 | 0.0 |
| 0.5 | 0.444… | 0.5 |
| 1.0 | 1.0 | 1.0 |

For a value in another range, such as −100…100, convert it with `map_range` to −1…1 first (see
[the recipe](#joystick-axis--velocity)).

**Use case:** Joystick drift, noisy analog inputs around zero.

### lowpass

Smooth a value with an exponential moving average:
`output = alpha × input + (1 − alpha) × previous_output`.

| Param | Required | Default |
|---|---|---|
| `alpha` | yes | — greater than 0, at most 1. Lower is smoother but slower |
| `state_key` | yes | — a name for this filter's memory. Use a different key for each filter |
| `initial_value` | no | the first input |

```json
{"kind": "lowpass", "version": 1, "params": {"alpha": 0.2, "state_key": "boiler_temp"}}
```

| Input sequence | Output sequence |
|---|---|
| 0, 100, 100, 100 | 0.0, 20.0, 36.0, 48.8 |

> **Known issue in 0.1.6:** in bindings, the filter's memory is not kept between messages, so
> `lowpass` passes values through unchanged. Smooth on the device until you upgrade. The next
> release fixes this. Each mapping and each direction then keeps its own filter memory, even when
> two mappings use the same `state_key`, and replaying the last value to a page that has just
> opened does not move the filter.

**Use case:** Smooth noisy sensor readings and reduce jitter on displays.

### cast

Convert the value to `int`, `float`, `str` or `bool`.

```json
{"kind": "cast", "version": 1, "params": {"to": "float"}}
```

| Input | `to` | Output |
|-------|-----|--------|
| `"42"` | `float` | 42.0 |
| `"23.5"` | `float` | 23.5 |
| `"abc"` | `float` | error |
| `"3.7"` | `int` | 3 (truncated) |
| `23.5` | `str` | `"23.5"` |

For `bool`, the strings `"false"`, `"no"`, `"off"`, `"0"` and the empty string become `false`, as
do `0` and `false`. Any other string becomes `true`, including `"banana"`.

**Use case:** MQTT and serial payloads that arrive as strings.

### map_value

Replace a value using a lookup table. The input is converted to text before lookup, so the keys
are strings.

| Param | Required | Default |
|---|---|---|
| `mapping` | yes | — `{"input": output}` |
| `default` | no | — returned when the value is not in `mapping` |
| `strict` | no | `false`. When `true`, a missing value is an error even if `default` is set |

```json
{"kind": "map_value", "version": 1, "params": {"mapping": {"0": "OFF", "1": "ON", "2": "ERROR"}, "default": "UNKNOWN"}}
```

| Input | Output |
|-------|--------|
| 0 | "OFF" |
| "2" | "ERROR" |
| 7 | "UNKNOWN" |

Without `default`, a value that is not in `mapping` is an error. Watch the text form of the
input:

- The float `1.0` becomes `"1.0"`, which does not match the key `"1"`.
- The boolean `true` becomes `"True"`, with a capital T.
- Matching is case-sensitive.

**Use case:** Status codes to readable labels, enum conversion.

### pick

Keep only the listed `fields` of an object. Dot notation reaches nested fields. The output is
always an object. To extract a single number for a widget, use the Mapping's `payload_path`
instead.

| Param | Required | Default |
|---|---|---|
| `fields` | yes | — list of paths, at least one |
| `flatten` | no | `true`: nested paths become flat keys such as `"data.temperature"` |
| `default` | no | — value for missing fields. Without it, missing fields are left out |
| `strict` | no | `false`. When `true`, a missing field is an error |

```json
{"kind": "pick", "version": 1, "params": {"fields": ["data.temperature", "data.humidity"], "flatten": false}}
```

| Input | Output |
|-------|--------|
| `{"data": {"temperature": 23.5, "humidity": 40, "x": 1}}` | `{"data": {"temperature": 23.5, "humidity": 40}}` |

With the default `"flatten": true`, the output would be
`{"data.temperature": 23.5, "data.humidity": 40}`.

**Use case:** Final Transform that trims a large payload before it is distributed or sent.

### wrap

Put the value into a JSON `template`. Each `"{{value}}"` is replaced by the value, and keeps its
type. `{{value}}` inside a longer string is inserted as text.

```json
{"kind": "wrap", "version": 1, "params": {"template": {"linear": {"x": "{{value}}", "y": 0, "z": 0}}}}
```

| Input | Template | Output |
|-------|---|--------|
| 0.5 | above | `{"linear": {"x": 0.5, "y": 0, "z": 0}}` |
| 255 | `{"pwm": "{{value}}"}` | `{"pwm": 255}` |
| 5 | `{"msg": "speed={{value}}"}` | `{"msg": "speed=5"}` |

**Use case:** Outbound commands for a device that expects a fixed JSON shape.

### chain

Run several transforms in order. The output of each step is the input of the next. If any step
fails, the chain fails and reports which step failed.

```json
{
  "kind": "chain",
  "version": 1,
  "params": {
    "transforms": [
      {"kind": "cast", "version": 1, "params": {"to": "float"}},
      {"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [-10, 50]}},
      {"kind": "round", "version": 1, "params": {"mode": "decimal", "decimals": 1}},
      {"kind": "clamp", "version": 1, "params": {"min": -10, "max": 50}}
    ]
  }
}
```

| Input | Output |
|-------|--------|
| "2048" | 20.0 |
| "5000" | 50.0 |

## Common Recipes

### Raw ADC → Temperature (°C)

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [-40, 125]}},
    {"kind": "round", "version": 1, "params": {"mode": "decimal", "decimals": 1}}
  ]}
}
```

2048 → 42.5

### Joystick axis → velocity

Converts an axis value in −100…100 to −0.5…0.5 m/s, with a 10% deadzone:

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "map_range", "version": 1, "params": {"from": [-100, 100], "to": [-1, 1]}},
    {"kind": "deadzone", "version": 1, "params": {"threshold": 0.1}},
    {"kind": "scale", "version": 1, "params": {"factor": 0.5}}
  ]}
}
```

5 → 0.0 · 100 → 0.5 · -50 → -0.222…

WJoystick's `position` port emits an object `{x, y}`, not a number, so this chain cannot run on it
directly. The joystick has its own **dead zone** setting for drift. To drive a robot's `cmd_vel`,
see [the TurtleBot example](examples/ros2-turtlebot.md#5-create-bindings).

### String MQTT payload → Gauge value

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "cast", "version": 1, "params": {"to": "float"}},
    {"kind": "clamp", "version": 1, "params": {"min": 0, "max": 100}}
  ]}
}
```

"42.5" → 42.5 · "140" → 100.0

### Percentage → PWM command

```json
{
  "kind": "chain", "version": 1,
  "params": {"transforms": [
    {"kind": "scale", "version": 1, "params": {"factor": 2.55}},
    {"kind": "round", "version": 1, "params": {}},
    {"kind": "wrap", "version": 1, "params": {"template": {"pwm": "{{value}}"}}}
  ]}
}
```

100 → `{"pwm": 255}`

## Applying Transforms

Transforms are set in the Binding Group editor (see
[Advanced Group Editing](bindings.md#advanced-group-editing)):

- **Per-port Transform:** open a Mapping, choose the transform in **Select transform**, and fill in
  its **Parameters**. The editor builds the parameter fields from the transform's definition and
  warns when a transform does not fit the port's value type.
- **Final Transform:** set it in the group's settings.

Or via MCP:

```
"Add a map_range transform from [0, 1023] to [0, 100] on the temperature gauge binding"
```

## Tips

- Add a transform only when the raw data does not match what the widget expects.
- Prefer `payload_path` to `pick` for selecting a single value.
- Use `chain` to combine several simple transforms instead of a custom one.
- `lowpass` with an alpha of 0.1–0.3 suits most noisy sensors. Mind the 0.1.6 known issue above.
- A `deadzone` threshold of 0.05–0.15 suits most joysticks.
- Test a transform by publishing known values and checking the widget's output.
