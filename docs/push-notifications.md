# Push Notifications API

Flintbay supports Web Push notifications. Users subscribe through the browser, and you can trigger notifications programmatically via a service-to-service endpoint.

## How It Works

1. **Users subscribe** — the browser prompts for notification permission; the subscription is stored per-workspace.
2. **You send** — call the `/api/push-subscription/notify` endpoint with an internal API key.
3. **Users receive** — all subscribers in the target workspace get the notification, even if the tab is closed.

## Setup

Set these environment variables to enable push notifications:

| Variable | Description |
|----------|-------------|
| `FLINTBAY_VAPID_PUBLIC_KEY` | VAPID public key (base64url) |
| `FLINTBAY_VAPID_PRIVATE_KEY` | VAPID private key (base64url) |
| `FLINTBAY_VAPID_CONTACT_EMAIL` | Contact email for VAPID (e.g. `mailto:you@example.com`) |
| `FLINTBAY_INTERNAL_API_KEY` | Secret key for service-to-service auth |

Generate VAPID keys:

```bash
npx web-push generate-vapid-keys
```

## Sending Notifications

### Endpoint

```
POST /api/push-subscription/notify
```

### Authentication

Use the `Flintbay-Api-Key` header with the value of your `FLINTBAY_INTERNAL_API_KEY` environment variable.

```bash
curl -X POST http://localhost:19580/api/push-subscription/notify \
  -H "Content-Type: application/json" \
  -H "Flintbay-Api-Key: your-internal-api-key" \
  -d '{
    "workspace_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "title": "Watering Complete",
    "body": "Zone 3 finished — 12 liters dispensed.",
    "url": "/",
    "tag": "watering-zone-3"
  }'
```

### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `workspace_id` | UUID | ✅ | Target workspace — all subscribers receive the notification |
| `title` | string | ✅ | Notification title (max 256 chars) |
| `body` | string | ✅ | Notification body text (max 1024 chars) |
| `url` | string | — | URL to open on click (default: `/`) |
| `tag` | string | — | Grouping tag — replaces existing notification with same tag |
| `renotify` | boolean | — | Re-alert even if a notification with the same tag exists (default: `false`) |
| `icon` | string | — | Icon URL (defaults to app icon) |
| `actions` | array | — | Action buttons (see below) |

### Actions

```json
{
  "actions": [
    { "action": "view", "title": "View Dashboard" },
    { "action": "dismiss", "title": "Dismiss" }
  ]
}
```

> **Note:** Action button support varies by browser and OS. Chrome on Android supports up to 2 actions; desktop browsers may show more or none.

### Response

```json
{
  "total": 5,
  "sent": 4,
  "failed": 0,
  "expired": 1
}
```

| Field | Description |
|-------|-------------|
| `total` | Subscriptions targeted |
| `sent` | Successfully delivered |
| `failed` | Send failures (network, server errors) |
| `expired` | Invalid/expired subscriptions (auto-removed) |

## Example: Notify on Sensor Alert

```python
import httpx

httpx.post(
    "http://flintbay:19580/api/push-subscription/notify",
    headers={"Flintbay-Api-Key": "your-internal-api-key"},
    json={
        "workspace_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "title": "🚨 Temperature Alert",
        "body": "Sensor T1 exceeded 85°C threshold.",
        "url": "/",
        "tag": "temp-alert-t1",
        "renotify": True,
    },
)
```

## Rate Limit

60 requests per minute per API key.
