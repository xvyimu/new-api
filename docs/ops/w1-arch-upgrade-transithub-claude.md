# W1 · TransitHub · Claude · architecture/stack upgrade

## Worktree identity

| Field | Value |
|-------|--------|
| Worktree (absolute) | `C:\Users\yuanjia\orca\workspaces\src\w1-th-claude` |
| Branch | `xvyimu/w1-th-claude` |
| HEAD at start | `baecf0b1532eeb3edf84538a691e5cd00ac35f9e` |
| Baseline tip (portfolio `repos/th.md`) | `baecf0b1` — matches |
| Agent | claude (solo) |
| Scope | W1 only: stack-matrix · web-console quality · cutover evidence pack · Gin/redis spike notes |
| Date | 2026-07-23 |

## Delivered

1. **`docs/ops/stack-matrix-2026-07.md`** — current → H2 target → W1 status for Go / Gin / redis / GORM / web-console / React LEGACY / CI pins.
2. **Cutover pre-flip evidence pack** — G1–G5 status embedded in `docs/operations/web-console-cutover-plan.md` (links here). **No D7 / no `FRONTEND_MODE` production flip.**
3. **web-console quality** — re-ran install · typecheck · test · build · NOTICE (all exit 0).
4. **`docs/ops/w1-gin-redis-spike.md`** — Gin 1.9.1→1.10+ and go-redis v8→v9 notes; **default no bump** this wave.
5. **This report** — commands + exit codes + intentional non-goals.

## Intentionally not done (W1 bans)

| Item | Status |
|------|--------|
| `git push` / merge default branch | Not done |
| **D7 production flip** | Not done |
| Change production `FRONTEND_MODE` | Not done |
| Delete / replace React `web/default` | Not done |
| Production migrate / SQL against live DB | Not done |
| Gin or redis `go.mod` bump | Deferred (spike only) |
| publish-runtime / asar / ISS | N/A · out of TH W1 |
| Production CSP/RLS | N/A (CP product) |

## Verification (this message · recorded exits)

Run from worktree root unless noted. Local agent: Go **1.26.5**, Node **v24.16.0** (console CI pins Node 22; build still green), pnpm **11.5.0**.

### web-console (CWD `web-console/`)

| # | Command | Exit | Notes |
|---|---------|-----:|-------|
| 1 | `pnpm install --frozen-lockfile` | **0** | lockfile up to date · 145 packages · pnpm 11.5.0 |
| 2 | `pnpm typecheck` | **0** | `vue-tsc -b --pretty false` clean |
| 3 | `pnpm test` | **0** | Vitest 5/5 (`logQuery.test.ts`) |
| 4 | `pnpm build` | **0** | `vue-tsc -b && vite build` · dist written · chunk-size warning only |

### NOTICE (CI parity · repo root)

| # | Check | Exit | Notes |
|---|-------|-----:|-------|
| 5 | `Select-String` / match `https://github.com/QuantumNous/new-api` in `web-console/src/layouts/ConsoleLayout.vue` | **0** | 1 match |
| 6 | match `Frontend design and development by New API contributors.` in `web-console/src/i18n/locales/en.ts` | **0** | 1 match |

Equivalent CI:

```text
grep -F -- 'https://github.com/QuantumNous/new-api' web-console/src/layouts/ConsoleLayout.vue
grep -F -- 'Frontend design and development by New API contributors.' web-console/src/i18n/locales/en.ts
```

### Cutover gates (pre-flip)

| Gate | Command / proof | Exit | Notes |
|------|-----------------|-----:|-------|
| G1 | tree presence of `web-console/`, `migrations/`, gateway docs | n/a | Met on tip |
| G2 | `pwsh -NoProfile -File scripts/e2e-web-console-login.ps1 -SkipVite` | **1** | Backend **reachable** on `http://127.0.0.1:3000`; login failed with default `root/123456` (`用户名或密码错误…`). **Env block:** need non-prod `TH_E2E_USER`/`TH_E2E_PASS`. Not production. |
| G4 | `docker build -f deploy/separated/Dockerfile.frontend.vue` | **n/a** | `docker` **not on PATH** on this host (`EXIT_DOCKER=1`). CI `image-reproducibility` remains authoritative for Vue image. |
| G5 | `go build -trimpath -buildvcs=true -tags frontend_external -o new-api-backend-w1.exe .` | **0** | Binary ~89 MB; ignored by `*.exe` in `.gitignore` |

### Spike tooling (versions only)

| Command | Exit | Notes |
|---------|-----:|-------|
| `go list -m -versions github.com/gin-gonic/gin` | **0** | latest **v1.12.0** |
| `go list -m -versions github.com/redis/go-redis/v9` | **0** | latest **v9.21.0** |

## Acceptance checklist (W1 prompt)

| Criterion | Met? |
|-----------|------|
| `docs/ops/stack-matrix-2026-07.md` exists | **Yes** |
| Evidence pack has command + exit | **Yes** (this file + cutover-plan table) |
| web-console four commands exit 0 (or env block) | **Yes · all 0** |
| No push / no D7 flip | **Yes** |

## Related

| Path | Role |
|------|------|
| [stack-matrix-2026-07.md](./stack-matrix-2026-07.md) | Stack card |
| [w1-gin-redis-spike.md](./w1-gin-redis-spike.md) | Optional Gin/redis notes |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | G1–G8 + W1 evidence table |
| [../ARCHITECTURE_TARGET.md](../ARCHITECTURE_TARGET.md) | TARGET / D7 human gate |
| `web-console/README.md` | Non-prod smoke table |
| `.github/workflows/quality.yml` | `web-console-quality` · Go 1.26.5 pin |
