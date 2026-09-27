# RTSP Cameras

To show an IP camera that speaks RTSP (or RTMP or SRT) in a **WStream** widget, register it as a
**media Source** and attach one of its streams to the widget. The built-in media gateway pulls the
camera once, for every viewer, and delivers WebRTC with an LL-HLS fallback. Latency is well under a
second on the WebRTC path. See [Live video](environment.md#live-video) for the ports it needs.

> **Typing `rtsp://…` straight into a WStream does not play.** The widget shows **Gateway required —
> not yet available** instead. Since 0.1.0, a direct RTSP URL has to go through a media Source.

## Add the Camera

1. **Sources** → **Add Source**, kind **Media**, use case **IP camera / live video**.
2. Enter the stream URL, for example:

   ```
   rtsp://192.168.1.100:554/stream1
   rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0
   ```

   Credentials in the URL stay on the server. The browser receives a media route for the stream,
   never the camera's address.
3. Save. Each stream of the Source appears as an endpoint.
4. Open **Connection Studio**, select the WStream widget, and choose **Attach here** on the stream.

Browser-playable URLs (HLS `…m3u8`, DASH `…mpd`, WHEP, MJPEG, `mp4`/`webm`) can still be typed
straight into the widget. They play without the gateway.

## Requirements

- `FLINTBAY_MEDIA_GATEWAY_ENABLED` left at its default `true`.
- Port `8189` (UDP, and TCP for networks that block UDP) published and reachable from the browser.
  Without it, playback falls back to LL-HLS over `19580`, about a second slower.
- Network reachability from the container to the camera.
- A codec the browser can decode. In practice that means **H.264** video; nothing is re-encoded.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| **Gateway required — not yet available** on a widget with a typed `rtsp://` URL | Expected: register the camera as a media Source and attach its stream |
| **Gateway required — not yet available** on an attached stream | The gateway process is not answering. Check it: `docker exec flintbay supervisorctl -c /etc/supervisor/conf.d/flintbay.conf status mediamtx` |
| An `HLS` badge in the corner of the video | The WebRTC port is not reachable from that browser. Open `8189` in the firewall or security group |
| Black player, no error | The camera is unreachable from the container, or it sends a codec the browser cannot decode (usually H.265). Switch the camera's stream to H.264 |
| Works in VLC, not here | Same as above. VLC decodes codecs browsers do not |

## The Legacy `/stream-proxy` Endpoint

The API still serves the older WebSocket at `/api/stream-proxy/ws?url=rtsp://…`. It runs one ffmpeg
process and one camera connection **per viewer**, repackages the video to MPEG-TS without audio,
and sends it over the socket. No current widget uses it; it stays for clients built against it and
will not be removed without an announced migration.

It authenticates the session cookie, and accepts `?token=` only where
`FLINTBAY_REALTIME_ALLOW_QUERY_TOKEN=true`. It refuses URLs that are not `rtsp://` or `rtsps://`,
that contain shell metacharacters, or that resolve to cloud metadata and reserved address ranges.
`FLINTBAY_ALLOW_PRIVATE_HOSTS=false` additionally refuses hosts that are, or resolve to, private
and loopback addresses. Camera credentials are removed from its logs. Each account may hold 8
concurrent proxy streams, and the deployment 32.

> Before 0.1.7, the private-host check covered only address literals and the camera URL was logged
> with its credentials. The proxy could also stall on a stream that produced many decoder warnings.
