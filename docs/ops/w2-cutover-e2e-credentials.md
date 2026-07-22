# W2 cutover · non-prod credentials for G2/G3 (no production)

> Complements `docs/operations/web-console-cutover-plan.md` and `web-console/E2E.md`.  
> **Never** put real passwords in git. Values below are env **names** and how to obtain them on a **non-prod** instance.

## Why G2 stayed red in W1/W2 agents

| Observation | Implication |
|-------------|-------------|
| Backend may be reachable on `http://127.0.0.1:3000` | Health path works; not proof of cutover |
| Default `root` / `123456` often fails | Live/shared DBs change root password; setup wizard may own first admin |
| Agent hosts often lack `TH_E2E_*` | Login e2e cannot complete without operator-provided non-prod secrets |

G2 = login e2e green on **non-prod**. G3 (channels RO) needs the same session.

## Required env (non-prod only)

| Variable | Required for | Example (local empty only) | Notes |
|----------|--------------|----------------------------|-------|
| `TH_API_BASE` | G2/G3 | `http://127.0.0.1:3000` | Default if unset |
| `TH_E2E_USER` | G2/G3 | `root` | Prefer dedicated e2e user on shared staging |
| `TH_E2E_PASS` | G2/G3 | *(secret)* | Empty-DB default `123456` only after root seed path; **not** production |
| `TH_VITE_BASE` | optional proxy check | `http://127.0.0.1:5173` | Script warns and continues if down |
| `TH_ACCESS_TOKEN` | logs smoke only | *(secret)* | `scripts/smoke-logs.ps1` — not login cookie path |
| `TH_USER_ID` | logs smoke only | `1` | With access token |

## How to mint a non-prod account (operators)

1. Use **staging / local** SQLite or a dedicated staging DSN — not production.
2. Fresh DB: complete `POST /api/setup` (or product setup wizard), then set a strong root password.
3. Or create a dedicated admin: UI or admin API on staging; store password in local secret store / CI secret (`TH_E2E_PASS`).
4. Export for the agent session:

```powershell
$env:TH_API_BASE = 'http://127.0.0.1:3000'
$env:TH_E2E_USER = '<non-prod-admin>'
$env:TH_E2E_PASS = '<non-prod-secret>'   # do not commit
pwsh -NoProfile -File scripts/e2e-web-console-login.ps1 -SkipVite
```

5. After login green, channels RO (G3):

```powershell
# Manual cookie session same as e2e script, then:
# GET /api/channel/ with New-Api-User header — keys must be absent
# Contract: docs/openapi/console-subset.yaml operation getChannelsList
```

## Explicitly out of scope

| Item | Status |
|------|--------|
| Production passwords | Never collected by this wave |
| Production `FRONTEND_MODE` flip | **D7 · W3 + human gate** |
| Storing secrets in repo / report | Forbidden |
| Using production DSN for migrate dry-run | Forbidden |

## Exit codes (`e2e-web-console-login.ps1`)

| Code | Meaning | Typical fix |
|------|---------|-------------|
| 0 | login + self OK | — |
| 1 | login failed | wrong `TH_E2E_*` or setup incomplete |
| 2 | self failed after login | cookie / `New-Api-User` mismatch |
| 3 | backend unreachable | start non-prod API; check `TH_API_BASE` |

## Related

| Path | Role |
|------|------|
| [web-console-cutover-plan.md](../operations/web-console-cutover-plan.md) | G1–G8 gates |
| [web-console/E2E.md](../../web-console/E2E.md) | Script usage |
| [console-subset.yaml](../openapi/console-subset.yaml) | Machine contract |
| [w2-arch-upgrade-transithub-claude.md](./w2-arch-upgrade-transithub-claude.md) | W2 report |
