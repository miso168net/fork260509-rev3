# Research: 003-envelope（Phase 0）

**Date**: 2026-06-13 ｜ **Input**: spec.md＋brainstorm `docs/superpowers/003-envelope.md`（B1 四向蒐集）＋plan 期實 grep（R1 rev2 源碼／R2 base-web typings）

## R1 · rev2 008 參考形實 grep（受控參照、讀允許拷貝禁止——不信 brainstorm 假設）

- **`Res<T>`**（`fork260509-rev2/rust-api/server/src/envelope.rs:19-25`）：`{ data: Option<T>, code: String, msg: String }`；宣告序＝序列化序 data→code→msg；無 `success`；`code` String（非數字）；`data:None`→`"data":null` 不 skip（無 `skip_serializing_if`）。建構子 ok/ok_msg/err/err_msg（err/err_msg `impl<T>` 泛型化、任何 `Res<T>` 都能回 error body）。`IntoResponse for Res<T>` 強制 HTTP 200。
- **`PageRes<T>`**（envelope.rs:79-88）：`{current,size,total,records}`、`#[serde(rename_all="camelCase")]`、u64 數字、無 `pages`/`success`、空頁 `records:[]`。
- **`BizCode` 13 碼**（envelope.rs:93-142；`code()` :110-126、`default_msg()` :128-144）——**逐字鎖定凍結矩陣**：
  | variant | code | default_msg |
  |---|---|---|
  | Success | `0000` | 请求成功 |
  | LoginFailed | `1000` | 用户名或密码错误 |
  | BizError | `2222` | 业务错误 |
  | TokenExpired | `3333` | 登录已过期 |
  | TokenInvalid9998 | `9998` | 登录信息无效 |
  | TokenExpiredAlt9999 | `9999` | 登录已过期 |
  | ModalLogout7777 | `7777` | 账号在他处登录 |
  | ModalLogout7778 | `7778` | 账号状态变更 |
  | Logout8888 | `8888` | 请重新登录 |
  | Logout8889 | `8889` | 账号已被禁用 |
  | NotFound | `4040` | 接口不存在 |
  | PermissionDenied | `5003` | 权限不足 |
  | Internal | `5000` | 服务器内部错误 |
  - rev2 的 `BizCode` **無 `http_status()` 方法**（status 散在 AppError match／enforce tuple）——rev3 改良新增此方法為單一真相（R4）。
- **`AppError`**（`error.rs:15-34`）：`enum { NotFound, Internal(String) }`；`Internal` 標 `#[allow(dead_code)]`「test-only producer」；`envelope(status, code)` helper（:25）以 `(status, Json(Res::err(code)))` 覆寫 200；`IntoResponse`：NotFound→`(404, BizCode::NotFound)`、Internal→`(500, BizCode::Internal)`。client msg 來自 `BizCode::default_msg()` **不洩漏內部字串**（error.rs:69 註解＋單測）。**只 router fallback 用一次**。
- **Decision**：rev3 逐字沿用 13 碼 code/msg 字串；`Res<T>`/`PageRes<T>` 序列化形照拷契約（非照拷碼）；`AppError` 改良為集中映射（R4）。**Rationale**：碼值與 msg 字串為 wire 凍結事實（⚠️f）、逐字對齊；序列化形是 base-web 對齊面。

## R2 · base-web wire 對齊 grep（§I.3 唯一權威）

- **typings**（`base-web/src/typings/app.d.ts:901-907`）：`Service.Response<T> = { code: string; msg: string; data: T }`——`code` **string**（非 number）、`msg`（非 message）、`data` 承載 payload。
- **成功碼**（`base-web/.env:32`）：`VITE_SERVICE_SUCCESS_CODE=0000`；攔截器 `isBackendSuccess`＝`String(response.data.code) === "0000"`（字面字串比對）。
- **demo 通道**（app.d.ts:913-917）：`{ status, message, result }`——**正式 API 不走、本刀不實作**（R5）。
- **Decision**：rev3 `Res<T>` 序列化必須 `code` 字串 `"0000"`、欄名 `code`/`msg`/`data`——逐欄對齊 typings。**Rationale**：§I.3 base-web 實碼為 wire 唯一權威；type-lie 雷點＝`code` 送 number 會被前端判失敗。

## R3 · 依賴增量

- **新增**：workspace `serde = { version = "1", features = ["derive"] }`＋`serde_json = "1"`＋`thiserror = "2"`（或 1，plan 期裁；`AppError` Display）；server crate 加這三個＋axum 改 `features = ["json"]`（0.7 `Json` 需 json feature、現宣告無 features）。
- **義務**：`cargo build --bins` 綠＝最小依賴足以序列化／json 回應；確認不引入非預期重依賴（serde/serde_json 為純序列化、無 time/重 runtime 顧慮，與 002 sea-orm 的 time 根因無關）。
- **dev-dependencies**：序列化 golden 需 `serde_json::to_string`（runtime dep 已含）；無額外 dev-dep。

## R4 · AppError 集中映射設計（rev3 改良；⚠️e 逆紋的解）

- **Decision**：`BizCode` 新增 `http_status()` 方法為 status 單一真相（矩陣三欄全收 BizCode）：Internal→**200**（⚠️e、無 500）、NotFound→404、PermissionDenied→403、其餘→200。`AppError { code: BizCode, msg: Option<String> }`（`code` 私有）；集中 `IntoResponse`＝`(code.http_status(), Json(error 信封 body))`，body 由 `Res::err`/`err_msg` 構造。handler（後續刀）回 `Result<Res<T>, AppError>` 用 `?`。
- **⚠️f 結構保證**：`AppError` 對 8 可發出 error 碼提供公開建構子（LoginFailed/BizError/TokenExpired/ModalLogout7777/Logout8888/NotFound/PermissionDenied/Internal），4 保留碼（7778/8889/9998/9999）**無建構子**；`code` 私有 → 結構上不可發出保留碼。
- **Rationale**：集中映射＝rev3 對 rev2「status 散在呼叫點手寫」的改良；`http_status()` 表把 Internal 鎖 200（⚠️e）、rev2 test-only 500 在集中模型不存在（無死碼）。**Alternatives**：①rev2 瘦身忠實（被否：放棄 `?` 人體學）②enum-of-8-variant（被否：失去 `code.http_status()` 的 DRY 集中映射；struct+私有欄+受限建構子已足夠保證 ⚠️f）。

## R5 · CLAUDE.md §3 Phase 0 三 grep 紀律適用性

| 紀律 | 本刀 |
|---|---|
| ① facade 真實返回型 grep | **N/A**——無業務 endpoint／facade |
| ② wire 鏈 3 端對齊 grep | **部分適用**——envelope 無新 wire endpoint（是外殼非 endpoint），但 R2 已 grep base-web `Service.Response` typings（code:string/msg/data）＋成功碼為對齊目標；3 端中 frontend typings 端已鎖、後端為本刀產出、無中間 component state |
| ③ data-model file:line 對照 | **已執行**——R1 rev2 envelope.rs/error.rs 逐行座標＋R2 base-web app.d.ts:901-907，data-model.md 引用 |

## R6 · contract test 策略（test-first TDD）

- **序列化 golden**（envelope.rs inline `#[cfg(test)]`、rev2 同形）：`Res::ok(42)`→`{"data":42,"code":"0000","msg":"请求成功"}`；error 信封；`PageRes` camelCase；`data:null`；空頁 `records:[]`——逐 byte（serde_json::to_string）。
- **13 碼 table-driven 矩陣**：`[(BizCode, code_str, msg_str, http_status)]` 13 列掃描斷言（rev2 envelope.rs:266+ 同形 table 形）。
- **⚠️e 鎖定**：`BizCode::Internal.http_status()==200`、全 13 碼無 500。
- **⚠️f 鎖定**：`AppError` 無公開路徑構造保留碼（建構子集 ⊆ 8 可發出碼；可用「保留碼無建構子」編譯期保證＋測試斷言可發出集大小）。
- **AppError 映射**（error.rs inline）：每可發出碼 → `IntoResponse` 的 (status, body) 對矩陣；Internal 內部字串不入 client body。
- **Decision**：test-first（先寫上述測試＝red、再實作＝green）；envelope 全純函式／序列化、無實機需求（與 002 相反）。NEEDS CLARIFICATION＝0。

## 移交 tasks 期紀律

- 各碼**發出點**（Res::err/AppError construct 實際呼叫）散在 auth/system_manage/enforce 後續刀；每 route 必有 contract case 的 coverage gate 同——**登 CHECKLIST follow-up、不在本刀**。
- ⚠️r id 序列化 2^53 fail-loud 守衛＋lie ledger → 首個 DTO 刀（data:T generic、本刀無 DTO）。
