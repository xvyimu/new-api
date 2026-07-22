# W4 · TransitHub · Claude · architecture upgrade (dual)

## D7 FLIP: NOT EXECUTED

Production `FRONTEND_MODE` **not** changed. No production migrate. No `git push`. No React delete.

## Worktree identity

| Field | Value |
|-------|--------|
| Worktree (absolute) | `C:\Users\yuanjia\orca\workspaces\src\w4-th-claude` |
| Branch | `xvyimu/w4-th-claude` |
| Tip (start) | `97516c0f` (`docs(ops): W3 D7 gate dossier (flip NOT EXECUTED)`) |
| Portfolio baseline | ~`97516c0f` per `prompts/w4-th.md` |
| Agent | **claude** (dual same prompt as codex) |
| Scope | W4 only: nonprod verify pack · dossier G1–G8 refresh · rollback min seq · stack-matrix 收口 · this report |
| Date | 2026-07-23 |

## Delivered

1. **`scripts/w4-d7-nonprod-verify.ps1`** — one-shot nonprod orchestrator (healthz · `/api/status` · contract · login · channels RO key check · optional `pnpm build` · optional `go build -tags frontend_external`). Exit **10** when creds missing (**no fake green**).  
2. **`docs/ops/w4-d7-nonprod-verify.md`** — how-to · exit map · rollback minimal command sequence.  
3. **`docs/ops/w3-d7-gate-dossier.md`** — G1–G8 refreshed with **W4 evidence** rows; no blank statuses.  
4. **Rollback** — min cmd sequence in verify doc + [w3-rollback-desktop-drill.md](./w3-rollback-desktop-drill.md); **not executed** on host.  
5. **`docs/ops/stack-matrix-2026-07.md`** — **W4 收口** column · H2 completion · backlog 3.  
6. Cutover-plan W4 evidence pack pointer · this report.

## Gate snapshot (W4)

| Gate | Status | One-line |
|------|--------|----------|
| G1 | **green** | Module2 tree present |
| G2 | **blocked** | verify pack exit **10** (no `TH_E2E_*`); e2e exit **1** default root |
| G3 | **blocked** live / contract **green** | channels step ready; needs G2 |
| G4 | **blocked** local / **CI SSOT** | docker absent |
| G5 | **green** | `frontend_external` build exit **0** |
| G6 | **blocked** | soak not run |
| G7 | **blocked** | doc + min seq only — not timed |
| G8 | **blocked** | human “D7 flip 现在” not given |

**Flip readiness: NO.** Written blockers (not silent DEFER).

## Intentionally not done (W4 bans)

| Item | Status |
|------|--------|
| **D7 production flip** | **NOT EXECUTED** |
| Production `FRONTEND_MODE` | Untouched |
| Delete / replace React `web/default` | Not done |
| Production migrate / live DSN | Not done |
| `git push` / merge default branch | Not done (总控) |
| Gin 1.10 **or** redis v9 bump | Deferred (backlog) |
| Real staging soak / docker image build on agent | Environment block |
| publish-runtime / asar / ISS | N/A |

## Verification (this message · recorded exits)

Agent: Go **1.26.5** · Node **v24.16.0** (console CI pins 22) · pnpm **11.5.0** · Python **3.14.5** · pwsh **7.6.3**.

### Nonprod pack / G2–G5 / migrate

| # | Command | Exit | Notes |
|---|---------|-----:|-------|
| 1 | `pwsh -NoProfile -File scripts/w4-d7-nonprod-verify.ps1 -SkipConsoleBuild -SkipBackendBuild` | **10** | healthz/status/contract **0**; `login=10` `channels=10` — **actionable block**, not green |
| 2 | `python scripts/validate-console-contract.py` | **0** | 8 ops + schemas PASS |
| 3 | `pwsh -NoProfile -File scripts/e2e-web-console-login.ps1 -SkipVite` | **1** | healthz 200; default root rejected |
| 4 | `pwsh -NoProfile -File scripts/migrate-three-dialect.ps1` | **0** | SQLite version=1; mysql/postgres SKIP |
| 5 | `go build -trimpath -buildvcs=true -tags frontend_external -o new-api-backend-w4-verify.exe .` | **0** | ~85 MB; removed after verify |
| 6 | docker on PATH | **absent** | G4 local blocked; CI SSOT |

### web-console (CWD `web-console/`)

| # | Command | Exit | Notes |
|---|---------|-----:|-------|
| 7 | `pnpm install --frozen-lockfile` | **0** | pnpm 11.5.0 |
| 8 | `pnpm typecheck` | **0** | clean |
| 9 | `pnpm test` | **0** | Vitest 5/5 |
| 10 | `pnpm build` | **0** | dist written · chunk-size warning only |

## DEFER table

| Item | Why deferred | Unblock |
|------|--------------|---------|
| Production D7 flip | No G8; G2–G7 open | Green dossier + human `D7 flip 现在` |
| G2/G3 live | `TH_E2E_*` not on agent | Operator mint non-prod creds · re-run pack |
| G4 local image | docker not on PATH | Docker Desktop / CI job URL |
| G6 soak ≥24h | no staging ownership | Operator staging + checklist |
| G7 timed drill | no compose/docker | Operator run Option A/B · wall-clock |
| Gin ≥1.10 | large import surface | Dedicated wt + full test |
| redis v9 | runtime-critical client | Dedicated wt + full test |
| MySQL/PG empty migrate | no URL env | Provide non-prod URLs per strategy doc |
| React shrink | only after D7 | Post-flip schedule |
| TS client from OpenAPI | not W4 knife | Optional H2 after contract stable |

## Dual · 对侧 (codex) 3 条可吸收优点假设

> Codex 同题 `w4-th.md`；本侧落地前未读对侧报告。下列为**可吸收假设**，合入时对照 codex 报告择优，非断言对侧已做。

1. **Channels RO 更严的 schema 断言** — 若 codex 对 `data.items` / pagination 字段做了强类型/表驱动检查，可并入 `w4-d7-nonprod-verify.ps1` 而不只做 key-omission 启发式。  
2. **G4/CI 证据粘贴模板** — 若 codex 写了 `image-reproducibility` job URL / digest 粘贴位（含 gh 一键命令），补进 dossier G4 Unblock，减少运维摩擦。  
3. **Rollback 计时脚本骨架** — 若 codex 有非生产 wall-clock wrapper（start/stop + checklist file append），可与本侧 min cmd seq 合并为 `scripts/w4-rollback-desktop-drill.ps1`（仍禁生产）。

## Acceptance checklist (W4 prompt)

| Criterion | Met? |
|-----------|------|
| 验证脚本/文档可定位 · 至少 1 次实跑 exit | **Yes** — pack exit **10** + supporting exits |
| dossier G1–G8 无空白 | **Yes** |
| 文首 **D7 FLIP: NOT EXECUTED** | **Yes** |
| 无密钥入库 | **Yes** |
| 对侧 3 优点假设 · DEFER · worktree 绝对路径 | **Yes** |
| 无生产 FRONTEND_MODE · 无 push | **Yes** |

## Related

| Path | Role |
|------|------|
| [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md) | Nonprod verify how-to |
| [w3-d7-gate-dossier.md](./w3-d7-gate-dossier.md) | G1–G8 dossier (W4 refresh) |
| [w3-rollback-desktop-drill.md](./w3-rollback-desktop-drill.md) | Rollback desktop drill |
| [w3-staging-soak-checklist.md](./w3-staging-soak-checklist.md) | 24h soak |
| [stack-matrix-2026-07.md](./stack-matrix-2026-07.md) | Stack card · W4 收口 |
| [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md) | G2 env names |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | G1–G8 + W4 pack |
| [../PROJECT.md](../PROJECT.md) §2.2 | Frontend transition SSOT |
