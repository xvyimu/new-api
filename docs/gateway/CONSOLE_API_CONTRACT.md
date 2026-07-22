# Console API 契约子集（Phase1 · WP-G G3）

| 字段 | 值 |
|------|-----|
| 日期 | 2026-07-22 · **W2 增量 2026-07-23** |
| 消费方 | `web-console`（WP-V） |
| 提供方 | Go management plane `/api` + probes |
| 版本策略 | **不**引入 `/api/v2`；兼容现有 React 所用约定 |
| 真源 | 实现代码；机器可读子集 `docs/openapi/console-subset.yaml`（见 OPENAPI_AUDIT） |
| 可测入口 | `python scripts/validate-console-contract.py`（exit 0 = 路径/schema 齐） |

---

## 1. 传输与会话

| 项 | 约定 |
|----|------|
| 部署 | **同域** HTTPS；Nginx 反代 `/api` 与探活到 Go；`FRONTEND_MODE=disabled` 推荐 |
| Cookie | 登录成功后 `Set-Cookie` session（`gin-contrib/sessions`）；`HttpOnly`；`SameSite=Strict`（logout 路径显式 Options） |
| 请求 | 浏览器 `credentials: 'include'` / axios `withCredentials: true` |
| CORS | 同域为主；跨站控制台 **非** Phase1 默认 |
| CSRF | 同站模型；不另发明 token 头（沿用现状） |
| Content-Type | `application/json`（login body） |
| 限流 | `/api` 全局 `GlobalAPIRateLimit`；login 额外 `CriticalRateLimit` + `TurnstileCheck`（若服务端开启） |

### 1.1 统一响应壳

成功/失败常见形态（与旧前端一致）：

```json
{
  "success": true,
  "message": "",
  "data": { }
}
```

失败时 `success: false`，`message` 为可读/i18n 文案；HTTP 状态码：业务错误多为 **200 + success=false**（历史习惯），探活失败用 **503**。客户端必须以 **`success` 字段** 为准，不能只看 HTTP 200。

---

## 2. 路径表（P0 必接）

### 2.1 `GET /healthz` · `GET /livez`

| | |
|--|--|
| Auth | 无 |
| 200 | `{"status":"ok","plane":"all"|"management"|"relay"}` |
| 用途 | 边缘/前端显示「API 活着」；`plane` 可辅助运维 |

### 2.2 `GET /readyz`

| | |
|--|--|
| Auth | 无 |
| 200 | `{"status":"ok"}` — DB（及启用时 Redis）可用 |
| 503 | `{"status":"unavailable","component":"database"|"redis"}` |
| 配置 | `READINESS_TIMEOUT_SECONDS`（默认 3） |

### 2.3 `GET /api/status`

| | |
|--|--|
| Auth | 无 |
| 中间件 | gzip · GlobalAPIRateLimit |
| 用途 | 首屏/登录前：系统名、版本、登录方式开关、Turnstile site key、setup 是否完成等 |

**`data` 常用字段（非穷尽；以实机为准，键名稳定者优先依赖）**

| 字段 | 类型（逻辑） | 面板用途 |
|------|--------------|----------|
| `version` | string | 页脚/关于 |
| `start_time` | number | 运行时长 |
| `system_name` / `logo` / `footer_html` | string | 品牌 |
| `password_login_enabled` | bool | 是否展示密码登录 |
| `register_enabled` / `password_register_enabled` | bool | 注册入口 |
| `turnstile_check` / `turnstile_site_key` | bool/string | 人机验证 |
| `github_oauth` / `discord_oauth` / `oidc_enabled` / … | bool | 第三方登录按钮 |
| `passkey_login` 及 passkey_* | bool/string | Passkey |
| `setup` | bool | 是否已安装 |
| `quota_display_type` / `display_in_currency` | string/bool | 展示 |
| `server_address` | string | 链接 |
| `rum_enabled` | bool | 是否打 RUM |

响应外层：`{ success, message, data }`（与 `controller.GetStatus` 一致）。

### 2.4 `POST /api/user/login`

| | |
|--|--|
| Auth | 无（匿名） |
| Body | `{"username":"string","password":"string"}` |
| 中间件 | CriticalRateLimit · AnonymousBodyLimit · TurnstileCheck |
| 成功（无 2FA） | `success: true`，`data`: `{ id, username, display_name, role, status, group }`，并 **Set-Cookie** |
| 成功（需 2FA） | `success: true`，`data.require_2fa: true`；session 为 pending；需再调 `POST /api/user/login/2fa`（MVP 可二期） |
| 失败 | `success: false` + message；密码登录关闭时同 |

**Vue MVP**：先支持密码登录无 2FA 路径；检测到 `require_2fa` 可显示「暂不支持」或跟进 2FA 页。

### 2.5 `GET /api/user/logout`

| | |
|--|--|
| Auth | 无强制（有 cookie 则清） |
| 成功 | `success: true`；Set-Cookie MaxAge=-1 清会话 |

### 2.6 `GET /api/user/self`

| | |
|--|--|
| Auth | **UserAuth**（有效 session） |
| 未登录 | 中间件中断（非 success 壳或 401 形态以现网为准，客户端应跳转登录） |
| 成功 `data` | 含 `id, username, display_name, role, status, email, group, quota, used_quota, permissions, sidebar_modules, setting, ...` |

守卫：进入需登录页前先 `GET /api/user/self`，失败则路由到 Login。

---

## 3. 渠道只读（P0 · cutover G3 · W2 升入契约）

### 3.1 `GET /api/channel/`

| | |
|--|--|
| Auth | **AdminAuth** + permission **ChannelRead** |
| 头 | 登录后 session cookie + `New-Api-User: <user id>`（与 React/Vue 一致） |
| 查询（常用） | `p` / `page_size` · `id_sort` · `sort_by` · `sort_order` · `tag_mode` · `group` · `status` · `type` |
| 成功 `data` | `{ items, total, page, page_size, type_counts }` |
| **密钥** | 列表路径 **`Omit("key")` + `clearChannelInfo`** — 响应不得含明文 API key；取 key 走独立 Root 路径 `POST /api/channel/:id/key`（**不在**本子集） |
| 失败 | 未登录/无权限由中间件中断；业务失败多为 `success: false` |

实现：`controller.GetAllChannels` · 路由 `router/channel-router.go`。

## 3.2 可选（P0 后 / T4）

| 路径 | 用途 | Auth |
|------|------|------|
| `GET /api/setup` | 安装向导 | 公开 |
| `GET /api/system-info/instances` | 实例信息 | Root |
| `POST /api/rum` | Web Vitals | 匿名；body 仅 name/value/rating |

---

## 4. 错误与限流

| 场景 | 期望 |
|------|------|
| 429 | Critical/全局限流；登录页提示稍后重试 |
| Turnstile 失败 | 按现网 message |
| 网络/502 | 反代错误；与 API success=false 区分 |
| readyz 503 | Health 页标红组件名 |

---

## 5. 非目标

- 不在此契约定义 `/v1/chat/completions`（Relay）。
- 不要求 Vue 实现全部 OAuth；仅 status 开关预留。
- 不改 Go handler 去「迁就」理想 REST；契约描述现状。

---

## 6. 给 OpenAPI 子集的映射

| 工件 | 角色 |
|------|------|
| `docs/openapi/console-subset.yaml` | **W2 机器可读契约**（probes · status · login/logout/self · **channels RO**）· 版本 `1.1.0-w2` |
| `python scripts/validate-console-contract.py` | 无第三方依赖的结构/覆盖校验（可 CI 化） |
| `python scripts/openapi_route_diff.py` | 只读：子集 vs 全量 api.json · relay drift |

字段以本文 + 实机抓包为准；yaml 落后时 **以本文与代码为准**。生成 TS client 时以 yaml 为输入，禁止从滞后 `api.json` 全量生成控制台类型。
