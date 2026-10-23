# Changelog

What changed in each release, and which image it is.

The release artifact is the container image named under each version. Its index digest is what
[cosign signs](SECURITY.md), so the digest — not this file and not a tag — is what identifies a
release. Deployments learn that a newer version exists by reading the release feed at
`https://flintbay.io/releases.json` and comparing it against their own version locally; nothing
about the deployment is sent anywhere.

Headings are the bare version, so the anchor for a version is its number without the dots:
`#012` for 0.1.2.

## 0.1.11

Released 2026-10-22.

- Security: the API and MCP server are now compiled to native machine code (Nuitka) for both
  architectures, replacing PyArmor. No Python source or bytecode ships, and the API's explanatory
  docstrings are stripped, so there is nothing left for a Python decompiler or unpacker to recover.
- The protection metadata follows: `/app/release.json` reports `"protection": "nuitka"`,
  `/app/protection.json` has profile `nuitka`, and the OCI labels
  `io.flintbay.protection.profile=nuitka` and `io.flintbay.protection.tool=nuitka-4.3.1` replace
  `io.flintbay.protection.pyarmor`. Anything that checked the old label or value needs updating.
- Security: the image no longer serves Swagger UI, ReDoc or `/api/openapi.json`, in any mode.
  `FLINTBAY_API_ENABLE_DOCS` is retired and only logs a warning if it is still set.
- The command audit trail records what a command actually sent again — the delivered value and
  its counts — instead of only that something was sent.
- Video and stream widgets play through an updated video.js integration.
- The image's licence label, `org.opencontainers.image.licenses`, is now
  `LicenseRef-Flintbay-EULA`, and the new labels `io.flintbay.license.terms` (`/app/EULA.txt`) and
  `io.flintbay.license.url` point at the [EULA](EULA.txt) that governs the image; earlier images
  wrongly said `MIT`.
- Nothing else changes in how Flintbay is configured or run: the same ports, environment
  variables and volume.

```
ghcr.io/flintbayhq/flintbay:0.1.11
index  sha256:130fc3220a968566ef2c329a3dbb8938914d74d3ea85193280441f53c9bc2f44
amd64  sha256:08ab3e2a8f4e8806c91c3f12b2cc6c158fb4312f6797443799c40b5be7d45c8a
arm64  sha256:0371829e0e13c6435dac0d0edd4ceda03f99552895488cac0b0a2d6f9865cf9c
```

## 0.1.10

Released 2026-10-22.

- Security: carries certifi 2026.10.19, which no longer trusts the emSign ECC Root CA - G3 after
  eight of its eMudhra intermediates were compromised (GHSA-6q48-6c7w-9gw2). MediaMTX 1.21.2, still
  the latest release, predates Go's hard block of those intermediates (CVE-2026-111943); the media
  gateway verifies against the image's system store, which holds no emSign G3 root, so no chain
  through them can be built.
- Security: carries the current Debian fixes for expat (CVE-2026-66046, CVE-2026-76956,
  CVE-2026-76957, CVE-2026-77214, CVE-2026-93990).
- Connecting a widget on the page that is already open shows its data at once. MQTT, WebSocket and
  ROS 2 widgets used to say "No data" until the page was reloaded.
- A pasted camera address can be added. The track type and direction are asked as plain choices
  instead of a JSON editor, the Endpoint no longer fails validation after its Source was created,
  and a camera attached from the widget's own Bindings tab stays attached after leaving the editor.
- A second address from the same device — a camera on RTSP and telemetry on REST, say — gets its
  own Source named after its kind instead of failing with "source already exists". Abandoning a
  paste halfway no longer leaves an empty Source behind, and a ROS 2 bridge or broker pasted
  without a topic can be opened to choose what to read.
- A joystick held still keeps the robot moving: repeated commands are sent, not dropped as
  "unchanged", so the robot's own watchdog no longer stops it between them. Controls that only send
  no longer wear a "No data" marker.
- Smaller fixes: a text size such as 2.5 can be typed; a Gauge that is not connected yet previews a
  value inside its own range; the widget palette stays open while a widget is dragged from it; the
  Compass letters scale to the dial.

```
ghcr.io/flintbayhq/flintbay:0.1.10
index  sha256:c13ea7296dd75b645cfb2952b2294eb00ea7c4739b3589931ff1dedddfd85b5e
amd64  sha256:f740d17f8be321b47fb703a7a3b3aff343519d05af0b0c47641f1f55bbb09921
arm64  sha256:c743aeaf121981292d4657adcef8d4319a06be007f4c325c0b794034f44c7031
```

## 0.1.9

Released 2026-10-15.

- Security: carries MediaMTX 1.21.2, which also refuses cross-site browser `POST`s from origins
  outside its allow list. The Go standard library advisories for HTTP/2 and TLS that 0.1.8 carried
  are fixed. One `golang.org/x/net` advisory (CVE-2026-78669) remains until MediaMTX publishes its
  fix; the media gateway's HTTP listeners are reachable only through the built-in proxy, over
  HTTP/1.1, so its HTTP/2 server is never exposed.
- Security: carries the current Debian fixes for curl (CVE-2026-8286, CVE-2026-8927,
  CVE-2026-92392).
- Every dependency moved to its current release: FastAPI 0.143, Starlette 1.8, uvicorn 0.54,
  pydantic 2.14, SQLAlchemy 2.1, Alembic 1.20, websockets 17 and cryptography 50.0.2 on the server;
  Vue 3.5.44, PrimeVue 5.0.2, Pinia 4.1 and Vite 8.3 in the browser. Nothing changes in how
  Flintbay is configured or run.

```
ghcr.io/flintbayhq/flintbay:0.1.9
index  sha256:a20e9c9ad74dd5048ffd9ef6c51a711688aa3fb42018f926ee3dc9460e680aef
amd64  sha256:b5e3d93e913f3a296674095c47bfff8b1204b2fafe1d05ae252a1515c635d546
arm64  sha256:edee5f320aa738b096ed82be9b600b2731ab5ff17ef2f2115cef66835ce7aaf3
```

## 0.1.8

Released 2026-10-05.

- Security: carries PyJWT 2.15.1. The previous version had advisories for token forgery and
  authentication bypass (CVE-2026-102268 and five related ones).
- Security: carries urllib3 2.8.0, axios 1.20.0 and DOMPurify 3.4.16, and the current Debian fixes
  for OpenSSL, PCRE2 and the bundled Redis.
- A new page says what to do next. A page with no widgets shows a card in the middle of the canvas:
  turn on the editor, or add the first widget. A reader who may not edit is told the page is empty.
- The add-widget button is larger.
- Connection Studio shows where a connection goes, whatever is collapsed. Pointing at a port, a field
  or a feed lights exactly one row for each end of its connections: the end itself, or, faintly, the
  closed source, feed, field or widget it is hidden in. The line ends on that same row. Pointing at an
  object field lights the bound fields inside it.
- Every Connection Studio row highlights across its full width, and pointing anywhere on it shows its
  connections, not only over its label. Grey means the cursor alone; blue means part of a connection.

```
ghcr.io/flintbayhq/flintbay:0.1.8
index  sha256:8eb9de734173d540c7a87d6da79e81cc2facf33a697c7b732eb52f608090e474
amd64  sha256:8ad9fda84ef6268321990387673f8c919555f3f2de74653f348bad2dd574eb3c
arm64  sha256:7cccf9042a5e46fc7ab0edcc064aec4023271fa506d2af1d537e9b6f65e7939b
```

## 0.1.7

Released 2026-09-27.

- Security: refresh tokens can no longer be raced. Two refreshes presenting the same token at the
  same moment used to both succeed, and the check that revokes every session when a replaced token
  comes back did not see it. Now only one replaces the token. A second tab of the same browser within
  10 seconds gets an access token and nothing more
  (`FLINTBAY_SESSION_REFRESH_REUSE_GRACE_SECONDS`), and each use of that window is logged. Later
  reuse is treated as theft, as before.
- Security: a signed-in request belongs to the account its session belongs to, not to the username
  written in the token. Renaming an account no longer breaks its open sessions, and its old name,
  once given to someone else, no longer lets a still-valid token act as that account.
- Security: rotating an API key keeps exactly its scopes and its lifetime. A key whose scopes matched
  no current preset came back as a `full` key, every rotated key came back with 90 days, and an
  expired key could be rotated back to life. Revoking the old key and creating the new one are now
  one step, so a failure leaves the old key working.
- Security: the legacy `/api/stream-proxy` socket no longer logs camera passwords. It refuses names
  that resolve to private addresses when `FLINTBAY_ALLOW_PRIVATE_HOSTS=false`, and limits each
  account to 8 concurrent streams (32 in total). It also accepts `?token=` only where query tokens
  are enabled, and it no longer freezes on a stream that produces many decoder warnings.
- Security: the memory profiler's routes answer `404` while it is disabled and `401` for a wrong
  token, instead of `200`. The token is compared in constant time and can be sent in an
  `X-Memprof-Token` header, which proxies do not log.
- Rotating the JWT secret with `FLINTBAY_JWT_PREVIOUS_SECRET_KEY` set no longer breaks API keys or
  signs everyone out. A key or refresh token issued under the previous secret is accepted and moved
  to the new one when it is next used.
- The joystick can drive a robot directly. A new `twist` port sends a ready `geometry_msgs/Twist`:
  stick up drives forward, stick right turns right, and releasing the stick sends a zero Twist (with
  Return to Center on, the default). Two new settings cap the speed (m/s) and turn rate (rad/s). Bound
  to a `cmd_vel` topic it is sent as the whole message, so the key Connection Studio proposes works
  as-is. It is sent only while bound, so existing joysticks send exactly what they did before.
- `lowpass` smooths. In a binding, the filter forgot its previous value with every message and passed
  readings through unchanged. Each mapping and each direction now keeps its own filter memory, and
  a page that has just opened does not nudge it.
- A `chain` transform with an invalid step is refused when the binding is saved, and the error names
  the step. It used to be saved and then fail on every message.

```
ghcr.io/flintbayhq/flintbay:0.1.7
index  sha256:334a697773dca690d30f5d7a2722736e03b18f5f3b7cc1b37db3e29637f91bd3
amd64  sha256:7a725be71f874b7f6627f2b8e2e79c0917ab418c7751c3553d3de01d420b7c3c
arm64  sha256:261834e4c86a2fdd2bd566d663ba2dd3e8e2c4c5ef7932fbd2420a62603126e4
```

## 0.1.6

Released 2026-09-23.

- Security: the image carries a patched `anyio`. The previous version encoded TLS host names with
  IDNA 2003 ([CVE-2026-63374](https://avd.aquasec.com/nvd/cve-2026-63374)), which can be made to
  accept a certificate issued for a different name — reachable wherever a deployment talks to a
  source over TLS. Nothing needs to be reconfigured; upgrading the image is the fix.
- Turning a binding mapping off now actually stops it. The row was saved as disabled and the API
  reported success, but the widget kept receiving values until the deployment was restarted — two
  mappings feeding one port kept interleaving into a sawtooth. A group whose mappings are all
  disabled also no longer holds a subscription open for data nobody reads.
- Changing one widget setting over the API or from an MCP client no longer resets the others. A
  patch is merged into the stored settings, so sending a timeline's item limit keeps its horizontal
  orientation instead of silently turning it into a vertical list. The web editor was never
  affected, because it always sent every setting at once.
- A source that only subscribes while a page is open reports itself connected once data is
  flowing, instead of showing "connecting" for as long as the page stayed open.
- Bar charts draw their category labels: long names are shortened to fit, under the bars when they
  are vertical and beside them when they are horizontal. The labels port could be connected and
  delivering with nothing appearing.
- Connection Studio findings can be told apart. Each one carries its full message, and findings of
  the same kind are distinguished by a short identifier when the server sends no name.
- Ports and other numeric identifiers no longer show a thousands separator, so an MQTT port reads
  1883 rather than 1,883.
- The battery widget's terminal is sized from the battery's thickness, so a wide one no longer
  grows a nub wider than the battery is tall.

```
ghcr.io/flintbayhq/flintbay:0.1.6
index  sha256:ddf9103da8f865ab3883c1575ec5f3682e09925e88d11dcc42f48fed6b28013d
amd64  sha256:4dc62c5c976132a6e99e39faf0038bb00b2c2fa616321a5a4280b1e11002d06a
arm64  sha256:722b63d746af2e1a8daa1a92d445b24031eda4878a1bcc08a3c57f602ee73a23
```

## 0.1.5

Released 2026-09-18.

- Widgets dragged or resized on a phone now stay where they were put. The move was saved too late
  to survive a reload, a gesture the browser took over left the widget adrift on screen, and a
  second move could be overtaken by the answer to the first.
- Live video and audio, and the map, image and stream widgets, recover on their own after a
  connection drops or the network returns, instead of staying dark until the page is reloaded.
- A dashboard opened just after a reconnect shows its real values. Bindings are read again when the
  socket reopens, and the previous workspace's bindings no longer flash sample values over a
  configured page.
- Connection Studio is steadier: a long session no longer accumulates acknowledgement history, a
  commit that will keep being refused now says why instead of reporting progress for a whole lease
  window, and replacing a connection reports which Endpoint it leaves unreferenced.
- The widget editor only offers settings that apply to the style in use, so a choice that cannot
  take effect is no longer presented. With it: the joystick honours its repeat interval, arrow keys
  move whichever D-Pad has focus, an E-Stop with its own arm asks once, and the compass and map no
  longer point north for a heading they do not have.
- Existing D-Pads keep their layout and repeat interval across the upgrade.

```
ghcr.io/flintbayhq/flintbay:0.1.5
index  sha256:7f0d53d09c3e7925c40ca8a879de494b562df1dc7f39766f2e88c6622c636645
amd64  sha256:0167b4cb2134fe42e23dffa0813dff7c2057c88433ee7a83464e8e3993e5b45f
arm64  sha256:5eb445c2a22f864706487036dc2709a352239950557b8b4aa9dec1da996cb6dc
```

## 0.1.4

Released 2026-09-14.

- Live camera video now starts on hosts whose UDP receive buffer limit is at the system default. The
  media gateway asked for more than the kernel would grant and refused to run at all, which left
  every camera reporting that a gateway was required.
- API keys are refused on routes no scope can bound, and destructive permissions require a key issued
  for them.
- Workspace membership is stricter: nobody can change their own role or leave a workspace without an
  owner, and deactivated accounts stay visible as members.
- The divider widget draws bends, caps and routing correctly.

```
ghcr.io/flintbayhq/flintbay:0.1.4
index  sha256:1820688ca362d51a7b2d30ba3fe77f7911570ed22626c9c168504f7286c1537c
amd64  sha256:d40e20aa40fa4e21f59130e536cf25dd6ad66046b32d89815690db9b8f168d5f
arm64  sha256:c6bfab4bc2d216db8cb5a78b695d304c4fc1c6e159b3a66c2c7f4e46bb221f87
```

## 0.1.3

Released 2026-09-13.

- Connection Studio can now preview the first payload from an expanded readable endpoint and show
  its observed fields.
- Connecting fields to widgets now gives clearer waiting, error, and retry feedback.
- Media widgets and controls are more polished and resilient.

```
ghcr.io/flintbayhq/flintbay:0.1.3
index  sha256:858436797f1a262757f455528094417d6ed8d474181ae84aaf0bd1a155f8acd4
amd64  sha256:9bb5527c4abae9ebe324c2d27f00b063f44d45501a71621e60842f5f4ada2c44
arm64  sha256:b80c919125c071ae69c69756d2910203fd8048c09da54aa81d097ddaaf10b2d2
```

## 0.1.2

Released 2026-09-10.

- Pasting an address into Connection Studio no longer inserts it twice.
- The default font size now follows the form factor of the device you are on.

```
ghcr.io/flintbayhq/flintbay:0.1.2
index  sha256:237cc19ad09730d2835fc1c4c9cd60c7f9e992c752f980139e83922b5b97a073
amd64  sha256:03aca0a98dd72215330183266dfd61abd8b779776e4812cfda9ea594511d27cb
arm64  sha256:a8fee7fc1a7b548f4a9708c36ea68dba81d54581236ea15ab6997c5db3a8764c
```

## 0.1.1

Released 2026-09-08.

- The version shown in About is now read from the image itself, instead of a placeholder that
  always said 1.0.0.
- The interface tells you when a newer version has been released. The check compares versions on
  your deployment and sends nothing about it.
- Release verification in CI now pins every action by commit and checks each architecture by its
  own digest.

```
ghcr.io/flintbayhq/flintbay:0.1.1
index  sha256:67f8a427ee83625ddcf510cabe87dd488fef97cfa30cc1c25f79597b660a9a7e
```

## 0.1.0

Released 2026-09-08. First stable release.

- One protected multi-architecture image for amd64 and arm64.
- The published index is signed with cosign and can be verified before deploying.

```
ghcr.io/flintbayhq/flintbay:0.1.0
index  sha256:b934d968c031d7889b83ae8a0bba72d764ed9880927044bf79acc119122cfbde
```
