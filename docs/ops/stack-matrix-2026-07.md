# TransitHub · stack matrix · 2026-07

> W1 baseline card. Tracks **current → H2 2026 target → this wave**.  
> Companion: portfolio plan `D:\orca\.planning\portfolio-arch-upgrade-2026h2\repos\th.md`.  
> Does **not** authorize production cutover, dependency bumps that fail CI, or React deletion.

## Worktree identity (W1 evidence run)

| Field | Value |
|-------|--------|
| Worktree | `C:\Users\yuanjia\orca\workspaces\src\w1-th-claude` |
| Branch | `xvyimu/w1-th-claude` |
| HEAD | `baecf0b1532eeb3edf84538a691e5cd00ac35f9e` |
| Date | 2026-07-23 |
| Agent | claude |

## Matrix

| Layer | Current (repo tip) | Target (H2 ~2027-01) | W1 this wave |
|-------|--------------------|----------------------|--------------|
| **Go** | `go 1.25.1` · `toolchain go1.26.5` | Pin CI to toolchain; follow security patches | **CI already pins `go-version: 1.26.5`** (`.github/workflows/quality.yml`). Local agent Go = 1.26.5. No go.mod change. |
| **Gin** | `github.com/gin-gonic/gin v1.9.1` | Maintain line **≥1.10** after soak | **Spike only** — latest published `v1.12.0`. No bump (see [gin-redis-spike](./w1-gin-redis-spike.md)). |
| **Redis client** | `github.com/go-redis/redis/v8 v8.11.5` | **v9** (`github.com/redis/go-redis/v9`) on dedicated worktree | **Spike only** — v9 latest `v9.21.0`; 5 import sites. Default **no bump in W1**. |
| **GORM** | `gorm.io/gorm v1.25.2` (+ mysql/postgres/sqlite drivers) | Maintain line + three-dialect empty-DB CI | Documented; migrate CI still SQLite-only for file baseline. No GORM bump in W1. |
| **web-console** | Vue 3.5 · Vite 8 · Naive UI · **pnpm 11.5.0** · Node **22** in CI | Patch follow; e2e into main CI later (W2) | **Quality gates re-run green** (install/typecheck/test/build + NOTICE). |
| **React default** | `web/default` **LEGACY** (feature freeze) | No new features → time-boxed shrink after D7 | Unchanged; freeze remains (`docs/legacy-frontend-gate.md`). |
| **Node (console CI)** | Node 22 · pnpm 11.5 | Align portfolio matrix (crosscut) | Matches `crosscut.md` target for TH console. |
| **Bun (legacy web)** | Bun 1.3.14 in quality/release | Keep for React themes until D7 | Unchanged. |

## CI pins (authoritative)

| Job / path | Pin |
|------------|-----|
| `go-quality` / `sqlite-migrate` | Go **1.26.5** |
| `web-quality` | Bun **1.3.14** |
| `web-console-quality` | Node **22** · pnpm **11.5.0** |
| Vue image builder | `node:22-bookworm` · pnpm 11.5.0 (`deploy/separated/Dockerfile.frontend.vue`) |

## Architecture boundary (unchanged)

- TransitHub = **AI gateway** (protocol / billing / channel routing). Not a desktop Chat workbench.
- Console = same-origin management plane; **no** relay/billing logic in Vue.
- Production default frontend remains **embedded React** until D7 human gate (`docs/operations/web-console-cutover-plan.md`).

## Next waves (pointer only)

| Wave | Stack / arch |
|------|----------------|
| W2 | Gin/redis evaluation merge if soak green · OpenAPI/contract · migrate multi-dialect CI · staging Vue soak |
| W3 | **D7 human gate** · rollback drill record |
| W4 | React shrink strategy or schedule · matrix close-out |

## Related

| Path | Role |
|------|------|
| [w1-arch-upgrade-transithub-claude.md](./w1-arch-upgrade-transithub-claude.md) | W1 report + command exits |
| [w1-gin-redis-spike.md](./w1-gin-redis-spike.md) | Gin/redis upgrade notes |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | Cutover G1–G8 (no flip) |
| [../ARCHITECTURE_TARGET.md](../ARCHITECTURE_TARGET.md) | Phase1 target contract |
