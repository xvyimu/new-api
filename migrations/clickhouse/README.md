# ClickHouse log migrations

Main track is `migrations/main` (SQLite/MySQL/PostgreSQL).

ClickHouse (`LOG_SQL_DSN=clickhouse://...`) still uses `model.migrateClickHouseLogDB` until SQL here is wired.

Do not merge CH DDL into `main/`.
