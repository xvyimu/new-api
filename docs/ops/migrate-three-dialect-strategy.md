# Migrations · three-dialect strategy (W2)

> Empty-DB evidence + policy. **No production migrate. No D7.**  
> Companion runner: `scripts/migrate-three-dialect.ps1`  
> Tooling: `cmd/dbmigrate` (golang-migrate · pure-Go SQLite).

## Worktree identity (W2 evidence)

| Field | Value |
|-------|--------|
| Worktree | `C:\Users\yuanjia\orca\workspaces\src\w2-th-claude` |
| Branch | `xvyimu/w2-th-claude` |
| Date | 2026-07-23 |
| Agent | claude (solo) |

## Dialect matrix

| Dialect | Role | Empty-DB file migrate (W2) | Production default | W2 action |
|---------|------|----------------------------|--------------------|-----------|
| **SQLite** | Dev / edge / **CI required** | **Green** — `000001_baseline` → version `1` | AutoMigrate or file migrate OK | Local + CI `sqlite-migrate` job |
| **MySQL** ≥5.7.8 | Common production | **Not validated** with current SQLite-shaped baseline | Keep **`SQL_AUTO_MIGRATE=true`** | Strategy only; opt-in `MIGRATE_MYSQL_URL` |
| **PostgreSQL** ≥9.6 | Preferred production | **Not validated** with current baseline | Keep **`SQL_AUTO_MIGRATE=true`** | Strategy only; opt-in `MIGRATE_PG_URL` |

Hard constraint (AGENTS.md): do not drop SQLite or MySQL support.

## Why MySQL/PG are not green on this baseline

`migrations/main/000001_baseline.up.sql` is **SQLite-exported** (`scripts/export-sqlite-schema`):

- Backtick quoting + SQLite type mix (`integer` / `numeric` / `json` / `datetime`)
- No MySQL engine/charset clauses
- No PostgreSQL type mapping (`boolean`, `timestamptz`, serial/identity)

Running the same file against empty MySQL/PG is **expected to fail** until a dialect-selection mechanism exists (see `migrations/README.md` “Baseline gate”).

## Required before MySQL/PG file-migrate cutover

1. Choose one unambiguous path for `cmd/dbmigrate` (suffix files **or** `main/{sqlite,mysql,postgres}/`).
2. Empty-DB **up + version** for all three dialects in CI (non-prod containers).
3. Document live-install `force` baseline procedure per dialect.
4. Only then set `SQL_AUTO_MIGRATE=false` for that dialect in ops runbooks.

Until then: **file migrate = SQLite CI only**; server dialects stay on GORM AutoMigrate.

## Local commands (non-prod)

### SQLite (required)

```powershell
pwsh -NoProfile -File scripts/migrate-three-dialect.ps1
# or:
pwsh -NoProfile -File scripts/sql-migrate-dry-run.ps1
# or CI-parity:
mkdir -Force .tmp | Out-Null
go run ./cmd/dbmigrate -path migrations/main -database "sqlite://.tmp/ci-migrate.db" up
go run ./cmd/dbmigrate -path migrations/main -database "sqlite://.tmp/ci-migrate.db" version
# expect: 1
```

### MySQL / PostgreSQL (optional · empty DB only)

```powershell
# Create empty local DBs first — never point at production DSN.
$env:MIGRATE_MYSQL_URL = 'mysql://user:pass@tcp(127.0.0.1:3306)/th_migrate_empty'
$env:MIGRATE_PG_URL    = 'postgres://user:pass@127.0.0.1:5432/th_migrate_empty?sslmode=disable'
pwsh -NoProfile -File scripts/migrate-three-dialect.ps1
```

Expect **fail on current baseline** until dialect SQL lands — treat as red evidence, not production incident.

`-RequireMySQL` / `-RequirePostgres` flips SKIP into FAIL when env missing (CI matrix later).

## CI today

| Job | File | Behavior |
|-----|------|----------|
| `sqlite-migrate` | `.github/workflows/quality.yml` | empty SQLite `up` + `version == 1` |
| MySQL/PG matrix | — | **Not added in W2** (would red-fail without dialect SQL) |

W3+ hook: add service containers **after** dialect baselines exist.

## Safety

| Do | Do not |
|----|--------|
| Empty / throwaway DBs for experiments | Point `MIGRATE_*_URL` at production |
| Keep AutoMigrate on for MySQL/PG prod | Flip `SQL_AUTO_MIGRATE=false` without force/up |
| Single-flight migrate Job | Concurrent migrate from every replica |
| Backup before any live force | `down` past baseline on live data |

## Related

| Path | Role |
|------|------|
| [migrations/README.md](../../migrations/README.md) | Layout + three-dialect policy |
| [db-migrations.md](../operations/db-migrations.md) | Ops publish contract |
| [sql-migrate-dry-run-2026-07-22.md](../operations/sql-migrate-dry-run-2026-07-22.md) | Prior SQLite dry-run |
| `scripts/migrate-three-dialect.ps1` | W2 runner |
| `scripts/db-migrate.ps1` | Generic wrapper |
| `cmd/dbmigrate` | In-repo migrate CLI |
