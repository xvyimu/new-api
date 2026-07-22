# Historical data patches (not golang-migrate versions)

These files were previously under `bin/`. They are **not** part of the automated
`migrations/main` up chain. Do not re-apply on databases that already ran them.

| File | Purpose |
|------|---------|
| migration_v0.2-v0.3.sql | users.quota += sum(tokens.remain_quota) |
| migration_v0.3-v0.4.sql | seed abilities for channels |

Schema evolution uses numbered files under `migrations/main/`.
