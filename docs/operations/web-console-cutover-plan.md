# Production cutover plan — Vue web-console (NO traffic flip yet)

**Status**: Plan only · **2026-07-22**  
**Decision**: User deferred live cutover; this document is the gate package.  
**Does not**: switch production traffic, delete React, change DNS.

## Goal

Same-origin public console served from Vue `web-console`, backend `FRONTEND_MODE=disabled` (`-tags frontend_external`), with **≤5 min** rollback to embedded React.

## Preconditions (all required before flip)

| # | Gate | How to prove |
|---|------|----------------|
| G1 | Module2 on `main` | `web-console/`, `migrations/`, gateway docs present |
| G2 | Login e2e green | `scripts/e2e-web-console-login.ps1` on non-prod |
| G3 | Channels RO usable | `/channels` lists without keys |
| G4 | Vue image builds | `docker build -f deploy/separated/Dockerfile.frontend.vue` |
| G5 | Backend external build | `go build -tags frontend_external` |
| G6 | Staging soak ≥ 24h | Login + health + channels RO; no dual public URLs |
| G7 | Rollback drill | Flip back to React image/binary once on staging |
| G8 | Owner sign-off | Explicit “cutover now” from you |

### W1 pre-flip evidence pack (2026-07-23 · **no production flip**)

Recorded on worktree `C:\Users\yuanjia\orca\workspaces\src\w1-th-claude` · branch `xvyimu/w1-th-claude` · HEAD `baecf0b1532eeb3edf84538a691e5cd00ac35f9e`. Full command table: `docs/ops/w1-arch-upgrade-transithub-claude.md`.

| Gate | Result | Notes |
|------|--------|-------|
| G1 | **Met on tree** | `web-console/`, `migrations/`, `docs/gateway/*` present on tip |
| G2 | **Blocked (credentials)** | Backend at `:3000` reachable; default `root/123456` login failed (`success:false`). Need dedicated non-prod `TH_E2E_USER`/`TH_E2E_PASS` (see `web-console/E2E.md`). Not re-run against production. |
| G3 | Not re-exercised this wave | Prior RO channels work remains; live list needs auth from G2 |
| G4 | **Blocked (no Docker CLI)** | `docker` not on PATH on this agent host. Image path covered by CI `image-reproducibility` + `Dockerfile.frontend.vue`. |
| G5 | **Pass · exit 0** | `go build -trimpath -buildvcs=true -tags frontend_external -o new-api-backend-w1.exe .` (binary gitignored via `*.exe`) |
| G6–G8 | Open | Staging soak / rollback drill / owner flip — **W3 + human gate** |

Also green (TARGET gates 1–2, not a traffic flip): `web-console` `pnpm install --frozen-lockfile` · `typecheck` · `test` · `build` · NOTICE strings — all exit **0**.

## Topology (target)

```text
browser → Nginx (Vue dist)
            ├─ static SPA
            └─ /api /v1 /healthz… → Go :3000
                                    FRONTEND_MODE=disabled
```

Cross-origin SPA + open CORS = **not** the default (cookie / CSRF).

## Cutover steps (when G1–G8 pass)

1. Backup DB; note current image digests.  
2. Deploy backend image/binary with `frontend_external` + `FRONTEND_MODE=disabled`.  
3. Deploy frontend image from `Dockerfile.frontend.vue`.  
4. Smoke: `/frontend-healthz`, `/healthz`, login, `/health`, `/channels`.  
5. Confirm `/metrics` not on public origin.  
6. Soak; watch 4xx/5xx and auth errors.

## Rollback (≤5 min)

See `docs/operations/web-console-cutover-rollback.md`:

- **Fastest**: previous **integrated** React embed image; unset/`auto` `FRONTEND_MODE`.  
- **Alt**: keep external backend; swap frontend image to React `Dockerfile.frontend`.

No SQL down-migration required for UI rollback.

## Explicit non-goals (this plan)

- Deleting `web/default`  
- Long-term dual public React+Vue  
- Turning off AutoMigrate without migration force on live DB  

## Related

| Path | Role |
|------|------|
| `docs/operations/web-console-cutover-rollback.md` | Operator runbook |
| `docs/legacy-frontend-gate.md` | React feature freeze |
| `deploy/separated/Dockerfile.frontend.vue` | Vue image |
| `web-console/E2E.md` | Login e2e |
