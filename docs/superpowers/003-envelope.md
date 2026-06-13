# 003-envelope — Phase 0 Brainstorm（spec-design）

> 波 0 第三刀（001 infra-deploy → 002 rev2-schema-baseline → **003 envelope**）。
> 對應 rev2 008「統一回應信封」。本檔為 brainstorm 定稿的 spec-design，作為 `/speckit-specify` 的 input。
> **凍結權威**：⚠️e（5000→HTTP 200）、⚠️f（13 碼矩陣整組凍結）已決於 DECISIONS §1；DESIGN §5.4／§7.3 為設計本體；constitution §I.3 為 wire 不變式。本檔不得與三者衝突（衝突以 DECISIONS §1＞DESIGN＞本檔為序）。

---

## 1. 目標一句話

把後端統一回應信封 `Res<T>{data,code,msg}` ＋ 13 碼 `BizCode` 矩陣 ＋ 集中映射的 `AppError` 一次建成型別骨架，序列化逐欄對齊 base-web wire 期望，contract 形狀測試鎖死凍結矩陣——讓後續所有 handler 刀都站在「回應信封已是 wire 事實」的前提上。

## 2. Context（B1 蒐集，四向交叉驗證）

### 2.1 rev2 008 參考形（受控參照重寫、非照拷）
- `Res<T>{data: Option<T>, code: String, msg: String}`：宣告序＝序列化序（data→code→msg）、**無 `success`** 欄、`code` 永遠 JSON 字串（`"0000"`）、錯誤 `data:null` 不 skip。`IntoResponse` 永遠 HTTP 200（非 200 須 tuple 覆寫）。建構子 `ok`/`ok_msg`/`err`/`err_msg`。
- `BizCode` 13 碼：`code()`＋`default_msg()`；**BizCode 本身不持 HTTP status**，status↔code 配對散在呼叫點（AppError match／enforce tuple）。
- `AppError` 終態極瘦（2 variant：NotFound→404、Internal(String)→500 標 dead/test-only）；**只 router fallback 用一次**，業務錯誤全走 handler 裸回 `Res::err(BizCode)`→HTTP 200。
- `PageRes<T>{current,size,total,records}`（016 引入、同住 envelope.rs）：camelCase、u64 數字、無 `pages`/`success`、空頁 `records:[]`。

### 2.2 凍結權威
- **⚠️e**（DECISIONS §1）：`5000` 一律 HTTP 200 信封；`AppError::Internal`→HTTP 500 mapping 標 test-only 或刪除；contract test 鎖 `5000`→200。理由：base-web envelope msg 顯示通道僅 HTTP 200 業務失敗時生效。
- **⚠️f**（DECISIONS §1）：13 碼矩陣整組凍結（含 4 保留碼 7778/8889/9998/9999）；保留碼是前端 `.env` 分組實值、刪碼違 §I.1；contract test 斷言「後端從不發出保留碼」。
- **constitution §I.3**（wire 鎖定不變式）：envelope `{data,code,msg}` 無 success、code=string「0000」not number、business error 走 HTTP 200；13 碼整組凍結、HTTP 例外僅 4040→404/5003→403、5000→200；PageRes 形；universal 例外僅 `/health`（plain text）與 `/metrics`（Prometheus）。

### 2.3 rust-api 現況＝白紙
- `server/src/` 只有 `main.rs`（63 行 flat-in-main、唯一 handler `/health`）；**零 error/response 型**、零 `IntoResponse`。
- 缺 `serde`/`serde_json`/`thiserror`；axum 0.7 的 `json` feature 未啟。
- envelope 落點＝**server crate 內 module（`envelope.rs`＋`error.rs`）、非新 crate**（DESIGN §1.5 L1 側軌、§7.3 as-built 錨 `server/src/envelope.rs`；⚠️v sub-crate 消解精神）。
- `/health` = `async fn health() -> &'static str { "ok" }`，universal 例外、**不動**。

### 2.4 base-web wire 權威（必須對齊）
- typings `Service.Response<T> = { code: string; msg: string; data: T }`（app.d.ts:900-908）。
- 攔截器 `isBackendSuccess`：`String(response.data.code) === VITE_SERVICE_SUCCESS_CODE`（`"0000"`）；失敗依 `code` 分流（`.env`：logout 8888/8889、modalLogout 7777/7778、expiredToken 9999/9998/3333）；錯誤 msg 取 `data.msg` toast。
- **type-lie 雷點**：`code` 必須序列化成**字串** `"0000"`，送 number `0`/`200` 會被判失敗。
- demo 通道（`status/message/result`）為 soybean starter 內建、**正式 API 不走、本刀不實作**。

## 3. Scope（B2 拍板）

**核心 + PageRes<T>（本刀做）：**
- `Res<T>`（ok/ok_msg ＋序列化契約）＋`PageRes<T>` ＋ `BizCode`（13 變體＋三方法）＋ `AppError`（集中映射）＋ 依賴/接線 ＋ contract 形狀測試（test-first TDD）。

**Deferred（不在本刀）：**
- ⚠️r id 序列化 2^53 fail-loud 守衛＋lie ledger — **defer 到首個 DTO 刀**（本刀 `data:T` 是 generic、無具體 DTO 可守）。
- 各碼**發出點**（`Res::err`/AppError construct 的實際呼叫）散在 auth/system_manage/enforce 等**後續 handler 刀**；每 route 必有 contract case 的 coverage gate 同。

## 4. 四項 brainstorm 拍板

| # | 決策 | 結論 |
|---|---|---|
| B2 刀範圍 | 核心 vs +PageRes vs +⚠️r 守衛 | **核心 + PageRes<T>**；⚠️r 守衛 defer |
| B3 **AppError 模型** | 瘦身忠實（rev2 複製）vs **rev3 改良集中映射** vs 瘦身+擴展縫 | **rev3 改良：集中映射**（user 選；與凍結逆紋的張力以 `BizCode::http_status()` 單一真相解、見 §5.2） |
| thiserror | 用 vs 手寫 | **用 thiserror**（rev2 同形、Display 供 log、一致性） |
| PageRes | 納本刀 vs defer | **納本刀**（凍結型、零下游依賴） |

## 5. Design（兩段逐段 user 核可）

### 5.1 架構與檔案
- `server/src/envelope.rs` — `Res<T>` ＋ `PageRes<T>` ＋ `BizCode`（13 變體＋ `code()`/`default_msg()`/`http_status()`）。
- `server/src/error.rs` — `AppError` ＋ 集中 `IntoResponse`。
- `main.rs` 加 `mod envelope; mod error;`（首次 `mod` 引入、純加法）；`/health` 不動。

### 5.2 AppError 集中映射模型（rev3 改良；張力的解）
**核心解法**：把「13 碼矩陣的 HTTP status 欄」收進 **`BizCode::http_status()` 單一真相**（rev3 vs rev2「status 散在呼叫點」的差異點）。`AppError` 攜帶一個 `BizCode` ＋ 可選覆寫 msg；集中 `IntoResponse` 一處用 `http_status()` 表驅動：
```
AppError { code: BizCode, msg: Option<String> }   // code 欄私有
impl IntoResponse for AppError:
    (self.code.http_status(), Json(<error 信封 {data:null, code: code(), msg: msg or default_msg()}>))
```
- handler（後續刀）回 `Result<Res<T>, AppError>`、用 `?` 傳播 → 這是改良要的人體學。
- **⚠️e 消解**：`BizCode::Internal.http_status() == 200`（不是 500）；rev2 那條 test-only 500 在集中模型裡**根本不存在**（無死碼、更乾淨）。非 200 只剩 `http_status()` 表的 `4040→404`、`5003→403` 兩格。

### 5.3 序列化契約（凍結 wire 事實、不可改）
- `Res<T>`：欄序 `data→code→msg`；`code` 字串；無 `success`；`data:None`→`"data":null`（不 skip_serializing_if）；`Res::ok(42i32)` → `{"data":42,"code":"0000","msg":"请求成功"}`。
- **`Res` 建構子四件**（envelope-shape 單一真相）：成功 `ok`/`ok_msg`（code 固定 `"0000"`）；error-envelope `err(BizCode)`/`err_msg(BizCode, msg)`（產 `{data:null, code, msg or default_msg}`）。**分工**：error-envelope 的 body 由 `Res::err`/`err_msg` 構造，HTTP status 由 `AppError::IntoResponse` 套 `http_status()`——即 `AppError::IntoResponse` 內部呼叫 `Res::err`／`err_msg` 組 body、再配 status。handler（後續刀）**回 `AppError` 用 `?`、不直接呼叫 `Res::err`**（`Res::err` 是 AppError 的內部 body builder、亦供 router fallback 等少數直建處）。`Res::err`/`err_msg` 泛型化 `impl<T>`（任何 `Res<T>` 都能回 error body、`data` 仍 null、T 只是型別參數）。
- `PageRes<T>`：`{current,size,total,records}`、`rename_all="camelCase"`、u64 數字、無 `pages`/`success`、空頁 `records:[]`；作為 `Res<T>` 的 `data` 攜帶。

### 5.4 BizCode 13 碼矩陣（逐碼凍結；code/msg 簡中字串為 wire 事實、`http_status()` 為本刀新增單一真相）

| # | variant | `code()` | `default_msg()` | `http_status()` | 發出（後續刀） | base-web `.env` 分組 | 可發出? |
|---|---|---|---|---|---|---|---|
| 1 | `Success` | `0000` | 请求成功 | 200 | 全 success（Res::ok 路徑） | SUCCESS_CODE | （success，非 error） |
| 2 | `LoginFailed` | `1000` | 用户名或密码错误 | 200 | auth 刀 | 顯示錯誤 | ✅ |
| 3 | `BizError` | `2222` | 业务错误 | 200 | 業務拒絕（種子保護/治理 Rejected） | 顯示錯誤 | ✅ |
| 4 | `TokenExpired` | `3333` | 登录已过期 | 200 | enforce/auth | EXPIRED→refresh | ✅ |
| 5 | `ModalLogout7777` | `7777` | 账号在他处登录 | 200 | single-session gate | MODAL_LOGOUT | ✅ |
| 6 | `ModalLogout7778` | `7778` | 账号状态变更 | 200 | **零發出** | MODAL_LOGOUT | ❌ 保留 |
| 7 | `Logout8888` | `8888` | 请重新登录 | 200 | refresh reuse/notfound | LOGOUT | ✅ |
| 8 | `Logout8889` | `8889` | 账号已被禁用 | 200 | **零發出** | LOGOUT | ❌ 保留 |
| 9 | `TokenInvalid9998` | `9998` | 登录信息无效 | 200 | **零發出** | EXPIRED | ❌ 保留 |
| 10 | `TokenExpiredAlt9999` | `9999` | 登录已过期 | 200 | **零發出** | EXPIRED | ❌ 保留 |
| 11 | `NotFound` | `4040` | 接口不存在 | **404** | router fallback | — | ✅ |
| 12 | `PermissionDenied` | `5003` | 权限不足 | **403** | enforce_mw deny | axios 泛錯 toast | ✅ |
| 13 | `Internal` | `5000` | 服务器内部错误 | **200** | handler DB/簽章失敗 | 顯示錯誤 | ✅ |

> variant 命名沿 rev2 enum（⚠️k 風格）。`Internal` 攜帶內部細節字串只進 thiserror Display（log），client 看到的 msg 來自 `default_msg()`、**不洩漏內部**。

### 5.5 ⚠️f 結構保證（型別系統強制「後端從不發出保留碼」）
- `BizCode` enum 含**全 13**（矩陣完整＋對齊 base-web `.env`）。
- `AppError` 對 **8 個可發出 error 碼提供公開建構子**（LoginFailed/BizError/TokenExpired/ModalLogout7777/Logout8888/NotFound/PermissionDenied/Internal），**4 保留碼（7778/8889/9998/9999）無建構子**；`code` 欄私有。
- ⇒ 結構上不可能經 `AppError` 發出保留碼，「後端從不發出」由型別系統保證、非靠紀律。（`Success` 走 `Res::ok`、不在 AppError。）

### 5.6 contract test 策略（test-first TDD；envelope 全是可獨立測純函式/序列化）
- **序列化 golden 單測**：`Res::ok`、error 信封、`PageRes`、`data:null`、空 `records:[]` 逐 byte 斷言。
- **table-driven 矩陣測**：掃 13 BizCode 斷言 `code()`/`default_msg()`/`http_status()` 對齊 §5.4 凍結表。
- **⚠️e 鎖定**：`BizCode::Internal.http_status()==200`、全 enum 無任何 →500。
- **⚠️f 鎖定**：斷言 `AppError` 無公開路徑構造出保留碼（建構子集 ⊆ 8 可發出碼）。
- **發出點 coverage gate**（每 route 必有 case）＝後續 handler 刀的事、登 backlog、本刀無 handler 可掛。

### 5.7 依賴與接線
- workspace deps 加 `serde`(derive)＋`serde_json`；server crate 加這兩個＋axum 改 `features=["json"]`；`AppError` Display 用 `thiserror`。
- **非新 crate** → CLAUDE.md §3「新 workspace crate ⇒ acceptance 必含 prod build」紀律**不觸發**；spec 仍確認 prod Dockerfile build server crate 不受影響（serde/json feature 加入不破壞 multi-stage）。

## 6. Out of scope / Deferred / Backlog

- **⚠️r id 2^53 fail-loud 守衛 ＋ lie ledger** → 首個 DTO 刀（CHECKLIST follow-up 登記）。
- **各碼發出點** ＋ **每 route contract coverage gate** → auth/system_manage/enforce 等後續 handler 刀。
- **demo 通道**（status/message/result）→ 永不實作（soybean starter 內建、正式 API 不走）。

## 7. 驗收方向（交 /speckit-specify 形式化）

- SC：序列化 golden 全綠（Res::ok/error/PageRes/null/空頁逐 byte）。
- SC：13 碼矩陣 table-driven 全綠（code/msg/http_status 對齊 §5.4）。
- SC：⚠️e — `Internal.http_status()==200`、全 enum 無 →500。
- SC：⚠️f — AppError 無保留碼建構子（結構斷言）。
- SC：`cargo build` 綠（serde/json feature 加入後）＋prod Dockerfile build server crate 不退化。
- SC：`/health` 維持 plain text、不走信封（universal 例外不退化）。

## 8. Phase 0 research 待辦（交 /speckit-plan 期 research.md；CLAUDE.md §3 三 grep 紀律）

- **wire 3 端對齊 grep**：本刀無新 wire endpoint（envelope 是外殼、非 endpoint），但須複驗 base-web `Service.Response` typings 形（code:string/msg/data）與 `.env` 成功碼 `0000` 為對齊目標（B1 已驗、plan 期 grep 留痕）。
- **rev2 源碼受控參照 grep**：`envelope.rs`/`error.rs` 的 `Res<T>`/`BizCode`/`AppError` 真實形（讀允許、拷貝禁止——envelope 不在 §I.5 拷貝例外、屬全新寫）；13 碼 code/msg 字串逐字對齊凍結矩陣。
- **依賴增量複驗**：加 serde/serde_json 後 `cargo build` 綠；確認不引入非預期重依賴。

---

**brainstorm 定稿 2026-06-13；四項拍板（刀範圍核心+PageRes／AppError 集中映射／thiserror 用／PageRes 納入）＋⚠️e/⚠️f 凍結承接。下一步：手動 `/speckit-specify`（input＝本檔）。**
