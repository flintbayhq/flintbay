# RTSP Stream Proxy

Flintbay includes a built-in RTSP-to-browser proxy. View IP camera feeds directly in your dashboard without exposing RTSP ports to the browser or installing plugins.

> **Prefer a media Source for new cameras.** This page describes the original
> path: an RTSP URL typed straight into a widget, transcoded by one ffmpeg
> process per stream. Registering the camera as a media Source instead routes it
> through the built-in media gateway, which pulls the camera once for all
> viewers and delivers WebRTC with LL-HLS fallback — sub-second instead of
> several seconds, and no per-viewer ffmpeg. See
> [Live video](environment.md#live-video). The path below stays supported for
> existing widgets and is not going away without an announced migration.

## How It Works

```
IP Camera (RTSP) → Flintbay Server (ffmpeg transcode) → Browser (WebSocket → MSE)
```

1. You place a **WStream** widget and set the stream URL to an RTSP address
2. Flintbay spawns an ffmpeg process that connects to the RTSP source
3. ffmpeg transcodes to MPEG-TS (H.264 + AAC)
4. The transcoded stream is forwarded as binary WebSocket frames to the browser
5. The browser plays it using Media Source Extensions (MSE)

## Requirements

- **ffmpeg** must be installed in the Flintbay container (included in the official image)
- The Flintbay server must have network access to the RTSP camera
- Browser must support MSE (all modern browsers)

## Usage

### 1. Place a WStream Widget

Add a **WStream** widget to your page. Set the stream URL parameter to your RTSP address:

```
rtsp://192.168.1.100:554/stream1
```

Or with authentication:
```
rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0
```

### 2. Bind Dynamically (Optional)

You can bind the `stream_url` port to an endpoint, allowing dynamic camera switching:

- Create an endpoint that provides the RTSP URL as a string
- Bind it to the WStream widget's `stream_url` port
- Change the URL at runtime to switch cameras

## Supported Protocols

WStream auto-detects the protocol from the URL:

| URL Prefix | Protocol | Proxy Used |
|------------|----------|------------|
| `rtsp://` | RTSP | ✅ Yes (ffmpeg transcode) |
| `http://*.m3u8` | HLS | No (native browser) |
| `http://*.mpd` | DASH | No (native browser) |
| `http://*mjpeg*` | MJPEG | No (native `<img>` tag) |
| `ws://` / `wss://` | WebRTC/Custom | No (direct WebSocket) |

## Security

- The proxy only accepts connections from authenticated users
- RTSP URLs are not exposed to the browser — the browser only sees the WebSocket endpoint
- Private network addresses (192.168.x.x, 10.x.x.x) are allowed by default
- Set `FLINTBAY_ALLOW_PRIVATE_HOSTS=false` to block connections to private IPs

## Performance Notes

- Each active stream spawns one ffmpeg process
- Typical resource usage: ~50–100 MB RAM, 5–15% CPU per 1080p stream
- Multiple viewers of the same stream share one ffmpeg process
- Stream stops automatically when the last viewer disconnects

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Black screen | Check RTSP URL is reachable from the Flintbay container (`docker exec flintbay ffmpeg -i rtsp://... -t 1 -f null -`) |
| High latency | Use the camera's sub-stream (lower resolution) for real-time control |
| "ffmpeg not found" | Ensure you're using the official Flintbay image (ffmpeg is pre-installed) |
| Connection refused | Camera may limit concurrent RTSP connections — close other viewers |
