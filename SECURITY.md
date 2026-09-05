# Security Policy

## Reporting a vulnerability

**Do not open a public issue, discussion, or pull request for an undisclosed
security vulnerability.** Report it privately through one of these channels:

- Email **security@flintbay.io** with the subject prefix `[Flintbay SECURITY]`.
- Send a Discord DM to a maintainer in the
  [project server](https://discord.gg/ptCvyXAAnV).

Include enough information to reproduce and assess the issue:

- A concise description, affected component, and expected impact.
- Reproduction steps or a minimal proof of concept.
- What you tested. The container records it itself:
  `docker exec flintbay cat /app/release.json` reports the version, git
  revision, and protection profile. The image reference and index digest work
  too.
- Relevant configuration and logs, with credentials, tokens, personal data,
  private hostnames, and customer data removed.
- Whether the issue is already public or has an upstream advisory.

Do not send live secrets in the initial report. If sensitive material is needed,
ask the maintainer to agree on a transfer method first. If no acknowledgement
arrives within 72 hours, follow up through the other private channel.

You should receive an acknowledgement within 72 hours. For a confirmed
high-severity issue, the target is a fix or documented mitigation within 14 days;
complex fixes or coordinated upstream disclosures may take longer. Please allow
time for triage and remediation before publishing details, and coordinate a
disclosure date with the maintainer.

When testing, use systems and data you own or have explicit permission to test.
Stop after demonstrating impact, avoid persistence or data destruction, and do
not degrade service for other users.

## Supported versions

Releases are immutable. Version `X.Y.Z` is one multi-architecture index covering
`linux/amd64` and `linux/arm64`; the per-architecture tags `X.Y.Z-amd64` and
`X.Y.Z-arm64` are its parts. A stable version also moves `latest`; a prerelease
such as `X.Y.Z-rc.1` does not. An existing version tag is never overwritten.

| Distribution | Security support |
| --- | --- |
| Newest published stable `ghcr.io/flintbayhq/flintbay:X.Y.Z`, and `latest` while it points there | Supported |
| Older versions, prereleases, per-architecture tags, superseded digests, and downstream repackaging | Not supported |

Security fixes ship in the next published version. Pulling `latest` does not
update a running container and a locally cached image may be older, so pin
`X.Y.Z` or an index digest in production and record which one you tested when
reporting a problem. See [upgrading](docs/upgrading.md).

## Verifying a release

Each published index is signed with cosign through GitHub OIDC, after a workflow
verifies that it carries both expected platforms and that the two architecture
images agree on version and protection metadata. Verify before deploying:

```bash
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/flintbayhq/flintbay-core/\.github/workflows/build\.yml@' \
  ghcr.io/flintbayhq/flintbay:X.Y.Z
```

The identity names the private build repository; that is expected — the image is
built and released from there.

## Scope

In scope:

- The API and its authentication and authorization logic.
- The web dashboard.
- The MCP integration.
- Live media: the WebRTC/LL-HLS paths and the workspace authorization boundary
  in front of the media gateway.
- The all-in-one image, its entrypoint and process supervision, the bundled
  reverse-proxy rules, and the deployment Compose file in this repository.
- Security-sensitive defaults and controls: RBAC, rate limiting, account
  lockout, CSRF, CORS, security headers and CSP, secret handling, audit
  logging, and workspace isolation. See
  [security configuration](docs/security.md).

Out of scope:

- The shipped `admin` / `admin` login, absent a bypass. It applies only while
  `FLINTBAY_SUPERADMIN_PASSWORD` is unset, and while it is in force startup logs a
  warning, the boot `lifecycle` entry flags it, and the interface shows a
  banner. Change it before exposing the deployment.
- The unauthenticated Prometheus exposition at `GET /api/metrics` on the
  published port. That is documented behaviour: the image publishes one port and
  has no separate internal network, so hiding the exposition from outside would
  hide it from a scraper too. Restrict it at your own proxy or firewall, or set
  `FLINTBAY_METRICS_ENABLED=false`. A leak *within* the exposition, beyond the
  request, session, and connector counts it is documented to carry, is in scope.
- Plain HTTP on the published port. The bundled proxy deliberately does not
  terminate TLS; an external terminator is the documented topology. See
  [reverse proxy](docs/reverse-proxy.md).
- An upstream dependency issue with no demonstrated Flintbay-specific exposure or
  impact. If the supported image is exploitable, report it even when an upstream
  advisory already exists.
- Unsupported versions after the issue is fixed in the current supported one.
- Social engineering, phishing, and testing against deployments you do not own.

## Before exposing a deployment

The full guidance is in [security configuration](docs/security.md),
[environment](docs/environment.md), and [reverse proxy](docs/reverse-proxy.md).
The short version:

1. Set `FLINTBAY_PUBLIC_URL` to the exact external **HTTPS** origin. The container
   refuses to start on a value carrying credentials, a path, a query, or a
   fragment. It derives CORS, secure-cookie behaviour, MCP metadata, and the
   default WebRTC host.
2. Set `FLINTBAY_SUPERADMIN_PASSWORD` to a unique, strong value.
3. Terminate TLS in front. The bundled proxy listens on plain HTTP `19580` with
   automatic HTTPS off; do not expose that listener to an untrusted network.
4. Set `FLINTBAY_TRUSTED_PROXIES` only for a proxy that reaches the container from
   a non-loopback address, and only to that proxy's IPs or CIDRs. Trusting an
   address lets anything arriving from it choose its own client address for rate
   limiting and audit records.
5. Publish only `19580/tcp`, plus `8189/udp` and `8189/tcp` when live video is
   needed. Do not publish database, Redis, or media-gateway control ports.
6. Persist `/var/lib/flintbay` on durable storage, protect it as sensitive data,
   and copy verified backups off the volume. Replacing the volume regenerates
   the generated secrets and invalidates existing access tokens.
7. Run with `no-new-privileges:true`, no privileged mode, no host networking,
   no Docker socket mount, and bounded container-log rotation.
