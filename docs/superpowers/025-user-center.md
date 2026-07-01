# 025-user-center — Phase 0 Brainstorm（spec-design）

> **波4 後獨立刀**（024-password-policy 收刀 merge `aca02c81`、2026-07-02 後）。本刀為「密碼複雜度政策 ＋ 個人中心」**2 刀組的第 2 刀（個人中心）**；**消費 024 as-built** 的 `auth/password_policy.rs` 純驗證原語（喚醒其 dormant 模組）。
> **拍板（本檔 brainstorm 對話定、2026-07-02）**：①**範圍**＝把 `/user-center` 的 `<LookForward/>` 佔位換成真頁（profile 自助檢視/編輯 ＋ 改密碼 ＋ 手机/邮箱驗證 UI 預留）；②**版面**＝主體參考 `pro-naive/form/basic`（分段表單），**密碼/手機/邮箱參考 `function/request` 的「一功能一區塊」分區塊**；③**手機/邮箱值＝A（值在各自區塊內）**：手机/邮箱各一區塊＝值 input（可改）＋保存＋**預留** 發送/驗證碼/驗證 三控件；④**驗證機制＝純 UI 佔位**（三控件不接後端、點擊 toast「功能建置中」；未來接 SMS／SAML2-Google）；⑤**治理＝MODAL-WIRING 新用途 (g)**（`/user-center` 為**非-manage** 頂層自助頁、現六用途硬綁 `views/manage/**`；MINOR bump v1.2.0→v1.3.0，比照 023 (f)、非 024 (e)）；⑥**i18n zh-CN 為主**（zh-TW 屬未來 feature）。
> **凍結權威**：024 as-built `password_policy` API（見 §2.1、grounding `wf_c3044ab2`）＋constitution v1.2.0（(g) amend 於 plan 落 v1.3.0）＋facade-only／§I.6 審計成對＋003 envelope/biz 碼＋endpoint auth-only 三分類＋BASE-WEB-I18N-WIRING(⚠️aa)／ADAPT／WRAPPER 軌道。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（跨檔引用用穩定 §錨；本檔不引用本機 memory）。

---

## 1. 目標一句話

把 `/user-center` 佔位頁換成真個人中心——使用者自助**檢視/編輯 profile**（用戶名·角色唯讀；性别/昵称/手机/邮箱可改）、**改密碼**（舊密碼 verify → 套 024 政策 → hash → 窄寫）、**手机/邮箱驗證流程 UI 預留**（不接後端）；後端新增 **3 個 auth-only self 端點** ＋ **2 支窄寫 facade fn**、喚醒 024 dormant `password_policy`、**零 migration**。

## 2. Context（探索蒐集、act-on-code 親驗；grounding `wf_c3044ab2`）

### 2.1 024 as-built 消費 API（`rust-api/server/src/auth/password_policy.rs`，現 dormant `#![allow(dead_code)]`）
- `PasswordPolicy{ min_length/max_length: usize, require_uppercase/lowercase/digit/special/forbid_username: bool }`。
- `from_settings(items: &[(&str, &str)]) -> PasswordPolicy`（吃**借用 KV slice**、非 Model/非 owned；缺鍵→保守預設 8/64/off）。
- `validate_password_complexity(policy: &PasswordPolicy, plain: &str, user_name: &str) -> Result<(), Vec<PolicyViolation>>`（**含 user_name 第三參**、Err 帶全部違規非短路）。
- `PolicyViolation`（7 變體：TooShort/TooLong/NeedUppercase/NeedLowercase/NeedDigit/NeedSpecial/SameAsUsername）。
- **政策載入範式**（handler 端）：`facade::system_settings::find_all(&db)` 回 `Vec<Model>` → bind local → `.iter().map(|m|(m.setting_key.as_str(), m.setting_value.as_str())).collect::<Vec<(&str,&str)>>()` → `from_settings(&pairs)`（無現成 helper、handler 自組；非 password_* key 自動忽略）。
- 024 migration 實際＝`m009_seed_password_policy.rs`（git「退回 m010」＝曾短暫 m010 又退回 m009）；**下一支＝m010**（本刀不需）。
- `auth/password.rs`：`verify(input, phc) -> bool`、`hash_password(plain) -> Result<String, argon2::password_hash::Error>`。

### 2.2 025 landing 缺口（需新建）
- `/auth/getUserInfo` 回 `UserInfo` **僅 4 欄**（userId/userName/roles/buttons）→ 讀自己 gender/nick/phone/email **無來源**。
- `facade::sys_user`：`find_active_by_id(conn, id) -> Option<Model>`（可取自己、含 `password` PHC 與 `user_name`）；`update`/`build_update_active_model` **刻意不碰 password**（密碼治理分離）→ 改密碼須**另立窄寫 fn**。無任何 self-service 端點。
- `views/user-center/index.vue` ＝上游 soybean `<LookForward/>` 佔位；路由 `/user-center` 已在（`hideInMenu:true`、非 constant、需認證）、頭像下拉入口已通。
- 當前登入者 id：`Extension<Claims>` → `claims.uid`（不信 body id）。

### 2.3 治理（唯一拍板級 gate）
- `/user-center` 在 `views/user-center/`、**非 `views/manage/**`**；constitution §III.2 MODAL-WIRING 六用途 (a)~(f) **硬綁 `views/manage/**`**，(e) 明文排除「非 manage 頁」→ 現無軌道涵蓋此頁 inline/建頁。**user 拍板 A：新開用途 (g)、MINOR bump v1.2.0→v1.3.0**（比照 023 ⚠️af (f)；(e) 有「仍在 manage 頁內」前提不能延伸）；`page.userCenter.*` i18n 綁進 (g)。正式 amend 於 `/speckit-plan` Constitution Check 落（比照 024 (e) 流程）、記 DECISIONS §1。

### 2.4 可複用（不新建）
- NForm 範本 `views/manage/user/modules/user-operate-drawer.vue`（gender radio / nick / phone / email 結構 ~90% 重疊）；`hooks/common/form.ts`（`useNaiveForm`/`useFormRules`/`patternRules.phone/email/pwd`/**`createConfirmPwdRule`**〔改密碼確認直接可用〕）；`constants/business.ts`（gender options）；`constants/reg.ts`。
- i18n 可複用：`page.manage.user.*`（userGender/nickName/userPhone/userEmail 標籤）、`common.userCenter`、`form.pwd/confirmPwd`、`route.user-center`。
- wire 慣例：view 直接路徑 import wrapper（新檔 `rev3-user-center.ts`）、typings declaration-merge。

### 2.5 已知坑（設計須納入）
- **root 模板 overflow 裁切**：table 頁 root `min-h-500px flex-col-stretch overflow-hidden` 用在**卡片/表單頁**會裁掉溢出、無法下滾 → 本刀（多區塊表單頁）用 `flex-col-stretch gap-16px` 讓 main 滾（024 system-settings 已踩、已有解法範式）。
- **vite stale-locale**：新增 `page.userCenter.*`/`backend.biz.password.*` 後 CDP 驗前先 `restart base-web`、斷言 toast 非 raw key。
- **locale 簡繁**：跟隨專案 zh-CN 慣例、勿修既有簡繁混用（zh-TW 屬未來 feature）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由 |
|---|---|---|---|
| D1 | 範圍 | 第 2 刀＝個人中心（024 政策已 done）；替換 `/user-center` LookForward | 2 刀組收尾；消費 024 dormant 原語 |
| D2 | 版面/技術棧 | 縱向堆疊區塊：基本资料〔form/basic 表單風〕＋手机/邮箱/密码〔function/request 一功能一區塊風〕；naive `NForm`+`NCard`、**非** pro-naive-ui | user 指定兩頁參考；naive 為專案主流、驗證工具齊（form.ts） |
| D3 | 手機/邮箱值放置 | **A：值在各自區塊內**——手机/邮箱各一區塊＝值 input（可改）＋保存＋預留三控件 | user 拍板 A；值與（未來）驗證同區塊更連貫 |
| D4 | 驗證機制 | 純 UI 佔位：發送验证码鈕＋驗證碼 input＋驗證鈕，**不接後端**（點擊 toast「功能建置中」） | user 拍板；真 SMS／SAML2-Google 屬未來 |
| D5 | 讀自己 profile | 新 `GET /userCenter/getProfile`（**不**擴 `getUserInfo`） | getUserInfo 在登入關鍵路徑、不為 profile 加欄動它 |
| D6 | self 端點授權 | 3 端點皆 **auth-only**（`enforce_mw` 注 Claims、無 `require_policy`）、operator=`claims.uid`、不信 body id、免 casbin seed | 「操作自己」非 RBAC 資源授權；比照 getUserInfo |
| D7 | 改密碼流程 | 消費 024：`find_all→from_settings→validate_password_complexity(policy, 新密, user_name)→verify(舊密)→hash_password→窄寫 password`；前端動態 rule 取自 `getSystemSettings` ＋後端權威 | 雙保險；喚醒 024 dormant（拿掉 allow(dead_code)） |
| D8 | 窄寫 facade fn | **2 支新 fn**：`update_own_profile`（寫 gender/nick/phone/email、**不碰 user_name/password**）、`change_own_password`（寫 password）；皆 `updated_at`/`updated_by` 成對（§I.6）、operator=claims.uid、同 txn op-log、redact password | 既有 `update` 刻意不碰 password；facade-only 守恆 |
| D9 | 治理授權 | **MODAL-WIRING 新用途 (g)**（非-manage user-center 頁）、v1.2.0→v1.3.0（user 拍板 A、plan 正式 amend、DECISIONS §1 新列）；`page.userCenter.*` 綁 (g) | 六用途硬綁 manage、(e) 排除非-manage；比照 023 (f) |
| D10 | migration | **零**（sys_user gender/nick/phone/email/status/password 欄 024 前已齊；驗證無 verified flag＝未來） | 純寫既有欄 |
| D11 | i18n | 新 `page.userCenter.*`（綁 (g)）＋`backend.biz.password.*`（改密碼碼、BASE-WEB-I18N-WIRING 既授）；zh-CN 為主 | (g) 綁 page key；backend key 走既授軌道 |
| D12 | created/updated 顯示 | 基本资料卡唯讀加**创建时间＋建立原點語意**（後端解析 `created_by` vs `claims.uid`＋null → `system`/`self`/`admin`、always 顯示）；**更新时间僅「被管理員更新過」才顯示**（`updated_by` = 本人 或 null → **整列不顯示**）；**不洩露哪個管理員**（只回語意分類、不回 operator uid、不 join 查名） | user 拍板：只 surface「管理員動過我帳號」、本人更新/未更新皆隱藏；隱私＋零 join；抽樣實證 seed 帳號 `by=null`＝系统、admin 建的 `by=admin uid` |

## 4. 元件設計（act-on-code、既有 seam 名）

### 4.1 後端 handler（新 `server/src/handler/user_center.rs`、3 auth-only 端點）
- `GET /userCenter/getProfile`（`Extension<Claims>`）→ `find_active_by_id(claims.uid)` → DTO `{ userName, roles, userGender?, nickName?, userPhone?, userEmail?, createdAt, createdBy: 'system'|'self'|'admin', adminUpdatedAt: string|null }`（camelCase；roles 走 `roles_of_user`；`createdBy`＝比對 `created_by`：null→system／==claims.uid→self／else→admin；`adminUpdatedAt`＝`updated_at` **僅當** `updated_by` 非 null 且 ≠ `claims.uid`〔＝管理員更新〕、否則 `null`——本人更新/未更新皆不回時間，**不洩露 operator uid/姓名**）。
- `POST /userCenter/updateProfile`（`Extension<Claims>`+`Extension<RequestContext>`+`Json<UpdateProfileReq{ userGender?, nickName?, userPhone?, userEmail? }>`）→ `update_own_profile`（各區塊保存共用此端點、送全 model）。
- `POST /userCenter/changePassword`（`Json<ChangePwdReq{ oldPassword, newPassword, confirmPassword }>`）→ D7 流程；違規→`backend.biz.password.*`。
- `main.rs` 註冊 3 route（auth-only、無 `require_policy`）；`endpoint_coverage_lint` `AS_BUILT_ROUTES` +3（as-built 維護、非治理拍板）。

### 4.2 facade（`server/src/model/facade/sys_user.rs` 加 2 窄寫 fn）
- `update_own_profile(conn, uid, gender?, nick?, phone?, email?, meta)`：set 該 4 欄＋`updated_at`/`updated_by`（成對）；**不 Set** user_name/password；`mutate_in_txn` 同 txn op-log。
- `change_own_password(conn, uid, new_phc, meta)`：set `password`＋`updated_at`/`updated_by`；op-log redact（比照既有 AuditSerialize password `<redacted>`）。

### 4.3 喚醒 024 `password_policy`
- 拿掉 `#![allow(dead_code)]`（接線後成活碼）；changePassword handler 依 §2.1 載入範式呼叫。gender/enum 值域沿既有 normalize（`'1'|'2'`）。

### 4.4 前端 `views/user-center/index.vue`（4 區塊、★MODAL-WIRING (g)）
- 縱向 4 個 `NCard` 區塊；建議子元件拆 `views/user-center/modules/`（`basic-info-card.vue`／`phone-card.vue`／`email-card.vue`／`password-card.vue`）。
- 基本资料卡：用戶名/角色唯讀顯示（讀 authStore/getProfile）＋性别 radio＋昵称 input＋保存（updateProfile）；**唯讀資訊列**：`创建时间 <createdAt>（<origin>）`〔origin：system→系统创建／admin→由管理员创建／self→本人创建（罕見）〕；`adminUpdatedAt` 非 null 才顯示 `更新时间 <adminUpdatedAt>（由管理员更新）`、否則整列不顯示（本人更新/未更新皆隱藏）。
- 手机/邮箱卡：值 input（可改）＋保存（updateProfile）＋預留 發送/驗證碼 input/驗證（disabled 或 toast「功能建置中」）。
- 修改密码卡：舊/新/確認 input＋改密码（changePassword）；rule 用 `createConfirmPwdRule`＋動態取自 `getSystemSettings`。
- root 用 `flex-col-stretch gap-16px` 讓 main 滾（§2.5 overflow 修）。

### 4.5 wire（base-web、新檔）
- `service/api/rev3-user-center.ts`（`fetchGetProfile`/`fetchUpdateProfile`/`fetchChangePassword`、BASE-WEB-WRAPPER 新檔、不改 `auth.ts`）。
- `typings/api/rev3-user-center.d.ts`（profile/changePwd DTO、ADAPT declaration-merge）。

## 5. wire / 碼 / i18n
- **3 新 wire 端點**（3 端對齊：rust DTO ↔ ts inline type ↔ component state）。
- **碼**：改密碼違規→`backend.biz.password.complexity`（或逐 violation 細化）、舊密不符→`backend.biz.password.oldMismatch`、查無自己→復用 `biz.user.notFound`；皆 `2222` 信封、13 碼矩陣不擴張。
- **i18n**：`page.userCenter.*`（區塊標題/欄位/按鈕/改密碼標籤＋`createdAt`/`updatedAt` 標籤＋**`origin.system`／`origin.adminCreated`／`origin.selfCreated`／`origin.adminUpdated`**、綁 (g)）＋`backend.biz.password.*`（zh-cn/en-us＋`App.I18n.Schema` 先 Schema 後 locale）；zh-CN 為主。

## 6. 範圍邊界
**IN**：4 區塊 user-center 頁（basic/phone/email/password）／3 auth-only 端點（getProfile/updateProfile/changePassword）／2 窄寫 facade fn／喚醒 024 password_policy／前端動態密碼 rule／手机·邮箱驗證流程 **UI 預留**／`page.userCenter.*`+`backend.biz.password.*` i18n／MODAL-WIRING (g) amendment／overflow 修／零 migration／C-V（純測 changePassword 邏輯無新純函式〔複用 024〕→ acceptance 覆蓋；curl/psql/CDP）。

**OUT（未來 feature）**：真手機 SMS 發碼/驗證／真邮箱驗證·SAML2-Google 綁定登入／首登強制改密（must_change_pwd）／頭像上傳／2FA·TOTP／密碼歷史·到期／改密後撤 session／弱密字典·常見密碼黑名單／自助 session 管理／zh-TW locale。

**MOOT（already-done、不重做）**：024 `password_policy`（m009、dormant）／sys_user gender/nick/phone/email 欄（024 前齊）／`/user-center` 路由·頭像入口·`route.user-center` i18n／NForm 範本·`form.ts`·gender options·`page.manage.user.*` 標籤／`auth/password.rs` hash·verify／`claims.uid` extractor。

## 7. Constitution Check 留痕（`/speckit-plan` 對齊用）
- **唯一 gate＝MODAL-WIRING 新用途 (g)**（非-manage user-center 頁 inline/建頁＋`page.userCenter.*`）；user 拍板 A、plan 正式 amend v1.2.0→v1.3.0（§V.2/§V.3 MINOR）、DECISIONS §1 新列。
- **其餘全既授**：`backend.biz.password.*`→BASE-WEB-I18N-WIRING(⚠️aa) (ii)(iii)；新 typings→ADAPT／新 wrapper（rev3-*.ts 新檔）→WRAPPER／新 handler·facade→RUSTAPI-SOURCE-ISOLATION；3 auth-only 端點免 casbin seed（endpoint_coverage_lint AS_BUILT +3＝as-built 維護）；2 窄寫 facade 守 §I.6 成對＋facade-only＋op-log、operator=claims.uid 合規；零 migration（§I.6 archetype N/A）。
- **§I.7 行為島**：改密碼不改 token/policy/single-session 不變式（「改密後撤 session」屬未來、非本刀）。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）
- **FR-001** 使用者於 `/user-center` 見自己 profile：用戶名·角色**唯讀**、性别/昵称/手机/邮箱**可改**。**FR-002** 讀自己 profile 經新 self 端點（非擴 getUserInfo）。
- **FR-003** 改 profile（gender/nick/phone/email）持久（updateProfile、operator=自己、同 txn op-log）；**MUST NOT** 改 user_name/roles/password。
- **FR-004** 改密碼：舊密碼 verify 通過 ＋ 新密碼滿足 **024 admin 政策** → 寫入；舊密不符/新密違政策→明確業務錯誤、不寫入。**FR-005** 新密碼前端依政策動態 rule＋後端 `validate_password_complexity` 權威把關（雙保險）。
- **FR-006** 手机/邮箱各區塊有值 input（可改）＋**預留** 發送/驗證碼/驗證（點擊不接後端、明示佔位）。**FR-007** self 端點皆 **auth-only**（登入即可操作自己）、operator=`claims.uid`、不信 body id。
- **FR-008** 零 schema/migration；零 base-web 既有檔破壞性改（user-center 為換佔位、新檔為主）；`getUserInfo`/enforce 零回歸。 **FR-009** 基本资料卡唯讀顯示 `创建时间`＋建立原點語意（system/self/admin、**不洩露 operator 身分**〔uid/姓名〕）；`更新时间` **僅當被管理員更新過**（`updated_by` 非 null 且 ≠ 本人）才顯示、標「由管理员更新」，**本人更新/未更新皆不顯示更新列**。
- **SC**：SC-001 使用者見/改自己 profile 持久（CDP＋psql）。SC-002 改密碼 happy path 成功、新密碼可登入（live）。SC-003 舊密不符 / 新密違政策 → 2222、不寫入（純測＋live）。SC-004 政策動態 rule 隨 admin 設定變（CDP：改 min_length 後前端 rule 反映）。SC-005 手机/邮箱值可改可存、驗證三控件為預留（CDP）。SC-006 零回歸（getUserInfo/enforce/既有頁不變）。SC-007 profile 顯示创建时间＋建立原點；被管理員更新過的帳號顯示「由管理员更新」、本人更新/未更新不顯示更新列（CDP：以 seed 帳號〔系统创建〕vs admin-建帳號〔由管理员创建〕vs 自改帳號驗）。

## 9. C-V 驗收（草案、live serial；rust 容器內 `docker exec`）
- **C-V-1** live changePassword：舊密對+新密合規→200、psql `password` PHC 變、新密可 login；舊密錯→2222 oldMismatch；新密違政策→2222 complexity → FR-004/SC-002/SC-003。
- **C-V-2** live updateProfile：改 gender/nick/phone/email→psql 值變、op-log 一列 operator=自己；不動 user_name/password → FR-003/SC-001。
- **C-V-3** getProfile：回自己 4 profile 欄＋唯讀 userName/roles → FR-001/FR-002。
- **C-V-4** CDP：/user-center 4 區塊（基本资料/手机/邮箱/密码）；改 profile 持久、改密碼成功 toast、驗證三控件預留（點擊佔位）、動態密碼 rule 隨政策；restart base-web 後驗 i18n 非 raw key → SC-001/004/005。
- **C-V-5** 三守恆（entity_access_lint／endpoint_coverage_lint〔AS_BUILT+3〕／migration up→down→up〔零 migration、僅確認未破〕）＋`pnpm typecheck` → 守恆。
- **C-V-6** 零回歸（getUserInfo/login/enforce 不變、既有頁不破）→ SC-006。
- **C-V-7** prod image build（無新 crate；確認 user_center handler/facade 編入）。

## 10. Files（BUILD vs ALREADY）
**BUILD（新/改）**：`rust-api/server/src/handler/user_center.rs`（新、3 端點）＋`handler/mod.rs`／`server/src/model/facade/sys_user.rs`（+2 窄寫 fn）／`server/src/auth/password_policy.rs`（拿掉 `#![allow(dead_code)]`）／`server/src/main.rs`（+3 auth-only route）＋`server/tests/endpoint_coverage_lint.rs`（AS_BUILT +3）／base-web `src/views/user-center/index.vue`（換佔位）＋`views/user-center/modules/*`（4 卡）＋`src/service/api/rev3-user-center.ts`（新）＋`src/typings/api/rev3-user-center.d.ts`（新）＋i18n（`page.userCenter.*`+`backend.biz.password.*`，zh-cn/en-us＋`app.d.ts` Schema）。**★ constitution §III.2 加 MODAL-WIRING 用途 (g)、v1.3.0（plan amend）**。

**ALREADY（不動）**：024 `password_policy.rs`（m009）／sys_user 欄位·schema／`/user-center` 路由·頭像入口·`route.user-center`／`auth/password.rs`·`form.ts`·`user-operate-drawer.vue`（範本）·`page.manage.user.*`·gender options／`getUserInfo`（不擴）。

## 11. forward-compat / 下游
- **手機驗證真流程**：接外部 SMS（發碼→redis TTL→驗碼→`phone_verified`），需 verified 欄/端點——本刀 UI 預留已備接點。
- **邮箱驗證 / SAML2-Google**：SSO 綁定、`email_verified`。
- **其他**：首登強制改密（must_change_pwd）／頭像／2FA／密碼歷史·到期／改密後撤 session／弱密黑名單／自助 session 管理／zh-TW locale。
- **plan-phase 接地清單**：改密碼違規 wire 碼粒度（單一 complexity vs 逐 violation）／getProfile roles 呈現（code vs 顯示名）／各區塊「保存」共用 updateProfile 送全 model 的前端範式／(g) amendment 條文精確措辭（plan Constitution Check）。
