# 019-login-lockout — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → 手動 `/speckit-specify`（input＝本檔）起 019 feature branch。
> 日期：2026-06-25。來源：[DECISIONS §1 ⚠️w](../INTEGRATION-DECISIONS.md)（已拍板「做」）／[DESIGN §5.8＋附錄 F](../INTEGRATION-DESIGN.md)（索引預留）／[007 audit-overlay brainstorm](007-audit-overlay.md)（誕生脈絡、user 親提 2026-06-14）／rev2 FR-008（原始需求意圖）。

---

## 1. 背景與目標

login-lockout ＝ 登入失敗 rate-limit、擋暴力破解／撞庫。**已拍板「做」**（⚠️w）、為**下游唯讀消費**功能：消費 007-audit-overlay 備齊的 `sys_login_attempt` 表＋兩複合索引、在 login 前置跑「時窗內失敗數 count」、超閾值即擋提交。**0 新表／0 migration／0 新 crate**。

**user 原始動機（007）**：做 audit overlay 記錄每次登入嘗試的真實 client IP 時，意識到這些資料天生能防暴力破解；**刻意把真 IP 解析做對（fail-safe／anti-XFF-spoof、013 兩層信任模型）就是為了讓 per-ip lockout 不被偽造 XFF 繞過**。lockout 本體當時明確 defer 到後續刀（⚠️w）。

**範圍**：login 前置 count gate、**雙軌 both**（per-ip ＋ per-user）。觀測層（018）、審計顯示（012 getLoginAttempt）不涉。

---

## 2. 拍板紀錄（user 親決 2026-06-25 brainstorm）

| # | 決策 | 結論 |
|---|---|---|
| **D1** 維度 | 按哪個維度鎖 | **both（per-ip ＋ per-user）**——per-ip 擋單源暴力破解、per-user 擋跨 IP 撞單帳號；兩索引都已建、邊際成本低（否決 per-ip-only〔換 IP 撞單帳號擋不住〕／per-user-only〔掃多帳號難觸發〕） |
| **D2** 政策值 | 門檻／時窗 | **per-user 5 次／15 分、per-ip 20 次／15 分**（per-ip 門檻刻意高、免鎖死 NAT/共用 IP 整間辦公室）；滑動時窗自動解鎖 |
| **D3** 訊息 | 鎖中 toast | **靜態「登入失敗次數過多，請稍後再試」**（否決帶動態「剩 N 分」倒數〔i18n 字串耦合 hardcode 窗值＋parameterized i18n 複雜度〕） |

**工程拍板（我決、記錄；非 user 拍板級）**：

| # | 決策 | 結論 |
|---|---|---|
| E1 | 機制 | **DB 滑動窗 count**（非 Redis——Redis〔014〕fail-OPEN 可降級、當安全 gate 會「Redis down 就無鎖」；DB always-up 為唯一可靠來源、且資料已在 `sys_login_attempt`） |
| E2 | envelope 碼 | **2222 `AppError::Biz("auth.login.locked")` ＋ i18n key**（不需新碼、不破 ⚠️f「13 碼整組凍結」、不需 constitution amendment；i18n key 走既授權 ⚠️aa BASE-WEB-I18N-WIRING） |
| E3 | gated 攻擊寫 attempt | **寫**（success=false）——① 審計完整（鎖中嘗試留痕）② **sticky lockout**（持續攻擊把自己壓在鎖中、必須停手滿窗才解）；且 gate 在 login_inner【前】＝跳過 user 查詢＋argon2 驗證、被鎖請求更便宜（防 DoS 加分） |
| E4 | 政策值載體 | **hardcode consts**（runtime 可調〔settings 島〕留未來、最小 scope） |
| E5 | 恢復 | **滑動窗自動解鎖**（只 count 時窗內失敗數、舊失敗滑出即恢復、0 狀態儲存、0 新欄）；★ **成功登入不 reset 計數**（純窗內 count、無 reset-on-success state——門檻下登入成功不清既有失敗列、仍隨窗自然滑出；v1 最小化取捨，reset-on-success〔需查最近成功時點或存狀態〕留未來） |
| E6 | count 範圍 | 只算 `success=false`；失敗寫**維持 best-effort**（⚠️w 拍板：足以當縱深防禦一層、不要求強一致） |
| E7 | gate 插點 | `login` handler 呼叫 `login_inner` **前**（該處已有 `ctx.client_ip`；`login_inner` 簽名不動、不接 ctx） |
| E8 | count 出錯策略 | **fail-OPEN**（count query DbErr → gate 跳過、login 照常進 `login_inner`）——§I.7 fail-OPEN ＋ ⚠️w「best-effort 縱深防禦」；DB 抖動不可鎖死全站登入入口（鏡像 `is_current`/`denylist_gate` fail-OPEN 範式） |

---

## 3. Phase 0 研究實證（act-on-code、3 agent 接地 @ 2026-06-25）

**★ 不信 rev2 假設、不信 DESIGN 目標態、以 as-built 為準。** 以下已核（exact 行號於 `/speckit-plan` research.md 再固化）：

**資料源（全綠、007 已備）**
- `sys_login_attempt` 表（m001）＋ entity 11 欄：`id`／`attempted_user_name` text／`success` **bool**／`operator_id` nullable／`real_ip` inet NN〔m006 改名自 client_ip〕／`peer_ip`／`ip_confidence`／`x_forwarded_for`／`region`／`trace_id`／`created_at` tz。
- **兩索引全已建**（m001:799-819）：`idx_login_attempt_ip_time (real_ip, created_at)`／`idx_login_attempt_user_time (attempted_user_name, created_at)`——007 明文「為 ⚠️w lockout 備」。
- archetype B append-only（facade 僅暴露 write、不可竄改）。

**login 流程（`handler/auth.rs`）**
- `login` handler（185-222）→ `login_inner`（66-177、回 `Result<Success, (Option<i64>, AppError)>`）。**6 終局路徑**：查無帳號／密碼錯／停用＝**1000 LoginFailed**（統一碼防枚舉、FR-016/§5.3）；DB/JWT 錯＝5000；成功＝0000。
- 寫 `sys_login_attempt` ＝ handler 內**單一寫點**（197-212）、涵蓋**全 6 路徑**（成敗皆寫）、best-effort、`success: bool` 欄、`operator_id`＝識別前失敗 None／識別後 Some。
- facade：`write` ＋ `list(filter, 回 total)`；**無 count-by-window** → 本刀補一個小 count 方法。
- **gate 插點**：handler 呼叫 `login_inner` 前（已有 `ctx`＝Extension<RequestContext>、含 013 解析的 `client_ip`；`login_inner` 沒接 ctx）。

**envelope（13 碼凍結 ⚠️f）**
- 13 碼：0000/1000/2222/3333/7777/8888/4040〔404〕/5003〔403〕/5000 ＋ 4 保留〔7778/8889/9998/9999、後端從不發、前端 .env 認得〕。
- **2222 `Biz(key)`＝可擴充碼**（傳穩定 i18n key、前端 `$t("backend."+key)` 譯、⚠️y/⚠️aa）——lockout 用它＝**不需新碼、不破 ⚠️f、不需 amendment**。
- **★ 防枚舉確認**：login 對「查無帳號」**也寫失敗列**（path 1、operator=None、attempted_user_name=req.user_name、success=false）→ 試不存在的帳號 N 次**一樣會 per-user 鎖**、回**一樣的「失敗次數過多」訊息**→ 真假帳號鎖法完全相同、攻擊者分不出 → lockout 訊息**不洩帳號存在**（D3 靜態訊息更保守）。

**lockout 不查 operator_id**（007 R3）：只查 `attempted_user_name`／`real_ip`＋`created_at`＋`success=false` 兩索引、無外洩疑慮。

**rev2-parity**：DESIGN §8.2 rev2 35 work-item **無對應 login-lockout 刀／migration**；rev2 FR-008 是**需求意圖**非 as-built。**從零設計**；可承接＝(a) 007 資料源＋兩索引＋真 IP 解析 (b) ⚠️w 框架 (c) FR-008 意圖。〔註：codebase 多處 `lockout` 字樣屬 RBAC anti-lockout〔防自撤 Super policy〕、與登入限流無關。〕

**audit／lockout 關係**：同表兩獨立讀消費——**012 審計顯示**（getLoginAttempt、R_SUPER、人讀分頁）vs **lockout**（login 內即時 COUNT gate、不分頁不顯示）；0 寫競爭、0 schema 衝突。這正是把 lockout 設計成「audit 下游消費者」的價值（0 新表、純加一條 count query ＋ 一個前置 gate）。

---

## 4. 設計細節

> 一刀 `019-login-lockout`、規模小（3 rust 動點＋1 base-web i18n key、0 schema）。**執行單元（待 `/speckit-tasks` firm）**：U1 rust lockout gate ｜ U2 base-web i18n 接線。

### 4.1 U1 — rust lockout gate（RUSTAPI-SOURCE-ISOLATION 軌）

**facade（`model/facade/sys_login_attempt.rs`）補 count**：
- 兩用途 count（shape〔單一參數化 fn vs 兩 fn〕由 implementer 定、走對的索引即可）：per-ip ＝`WHERE real_ip=? AND success=false AND created_at>=?`（走 `idx_login_attempt_ip_time`）／per-user ＝`WHERE attempted_user_name=? AND success=false AND created_at>=?`（走 `idx_login_attempt_user_time`）。

**gate（`handler/auth.rs`）**：
- 純函式 `is_locked_out(ip_fails: i64, user_fails: i64) -> bool`（test-first：`ip_fails >= PER_IP_THRESHOLD || user_fails >= PER_USER_THRESHOLD`）。
- hardcode consts：`PER_USER_THRESHOLD=5`／`PER_USER_WINDOW_SECS=900`／`PER_IP_THRESHOLD=20`／`PER_IP_WINDOW_SECS=900`。
- handler 在呼叫 `login_inner` 前：算 `since`、跑兩個 count（`ctx.client_ip` / `req.user_name`）、`is_locked_out`？
  - **鎖中** → 不進 login_inner（短路）、結果定為 `success=false`／`operator=None`／`Err(Biz("auth.login.locked"))`〔2222〕。
  - **未鎖** → 走既有 `login_inner`、結果照常。
- ★ **gate 結果匯流進【既有單一寫點】**（197-212）：把 gate 的「鎖中」當成另一條 `success=false` 分支、與 login_inner 的 Ok/Err 一起餵同一個 attempt write ＋ return——**不重複寫、不改寫點位置、不改 login_inner 簽名**。gated 列照填 ctx 四欄鑑識（real_ip/peer_ip/ip_confidence/xff/region/trace_id）。

**資料流**：
```
POST /auth/login
 → handler 建 ctx（client_ip 走 013 真 IP 解析）
 → GATE：ip_fails=count(real_ip, 900s) / user_fails=count(user_name, 900s)
     ├─ is_locked_out → 短路（success=false, op=None, Err Biz auth.login.locked〔2222〕）
     └─ else → login_inner（既有 6 路徑不動）
 → 【單一寫點】write attempt(success, op, ctx 四欄) ＋ return（2222 / 0000 / 1000 / 5000）
```

### 4.2 U2 — base-web i18n（⚠️aa BASE-WEB-I18N-WIRING 軌）

- locale 加 `backend.auth.login.locked`（zh-cn「登入失敗次數過多，請稍後再試」／en-us「Too many failed login attempts. Please try again later.」）。
- `app.d.ts` App.I18n.Schema.backend.auth 加 `loginLocked`（**先 Schema 後 locale**、否則 dict typecheck red、見 memory `base-web-i18n-schema-iii-gotcha`）。
- 鎖中 toast 走**既有** request interceptor `onError`（§3.G `translateBackendMsg`、已落地）——2222+msg 自動譯成 toast、login form 預期無需特殊處理〔★ research 須驗 login 錯誤路徑確走此 interceptor、非自訂 login-error 處理〕。

**nginx／DB**：零改（login=`/api/auth/login` public、無新 route、無 schema）。

---

## 5. v1 不做（defer）

| 項 | 何時做 |
|---|---|
| 管理員手動解鎖 UI | 未來（v1 滑動窗自動解鎖足夠） |
| runtime 可調門檻（settings 島） | 未來（v1 hardcode；要可調再接 008 settings） |
| 鎖定事件專屬審計欄（區分 lockout-blocked vs 真 auth-fail、且哪維度 ip/user 觸發） | 未來（v1 gated 列統一 `success=false`、**dimension-blind**〔`is_locked_out` 回 bool 收斂維度、不標哪軌觸發〕；需鑑識區分時加欄） |
| 訊息帶動態「剩 N 分」倒數（option B） | 未來（需 parameterized i18n） |
| 鎖後 CAPTCHA | 連 ⚠️c alt-login captcha（alt-login 刀、⚠️m） |
| per-ip 信任白名單（內網固定 IP 不鎖） | 未來（v1 一律鎖；prod 真內網拓樸時評估） |

---

## 6. 出口條件

- [ ] per-user 鎖生效（對 Foo 連 5 次失敗 → 第 6 次回 2222；換 Bar 不受影響＝per-user 隔離）
- [ ] per-ip 鎖生效（同 IP 跨多帳號 20 次失敗 → 回 2222 per-ip）
- [ ] 滑動窗恢復（純函式＋短窗 override 驗、舊失敗滑出即解）
- [ ] 正確登入零回歸（0000、既有 6 路徑不變）；13 碼矩陣不變（2222 既有、不破 ⚠️f）

---

## 7. 測試／驗收策略

- **純函式 test-first（TDD）**：`is_locked_out` 門檻邊界（剛好/低於/高於、per-ip 與 per-user 各自觸發、both 任一觸發即鎖）。
- **count 方法＋gate**：acceptance C-V（curl 連續失敗登入 → 鎖；psql 驗 attempt 寫入含 gated 列；EXPLAIN 驗走 `idx_login_attempt_*`）＋ in-crate `#[ignore]` live smoke（DB-gated、`--test-threads=1`、env-gate、見 §3 紀律：`server` bin-only crate、需 crate API 的測試放 in-crate ignore）。
- **★ 測試隔離（必守、防污染共用 dev DB／鎖到下游 serial live smoke）**：per-user 測一律用【拋棄式 `attempted_user_name`】（**絕不用 seed Super/Admin/User**、否則把 seed 帳號鎖 15 分、後續別 feature live smoke 連不上）；per-ip 測（20 次跨帳號）會把【該測試 IP】對**所有帳號**鎖 15 分 → live `#[ignore]` smoke 必用【短窗 const override】使其快速自解、或排最後＋註明窗等待（鏡像 memory `oplog-count-assert-nonidempotent-shared-entity-id` 跨 feature live-test 污染教訓）。
- **滑動窗**：純函式＋短窗 const override 測（避免 live 等 15 分）。
- **prod image build**：無新 crate、惟 rust 動 build → contracts 仍納一條 prod target build（§3 紀律保險、防 dev bind-mount 遮蓋）。
- **零回歸**：既有 login 測（6 路徑）、`entity_access_lint`／`endpoint_coverage_lint`（/auth/login 既在、無新 route）、13 碼 contract。
- rust 全程 serial、build/test 容器內 `docker exec`、live smoke 帶 `DATABASE_URL`＋`--test-threads=1`、base-web commit `--no-verify`、★ 絕不 push/merge（留 `finishing-a-development-branch`）。

---

## 8. Phase 0 research 待固化（交 `/speckit-plan` research.md）

1. **count 方法 SQL ＋ 索引使用**：確證 COUNT query 走 `idx_login_attempt_ip_time`／`idx_login_attempt_user_time`（EXPLAIN）；`real_ip` 比較型（sea-orm `IpNetwork` eq）、`created_at` 時窗比較（`since` 型＝DateTimeWithTimeZone）。★ **建議 Postgres-side `created_at >= now() - make_interval(secs => N)`（一致 cleanup-job、避 app/DB clock-skew）**、非 Rust 端算 now（server crate 雖有 chrono re-export〔memory `seaorm-now-via-sqlx-chrono-reexport`〕、但跨機時鐘偏移風險同 cleanup-job SKEW_MARGIN 教訓）。
2. **gate 插點不破既有流程**：確證 handler 在 login_inner 前插 gate、匯流寫點不破 best-effort write 與 6 路徑；gated write 欄位（operator=None、success=false、ctx 四欄鑑識照填）。
3. **base-web 錯誤路徑對齊（wire 3 端）**：grep login form（`views/_builtin/login` 或對應）的錯誤處理——確認 2222+msg 走 §3.G `onError`/`translateBackendMsg`、1 locale key 足夠、非自訂 login-error 處理（否則 U2 須補）。★ 此為 curl≠modal 經典點、CDP browser 軌驗鎖中 toast 在地化。
4. **gated write 的 sticky-lockout 語意**：確認 count 包含 gated 列 → 持續攻擊不解鎖、停手滿窗才解（與 D2/E3/E5 一致）。
5. **政策值 const 命名／位置**（handler 內 vs 獨立 config module）。
6. （**無 MSRV／新 dep 風險**——0 新 crate；不觸 §3「新 crate ⇒ 四處 COPY」。）
7. **Constitution Compliance 預答**（正式 9 項檢在 `/speckit-plan` §IV、brainstorm 不做；此處預答易誤判的 item 6/9）：lockout gate ＝【新增 fail-OPEN blocking gate】、**不動 §I.7 任何 state-machine invariant**（非 token-rotation／policy-governance／single-session）、fail-OPEN 鏡像 `is_current`／`denylist_gate` 范式（非反轉）→ **不需 §V.2 amendment**；§V.2「gate 跳過清單」條款指 skip-list 改動、與「新增 blocking gate」無關。item 6（§II 拍板 #1~#13）答「新 fail-OPEN gate、無 invariant 反轉、2222 復用不破 ⚠️f」；item 9（§I.7 行為島）答「不涉、enforce/token/session 不動」。

---

## 9. DESIGN 落差紀錄（act-on-code 接住、供勘誤評估）

- DESIGN 對 lockout **只預留索引、無機制細節**（§5.8 line 319／附錄 F #9 line 871）→ 本 brainstorm 從零定機制＝⚠️w 待定項落地（非落差、是 deferred 排程）。
- m001 索引 `idx_login_attempt_ip_time` 原建在欄 `client_ip`、m006 後欄改名 `real_ip`（索引名未改、PG RENAME COLUMN 自動跟欄參照）→ 設計一律用 `real_ip`。
- ★ **D3 靜態訊息 supersede ⚠️w「顯示 N 分鐘」措辭**：⚠️w 結論欄（DECISIONS §1）原述「超閾值回 lockout 碼擋提交＋前端顯示『鎖定 **N 分鐘**』」（動態倒數）；D3 改**靜態**「請稍後再試」（動態倒數＝option B、移 §5 defer、避 i18n parameterize 複雜度）。此為對 ⚠️w 原述 UX 的有意收斂、**非疏漏**。**019 收刀時 ⚠️w 結案須把此 corrected 結論回填 DECISIONS §1 ⚠️w 那列**（免決策記錄與 as-built 行為矛盾 rot、CLAUDE.md §7.2）。
- ⚠️w 在 CHECKLIST §4.2／拍板索引列「做、刀位/設計待排程」；019 收刀後該移 done（⚠️w 結案）。
