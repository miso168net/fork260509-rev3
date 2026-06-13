# Feature Specification: envelope（統一回應信封＋13 碼矩陣＋集中錯誤映射）

**Feature Branch**: `003-envelope`

**Created**: 2026-06-13

**Status**: Draft

**Input**: User description: "docs/superpowers/003-envelope.md（波 0 第三刀 Phase 0 brainstorm：rev2 008 對應；`Res<T>{data,code,msg}`＋`BizCode` 13 碼矩陣＋`AppError` 集中映射；四項拍板〔刀範圍核心+PageRes／AppError 集中映射／thiserror／PageRes 納入〕＋⚠️e/⚠️f 凍結承接）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 統一回應信封形狀對齊前端 (Priority: P1) 🎯 MVP

後端每一個業務 API 回應都是同一個三欄信封 `{data, code, msg}`，序列化形**逐欄對齊** base-web 的消費期望：`code` 是字串（不是數字）、無 `success` 欄、欄序固定、成功 payload 在 `data`、無 payload 時 `data` 為 null、空集合序列化成 `[]`。分頁回應另以固定分頁殼承載於 `data`。前端不需任何容錯補丁即能正確判讀成功／失敗並取出 payload。

**Why this priority**: 信封形狀是所有後續 handler 刀的 wire 地基——先有「回應信封已是 wire 事實」的前提，後續 Auth／data island 刀才有意義地掛上業務碼。與 base-web typings 逐欄對齊是「契約靜默漂移／type-lie」的根本防線（前端 `code` 比對成功是字面字串比較，送錯型別即被判失敗）。

**Independent Test**: 對成功信封、錯誤信封、分頁信封各構造一筆，序列化後與凍結 wire 形逐 byte 比對，並對照 base-web `Service.Response` typings（`code:string`／`msg`／`data`）與成功碼 `"0000"`；含 `data:null`、空集合 `[]`、欄序三項邊界。零差異即過。

**Acceptance Scenarios**:

1. **Given** 一筆成功 payload，**When** 包成回應信封並序列化，**Then** 輸出恰為 `{"data":<payload>,"code":"0000","msg":"请求成功"}`——欄序 data→code→msg、`code` 帶引號的字串、無 `success` 欄。
2. **Given** 一筆無 payload 的成功或錯誤回應，**When** 序列化，**Then** `data` 欄出現且為 `null`（不被省略）。
3. **Given** 一筆分頁結果，**When** 包成分頁殼承載於信封的 `data`，**Then** 分頁殼為 `{current,size,total,records}`（camelCase、頁碼/大小/總數為數字、無 `pages`、無 `success`），空頁時 `records` 為 `[]` 不是 `null`。
4. **Given** base-web 攔截器以「`code` 字串等於成功碼」判讀成功，**When** 後端回成功信封，**Then** `code` 序列化為字串 `"0000"`、前端判為成功並取出 `data` 那一層。

---

### User Story 2 - 13 碼矩陣型別化單一真相 (Priority: P2)

系統把「13 碼業務碼矩陣」固化為**型別化的單一真相**：每個碼有固定的字串碼值、固定的預設訊息、固定的 HTTP status，逐碼對齊凍結矩陣；其中業務／授權碼一律走 HTTP 200 信封（僅「接口不存在」與「權限不足」兩格為非 200）；4 個保留碼是前端分組實值、**後端從不發出**。任何對矩陣的偏離（碼值錯、訊息錯、HTTP status 錯、發出保留碼）都被測試擋下。

**Why this priority**: 13 碼矩陣是凍結契約（⚠️f），前端 `.env` 分組行為依賴這些碼值；把矩陣收進單一真相讓契約測試鎖死、根除碼值漂移。依附 US1 的信封形狀（碼是信封的 `code` 欄內容）。

**Independent Test**: 以 table-driven 逐一掃過 13 個碼，斷言碼值字串／預設訊息／HTTP status 對齊凍結矩陣；另斷言「服务器内部错误」碼回 HTTP 200（非 500）、整組碼無任何回 HTTP 500、4 個保留碼無任何發出路徑。

**Acceptance Scenarios**:

1. **Given** 凍結矩陣（13 碼），**When** 對每個碼查碼值／預設訊息／HTTP status，**Then** 13/13 逐項對齊矩陣（碼值與訊息字串為 wire 事實、不可改）。
2. **Given** 「服务器内部错误」碼（5000），**When** 經回應落地，**Then** HTTP status 為 **200**（⚠️e）；且整組 13 碼中無任何碼落 HTTP 500。
3. **Given** 4 個保留碼（7778／8889／9998／9999），**When** 檢查後端是否有發出它們的路徑，**Then** 不存在任何發出路徑（後端永不發出、僅前端分組認得）。
4. **Given** 「接口不存在」（4040）與「權限不足」（5003），**When** 經回應落地，**Then** HTTP status 分別為 404 與 403（矩陣唯二非 200 例外）。

---

### User Story 3 - 集中錯誤映射人體學 (Priority: P3)

後端的錯誤回應經**單一集中機制**映射成信封：錯誤攜帶一個業務碼（＋可選的覆寫訊息），集中機制據此產出 `{data:null, code, msg}` 信封 body 並配上該碼的正確 HTTP status。未來 handler 刀因此能以「回傳錯誤型＋向上傳播」的人體學寫錯誤路徑，而不必每處手寫信封與 status。內部錯誤的細節僅供伺服器日誌、不洩漏給 client（client 看到的是該碼的預設訊息）。

**Why this priority**: 集中映射是 rev3 對前代「錯誤散在各呼叫點手寫」的改良；但本刀無 handler 消費者，價值在「機制就位、未來 handler 刀站上去」。依附 US2 的 HTTP status 單一真相。

**Independent Test**: 對每個可發出的錯誤碼，經集中機制產出回應，斷言 body 為對應信封形、HTTP status 為矩陣值；斷言保留碼無法經此機制構造；斷言內部錯誤的細節字串不出現在 client 可見的訊息中。

**Acceptance Scenarios**:

1. **Given** 一個攜帶業務碼的錯誤，**When** 經集中機制落地為回應，**Then** body 為 `{data:null, code:<碼值>, msg:<預設或覆寫訊息>}`、HTTP status 為該碼矩陣值。
2. **Given** 一個「服务器内部错误」並附帶內部細節字串，**When** 落地為回應，**Then** client 收到的 `msg` 為預設「服务器内部错误」、內部細節**不出現**在回應（僅供日誌）。
3. **Given** 保留碼（7778／8889／9998／9999），**When** 嘗試經集中錯誤機制構造，**Then** 不存在構造路徑（結構上無法發出）。
4. **Given** 一個泛型 payload 型別的端點在錯誤路徑，**When** 回錯誤信封，**Then** `data` 仍為 `null`、payload 型別僅為型別參數、不影響錯誤 body。

---

### Edge Cases

- **`code` 型別（type-lie 雷點）**：`code` 必須序列化成**字串** `"0000"`；若落成數字 `0`/`200`，前端字面字串比對會判為失敗——序列化必須帶引號的字串。
- **業務錯誤的 HTTP status**：業務／授權失敗（如登入失敗、業務拒絕、權杖過期）一律走 HTTP **200** 信封、靠 body 的 `code` 傳達，**不**用各碼「直覺上的」HTTP status；非 200 僅「接口不存在」（404）與「權限不足」（403）兩格。
- **空集合 vs null**：分頁空頁的 `records` 序列化成 `[]` 不是 `null`；無 payload 的 `data` 序列化成 `null` 不被省略——兩者語意不同、不可混。
- **內部細節洩漏**：內部錯誤攜帶的細節字串僅供日誌、**不得**進入 client 可見訊息。
- **保留碼誤發**：後端無任何路徑能發出 4 個保留碼——須為結構保證（型別系統強制），非靠紀律。
- **universal 例外端點**：基建端點（健康檢查）回 plain text、**不**走信封——信封是 universal 但有此明文例外，不可被「全部 API 都套信封」誤傷。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 提供統一回應信封，欄位恰為 `data`／`code`／`msg`，序列化欄序為 `data → code → msg`；**無 `success` 欄**；`code` 序列化為**字串**；無 payload 時 `data` 序列化為 `null`（不被省略）。
- **FR-002**: 系統 MUST 提供分頁殼，欄位恰為 `current`／`size`／`total`／`records`（camelCase、頁碼/大小/總數為數字、**無 `pages`**、**無 `success`**），承載於信封的 `data`；空頁時 `records` 為 `[]`（非 null）。
- **FR-003**: 信封序列化 MUST 逐欄對齊 base-web 消費權威（`Service.Response<T>` typings＝`{code:string, msg, data}`＋成功碼字串 `"0000"`）；前端不需容錯補丁即能判讀成功／失敗並取出 `data`。
- **FR-004**: 系統 MUST 以單一真相固化 13 碼矩陣，每碼有固定碼值字串、固定預設訊息、固定 HTTP status，逐碼對齊凍結矩陣（碼值與訊息字串為 wire 凍結事實、不可改）；矩陣見下方「Key Entities — 13 碼矩陣」。
- **FR-005**: HTTP status MUST 由 13 碼矩陣的單一真相決定：「服务器内部错误」（5000）一律 HTTP **200**（⚠️e）、整組碼無任何 HTTP 500；唯二非 200 例外為「接口不存在」（4040→404）與「權限不足」（5003→403）；其餘業務／授權碼一律 HTTP 200。
- **FR-006**: 錯誤回應 MUST 經單一集中機制映射為信封：攜帶一個業務碼（＋可選覆寫訊息）→ 產出 `{data:null, code, msg}` body ＋ 該碼 HTTP status；機制 MUST 支援「回傳錯誤型＋向上傳播」的錯誤人體學（供未來 handler 刀）。
- **FR-007**: 4 個保留碼（7778／8889／9998／9999）MUST 由結構（型別系統）強制「後端從不發出」——不存在任何經集中錯誤機制構造／發出保留碼的路徑；非靠紀律。
- **FR-008**: 內部錯誤攜帶的細節字串 MUST 僅供伺服器日誌、**不得**洩漏給 client；client 可見訊息為該碼的預設訊息。
- **FR-009**: 健康檢查端點 MUST 維持 plain text 回應、**不**走信封（universal 例外，不退化）。
- **FR-010**: 本刀 MUST NOT 含各碼的實際發出邏輯（散在後續 auth／handler／enforce 刀）、亦 MUST NOT 含 id 序列化的數值安全守衛（⚠️r、deferred 至首個 DTO 刀）——範圍僅信封／分頁殼／碼矩陣／集中錯誤機制／契約測試。
- **FR-011**: 信封落地 MUST NOT 引入新的建置單元（非新 workspace crate、屬既有後端服務內模組）；新增的序列化依賴 MUST NOT 破壞既有正式環境映像建置。

### Key Entities

| 實體 | 要點 |
|---|---|
| 回應信封 | 三欄 `{data, code, msg}`；欄序 data→code→msg；無 success；`code` 字串；`data` 可為 null（不省略） |
| 分頁殼 | `{current, size, total, records}`；camelCase；數字頁碼/大小/總數；無 pages/success；空頁 `records:[]`；承載於信封 `data` |
| 業務碼（13 碼矩陣，單一真相） | 每碼＝碼值字串＋預設訊息＋HTTP status（見下表） |
| 應用錯誤（集中映射） | 攜帶一個業務碼＋可選覆寫訊息；集中機制 → 信封 body＋HTTP status；保留碼無構造路徑 |

**13 碼矩陣（凍結；碼值與訊息字串為 wire 事實、HTTP status 為單一真相）：**

| 碼值 | 預設訊息（簡中） | HTTP status | 可發出? | 概念類別 |
|---|---|---|---|---|
| `0000` | 请求成功 | 200 | （成功路徑） | 成功 |
| `1000` | 用户名或密码错误 | 200 | ✅ | 登入失敗 |
| `2222` | 业务错误 | 200 | ✅ | 業務拒絕 |
| `3333` | 登录已过期 | 200 | ✅ | 權杖過期（前端 refresh） |
| `7777` | 账号在他处登录 | 200 | ✅ | modal 登出 |
| `7778` | 账号状态变更 | 200 | ❌ 保留 | modal 登出（前端分組） |
| `8888` | 请重新登录 | 200 | ✅ | 登出 |
| `8889` | 账号已被禁用 | 200 | ❌ 保留 | 登出（前端分組） |
| `9998` | 登录信息无效 | 200 | ❌ 保留 | 權杖過期（前端分組） |
| `9999` | 登录已过期 | 200 | ❌ 保留 | 權杖過期（前端分組） |
| `4040` | 接口不存在 | **404** | ✅ | 路由 fallback |
| `5003` | 权限不足 | **403** | ✅ | 授權拒絕 |
| `5000` | 服务器内部错误 | **200** | ✅ | 伺服器內部（⚠️e：200 非 500） |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 序列化 golden 100% 通過——成功信封、錯誤信封、分頁殼、`data:null`、空頁 `records:[]` 各案產出 byte-exact 的凍結 wire JSON（含欄序與 `code` 字串）。
- **SC-002**: 13 碼矩陣 table-driven 100% 對齊——13/13 碼的碼值／預設訊息／HTTP status 逐項符合凍結矩陣。
- **SC-003**: 「服务器内部错误」碼落 HTTP 200；整組 13 碼落 HTTP 500 的數量為 0（⚠️e 達成）。
- **SC-004**: 4 個保留碼的後端發出路徑數量為 0——結構（型別）驗證後端無法發出（⚠️f 達成）。
- **SC-005**: 前端對齊——成功碼序列化為字串 `"0000"`（非數字）、信封三欄為 `code`／`msg`／`data`，與 base-web `Service.Response` typings 一致；前端成功判讀無需容錯補丁。
- **SC-006**: 加入序列化依賴後建置成功；後端服務的正式環境映像建置不退化。
- **SC-007**: 健康檢查端點維持 plain text「ok」回應、不走信封（universal 例外不退化）。
- **SC-008**: 內部錯誤的細節字串在 client 可見回應中出現次數為 0（僅進日誌）。

## Assumptions

- base-web wire 消費形為對齊權威（`Service.Response<T>={code:string,msg,data}`＋成功碼 `"0000"`、攔截器以字串比對判成功）——B1 已四向交叉驗證（typings／攔截器／mock／.env 一致）。
- 前代（rev2 008）的信封實作為受控參照（讀允許、拷貝禁止——信封屬全新寫、不在拷貝例外清單）；13 碼的碼值與訊息字串逐字對齊凍結矩陣。
- 凍結權威 ⚠️e（5000→HTTP 200）、⚠️f（13 碼整組凍結含 4 保留碼）、constitution §I.3（wire 不變式）為不可違反邊界；本 spec 與三者一致（衝突以 DECISIONS §1 ＞ DESIGN ＞ 本 spec 為序）。
- 各碼的實際發出點（散在 auth／system_manage／enforce 等後續 handler 刀）與每 route 必有 contract case 的 coverage gate 不在本刀；id 序列化 2^53 數值安全守衛（⚠️r）deferred 至首個 DTO 刀。
- 信封屬既有後端服務內模組、非新建置單元；現況後端服務為極簡 scaffold（僅健康檢查端點、零既有回應／錯誤型），信封為其首個回應契約。
- demo 通道（前端 starter 內建的另一種回應形）不在本刀——正式 API 不走此通道、後端不實作。
- 驗收以可獨立測的純函式／序列化契約測試為主（test-first TDD 適用，與前一刀「無純函式測試、靠實機」相反）。
