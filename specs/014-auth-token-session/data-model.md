# Phase 1 Data Model: Auth/Token/Session 合刀

> 接地自 pin `3f2ebc6`。**本刀零 migration**——下列 schema 全已存在於 m001/m002（⚠️t 波0全建）；新增者僅 **Redis key schema**（無表）、**解析期型**（in-memory）、**wire DTO 欄**（honest）。

## 1. 既有持久化 schema（零變更、僅讀寫）

### sys_token（archetype C 狀態機、§I.6 C）— 既有，本刀讀寫
`entity/src/sys_token.rs`：`id` / `user_id` / `token_hash`(UNIQUE) / `rotation_chain` / `status`("active"→"used"→"revoked" 單向) / `issued_at` / `expires_at` / `used_at`(Option) / `created_at`。
- 本刀新讀寫：`find_by_hash(token_hash)`→Option<Model>；rotate 時 `UPDATE status='used', used_at=now WHERE id=? AND status='active'`（冪等守門）+ 插新 active 同 chain；reuse 時 `UPDATE status='revoked' WHERE rotation_chain=?`（撤整鏈）。**無 jti 欄**（jti 在 JWT、使 token_hash byte-distinct）。

### sys_user.session_policy / current_session_id — 既有，本刀讀寫
`entity/src/sys_user.rs`：`session_policy: String`(DB default `'inherit'`、∈{inherit,on,off}) / `current_session_id: Option<String>`(pointer)。
- 本刀新寫：`build_update_active_model` 加 `Set(session_policy)`（updateUser）；`revoke_user_sessions` 清 `current_session_id=NULL`。

### system_settings: single_session_default — 既有，本刀讀
`m002:263` seed `('single_session_default','off','enum:on,off',...)`。本刀於 boot 讀入 AppState 快取、watcher 失效重載。008 update handler commit 後 `PUBLISH settings:invalidate`。

## 2. Redis key schema（本刀新增、無表、守零 migration）

| key / channel | 型 | 語意 | TTL |
|---|---|---|---|
| `revoked:user:{uid}` | string = `revoked_at`(unix) | 硬即時撤銷標記；enforce_mw 查 `claims.iat < revoked_at`→reject | `EX access_ttl`(3600)+skew |
| `sess:{uid}` | string = `current_session_id` | pointer 熱快取（persist-then-cache：set_pointer 寫 DB 後 best-effort 寫此；is_current 讀此→miss 回 DB lazy rehydrate） | 無 / 長 TTL |
| `settings:invalidate`（channel） | pub-sub | 008 update 後 PUBLISH；watcher SUBSCRIBE→重載 `single_session_default` 快取 | — |

> 全 fail-OPEN：Redis 不可達 → denylist 不 reject、sess 快取 miss 回 DB、watcher 重試訂閱（§I.7）。

## 3. 解析期型（in-memory、純函式可測）

```rust
// auth/session（或 model/token）
enum RotationDecision { Rotate, Benign, Reuse, NotFound }
// decide_rotation(token_row: Option<&Model>, now) -> RotationDecision
//   None→NotFound / status=active→Rotate / status=used & (now-used_at)<GRACE_SECS(30)→Benign
//   / status=used & ≥grace → Reuse / status=revoked → Reuse / used_at=NULL(非active) → Reuse(fail-closed)

enum EffectivePolicy { On, Off }
// resolve_policy(user_session_policy: &str, global_default: bool) -> EffectivePolicy
//   "on"→On / "off"→Off / "inherit"→ global_default ? On : Off
```
- `GRACE_SECS=30`（rotation、`sys_token.rs` 常數）≠ `SKEW_MARGIN_SECS=60`（cleanup-job crate 常數）——名異值異用途異（§I.7）。

## 4. AppState 擴充（本刀）

```rust
pub struct AppState {
    pub db, pub jwt, pub enforcer, pub trust_model, pub xdb_ready,   // 既有
    pub redis: Arc<RedisPool>,                  // 本刀：多工連線/pool（denylist/publish/sess cache）
    pub single_session_default: Arc<AtomicBool>,// 本刀：runtime 快取（watcher 失效重載、§I.7 非靜態 config）
}
```
- main.rs boot：連 Redis（best-effort 降級）+ 讀 `single_session_default` 初值 + spawn watcher task（SUBSCRIBE settings:invalidate）。

## 5. wire DTO（honest、§I.3 對齊）

- **`/auth/refreshToken`** 回 `LoginToken{token, refreshToken}`（**沿 login 既有形**、base-web `fetchRefreshToken` 已消費）；錯誤碼 8888/7777（信封 §7.3）。
- **`getUserList` item** 加 `sessionPolicy: 'inherit'|'on'|'off'`（literal、honest、NOT NULL 沿 DB default）。
- **`updateUser`**（UserUpsertModel）加 `sessionPolicy?: 'inherit'|'on'|'off'`（Option、未送→不改）。
- IP/id 等沿 §I.3；無新碼（7777/8888 在凍結 13 碼矩陣）。

## 6. Validation rules（自 FR）

- FR-1/2/3：`decide_rotation` 必回四態之一；`used_at=NULL` 於非 active → Reuse(fail-closed)；Rotate 用 `WHERE status='active'` 守冪等（同秒雙寫只一成）。
- FR-4/5：`resolve_policy` 必回 On/Off；effective Off→is_current 放行；`is_current` fail-OPEN（DB/Redis 讀不到 pointer→放行）。
- FR-6：login `set_pointer` 永遠執行；effective On→revoke_other_chains。
- FR-7：denylist `iat < revoked_at` 才 reject；fail-OPEN。
- FR-8：revoke_user_sessions 原子（撤鏈+清 pointer 同 txn；denylist Redis best-effort）。
- FR-11：cleanup-job `expires_at < now-60s`、dry-run 不刪、--execute 刪、冪等。
- FR-14：zero migration（無 CREATE/ALTER；C-V migration up→down→up 仍綠、不新增 mNNN）。
