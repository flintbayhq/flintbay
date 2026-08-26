# Realtime Performance Verification

This page records the reproducible performance verification for Flintbay's bounded realtime pipeline. It is evidence for behavioral correctness under controlled load—not a universal throughput claim or production SLA.

## Verdict

**PASS on the tested local Docker profile.** All five profiles completed without an invariant failure:

- connector and binding concurrency reached, but never exceeded, their configured limits;
- saturation produced explicit rejection or overflow instead of unbounded work;
- endpoint processing preserved exact per-endpoint FIFO order;
- lifecycle writers ran before queued readers, and endpoint generations did not overlap;
- one blocked WebSocket subscriber did not stop 64 healthy subscribers;
- only pending live state was coalesced; accepted critical messages completed;
- a 15-second mixed soak retained no extra asyncio tasks and showed no RSS growth after warm-up.

This result does **not** measure browser-to-server network latency, authentication, database queries, external MQTT/REST/ROS 2 systems, multiple API workers, or target edge hardware. Rerun the same harness on your deployment class before setting capacity limits or SLAs.

## Test environment

Captured on **2026-07-18 at 14:53–14:54 UTC**.

| Item | Value |
|---|---|
| Execution | Local Docker API container |
| Source provenance | `cec8746297790e1ba610556a0b96c002ac28b770+dirty-slices-2-8` (custom `--revision` tag for uncommitted slices #2–#8) |
| Host/container platform | Linux 6.17.0-40, x86_64, 8 logical CPUs |
| Python | 3.13.14 |
| Preset | `standard` |
| Steady operations | 1,024 per connector/binding profile |
| Endpoint workload | 32 endpoints × 64 events = 2,048 accepted events |
| Fan-out workload | 64 healthy subscribers + 1 blocked subscriber |
| Artificial operation delay | 1 ms |
| Soak | 15 seconds |
| Per-profile timeout | 45 seconds |

The harness is dependency-free beyond Flintbay's own runtime. It imports the production `ConnectorSendGate`, `BindingOperationGate`, `EndpointIngressCoordinator`, `ConnectionOutbox`, and `ConnectionManager`; algorithms are not copied into a synthetic benchmark implementation.

## Results

| Profile | Operations | Throughput | p50 | p95 | p99 | Result |
|---|---:|---:|---:|---:|---:|---|
| Connector admission | 1,041 | 5,286.91 ops/s | 1.494 ms | 1.657 ms | 1.815 ms | PASS |
| Binding processing | 1,034 | 5,362.77 ops/s | 1.495 ms | 1.680 ms | 1.790 ms | PASS |
| Endpoint ingress | 2,050 | 5,603.16 ops/s | 184.892 ms | 338.563 ms | 351.337 ms | PASS |
| WebSocket outbox/fan-out | 173 | 13,979.58 ops/s | 4.890 ms | 4.890 ms | 4.890 ms | PASS |
| Mixed soak | 398,160 | 26,421.50 ops/s | 1.616 ms | 1.815 ms | 2.670 ms | PASS |

### How to read the numbers

These are in-process micro/integration measurements of the realtime boundaries. They are useful for regression comparison on equivalent hardware, not as a promise that every Flintbay deployment will sustain the same rate.

Endpoint ingress latency intentionally includes queue residence from submission to completion. The profile submits 2,048 events while allowing eight endpoints to execute concurrently and serializing each endpoint's own events. Its ~351 ms p99 therefore demonstrates bounded FIFO backlog behavior under a burst; it is not the service time of one endpoint callback.

The outbox latency is the time for every healthy subscriber to progress while one subscriber is blocked. The blocked subscriber was released only after all 64 healthy sinks had written.

## Behavioral evidence

| Invariant | Observed evidence |
|---|---|
| Connector bound | Peak active `8/8`; 5 overload attempts explicitly rejected |
| Binding bound | Peak active `8/8`; 3 overload attempts explicitly rejected |
| Writer priority | Lifecycle order was `writer → reader` |
| Endpoint FIFO | 0 violations across 32 endpoints |
| Endpoint lifecycle | Generation order `old → new`; fresh coordinator recovered |
| State coalescing | 99 replacements retained final value `99` |
| Outbox bounds | Critical lane and distinct state-key lane both returned `overflow` |
| Slow subscriber isolation | 65/65 targets delivered; 64 healthy targets progressed in 4.890 ms |
| Soak stability | 5,525 measured cycles; tasks `1 → 1`; RSS `75.285 → 75.285 MiB` |

## Container resource window

The resource sampler overlapped most of the reviewed standard profile, capturing 15 samples at one-second intervals. The 15.84-second harness started shortly after sampling began and finished shortly after the resource window ended, so these figures are a concurrent sample—not complete run accounting.

| Container | CPU min / avg / max | Memory min / avg / max |
|---|---:|---:|
| `flintbay-api` | 1.48% / 35.40% / 105.19% | 118.9 / 137.6 / 174.4 MiB |
| `flintbay-db` | 0.00% / 0.43% / 2.30% | 39.0 / 39.3 / 40.5 MiB |
| `flintbay-redis` | 0.36% / 0.73% / 2.61% | 8.0 / 8.5 / 9.0 MiB |
| `flintbay-web` (development only) | 0.16% / 0.19% / 0.25% | 212.9 / 213.3 / 213.8 MiB |

`flintbay-api` includes both the development Uvicorn process and the temporary harness process; CPU above 100% means more than one logical CPU was used. The Vite development container is not part of the production edge footprint, where the web application is served as static assets.

Redis reported 1.74 MiB used memory, 6.74 MiB RSS, and a configured 256 MiB maximum. The harness itself stabilized at 75.285 MiB RSS after warm-up with a measured delta of 0.0 MiB. Short runs cannot rule out very slow leaks; longer target-device soaks remain appropriate before a high-consequence deployment.

## Pass/fail rules

A profile fails—and the CLI exits non-zero—if any of these occur:

- a configured active/waiting/state-key bound is exceeded or overload is admitted unexpectedly;
- endpoint order changes, generations overlap, or shutdown allows resurrection;
- lifecycle writer priority is violated;
- accepted critical messages are lost;
- healthy fan-out stalls behind the blocked subscriber;
- fresh recovery fails;
- post-warm-up RSS grows by more than 8 MiB or asyncio task count grows;
- a profile exceeds its timeout or raises an exception.

Invalid presets, invalid soak durations, missing output paths, and silent output overwrite also fail before a workload starts.

## Reproduce

The harness lives in the full Flintbay source tree and runs inside the development API container. It is not included in this public deployment repository or its pre-built distribution image. The commands below are therefore for maintainers and contributors who have a source checkout and the development Docker Compose stack; they cannot be run from this repository alone. The workload does not send traffic to production, staging, ngrok, or third-party systems.

```bash
set -euo pipefail
cd /path/to/flintbay-core
docker compose up -d

revision="$(git rev-parse HEAD)"
if test -n "$(git status --porcelain)"; then
  revision="${revision}+dirty"
fi

# Fast contract and boundary regressions
docker compose exec -T api \
  pytest -q src/realtime/test_performance_harness.py src/realtime/test_backpressure.py

# Fast smoke profile
docker compose exec -T api \
  python scripts/realtime_perf.py \
  --preset smoke \
  --revision "$revision" \
  --output /tmp/realtime-performance-smoke.json

# Reviewed standard profile plus concurrent container sampling
scripts/resource_snapshot.sh 15 1 realtime-standard-reviewed > /tmp/realtime-resources.txt &
snapshot_pid=$!
docker compose exec -T api \
  python scripts/realtime_perf.py \
  --preset standard \
  --revision "$revision" \
  --output /tmp/realtime-performance-standard.json
wait "$snapshot_pid"

# Copy machine-readable evidence out of the container
api_container="$(docker compose ps -q api)"
docker cp "$api_container:/tmp/realtime-performance-standard.json" .
cat /tmp/realtime-resources.txt
```

Use `--soak-seconds N` for a custom duration up to 300 seconds. Output paths are not overwritten unless `--overwrite` is explicit. The published artifact used the descriptive custom revision tag shown in the environment table; the example above records the current commit plus a generic `+dirty` suffix when applicable. For comparisons, keep the preset, hardware, Docker allocation, Python version, and background workload equivalent.

## What to test next

For deployment-specific confidence, repeat on the target device and add an authenticated end-to-end WebSocket workload through the production image. Measure browser/network p95 and p99, connector round trips, multiple workers, and external system degradation separately; those layers are intentionally outside this isolated backpressure verification.
