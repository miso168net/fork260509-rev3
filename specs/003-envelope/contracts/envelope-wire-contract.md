# Contract: envelope-wire-contract（凍結 wire 形；contract test 權威）

> 序列化 golden 逐 byte 期望＋13 碼 table-driven 權威＋AppError 映射。test-first：先寫本契約對應測試（red）、再實作（green）。golden 字串與 13 碼 code/msg 為 wire 凍結事實（⚠️e/⚠️f／§I.3），紅了校實作、**不調 golden 遷就實作**。

## 1. 序列化 golden（`serde_json::to_string` 逐 byte）

| 案 | 輸入 | 期望 JSON |
|---|---|---|
| 成功有 payload | `Res::ok(42i32)` | `{"data":42,"code":"0000","msg":"请求成功"}` |
| 成功自訂 msg | `Res::ok_msg(true, "x")` | `{"data":true,"code":"0000","msg":"x"}` |
| 錯誤信封 | `Res::<()>::err(BizCode::LoginFailed)` | `{"data":null,"code":"1000","msg":"用户名或密码错误"}` |
| 錯誤自訂 msg | `Res::<()>::err_msg(BizCode::Internal, "boom")` | `{"data":null,"code":"5000","msg":"boom"}` |
| 錯誤泛型 T | `Res::<SomePayload>::err(BizCode::TokenExpired)` | `{"data":null,"code":"3333","msg":"登录已过期"}`（data:null、T 僅型別參數） |
| 分頁殼 | `PageRes{current:1,size:10,total:0,records:Vec::<i32>::new()}` | `{"current":1,"size":10,"total":0,"records":[]}`（camelCase、數字、空 `[]`） |
| 分頁承載 | `Res::ok(PageRes{...})` | `{"data":{"current":...,"records":[...]},"code":"0000","msg":"请求成功"}` |

**硬約束**：欄序 data→code→msg（Res）／current→size→total→records（PageRes）；`code` 帶引號字串；**無 `success`**（斷言序列化字串不含 `"success"`）；`data:null` 不省略；空集合 `[]` 非 `null`。

## 2. 13 碼 table-driven 矩陣（權威；逐碼斷言）

```
[(variant, code(), default_msg(), http_status())] × 13：
 Success            "0000" "请求成功"            200
 LoginFailed        "1000" "用户名或密码错误"     200
 BizError           "2222" "业务错误"            200
 TokenExpired       "3333" "登录已过期"          200
 ModalLogout7777    "7777" "账号在他处登录"       200
 ModalLogout7778    "7778" "账号状态变更"        200   ← 保留
 Logout8888         "8888" "请重新登录"          200
 Logout8889         "8889" "账号已被禁用"        200   ← 保留
 TokenInvalid9998   "9998" "登录信息无效"        200   ← 保留
 TokenExpiredAlt9999"9999" "登录已过期"          200   ← 保留
 NotFound           "4040" "接口不存在"          404
 PermissionDenied   "5003" "权限不足"            403
 Internal           "5000" "服务器内部错误"       200   ← ⚠️e（非 500）
```

**斷言**：13/13 逐碼 code/msg/http_status 對齊上表；`Internal.http_status()==200`；`count(http_status==500)==0`（⚠️e）。

## 3. AppError → (HTTP status, 信封 body) 映射

| AppError 建構子 | code | HTTP status | body |
|---|---|---|---|
| `not_found()` | 4040 | 404 | `{"data":null,"code":"4040","msg":"接口不存在"}` |
| `permission_denied()` | 5003 | 403 | `{"data":null,"code":"5003","msg":"权限不足"}` |
| `internal(detail)` | 5000 | **200** | `{"data":null,"code":"5000","msg":"服务器内部错误"}`（detail **不**入 body、僅 log） |
| `login_failed()` | 1000 | 200 | `{"data":null,"code":"1000","msg":"用户名或密码错误"}` |
| `biz(msg)` | 2222 | 200 | `{"data":null,"code":"2222","msg":<msg>}` |
| `token_expired()` | 3333 | 200 | … |
| `modal_logout()` | 7777 | 200 | … |
| `logout()` | 8888 | 200 | … |

**斷言**：①每建構子 `into_response()` 的 `.status()` 與 body 對上表②`internal("boom")` 的 body msg＝「服务器内部错误」、不含「boom」（內部不洩漏）。

## 4. ⚠️f 結構保證斷言

- `AppError` **無**建構子產出 7778/8889/9998/9999（編譯期：無對應建構子；測試期：可發出碼集合大小＝8、且皆 ≠ 保留碼）。
- `code` 欄私有 → 模組外無路徑構造任意 BizCode 的 AppError。

## 5. universal 例外

- `/health` 維持 `async fn health() -> &'static str { "ok" }`、回 plain text、**不**走信封——契約斷言 health 回應不是 JSON 信封形（本刀不改 health、僅確認不退化）。
