# Phase 0 Research: 025-user-center

> 決策格式 Decision／Rationale／Alternatives，皆 act-on-code 接地（grounding `wf_c3044ab2`〔brainstorm〕＋`wf_36bc32af`〔plan〕）。brainstorm 決策見 `docs/superpowers/025-user-center.md` §3。**治理 (g) amendment 已落**（constitution v1.2.0→v1.3.0、DECISIONS ⚠️ah、CHECKLIST 索引、commit `63d35179`）。

## R1 — 消費 024 `password_policy`（精確 as-built API）
- **Decision**：changePassword handler 呼叫 024 as-built：`from_settings(items: &[(&str,&str)]) -> PasswordPolicy`、`validate_password_complexity(&policy, new_plain, &user_name) -> Result<(), Vec<PolicyViolation>>`（**含 user_name 第三參**）。喚醒 dormant——移除 `server/src/auth/password_policy.rs` 檔頭 `#![allow(dead_code)]`。
- **Rationale**：政策先行 2 刀組第 2 刀的接線目標；024 原語已完整單元測試。**Alt**：025 自寫驗證＝重複 024，否決。

## R2 — 政策載入範式（handler）
- **Decision**：`let rows = facade::system_settings::find_all(&state.db).await?;`（Vec<Model> 須 bind local 保命）`let pairs: Vec<(&str,&str)> = rows.iter().map(|m|(m.setting_key.as_str(), m.setting_value.as_str())).collect();`→`password_policy::from_settings(&pairs)`。DB-fresh 每次改密碼現查。
- **Rationale**：`from_settings` 吃**借用 slice**、無現成 helper、非 password_* key 自動忽略；改密碼罕用不需快取。

## R3 — 2 支窄寫 facade fn（`model/facade/sys_user.rs`）
- **Decision**：仿既有 `update`+`build_update_active_model`（sys_user.rs:359/286）的 `mutate_in_txn` 骨架：
  - `update_own_profile(conn, uid, nick, gender, phone, email, meta) -> Result<Option<Model>, DbErr>`：`into_active_model` 只 `Set` nick/gender/phone/email ＋`updated_at`/`updated_by`（§I.6 成對）；user_name/password/status/session_policy/roles 皆 **Unchanged**（不 Set）；payload **不套 with_roles**（無角色改）。
  - `change_own_password(conn, uid, new_phc, meta)`：只 `Set` password ＋`updated_at`/`updated_by`；其餘 Unchanged。
  兩者同 txn op-log；`AuditSerialize` 自動 redact password（sys_user.rs:27）；operator＝`meta.operator.id`＝claims.uid。
- **Rationale**：既有 `update` 連 roles/status 處理、需 target id、不契合自助；facade-only 守恆。**Alt**：複用 `update`→會動 roles/status，否決。

## R4 — auth-only 端點註冊
- **Decision**：仿 `route_auth`（main.rs:190）：`Router::new().route("/userCenter/getProfile", get(..)).route("/userCenter/updateProfile", post(..)).route("/userCenter/changePassword", post(..)).layer(enforce_mw)`〔**無 require_policy**〕→ merge 進 app（main.rs:661）。`endpoint_coverage_lint` `AS_BUILT_ROUTES` **50→53**（加 3 路徑到陣列 endpoint_coverage_lint.rs:104）。**免 casbin seed**（斷言 A 只對 `require_policy` route 要 seed）。
- **Rationale**：「操作自己」非 RBAC 資源授權；比照 getUserInfo（auth-only、enforce_mw 注 Claims）。

## R5 — getProfile roles ＝ CODE
- **Decision**：getProfile 回 roles 為 **code**（`Vec<String>`）、複用 `sys_user_role::roles_of_user(&state.db, claims.uid)`（sys_user_role.rs:29）；與 getUserInfo（auth.rs:692 回 code）一致。前端唯讀顯示（顯示名映射屬前端 nicety、低優先、可後補）。
- **Rationale**：契約一致、零新 facade。**Alt**：resolve sys_role name→需 join、與 getUserInfo 不一致，否決（顯示名前端做）。（解掉 clarify deferred「roles code vs name」＝採 code。）

## R6 — created/updated 顯示語意（隱私、user 拍板）
- **Decision**：getProfile 回 `createdAt`（rfc3339）、`createdBy: "system"|"self"|"admin"`（後端 `match created_by { None→system, Some(u) if u==claims.uid→self, Some(_)→admin }`）、`adminUpdatedAt: Option<String>`（`match updated_by { Some(u) if u != claims.uid → Some(updated_at?.to_rfc3339()), _ → None }`——本人/未更新→None）。**不回 operator uid/name、不 join**。
- **Rationale**：user 拍板（只 surface「管理員動過我帳號」、本人更新/未更新隱藏）；隱私不洩露哪個 admin；`DateTimeWithTimeZone.to_rfc3339()`（沿 AuditSerialize 範式）。

## R7 — changePassword wire 碼（複用既有、少建）
- **Decision**：grep 確認 `biz.password.tooWeak`／`biz.password.mismatch`／`biz.password.sameAsOld`／`biz.user.notFound` **既存**。changePassword：新密違政策→**`biz.password.tooWeak`（複用）**、確認不符→前端攔＋後端 `biz.password.mismatch`、舊密不符→`biz.password.oldMismatch`（既有無此鍵、新增；或既有 mismatch 語意細分——impl grep 定）、查無自己→`biz.user.notFound`。皆 2222 信封、13 碼矩陣不擴張。前端 locale 補缺鍵（BASE-WEB-I18N-WIRING）。
- **Rationale**：複用既有碼、最小新 i18n key（比 brainstorm 假設「全新 backend.biz.password.*」更省）。

## R8 — 前端動態密碼 rule
- **Decision**：改密碼卡 `onMounted` `fetchGetSystemSettings()` 取 7 政策 → 組 naive rule（min/max length、字元類別 require）；確認欄用既有 `createConfirmPwdRule(newPwd)`（form.ts）；後端 `validate_password_complexity` 權威把關（雙保險）。
- **Rationale**：即時 UX ＋ 後端權威。

## R9 — 版面（4 卡 ＋ overflow 修）
- **Decision**：`views/user-center/index.vue` root 用 `flex-col-stretch gap-16px`（讓 main 滾、**去 table 模板 `overflow-hidden`**、見 024 收刀範式 DECISIONS ⚠️ag）；4 個 `NCard` 卡拆 `views/user-center/modules/`（`basic-info-card`/`phone-card`/`email-card`/`password-card`）。基本资料卡 form/basic 風（NForm labels）；手机/邮箱/密码卡 function/request 分區塊風（標題＋控件）。手机/邮箱值在各自卡（A）＋保存（共用 updateProfile 送全 model）＋預留驗證控件。
- **Rationale**：user 指定兩頁參考；naive 主流；overflow 已知坑；`modules/` 不生路由。

## R10 — 驗證佔位
- **Decision**：手机/邮箱卡的 發送驗證碼／驗證碼 input／驗證 ＝ NButton/NInput、點擊 `window.$message?.info($t('page.userCenter.verify.comingSoon'))`（明示建置中）、不接後端。
- **Rationale**：user 拍板純 UI 佔位；未來接 SMS/SAML2。

## R11 — 治理 (g)（已落）
- **Decision**：MODAL-WIRING (g) amendment 已完成（constitution v1.2.0→v1.3.0、§III.2 加用途 (g)、DECISIONS ⚠️ah、CHECKLIST 索引、commit `63d35179`、025 feature branch）。`page.userCenter.*` 綁 (g)。
- **Rationale**：user 親決 A；`views/user-center` 非-manage、(a)~(f) 硬綁 `views/manage/**` 未涵蓋（比照 023 ⚠️af feature-branch amendment 範式）。

## R12 — 零 migration
- **Decision**：sys_user 的 created_at/created_by/updated_at/updated_by/gender/nick/phone/email/password 欄 024 前已齊（實 DB 16 欄親驗 `\d sys_user`）→ **零 migration**。
- **Rationale**：純寫既有欄；驗證無 verified flag（未來）。

## R13 — i18n
- **Decision**：新 `page.userCenter.*`（區塊標題/欄位/按鈕/改密碼標籤 ＋ `createdAt`/`updatedAt` label ＋ `origin.system`/`origin.adminCreated`/`origin.selfCreated`/`origin.adminUpdated` ＋ `verify.comingSoon`，綁 (g)）；`backend.biz.password.*` 補缺（複用 tooWeak/mismatch ＋ 新 oldMismatch）。`App.I18n.Schema` **先擴 Schema 後加 locale**（zh-cn/en-us）。zh-CN 為主（zh-TW 未來）。
- **Rationale**：(g) 綁 page key；backend key 走 BASE-WEB-I18N-WIRING(⚠️aa)。
