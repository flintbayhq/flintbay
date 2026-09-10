# RTSP Stream Proxy

An RTSP URL typed into a **WStream** widget plays in the browser without opening the camera to the
internet and without a plugin. The server dials the camera, repackages the video stream and forwards
it over a WebSocket.

> **For a new camera, register a media Source instead.** The proxy on this page spawns **one ffmpeg
> process and one camera connection per viewer**, and delivers video only. A media Source routes the
> same camera through the built-in gateway, which pulls it once for every viewer and delivers WebRTC
> with LL-HLS fallback — sub-second rather than several seconds. See
> [Live video](environment.md#live-video). This path stays supported for existing widgets and will
> not be removed without an announced migration.

## What Actually Happens

```
IP camera (RTSP) → ffmpeg, one per viewer (repackage) → WebSocket → browser (MSE)
```

The ffmpeg invocation is:

```
ffmpeg -rtsp_transport tcp -i <url> -c:v copy -an -f mpegts -flush_packets 1 pipe:1
```

Three consequences follow from that command, and each of them surprises somebody:

**Nothing is re-encoded.** `-c:v copy` repackages the camera's existing video stream into MPEG-TS. It
does not convert it. The browser therefore has to be able to play whatever the camera already sends,
which in practice means **H.264** — there is no fallback that would produce it.

**There is no audio.** `-an` drops it. The proxy carries video only.

**Each viewer costs a camera connection.** There is no shared process and no fan-out: two people
looking at the same camera open two ffmpeg processes and two RTSP sessions. Cameras commonly cap
concurrent sessions at two or four, which is the usual cause of the third viewer seeing nothing.

## Requirements

- `ffmpeg` on the server's `PATH` — present in the official image. Without it the socket closes with
  code `1011`.
- Network reachability from the container to the camera.
- A browser with Media Source Extensions, which is all of them.

## Usage

Place a **WStream** widget and set its stream URL:

```
rtsp://192.168.1.100:554/stream1
rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0
```

The URL never reaches the browser — it is resolved server-side, and the browser is only given the
WebSocket endpoint. Credentials embedded in it stay on the server.

To switch cameras at runtime, bind the widget's `stream_url` port to an endpoint that supplies the
address as a string.

## Protocol Handling

WStream picks its transport from the URL, and only RTSP involves the proxy:

| URL | Transport | Proxy |
|---|---|---|
| `rtsp://`, `rtsps://` | MPEG-TS over WebSocket | Yes — ffmpeg, one process per viewer |
| `…m3u8` | HLS | No — the browser plays it |
| `…mpd` | DASH | No — the browser plays it |
| `…mjpeg…` | MJPEG | No — a plain `<img>` |
| `ws://`, `wss://` | Custom | No — the socket is opened directly |

## What the Proxy Refuses

The WebSocket is authenticated before ffmpeg is started: the session cookie, or `?token=` for
clients that cannot send one. An absent or invalid token closes the socket with `4001`.

The URL is then checked, in this order:

1. The scheme must be `rtsp://` or `rtsps://`.
2. The URL must contain none of `; | & ` $` or a newline — a shell metacharacter in an address is not
   a camera, and the address becomes an argument to a subprocess.
3. If `FLINTBAY_ALLOW_PRIVATE_HOSTS=false`, loopback, private, link-local and reserved literals are
   refused. The default is `true`, because a camera on the LAN is the normal case.
4. **Always, regardless of that setting**, the hostname is resolved and the resulting address
   classified: cloud metadata endpoints (`169.254.169.254` in any spelling) and reserved ranges are
   refused. This is what stops the field being used to read instance credentials, so it is not
   configurable.

## Cost

No encoding happens, so CPU is dominated by moving bytes rather than by the resolution of the
picture — a 1080p stream is not meaningfully more expensive to repackage than a 480p one, while its
bandwidth is. What scales badly is viewers: each one is a separate process, a separate RTSP session
and a separate copy of the stream leaving the camera.

If more than one or two people watch the same camera, the media gateway is the right answer rather
than a tuning exercise on this one.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| Black player, no error | The camera is unreachable from the container. Test it there: `docker exec flintbay ffmpeg -i rtsp://… -t 1 -f null -` |
| Plays for one person, not the second | The camera's concurrent-session limit. Register it as a media Source so it is pulled once |
| No sound | Expected — the proxy drops audio |
| Plays nowhere, camera works in VLC | The camera is probably not sending H.264. Nothing here converts it; switch the camera's codec or use a media Source |
| Socket closes immediately with `1011` | `ffmpeg` is missing from the image |
| Socket closes with `4001` | The request carried no valid session |
| Latency of several seconds | Inherent to this path. Use the camera's sub-stream to reduce it, or the gateway to replace it |
