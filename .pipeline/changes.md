# Changes: OpenTelemetry Phase 1 — Traces Only

## Summary

Opt-in OTEL traces (OTLP/gRPC) for HTTP root spans + relay attempt/upstream child spans. Default **off** (`OTEL_TRACES_ENABLED=false`). Fail-open on exporter init. Prometheus / TraceContext / adaptive routing untouched.

## Files created

| Path | What |
|------|------|
| `pkg/observability/traces.go` | `EnabledTraces`, `InitTraces`, `ShutdownTraces`, `Tracer`, `HTTPTraceMiddleware`, `StartSpan`, `SpanFromGin`, helpers `parseSamplerRatio` / `normalizeOTLPEndpoint`, test hook `InitTracesForTest` |
| `pkg/observability/traces_test.go` | Default-off, disabled no-exporter, bad endpoint no panic, in-memory span attributes whitelist, sampler clamp, endpoint normalize |

## Files modified

| Path | What |
|------|------|
| `main.go` | After Pyroscope: `InitTraces` (fail-open log). Middleware: `HTTPTraceMiddleware` after `TraceContext` when enabled. `ShutdownTraces` on HTTP and non-HTTP quit paths. |
| `controller/relay.go` | Child span `relay.attempt` around each retry helper call; attrs: `channel_id`, `model`, `attempt`, `relay_format`, `upstream_status` on error. Propagates span ctx on `c.Request`. |
| `relay/channel/api_request.go` | Child span `relay.upstream` in `doRequest`; attrs: `channel_id`, `http.request.method`, `server.address` (host only), `upstream_status`; errors set span status. |
| `go.mod` / `go.sum` | Direct OTEL v1.37.0: `otel`, `otel/sdk`, `otel/trace`, `otlptracegrpc` (+ tidy) |

## Env (phase 1)

| Env | Default |
|-----|---------|
| `OTEL_TRACES_ENABLED` | `false` |
| `OTEL_SERVICE_NAME` | `new-api` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4317` (scheme stripped if present) |
| `OTEL_TRACES_SAMPLER_RATIO` | `0.1` (invalid → 0.1 + SysError) |
| `OTEL_TRACES_INSECURE` | `true` |

## How to verify

```text
cd D:\newapi\src
go test ./pkg/observability/ -count=1
go test ./middleware/ -count=1
go build -o NUL .
```

Optional smoke (needs collector):

```text
$env:OTEL_TRACES_ENABLED='true'
$env:OTEL_EXPORTER_OTLP_ENDPOINT='localhost:4317'
$env:OTEL_TRACES_SAMPLER_RATIO='1.0'
# start process; hit any HTTP route; process must not fatal if collector down
```

## Tester focus

1. **Default off** — no OTLP dial when env unset; `EnabledTraces()==false`.
2. **Fail-open** — bad endpoint + enabled: no panic; HTTP still serves.
3. **Span attrs whitelist only** — no Authorization/body/query secrets on spans.
4. **Middleware order** — after RequestId + TraceContext; axon ids as attributes only.
5. **No regression** — TraceContext headers, metrics path, adaptive/shadow/refund logic unchanged.
6. **Shutdown** — double `ShutdownTraces` safe; HTTP + non-HTTP paths both call it.
7. **Relay spans** — attempt + upstream only at shared choke points (not per-adaptor).

## Out of scope (not done)

OTEL metrics dual-write, log correlation, RUM, collector deploy, cloud exporters, adaptive/shadow changes.
