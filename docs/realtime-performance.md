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

## Reproducing this

The harness is not in this repository. It runs inside the development API container
of the full Flintbay source tree — `pytest src/realtime/test_performance_harness.py`
for the contract and boundary regressions, then `scripts/realtime_perf.py` with a
named preset for the measured runs, with container resource sampling alongside the
standard profile. Presets, soak durations and output paths are validated before a
workload starts, and output files are never overwritten implicitly, so a published
number always corresponds to one recorded run. The workload is fully local: no
traffic goes to production, staging, tunnels or third-party systems.

What that means for you as an operator: these figures are a ceiling measured on the
hardware in the environment table above, not a promise about your device. The
section below is the part you can act on.

## What to test next

For deployment-specific confidence, repeat on the target device and add an authenticated end-to-end WebSocket workload through the production image. Measure browser/network p95 and p99, connector round trips, multiple workers, and external system degradation separately; those layers are intentionally outside this isolated backpressure verification.
