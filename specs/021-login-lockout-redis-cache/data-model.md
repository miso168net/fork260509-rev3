# Data Model: 021-login-lockout-redis-cache

**Branch**: `021-login-lockout-redis-cache` | **Date**: 2026-06-28

> **零 schema 變更**（無新表/欄/migration）。本刀＝既有 entity 的新【行為】（login gate 分層）＋ Redis key 模型（非 DB）＋ obs log 麵包屑。下列為涉及的既有 entity、Redis key 模型、與 gate 狀態轉移。

## 涉及 Entity（皆既有、本刀不改 schema）

### sys_login_attempt（登入嘗試稽核軌）— archetype B（§I.6）
- append-only：只 `write`（INSERT）、無 update/delete、不可竄改。欄含 `attempted_user_name`/`success`/`operator_id`/`real_ip`/`peer_ip`/`ip_confidence`/`x_forwarded_for`/`region`/`trace_id`/`created_at`。
- 兩複合索引：`idx_login_attempt_ip_time(real_ip,created_at)`／`idx_login_attempt_user_time(attempted_user_name,created_at)`。
- **本刀**：L2（Redis-miss）路徑沿用既有 `count_failed_by_*_since`（讀）＋ `write`（寫、含觸發那發）；**L1（已鎖）路徑不 write**（②b、FR-004 反轉）。archetype B 規則不變（仍只 INSERT、本刀只是鎖後 INSERT 更少列）。

### sys_role / sys_user（不涉）
- 不動。

## Redis Key 模型（L1 加速層、非權威、非 DB）

| Key | 值 | TTL | 寫於 | 讀於 | 語意 |
|---|---|---|---|---|---|
| `lockout:ip:{real_ip}` | `"1"`（占位） | 900s（D3 固定、不 refresh） | L2 達門檻（`ip_fails>=20`）`set_ex` | L1 每請求 `get` | 該來源已鎖（存在＝鎖） |
| `lockout:user:{name}` | `"1"`（占位） | 900s（固定、不 refresh） | L2 達門檻（`user_fails>=5`）`set_ex` | L1 每請求 `get` | 該帳號已鎖（存在＝鎖、擋分散式） |
| `lockout:suppressed:{locked_key}` | INCR 計數 | 900s（自清） | L1 命中 `incr` | ②c flush 時 `take`(GETDEL) | 壓制次數累計（②c、FR-005 count 必需） |
| `lockout:flushed:{locked_key}` | `"1"` | 60s（節流窗） | ②c flush 後 `set_ex` | ②c flush 前 `get`（不存在才 flush） | 節流閘（≤1 麵包屑/60s/key） |

- **不變式**：`lockout:*` 存在性＝鎖定快取（非鎖定真相）；真相在 DB 滑動窗 count。Redis 記憶體＝O(不同被鎖 key)（分散式打 Super 只長 1 個 `lockout:user:Super`）。`{locked_key}` ∈ {`ip:{ip}`,`user:{name}`}（觸發/命中的維度）。
- **distinct-source 廣度**（HLL `lockout:supip:{key}` via PFADD/PFCOUNT）＝**可選/遞延**（clarify Q1、不做 v1）。

## ★ 快取決策純函式（安全核心、可測）

抽純函式供 test-first（不碰 IO）：
- `lockout_keys(ip, name) -> (String, String)`：組 `lockout:ip:{ip}` / `lockout:user:{name}`（key 組裝、可測）。
- `tripped_keys(ip_fails, user_fails, ip, name) -> Vec<String>`：L2 達門檻時要 set 哪些 key（`ip_fails>=20` → ip key；`user_fails>=5` → user key；可同時）。對齊 `is_locked_out`（:68-69）。
- `should_flush(flushed_exists: bool) -> bool`：節流判定（不存在才 flush）。
（鎖定真相判定 `is_locked_out` 不變、已有 `is_locked_out_for_test`。）

## 操作（gate 狀態轉移）

```
login(ip, name):
  # L0 [未來 seam] trusted_ip(ip) bypass — 本刀不實作、結構預留（gate 最頂端）
  # L1 Redis 負快取（fast path、O(1)）— state.redis 為 None（Redis-down）→ 整段跳過（D8 fail-open）
  if get(lockout:ip:{ip}) or get(lockout:user:{name}):     # 命中任一＝已鎖
       incr(lockout:suppressed:{locked_key})                # ②c 累計（TTL 900）
       if not get(lockout:flushed:{locked_key}):            # ②c 節流 ≤1/60s
            n = take(lockout:suppressed:{locked_key})        # GETDEL 讀+重置
            warn!(target:"security.lockout", locked_key, dimension, suppressed=n)  # → loki（FR-005/011）
            set_ex(lockout:flushed:{locked_key}, "1", 60)
       return Err(Biz("auth.login.locked"))                 # ②b 不寫 sys_login_attempt（FR-004 反轉）
  # L2 既有 DB gate（Redis miss＝真相、原邏輯完全不動）
  ip_fails, user_fails = count_failed_by_*_since(...)        # 既有、unwrap_or(0)
  if is_locked_out(ip_fails, user_fails):                    # 既有純函式
       if ip_fails>=20:  set_ex(lockout:ip:{ip}, "1", 900)   # D2/D3 觸發維度 set、固定 TTL
       if user_fails>=5: set_ex(lockout:user:{name}, "1", 900)
       r = Err(Biz("auth.login.locked"))                     # 觸發那發
  else:
       r = login_inner(...)                                  # 既有 6 路徑
  write(sys_login_attempt, ...)                              # ②b：Redis-miss 路徑照寫（含觸發那發、FR-006）
  return r
```

- **自癒**（FR-007）：D3 固定 TTL + ②b 不寫 → 攻擊停 ~900s 後 `lockout:*` 過期、觸發失敗列 age-out → L2 重判 count<門檻 → 解鎖。
- **fail-open**（FR-008、D8）：`state.redis=None` 或個別 op 失敗 → L1 降級、退 L2；鎖定正確性由 DB 維持。

## 不涉及 / 非目標
- 無 schema migration、無新 entity/欄、無新 crate、無新 route、無新 wire（login envelope/2222/`auth.login.locked` 不變）。
- 不動 `is_locked_out` 真相判定、不動 L2 DB gate、不動鎖定政策值（reuse 019：5/20/900）。
- 不做 trusted-IP 白名單（僅留 L0 seam）／CAPTCHA／distinct-source HLL／告警規則配置（clarify Q2 遞延 ops）。
