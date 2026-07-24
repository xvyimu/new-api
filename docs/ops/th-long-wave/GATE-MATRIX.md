# TransitHub · Long Wave · GATE Matrix

> SSOT · inherits W3/W4 + scout + long-wave W1/W2/W5 · **no greenwash**  
> Plan: `docs/operations/web-console-cutover-plan.md` · Week: [WEEK-BACKLOG.md](./WEEK-BACKLOG.md)  
> **D7 FLIP: NOT EXECUTED** · G0=**D** · 2026-07-24

Updated: **2026-07-24** (催办 harvest)

| Gate | Status | Evidence | Unblock |
|------|--------|----------|---------|
| **G1** | **green** | Module2 tree · W1 console quality | — |
| **G2** | **blocked** (honest) | `th-g2-e2e-nonprod-evidence-2026-07-24.md` · W4 pack **exit 10** · `TH_E2E_*` unset · healthz/status/contract 0 | non-prod `TH_E2E_*` · re-run pack |
| **G3** | **blocked** live · contract **green** | G2 evidence: channels=10 · contract step 0; W3 worker refreshing | after G2 live |
| **G4** | **blocked** local · **CI SSOT** | docker absent historically; W4 worker | Docker or CI digest |
| **G5** | **green** (refreshed) | `th-g5-backend-regression-evidence-2026-07-24.md` · tip `d6e3dfae` · `frontend_external` **0** · `go test common+model` **0** · migrate sqlite **0** | — |
| **G6** | **blocked** | W6 worker · no full 24h | staging owner |
| **G7** | **blocked** | doc only | W7 later |
| **G8** | **blocked** | no `D7 flip 现在` | [G8-HUMAN-CHECKLIST.md](./G8-HUMAN-CHECKLIST.md) |

## Workers now

| ID | wt | Status |
|----|-----|--------|
| W2 G2 | `th-g2-e2e-nonprod` | **DONE · reviewed · closing** |
| W5 G5 | (rm by human) | **DONE · reviewed** · on coord |
| W3 G3 | `th-g3-channels` | opening |
| W4 G4 | `th-g4-image-repro` | opening |
| W6 G6 | `th-g6-soak-checklist` | opening |

## Flip

**Forbidden** without human phrase. Exit 10 / docs / push **≠ D7**.
