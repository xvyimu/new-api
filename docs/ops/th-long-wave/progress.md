# TransitHub · Long Wave · Progress

> **Coord:** th-coord · 2026-07-24 · **D7 NOT EXECUTED**

## Status

| Field | Value |
|-------|--------|
| Phase | **催办 · G2 harvested · W3/W4/W6 dispatch** |
| G0 | D = A+C non-prod |
| Flip | **NO** · [G8-HUMAN-CHECKLIST.md](./G8-HUMAN-CHECKLIST.md) |
| Live agents target | ≤3 |

## Inventory

| wt | role | action |
|----|------|--------|
| main | product | keep |
| th-coord | 总控 | active |
| th-g2-e2e-nonprod | W2 | **closing** after review |
| th-g3-channels | W3 | **open** |
| th-g4-image-repro | W4 | **open** |
| th-g6-soak-checklist | W6 | **open** |

W1 / W5 wt reported **rm+push** by human; evidence on coord via cherry-pick.

## Harvest

| Module | Commit / tip | Key exits |
|--------|--------------|-----------|
| W1a console | `4afcf5b3` / `907eaa6b` | pnpm 0 · pack 10 |
| W1b backend scout | `d1dd3278` / `0973f5d3` | tests 0 · migrate sqlite 0 |
| W2 G2 e2e | `d1957b64` / `0d271aaa` | pack **10** · G2 **blocked** |
| W5 G5 regression | `d6e3dfae` / `b162a8bb` | frontend_external **0** · test **0** |

## GATE snapshot

G1 green · G2 **blocked** · G3 live blocked / contract green · G4 blocked·CI · G5 **green** · G6–G8 blocked

## Log

| Time | Event |
|------|--------|
| 2026-07-24 | Week mode · W1 · W2/W5 |
| 2026-07-24 | 催办: G2 DONE blocked honest · G5 on coord · open W3/W4/W6 · close G2 |
