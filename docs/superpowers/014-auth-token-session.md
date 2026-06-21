# 014 · Auth/Token/Session 合刀 — spec-design（Phase 0 brainstorm）

> **性質**：spec-kit feature **014** 的 Phase 0 brainstorm spec-design（CLAUDE.md §3 階段 0 產物）。本檔聚焦**需求 / 範圍 / 驗收 / 行為島形狀 / 實作單元 / 已拍板選擇**；三台狀態機的 states/transitions/invariants/對外碼**權威設計**見 `docs/INTEGRATION-DESIGN.md` §4.1（token rotation）/§4.3（single-session）/§4.4（行為島紀律 2+1 合刀）。
> **下一步**：手動跑 `/speckit-specify`（階段 1；`before_specify` pre-hook 建 feature branch `014-auth-token-session`）。**勿**把 `/speckit-specify` 排進 brainstorm 流程觸發（會漏跑 `speckit.git.feature`）。
> **接地 pin**：rust-api `3f2ebc6`／base-web `e79e7aa8`（波 2 + D11/013 全收後）。schema 已盤點：rotation/session/denylist 所需欄**全在 m001/m002**、本刀**零 migration**。

---

## 1. Feature 一句話

把 006 鋪的「Auth 島最小段」（login + `enforce_mw` + pointer + `is_current` stub）補成**完整行為島**：§4.1 **token rotation chain**（refresh 輪替 / 雙擊 benign 容忍 / reuse 偵測→撤整鏈→8888）＋§4.3 **single-session lifecycle**（`single_session_default` 全域 × per-user `session_policy` 三態驅動、不符→7777）＋**硬即時撤銷**（停用/刪 user → Redis denylist → access token 立即失效、不分 policy）＋**cleanup-job binary**（過期 token 清理），並以 **2-instance 多實例驗證**證跨進程收斂與 watcher 韌性。

## 2. 問題 / 動機

006（auth-island-min）已鋪地基：login（argon2 + 簽 access/refresh + `token_hash=sha256(refresh)` + `set_pointer` + `insert_token` 同 plain txn 原子）、`enforce_mw`（bearer→is_current）、`is_current`（DB pointer 比對）、getUserInfo。但 Auth 行為島**只完成最小一段**，三個機制缺口（接地實證）：

1. **token 不輪替、無 reuse 偵測**：login 簽了 refresh 並寫 `sys_token`（`rotation_chain`/`status`/`used_at` 欄齊備），但**沒有 refresh-rotation 端點** → refresh 永不輪替、被竊用也偵測不到。
2. **★ single-session 現況「永遠踢」**：`is_current`（`server/src/auth/enforce.rs`）**只比對 pointer、未讀 policy**；雖然 `single_session_default` seed = `'off'`（全站預設不強制單session），實際行為卻是 B 裝置登入即踢掉 A（`set_pointer` 永遠覆寫 + is_current 永遠比對）。`single_session_default` 開關**目前無效**、`sys_user.session_policy`（預設 `inherit`）**從未被讀**。
3. **停用 user 的 access token 活到過期**（CHECKLIST §3.9）：login 端擋得住停用（status=2→1000）/軟刪 user，但**已發 access token 仍通關 ≤access_ttl（~1h）**（`enforce_mw` 不查 user-active、`is_current` 不讀 policy）。

對應 DESIGN §4 **三台行為島狀態機**之前兩台（token rotation §4.1 + single-session §4.3；治理 §4.2 = 下一刀）。本刀用 **state-machine 鏡頭**把它們補完整（§4.4「2+1 合刀」之合刀；cleanup-job = 本縱切 L8 binary）。

## 3. Scope

### 3.1 In scope

| 區 | 內容 |
|---|---|
| **§4.1 token rotation** | refresh-rotation 端點 + `decide_rotation` 純函式四分支（active→Rotate／used&<grace→Benign／used≥grace·revoked·used_at=NULL→Reuse／notfound）；per-token `jti`、`rotation_chain` 隔離 |
| **§4.3 single-session** | `resolve_policy`（`single_session_default` 全域 × per-user `session_policy` → effective on/off）；**`is_current` 補讀 policy**（'off' 不踢、修現況永遠踢）；`revoke_other_chains`（login 且 effective on）；補齊 4+1 gates（006 只掛 getUserInfo→補 getUserRoutes/isRouteExist/enforce_mw/refresh）；7777 通道 |
| **硬即時撤銷** | Redis denylist `revoked:user:{uid}=revoked_at`（TTL=access_ttl、`enforce_mw` 查 `iat<revoked_at`→reject、**fail-OPEN**）；`revoke_user_sessions(uid)`（撤鏈 + 清 pointer + denylist）→接 009 deleteUser/停用 handler |
| **per-user UI** | 009 編輯 user 頁 `session_policy` inherit/on/off 下拉（updateUser wire + handler + facade + i18n） |
| **cleanup-job** | 過期 token 清理 binary（`expires_at<now-SKEW_MARGIN(60s)`、與 status 無關、dry-run 預設只 count、`--execute` 才物理刪、冪等、單旗標） |
| **多實例 B-驗證** | acceptance 起 2 rust-api（共享同 DB+Redis、不同 port、直連 curl）實測 `single_session_default` 跨進程收斂 + watcher 斷線重訂閱 + shared-pointer 跨副本踢 + denylist 跨副本一致 |
| **base-web 薄接線** | refresh-rotation 接既有 axios 攔截器（自動輪替）＋ 7777/8888 乾淨登出 |

### 3.2 Out of scope / deferred

- **alt-login 4 流程 stub**（DESIGN §8.2 獨立尾巴刀、⚠️m 另排程、預設入波 3）
- **nginx 真 upstream LB／prod 預設 ≥2 副本**（真水平擴展時；本刀只 2-instance **驗證**、dev 預設仍 1）
- **★ casbin enforcer 跨實例 pub-sub**（§4.2 治理島的 reload+publish ＝ **下一刀 Policy-governance**；本刀只處理 session 端 `single_session_default` 的 watcher。「真 prod 多副本上線」橫跨本刀〔session〕+ 下一刀〔policy〕兩刀才齊）
- **新 migration**（`sys_token` rotation 欄 / `sys_user.session_policy`+`current_session_id` / `single_session_default` seed **全在 m001/m002**、⚠️t 波0全建兌現）

## 4. 設計綱要（已定案；states/transitions/invariants/對外碼 權威見 DESIGN §4.1/§4.3）

**① token rotation（持久化 `sys_token`、DESIGN §4.1）**：state `active→used→revoked`（單向）。presented refresh JWT → sha256→token_hash 查列 → `decide_rotation`：active→**Rotate**（FOR UPDATE 鎖、舊 active→used〔WHERE status=active 守冪等〕+ 插新 active 同 `rotation_chain`）／used&(now−used_at)<grace(30s)→**Benign**（雙擊容忍：插新 active、不動舊、不撤）／used≥grace·revoked·used_at=NULL→**Reuse**（撤整 `rotation_chain`+warn→8888）／notfound。同秒輪替靠 per-token `jti`(uuid) 使 JWT body byte-distinct 不撞 `token_hash` UNIQUE。

**② single-session（持久化 `sys_user.current_session_id`/`session_policy`、DESIGN §4.3）**：pointer 真相 = `current_session_id`（DB 持久）+ Redis `sess:{uid}` 熱快取（persist-then-cache）。**resolve_policy(user)** = `session_policy`∈{`on`→enforce／`off`→true 不踢／`inherit`→跟全域 `single_session_default`} → effective on/off。login → `set_pointer`（**永遠執行**、即使 off、供日後切 on 即生效）+（effective on）`revoke_other_chains`。每受保護請求 `is_current`（effective on 且 `claims.sid≠pointer`→7777；**fail-OPEN**：pointer 讀不到→放行）。

**③ 硬即時撤銷（本刀新增、§3.9 閉口）**：Redis denylist `revoked:user:{uid}=revoked_at`、TTL=access_ttl。`enforce_mw`（JWT verify 後）查：uid 在名單且 `claims.iat < revoked_at` → reject（**不分 session policy、access token 立即死**）；**fail-OPEN**（Redis 不可達→不 reject、撤銷窗口被短 token TTL 兜底）。re-enable 後新 token `iat>revoked_at` 自動放行、名單 TTL 到期自清。

**對外碼（DESIGN §4.1/§4.3）**：rotate/benign→200+新 pair；**Reuse/refresh-verify-fail→8888**（乾淨登出、非 5000）；**is_current/denylist→7777/8888**（踢人/乾淨登出）；簽發/DbErr→5000（HTTP 200 信封）。handler **絕不回 3333/9999/9998**（避免前端 auto-refresh 迴圈）。

## 5. Functional Requirements

- **FR-1 rotation 端點 + `decide_rotation` 純函式**：四分支如 §4.1（Rotate/Benign/Reuse/notfound）、FOR UPDATE 鎖、`jti` byte-distinct。
- **FR-2 reuse 偵測**：used 超 grace / revoked / used_at=NULL → 撤整 `rotation_chain` + warn → 8888。
- **FR-3 rotate 前置出口**：refresh JWT verify 失敗→8888；pointer-first `is_current` 失敗→7777；簽發失敗→5000。
- **FR-4 `resolve_policy` 純函式**：`session_policy` 三態 × 全域 `single_session_default` → effective on/off。
- **FR-5 `is_current` 補讀 policy**：effective off→不踢；on→pointer 不符→7777；fail-OPEN。補齊 4+1 gates。
- **FR-6 login single-session**：`set_pointer` 永遠執行；effective on 時 `revoke_other_chains`。
- **FR-7 硬即時撤銷**：Redis denylist + `enforce_mw` 查 `iat<revoked_at`→reject、fail-OPEN。
- **FR-8 `revoke_user_sessions(uid)`**：撤鏈 + 清 pointer(DB+Redis) + 寫 denylist；接 009 deleteUser / updateUser(status=2 停用)。
- **FR-9 per-user `session_policy` UI**：009 編輯 user drawer inherit/on/off 下拉；updateUser 三端對齊收+寫 `session_policy`；i18n 三態。
- **FR-10 `single_session_default` 熱載**：admin 經 008 設定頁切 → 跨實例收斂（`settings:invalidate` watcher + AppState 快取失效、fail-OPEN）。
- **FR-11 cleanup-job binary**：`expires_at<now-60s`、dry-run 預設只 count、`--execute` 物理刪、冪等、單旗標。
- **FR-12 base-web 薄接線**：refresh 接既有 axios 攔截器；7777/8888→清 auth + toLogin。
- **FR-13 多實例收斂**：2 instance 共享 DB+Redis → `single_session_default`/pointer/denylist 跨進程一致、watcher 斷線重訂閱。

## 6. Success Criteria（驗收；DESIGN §8.8 DoD：§4 狀態機 invariants 逐條自動化驗證 + 7777/8888 CDP）

- **SC-1 純函式測全矩陣**：`decide_rotation` 四分支（含 grace 邊界、used_at=NULL fail-closed）+ `resolve_policy` 三態 × 全域 on/off。
- **SC-2 live rotation**：rotate→新 pair、benign 雙擊→新 active 不撤、**reuse→撤整鏈 + 8888**。
- **SC-3 live single-session**：effective on→B 登入踢 A(7777)、effective off→多裝置共存(不踢)、per-user override 蓋全域。
- **SC-4 live 硬即時撤銷**：停用/刪 user→其 access token 下一請求**立即 reject(8888)**、不分 policy、不等過期。
- **SC-5 CDP per-user session_policy**：009 編輯設某 user on/off→行為改變。
- **SC-6 ★ 多實例 2-instance**：A 切 `single_session_default`→B 收斂(watcher)；kill Redis pub-sub→watcher 重訂閱；A 登入→B 讀 shared pointer 踢；denylist 跨副本一致。
- **SC-7 cleanup-job**：dry-run 只 count 不刪、`--execute` 刪過期、重跑冪等。
- **SC-8 CDP 7777/8888 兩通道**：pointer 踢(7777)／refresh reuse(8888) 皆乾淨登出（清 auth+toLogin、不白屏）。
- **SC-9 零回歸**：006 login/getUserInfo/enforce、009 既有 CRUD、008 設定頁、013 audit 全不破 + **prod target image build**。
- **SC-10 schema 零變更**：無新表/無 ALTER/無 migration（Constitution Check item 8）。

## 7. 兩層 single-session 模型（接地實況、本刀核心）

| 層 | 存哪（接地 pin 3f2ebc6） | 現況 |
|---|---|---|
| **全域預設 `single_session_default`** | `system_settings` key（m002 seed=`'off'`、`enum:on,off`、「全站單一-session 預設」） | ✅ 已 seed、**008 設定頁已能切**（NSwitch）；惟**目前無效**（is_current 未讀） |
| **per-user `session_policy`** | `sys_user.session_policy`（m001 欄、DB default `'inherit'`、009 建 user 時 set inherit） | ✅ 欄已存在、新 user 自動 inherit；惟**從未被讀** |

**resolve_policy(某 user)** = `session_policy='on'`→強制單session／`'off'`→不強制／`'inherit'`→**跟全域 `single_session_default`** → effective on/off。`is_current` 只在 effective=on 時才踢。

> **★ 現況 gap（本刀動機核心）**：`is_current` 目前只比對 pointer、不讀 policy → **永遠踢**（B 裝置登入踢 A），與 `single_session_default='off'` 的意圖**相反**。本刀補 `resolve_policy` 才讓全域開關 + per-user override 真的生效。

## 8. 實作單元（rough、階段 2 由 Workflow 編執行單元；不綁定本清單）

`L1` `decide_rotation`/`resolve_policy` 純函式（test-first）｜`L2` refresh-rotation 端點 + reuse→撤鏈 + 前置出口｜`L3` `is_current` 補 resolve_policy + 4+1 gates + `revoke_other_chains`｜`L4` 硬即時 denylist（enforce_mw 查 + `revoke_user_sessions`）+ 接 009 deleteUser/停用｜`L5` `single_session_default` 熱載 watcher + **2-instance 多實例驗證**｜`L6` cleanup-job binary｜`L7` base-web（refresh 接線 + 7777/8888 + 009 編輯頁 session_policy 下拉 + i18n）。
> 相依：L1→L2/L3；L3 依 resolve_policy；L4 依 L3 + 接 009；L5 依 008 settings 機制；L7 依 L2/L3/L4 wire。實際執行單元由階段 2 `executing-plans` 依 tasks.md 真實相依重組。

## 9. 已拍板的設計選擇

**brainstorming 拍板（user 親決、本輪）**：
- **C1 多實例 = B-驗證版**：建 watcher 機制 + acceptance 起 **2 rust-api**（共享 DB+Redis、不同 port、直連 curl）實測 `single_session_default` 跨進程收斂 + watcher 斷線重訂閱 + shared-pointer 跨副本踢；**dev 預設仍 1**、nginx 真 LB / prod 多副本 / enforcer pub-sub **不在本刀**。
- **C2 撤銷 = B-硬即時（Redis denylist）**：`revoked:user:{uid}=revoked_at`、TTL=access_ttl、`enforce_mw` 查 `iat<revoked_at`→reject（**不分 session policy、access token 立即死**）、**fail-OPEN**（Redis 掛時不 reject、撤銷窗口被短 token TTL 兜底）；接 009 deleteUser/停用。
- **C3 per-user `session_policy` UI = 做**：009 編輯 user 頁加 inherit/on/off 下拉（updateUser 三端；addUser 維持建立預設 inherit、override 走編輯）。
- **C4 alt-login = 排除本刀**（DESIGN §8.2 獨立尾巴刀）。

**engineering 預設（已定、非 user 拍板級）**：
- **cleanup-job = binary**（dry-run 預設、`--execute` 才物理刪、`expires_at<now-60s SKEW_MARGIN`、冪等、單旗標）；crate 形狀（新 workspace member vs 既有 crate bin target）留 plan 接地（**新 crate ⇒ prod build COPY 紀律** §3 Phase 1）。
- **reject code**：denylist 命中→8888（乾淨登出）；rotation 8888 / single-session 7777 沿 DESIGN §4.1/§4.3。
- **`single_session_default` 熱載機制** = `settings:invalidate` Redis pub-sub + AppState 快取失效 + fail-OPEN；接地確認 008 有無既有 settings watcher（reuse）否則本刀建。
- **`SKEW_MARGIN_SECS`(60s, cleanup) ≠ `GRACE_SECS`(30s, rotation)** — 名異值異用途異、勿混用（DESIGN §4.1 invariant ③）。

## 10. 留待 plan/impl 階段定（非 feature-shaping、無 user 拍板）

- cleanup-job crate 形狀（新 member vs bin target）+ prod Dockerfile COPY（若新 crate）
- **008 既有 settings watcher 現況**（reuse vs 新建 `single_session_default` 熱載）— Phase 0 research grep 確認
- **`is_current` 4+1 gates 現況**（006 已掛 getUserInfo、確認 getUserRoutes/isRouteExist/enforce_mw/refresh 待補的精確掛點）
- denylist fail-OPEN 確切邊界（Redis 不可達 vs key 不存在）+ TTL 精確值（access_ttl=3600s + skew；006 boot 常數）
- **多實例 dev 怎麼起 2 instance**（`--scale rust-api=2` 撞固定 host port `31081` → 需第二 service 或 profile；acceptance 用、dev 預設不啟）
- `decide_rotation` 的 FOR UPDATE 鎖 + 同秒輪替 `jti` byte-distinct 細節（DESIGN §4.1 invariant ①③）
- Redis client 在 enforce 熱路徑的現況（rev3 首個 enforce 熱路徑 Redis 讀）+ `sess:{uid}` 快取讀寫 seam

## 11. Constitution / 紀律對齊

- **§4 行為島**：用 state-machine 鏡頭**第一輪設計**（DESIGN §4.1/§4.3 已凍）；不混進 §5 CRUD 格子（§4.4）。本刀逐 invariant 須有自動化驗證（§8.8 DoD）。
- **§I.7 行為島 invariants**：token 單向 status / `rotation_chain` 隔離 / is_current fail-OPEN / pointer DB-truth / denylist fail-OPEN — 逐條 SC 覆蓋。
- **動 009（跨 feature）**：MODAL-WIRING ★ (a) 編輯 drawer 加 `session_policy` 下拉 + updateUser handler/facade 收+寫 + `revoke_user_sessions` 接 deleteUser/停用——授權軌道內、記 `file:line` + 不破 009 既有行為、不退化其 C-V。
- **零 migration**：schema 全在 m001/m002（⚠️t 兌現）；Constitution Check item 8 = 無新表/無 ALTER。
- **denylist = 新 Redis 用法**（rev3 首個 `enforce_mw` 熱路徑 Redis 讀）— 接地確認 redis client、fail-OPEN 守 §I.7 fail-OPEN 哲學。
- **cleanup-job 若新 crate** ⇒ `contracts/verification-commands.md` 必含 **prod target image build**（§3 Phase 1 紀律、SC-9）。
- **多實例驗證** = §8.5 de-risk 的「single-session 跨實例」spike **做進本刀 acceptance**（C1 拍板、非拋棄式 spike、直接交付驗證）。

## 12. References

- **DESIGN**：§4.1（token rotation chain）/ §4.3（single-session lifecycle）/ §4.4（行為島紀律 2+1 合刀）/ §8.2（縱切清單 Auth/Token/Session = rev2 013*/026/027/028/029/030）/ §8.5（風險序 single-session 跨實例 spike）/ §8.8（DoD）
- **接地（pin 3f2ebc6/e79e7aa8）**：`server/src/auth/enforce.rs`（is_current）/ `handler/auth.rs`（login set_pointer+insert_token）/ `model/facade/sys_user.rs`（set_pointer/current_session_id_of/session_policy）/ `model/facade/sys_token.rs`（insert_token）/ `entity/src/sys_token.rs`（rotation_chain/status/used_at）/ m001（sys_user.session_policy+current_session_id 欄）/ m002:263（single_session_default seed）
- **CHECKLIST**：§3.9（006 follow-up：token 即時撤銷 / JWT 參數硬編，本刀閉口）/ DECISIONS §1 ⚠️m（alt-login 排程）
