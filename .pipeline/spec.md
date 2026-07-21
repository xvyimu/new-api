# Spec: OpenTelemetry Phase 1 — Traces Only (NewAPI)

**Repo root (code):** `D:\newapi\src`  
**Paths below are relative to that root.**  
**Product gates:** ADR `D:\newapi\docs\adr-otel-2026-07-21.md` · design draft §1–§6 · opt-in default off · Prometheus coexistence · no shadow/routing changes.

No OPEN QUESTIONS — defaults below are fixed from ADR + design draft so Coder can proceed without user input.

---

## 1. Goal

Add opt-in OpenTelemetry **traces** (OTLP/gRPC) for:

1. HTTP request root span (Gin middleware, global chain).
2. Relay hot-path child spans (shared channel request path + controller attempt), without mass-refactor of every adaptor.

When disabled (default), **zero** OTEL exporter init, **no** panic, and request path behavior unchanged.

---

## 2. Env vars and defaults

| Env | Default | Notes |
|-----|---------|--------|
| `OTEL_TRACES_ENABLED` | `false` | Opt-in; parse via `common.GetEnvOrDefaultBool` (same style as `METRICS_ENABLED`). |
| `OTEL_SERVICE_NAME` | `new-api` | Resource `service.name`. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4317` | OTLP/gRPC target host:port **without** scheme. If value includes `http://`/`https://`, strip scheme for gRPC dial. |
| `OTEL_TRACES_SAMPLER_RATIO` | `0.1` | Head sampling ratio in `[0,1]`. Invalid/out-of-range → fall back to `0.1` and log once via `common.SysError`. `1.0` = always sample (debug). |
| `OTEL_TRACES_INSECURE` | `true` | gRPC insecure (LOCAL-ONLY collector). Only used when traces enabled. |

Do **not** invent other OTEL env vars in phase 1. Do not dual-write metrics. Do not touch logs correlation.

---

## 3. Package layout and signatures

### 3.1 Create `pkg/observability/traces.go`

Package: `observability` (same as metrics).

```go
// EnabledTraces reports whether OTEL traces are opted in.
func EnabledTraces() bool

// InitTraces installs global TracerProvider when enabled.
// When disabled: no-op, returns (nil, nil).
// When enabled but exporter setup fails: log error, leave noop provider, return (nil, err)
// so main can continue serving (fail-open). Never panic.
func InitTraces(ctx context.Context) (shutdown func(context.Context) error, err error)

// ShutdownTraces flushes and shuts down the provider if InitTraces installed one.
// Safe if never initialized or already shut down.
func ShutdownTraces(ctx context.Context) error

// Tracer returns a named tracer; always safe (uses global otel.GetTracerProvider()).
func Tracer(name string) trace.Tracer

// HTTPMiddleware returns Gin middleware that creates a server span for the request.
// When traces not enabled / noop provider: still call c.Next() with negligible cost
// (prefer early return if !EnabledTraces() after init, or rely on noop span).
func HTTPTraceMiddleware() gin.HandlerFunc
```

Implementation requirements for `InitTraces`:

- Resource: `service.name` from `OTEL_SERVICE_NAME`, optional `service.version` = `common.Version` if cheap.
- Exporter: `otlptracegrpc` → endpoint from env, `WithInsecure()` when `OTEL_TRACES_INSECURE` true.
- Batch span processor (SDK default batcher is fine).
- Sampler: `sdktrace.ParentBased(sdktrace.TraceIDRatioBased(ratio))` with ratio from `OTEL_TRACES_SAMPLER_RATIO`.
- Set global: `otel.SetTracerProvider(tp)` and a simple error handler that logs via `common.SysError` (no secrets).
- Propagator: `propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{})` — W3C only; **do not** replace AxonHub headers.
- Return `tp.Shutdown` as shutdown func.

Constants (package-private or exported as needed by tests):

- Tracer name: `"github.com/QuantumNous/new-api"` or `"new-api"`.
- Span names:
  - HTTP: `"HTTP {METHOD}"` or `"http.server"` with attributes — prefer `"HTTP {method}"` + `http.route` attr (see attributes).
  - Relay attempt: `"relay.attempt"`.
  - Upstream request: `"relay.upstream"` (around `doRequest` / shared API request).

### 3.2 Create `pkg/observability/traces_test.go`

Tests (table-driven where natural; use `t.Setenv`):

1. **`TestEnabledTracesDefaultOff`** — unset env → `EnabledTraces() == false`.
2. **`TestInitTracesDisabledNoExporter`** — `OTEL_TRACES_ENABLED=false` → `InitTraces` returns nil shutdown, nil err; calling `HTTPTraceMiddleware` + one request must not panic.
3. **`TestInitTracesEnabledBadEndpointNoPanic`** — enable traces, point endpoint at invalid host (e.g. `127.0.0.1:1` or unresolvable); init may error or succeed with exporter that fails later — either way **must not panic**; HTTP middleware + `c.Next()` still works.
4. **`TestHTTPTraceMiddlewareSetsSpanAttributes`** — enable with in-memory exporter **or** `tracetest.NewInMemoryExporter` / SDK `sdktrace.NewTracerProvider` with `AlwaysSample` injected only in test helper (preferred: export a test-only `InitTracesForTest(tp)` or build middleware against a local provider set via `otel.SetTracerProvider` in test then restore). Assert span exists with method + route or path after request.
5. **`TestSamplerRatioClamp`** — invalid ratio falls back (unit-test the parse helper if extracted).

Prefer extracting small pure helpers for testability:

```go
func parseSamplerRatio(raw string, defaultRatio float64) float64
func normalizeOTLPEndpoint(raw string) string // strip http(s):// if present
```

### 3.3 Optional thin helpers (same package or `pkg/observability/spanutil.go`)

Keep minimal; avoid new packages.

```go
// StartSpan starts a span from ctx; returns (ctx, span). Safe with noop provider.
func StartSpan(ctx context.Context, name string, opts ...trace.SpanStartOption) (context.Context, trace.Span)

// SpanFromGin returns context for span ops from gin.Context request context.
func SpanFromGin(c *gin.Context) context.Context
```

---

## 4. Files to create / modify

| Path | Action |
|------|--------|
| `pkg/observability/traces.go` | **Create** — init, middleware, shutdown, helpers |
| `pkg/observability/traces_test.go` | **Create** — enable/disable, no panic, basic span |
| `main.go` | **Modify** — call `InitTraces` after env/logger ready when `mode.servesHTTP()` (or always for simplicity if cheap when disabled); register shutdown on HTTP graceful path **and** non-HTTP quit path; register middleware after `RequestId` / `TraceContext` |
| `relay/channel/api_request.go` | **Modify** — wrap `doRequest` (and optionally outer `DoApiRequest`) with child span `relay.upstream` |
| `controller/relay.go` | **Modify** — wrap each retry attempt body (around `relayHandler` / helpers call) with child span `relay.attempt` |
| `go.mod` / `go.sum` | **Modify** — add direct OTEL deps (see §6) |

**Do not modify** (phase 1 out of scope / hard gate):

- `middleware/trace.go` / `TraceContext` behavior or headers.
- `pkg/observability/metrics.go` Prometheus path (except no conflict on package name).
- `service/channel_adaptive.go`, adaptive circuit, shadow, refund outbox logic.
- Frontend / RUM / OTEL metrics / log field injection.
- Per-adaptor files under `relay/channel/*/` (span only at shared `api_request` / controller).
- Collector scripts / Jaeger deploy (docs-only optional; not required for this ship).

---

## 5. Integration details

### 5.1 `main.go` middleware order

Existing chain (relevant):

```text
RequestId → Version → TraceContext → SecurityHeaders → I18n → [metrics if enabled] → logger → sessions → router
```

Insert **after** `middleware.TraceContext()` (so `request_id` and AxonHub `trace_id` are already on gin context):

```go
if observability.EnabledTraces() {
    // InitTraces should already have run; middleware always registered only when enabled
    // OR always register HTTPTraceMiddleware which no-ops when disabled.
}
server.Use(observability.HTTPTraceMiddleware())
```

**Preferred minimal pattern (mirror metrics):**

```go
// After common.InitEnv / logger in InitResources or early main servesHTTP block:
shutdownTraces, err := observability.InitTraces(context.Background())
// log err if any; do not fatal

// Middleware:
if observability.EnabledTraces() {
    server.Use(observability.HTTPTraceMiddleware())
}

// On graceful shutdown (both HTTP and non-HTTP quit paths that stop process):
if shutdownTraces != nil {
    _ = shutdownTraces(ctx) // use same shutdown timeout ctx as server.Shutdown
}
// or always call observability.ShutdownTraces(ctx)
```

Call `InitTraces` only when `mode.servesHTTP()` **or** always: if always, disabled path is free. Prefer **always call InitTraces** at start after `InitResources` (env loaded) so worker modes also clean; if disabled, no-op.

### 5.2 HTTP root span attributes (safe set only)

Set on root span (and/or via span name):

| Attribute | Source | Notes |
|-----------|--------|--------|
| `http.request.method` | `c.Request.Method` | |
| `http.route` | `c.FullPath()` after `c.Next()`, else `"unmatched"` | Same as metrics |
| `http.response.status_code` | `c.Writer.Status()` after Next | |
| `url.path` | path only, no query | Do **not** put raw query if it may contain keys |
| `request_id` | `c.GetString(common.RequestIdKey)` | App attribute (string) |
| `axon.trace_id` | `c.GetString("trace_id")` if set | AxonHub-compatible ID; **not** OTEL TraceID |
| `axon.thread_id` | `c.GetString("thread_id")` if set | Optional |
| `net.host.name` / service already on resource | — | |

**Forbidden on spans/attributes/events:**

- `Authorization`, API keys, token keys, full request/response bodies, cookies, `X-Api-Key`, channel secrets, model prompt text, query strings that may carry `key=`.

Span status: `codes.Error` if status ≥ 500; else OK. Record error message only if already a generic status text — do not attach response bodies.

Propagate: update `c.Request = c.Request.WithContext(spanCtx)` so downstream uses the span context.

### 5.3 Relay attempt span (`controller/relay.go`)

Inside the retry loop, around the call that runs the helper (where `attemptStart := time.Now()` already exists ~L228):

1. Start span `relay.attempt` from `c.Request.Context()`.
2. Attributes (when available on `relayInfo` / channel):
   - `channel_id` (int → int64 attr)
   - `model` = `relayInfo.OriginModelName` (not prompt)
   - `attempt` / `retry_index` = `relayInfo.RetryIndex`
   - `relay_format` string if cheap
3. On error from `newAPIError`: set span status Error + `upstream_status` if known from `newAPIError.StatusCode`.
4. `defer span.End()`; put span context back on request if needed for nested `doRequest`.
5. **Do not** change adaptive recording, refund, channel selection, or retry conditions.

### 5.4 Upstream span (`relay/channel/api_request.go`)

In `doRequest` (single choke point used by `DoApiRequest` / form / task):

1. Start child span `relay.upstream` from `c.Request.Context()` (already used for `req.WithContext`).
2. Attributes:
   - `channel_id` from `info.ChannelId` if field accessible (ChannelMeta embedded — use existing fields on `RelayInfo` / `ChannelMeta`; if ChannelId only on embedded meta after `InitChannelMeta`, use whatever is populated at doRequest time).
   - `http.request.method` of **upstream** req
   - `server.address` host only from URL (parse; never log full URL with query secrets — use existing `common.SanitizeURLForLog` only for logs, not as attribute if it still has sensitive query; prefer host + path template if available)
   - `upstream_status` from `resp.StatusCode` when resp non-nil
3. On `client.Do` error: record error, set status Error.
4. Ensure `req = req.WithContext(spanCtx)` so any future client hooks see context.
5. `defer span.End()` before return.

Optional: short span in `DoApiRequest` for setup URL/headers only if cheap; **not required** if `doRequest` span exists.

### 5.5 Coexistence with existing systems

| System | Rule |
|--------|------|
| Prometheus `METRICS_ENABLED` | Unchanged; independent flag |
| `middleware.TraceContext` | Unchanged; OTEL uses `request_id` / axon ids as **attributes only** |
| Shadow / adaptive routing | Observe-only; no reads of sampling for routing |
| Pyroscope | Unrelated; leave alone |

---

## 6. Dependencies (`go.mod`)

Add **direct** requires (run `go get` and let go resolve; pin current stable compatible with go 1.25.1). Target module set:

```
go.opentelemetry.io/otel
go.opentelemetry.io/otel/sdk
go.opentelemetry.io/otel/trace
go.opentelemetry.io/otel/exporters/otlp/otlptrace
go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
go.opentelemetry.io/otel/metric          // if pulled transitively only, ok
google.golang.org/grpc                  // transitive via exporter
```

Coder: from `D:\newapi\src` run something like:

```text
go get go.opentelemetry.io/otel@v1.37.0
go get go.opentelemetry.io/otel/sdk@v1.37.0
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc@v1.37.0
go mod tidy
```

If 1.37.x has issues, use latest 1.3x that `go get` resolves cleanly. Do not pin to ancient 0.x. No cloud exporters (Datadog, Honeycomb, etc.).

---

## 7. Patterns to copy

| Pattern | Source file |
|---------|-------------|
| Env bool default false + middleware gated in `main` | `pkg/observability/metrics.go` (`Enabled`, `HTTPMiddleware`) + `main.go` L246–248 |
| Env helpers | `common/env.go` (`GetEnvOrDefaultBool`, `GetEnvOrDefaultString`, `GetEnvOrDefaultFloat`) |
| Opt-in external profiler init (no-op when unset) | `common/pyro.go` (`StartPyroScope`) |
| Graceful shutdown timeout context | `main.go` L297–306 |
| Gin middleware style | `middleware/request-id.go`, `pkg/observability/metrics.go` |
| Relay attempt timing / retry loop | `controller/relay.go` (~L187–243) |
| Shared upstream HTTP | `relay/channel/api_request.go` `doRequest` / `DoApiRequest` |
| Test style for middleware | `pkg/observability/metrics_test.go` (gin + httptest + `t.Setenv`) |

---

## 8. Edge cases

| Case | Expected |
|------|----------|
| Traces disabled | No OTLP connection attempts; middleware not registered **or** pure no-op; no panic |
| Bad endpoint | Init fail-open (log + continue) **or** exporter errors in background only; HTTP still 200 for app routes |
| Concurrent requests | Provider/sampler thread-safe (SDK); no shared mutable span state without sync |
| Shutdown flush | `Shutdown`/`ForceFlush` within process shutdown ctx; errors logged, not fatal |
| Double shutdown | Safe / idempotent |
| Unmatched routes | `http.route=unmatched` after Next |
| WebSocket / SSE | Root HTTP span still ends when handler returns; do not block on stream lifetime beyond normal request (same as metrics middleware) |
| Panic in handler | Recovery middleware still works; span should End via defer in OTEL middleware |
| Sampler ratio 0 | Valid — drop all (except parent-based rules if remote parent forces; local usually none) |
| Secrets | Never as attributes/events/baggage |

---

## 9. Out of scope (phase 1)

- OTEL metrics dual-write / replacing Prometheus
- Log `trace_id`/`span_id` injection (phase 2)
- Frontend RUM (phase 4)
- Collector/Jaeger install scripts (nice-to-have docs only; not required for code ship)
- Tail sampling, remote sampler
- Spans for TokenAuth/Distribute individually (design ideal; phase 1 root + relay attempt + upstream is enough)
- Changing shadow/adaptive/refund
- Cloud exporters
- UI for sampling rate

---

## 10. Acceptance criteria (for Tester)

1. **Default off:** With env unset, `go test ./pkg/observability/ -count=1` passes; no test requires a live collector.
2. **Disabled path:** `EnabledTraces()==false`; `InitTraces` no-op; serving a request through `HTTPTraceMiddleware` (if registered) or without it does not panic and does not dial OTLP.
3. **Enabled unit path:** With in-memory or test provider, HTTP middleware creates a span with method + status; no Authorization/body attributes present.
4. **Compile:** `go build -o NUL .` (or project’s usual build) succeeds with new deps on go 1.25.1 toolchain.
5. **main wiring:** When `OTEL_TRACES_ENABLED=true`, process starts without fatal if collector down (fail-open); when false, binary behavior matches pre-change for metrics/trace headers.
6. **No regression:** Existing `middleware` TraceContext headers still set; `METRICS_ENABLED` path untouched; no edits to adaptive channel selection logic.
7. **Secrets:** Code review / tests confirm attributes whitelist only (request_id, axon ids, method, route, status, channel_id, model name, attempt, upstream_status).
8. **Shutdown:** Calling shutdown after init does not panic (unit or smoke).

Manual smoke (optional, not blocking CI if collector absent):

```text
OTEL_TRACES_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
OTEL_TRACES_SAMPLER_RATIO=1.0
# hit /v1/chat/completions with auth; Jaeger shows service new-api if stack running
```

---

## 11. Implementation order (Coder)

1. Add OTEL deps via `go get` / tidy.
2. Implement `traces.go` + tests (disabled + in-memory enabled).
3. Wire `main.go` init + middleware + shutdown.
4. Add `doRequest` span; add `relay.attempt` span in controller loop.
5. Run `go test ./pkg/observability/ ./middleware/ -count=1` and a focused compile.

Keep the diff minimal; prefer shared choke points over decorating every adaptor.
