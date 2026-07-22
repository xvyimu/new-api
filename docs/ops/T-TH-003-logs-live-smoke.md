# T-TH-003 · web-console `/logs` live smoke

| 字段 | 值 |
|------|-----|
| 任务 | T-TH-003 |
| 日期 | 2026-07-22 |
| 分支 tip | `f8be6892`（logs RO + logQuery unit tests） |
| 后端 | `http://127.0.0.1:3000`（live `new-api-fixed.exe` · SQLite `D:\TransitHub\data\one-api.db`） |
| 前端契约 | `web-console/src/api/logs.ts` · `views/LogsView.vue` · `types/api.ts` `LogItem`/`LogListData` |
| 结论 | **PASS**（API live + 响应壳与前端 `normalizeListBody` 对齐；**无代码缺陷，未改业务代码**） |

## 目标

补 wave1 QA（T-TH-002）标出的 P1：在真实后端上验证用量日志只读列表可解析，而非仅静态验收。

## 鉴权说明

- Console 鉴权：`session cookie` **或** `Authorization: <users.access_token>`，且必须带 **`New-Api-User: <user id>`**（与 legacy React / `web-console` axios 拦截器一致）。
- 本机共享库默认 `root/123456` **无效**；admin 账号 `xiejia`（role=100）密码登录在本次 smoke 中失败（哈希已轮换）。
- 成功路径：使用 DB 中已有 **console access_token** + `New-Api-User: 1`（值来自本机 env / DB 只读查询，**未写入仓库**）。
- 脚本环境变量（任选一组）：
  - `TH_ACCESS_TOKEN` + `TH_USER_ID`
  - 或 `TH_E2E_USER` + `TH_E2E_PASS`
  - 可选 `TH_API_BASE`（默认 `http://127.0.0.1:3000`）

## 复跑命令

```powershell
# 仓库 worktree 根（本任务：cl-dev-t-th-003-logs-live）
cd <repo-root>

# 方式 A：access token（推荐；勿把 token 写进脚本或 commit）
$env:TH_ACCESS_TOKEN = '<users.access_token>'
$env:TH_USER_ID = '1'
$env:TH_API_BASE = 'http://127.0.0.1:3000'
pwsh -File scripts/smoke-logs.ps1
# expect EXIT 0

# 方式 B：密码会话
$env:TH_E2E_USER = '<user>'
$env:TH_E2E_PASS = '<pass>'
pwsh -File scripts/smoke-logs.ps1
```

可选单元回归（本任务未改 TS 时仍可绿）：

```powershell
cd web-console
pnpm test
pnpm typecheck
```

## 实测结果（2026-07-22）

| 步骤 | 请求 | 结果 | exit / HTTP |
|------|------|------|-------------|
| 1 | `GET /api/status` | `success=true` · `version=v1.0.0-rc.21-81-gd1397d6e` · `setup=true` | **200** |
| 2 | `GET /healthz` | OK | **200** |
| 3 | `GET /api/log/?p=1&page_size=1` 无鉴权 | `success=false` · 未登录 | **401** |
| 4 | `GET /api/user/self` + access token + `New-Api-User:1` | `username=xiejia` · `role=100` | **200** · success |
| 5 | `GET /api/log/?p=1&page_size=2` | `items[]` · **total=34919** · keys 含 `id,type,created_at,model_name,username,quota,prompt_tokens,completion_tokens,channel,channel_name,request_id` | **200** · success |
| 6 | `GET /api/log/self?p=1&page_size=2` | `items[]` · **total=34917** · 同壳 | **200** · success |
| 7 | `GET /api/log/?type=2&p=1&page_size=2` | consume 过滤 · **total=33894** | **200** · success |
| 8 | 无效 `Authorization` | HTTP 200 + `success=false`「access token 无效」（与 `listLogs` admin 探测后降级到 `/self` 的设计一致） | **200** body fail |

### 脚本实跑

```text
# credentials in process env only (TH_ACCESS_TOKEN + TH_USER_ID=1)
pwsh -File scripts/smoke-logs.ps1
# EXIT: 0
# PASS smoke-logs auth=access_token+New-Api-User(1) adminList=True
# admin /api/log/ items=5 total=34919
# user /api/log/self items=5 total=34917
# admin type=2 items=2 total=33894

# no credentials
pwsh -File scripts/smoke-logs.ps1
# EXIT: 4  (blocked-auth; status/healthz still OK)
```

可选回归（本任务未改 TS，基线仍绿）：

```text
cd web-console
node node_modules/vitest/vitest.mjs run   # 5 tests PASS · EXIT 0
node node_modules/vue-tsc/bin/vue-tsc.js -b --pretty false  # EXIT 0
```

### 与前端解析对齐

- 后端 `data` 壳：`{ page, page_size, total, items }` —— 对应 `LogListData` 与 `LogsView.normalizeListBody`。
- `listLogs`：admin 优先 `GET /api/log/`；`success!==true` 或 HTTP 401/403 → `GET /api/log/self`。
- 样本行字段与表格列（时间/类型/用户/模型/配额/tokens/渠道/request_id）齐全；`created_at` 为秒级时间戳（UI 已兼容）。

## 代码改动

| 路径 | 说明 |
|------|------|
| `scripts/smoke-logs.ps1` | **新增** 可复跑 live smoke |
| `docs/ops/T-TH-003-logs-live-smoke.md` | **新增** 本报告 |
| `web-console/*` | **未改**（live 契约与实现一致，无最小修复必要） |

## 非目标 / 未做

- 未跑 Playwright / 浏览器 UI e2e（任务允许 API smoke；仓内无 Playwright 依赖）。
- 未测「非 admin 用户 403→self」真实第二账号（DB 仅 `xiejia` role=100）；无效 token 的 `success:false` 形状已覆盖 `isAdminLogBodyOk` 降级触发条件。
- 未 DELETE 日志、未改 `FRONTEND_MODE`、未 cutover、未 push。
- 密钥/token **未** 入 git。

## 风险

- 共享 live DB 日志量大（~35k）；分页参数正常，列表延迟可接受。
- access token 轮换后需更新本地 env；密码登录需运维侧账号，不在脚本内硬编码。
- UI 层 live 仍依赖浏览器 cookie/`localStorage.uid`；API 层已证明同源契约可用。

## 验收对照（T-TH-003）

1. [x] 报告含至少一次 live API 实测（成功）  
2. [x] 可复跑脚本 `scripts/smoke-logs.ps1`  
3. [x] 无密钥入仓  
4. [x] 无业务 bug 需修；可选 `pnpm test` / `typecheck` 基线仍为 tip 绿  
