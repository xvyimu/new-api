# W1/W2 spike · Gin / go-redis upgrade notes

> **Decision (W1): document only — do not bump.**  
> **Decision (W2 · 2026-07-23): still defer — no Gin 1.10 and no redis v9 bump on this branch.**  
> Reasons: W2 main knife is **console contract + migrate three-dialect evidence**; Gin blast radius ~300+ imports; redis v9 is runtime-critical (auth cache / rate limit). Portfolio still targets maintain-line Gin + redis v9 in a **dedicated** worktree after cutover soak prep, not bundled with contract/migrate PRs.

Recorded W1: 2026-07-23 · worktree `C:\Users\yuanjia\orca\workspaces\src\w1-th-claude` · HEAD `baecf0b1532eeb3edf84538a691e5cd00ac35f9e`.  
W2 reaffirm: worktree `C:\Users\yuanjia\orca\workspaces\src\w2-th-claude` · branch `xvyimu/w2-th-claude`.

## Current

| Module | go.mod |
|--------|--------|
| Gin | `github.com/gin-gonic/gin v1.9.1` |
| Redis | `github.com/go-redis/redis/v8 v8.11.5` |
| GORM | `gorm.io/gorm v1.25.2` (out of spike scope for code change) |

## Available versions (module proxy · this agent)

| Module | Latest listed |
|--------|----------------|
| `github.com/gin-gonic/gin` | **v1.12.0** (also v1.10.x / v1.11.x on line) |
| `github.com/redis/go-redis/v9` | **v9.21.0** |
| `github.com/go-redis/redis/v8` | v8.11.5 (EOL major; still current pin) |

Commands used:

```text
go list -m -versions github.com/gin-gonic/gin
go list -m -versions github.com/redis/go-redis/v9
```

## Gin v1.9.1 → ≥1.10 (target maintain line)

### Risk surface

- **~300+ files** import `github.com/gin-gonic/gin` (router, middleware, controllers, relay handlers).
- Coupled contrib packages already in tree: `gin-contrib/cors`, `gzip`, `sessions`, `static` — verify peer versions on bump.
- Trusted-proxy / security header middleware and `trusted_proxy.go` are Gin-context sensitive.

### Suggested bump path (W2+)

1. Dedicated branch; `go get github.com/gin-gonic/gin@v1.10.1` (or current patch on 1.10+), then iterate to 1.11/1.12 only if 1.10 green.
2. `go test -count=1 ./...` + `go test -count=1 -tags frontend_external .`
3. Manual smoke: login session cookie, SSE/stream relay path, CORS preflight if used.
4. Do **not** combine with redis major in the same PR.

### W1 recommendation

**No bump.** Gap is maintain-line hygiene, not a security emergency for this wave. Prefer later wave after cutover evidence pack stabilizes.

### W2 recommendation

**Still no bump (defer).** Do not combine with contract/migrate deliverables. Next candidate window: dedicated wt after G2 credentials + staging soak prep, still **before** D7 production flip.

## go-redis v8 → v9

### Import sites (direct `github.com/go-redis/redis/v8`)

| File | Role |
|------|------|
| `common/redis.go` | `RDB *redis.Client`, `ParseURL`, pool |
| `common/limiter/limiter.go` | `ScriptLoad` / rate-limit Lua |
| `pkg/cachex/hybrid_cache.go` | Hybrid cache client |
| `middleware/model-rate-limit.go` | Rate limit middleware |
| `model/user_authentication_test.go` | Test double / client |

### Migration notes (from community + module move)

- Module path becomes `github.com/redis/go-redis/v9` (repo rename).
- API is largely context-first already in our call sites; still re-audit every `Cmdable` / pipeline / script SHA use.
- Confirm `ParseURL` option field compatibility and pool defaults.
- Run all rate-limit + cache tests with Redis up and with Redis disabled (`REDIS_CONN_STRING` empty).

### Suggested bump path (W2 dedicated wt)

1. Replace imports; `go get github.com/redis/go-redis/v9@v9.21.0` (or current patch).
2. Fix compile; run unit tests that touch limiter/cache.
3. Integration: `REDIS_CONN_STRING=redis://...` local + rate-limit scripts.
4. Keep Gin pin unchanged in the same PR.

### W1 recommendation

**No bump.** Blast radius is small file-count but high runtime criticality (auth cache, rate limit). Portfolio card placed redis v9 in W2 as evaluation window.

### W2 recommendation

**Still no bump (defer).** Same five import sites; still require Redis-up + Redis-disabled test matrix on a dedicated branch. **Not** done in W2-th-claude.

## Explicit non-goals of this spike

- No `go.mod` / `go.sum` edits on W1/**W2** branch for Gin/redis.
- No production Redis topology change.
- No GORM major/minor bump in the same effort.
- No dual Gin+redis major in one PR.
