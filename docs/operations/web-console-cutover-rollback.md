# Web console cutover & rollback (Phase1 WP-V7)

**Audience**: operators  
**Goal**: same-origin Vue `web-console` cutover with **≤5 minute** config-level rollback to embedded React.  
**SSOT**: ADR-0001 · `docs/operations/runtime-separation.md` · Phase1 execution spec WP-V

## Preferred topology (same-origin)

```text
browser  -->  frontend Nginx (:8080)
                 |-- SPA static (React default image OR Vue web-console image)
                 +-- /api /v1 /v1beta /mj /pg /suno /kling /jimeng
                     /healthz /livez /readyz  -->  backend (:3000)
                                                   FRONTEND_MODE=disabled
                                                   build: -tags frontend_external
```

Do **not** use cross-origin SPA + broad CORS as the default path (cookie / CSRF / OAuth risk).

## A. Cutover to Vue (pre-production / internal first)

1. Build pure backend:
   ```bash
   go build -trimpath -tags frontend_external -o new-api-backend .
   # or docker build -f Dockerfile.backend -t new-api-backend:local .
   ```
2. Run backend with `FRONTEND_MODE=disabled` and correct `TRUSTED_PROXY_CIDRS`.
3. Build Vue frontend:
   ```bash
   docker build -f deploy/separated/Dockerfile.frontend.vue -t new-api-frontend-vue:local .
   ```
4. Point edge to Vue frontend container; keep path proxy rules unchanged.
5. Smoke:
   - `GET /frontend-healthz` → `{"status":"ok",...}`
   - `GET /healthz` → ok
   - Browser: login → `/health` shows status + probes
   - `GET /metrics` on public edge → **404**

## B. Rollback to embedded React (≤5 minutes)

**Config / artifact only — no DB down-migration.**

### Option 1 — Integrated binary/image (fastest)

1. Deploy previous **integrated** image/binary (default embed build of `web/default` + `web/classic`).
2. Ensure `FRONTEND_MODE` is unset or `auto` (not `disabled`).
3. Remove or bypass the separated frontend container if it was the only public entry.
4. Verify: open site → React console loads; `POST /api/user/login` still works.

### Option 2 — Separated but React SPA

1. Keep `FRONTEND_MODE=disabled` backend.
2. Replace frontend image with React build:
   ```bash
   docker build -f deploy/separated/Dockerfile.frontend -t new-api-frontend:local .
   ```
3. Redeploy frontend service only; Nginx contract is identical.
4. Verify login + a known React route.

### Checklist after rollback

- [ ] Public origin serves React shell
- [ ] Session cookie login works
- [ ] `/api/status` 200
- [ ] No requirement to reverse SQL migrations

## C. What not to do

- Do not delete `web/default` until cutover gate + soak period.
- Do not enable long-term dual public URLs for React and Vue without sticky cookie strategy (forbidden dual-write product path).
- Do not proxy `/metrics` on the public console origin.

## D. Related files

| Path | Role |
|------|------|
| `deploy/separated/Dockerfile.frontend` | React SPA image (**default**) |
| `deploy/separated/Dockerfile.frontend.vue` | Vue SPA image (Phase1) |
| `deploy/separated/nginx.conf.template` | Shared reverse proxy |
| `web-console/` | Vue source |
| `web/default/` | React LEGACY until cutover |
| `docs/legacy-frontend-gate.md` | New-feature gate for old UI |
