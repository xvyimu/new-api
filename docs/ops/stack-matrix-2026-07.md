# TransitHub · stack matrix · 2026-07

> Stack card: **current → H2 2026 target → wave status · W4 收口**.  
> Companion: portfolio plan `D:\orca\.planning\portfolio-arch-upgrade-2026h2\repos\th.md`.  
> Does **not** authorize production cutover, dependency bumps that fail CI, or React deletion.

## Worktree identity

| Field | W1 | W2 | W3 | W4 |
|-------|----|----|----|----|
| Worktree | `...\w1-th-claude` | `...\w2-th-claude` | `...\w3-th-claude` | `C:\Users\yuanjia\orca\workspaces\src\w4-th-claude` |
| Branch | `xvyimu/w1-th-claude` | `xvyimu/w2-th-claude` | `xvyimu/w3-th-claude` | `xvyimu/w4-th-claude` |
| Date | 2026-07-23 | 2026-07-23 | 2026-07-23 | 2026-07-23 |
| Agent | claude | claude | claude | claude (dual vs codex) |

## Matrix

| Layer | Current (repo tip) | Target (H2 ~2027-01) | W1 | W2 | W3 | **W4 收口** |
|-------|--------------------|----------------------|----|----|----|-------------|
| **Go** | `go 1.25.1` · `toolchain go1.26.5` | Pin CI to toolchain; security patches | CI pins `1.26.5` | Unchanged | G5 re-green | G5 re-green · **~done** for H2 pin goal |
| **Gin** | `github.com/gin-gonic/gin v1.9.1` | Maintain line **≥1.10** after soak | Spike only | Still defer | Still defer | **DEFER** → H2 backlog #1 (dedicated wt) |
| **Redis client** | `github.com/go-redis/redis/v8 v8.11.5` | **v9** dedicated wt | Spike only | Still defer | Still defer | **DEFER** → H2 backlog #2 |
| **GORM** | `gorm.io/gorm v1.25.2` | Maintain + three-dialect empty-DB | Doc only | SQLite green + strategy | SQLite re-green | SQLite empty migrate re-green · MySQL/PG still skip without URL |
| **web-console** | Vue 3.5 · Vite 8 · pnpm 11.5 · Node 22 CI | Patch follow; e2e main CI later | Quality green | Quality re-run | Quality re-run | Quality re-run exit 0 · pack wires `pnpm build` |
| **Console API contract** | Markdown + yaml | OpenAPI subset → TS client path | — | **`console-subset.yaml` 1.1.0-w2** + validator | Validator re-green | Validator re-green · **no schema bump** |
| **D7 / cutover** | React prod default until gate | D7 after G1–G8 + human | Evidence pack start | Cred checklist | Dossier G1–G8 | **Nonprod verify pack** · dossier W4 evidence · **NOT EXECUTED** · flip readiness **NO** |
| **React default** | `web/default` LEGACY freeze | Shrink after D7 | Unchanged | Unchanged | Unchanged | Unchanged (no delete) · shrink **after** D7 only |
| **Node (console CI)** | Node 22 · pnpm 11.5 | Crosscut align | Match | Match | Match | Match |
| **Bun (legacy web)** | Bun 1.3.14 | Until D7 | Unchanged | Unchanged | Unchanged | Unchanged |

### H2 completion (W4 snapshot)

| Goal | Status | Notes |
|------|--------|-------|
| Stack matrix exists | **done** | this file |
| D7 either flipped+drilled **or** written defer+blockers | **written block** (not silent) | G2/G3/G4/G6/G7/G8 open · pack ready |
| Gin ≥1.10 | **not started** | backlog |
| redis v9 | **not started** | backlog |
| Vue prod default | **not started** | blocked on human D7 |

### H2 backlog (next 3 · post-W4)

1. **Operator G2:** mint non-prod `TH_E2E_*` → green `scripts/w4-d7-nonprod-verify.ps1` (login + channels RO).  
2. **G4/G6/G7 on staging:** Docker Vue image digest · ≥24h soak · timed ≤5 min rollback (then request G8).  
3. **Dedicated wt:** Gin ≥1.10 **or** go-redis v9 (one at a time · full test gate) — not mixed with D7 flip day.

## CI pins (authoritative)

| Job / path | Pin |
|------------|-----|
| `go-quality` / `sqlite-migrate` | Go **1.26.5** |
| `web-quality` | Bun **1.3.14** |
| `web-console-quality` | Node **22** · pnpm **11.5.0** |
| Vue image builder | `node:22-bookworm` · pnpm 11.5.0 |

## Architecture boundary (unchanged)

- TransitHub = **AI gateway** (protocol / billing / channel routing). Not a desktop Chat workbench.
- Console = same-origin management plane; **no** relay/billing logic in Vue.
- Production default frontend remains **embedded React** until D7 human gate (`docs/operations/web-console-cutover-plan.md`).

## Related

| Path | Role |
|------|------|
| [w1-arch-upgrade-transithub-claude.md](./w1-arch-upgrade-transithub-claude.md) | W1 report |
| [w2-arch-upgrade-transithub-claude.md](./w2-arch-upgrade-transithub-claude.md) | W2 report |
| [w3-arch-upgrade-transithub-claude.md](./w3-arch-upgrade-transithub-claude.md) | W3 report · **D7 NOT EXECUTED** |
| [w4-arch-upgrade-transithub-claude.md](./w4-arch-upgrade-transithub-claude.md) | W4 report · **D7 NOT EXECUTED** |
| [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md) | Nonprod verify pack |
| [w3-d7-gate-dossier.md](./w3-d7-gate-dossier.md) | G1–G8 dossier (W4 refresh) |
| [w3-rollback-desktop-drill.md](./w3-rollback-desktop-drill.md) | Non-prod rollback drill |
| [w3-staging-soak-checklist.md](./w3-staging-soak-checklist.md) | 24h soak checklist |
| [w1-gin-redis-spike.md](./w1-gin-redis-spike.md) | Gin/redis — still defer |
| [migrate-three-dialect-strategy.md](./migrate-three-dialect-strategy.md) | Empty-DB dialect policy |
| [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md) | G2 non-prod env list |
| [../openapi/console-subset.yaml](../openapi/console-subset.yaml) | Machine contract |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | Cutover G1–G8 |
| [../ARCHITECTURE_TARGET.md](../ARCHITECTURE_TARGET.md) | Phase1 target |
