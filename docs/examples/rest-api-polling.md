# Example: REST API Polling with Chart Widget

Poll a REST API at regular intervals and display the data on a real-time chart. Works with any JSON API — weather services, home automation, custom backends.

## Architecture

```
REST API (JSON) ← Flintbay polls every N seconds → Chart + Value Display
```

## Use Case

We'll poll a weather API and display temperature history on a chart with current value on a gauge.

## 1. Flintbay Source Configuration

1. **Sources** → **+ Add Source**
2. Configure:
   - **Name:** `Weather API`
   - **Protocol:** REST
   - **Base URL:** `https://api.open-meteo.com`
3. **Save**

## 2. Create Endpoint

1. **+ Add Endpoint** on the source
2. Configure:
   - **Name:** `Current Temperature`
   - **Direction:** In
   - **Address:** `/v1/forecast?latitude=50.45&longitude=30.52&current=temperature_2m,wind_speed_10m`
   - **Config:**
```json
{
  "method": "GET",
  "poll_interval_ms": 60000,
  "history_size": 60
}
```

This polls every 60 seconds and keeps 60 data points in the server-side ring buffer (1 hour of history).

### API Response Structure

The Open-Meteo API returns:
```json
{
  "current": {
    "temperature_2m": 18.3,
    "wind_speed_10m": 12.5
  }
}
```

## 3. Build the Dashboard

Create screen `Weather`, page `Current`.

### Widgets

| Widget | Type | Config |
|--------|------|--------|
| Temperature | WGauge | min: -20, max: 45, unit: °C |
| Wind Speed | WValueDisplay | unit: km/h, label: Wind |
| Temp Chart | WChart | — |
| Wind Chart | WSparkline | — |

## 4. Create Bindings

**Binding Group:** `Weather Data`
- Endpoint: `Current Temperature`
- Direction: In

**Mappings:**

| Widget | Port | Payload Path |
|--------|------|-------------|
| Temperature (WGauge) | `value` | `current.temperature_2m` |
| Wind Speed (WValueDisplay) | `value` | `current.wind_speed_10m` |
| Temp Chart (WChart) | `value` | `current.temperature_2m` |
| Wind Chart (WSparkline) | `value` | `current.wind_speed_10m` |

> The `history_size: 60` on the endpoint means the chart will show backfill data immediately when you open the page — no waiting for 60 polls to fill up.

## 5. Custom REST API Example

If you have your own API at `http://192.168.1.100:8080`:

**Source config:**
```
Base URL: http://192.168.1.100:8080
```

**Endpoint:**
```
Address: /api/sensors
Method: GET
Poll interval: 3000 (every 3 seconds)
```

**If your API requires auth headers**, add them to the source config:
```json
{
  "base_url": "http://192.168.1.100:8080",
  "headers": {
    "Authorization": "Bearer your-token-here"
  }
}
```

**If the data is nested**, use dot-notation in payload_path:
```json
// API returns: {"data": {"sensors": [{"temp": 25.1}]}}
// payload_path: "data.sensors.0.temp"
```

## 6. Adding Transforms

Scale raw sensor values to meaningful units:

```json
{
  "kind": "map_range",
  "version": 1,
  "params": {
    "from": [0, 1023],
    "to": [0, 100]
  }
}
```

Round to 1 decimal place:
```json
{
  "kind": "round",
  "version": 1,
  "params": {"decimals": 1}
}
```

Chain multiple transforms:
```json
{
  "kind": "chain",
  "version": 1,
  "params": {
    "transforms": [
      {"kind": "map_range", "version": 1, "params": {"from": [0, 4095], "to": [0, 100]}},
      {"kind": "round", "version": 1, "params": {"decimals": 1}}
    ]
  }
}
```

## Polling Intervals

| Use Case | Interval | Notes |
|----------|----------|-------|
| Weather API | 60000ms | Rate limits apply |
| Local sensor API | 1000–3000ms | Low latency |
| Database dashboard | 5000–10000ms | Reduce DB load |
| Health check | 10000–30000ms | Just need up/down |

> **Tip:** When no browser tab is viewing the page, Flintbay automatically throttles REST polling to save resources (demand-aware lifecycle). The cached value is replayed instantly when you return.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Chart shows nothing | Verify `history_size > 0` in endpoint config |
| Wrong value displayed | Use `test_fetch_endpoint` (MCP) or check payload_path |
| CORS errors in logs | Flintbay backend makes the request, not the browser — CORS doesn't apply |
| API returns HTML | Check the endpoint address — likely a 404 redirect |

## Next Steps

- [Transforms Guide](../transforms.md) — full reference for data transforms
- [Widget Catalog](../widgets.md) — explore WTable for tabular API data
- [MQTT Example](./mqtt-temperature.md) — for push-based real-time data
