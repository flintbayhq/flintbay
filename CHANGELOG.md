# Changelog

What changed in each release, and which image it is.

The release artifact is the container image named under each version. Its index digest is what
[cosign signs](SECURITY.md), so the digest — not this file and not a tag — is what identifies a
release. Deployments learn that a newer version exists by reading the release feed at
`https://flintbay.io/releases.json` and comparing it against their own version locally; nothing
about the deployment is sent anywhere.

Headings are the bare version, so the anchor for a version is its number without the dots:
`#012` for 0.1.2.

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
