# Phase 0 Research: Auth/Token/Session 合刀

> 接地自 pin rust-api `3f2ebc6`／base-web `e79e7aa8`（波 2+D11/013 全收後）。3 支平行 grep agent 實碼盤點 + DESIGN §4.1/§4.3 + constitution §I.7。`file:line` 為快照、會隨 commit rot。

## ★ 接地關鍵發現（決定本刀規模）

| 面 | 現況 | 對 014 含義 |
|---|---|---|
| **Redis client** | **rust-api 完全沒有**（無 crate／AppState 無欄／零 Redis 程式碼／不讀 `APP_REDIS_URL_FILE`；只有 compose 起 redis-stack 容器） | **★ 本刀須先建 Redis 基建**（denylist／pub-sub watcher／pointer 快取全靠它；憲法 §I.7「Redis 僅快取」假設它存在、實際沒有） |
| **JWT Claims** | 已含 `uid`/`sid`/`jti`/`rotation_chain`/`iat`/`exp`/`iss`/`aud`/`roles`（`auth/jwt.rs:12-23`、access/refresh 同型） | ✅ **denylist iat-compare + single-session sid 直接可用、無需改 Claims**（006 已前瞻備好） |
| **`is_current`** | 只比對 pointer、**不讀 policy**（`auth/enforce.rs:74-90`、唯一呼叫點 enforce_mw:157、回 7777、fail-OPEN） | 014 補 `resolve_policy`（讓 `single_session_default`/`session_policy` 生效）；現況「永遠踢」 |
| **`sys_token`** | 9 欄齊（`token_hash` UNIQUE／`rotation_chain`／`status`／`used_at`／`expires_at`），**無 `jti` 欄** | reuse 偵測靠 `token_hash`（sha256(refresh) 查列）；`jti` 在 JWT 內使 body byte-distinct→`token_hash` 不撞、**無需持久化 jti**（符 §I.7） |
| **rotation/refresh** | **無 `/auth/refreshToken` 端點、無 `decide_rotation`、無 `find_by_hash`、無 logout**（login 只寫一列）；註解明標「波3」 | 014 全新建 |
| **settings watcher** | 008 純 KV CRUD（`find_by_key`/`update_by_key`）、**無 watcher/hot-reload**；`single_session_default` production 無讀取點 | 014 建讀取點 + 熱載 watcher |
| **`session_policy` 寫** | `UserWrite`/`build_update_active_model` **不含 session_policy**（create 硬編 inherit、update 不改）；`find_by_id` 不濾 deleted_at（§3.9 gap 之源） | 014 加 session_policy 寫端 + UI |
| **cleanup-job** | **無**（workspace members：server/migration/entity/sea-orm-adapter/xdb；server 只一 bin） | 014 建新 crate |
| **base-web refresh** | **已存在**（soybean starter：`request/index.ts:94-105`→`shared.ts:14-28`→`fetchRefreshToken('/auth/refreshToken')`） | 014 只需 rust 端點對上、**base-web refresh 零改** |
| **base-web 登出碼** | **7777/8888/3333 已配在 `.env`**（modalLogoutCodes=7777,7778／logoutCodes=8888,8889／expiredTokenCodes=9999,9998,3333） | ✅ **base-web 登出碼零改動**（Constitution item 2 攔截器無慮） |
| **base-web session_policy UI** | 009 drawer 7 欄無 session_policy；User 讀型在 **frozen** `system-manage.d.ts`、UserUpsertModel 在 rev3-owned `rev3-system-manage.d.ts` | 014 加 session_policy 走 **rev3-owned typing**（不動 frozen）+ drawer NSelect〔MODAL-WIRING (a)〕+ page i18n |
| **config** | `access_ttl=3600`／`refresh_ttl=7d`／`iss=rev3-admin`／`aud=rev3-admin-web`（main.rs boot 常數）；JwtConfig 在 AppState | denylist TTL=access_ttl=3600s |

---

## D1 — ★ Redis client 基建（本刀新建、規模擴大主因）

- **Decision**：本刀新建 async Redis 基建——加 Redis crate、AppState 加 Redis pool/連線、main.rs 自 `APP_REDIS_URL_FILE`(secret 既存) 初始化。**多工連線**（`MultiplexedConnection` 或 pool）供 denylist 讀寫 + `PUBLISH settings:invalidate`；**專用連線**供 watcher `SUBSCRIBE settings:invalidate`（pub-sub 需獨立連線）。boot **best-effort**：Redis 不可達 → 降級（denylist fail-OPEN、watcher 重試訂閱、單實例 fallback）、**不 panic**（沿 007 xdb 缺檔降級哲學）。
- **Rationale**：憲法 §I.7 §4.3 已凍「pointer 真相在 DB、Redis 僅快取（persist-then-cache、lazy rehydrate）」+ denylist 硬即時撤銷需跨副本共享 store（Redis、避開新表→守零 migration）+ pub-sub 熱載（§I.7「session_mode 讀 runtime store」）。Redis 是設計既定路徑、本刀為其首個 consumer（建基建於首消費者、非 infra-ahead）。
- **Alternatives**：DB denylist 表（違零 migration）；DB 輪詢 settings（無 pub-sub、§I.7 隱含 pub-sub）；不建 Redis 把 pointer/denylist 全 DB（denylist 需表、pointer 快取失、多副本熱載無門）——皆被否決。
- **crate 選擇**：傾向 `redis`(0.27+、`tokio-comp`+`aio`) 或 `deadpool-redis`(pool)；**pin 版 + 容器內驗 1.86 編過**（沿 toml/time/simple_asn1 MSRV 教訓、§6 全域紀律；Cargo.lock 釘版、prod build C-V-8 驗編入）。確切 crate/版於 plan→impl 接地定（首選驗 build 綠者）。

## D2 — resolve_policy（兩層 single-session 策略生效）

- **Decision**：新 `resolve_policy` 純函式（per-user `session_policy`∈{on,off,inherit} × 全域 `single_session_default` → effective on/off）；`is_current` 補讀之（effective off→放行不踢、修現況永遠踢）。`single_session_default` 快取於 AppState（`Arc<AtomicBool>` 或 `RwLock`）、boot 載入、由 watcher(D1 subscribe) 收 `settings:invalidate` 失效重載（§I.7「runtime store、非靜態 config」）。
- **Rationale**：現況 `is_current` 永遠踢、與 `single_session_default='off'` 意圖相反；resolve_policy 為純函式可測（§I.7 decision seam 精神）。
- **Alternatives**：每請求查 DB settings（熱路徑 DB hit、棄）；只全域不 per-user（漏 §4.3 三態、棄）。

## D3 — token rotation chain（refresh 端點 + decide_rotation）

- **Decision**：新 `/auth/refreshToken` 端點（對上 base-web 既有呼叫）：verify refresh JWT(失敗→8888) → pointer-first `is_current`(失敗→7777) → sha256→token_hash → `find_by_hash` → `decide_rotation` 純函式四分支（active→Rotate〔FOR UPDATE、舊 active→used WHERE status=active、插新 active 同 chain〕／used&(now−used_at)<GRACE_SECS(30s)→Benign〔插新、不撤〕／used≥grace·revoked·used_at=NULL→Reuse〔撤整 rotation_chain + warn → 8888〕／notfound→8888）→ 簽新 pair(新 jti)。
- **Rationale**：§I.7 §4.1 凍結（decision seam 純函式、used_at NULL fail-closed、reuse 撤整鏈、refresh 絕不回 3333/9999/9998）。`jti` 使同秒輪替 token byte-distinct→token_hash UNIQUE 不撞。
- **Alternatives**：固定窗口無 grace（誤殺雙擊、棄）；reuse 只撤該列不撤鏈（攻擊者沿鏈、棄）。

## D4 — 硬即時撤銷（Redis denylist、§3.9 閉口）

- **Decision**：Redis denylist `revoked:user:{uid}=revoked_at`(unix)、TTL=access_ttl(3600s)+skew；`enforce_mw`（bearer→is_current 後）查：uid 在名單且 `claims.iat < revoked_at`→reject(8888)；**fail-OPEN**（Redis 不可達→不 reject、撤銷窗口被 access_ttl 兜底）。`revoke_user_sessions(uid)`：撤該 user 全部 active rotation chain(DB) + 清 pointer(DB current_session_id=NULL + Redis sess) + `SET revoked:user:{uid}=now EX access_ttl`；接 009 `deleteUser` + `updateUser(status=2 停用)` handler。re-enable 後新 token iat>revoked_at 自動放行、TTL 到期自清。
- **Rationale**：閉 §3.9 gap（停用/刪 user 的 access token 活到過期）；Redis 共享→多副本一致；無新表→守零 migration（item 8）。
- **Alternatives**：fail-CLOSED（Redis=全站 auth 單點、棄）；per-request 查 DB user-active（熱路徑 DB hit、棄）；DB denylist 表（違零 migration、棄）。

## D5 — cleanup-job binary（新 workspace crate）

- **Decision**：新 workspace crate `cleanup-job`（`rust-api/cleanup-job/`、加入 `members`）：清 `sys_token` 過期列（`expires_at < now() - SKEW_MARGIN_SECS(60s)`、與 status 無關）；**dry-run 預設只 count、`--execute` 才物理刪、冪等、單旗標**（§I.7 §4.1 凍結、不開其他 CLI flag）。
- **Rationale**：§I.7 明文「on-demand cleanup-job binary」。新 crate 便獨立部署/排程。
- **★ 紀律（D-01 校正）**：**新 workspace crate ⇒ prod Dockerfile 須補【四處】COPY**——① Manifest `cleanup-job/Cargo.toml` ② Source `cleanup-job/src` ③ **builder cp `target/release/cleanup-job`→/out〔`Dockerfile.rust-api.txt:60-62`〕** ④ **runtime `COPY /out/cleanup-job`→/usr/local/bin/〔:102〕**。entrypoint 已有 `cleanup-job)` dispatch（exec `/usr/local/bin/cleanup-job`）、缺 ③④ 則 `--bins` 編出卻不落地、prod `exec: not found`、**且 `build` 仍綠**（cp 未列不報錯）→ acceptance 漏。必跑 **prod build + runtime binary 斷言**（`docker run … ls /usr/local/bin/cleanup-job`）；dev bind-mount/`cargo run` 系統性遮缺口（rev2 binary-landing 變體、CLAUDE.md §3 Phase 1）。
- **Alternatives**：server 內 tokio background task 定時清（與 on-demand binary 設計不符、§I.7 棄）；server 加 `[[bin]]`（不獨立、傾向新 crate）。

## D6 — per-user session_policy UI（動 009、跨 feature）

- **Decision**：rust：`getUserList` wire item 加 `sessionPolicy`(honest、literal `'inherit'|'on'|'off'`)；`updateUser` handler/facade 收+寫——`UserWrite` 加 `session_policy: Option<String>`、`build_update_active_model` 加 `Set(session_policy)`（None→不改）。base-web：009 編輯 drawer 加 `session_policy` NSelect〔MODAL-WIRING (a)〕；typing 走 **rev3-owned**（`rev3-system-manage.d.ts` 的 UserUpsertModel 加 `sessionPolicy?` + 一個 rev3 list-item 型帶 sessionPolicy、**不動 frozen `system-manage.d.ts` 的 User**）；page i18n（`page.manage.user.sessionPolicy.*`、先 Schema 後 locale）。addUser 維持建立預設 inherit、override 走編輯。
- **Rationale**：FR-006/FR-009 per-user 覆寫；frozen `system-manage.d.ts` 不可動（§I.1）→ 走 rev3-owned ADAPT typing。
- **Alternatives**：addUser 也設（user 拍板 edit-only、棄）；改 frozen User 型（違 §I.1、棄）。

## D7 — 多實例 B-驗證（dev 第二 instance）

- **Decision**：dev compose 加第二 rust-api service `rust-api-2`（host port `31082`、`profiles:[multi]` opt-in、共享同 DB+Redis、繼承 dev rust-api 定義）。acceptance（C-V）：A 切 `single_session_default`→B 收斂(watcher)；A 登入→B 讀 shared pointer(DB+Redis) 踢；kill Redis pub-sub→watcher 重訂閱；denylist 跨副本一致。**dev 預設仍 1 instance**（不帶 `--profile multi`）；nginx 真 LB/prod 多副本不做。
- **Rationale**：C1 拍板（B-驗證版）；§8.5 de-risk「single-session 跨實例」做進 acceptance（非拋棄式 spike）。`--scale rust-api=2` 撞固定 host port 31081 → 用第二 named service 給 31082、直連 curl 各 instance。
- **Alternatives**：`--scale`（port 撞、棄）；nginx upstream RR（B-部署版、user 否決）；只單實例驗（驗不到跨實例、C1 否決）。

## 收掉的 plan-level opens

- **is_current 4+1 gates**：現況唯 enforce_mw(1 處) → 014 確認 enforce_mw 覆蓋 getUserInfo/getUserRoutes/isRouteExist/系統管理全族（4 access gate 由 enforce_mw 統一掛），refresh 端點為第 5 掛點（pointer-first）。無需逐 handler 加。
- **session_mode 熱載**：008 update_setting handler commit 後 `PUBLISH settings:invalidate`（D1 watcher 收→重載 AppState 快取）；008 動一行 publish（跨 feature 小改、授權內）。
- **denylist key 形**：`revoked:user:{uid}` value=revoked_at(unix str)、`EX access_ttl`；enforce_mw `GET` 一次（熱路徑 +1 Redis GET、受全域 ⚠️a perf 預算）。
- **sess 快取一致性（X-01 校正）**：`sess:{uid}` 採 **invalidate-on-write**（set_pointer best-effort **DELETE**、非 write-through 寫值）——write-through 若 Redis 寫失敗留 stale-hit、多副本下 is_current 讀 stale 恐踢錯會話（踢新留舊、破 SC-006）；DELETE 後下次 miss→DB rehydrate 正確值（契合 §I.7「可失憶 lazy rehydrate」、屬非凍結機制細節）。v1 亦可 defer 快取〔is_current 直讀 DB pointer〕、同 §I.7-compliant。
- **4 access gate 7777 驗證（D-03）**：4 gate 共用同一 `enforce_mw`（單 middleware）→ is_current 一致；acceptance 驗 ≥2 gate（getUserInfo+getUserRoutes）effective-on 各回 7777 即代表（C-V-4）。refresh 端點第 5 掛點獨立驗 7777（C-V-3、D-04）。
- **Redis crate MSRV**：pin + 容器內驗 1.86（Cargo.lock 釘、prod build 驗）；確切 crate/版 impl 接地。
