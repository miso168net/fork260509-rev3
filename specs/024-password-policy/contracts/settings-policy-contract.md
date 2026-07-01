# Contract: 024-password-policy

> 本刀**零新 HTTP 端點**。契約＝①復用 008 端點 ②7 KV 資料契約 ③`number` value_type 驗證契約 ④`password_policy` 純函式契約 ⑤i18n。

## 0. HTTP 端點（復用 008、零新增）

| 端點 | method | 授權 | 本刀影響 |
|---|---|---|---|
| `/systemManage/getSystemSettings` | GET | super-only（require_policy）| 回形不變；m009 後多回 7 個 `password_*` 列 |
| `/systemManage/updateSystemSetting` | POST | super-only | 簽名不變；`body {settingKey, settingValue}`；number 列經新 `validate_value_type` number 分支守門 |

- **無新 route、無新 casbin policy** → `endpoint_coverage_lint` registry 不變。
- wire DTO：`SystemSettingItem{settingKey,settingValue,valueType,description?}`（camelCase）／`UpdateReq{settingKey,settingValue}`——**皆既有、不改**。`settingValue` wire 恆 `string`（number 僅前端 render 時 `Number()`、送出 `String()`）。

## 1. 7 KV 資料契約

| setting_key | value_type | 預設 | 合法值 | 語意 |
|---|---|---|---|---|
| `password_min_length` | `number` | `8` | 正整數 1..=1024 | 密碼最小長度 |
| `password_max_length` | `number` | `64` | 正整數 1..=1024 | 密碼最大長度 |
| `password_require_uppercase` | `enum:on,off` | `off` | on / off | 需含大寫字母 |
| `password_require_lowercase` | `enum:on,off` | `off` | on / off | 需含小寫字母 |
| `password_require_digit` | `enum:on,off` | `off` | on / off | 需含數字 |
| `password_require_special` | `enum:on,off` | `off` | on / off | 需含特殊符號（R1：ASCII 可列印非英數） |
| `password_forbid_username` | `enum:on,off` | `off` | on / off | 禁止密碼與帳號相同 |

## 2. `number` value_type 驗證契約（`validate_value_type`）

| value_type | value | 結果 |
|---|---|---|
| `number` | `"8"` / `"1"` / `"1024"` | ✅ `Ok(())` |
| `number` | `"0"` | ❌ `2222 biz.systemSettings.invalidValue`（下界）|
| `number` | `"-1"` | ❌ 2222（parse u32 失敗）|
| `number` | `"abc"` / `""` | ❌ 2222（parse 失敗）|
| `number` | `"1025"` / `"9999"` | ❌ 2222（上界）|
| `enum:on,off` | `on` / `off` | ✅（既有 enum 分支、不改）|

- 錯誤 wire：HTTP 200 信封 `{code:"2222", msg:"biz.systemSettings.invalidValue", data:null}`（沿 008 既有 pattern，前端攔截器 `$t('backend.biz.systemSettings.invalidValue')`）。
- **實作註**：`number` 為 bare value_type（無冒號）→ 以**整串比對**判定（`value_type == "number"` early-return）、**不經 `split_once`**（否則 `Some(("number",_))` arm 永不命中、靜默放行）。

## 3. `password_policy` 純函式契約（本刀 dormant、供刀2）

```
fn from_settings(items: &[(&str, &str)]) -> PasswordPolicy       // 缺鍵→預設；零 entity::、零 DB
fn validate_password_complexity(&PasswordPolicy, plain: &str, user_name: &str)
    -> Result<(), Vec<PolicyViolation>>                          // 回全部違規、非短路
enum PolicyViolation { TooShort, TooLong, NeedUppercase, NeedLowercase, NeedDigit, NeedSpecial, SameAsUsername }
```

- 契約性質：**純函式、零 side-effect、零 `entity::`、零 DB**（消費者從 `find_all()` 讀欄位建 `(key,value)` 對餵入）。
- 規則細節見 data-model §2~§4。
- 刀2 i18n 對映（登、本刀不實作）：`PolicyViolation::X → backend.biz.password.<x>`。

## 4. i18n 契約

- **零新 key**：number 非法復用既有 `biz.systemSettings.invalidValue`（zh-cn `zh-cn.ts:893` / en-us `en-us.ts:898` 已存在）；7 列說明用 DB `description`（中文，沿 `single_session_default` 範式）。
