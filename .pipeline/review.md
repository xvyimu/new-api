# Review: OpenTelemetry Phase 1 — Traces Only

**Reviewer:** pipeline-reviewer (read-only)
**Date:** 2026-07-21
**Working dir:** `D:\newapi\src`
**Basis:** code reading of all changed files + Tester green (`test-results.md` PASS). Builds not run (sandbox `-buildvcs` block, per ADR §4).

## VERDICT: SHIP

Default-off, fail-open, secrets-clean. All 8 hard gates PASS on code inspection. Findings are minor/non-blocking.

---

## Per-gate results

| # | Gate | Result | Evidence |
|---|------|--------|----------|
| 1 | Default off; zero exporter init when disabled | **PASS** | `traces.go:46` `GetEnvOrDefaultBool("OTEL_TRACES_ENABLED", false)`; `InitTraces` early-return `traces.go:100-102` before any `otlptracegrpc.New`; middleware gated `main.go:252-254`; `HTTPTraceMiddleware` self-guards `traces.go:220-223`. Test `TestEnabledTracesDefaultOff`, `TestInitTracesDisabledNoExporter`. |
| 2 | Fail-open: bad endpoint no panic/fatal; HTTP still serves | **PASS** | Exporter err logged + returned, no panic `traces.go:116-120`; resource err path shuts exporter + returns `traces.go:128-132`; `main.go:203-205` logs, does not fatal. Test `TestInitTracesEnabledBadEndpointNoPanic` (HTTP still 200). |
| 3 | No secrets on span attributes | **PASS** | HTTP attrs whitelist only: `http.request.method`, `url.path` (path only, no query), `http.route`, status, `request_id`, `axon.trace_id`, `axon.thread_id` (`traces.go:230-257`). Relay attempt: `channel_id`, `model` (OriginModelName, not prompt), `attempt`, `relay_format`, `upstream_status` (`relay.go:240-267`). Upstream: `channel_id`, `http.request.method`, `server.address` = `req.URL.Host` (host only, no query), `upstream_status` (`api_request.go:489-546`). No Authorization/body/cookie/full-URL. Status text is generic class only (`traces.go:268-278`). Test asserts absence of `Authorization`/`http.request.body`. |
| 4 | Prometheus /metrics + MetricsAuth untouched | **PASS** | `main.go:258-261` unchanged: `if observability.Enabled()` → `HTTPMiddleware` + `/metrics` with `MetricsAuth()`. `metrics.go` `Enabled`/`HTTPMiddleware`/`MetricsAuth` not edited. OTEL is an independent flag. |
| 5 | TraceContext (AxonHub) headers unchanged; W3C propagator only on OTEL path | **PASS** | `middleware/trace.go` untouched — still sets AH-*/X-* headers (`trace.go:81-84`) and gin keys. OTEL reads `trace_id`/`thread_id` as attributes only. `otel.SetTextMapPropagator(TraceContext + Baggage)` runs only inside `InitTraces` (`traces.go:141-144`), i.e. only when enabled. Axon headers not replaced. |
| 6 | Adaptive/shadow/refund unchanged (observe-only) | **PASS** | `RecordAdaptiveResult` still called post-attempt (`relay.go:286`), outside/after the span closure, with unchanged args. Span wraps only the helper dispatch (`relay.go:234-270`); retry loop, `getChannel`, permit release, refund, `RecordRelayAttempt` untouched. No edits to adaptive/shadow packages in this change set. |
| 7 | Relay spans only at shared choke points, not per-adaptor | **PASS** | `relay.attempt` at controller retry loop `relay.go:237`; `relay.upstream` at single `doRequest` choke point `api_request.go:486` (used by `DoApiRequest`/form/task via `api_request.go:333,365,478,578`). No OTEL imports/spans in `relay/channel/*/` adaptor files (grep clean). |
| 8 | LOCAL-ONLY: OTLP/gRPC to localhost, insecure default; no cloud exporter | **PASS** | Endpoint default `localhost:4317` (`traces.go:27,104`); `OTEL_TRACES_INSECURE` default `true` (`traces.go:107`), `WithInsecure()` applied `traces.go:112-114`. Only exporter is `otlptracegrpc`; no Datadog/Honeycomb/cloud imports. `go.mod` direct deps limited to `otel`, `otel/sdk`, `otel/trace`, `otlptracegrpc` @ v1.37.0 (lines 98-101). |

---

## Findings

- **[LOW] `url.path` on HTTP span may echo IDs in path segments.** `traces.go:231` records `c.Request.URL.Path`. Query is correctly excluded, but path params (e.g. `/v1/keys/{id}`) are raw. Not a secret leak (keys travel in Authorization/query, not path here), and `http.route` gives the template. No action needed for phase 1; note for phase 2 if any route ever puts a token in the path.
- **[LOW] Double `req.Body.Close()` unrelated to OTEL.** `api_request.go:555-556` closes both `req.Body` and `c.Request.Body`; pre-existing behavior, span change did not introduce it. Out of scope.
- **[INFO] `channel_id` on upstream span guarded by `info.ChannelMeta != nil` but reads `info.ChannelId`** (`api_request.go:488-489`). Consistent with ADR note that ChannelId lives on embedded meta; safe (nil-guarded). Fine.
- **[INFO] Sampler ratio env read via raw `os.Getenv`** (`traces.go:106`) rather than a `common.GetEnvOrDefault*` helper, but parsing/clamping is covered by `parseSamplerRatio` + `TestSamplerRatioClamp`. Acceptable.

No BLOCK/NEEDS-WORK findings.

---

## Deploy safety (default-off)

Safe to merge and deploy default-off. The change introduces new direct deps (OTEL v1.37.0 x4) and one middleware, but:

- Middleware is registered only when `EnabledTraces()` is true (`main.go:252-254`) and self-no-ops otherwise (`traces.go:220-223`) — zero request-path cost when unset.
- `InitTraces` early-returns with no exporter dial when disabled; relay `StartSpan` calls resolve to the global noop tracer, so `relay.attempt`/`relay.upstream` are cheap no-ops.
- New deps add binary size / supply-chain surface but no runtime behavior until opted in; versions are pinned (v1.37.0).
- Rollback matches ADR §6: unset `OTEL_TRACES_ENABLED` + restart. No live main-path dependency.

Recommend: ship default-off; before flipping `OTEL_TRACES_ENABLED=true` in any env, confirm a LOCAL collector is reachable (fail-open handles absence, but background exporter errors will log via `SysError`).
