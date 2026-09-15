# Contributing

Flintbay is free to use and actively developed by a solo developer. Bugs get fixed and
sensible features get added — but only for problems that reach me in a form I can act on.
That is what this document is about.

## Where to take what

| You have | Take it to |
|---|---|
| A bug — something behaves differently than documented | [Open a bug report](https://github.com/flintbayhq/flintbay/issues/new/choose) |
| A missing capability, widget, or connector | [Open a feature request](https://github.com/flintbayhq/flintbay/issues/new/choose) |
| A question — how to wire a device, whether something is possible | [Discord](https://discord.gg/ptCvyXAAnV) |
| A security vulnerability | **Not a public issue.** See [SECURITY.md](SECURITY.md) |
| A documentation error | A pull request here, or an issue if you would rather not edit |

Discord is faster for questions because a question is usually answered in one exchange. An
issue is better for a bug because it keeps the reproduction, the diagnosis, and the fix in one
place that the next person can find by searching.

## What lives in this repository

The documentation, the deployment Compose file, and these issue templates. Flintbay itself ships
as a ready-to-run container image rather than as source, so changes to how the application behaves
come from me rather than from a pull request.

That shapes what helps most here. In a project where you could open the code and send a patch, a
rough bug report is a starting point. Here it is the whole input — so a report I can reproduce
without three rounds of follow-up questions is the single most useful thing you can send.

What a pull request here *can* change: anything under `docs/`, the `README`, the deployment
`docker-compose.yml`, and these templates.

## What makes a bug report actionable

The [bug report form](https://github.com/flintbayhq/flintbay/issues/new/choose) asks for these,
and this is why:

- **The version, from the container itself.** Run `docker exec flintbay cat /app/release.json`.
  It reports the version, git revision, and protection profile. A tag is not enough — `latest`
  moves, and a locally cached image may be older than you think.
- **The host architecture and device.** A Jetson, a Raspberry Pi, and a cloud VM fail
  differently, especially around live video and memory limits.
- **Which connector and which widget.** Faults usually live in a combination — this payload,
  through that transform, into that port — rather than in one component.
- **Steps from a reachable starting state.** Ideally from the README's unmodified Compose file.
  If it only reproduces with your reverse proxy or external PostgreSQL, that fact is itself the
  clue.
- **Logs.** `docker logs flintbay --tail 200`. Setting `FLINTBAY_LOG_LEVEL=INFO` or `DEBUG`
  before reproducing usually exposes the cause directly.

Strip credentials, tokens, private hostnames, and any customer data before pasting. This applies
to logs and Compose files alike; both routinely contain more than people expect.

Report against the newest published stable version when you can. Fixes ship forward, in the next
release, so a bug confirmed on an old version still has to be confirmed on the current one before
it can be fixed. See [upgrading](docs/upgrading.md).

## Reporting against real hardware

Flintbay sits between a browser and a machine, so a symptom you see in a widget may originate in
the network or the device. Narrowing this before filing saves the most time:

- Does the raw data arrive at all? Subscribe with `mosquitto_sub`, run `ros2 topic echo`, or
  `curl` the REST endpoint from the same host the container runs on.
- Does Connection Studio show the observed field, or does discovery come up empty?
- Does the source report connected while nothing flows, or does it report a failure?
- For live video: does it play as LL-HLS but not WebRTC? That points at port `8189` being closed
  rather than at the media pipeline.

An answer of "I do not know" to any of these is fine — say so rather than guessing. A wrong guess
in a report costs more than a gap.

## Feature requests

Describe the machine you are building and what blocks you, before describing the fix you have in
mind. Sometimes an existing widget, transform, or ACK mode already covers it. Sometimes the
request points at one place and the real fix belongs somewhere else. Either way the problem
statement survives longer than the proposal.

Requests are weighed against each other rather than queued, and something that unblocks a working
deployment tends to move first. You will get an honest answer about whether it is planned, which
may be no.

## What to expect

One developer, no support contract, no response-time guarantee. In practice:

- Security reports are acknowledged within 72 hours — that one *is* a commitment, see
  [SECURITY.md](SECURITY.md).
- Everything else gets looked at, but a quiet week happens.
- An issue that needs information gets a `needs-info` label and a question. Without an answer it
  eventually gets closed, and reopening it later is fine.
- A closed issue is not a verdict on whether the problem is real, only on whether it is
  currently actionable.

If Flintbay is load-bearing for something you are building and you need more than that,
[let's talk](https://flintbay.io/) — custom widget development and direct arrangements are
available.

## Documentation pull requests

No build step and no toolchain: the docs are Markdown, rendered by GitHub. Edit the file, open a
pull request, and describe how you verified the change.

Two things to match:

- **Verify commands and values against a running deployment** before changing them. The docs make
  specific factual claims — port numbers, environment defaults, route paths — and a plausible but
  untested correction is worse than the original error, because it reads as confirmed.
- **Follow the surrounding voice.** The docs explain *why* a thing is the way it is, not only what
  to type. Keep that.

Typos, broken links, and unclear wording need no verification. Send those freely.

## Licensing

The contents of this repository — the documentation, the Compose file, these templates — are MIT
licensed, as stated in [LICENSE](LICENSE). By opening a pull request you agree that your
contribution is offered under the same terms.

The Flintbay image is free to download, self-host, and use commercially, with no subscription or
license key. It is distributed as a built image rather than as source, so building or forking the
application is not part of what it offers — using it, on as many machines as you like, is.

## Code of conduct

There is no formal document. The expectation is ordinary professional courtesy: assume good faith,
keep it about the technical problem, and remember that the person reading your issue built this
and is giving it away.
