# Phase1 Bid · SQL/数据架构师（槽 th-4）

| 字段 | 值 |
|------|-----|
| 角色 | SQL/数据架构师 |
| 槽位 | th-4 |
| 日期 | 2026-07-22 |
| 性质 | **只出方案**；不执行迁移、不改 controller/service 业务逻辑、不 commit/push |
| 用户决议 | `D:\orca\docs\architecture-decision-2026-07-22-approved.md`（Bid-C · SQL 迁移规范） |
| Master | `D:\orca\docs\architecture-stack-refactor-master-2026-07-22.md` Phase1 T2 |
| ASIS | `D:\TransitHub\src\docs\ARCHITECTURE_ASIS.md` §6 / D4 |
| 代码证据基线 | 本 worktree `model/main.go`（`migrateDB` / `migrateLOGDB` / 方言分支） |

---

## 1. 目标与非目标

### 1.1 目标（Phase1 T2 可验收）

1. **产品化 SQL 演进**：从「进程启动时 GORM `AutoMigrate` 即 schema 真源」转为 **`migrations/` 可审、可回放、可版本化** 的主路径。
2. **保留三方言硬约束**：SQLite / MySQL ≥5.7.8 / PostgreSQL ≥9.6 同时可部署（与 `AGENTS.md` 一致）；**不能**在无产品决策下降级为「仅 Postgres」。
3. **日志库分轨**：主库 `SQL_DSN` 与日志库 `LOG_SQL_DSN`（含 ClickHouse）分规范；ClickHouse 不进主库迁移链。
4. **与发布衔接**：迁移步骤进入 release/运维脚本契约（先 migrate 后切流量 / 主节点执行），与现有 `IsMasterNode` 语义对齐或显式替代。
5. **与 Go 模型同步流程**：约定「改 GORM 结构体 → 出迁移文件 → CI 方言矩阵」的单向流程，避免 AutoMigrate 与手工 SQL 双写漂移。
6. **首批迁移清单草案**（本任务只列清单与规范，**不落地 SQL 文件执行**）。

### 1.2 非目标（本 Bid / Phase1 明确不做）

| 不做 | 原因 |
|------|------|
| 执行生产/开发库真实 migrate | 任务禁止；模块二 gate 后再做 |
| 改 controller/service 业务逻辑 | 决策门前只方案 |
| 单切 Postgres 砍掉 SQLite/MySQL | ASIS D4：与 fork 部署形态冲突 |
| 重写计费/配额表语义 | 高风险；迁移只保全结构契约 |
| 引入第二套 ORM 或换 GORM | 无 R2 证据；主参考是 SQL 工具层而非 ORM 宗教 |
| 把 ClickHouse 并入主库 goose/atlas 链 | 已有独立 `migrateClickHouseLogDB` 路径 |
| 数据内容迁移（Option 键搬家等）当 schema 迁移 | `controller/console_migrate.go` 属配置迁移，另轨 |

---

## 2. 改动文件/目录范围

### 2.1 本期方案落地后（模块二）预期新增/触达

```text
migrations/                          # 新建 · 规范根
  README.md                          # 工具、命名、三方言策略、回滚
  schema_migrations 约定说明         # 版本表语义（工具自带或自定义）
  main/                              # 主库 SQL_DSN
    000001_baseline.up.sql           # 首批：从现网 AutoMigrate 结果导出基线
    000001_baseline.down.sql         # 或标注 irreversible
    000002_….up.sql / .down.sql
  log/                               # 可选：非 CH 的 LOG_SQL_DSN（Log 表）
    …
  clickhouse/                        # 可选：从 model 内嵌 SQL 外置
    000001_logs.up.sql
scripts/
  db-migrate.ps1 / db-migrate.sh     # 发布入口：选方言 + 方向 up/down
  db-diff-check.*                    # CI：模型标签 vs 迁移末态（可选阶段）
docs/
  operations/db-migrations.md        # 运维手册（从本 Bid 提炼）
model/
  main.go                            # 模块二：AutoMigrate 收口为「兼容开关」或精简
deploy/ · docker-compose*.yml        # 入口顺序：migrate job → app
.github/workflows/*                  # 方言矩阵 migrate 冒烟
```

### 2.2 本期只写文档（本 worktree 允许）

| 路径 | 动作 |
|------|------|
| `docs/phase1-bid-sql-data-architect.md` | **本文件** |
| 业务 `controller/` `service/` `relay/` | **禁止修改** |
| 现有 `bin/migration_v*.sql` | 只读引用；模块二归档到 `migrations/archive/` 或 docs 附录 |

### 2.3 现状盘点（证据，非改动）

| 现状 | 路径 / 行为 |
|------|-------------|
| 无 `migrations/` | ASIS §2 / §6.1；Glob 确认 0 |
| 主库 AutoMigrate 入口 | `model/main.go` → `InitDB` → 仅 `IsMasterNode` 调 `migrateDB()` |
| 日志库 | `InitLogDB` → `migrateLOGDB()`；CH 走 `migrateClickHouseLogDB` |
| 启动前手写 ALTER | `migrateTokenModelLimitsToText`、`migrateSubscriptionPlanPriceAmount` |
| SQLite 特例 | `ensureSubscriptionPlanTableSQLite`（CREATE + PRAGMA 补列） |
| 历史 SQL | `bin/migration_v0.2-v0.3.sql`、`bin/migration_v0.3-v0.4.sql`（数据补丁，非版本工具） |
| 配置迁移 | `controller/console_migrate.go`（Option 键，非 DDL） |
| 发布脚本 | `scripts/build-release.ps1`、`docs/operations/build-and-release.md` **未**含 schema migrate 步骤 |

---

## 3. 依赖与上下游

```text
[ 本 Bid · SQL 规范 ] ──文档──► 协调员合成 Phase1 执行规格
        │
        ├── 上游依赖
        │     · 用户决议 Bid-C
        │     · Master T2
        │     · ASIS 实体清单 + 本仓 migrateDB 真源
        │     · Go 模型 `model/*.go` gorm tag（结构契约）
        │
        ├── 同级并行（模块一）
        │     · Bid-A Go 边界/OpenAPI：API 不依赖本迁移；共享「表实体名」词汇
        │     · Bid-B web-console：不直连 DB；仅消费 /api
        │
        └── 下游（模块二+）
              · 实现师：落地 migrations/ + 启动开关
              · DevOps：compose/K8s init container 或 release step
              · 测试：SQLite/MySQL/PG 三矩阵 + CH 日志冒烟
              · Phase2 AI-Core 任务表：复用同一 migrations 规范（另库或同库 schema 前缀）
```

### 3.1 运行时耦合点

| 耦合 | 说明 |
|------|------|
| `SQL_DSN` / `LOG_SQL_DSN` | 方言探测逻辑在 `chooseDB`；迁移工具须复用同一探测规则 |
| `common.IsMasterNode` | 今：仅主节点 AutoMigrate；迁出后：migrate 进程/Job 应 **单飞**，app 副本零 DDL |
| `lockForUpdate` / 保留字列 | `group`/`key` 引号策略在 Go 查询层；DDL 层须按方言报价 |
| GORM bool default | AGENTS：慎用 `default:true` 标签；迁移 SQL 用显式 DEFAULT，模型默认放代码 |

### 3.2 工具选型（推荐默认 + R2 空间）

| 方案 | 优点 | 代价 | 建议 |
|------|------|------|------|
| **A. golang-migrate**（CLI + 文件） | 生态成熟、up/down、多驱动、CI 友好 | 需自管三套或条件 SQL | **★ 默认推荐** |
| B. goose | Go 嵌入友好、可 embed | 团队熟悉度；down 纪律 | 可接受替代 |
| C. Atlas / 声明式 | 强 diff | 学习成本、三方言 diff 噪声 | Phase3 再评 |
| D. 继续纯 AutoMigrate | 零引入 | 不可审、不可回滚、生产惊悚 | **否决**（决议 Bid-C） |

**推荐 A**：`migrations/main` 以 **可执行 SQL 文件** 为 SSOT；Go 模型只表达运行时映射，不再承担「隐式演进」。

**三方言策略（核心）**：

1. **优先一份 SQL + 最小方言分支**：能用标准子集（`CREATE TABLE`、`ADD COLUMN`、索引）写一份时不拆。  
2. **必须拆时**：`00000N_name.mysql.up.sql` / `.postgres.up.sql` / `.sqlite.up.sql` 或目录 `main/mysql|postgres|sqlite/`（二选一，落地时固定一种，禁止混用）。  
3. **禁止**依赖 MySQL-only JSON 类型 / PG-only 操作符 / SQLite 不支持的 `ALTER COLUMN` 无回退（与 AGENTS 一致；现网已在 Go 里用分支处理 `price_amount`/`model_limits`）。  
4. **ClickHouse**：独立目录 + 现有 `CREATE TABLE IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` 模式外置。

---

## 4. 分步执行计划（S0… 每步验收）

> 以下步骤供 **模块二实现** 与协调员合成规格使用。本 Bid 完成 = 文档验收，不等于 S1 已编码。

### S0 · 基线冻结（只读）

| 项 | 内容 |
|----|------|
| 动作 | 从 `migrateDB` 导出 **当前 AutoMigrate 实体清单**；对照 ASIS §6.4；标记遗漏（见 §7） |
| 验收 | 清单表评审通过；无业务代码改动 |

**当前 `migrateDB` AutoMigrate 实体（主库，代码真源）**

| # | 模型 | 备注 |
|---|------|------|
| 1 | Channel | |
| 2 | Token | 含 `model_limits` 启动时 text 迁移 |
| 3 | User | |
| 4 | PasskeyCredential | |
| 5 | Option | |
| 6 | Redemption | |
| 7 | Ability | 历史数据补丁见 `bin/migration_v0.3-v0.4.sql` |
| 8 | Log | 亦可在 LOG_DB |
| 9 | Midjourney | |
| 10 | TopUp | |
| 11 | QuotaData | |
| 12 | Task | |
| 13 | Model | |
| 14 | Vendor | |
| 15 | PrefillGroup | |
| 16 | Setup | |
| 17 | TwoFA | |
| 18 | TwoFABackupCode | |
| 19 | Checkin | |
| 20 | SubscriptionOrder | |
| 21 | UserSubscription | |
| 22 | SubscriptionPreConsumeRecord | |
| 23 | CustomOAuthProvider | |
| 24 | UserOAuthBinding | |
| 25 | PerfMetric | |
| 26 | SystemInstance | |
| 27 | SystemTask | |
| 28 | SystemTaskLock | |
| 29 | CasbinRule | |
| 30 | AuthzRole | |
| 31 | SubscriptionPlan | SQLite 走 `ensureSubscriptionPlanTableSQLite`；他库 AutoMigrate；`price_amount` 手写 decimal |

**日志库**

| 路径 | 行为 |
|------|------|
| 非 CH | `LOG_DB.AutoMigrate(&Log{})` |
| CH | `clickHouseLogCreateTableSQL` + `trace_id` 列/索引 + TTL 同步 |

**`migrateDBFast` 缺口（风险）**：并行路径 **未** 含 `CasbinRule` / `AuthzRole`，与 `migrateDB` 不一致。规范落地后应 **删除或对齐** Fast 路径，避免双实现。

### S1 · 目录与 README 规范

| 项 | 内容 |
|----|------|
| 动作 | 建 `migrations/` + README：命名 `NNNNNN_snake_name.{up,down}.sql`、版本表、方言规则、禁止事项 |
| 验收 | 空目录可被 CI 识别；评审通过命名与目录布局 |

### S2 · 工具与脚本挂钩

| 项 | 内容 |
|----|------|
| 动作 | 选定 golang-migrate（或 goose）；`scripts/db-migrate.ps1` 读 `SQL_DSN`，映射 driver，执行 up；文档写入 `docs/operations/db-migrations.md` |
| 验收 | 本地 SQLite 空库 `up` 成功（模块二）；`--dry-run` 或 version 打印可用 |

### S3 · Baseline 迁移草案（首批清单 · 本任务只草案）

| 迁移 ID（草案） | 内容 | 风险 |
|-----------------|------|------|
| **000001_baseline_main** | 主库全量表结构 = 现网 AutoMigrate 稳态导出（三方言各一份或兼容子集） | 高：导出完整性 |
| **000002_token_model_limits_text** | 固化 `migrateTokenModelLimitsToText`（PG/MySQL；SQLite no-op） | 中：幂等 |
| **000003_subscription_plan_price_decimal** | 固化 `migrateSubscriptionPlanPriceAmount` | 中：类型变更 |
| **000004_subscription_plan_sqlite_columns** | 固化 SQLite `ensureSubscriptionPlanTableSQLite` 补列集 | 中：与 000001 重复需合并 |
| **000005_log_trace_id_ch**（CH 轨） | 外置 `trace_id` + bloom index | 低 |
| **A-001 archive** | `bin/migration_v0.2–v0.4.sql` 迁入 `migrations/archive/` 仅文档化，**不**自动 re-run | 低 |

**合并建议**：若 baseline 已从「当前代码跑一次 AutoMigrate 后的库」`mysqldump`/`pg_dump`/`sqlite .schema` 导出，则 000002–000004 可 **并入 baseline**，仅对新环境生效；对存量库用 **baseline version 标记**（`force` 到 1）而非重放 DDL。

**存量库接入流程（运维契约）**：

1. 备份。  
2. 在影子库跑 AutoMigrate 或与生产 schema diff。  
3. 确认无未应用手工 DDL 后 `migrate force 1`（或工具等价）标记 baseline。  
4. 关闭进程内 AutoMigrate（feature flag）。  
5. 之后仅文件迁移。

### S4 · 启动路径收口

| 项 | 内容 |
|----|------|
| 动作 | `InitDB`：默认 **不再** AutoMigrate；`SQL_AUTO_MIGRATE=true` 仅 dev 逃生舱（有限生命周期） |
| 验收 | 生产配置缺 migrate 则 fail-fast 或明确日志；主节点不再隐式改表 |

### S5 · 发布脚本衔接

| 项 | 内容 |
|----|------|
| 动作 | `docs/operations/build-and-release.md` 增加「schema migrate」门闩；compose 增加 `migrate` service；Windows：`build-release` 不绑 migrate，运维 runbook 绑 |
| 验收 | 检查清单：备份 → migrate up → 部署 app → smoke；回滚段见 §5 |

### S6 · Go 模型同步流程（纪律）

```text
1. 改 model/*.go 字段/tag（业务 PR）
2. 同 PR 必带 migrations/main 新版本 SQL（三方言验收说明）
3. 本地：scripts/db-migrate up + go test ./model/...
4. CI：sqlite 必跑；mysql/pg 用 service container
5. 禁止「只改结构体指望 AutoMigrate」
6. 禁止无 down 说明的破坏性变更（不可逆须 README 标注 irreversible）
```

| 验收 | CODEOWNERS 或 PR 模板勾选「含迁移 / 已标 irreversible」 |

### S7 · 观测与门禁

| 项 | 内容 |
|----|------|
| 动作 | 启动日志打印 `schema_version`；admin/system-info 可选暴露；CI 失败阻断合并 |
| 验收 | 版本号与仓库最新 migration 一致可查 |

---

## 5. 风险与回滚

| 风险 | 等级 | 触发 | 缓解 | 回滚 |
|------|------|------|------|------|
| Baseline 与真实生产漂移 | **高** | 手工改表、半失败 AutoMigrate | 导出前三环境 diff；force 前人工确认 | 保留备份；勿 down baseline |
| SQLite `ALTER COLUMN` 限制 | **高** | 类型变更迁移 | 沿用现网：跳过或表重建脚本；优先 ADD COLUMN | 文件级 DB 备份恢复 |
| 多副本同时 migrate | **高** | 去掉 IsMasterNode 未改流程 | migrate Job 单副本 / advisory lock | 重跑幂等 up；修复 version 脏状态 |
| 双轨期 AutoMigrate+文件 | **中高** | 开关未关 | 默认关 AutoMigrate；dev only flag | 关 flag |
| 三方言 SQL 漏写 | **中高** | 只测 SQLite | CI 矩阵；方言文件强制成对 | 修迁移 forward-fix |
| down 不可安全执行 | **中** | 删列/改类型 | 默认生产 **禁止 down**；用 forward-fix + 备份回滚 | 恢复备份优于 migrate down |
| 计费相关列误改 | **高** | quota 类列类型/精度 | 计费表变更独立评审；不与面板绞杀绑同一 PR | 备份 + 禁止自动 down |
| `migrateDBFast` 与 migrateDB 不一致 | **中** | 有人启用 Fast | 删除 Fast 或补齐 Casbin/Authz | N/A |
| CH TTL/列迁移失败 | **中** | 权限/版本 | 保持 IF NOT EXISTS 幂等 | 保留旧表结构仍可写日志 |
| 历史 bin SQL 被误 re-run | **低** | 归档不清 | archive 不进 up 链 | 无 |

**回滚策略分层**

1. **应用回滚**：旧二进制 + **不**自动 down（schema 向后兼容优先：只加不删）。  
2. **迁移回滚**：仅 dev/staging 允许 `migrate down 1`；生产以 **备份恢复** 为主。  
3. **兼容窗口**：破坏性变更拆两步：先扩展读写 → 再删旧列（expand/contract）。

---

## 6. 测试建议

| 层级 | 内容 | 通过标准 |
|------|------|----------|
| 单元 | 方言探测与 migration 文件命名解析（脚本） | 表驱动 |
| 集成 · SQLite | 空库 up → 应用冒烟（healthz）→ 可选 down | exit 0 |
| 集成 · MySQL | compose service；utf8mb4 检查与现网 `checkMySQLChineseSupport` 不冲突 | migrate + 选表 INSERT |
| 集成 · PG | 保留字列 `"group"`/`"key"` 建表与 Go 查询共存 | 关键路径 query OK |
| 集成 · CH | 仅 LOG；create + trace_id 幂等二次 up | 无 error |
| 回归 | `go test ./model/...` 含 locking、task CAS 等不依赖隐式新列假设 | 全绿 |
| 存量模拟 | 旧库 force baseline 后再 up 新版本 | version 单调 |
| 发布演练 | runbook dry-run：备份 → up → 部署 → 回滚二进制 | 检查单勾选 |
| 明确禁止 | 随机 fuzz DDL、以 coverage 为目的的空测 | 符合 AGENTS 测试质量 |

---

## 7. 相对主参考偏离（若有）+ 证据

| 项 | 主参考 | 本方案 | 判定 |
|----|--------|--------|------|
| SQL 为通用工具 + `migrations/` | Master §1 / §3.2 / T2 | 采纳文件化 migrations | **对齐** |
| Postgres 优先 | Master §1「Postgres 优先；边缘 SQLite」 | **保留三方言**；PG 为推荐生产，SQLite 边缘/dev，MySQL 存量 | **有意偏离（兼容）** |
| 偏离证据 | ASIS §6.5、AGENTS「三库必须」 | 单切 PG 破坏既有部署与 CI 假设 | R2：契合度 + 迁移工期；代价=迁移文件分支 |
| 不用声明式 Atlas 作默认 | 未强制 | 选 golang-migrate 命令式 | **可接受**；Phase3 可 R2 再议 |
| AutoMigrate 过渡 flag | 主参考未写 | 短期 dev 逃生舱 | **迁移窗口并行**（R4 允许） |
| ASIS §6.4 列 RefundIntent | 测绘含 | **本 worktree `migrateDB` 无 RefundIntent** | 以代码为准；实现前再扫 `model/` 防漏表 |

**与 ASIS 的差异（以代码为准）**

- ASIS 写「RefundIntent」等：当前分支 `migrateDB` **未** AutoMigrate `RefundIntent`（Grep 无匹配）。首批 baseline **以 `model/main.go` 列表为准**，另开「模型存在但未迁移」审计项。  
- `migrateDBFast` 缺 Casbin/Authz：规范要求消灭双路径。

---

## 8. 工作量粗估

| 阶段 | 人天（1 人等价） | 说明 |
|------|------------------|------|
| 规范终稿 + 目录脚手架 | 0.5–1 | README、runbook、脚本骨架 |
| Baseline 导出与三方言校验 | 2–4 | 最大不确定；含存量 force 流程 |
| 固化现有手写 ALTER/SQLite 特例 | 1–2 | 并入或紧随 baseline |
| 启动收口 + flag | 0.5–1 | `InitDB`/`InitLogDB` |
| CI 矩阵 + compose migrate | 1–2 | sqlite 必选；mysql/pg 容器 |
| CH 外置 | 0.5 | 可选同期 |
| 文档与发布清单 | 0.5 | build-and-release 挂钩 |
| **合计（模块二）** | **约 6–11 人天** | 不含全量业务功能开发；可 1 人串行或 2 人（规范+CI // baseline） |

**本 Phase1 Bid 本身**：只读测绘 + 本文 ≈ 已完成；**0** 业务代码改动。

---

## 附录 A · 首批迁移清单草案（汇总）

| ID | 轨 | 摘要 | 可逆 | 优先级 |
|----|----|------|------|--------|
| 000001 | main | 全量 baseline schema | 否（irreversible） | P0 |
| 000002 | main | tokens.model_limits → text（若未进 baseline） | 条件 | P0 |
| 000003 | main | subscription_plans.price_amount → decimal(10,6) | 条件 | P0 |
| 000004 | main | SQLite subscription_plans 列齐套 | 部分 | P0 |
| 000005 | ch | logs.trace_id + index | 是（drop column） | P1 |
| ARCH-v02 | archive | users.quota += tokens 历史数据 | N/A | 文档 |
| ARCH-v03 | archive | abilities 种子 | N/A | 文档 |

## 附录 B · 关键证据锚点

| 主题 | 位置 |
|------|------|
| AutoMigrate 列表 | `model/main.go` `migrateDB` ~L284–336 |
| 主节点门闩 | `InitDB` / `InitLogDB` `IsMasterNode` |
| SQLite 特例 | `ensureSubscriptionPlanTableSQLite` |
| 类型修补 | `migrateTokenModelLimitsToText` / `migrateSubscriptionPlanPriceAmount` |
| CH | `migrateClickHouseLogDB` 及 SQL builder |
| 历史 SQL | `bin/migration_v0.2-v0.3.sql`、`v0.3-v0.4.sql` |
| 配置非 DDL | `controller/console_migrate.go` |
| 产品约束 | `AGENTS.md` Database compatibility / JSON / locking |
| 决议 | architecture-decision Bid-C；Master T2 |

## 附录 C · 给协调员的合成要点（3 条）

1. **采纳**：`migrations/` + golang-migrate（或等价）+ 主库/日志/CH 分轨 + 生产禁止隐式 AutoMigrate。  
2. **强制保留三方言**；Postgres 优先仅作推荐部署，不作唯一支持。  
3. **存量**：baseline + `force` 标记，不以 re-run 历史 `bin/*.sql` 当升级路径。

---

*Bid 结束。等待协调员回收三方案后合成 Phase1 执行规格；模块二前不改业务代码。*
