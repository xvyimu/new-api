# Database migrations (Phase1 WP-S)

## Tool

- **Default**: [golang-migrate](https://github.com/golang-migrate/migrate) CLI (`migrate`).
- **Source of truth for new schema changes**: SQL files under this tree (not GORM AutoMigrate alone).
- **App default**: `SQL_AUTO_MIGRATE` defaults to **enabled** (conservative). Production cutover sets `SQL_AUTO_MIGRATE=false` and applies files before traffic.

## Layout

```text
migrations/
  main/                 # SQL_DSN (SQLite / MySQL / PostgreSQL)
    NNNNNN_name.up.sql
    NNNNNN_name.down.sql
  archive/              # Historical bin/ data patches (not auto-run)
  clickhouse/           # Optional LOG_SQL_DSN=clickhouse (separate track)
  README.md             # This file
```

Version table: `schema_migrations` (managed by golang-migrate).

## Naming

- `NNNNNN_snake_case.up.sql` / `.down.sql` (six-digit zero-padded version).
- Prefer **one dialect-portable SQL** when possible.
- When dialects diverge, use explicit suffixes or subdirs (pick one style per PR; do not mix):
  - `000002_add_foo.mysql.up.sql` + matching postgres/sqlite, **or**
  - `main/mysql/`, `main/postgres/`, `main/sqlite/` (future).

## Three-dialect policy

| Dialect | Role | Baseline status (Phase1) |
|---------|------|---------------------------|
| **SQLite** | Dev / edge / CI required | `000001_baseline` verified empty-DB `up` |
| **MySQL** | Common production | Prefer AutoMigrate or dialect follow-up; do not drop support |
| **PostgreSQL** | Preferred production (Master) | Same as MySQL until dedicated baseline |

Hard constraint (AGENTS.md): **do not remove SQLite or MySQL** without a product decision.

Rules:

1. Prefer standard subset: `CREATE TABLE`, `ADD COLUMN`, indexes.
2. No MySQL-only / PG-only / SQLite-unsupported `ALTER COLUMN` without a fallback branch.
3. Expand/contract for breaking changes; never silent column drop in up migrations.
4. ClickHouse log schema is **not** on the main track.

## Developer workflow (model ↔ SQL)

1. Change `model/*.go` structs/tags if needed.
2. Same PR: add `migrations/main/NNNNNN_*.up.sql` (+ down or mark irreversible).
3. Local: `pwsh -File scripts/db-migrate.ps1 -Direction up` (SQLite).
4. CI: SQLite migrate job must pass.
5. **Forbidden**: rely only on startup AutoMigrate for production schema evolution.

Export helper (draft baseline refresh):

```powershell
go run ./scripts/export-sqlite-schema/ > tmp_schema.sql
```

## Commands

**Preferred runner**: in-repo `cmd/dbmigrate` (pure-Go SQLite driver, no CGO; works on Windows CI).

```powershell
# Empty SQLite demo
go run ./cmd/dbmigrate -path migrations/main -database "sqlite://.tmp/migrate-demo.db" up
go run ./cmd/dbmigrate -path migrations/main -database "sqlite://.tmp/migrate-demo.db" version

# Or wrapper
pwsh -File scripts/db-migrate.ps1 -Direction up
```

Optional external CLI (needs CGO for sqlite3 tag): `go install -tags sqlite3 github.com/golang-migrate/migrate/v4/cmd/migrate@v4.18.3`.

See also `docs/operations/db-migrations.md`.

## Historical files

`bin/migration_v0.2-v0.3.sql` and `v0.3-v0.4.sql` are archived under `migrations/archive/`. Do not re-run them automatically.
