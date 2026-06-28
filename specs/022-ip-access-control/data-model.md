# Data Model: 022-ip-access-control

**Branch**: `022-ip-access-control` | **Date**: 2026-06-28

> **1 schema 變更**（新表 `sys_ip_rule`、migration m007）。本刀＝新受管實體 + in-process RuleSet（記憶體判定）+ Redis key（invalidate 門鈴 + reset-marker + ②c 計數，非 DB）+ 既有 `sys_login_attempt` 之新【行為】（白名單跳 lockout、per-dim reset）。

## 涉及 Entity

### sys_ip_rule（IP 存取規則）— 新表、archetype 受管實體 + soft-delete + 稽核 shadow（沿 system_settings/sys_role）

| 欄 | PG 型 | 說明 |
|---|---|---|
| `id` | `bigserial` PK | auto-increment |
| `cidr` | `cidr`（或 `inet`）NOT NULL | sea-orm `IpNetwork`、v4/v6 通用、單 IP=/32·/128 |
| `rule_type` | `varchar` NOT NULL | `'allow'` \| `'deny'`（字串-enum） |
| `order` | `int4` nullable（`column_name="order"`） | **純查看排序、不影響比對、admin 給值、永不被覆寫** |
| `description` | `varchar` nullable | 規則用途 |
| `created_at` | `timestamptz` NOT NULL default now | 稽核 |
| `created_by` | `int8` nullable | operator |
| `updated_at` | `timestamptz` nullable | 稽核 shadow |
| `updated_by` | `int8` nullable | |
| `deleted_at` | `timestamptz` nullable | soft-delete |
| `deleted_by` | `int8` nullable | |

- **索引**：PK；**partial unique** `UNIQUE (cidr, rule_type) WHERE deleted_at IS NULL`（防 active 重複；`execute_unprepared`、沿 m001:753-766）。無額外查詢索引（小表、boot 全載 + CRUD 分頁皆足）。
- **archetype**：受管實體（CRUD + soft-delete + 稽核 shadow）。op-log：create/update/soft_delete/restore 各同 txn 寫 `sys_operation_log`（AuditEvent、沿 sys_menu）。
- **不變式**：同 `(cidr,rule_type)` 的 active 列至多一條（partial unique）；`order` 永不被 soft_delete/restore 覆寫（已刪沉底靠查詢排序式、非改值）。

### sys_login_attempt（既有、archetype B append-only）— 不改 schema、新【行為】
- 不加欄。本刀新行為：①白名單來源於 login L0 seam 跳過 L1/L2 lockout（不評估其失敗 count）；②手動解鎖以 reset-marker 調整 `since`（不刪/不改既有列）。archetype B（只 INSERT、不可竄改）規則不變。

### sys_role / sys_user / casbin_rule（不改 schema）
- `casbin_rule`：m007 seed 6 route p-policy（R_SUPER）+ menu policy（`manage_ip-rule`）。

## In-process RuleSet（記憶體判定、非 DB）

```rust
pub struct RuleSet { pub allow: Vec<IpNetwork>, pub deny: Vec<IpNetwork> }
// AppState.ip_rules: Arc<ArcSwap<RuleSet>>
```
- boot：`facade::sys_ip_rule::load_active()`（`WHERE deleted_at IS NULL`、依 rule_type 分兩袋、parse 成 `Vec<IpNetwork>`）→ `ArcSwap::from_pointee`。DB 錯→空集（fail-OPEN）。
- 刷新：watcher 收 `ipgate:invalidate`→重讀 DB→`ip_rules.store(新 RuleSet)`。
- 判定：每請求 `ip_rules.load()`（lock-free）→ `allow.any(|n|n.contains(ip))` / `deny.any(...)`。

## Redis Key 模型（非 DB；invalidate 門鈴 + reset-marker + ②c）

| Key | 值 | TTL | 寫於 | 讀於 | 語意 |
|---|---|---|---|---|---|
| `ipgate:invalidate`（channel） | 空 payload | — | CRUD 改規則後 `publish` | watcher `subscribe` | 規則變更門鈴（重讀 DB） |
| `ipgate:blocked:{deny_cidr}` | INCR 計數 | 自清（如 900s） | ②c 被擋時 incr | ②c flush take(GETDEL) | 被擋量級（per 命中 deny 規則、節流摘要） |
| `ipgate:flushed:{deny_cidr}` | `"1"` | 60s | ②c flush 後 set_ex | ②c flush 前 get | 節流閘（≤1 摘要/60s/規則） |
| `lockout:reset:user:{name}` | reset 時刻 unix 秒 | 窗（900s） | 手動解鎖 set_ex | 021 L2 gate get→`since_user` | 帳號維度解鎖標記（沿 `set_revoked` 存值範式） |
| `lockout:reset:ip:{ip}` | reset 時刻 unix 秒 | 窗（900s） | 手動解鎖 set_ex | 021 L2 gate get→`since_ip` | 來源維度解鎖標記 |

- 既有 021 key（`lockout:ip/user`、`lockout:suppressed/flushed`）不變；手動解鎖 `del lockout:{dim}:{value}` + companions。

## CIDR 比對純函式（安全核心、可測）
- `STRUCTURAL_EXEMPT: &[IpNetwork]`＝`["127.0.0.0/8","::1/128","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","fc00::/7"]`。
- `decide(ip, &RuleSet) -> Decision{Allow|Block}`：白集任一 contains→Allow；黑集任一 contains→Block；else Allow（default-allow）。**結構豁免 + path 豁免在 decide 之前於 middleware 短路**。
- 比對為**集合 any-match**（非 first-match 規則鏈、白優先於黑由程式碼順序保證、無 priority 欄、FR-016）。

## 操作（gate 狀態轉移）

```
# ── 全站每請求（ipgate_mw、audit_mw 內側）──
ipgate_mw(req):
  if path ∈ {/health,/metrics}: → 放行
  ip = ctx.client_ip                      # audit_mw 注入（含 D5 tunnel fallback）；無 ctx→fail-OPEN 放行
  if in_set(ip, STRUCTURAL_EXEMPT): → 放行   # loopback/私網、不可被規則擋（僅豁免阻擋、非 lockout-bypass）
  rules = ip_rules.load()                  # arc-swap lock-free
  if rules.allow.any(contains ip): → 放行
  if rules.deny.any(contains ip):  → ②c(incr+節流 warn) → Err(PermissionDenied 5003/403)
  → 放行                                    # default-allow
  # fail-OPEN：load/parse 失敗→空集→放行

# ── login gate（既有 021 + 本刀 D6/D7）──
login(ip, name):
  if rules.allow.any(contains ip): → 跳過 L1/L2 lockout（D6 白名單免鎖）→ login_inner
  # L1/L2 既有 021，但 since 改 per-dim（D7）：
  reset_ip   = get(lockout:reset:ip:{ip})       # 手動解鎖標記
  reset_user = get(lockout:reset:user:{name})
  since_ip   = max(now-窗, reset_ip)
  since_user = max(now-窗, reset_user)
  ip_fails   = count_failed_by_ip_since(ip, since_ip)
  user_fails = count_failed_by_user_since(name, since_user)
  ... 既有 is_locked_out / set_ex / write ...

# ── 手動解鎖 handler ──
unlock(dim, value):
  del lockout:{dim}:{value}  (+ suppressed/flushed companions)
  set_ex(lockout:reset:{dim}:{value}, now_unix, 窗)
  # both-dims 鎖：須對兩維各呼一次（UI 提示）
```

## 不涉及 / 非目標
- 無第 2 個 migration、無新 entity 欄（除 sys_ip_rule 新表）、無新 crate（arc-swap 提升既有）、無新 wire 碼（blocked reuse 5003）。
- 不動 `is_locked_out` 真相判定、不動 L2 既有 count facade、不動鎖定政策值（reuse 019：5/20/900）。
- 不做 runtime 可調門檻／IPv6 /64 群組／CAPTCHA／distinct-source HLL／告警規則配置（§5 defer）。
