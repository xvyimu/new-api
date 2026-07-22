# W3–W4 · D7 gate dossier (TransitHub) · **D7 FLIP: NOT EXECUTED**

> **Purpose:** Executable pre-flip package for G1–G8.  
> **Does not:** change production `FRONTEND_MODE`, delete React, migrate live DB, or flip traffic.  
> **Requires for live D7:** this dossier green **and** explicit human phrase `D7 flip 现在` (or equivalent).  
> W3 recorded: **2026-07-23** · `...\w3-th-claude` · tip `b2fff447` (later land `97516c0f`).  
> **W4 refresh:** **2026-07-23** · worktree `C:\Users\yuanjia\orca\workspaces\src\w4-th-claude` · branch `xvyimu/w4-th-claude` · tip `97516c0f` + W4 docs/scripts · agent **claude**.

## Summary (W4 · 2026-07-23)

| Gate | Status | Owner | Gap |
|------|--------|-------|-----|
| **G1** Module2 on tip | **green** | platform / TH maintainers | — |
| **G2** Login e2e (non-prod) | **blocked** | operator (creds) | `TH_E2E_*` unset; orchestrator exit **10** (no fake green); legacy e2e exit **1** on default root |
| **G3** Channels RO | **blocked** live · **green** contract | operator + console | live list needs G2; validator exit **0**; pack includes key-omission check when authed |
| **G4** Vue image | **blocked** (agent host) / **CI SSOT** | CI + Docker operator | `docker` still absent; Dockerfile + CI job unchanged |
| **G5** Backend external | **green** | platform | W4 `go build -tags frontend_external` exit **0** (~85 MB) |
| **G6** Staging soak ≥24h | **blocked** (not run) | operator / SRE | checklist only — not executed |
| **G7** Rollback drill | **blocked** (doc + min cmd seq) | operator | W4 minimal command sequence in [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md); **not** timed on host |
| **G8** Owner sign-off | **blocked** | **human** | no `D7 flip 现在` in W3/W4 |

**Flip readiness:** **NO** — G2/G3/G4(local)/G6/G7/G8 open. Production flip **forbidden** until green + human gate.

### W4 new evidence (not flip)

| Artifact | Role |
|----------|------|
| [`scripts/w4-d7-nonprod-verify.ps1`](../../scripts/w4-d7-nonprod-verify.ps1) | One-shot nonprod orchestrator (healthz · status · contract · login · channels RO · builds) |
| [`w4-d7-nonprod-verify.md`](./w4-d7-nonprod-verify.md) | Operator how-to · exit codes · rollback min sequence |
| [`w4-arch-upgrade-transithub-claude.md`](./w4-arch-upgrade-transithub-claude.md) | W4 dual report + recorded exits |

---

## G1 · Module2 on tip · **green**

| Field | Value |
|-------|--------|
| Status | **green** |
| Owner | TH maintainers |
| How to prove | Tree presence on default-branch tip / this worktree |
| Evidence (W3) | All present: `web-console/` · `migrations/` · `docs/gateway/` · `docs/openapi/console-subset.yaml` · `docs/gateway/CONSOLE_API_CONTRACT.md` · `docs/operations/web-console-cutover-plan.md` · `docs/operations/web-console-cutover-rollback.md` · `deploy/separated/Dockerfile.frontend.vue` · `deploy/separated/Dockerfile.frontend` · `deploy/separated/nginx.conf.template` |
| Gap | None |
| Commands | `Test-Path` list (W3 report) — all OK |

---

## G2 · Login e2e (non-prod) · **blocked**

| Field | Value |
|-------|--------|
| Status | **blocked** (credentials) |
| Owner | Operator who controls **non-prod** admin password |
| How to prove | Prefer `pwsh -NoProfile -File scripts/w4-d7-nonprod-verify.ps1` → login step exit **0** (overall 0 only if all steps green). Alt: `scripts/e2e-web-console-login.ps1 -SkipVite` → exit **0** |
| Credentials | Env names only — see [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md). **Never** commit secrets. |
| Evidence (W3) | Backend `http://127.0.0.1:3000/healthz` → **200**. Login as default `root` → `用户名或密码错误…`. Exit **1**. `TH_E2E_*` **unset**. **Not production.** |
| Evidence (W4) | healthz **200** · `/api/status` **200** · `w4-d7-nonprod-verify.ps1 -SkipConsoleBuild -SkipBackendBuild` → exit **10** (`login=10` · no silent default root) · legacy e2e still exit **1** on default root. **Not production.** |
| Gap | Operator must export non-prod `TH_E2E_USER` / `TH_E2E_PASS` (or seed empty local DB via setup wizard). |
| Unblock | Follow w2 credentials checklist § mint non-prod account; re-run W4 pack; attach exit 0 to this dossier. |

---

## G3 · Channels RO · **blocked** (live) / contract **green**

| Field | Value |
|-------|--------|
| Status | **blocked** live · **green** machine contract |
| Owner | Operator (session) + console owners |
| How to prove | Authenticated `GET /api/channel/` same-origin; response lists channels; **keys omitted** from list items. W4 pack runs this after login and fails exit **4** on key leak. |
| Evidence (W3) | OpenAPI `docs/openapi/console-subset.yaml` op `getChannelsList` · human `CONSOLE_API_CONTRACT.md` §3 · `python scripts/validate-console-contract.py` exit **0** |
| Evidence (W4) | Contract re-green exit **0** · live channels step **not run** (blocked on G2 / exit 10) · script path ready in `w4-d7-nonprod-verify.ps1` |
| Gap | Live list requires G2 cookie / `New-Api-User` session |
| Unblock | After G2: re-run W4 pack with `TH_E2E_*`; confirm channels=0 |

---

## G4 · Vue image builds · **CI SSOT** / local **blocked**

| Field | Value |
|-------|--------|
| Status | **blocked** on agent host · **CI is SSOT** |
| Owner | CI (`image-reproducibility`) · local operator with Docker Desktop |
| How to prove (CI) | `.github/workflows/quality.yml` job `image-reproducibility` step **Build separated Vue console image** (`-f deploy/separated/Dockerfile.frontend.vue`) + nginx `-t` on both React and Vue images |
| How to prove (local) | `docker build -f deploy/separated/Dockerfile.frontend.vue -t new-api-frontend-vue:local .` exit 0 |
| Evidence (W3) | `docker` **not on PATH** → local exit n/a. Dockerfile present. CI job definition present on tip. |
| Evidence (W4) | `docker` still **absent** on agent host. No local image build. CI remains SSOT. |
| Gap | This agent cannot re-run docker build. Operators with Docker should record digest on non-prod. |
| Unblock | Run CI on branch/PR **or** local docker build; paste job URL / image id into this dossier |

---

## G5 · Backend `frontend_external` · **green**

| Field | Value |
|-------|--------|
| Status | **green** |
| Owner | platform |
| How to prove | `go build -trimpath -buildvcs=true -tags frontend_external -o <bin> .` exit 0; CI `go-quality` same tag |
| Evidence (W3) | Exit **0** · binary ~89 MB · removed after verify (gitignored `*.exe`) |
| Evidence (W4) | Exit **0** · binary ~85 MB (`88987648` bytes) · removed after verify · also wired into W4 verify pack |
| Gap | None for compile gate |

---

## G6 · Staging soak ≥24h · **blocked** (not run)

| Field | Value |
|-------|--------|
| Status | **blocked** — soak **not executed** W3/W4 |
| Owner | Operator / SRE owning staging |
| How to prove | Staging on Vue edge + `FRONTEND_MODE=disabled` backend for **≥24h**; checklist in [w3-staging-soak-checklist.md](./w3-staging-soak-checklist.md) all critical rows checked |
| Evidence (W3) | Checklist authored only |
| Evidence (W4) | Still not run; pre-soak smoke can use [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md) |
| Gap | No dedicated staging stack controlled by this agent; no dual public React+Vue |
| Unblock | Run soak on **non-prod**; attach log/metrics summary + filled checklist |

### Staging soak — what to watch (summary)

| Signal | Pass criteria (suggest) |
|--------|-------------------------|
| 5xx rate | No sustained spike vs baseline; investigate any burst |
| 4xx auth | No unexpected surge on `/api/user/login` / `/api/user/self` |
| Login | Manual + e2e login remain green |
| Channels RO | `/channels` lists; keys absent |
| Probes | `/healthz` `/livez` `/readyz` `/frontend-healthz` OK |
| Metrics edge | Public origin `/metrics` stays **404** |

Full table: [w3-staging-soak-checklist.md](./w3-staging-soak-checklist.md).

---

## G7 · Rollback drill · **blocked** (doc ready · not executed)

| Field | Value |
|-------|--------|
| Status | **blocked** — **desktop drill documented**, not run on live staging |
| Owner | Operator |
| How to prove | On **non-prod** only: flip Vue → React (integrated or separated React image) in ≤5 min; login works |
| Evidence (W3) | Step table: [w3-rollback-desktop-drill.md](./w3-rollback-desktop-drill.md) · runbook SSOT [web-console-cutover-rollback.md](../operations/web-console-cutover-rollback.md) |
| Evidence (W4) | Minimal command sequence added in [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md) § Rollback · **still not timed** (no docker / no staging) |
| Gap | No docker / no staging compose on this host → cannot time a real flip |
| Unblock | Execute desktop drill on non-prod; record wall-clock and verification exits |

---

## G8 · Owner sign-off · **blocked**

| Field | Value |
|-------|--------|
| Status | **blocked** |
| Owner | **Human product/ops owner** |
| How to prove | Explicit written authorization: `D7 flip 现在` (or cutover-plan “cutover now”) **after** G1–G7 green |
| Evidence (W3) | User W3 prompt: **D7 FLIP NOT EXECUTED** · no production `FRONTEND_MODE` change |
| Evidence (W4) | User W4 prompt: **D7 FLIP NOT EXECUTED** · dual prep only · no production `FRONTEND_MODE` · no push |
| Gap | Human gate not given |
| Unblock | G1–G7 closed + owner phrase |

---

## Gin / redis (optional) · **defer** (W3 + W4)

| Choice | Decision |
|--------|----------|
| Gin 1.10+ **or** redis v9 | **Neither bumped** in W3/W4 |
| Rationale | D7 nonprod pack is the W4 knife; Gin/redis remain dedicated-wt backlog |
| Spike | [w1-gin-redis-spike.md](./w1-gin-redis-spike.md) |
| Pins | Gin `v1.9.1` · redis/v8 `v8.11.5` |

---

## Explicit non-goals (this dossier)

| Item | Status |
|------|--------|
| Production D7 flip | **NOT EXECUTED** (W3 + W4) |
| Production `FRONTEND_MODE` | Untouched |
| Delete `web/default` | Not done |
| Production migrate / live DSN | Not done |
| `git push` / merge main | Not done (总控) |
| TH+CP simultaneous production flip | Forbidden by portfolio protocol |

---

## Related

| Path | Role |
|------|------|
| [w4-arch-upgrade-transithub-claude.md](./w4-arch-upgrade-transithub-claude.md) | W4 report + verification exits |
| [w4-d7-nonprod-verify.md](./w4-d7-nonprod-verify.md) | Nonprod verify pack how-to |
| [w3-arch-upgrade-transithub-claude.md](./w3-arch-upgrade-transithub-claude.md) | W3 report + verification exits |
| [w3-rollback-desktop-drill.md](./w3-rollback-desktop-drill.md) | Non-prod rollback step table |
| [w3-staging-soak-checklist.md](./w3-staging-soak-checklist.md) | 24h soak checklist |
| [w2-cutover-e2e-credentials.md](./w2-cutover-e2e-credentials.md) | G2 env names |
| [../operations/web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | G1–G8 definition |
| [../operations/web-console-cutover-rollback.md](../operations/web-console-cutover-rollback.md) | Operator rollback runbook |
| [../PROJECT.md](../PROJECT.md) §2.2 | Frontend transition SSOT |
