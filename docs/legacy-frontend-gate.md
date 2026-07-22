# LEGACY frontend gate (Phase1 WP-V6)

**Status**: draft gate for strangler migration  
**Date**: 2026-07-22  
**Resolution**: B — new UI in `web-console` only; no long-term React+Vue dual-write

## Labels

| Path | Label | Rule |
|------|-------|------|
| `web-console/**` | **Target console** | Default home for **new** admin UI features |
| `web/default/**` | **LEGACY** | Security / severe regression hotfixes only |
| `web/classic/**` | **L2 frozen** | No feature parity work; no new screens |

## Allowed changes on LEGACY (`web/default`)

- Security fixes (XSS, auth bypass, dependency CVE in that tree)
- Production-breaking regression fixes with linked incident
- Build/tooling fixes required to keep embed path bootable for **rollback**
- i18n typo fixes only if already broken in production

## Forbidden on LEGACY (without explicit cutover exception)

- New product features, new settings pages, new tables/forms
- Refactors “while we are here”
- New OAuth providers or billing UI only on React
- Parallel “improve React and Vue” dual implementation of the same feature

## CODEOWNERS (proposed)

If/when the repo enables GitHub CODEOWNERS, use:

```text
# Phase1 panel strangler — adjust team handles before merge to default branch
/web-console/          @xvyimu
/web/default/          @xvyimu
/web/classic/          @xvyimu
/deploy/separated/     @xvyimu
```

Reviewers must reject PRs that add features under `web/default` or `web/classic` unless the description contains `LEGACY-HOTFIX` and an incident link.

## CI notes (proposed, not required for MVP merge)

- Keep existing `web/default` quality jobs until cutover (rollback must stay green).
- Add optional job: `web-console` → `pnpm typecheck` + `pnpm build`.
- Optional label check: changes under `web/default/src/features/**` require `legacy-ui` label.

## PR checklist snippet

```markdown
- [ ] UI changes are under `web-console/` (or documented LEGACY-HOTFIX)
- [ ] No new long-lived dual implementation of the same screen in React and Vue
- [ ] Billing / relay semantics untouched
```

## Cutover end-state

After organizational cutover gate:

1. Public edge serves Vue image by default.
2. React remains buildable for one release window as rollback artifact.
3. Then archive or delete classic; default either removed or docs-only.

See `docs/operations/web-console-cutover-rollback.md`.
