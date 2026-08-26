# Example: ESP32 Temperature Sensor → MQTT → Flintbay Gauge

A complete end-to-end example: ESP32 with DHT22 sensor publishes temperature via MQTT, Flintbay displays it on a gauge with a real-time chart.

## Architecture

```
ESP32 + DHT22 → MQTT Broker → Flintbay (Gauge + Chart)
```

## What You Need

- ESP32 dev board
- DHT22 temperature/humidity sensor
- MQTT broker (Mosquitto, or use `test.mosquitto.org` for testing)
- Flintbay instance running ([Getting Started](../getting-started.md))

## 1. ESP32 Firmware (Arduino)

Install libraries: `PubSubClient`, `DHT sensor library`

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

#define WIFI_SSID     "your-wifi"
#define WIFI_PASS     "your-password"
#define MQTT_HOST     "192.168.1.100"  // your broker IP
#define MQTT_PORT     1883
#define MQTT_TOPIC    "sensors/esp32/temperature"
#define DHT_PIN       4
#define PUBLISH_INTERVAL_MS 2000

DHT dht(DHT_PIN, DHT22);
WiFiClient net;
PubSubClient mqtt(net);

void setup() {
  Serial.begin(115200);
  dht.begin();

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nWiFi connected: %s\n", WiFi.localIP().toString().c_str());

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
}

void reconnect() {
  while (!mqtt.connected()) {
    if (mqtt.connect("esp32-sensor")) {
      Serial.println("MQTT connected");
    } else {
      delay(2000);
    }
  }
}

void loop() {
  if (!mqtt.connected()) reconnect();
  mqtt.loop();

  static unsigned long lastPublish = 0;
  if (millis() - lastPublish >= PUBLISH_INTERVAL_MS) {
    lastPublish = millis();

    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    if (!isnan(temp)) {
      // Publish as JSON
      char payload[64];
      snprintf(payload, sizeof(payload),
        "{\"temperature\":%.1f,\"humidity\":%.1f}", temp, hum);
      mqtt.publish(MQTT_TOPIC, payload);
      Serial.println(payload);
    }
  }
}
```

The ESP32 publishes every 2 seconds:
```json
{"temperature": 23.5, "humidity": 45.2}
```

## 2. MQTT Broker (if self-hosting)

Quick Mosquitto setup alongside Flintbay:

```yaml
# Add to your docker-compose.yml
services:
  mosquitto:
    image: eclipse-mosquitto:2
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
    restart: unless-stopped
```

`mosquitto.conf`:
```
listener 1883
allow_anonymous true
```

## 3. Flintbay Configuration

### Create Source

1. **Sources** → **+ Add Source**
2. Name: `ESP32 Broker`
3. Protocol: **MQTT**
4. Host: `mosquitto` (Docker service name) or `192.168.1.100`
5. Port: `1883`

### Create Endpoints

Create two endpoints on the source:

**Temperature endpoint:**
- Name: `Temperature`
- Direction: In
- Topic: `sensors/esp32/temperature`

**Humidity endpoint:**
- Name: `Humidity`
- Direction: In
- Topic: `sensors/esp32/temperature`

> Both endpoints use the same topic — we'll use `payload_path` in bindings to extract different fields.

### Build the Dashboard

Create a screen `ESP32 Monitor` with a page `Environment`.

Add widgets:
| Widget | Type | Config |
|--------|------|--------|
| Temperature | WGauge | min: 0, max: 50, unit: °C |
| Humidity | WGauge | min: 0, max: 100, unit: % |
| Temp History | WChart | label: Temperature |
| Status | WIndicator | label: Sensor Online |

### Create Bindings

**Binding Group: "Temperature Reading"**
- Endpoint: `Temperature`
- Direction: In
- Mappings:
  - WGauge (Temperature) → port `value` → payload_path: `temperature`
  - WChart (Temp History) → port `value` → payload_path: `temperature`

**Binding Group: "Humidity Reading"**
- Endpoint: `Humidity`
- Direction: In
- Mappings:
  - WGauge (Humidity) → port `value` → payload_path: `humidity`

### Add a Transform (optional)

If your sensor outputs raw ADC values (0–4095) instead of degrees:

- Transform: `map_range`
- Params: `{"from": [0, 4095], "to": [-10, 50]}`

This maps the raw ADC range to -10°C to 50°C.

## 4. Test Without Hardware

Simulate the ESP32 with `mosquitto_pub`:

```bash
# Single reading
mosquitto_pub -h localhost -t "sensors/esp32/temperature" \
  -m '{"temperature": 23.5, "humidity": 45.2}'

# Continuous simulation (every 2s)
while true; do
  TEMP=$(echo "scale=1; 20 + $RANDOM % 100 / 10" | bc)
  HUM=$(echo "scale=1; 40 + $RANDOM % 200 / 10" | bc)
  mosquitto_pub -h localhost -t "sensors/esp32/temperature" \
    -m "{\"temperature\":$TEMP,\"humidity\":$HUM}"
  sleep 2
done
```

## Result

You should see:
- Temperature gauge updating every 2 seconds
- Humidity gauge tracking ambient moisture
- Chart building a time-series history
- All data flowing in real time via WebSocket to the browser

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Gauge shows no data | Check payload_path matches your JSON field name |
| Source shows disconnected | Verify broker host is reachable from Flintbay container |
| ESP32 won't connect | Check WiFi credentials and broker IP |
| Data arrives but chart is empty | Ensure endpoint has `history_size > 0` in config |

## Next Steps

- Add a [WToggleSwitch](../widgets.md) to control a relay on the ESP32
- Set up [Push Notifications](../push-notifications.md) for temperature alerts
- Use [Transforms](../transforms.md) to add deadzone filtering for noisy sensors
