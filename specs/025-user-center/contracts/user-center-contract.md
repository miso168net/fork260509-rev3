# Contract: 025-user-center

> 4 個**新 auth-only** 端點（`enforce_mw` 注 Claims、**無 `require_policy`**、operator=`claims.uid`、**免 casbin seed**）。零新 numeric 碼（2222＋i18n key）。
>
> **〔as-built 校正 · U2〕** 原計畫 3 端點＋前端直讀 `getSystemSettings` 取政策；實作發現 `/systemManage/getSystemSettings` 是 **R_SUPER-only**（m002 casbin seed 只給 R_SUPER→非-super 讀撞 403、動態 rule 靜默退化、違 FR-009/FR-014）。故【新增第 4 端點 `/userCenter/getPasswordPolicy`】（auth-only、allowlist 只回 7 個 `password_*` 鍵、不洩露 session/IP 等其他設定），前端改讀此端點。`AS_BUILT_ROUTES` 因此 **50→54**（非原 50→53）。

## 0. 端點（4 新、auth-only）

| 端點 | method | 授權 | 說明 |
|---|---|---|---|
| `/userCenter/getProfile` | GET | auth-only | 讀自己 profile ＋ created/updated 語意 |
| `/userCenter/updateProfile` | POST | auth-only | 寫自己 gender/nick/phone/email |
| `/userCenter/changePassword` | POST | auth-only | 舊密 verify → 套 024 政策 → hash → 窄寫 password |
| `/userCenter/getPasswordPolicy` | GET | auth-only | 回 7 個 `password_*` 政策鍵（allowlist、供改密卡動態 rule；避 super-only `getSystemSettings` 403） |

- 註冊：`route_auth` 範式（main.rs:190）、`.layer(enforce_mw)`、merge 進 app（main.rs:661）；`endpoint_coverage_lint` `AS_BUILT_ROUTES` **50→54**；**無 casbin p-policy seed**（斷言 A 只對 `require_policy` route 要 seed；auth-only 免）。

## 1. DTO（camelCase）

- **GetProfileRes**〔as-built U-polish 校正：`adminUpdatedAt` → `updatedAt`+`updatedBy`、user 拍板〕：`{ userName, roles: string[]〔code〕, userGender?, nickName?, userPhone?, userEmail?, createdAt〔rfc3339〕, createdBy: "system"|"self"|"admin", updatedAt: string|null〔rfc3339、從未修改→null〕, updatedBy: "system"|"self"|"admin" }`。
- **UpdateProfileReq**〔as-built U-polish 校正：改**部分更新**〕：`{ userGender?, nickName?, userPhone?, userEmail? }`（各區塊保存【只送自己欄位】、後端只 `Set` 有帶（`Some`）的欄、未帶者 Unchanged；不含 user_name/roles/password/status）。
- **ChangePwdReq**：`{ oldPassword, newPassword, confirmPassword }`。
- **PasswordPolicyItem**〔as-built U2、`getPasswordPolicy` 回 `[]`〕：`{ settingKey, settingValue }`（allowlist 7 個 `password_*` 鍵；前端 `buildPolicyRules` 消費組動態 rule）。

## 2. created/updated 語意契約（不洩露 operator、R6；as-built U-polish 校正＝user 拍板）

`createdBy` 與 `updatedBy` 共用同一純分類 `classify_operator`（`None`→`system`／`==claims.uid`→`self`／其他→`admin`）；`updatedAt`＝raw `updated_at` rfc3339、從未修改→`null`。**不回 operator uid/name、不 join**。前端渲染（修改时间列【一律顯示、不隱藏】）：

| 情況 | 创建时间 顯示 | 修改时间 顯示 |
|---|---|---|
| `created_by=null`＋`updated_at=null` | `<ts>（系统创建）` | `未修改` |
| created=admin＋updated=admin（有值） | `<ts>（管理员创建）` | `<ts>（管理员修改）` |
| created=self＋updated=self（有值） | `<ts>`（無標註） | `<ts>`（無標註） |
| updated=system（有值、罕見） | — | `<ts>（系统修改）` |

〔原設計「只 surface 管理員更新、本人/未更新隱藏整列（adminUpdatedAt）」已被 user 收尾拍板推翻——修改时间列永遠顯示、來源以 system/self/admin 標註、self 不標註。〕

## 3. changePassword 契約（消費 024、順序固定）

1. `find_active_by_id(claims.uid)` 無 → `biz.user.notFound`。
2. `confirm==new` 否 → `biz.password.mismatch`。
3. `verify(old, phc)` false → `biz.password.oldMismatch`。
4. 載政策（`find_all`→pairs→`from_settings`）→ `validate_password_complexity(&policy, new, &user_name)` Err → `biz.password.tooWeak`（淨新）。
5. `hash_password(new)` → `change_own_password(uid, hash, meta)`。

## 4. biz 碼 / i18n（3 個 password 碼淨新、僅 notFound 複用）

- **淨新**（★ 全庫零命中、實碼確認：需**新建**後端 `AppError::Biz(Cow::Borrowed(...))` 發射 ＋ 前端 `backend.biz.password.*` locale 三鍵）：`biz.password.tooWeak`／`biz.password.mismatch`／`biz.password.oldMismatch`。**唯一複用**：`biz.user.notFound`（後端 `system_manage.rs` 既有 + 前端 locale 既有）。皆 **2222 信封、13 碼矩陣不擴張**。
- i18n：`backend.biz.password.*` 補缺鍵（BASE-WEB-I18N-WIRING ⚠️aa）＋`page.userCenter.*`（含 `origin.*`／`createdAt`／`updatedAt`／`verify.comingSoon`，綁 (g)）；`App.I18n.Schema` 先 Schema 後 locale。

## 5. 授權 / 安全

- 全 auth-only、operator=`claims.uid`、**不信 body id**；只作用於「自己」（不能讀/改他人）。
- `password` 永不上 wire；op-log 對 password redact（`<redacted>`、AuditSerialize）。
- updateProfile **不動** user_name/roles/status/password；changePassword **只動** password。
