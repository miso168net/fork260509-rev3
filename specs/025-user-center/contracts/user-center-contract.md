# Contract: 025-user-center

> 3 個**新 auth-only** 端點（`enforce_mw` 注 Claims、**無 `require_policy`**、operator=`claims.uid`、**免 casbin seed**）。零新 numeric 碼（2222＋i18n key）。

## 0. 端點（3 新、auth-only）

| 端點 | method | 授權 | 說明 |
|---|---|---|---|
| `/userCenter/getProfile` | GET | auth-only | 讀自己 profile ＋ created/updated 語意 |
| `/userCenter/updateProfile` | POST | auth-only | 寫自己 gender/nick/phone/email |
| `/userCenter/changePassword` | POST | auth-only | 舊密 verify → 套 024 政策 → hash → 窄寫 password |

- 註冊：`route_auth` 範式（main.rs:190）、`.layer(enforce_mw)`、merge 進 app（main.rs:661）；`endpoint_coverage_lint` `AS_BUILT_ROUTES` **50→53**；**無 casbin p-policy seed**（斷言 A 只對 `require_policy` route 要 seed；auth-only 免）。

## 1. DTO（camelCase）

- **GetProfileRes**：`{ userName, roles: string[]〔code〕, userGender?, nickName?, userPhone?, userEmail?, createdAt〔rfc3339〕, createdBy: "system"|"self"|"admin", adminUpdatedAt: string|null }`。
- **UpdateProfileReq**：`{ userGender?, nickName?, userPhone?, userEmail? }`（各卡保存共用、送全 model；不含 user_name/roles/password/status）。
- **ChangePwdReq**：`{ oldPassword, newPassword, confirmPassword }`。

## 2. created/updated 語意契約（不洩露 operator、R6）

| 情況 | createdBy | 前端訊息 |
|---|---|---|
| `created_by=null` | `system` | 系统创建 |
| `==claims.uid` | `self` | 本人创建（罕見）|
| `≠自己、非 null` | `admin` | 由管理员创建 |

`adminUpdatedAt`：`updated_by` 非 null 且 ≠ `claims.uid` → `updated_at` rfc3339；否則 **null**（本人更新/未更新→前端不顯示更新列）。**不回 operator uid/name、不 join**。

## 3. changePassword 契約（消費 024、順序固定）

1. `find_active_by_id(claims.uid)` 無 → `biz.user.notFound`。
2. `confirm==new` 否 → `biz.password.mismatch`。
3. `verify(old, phc)` false → `biz.password.oldMismatch`。
4. 載政策（`find_all`→pairs→`from_settings`）→ `validate_password_complexity(&policy, new, &user_name)` Err → `biz.password.tooWeak`（複用）。
5. `hash_password(new)` → `change_own_password(uid, hash, meta)`。

## 4. biz 碼 / i18n（複用為主）

- 複用既有：`biz.password.tooWeak`、`biz.password.mismatch`、`biz.user.notFound`。新增：`biz.password.oldMismatch`。皆 **2222 信封、13 碼矩陣不擴張**。
- i18n：`backend.biz.password.*` 補缺鍵（BASE-WEB-I18N-WIRING ⚠️aa）＋`page.userCenter.*`（含 `origin.*`／`createdAt`／`updatedAt`／`verify.comingSoon`，綁 (g)）；`App.I18n.Schema` 先 Schema 後 locale。

## 5. 授權 / 安全

- 全 auth-only、operator=`claims.uid`、**不信 body id**；只作用於「自己」（不能讀/改他人）。
- `password` 永不上 wire；op-log 對 password redact（`<redacted>`、AuditSerialize）。
- updateProfile **不動** user_name/roles/status/password；changePassword **只動** password。
