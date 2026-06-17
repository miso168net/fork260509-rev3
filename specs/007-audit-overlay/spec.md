# Feature Specification: Audit Overlay（login-attempt＋access-log＋真實 client IP＋region）

**Feature Branch**: `007-audit-overlay`

**Created**: 2026-06-17

**Status**: Draft

**Input**: User description: "`docs/superpowers/007-audit-overlay.md`（波 0 第七刀〔末〕Phase 0 brainstorm：audit overlay＝access-log＋login-attempt 兩 append-only sink＋全域 audit 上下文中介層〔operator/trace/真實 client IP/region〕＋xdb（IP→region）＋app-side XFF trusted-proxy 真實 client IP 解析；既有 operation-log 取得 operator/operator-IP/trace 歸屬 seam。對應前代 015。借前代 v2 設計、對齊當前 lineage：INET 地基〔entity Model／with-ipnetwork／operator_ip 已 INET〕已由 004/005 落地→本刀零 migration/entity/型遷移。client IP 改自 forwarded 鏈 trusted-proxy 解析＝推進凍結 DESIGN §5.9。完整 lockout＝波3、audit 讀端/UI＝波2、retention＝波4。)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 登入事件稽核軌（含真實來源 IP）(Priority: P1) 🎯 MVP

安全/稽核人員要能事後查到「每一次登入嘗試」——不論成功或失敗——是誰（嘗試的帳號）、何時、從哪個**真實**來源 IP、哪個地區發出的。每個登入的終端結果都恰好留下一筆紀錄；失敗的紀錄也帶來源 IP（供日後鎖定濫用來源）。

**Why this priority**: 登入是最安全敏感的事件面；沒有登入嘗試稽核，就無從察覺暴力破解／異常來源，後續「登入鎖定」也沒有資料可消費。它是本刀稽核價值的最小可交付核心，且可獨立先行。

**Independent Test**: 對既有種子帳號送一次錯密碼登入＋一次正確登入（`Super`/`123456`），檢查系統留下**恰兩筆**登入嘗試紀錄——失敗筆 outcome=失敗、帶來源 IP、無已確認操作者；成功筆 outcome=成功、帶操作者與來源 IP；皆含時間、地區、關聯 id。

**Acceptance Scenarios**:

1. **Given** 錯誤密碼的登入請求，**When** 送出，**Then** 留下一筆登入嘗試紀錄（嘗試帳號、outcome=失敗、真實來源 IP、原始 forwarded 鏈、地區、關聯 id、時間），且不洩漏該失敗如何影響登入回應（登入回應行為與既有一致）。
2. **Given** 正確帳密的登入請求，**When** 送出，**Then** 留下一筆登入嘗試紀錄（outcome=成功、含已確認操作者與真實來源 IP）。
3. **Given** 登入流程中任一終端失敗路徑（帳號不存在／密碼錯／角色查詢失敗／憑證簽發失敗／會話寫入失敗），**When** 發生，**Then** 該路徑**恰**留下一筆登入嘗試紀錄（不重不漏）。
4. **Given** 稽核紀錄寫入時後端儲存暫時失敗，**When** 登入處理進行，**Then** 登入本身的成敗**不受影響**（稽核寫入為盡力而為、絕不擋業務）。

---

### User Story 2 - 已認證請求稽核軌 (Priority: P2)

稽核人員要能查到「誰、在何時、從哪個來源、對哪個受保護資源、做了什麼動作、結果如何」。每個**已認證**的請求恰好留下一筆存取紀錄；未認證請求（無／無效／過期憑證、登入、健康探針、公開路徑）**不**落列（單一操作者門檻、無路徑排除清單）。

**Why this priority**: 提供受保護資源的操作者問責軌；建立在 US1 與「真實來源 IP」之上。P2：登入稽核（US1）可獨立先交付價值，存取稽核緊接其後。

**Independent Test**: 以有效憑證呼叫身分資訊端點 → 留下一筆存取紀錄（操作者、方法、路徑、結果狀態、真實來源 IP、地區、關聯 id、時間）；不帶憑證呼叫同端點、呼叫健康探針、呼叫登入 → 皆**不**留存取紀錄。

**Acceptance Scenarios**:

1. **Given** 有效憑證的受保護請求，**When** 送出，**Then** 留下一筆存取紀錄、含操作者與真實來源 IP/地區/結果狀態。
2. **Given** 未帶／無效／過期憑證的請求（含登入、健康探針、公開路徑），**When** 送出，**Then** **不**留存取紀錄（但登入仍依 US1 留登入嘗試紀錄）。

---

### User Story 3 - 反代後方的可信來源 IP（防偽造）(Priority: P2)

系統位於反向代理（可能含多層 CDN/proxy）後方時，稽核與來源 IP 必須記到**真實 client**、而非代理的 IP；且**不可信任**來自未授信來源的 forwarded 標頭——否則攻擊者可偽造來源、規避日後鎖定、嫁禍他人 IP、污染稽核。

**Why this priority**: 這是 US1/US2 來源 IP「可信」的前提；獨立成則因它有自己的對抗式驗收（偽造防護、fail-safe）。P2：與 US1/US2 緊耦合但可獨立驗證其正確性。

**Independent Test**: 設定可信代理集合後，經可信代理鏈（帶 forwarded 標頭）送請求 → 記到的是真實 client（跳過代理 hop）；自不可信直連來源帶偽造 forwarded → 偽造被忽略、記直連位址；可信集合未設或直連來源不可信 → fail-safe 記直連位址。

**Acceptance Scenarios**:

1. **Given** 已設定可信代理集合，**When** 請求經該可信代理鏈（forwarded 含真實 client＋代理 hop），**Then** 記到的來源 IP＝真實 client（自右向左跳過可信 hop、取第一個不可信者）。
2. **Given** 直連來源**不在**可信集合，**When** 請求帶偽造 forwarded，**Then** 忽略 forwarded、記直連位址（防偽造）。
3. **Given** 可信集合未設定，或 forwarded 全為可信 hop／無 forwarded，**When** 請求送達，**Then** fail-safe 記直連位址。
4. **Given** forwarded 含畸形/非位址 token，**When** 解析，**Then** 略過該 token 繼續解析、不致錯誤。

---

### User Story 4 - 地區標註與優雅降級 (Priority: P3)

稽核紀錄帶一個由來源 IP 推導的「地區」欄，供一眼辨識來源；私有/內網來源標為非空的「內網」類標記；當地區查詢資料暫不可用時，地區留空但稽核仍正常運作（不因此崩潰）。

**Why this priority**: 提升鑑識可讀性的加值面；非稽核成立的必要條件，故 P3 且必須優雅降級。

**Independent Test**: 以一個已知公網來源 IP 觸發紀錄 → 地區欄被填；以私有/內網來源 → 地區為非空「內網」類；在地區查詢資料缺失的情境啟動 → 服務正常啟動、地區留空、稽核仍寫入。

**Acceptance Scenarios**:

1. **Given** 可解析的來源 IP，**When** 留稽核紀錄，**Then** 地區欄被填（私有/內網→非空「內網」類）。
2. **Given** 地區查詢資料缺失/不可用，**When** 系統啟動與處理請求，**Then** 不崩潰、地區留空、稽核紀錄仍正常寫入。

---

### User Story 5 - 操作日誌的操作者歸屬就緒 (Priority: P3)

既有的「資料異動操作日誌」要能歸屬到操作者及其來源 IP 與關聯 id——本刀把這條歸屬能力（seam）立到位；實際對線上異動端點的歸屬，自第一個操作者歸屬的異動功能起生效。

**Why this priority**: 讓三條稽核軌（操作日誌／存取／登入）的操作者歸屬一致；但本刀尚無線上異動端點可填，故為就緒性（P3）。

**Independent Test**: 以受稽核上下文的異動路徑（測試替身）證實操作者 id／操作者 IP／關聯 id 確實流入操作日誌紀錄（由恆空→真值），證明 seam 通。

**Acceptance Scenarios**:

1. **Given** 帶操作者與真實 IP 的受稽核上下文，**When** 一筆資料異動經既有原子審計路徑寫入，**Then** 該操作日誌紀錄帶操作者 id／操作者 IP／關聯 id（非空）。

---

### Edge Cases

- **偽造 forwarded（不可信直連）**：直連來源不在可信集合 → 一律忽略 forwarded、記直連位址（US3）。
- **無 forwarded／全可信 hop／可信集合未設**：fail-safe 記直連位址。
- **畸形 forwarded token**：略過、繼續解析。
- **地區資料缺失/不可用**：服務仍啟動、地區留空、稽核照寫（不崩潰）。
- **稽核寫入失敗**：盡力而為、吞錯、**不**擋/不失敗業務請求。
- **未認證請求**：不留存取紀錄；但登入無論成敗皆留登入嘗試紀錄（含未認證的失敗登入仍帶來源 IP）。
- **登入多終端路徑**：每終端路徑（成功＋各失敗）恰一筆登入嘗試紀錄、不重不漏。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 對每個**已認證**請求留**恰一筆**存取紀錄。
- **FR-002**: 系統 MUST NOT 對未認證請求（無／無效／過期憑證，含登入、健康探針、公開路徑）留存取紀錄。
- **FR-003**: 存取紀錄 MUST 含：操作者、請求方法、路徑、結果狀態、**真實**來源 IP、原始 forwarded 鏈、地區、關聯 id、時間。
- **FR-004**: 系統 MUST 對 login 的**每個終端結果**（成功或任一失敗路徑）留**恰一筆**登入嘗試紀錄。
- **FR-005**: 登入嘗試紀錄 MUST 含：嘗試帳號、outcome、操作者（已確認身分時）、真實來源 IP、原始 forwarded 鏈、地區、關聯 id、時間；未確認身分的失敗其操作者欄為空。
- **FR-006**: 系統 MUST 自 forwarded 鏈解析**真實 client IP**，且**只**信任顯式配置的可信代理集合；MUST NOT 信任來自未授信來源的 forwarded 資料。
- **FR-007**: 解析 MUST fail-safe：可信集合未設定、或直連來源不可信 → 使用直連位址、不採信 forwarded。
- **FR-008**: 系統 MUST 逐字保存原始 forwarded 鏈（與解析後的來源 IP 分欄）供鑑識。
- **FR-009**: 系統 MUST 由解析後的來源 IP 推導地區；私有/內網 → 非空「內網」類標記；地區推導為**盡力而為**——資料不可用時地區留空、稽核仍成立、系統不崩潰。
- **FR-010**: 系統 MUST 為每個請求附一個關聯 id（沿用入站的請求 id 標頭、否則生成）。
- **FR-011**: 系統 MUST 對**未認證**請求（含登入）亦擷取真實來源 IP，使登入嘗試紀錄帶 IP。
- **FR-012**: 所有稽核寫入 MUST 為**盡力而為**：寫入失敗 MUST NOT 使業務請求失敗或受阻。
- **FR-013**: 系統 MUST 為既有操作日誌建立「操作者／操作者 IP／關聯 id」歸屬能力（seam）；線上歸屬自第一個操作者歸屬的異動功能起生效（本刀以測試替身證實 seam 通）。
- **FR-014**: 三條稽核紀錄（操作日誌、存取、登入）MUST 為 append-only（不可更新／刪除、不可竄改）。
- **FR-015**: 本刀 MUST NOT 引入：稽核查詢/讀取端點或 UI、登入鎖定執行、紀錄保留/清理、任何資料 schema 變更或新增 migration、任何新業務 wire 端點——各歸後續波次。
- **FR-016**: 本刀 MUST 保持既有健康探針與既有登入/身分/守門行為**零回歸**。

### Key Entities *(資料層一覽；逐欄定義屬 plan 期 data-model)*

| 實體 | 角色 | 說明 |
|---|---|---|
| 登入嘗試紀錄 `sys_login_attempt` | 認證事件稽核 | 每登入終端結果一列：嘗試帳號／outcome／操作者（可空）／來源 IP／原始 forwarded／地區／關聯 id／時間。已於既有 schema 建齊（含為日後鎖定備的兩複合索引）；本刀只**新增**寫入。 |
| 存取紀錄 `sys_access_log` | 已認證請求稽核 | 每已認證請求一列：操作者（必有）／方法／路徑／結果狀態／來源 IP／原始 forwarded／地區／關聯 id／時間。schema 已建齊；本刀只新增寫入。 |
| 操作日誌 `sys_operation_log` | 資料異動稽核 | 既有（005 落地）；本刀補「操作者／操作者 IP／關聯 id」歸屬能力（seam）。 |
| 請求稽核上下文（RequestContext） | 每請求一次解析的稽核載體 | 操作者身分（可空）／真實來源 IP／原始 forwarded／地區／關聯 id；供三 sink 共用同一解析結果。 |
| 可信代理集合 | 來源 IP 解析的信任邊界 | 部署期顯式配置的代理網段集合；fail-safe 預設空。 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 已認證請求 100% 留恰一筆存取紀錄、未認證請求 0% 留存取紀錄——由活體驗證證實。
- **SC-002**: login 每終端結果（成功＋各失敗）100% 留恰一筆登入嘗試紀錄、失敗筆 100% 帶真實來源 IP——由活體驗證證實。
- **SC-003**: 真實 client IP 在可信代理鏈下 100% 正確解析；來自未授信來源的偽造 forwarded 100% 被忽略（fail-safe 用直連位址）——由單元測試＋活體驗證證實。
- **SC-004**: 來源 IP 以合法網路位址值寫入（無資料型別錯誤）——由活體驗證證實。
- **SC-005**: 每請求 100% 帶關聯 id（沿用或生成）；原始 forwarded 鏈逐字保存——由驗證證實。
- **SC-006**: 操作日誌的操作者／操作者 IP／關聯 id 歸屬 seam 由恆空→真值 100% 通——由測試替身證實。
- **SC-007**: 可解析來源 IP 100% 帶地區；私有/內網 100% 帶非空「內網」類；地區資料不可用時優雅降級（地區留空、不崩潰）——由驗證證實。
- **SC-008**: 本刀於正式環境封裝下建置＋啟動成功（地區資料就位、查詢就緒）——由正式環境建置驗證證實。
- **SC-009**: 既有健康探針＋登入/身分/守門行為零回歸；本刀**零 schema 變更、零 migration**——由活體驗證＋變更比對證實。

## Assumptions

- **稽核表與索引已就緒**：`sys_login_attempt`／`sys_access_log`（含登入嘗試的兩複合索引）／`sys_operation_log` 與其網路位址欄皆於既有基線建齊 → 本刀**無** migration、不建表、不動 schema。
- **反代已轉發來源位址標頭**：既有反向代理已轉發 forwarded／real-IP／request-id 標頭（本刀僅**驗證**、不改反代設定）。
- **系統位於可信反代後方**：可信代理集合由各部署環境的維運顯式配置（開發環境 fail-safe 預設空＝採直連位址）；CDN 段以加入可信集合方式處理、無 CDN 專屬特例邏輯。
- **地區查詢資料於正式封裝中提供**：正式環境映像含地區查詢資料檔；缺檔時優雅降級（地區留空、不崩潰）。
- **本刀「使用者」**＝安全/稽核維運人員＋下游功能（登入鎖定、稽核讀端 UI）＋操作日誌歸屬的消費功能。
- **DESIGN §5.9 推進留痕**：本刀的真實來源 IP 取自「forwarded 鏈 trusted-proxy 解析」，**推進**凍結設計註記（DESIGN §5.9 原為「地區由直連位址解」）——因系統在反代（可能含 CDN）後方、直連位址＝反代 IP、否則來源 IP 軌與日後鎖定皆失效。此屬**設計細節推進**（非 constitution / 非決策層變更），於 `/speckit-plan` Constitution Check 對齊、下次設計重鑄摺合（依 brainstorm §7）。
- **遞延（OUT，各歸其刀）**：稽核查詢/讀取端點＋UI（後續波次）；登入鎖定執行（後續波次，本刀僅備真實 IP＋既有索引）；紀錄保留/清理（後續波次）；操作日誌的線上歸屬填入（自第一個操作者歸屬的異動功能起）；全流量（含未認證）觀測性日誌（屬觀測性波次、非本稽核表）。
