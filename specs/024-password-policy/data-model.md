# Data Model: 024-password-policy

> 本刀**零 schema 變更**（不新增表/欄）。「資料模型」＝①`system_settings` 新增 7 政策 KV 列（m009 seed）②Rust 純邏輯型 `PasswordPolicy` / `PolicyViolation`。皆 act-on-code 接地（見 research.md）。

## 1. `system_settings` 新增 7 政策 KV 列（m009 seed）

既有表 `system_settings`（archetype A、PK=`setting_key` varchar、6 審計欄）不動；m009 `INSERT ... ON CONFLICT (setting_key) DO NOTHING` 加下列 7 列（`created_by=null`＝系統 seed、§I.6 明文授權）：

| setting_key | setting_value（預設） | value_type | description（DB 中文、上 wire） |
|---|---|---|---|
| `password_min_length` | `8` | `number` | 密碼最小長度 |
| `password_max_length` | `64` | `number` | 密碼最大長度 |
| `password_require_uppercase` | `off` | `enum:on,off` | 需含大寫字母 |
| `password_require_lowercase` | `off` | `enum:on,off` | 需含小寫字母 |
| `password_require_digit` | `off` | `enum:on,off` | 需含數字 |
| `password_require_special` | `off` | `enum:on,off` | 需含特殊符號 |
| `password_forbid_username` | `off` | `enum:on,off` | 禁止密碼與帳號相同 |

- **識別/唯一**：`setting_key`（PK）。`ON CONFLICT DO NOTHING` 冪等（重跑不重覆插）。
- **render 驅動**：`value_type` 決定前端控件——`enum:on,off`→既有 `NSwitch`（5 列、零前端改）；`number`→新 `NInputNumber` 分支（2 列，R8）。
- **值域**：`number` 列 value ∈ 正整數 `1..=1024`（R2、後端 `validate_value_type` 守）；`enum:on,off` 列 value ∈ {on, off}（既有 enum 驗證守）。
- **down**：`DELETE FROM system_settings WHERE setting_key IN (7 keys)`；up→down→up 可逆。

## 2. `PasswordPolicy`（Rust 純邏輯型，`auth/password_policy.rs`）

```
struct PasswordPolicy {
    min_length: usize,        // 預設 8
    max_length: usize,        // 預設 64
    require_uppercase: bool,  // 預設 false
    require_lowercase: bool,  // 預設 false
    require_digit: bool,      // 預設 false
    require_special: bool,    // 預設 false
    forbid_username: bool,    // 預設 false
}
```

### 2.1 `from_settings`（純 parse、吃非-entity 鍵值對，R5）

- 簽名（概念）：`fn from_settings(items: &[(&str, &str)]) -> PasswordPolicy`（或等價 iterator of (key, value)）。**不吃 `entity::…::Model`**（守 entity_access_lint）。
- parse 規則（**缺鍵→預設**、FR-010）：
  - `password_min_length` / `password_max_length`：`value.parse::<usize>().unwrap_or(<預設>)`（缺鍵或不可解析→預設 8 / 64）。
  - `password_require_*` / `password_forbid_username`：`value == "on"` → true，否則（含缺鍵）→ false。
- **不觸 DB**：消費者（刀2 handler）先 `facade::system_settings::find_all()` 讀欄位建 `(setting_key, setting_value)` 對再餵入。

## 3. `PolicyViolation`（Rust enum，`auth/password_policy.rs`）

```
enum PolicyViolation {
    TooShort,        // 長度 < min_length
    TooLong,         // 長度 > max_length
    NeedUppercase,   // require_uppercase 且無 [A-Z]
    NeedLowercase,   // require_lowercase 且無 [a-z]
    NeedDigit,       // require_digit 且無 [0-9]
    NeedSpecial,     // require_special 且無特殊符號（R1）
    SameAsUsername,  // forbid_username 且 密碼 eq_ignore_ascii_case 帳號
}
```

- 刀2 wire i18n 對映（本刀不實作、僅登）：`TooShort→backend.biz.password.tooShort`、`TooLong→…tooLong`、`NeedUppercase→…needUppercase`、`NeedLowercase→…needLowercase`、`NeedDigit→…needDigit`、`NeedSpecial→…needSpecial`、`SameAsUsername→…sameAsUsername`。

## 4. `validate_password_complexity`（純函式，回全部違規、R6）

- 簽名（概念）：`fn validate_password_complexity(policy: &PasswordPolicy, plain: &str, user_name: &str) -> Result<(), Vec<PolicyViolation>>`。
- 規則（逐條檢、**非短路**、收集全部違規；長度用 `chars().count()`、邊界含）：

| 條件 | 判定 | 違規 |
|---|---|---|
| 長度下界 | `chars().count() >= min_length` | 否→`TooShort` |
| 長度上界 | `chars().count() <= max_length` | 否→`TooLong` |
| 大寫 | `!require_uppercase || plain.chars().any(|c| c.is_ascii_uppercase())` | 否→`NeedUppercase` |
| 小寫 | `!require_lowercase || plain.chars().any(|c| c.is_ascii_lowercase())` | 否→`NeedLowercase` |
| 數字 | `!require_digit || plain.chars().any(|c| c.is_ascii_digit())` | 否→`NeedDigit` |
| 特殊符號 | `!require_special || plain.chars().any(|c| c.is_ascii_graphic() && !c.is_ascii_alphanumeric())` | 否→`NeedSpecial` |
| 禁同帳號 | `!forbid_username || !plain.eq_ignore_ascii_case(user_name)` | 否→`SameAsUsername` |

- 空違規集 → `Ok(())`；非空 → `Err(violations)`。
- **min>max**（R3）：`TooShort` 與 `TooLong` 可能同時觸發（任何長度無法同時滿足）→ 一律不符（安全 fallback、不當機）。

## 5. `validate_value_type` number 驗證（`handler/system_settings.rs`，R2）

- **⚠️ seed value_type ＝ bare `"number"`（無冒號）**：`"number".split_once(':')` 回 `None`，故**不可**用 `Some(("number", _))` arm（永不命中、落 `_ => Ok(())` 靜默放行非法值）。**number 走整串比對**：
  - 於函式開頭（既有 `match value_type.split_once(':')` **之前**）early-return：`if value_type == "number" { return match value.parse::<u32>() { Ok(n) if (1..=1024).contains(&n) => Ok(()), _ => Err(AppError::Biz(Cow::Borrowed("biz.systemSettings.invalidValue"))) }; }`。
- 既有 enum `split_once` match 與 `_ => Ok(())` 保守放行不動。

## 6. 狀態轉移 / 生命週期

- 政策 KV 列：m009 seed 建立（值＝保守預設）→ admin 經既有 update 端點改值（同 txn op-log）→ 值持久。無刪除路徑（沿 008、`system_settings` 無 delete 端點）。
- `PasswordPolicy`：無狀態（每次 `from_settings` 由當前 KV 現算，R7 load-on-demand）。
- 本刀 `validate_password_complexity` **dormant**：僅單元測試呼叫，無 live 消費者（刀2 接，R11）。
