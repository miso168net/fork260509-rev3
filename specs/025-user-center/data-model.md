# Data Model: 025-user-center

> **零 schema 變更**（不新增表/欄）。模型＝①`sys_user` 既有欄（025 讀/寫子集）②wire DTO（getProfile/updateProfile/changePassword）③created/updated 語意解析邏輯。act-on-code（grounding）。

## 1. `sys_user` 既有欄（025 讀/寫子集、零 migration）

| 欄位 | 025 用途 |
|---|---|
| `id` | claims.uid（內部、不上 wire 除 operator）|
| `user_name` | getProfile 唯讀回；**不寫** |
| `password` | change_own_password 寫（argon2 PHC）；**永不上 wire** |
| `nick_name` / `user_gender` / `user_phone` / `user_email` | getProfile 回 ＋ update_own_profile 寫 |
| `status` / `session_policy` / `current_session_id` | **不動**（admin/系統治理欄） |
| `created_at` / `created_by` | getProfile 讀 → `createdAt`／`createdBy` 語意（§3） |
| `updated_at` / `updated_by` | getProfile 讀 → `adminUpdatedAt` 語意（§3）；2 窄寫 fn 寫 `updated_at`/`updated_by` 成對 |
| `deleted_at` / `deleted_by` | N/A（自己必 active、find_active_by_id）|
| roles（join `sys_user_role`）| getProfile 回 `code[]`（唯讀、R5）|

## 2. wire DTO（camelCase）

### GetProfileRes（`GET /userCenter/getProfile` 回）
`{ userName: String, roles: Vec<String>〔code〕, userGender: Option<i16>, nickName: Option<String>, userPhone: Option<String>, userEmail: Option<String>, createdAt: String〔rfc3339〕, createdBy: "system"|"self"|"admin", adminUpdatedAt: Option<String>〔rfc3339 或 null〕 }`

### UpdateProfileReq（`POST /userCenter/updateProfile` 收）
`{ userGender?: i16, nickName?: String, userPhone?: String, userEmail?: String }`（各卡「保存」共用此端點、送全 model；**不含** user_name/roles/password/status）

### ChangePwdReq（`POST /userCenter/changePassword` 收）
`{ oldPassword: String, newPassword: String, confirmPassword: String }`

## 3. created/updated 語意解析（後端純邏輯、R6、不洩露 operator）

- **createdBy**：`match created_by { None => "system", Some(u) if u == claims.uid => "self", Some(_) => "admin" }`。always 回。
- **adminUpdatedAt**：`match updated_by { Some(u) if u != claims.uid => Some(updated_at?.to_rfc3339()), _ => None }`（本人更新 或 從未更新 → `None` → 前端隱藏更新列）。
- **不回 operator uid/name、不 join**（隱私）。`createdAt`＝`created_at.to_rfc3339()`。

## 4. facade 窄寫 fn（`sys_user.rs`、R3）

- `update_own_profile(conn, uid, nick, gender, phone, email, meta)`：`into_active_model` → Set 4 欄 ＋ `updated_at`/`updated_by`（成對）；user_name/password/status/roles **Unchanged**；`mutate_in_txn` 同 txn op-log（無 `with_roles`）。
- `change_own_password(conn, uid, new_phc, meta)`：Set `password` ＋ `updated_at`/`updated_by`；`mutate_in_txn` op-log（password redact）。
- 兩者 operator＝`meta.operator.id`＝claims.uid（`ctx.to_audit_meta(claims.uid)`）。

## 5. changePassword 驗證規則（handler、R1/R7；順序固定）

1. `find_active_by_id(claims.uid)` → 無 → `biz.user.notFound`。
2. `confirmPassword == newPassword`（前端攔 ＋ 後端驗）→ 否 → `biz.password.mismatch`。
3. `password::verify(oldPassword, user.password)` → false → `biz.password.oldMismatch`。
4. 載政策（R2）→ `validate_password_complexity(&policy, newPassword, &user.user_name)` → Err → `biz.password.tooWeak`（複用）。
5. `password::hash_password(newPassword)` → `change_own_password(uid, hash, meta)`。

## 6. updateProfile 規則

- 只寫 nick/gender/phone/email；phone/email 格式由前端 `patternRules.phone/email` 驗（後端容忍空值 Option）。operator＝claims.uid、不信 body id。

## 7. 狀態 / 生命週期

- **profile**：讀既有欄 → 改（updateProfile、operator=自己）→ 持久。
- **password**：改（changePassword）→ PHC 更新、新密可登入、舊 PHC 失效；不撤既有 session（撤 session 屬未來、§I.7 不動）。
- **驗證流程**：UI 佔位、無後端狀態（未來加 verified 欄/端點）。
