# Contract: envelope-contract（003-envelope 凍結信封＋13 碼矩陣）

> 權威＝constitution §I.3（NON-NEGOTIABLE）＋DESIGN §7.3＋⚠️e/⚠️f。本檔為本刀忠實實作的凍結對象；rust 型模型見 [../data-model.md](../data-model.md)。

## 1. 信封形（凍結）

**`Res<T>`**（universal、除 `/health` plain-text、`/metrics` exposition 兩例外）：
```json
{ "data": <T|null>, "code": "<string>", "msg": "<去前綴語意 key>" }
```
- 欄序固定 `data`→`code`→`msg`；`code` 為 **string**（非 number）；錯誤時 `data: null`（**不省略**）；**無** `success` bool。

**`PageRes<T>`**（包在 `Res<T>.data`）：
```json
{ "current": <num>, "size": <num>, "total": <num>, "records": [<T>...] }
```
- camelCase、JSON number；空頁 `records: []`；**無** `pages`／`success`。

## 2. 13 碼矩陣（整組凍結 ⚠️f；本刀實作 9 可發＋型別層擋 4 reserved）

| code | 變體（rust） | wire key（去前綴） | zh-CN 預設譯文 | HTTP | 後端發出 | 前端顯示路徑 |
|---|---|---|---|---|---|---|
| `0000` | `Res::ok`（成功路徑） | `common.success` | 请求成功 | **200** | ✅ 成功 | 否（走 data） |
| `1000` | `AppError::LoginFailed` | `auth.login.failed` | 用户名或密码错误 | **200** | ✅ | generic toast |
| `2222` | `AppError::Biz(key)` | 入參 key（預設 `biz.error`） | 业务错误 | **200** | ✅ | generic toast |
| `3333` | `AppError::TokenExpired` | `auth.token.expired` | 登录已过期 | **200** | ✅ | 否（前端刷新） |
| `7777` | `AppError::ModalLogout` | `auth.session.kicked` | 账号在他处登录 | **200** | ✅ | **modal**（`:71`） |
| `8888` | `AppError::Logout` | `auth.session.reLogin` | 请重新登录 | **200** | ✅ | 否（靜默登出） |
| `4040` | `AppError::NotFound` | `system.notFound` | 接口不存在 | **404** | ✅（`.fallback`） | **否**（R3 限制） |
| `5003` | `AppError::PermissionDenied` | `system.forbidden` | 权限不足 | **403** | ✅（enforce 刀） | **否**（R3 限制） |
| `5000` | `AppError::Internal` | `system.internal` | 服务器内部错误 | **200** | ✅ | generic toast |
| `7778` | —（**無變體**） | — | 账号状态变更 | — | **❌ 永不** | （前端 .env 行為認得） |
| `8889` | —（**無變體**） | — | 账号已被禁用 | — | **❌ 永不** | 同上 |
| `9998` | —（**無變體**） | — | 登录信息无效 | — | **❌ 永不** | 同上 |
| `9999` | —（**無變體**） | — | 登录已过期 | — | **❌ 永不** | 同上 |

## 3. HTTP 狀態映射（凍結）

- **預設全 HTTP 200 信封**（⚠️e：`5000` 亦 200——前端 msg 顯示通道僅 200 生效）。
- **真實非 200 僅二**：`4040`→**404**（router `.fallback`）、`5003`→**403**（enforce 刀、本刀未發）。
- 本刀 `IntoResponse for AppError`：match `NotFound`→404／`PermissionDenied`→403／其餘→200。

## 4. 不變式（contract test 守）

1. **碼集合**：所發 `code` ∈ 9 可發碼（`{0000,1000,2222,3333,7777,8888,4040,5003,5000}`）。
2. **reserved guard**：`7778`/`8889`/`9998`/`9999` **無 `AppError` 變體** → 編譯期保證後端無法構造/發出（型別層、非 runtime 斷言）。
3. **msg 是 key 非人話**：每 `AppError` 變體之 `key` 符語意 key regex（`^[a-z][a-zA-Z]*(\.[a-zA-Z]+)+$`、**無 CJK 漢字**）。
4. **欄序/形**：`Res<T>` 序列化 `data`→`code`→`msg`、`data:null` 不省略；`PageRes` 無 `pages`/`success`、空頁 `records:[]`。
5. **HTTP**：9 可發碼除 `4040`/`5003` 外皆 200。

> 逐碼 condition 命名（`reLogin` vs `expired`、`kicked` 等）spec→plan 期可微調、不影響不變式；root 集合（common/auth/biz/system）+ 文法已凍於 [i18n-key-convention.md](i18n-key-convention.md)。
