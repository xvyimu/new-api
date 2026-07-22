# W2 · TransitHub · Claude · architecture upgrade

## Worktree identity

| Field | Value |
|-------|--------|
| Worktree (absolute) | `C:\Users\yuanjia\orca\workspaces\src\w2-th-claude` |
| Branch | `xvyimu/w2-th-claude` |
| Baseline tip (portfolio / W1) | `b6dd951d` (W1 stack-matrix + cutover evidence) |
| Agent | claude (solo) |
| Scope | W2 only: console API machine contract · migrate three-dialect evidence · Gin/redis defer · cutover G2 creds list |
| Date | 2026-07-23 |

## Delivered

1. **Console API contract (machine-readable)**  
   - `docs/openapi/console-subset.yaml` → **1.1.0-w2**  
   - Paths: `/healthz` · `/livez` · `/readyz` · `GET /api/status` · login/logout/self · **`GET /api/channel/`** (RO, key omission)  
   - Schemas: `ProbeOk` · `SuccessEnvelope` · `StatusResponse` · `LoginResponse` · `ChannelList*`  
   - Validator: `scripts/validate-console-contract.py` (stdlib only)  
   - Human doc: `docs/gateway/CONSOLE_API_CONTRACT.md` §3 channels + §6 mapping  
   - Diff helper: `scripts/openapi_route_diff.py` CONSOLE_SUBSET includes channels  

2. **Migrations three-dialect**  
   - Strategy: `docs/ops/migrate-three-dialect-strategy.md`  
   - Runner: `scripts/migrate-three-dialect.ps1` (SQLite required; MySQL/PG opt-in `MIGRATE_*_URL` only — never auto `SQL_DSN`)  
   - SQLite empty-DB **green** (version `1`); MySQL/PG **SKIP** without env (baseline is SQLite-shaped — documented, not fake-green)  
   - `migrations/README.md` points at W2 strategy  

3. **Gin / redis**  
   - **W2 still defer** — no `go.mod` bump  
   - Updated `docs/ops/w1-gin-redis-spike.md` with W2 decision  

4. **Cutover evidence**  
   - G2 still red without non-prod secrets; checklist: `docs/ops/w2-cutover-e2e-credentials.md`  
   - `docs/operations/web-console-cutover-plan.md` — W2 pre-flip table  
   - stack-matrix W2 column: `docs/ops/stack-matrix-2026-07.md`  

5. **This report**

## Intentionally not done (W2 bans)

| Item | Status |
|------|--------|
| `git push` / merge default branch | Not done (总控) |
| **D7 production flip** | Not done |
| Change production `FRONTEND_MODE` | Not done |
| Delete / replace React `web/default` | Not done |
| Production migrate / live DSN | Not done |
| Gin 1.10 **or** redis v9 bump | Deferred (spike updated) |
| MySQL/PG empty-DB file baseline green | Strategy only — needs dialect SQL first |
| publish-runtime / asar / ISS | N/A |

## Verification (this message · recorded exits)

Agent: Go **1.26.5** · Node **v24.16.0** (console CI pins 22) · pnpm **11.5.0** · Python **3.14.5**.

### Contract / migrate

| # | Command | Exit | Notes |
|---|---------|-----:|-------|
| 1 | `python scripts/validate-console-contract.py` | **0** | 8 required ops + schemas PASS |
| 2 | `python scripts/openapi_route_diff.py` | **0** | Console subset OK vs api.json; channels path present |
| 3 | `pwsh -NoProfile -File scripts/migrate-three-dialect.ps1` | **0** | SQLite version=1 PASS; mysql/postgres SKIP (no URL) |

### web-console (CWD `web-console/`)

| # | Command | Exit | Notes |
|---|---------|-----:|-------|
| 4 | `pnpm install --frozen-lockfile` | **0** | lockfile up to date |
| 5 | `pnpm typecheck` | **0** | `vue-tsc -b` clean |
| 6 | `pnpm test` | **0** | Vitest 5/5 |
| 7 | `pnpm build` | **0** | dist written · chunk-size warning only |

### NOTICE

| # | Check | Exit / count | Notes |
|---|-------|-------------|-------|
| 8 | `https://github.com/QuantumNous/new-api` in `ConsoleLayout.vue` | **1 match** | OK |
| 9 | `Frontend design and development by New API contributors.` in `en.ts` | **1 match** | OK |

### Cutover gates (pre-flip · no production)

| Gate | Command / proof | Exit | Notes |
|------|-----------------|-----:|-------|
| G1 | tree + contract/migrate docs | n/a | Met |
| G2 | `pwsh -NoProfile -File scripts/e2e-web-console-login.ps1 -SkipVite` | **1** | Backend **reachable** (`/healthz` 200); login `root/123456` → `用户名或密码错误…`. **`TH_E2E_USER`/`TH_E2E_PASS` unset**. See [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md). Not production. |
| G3 | contract `GET /api/channel/` | n/a | Documented + yaml; live list blocked on G2 session |
| G4 | docker Vue image | n/a | docker not re-run; CI authority |
| G5 | `go build -trimpath -buildvcs=true -tags frontend_external -o new-api-backend-w2.exe .` | **0** | From repo root; binary gitignored via `*.exe` |
| G6–G8 | staging / rollback / owner | open | **W3 + human gate** |

## Acceptance checklist (W2 prompt)

| Criterion | Met? |
|-----------|------|
| Contract file locatable / machine-readable | **Yes** — `docs/openapi/console-subset.yaml` + validator exit 0 |
| Migrate evidence or CI patch | **Yes** — SQLite green + strategy doc + runner; no red MySQL/PG CI without dialect SQL |
| Gin **or** redis bump **or** explicit W2 defer | **Yes** — defer documented |
| Cutover G2 credential list if still red | **Yes** — `w2-cutover-e2e-credentials.md` |
| Report with exits · no D7 · no push | **Yes** |

## Related

| Path | Role |
|------|------|
| [stack-matrix-2026-07.md](./stack-matrix-2026-07.md) | Stack card (W2 column) |
| [migrate-three-dialect-strategy.md](./migrate-three-dialect-strategy.md) | Dialect policy |
| [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md) | Non-prod G2 env names |
| [w1-gin-redis-spike.md](./w1-gin-redis-spike.md) | Gin/redis still defer |
| [../openapi/console-subset.yaml](../openapi/console-subset.yaml) | OpenAPI subset |
| [../gateway/CONSOLE_API_CONTRACT.md](../gateway/CONSOLE_API_CONTRACT.md) | Human contract |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | G1–G8 + W2 table |
| `scripts/validate-console-contract.py` | Contract gate |
| `scripts/migrate-three-dialect.ps1` | Empty-DB runner |
