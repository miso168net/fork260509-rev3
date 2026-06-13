# Data Model — 003-envelope

> **權威序聲明**：本檔是**型別座標圖**。權威序＝①base-web 實碼（`Service.Response<T>` typings＋`.env` 成功碼＝wire 唯一權威，§I.3）＞②rev2 008 參考形（`fork260509-rev2/rust-api/server/src/envelope.rs`／`error.rs`、受控參照讀允許拷貝禁止）＞③本檔。implementer 寫型別時逐項對照 R1/R2 grep 座標，不得只抄本檔。
> **凍結紀律**：序列化形與 13 碼 code/msg 字串為 wire 凍結事實（⚠️e/⚠️f／constitution §I.3）；本檔座標與凍結不符 → 以 grep 實碼為準、回頭最小 patch 本檔。

## 1. 型別總覽（envelope.rs＋error.rs）

| 型別 | 檔 | 職責 | rev2 座標 |
|---|---|---|---|
| `Res<T>` | envelope.rs | 統一回應信封 `{data,code,msg}` | envelope.rs:19-70 |
| `PageRes<T>` | envelope.rs | 分頁殼（承載於 Res 的 data） | envelope.rs:79-88 |
| `BizCode` | envelope.rs | 13 碼矩陣＋3 方法（單一真相） | envelope.rs:93-144 |
| `AppError` | error.rs | 集中錯誤映射（rev3 改良） | error.rs:15-34（rev2 瘦身形、rev3 改良） |

## 2. `Res<T>`（信封；序列化形凍結）

- 欄位（宣告序＝序列化序）：`data: Option<T>` → `code: String` → `msg: String`。
- serde：`#[derive(Serialize)]`；`code` 序列化為**字串**；**無 `success` 欄**；`data:None`→`"data":null`（**不**加 `skip_serializing_if`）。
- 建構子四件（envelope-shape 單一真相）：
  | 建構子 | data | code | msg |
  |---|---|---|---|
  | `ok(data)` | `Some(data)` | `"0000"` | `"请求成功"`（`BizCode::Success.default_msg()`） |
  | `ok_msg(data, msg)` | `Some(data)` | `"0000"` | 自訂 |
  | `err(code)` | `None` | `code.code()` | `code.default_msg()` |
  | `err_msg(code, msg)` | `None` | `code.code()` | 自訂 |
  - `err`/`err_msg` 泛型化 `impl<T>`（任何 `Res<T>` 都能回 error body、`data` 仍 null、T 只是型別參數）。
- `IntoResponse for Res<T>`：強制 HTTP **200**（非 200 由 `AppError` tuple 覆寫——見 §5）。
- **golden**：`Res::ok(42i32)` → `{"data":42,"code":"0000","msg":"请求成功"}`（rev2 單測 envelope.rs:156+ 同形）。

## 3. `PageRes<T>`（分頁殼）

- 欄位：`current: u64` → `size: u64` → `total: u64` → `records: Vec<T>`。
- serde：`#[serde(rename_all = "camelCase")]`；u64＝JSON 數字；**無 `pages`**、**無 `success`**；空頁 `records:[]`（非 null）。
- 作為 `Res<T>` 的 `data` payload 攜帶（`Res<PageRes<X>>`）。↔ base-web `Common.PaginatingQueryRecord<T>`。

## 4. `BizCode`（13 碼矩陣；3 方法單一真相）

13 變體（命名沿 rev2、⚠️k 風格）；`code()`／`default_msg()`／**`http_status()`（rev3 新增單一真相）**。code/msg 字串為 wire 凍結事實（逐字對 R1 grep）：

| # | variant | `code()` | `default_msg()` | `http_status()` | 可發出? |
|---|---|---|---|---|---|
| 1 | `Success` | `0000` | 请求成功 | 200 | （成功路徑、非 AppError） |
| 2 | `LoginFailed` | `1000` | 用户名或密码错误 | 200 | ✅ |
| 3 | `BizError` | `2222` | 业务错误 | 200 | ✅ |
| 4 | `TokenExpired` | `3333` | 登录已过期 | 200 | ✅ |
| 5 | `ModalLogout7777` | `7777` | 账号在他处登录 | 200 | ✅ |
| 6 | `ModalLogout7778` | `7778` | 账号状态变更 | 200 | ❌ 保留 |
| 7 | `Logout8888` | `8888` | 请重新登录 | 200 | ✅ |
| 8 | `Logout8889` | `8889` | 账号已被禁用 | 200 | ❌ 保留 |
| 9 | `TokenInvalid9998` | `9998` | 登录信息无效 | 200 | ❌ 保留 |
| 10 | `TokenExpiredAlt9999` | `9999` | 登录已过期 | 200 | ❌ 保留 |
| 11 | `NotFound` | `4040` | 接口不存在 | **404** | ✅ |
| 12 | `PermissionDenied` | `5003` | 权限不足 | **403** | ✅ |
| 13 | `Internal` | `5000` | 服务器内部错误 | **200** | ✅（⚠️e：200 非 500） |

- **`http_status()` 單一真相**：唯二非 200＝`NotFound`(404)、`PermissionDenied`(403)；其餘全 200（含 `Internal`＝⚠️e）。
- **不變式**：13 碼 enum 完整（矩陣＋對齊 base-web `.env` 分組）；`Internal.http_status()==200`、全 enum 無 →500。

## 5. `AppError`（集中錯誤映射；rev3 改良）

- 形：`struct AppError { code: BizCode, msg: Option<String> }`（`code` 私有欄）；`#[derive(thiserror::Error)]`（Display 供 log）。
- **8 公開建構子**（可發出 error 碼）：`login_failed()`／`biz(msg)`／`token_expired()`／`modal_logout()`／`logout()`／`not_found()`／`permission_denied()`／`internal(detail)`——對應 LoginFailed/BizError/TokenExpired/ModalLogout7777/Logout8888/NotFound/PermissionDenied/Internal。**4 保留碼無建構子**（⚠️f 結構保證；`code` 私有 → 無路徑構造保留碼）。
- 集中 `IntoResponse`：`(self.code.http_status(), axum::Json(<Res::err 形 body: {data:null, code, msg or default_msg}>))`——一處 status↔code 映射、`http_status()` 表驅動。
- **內部不洩漏**：`internal(detail)` 的 detail 僅進 thiserror Display（log）；client body 的 msg 來自 `default_msg()`「服务器内部错误」（rev2 error.rs:69 同形）。
- handler（後續刀）回 `Result<Res<T>, AppError>` 用 `?` 傳播。

## 6. 序列化契約硬約束（contract test 鎖）

- `Res` 欄序 data→code→msg；`code` 帶引號字串；無 `success`；`data:null` 不省略。
- `PageRes` camelCase；u64 數字；無 pages/success；空 `records:[]`。
- 13 碼 code/msg 字串逐字（§4 表＝R1 grep 鎖）。
- `http_status()`：Internal=200、NotFound=404、PermissionDenied=403、餘 200。

## 7. 排除聲明

- **各碼發出點**（Res::err/AppError construct 實際呼叫）：散在 auth/system_manage/enforce 後續 handler 刀，**不在本刀**（本刀只建型別＋8 建構子，不呼叫）。
- **每 route contract coverage gate**：後續 handler 刀（無 handler 可掛）。
- **⚠️r id 序列化 2^53 fail-loud 守衛＋lie ledger**：首個 DTO 刀（本刀 `data:T` generic、無具體 DTO 可守）。
- **demo 通道**（`status/message/result`）：永不實作（base-web app.d.ts:913-917、正式 API 不走）。
