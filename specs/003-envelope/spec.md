# Feature Specification: envelope（統一回應信封＋msg-i18n key 規約）

**Feature Branch**: `003-envelope`

**Created**: 2026-06-16

**Status**: Draft

**Input**: User description: "docs/superpowers/003-envelope.md（波 0 第三刀 Phase 0 brainstorm：named aspect「error envelope ＋ msg-i18n key 規約」一體設計、scope A 完整縱切；4 項 sub-拍板＝scope A｜4 命名空間根＋文法、code-keyed 否決｜locale 外包一層 backend.｜前綴歸屬 (c) 後端發無前綴 key；凍結前提 ⚠️e／⚠️f／⚠️y）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 統一回應信封＋凍結錯誤碼契約 (Priority: P1)

每個 API 回應（健康／指標探針除外）都以**單一統一信封**交付：承載 payload、一個字串狀態碼、一則訊息；列表回應用單一分頁形。狀態碼是**固定凍結的集合**；業務與可復原錯誤以「前端讀得到、顯示得出」的方式交付（即落在成功傳輸狀態上），真正的傳輸錯誤例外僅二（找不到、無權限）；後端**永不發出**保留碼。

**Why this priority**: 這是整個 named aspect 的地基——後續每個業務刀的 wire 都站在「回應/錯誤有單一形」之上；亦為前代（rev2 008）回應信封的忠實重建。沒有它，全系統沒有一致的回應/錯誤處理。

**Independent Test**: 檢視回應（找不到路由的 fallback 路徑＋型別層契約測試）：信封形正確、碼為凍結集合中的字串、傳輸狀態映射正確（業務/內部→成功狀態、找不到→404、無權限→403）、保留碼可證永不產生。

**Acceptance Scenarios**:

1. **Given** 任一成功操作，**When** API 回應，**Then** body 為 `{data, code:"0000", msg}`、`data` 存在
2. **Given** 任一列表/分頁操作，**When** API 回應，**Then** `data` 承載 `{current, size, total, records}`（空頁 `records:[]`）、無額外分頁旗標（無 `pages`／`success`）
3. **Given** 一個業務或內部錯誤，**When** API 回應，**Then** 傳輸狀態為成功（200）、body 帶錯誤碼＋訊息使前端可讀
4. **Given** 對不存在路由的請求，**When** API 回應，**Then** 傳輸狀態 404、body 仍用信封形帶「找不到」碼
5. **Given** 完整碼集合，**When** 後端執行，**Then** 可證永不發出 4 個保留碼（僅 9 個可發碼可達）

---

### User Story 2 - 語言無關訊息 key＋前端在地化顯示 (Priority: P2)

錯誤訊息以**穩定、語言無關的識別碼（key）**交付、而非人話文字；前端將其翻譯成使用者當前語言並顯示；若某識別碼尚無翻譯，UI **graceful degrade**（顯示安全後備、絕不崩）。

**Why this priority**: 這是 named aspect 的 i18n 半邊——給使用者正確在地化訊息、並維持單一翻譯家（前端）。依附 US1 的信封存在，但可獨立驗證。

**Independent Test**: 驗每則交付的訊息欄皆為識別碼（無人話/無 CJK 漢字），且前端能將已知識別碼譯為在地化文字、對未知識別碼安全 fallback。

**Acceptance Scenarios**:

1. **Given** 任一錯誤回應，**When** 檢視，**Then** 訊息欄為穩定識別碼（結構化 key）、非人話散文
2. **Given** 一個已知識別碼與選定的 UI 語言，**When** 顯示訊息，**Then** 使用者看到該語言的訊息
3. **Given** 一個尚無翻譯的識別碼，**When** 顯示，**Then** UI 顯示安全後備（識別碼本身或通用訊息）而不中斷
4. **Given** 後端，**When** 產生訊息，**Then** 後端自身不做在地化（語言無關；單一翻譯家＝前端）

---

### User Story 3 - 可擴充的訊息 key 命名規約 (Priority: P3)

訊息識別碼的**命名規約被定義並鎖定**：一組命名空間根與結構文法，使每個後續切片一致地命名其錯誤識別碼、而非各自臨時自鑄。固定碼集合的識別碼作為此規約的 seed 成形。

**Why this priority**: 前瞻性契約價值——防止跨眾多後續切片的 key 漂移；其價值隨時間實現，但規則必須隨信封一起 ship，首批消費者才有規可循。

**Independent Test**: 規約已文件化；固定碼識別碼全數合於文法；一個檢查能拒絕不合規約的識別碼。

**Acceptance Scenarios**:

1. **Given** 規約，**When** 檢視，**Then** 它定義固定的命名空間根集合與結構化識別碼文法
2. **Given** 固定碼集合，**When** 檢查其識別碼，**Then** 全數合於規約
3. **Given** 後續切片新增一個識別碼，**When** 它遵循規約，**Then** 它無須改動信封或碼集合即可納入

---

### Edge Cases

- **本刀無業務端點**：唯一可達錯誤＝找不到（fallback）。「翻譯後業務錯誤顯示於 modal/toast」的端到端**只能待真端點出現**——i18n 顯示機制首檢點＝Auth/login 刀（login-failed 顯示碼、為本刀已鍵的固定碼）、per-entity 業務錯誤端到端＝首個 system_settings 刀；本刀 MUST 不靜默宣稱端到端覆蓋（登 follow-up backlog）
- **傳輸錯誤雙路徑**：找不到（404）/無權限（403）走前端 native 傳輸錯誤路徑、非成功路徑顯示處理——其識別碼也須在該路徑翻譯，莫只顧成功路徑
- **未翻譯識別碼**：尚未鍵化的 per-entity key 須 graceful degrade、不可空白或崩
- **可讀性取捨**：後端 log/curl/audit 的訊息變識別碼（非人話），可讀性降——以此換單一 i18n 家＋後端語言無關（既接受之取捨）
- **保留碼**：前端仍按行為分組辨識保留碼（雖後端永不發出）——契約 MUST 保留它們於凍結集合（刪除＝破壞凍結契約 ⚠️f）

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 以單一統一信封交付所有 API 回應（健康/指標探針除外）：payload（`data`）＋字串狀態碼（`code`）＋訊息（`msg`）三欄、固定欄序、`data` 永遠存在（錯誤時為 null、不省略）
- **FR-002**: 列表/集合回應 MUST 用單一分頁形（當前頁/每頁/總數/記錄陣列）：空頁記錄為空陣列、無額外分頁旗標（無 `pages`／`success`）
- **FR-003**: 狀態碼 MUST 為固定凍結之 13 碼集合——9 個後端可發、4 個保留碼後端 MUST 可證永不發出；碼為字串值（⚠️f）
- **FR-004**: 業務與可復原錯誤 MUST 以成功傳輸狀態（200）交付，使前端訊息通道可讀可顯；真實傳輸錯誤例外僅二（找不到→404、無權限→403）（⚠️e）
- **FR-005**: 訊息欄 MUST 載穩定、語言無關之識別碼（key）、非人話文字；後端 MUST 不做在地化（⚠️y）
- **FR-006**: 訊息識別碼 MUST 遵循既定命名規約——固定命名空間根集合（通用／auth／業務／系統）＋結構文法（根→實體→條件），供後續切片一致擴充；以共用業務碼承載「人話散文」式 code-keyed 方案被否決（無法區分共用碼下的 per-entity 訊息）
- **FR-007**: 前端 MUST 將交付的識別碼譯為使用者當前語言並顯示；尚無翻譯之識別碼 MUST graceful degrade（安全後備、不崩）（⚠️y graceful fallback）
- **FR-008**: 翻譯/顯示處理 MUST 同時涵蓋成功路徑顯示（200 業務錯誤的 toast/modal）與傳輸錯誤路徑（找不到/無權限），使無任何顯示錯誤逃過翻譯
- **FR-009**: 固定碼集合之識別碼 MUST 作為規約 seed 定義，並為專案支援語言（zh-CN、en-US）提供翻譯
- **FR-010**: wire 訊息 MUST 為去前綴之語意識別碼（`<root>.<entity>.<condition>`），與前端 locale 組織前綴無關；前端負責解析（補其 locale 樹位置）——後端 key 不耦合前端 locale 樹（拍板 4＝(c)）
- **FR-011**: 契約 MUST 由自動檢查守護：所發碼屬凍結集合、訊息為識別碼（非人話/無 CJK 漢字）、保留碼永不發出、識別碼合於規約文法
- **FR-012**: 「使用者看到翻譯後錯誤」之端到端覆蓋 MUST 登記為**階梯、不於本刀宣稱**：i18n 顯示機制首個自然端到端＝Auth/login 刀（login-failed 固定碼）、per-entity 業務錯誤端到端＝首個 system_settings 刀；本刀以型別/單元/component 測＋找不到路徑 wire 形覆蓋機制

### Key Entities *(契約一覽；逐欄定義屬 plan 期 data-model／contracts)*

| 實體 | 要點 |
|---|---|
| 回應信封 | `data`（payload、錯誤時 null 不省略）＋`code`（字串狀態碼）＋`msg`（語意識別碼）；固定欄序 data→code→msg |
| 分頁區塊 | `current`／`size`／`total`／`records`；空頁 `records:[]`；無 `pages`／`success` |
| 狀態碼集合（13） | 9 可發（`0000`/`1000`/`2222`/`3333`/`7777`/`8888`/`4040`/`5003`/`5000`）＋4 保留（`7778`/`8889`/`9998`/`9999` 永不發）；各帶意義、傳輸狀態映射、預設識別碼 |
| 訊息識別碼規約 | 4 根（`common`／`auth`／`biz`／`system`）＋文法 `<root>.<entity>.<condition>`；固定碼 seed 識別碼＋per-language（zh-CN/en-US）翻譯；wire 去前綴、前端 locale 外包一層 `backend.` |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% 的 API 回應符合統一信封形（`data`＋字串 `code`＋`msg`），由契約檢查證實
- **SC-002**: 每則回應之碼皆屬凍結集合；後端產生 4 個保留碼之次數＝0（可證）
- **SC-003**: 業務/內部錯誤以傳輸狀態 200 交付達 100%；僅找不到（404）/無權限（403）用傳輸錯誤狀態
- **SC-004**: 錯誤訊息欄為識別碼者達 100%（含人話/CJK 漢字者＝0%）
- **SC-005**: 固定碼集合之識別碼，於各支援語言（zh-CN/en-US）譯為正確在地化訊息、覆蓋率 100%
- **SC-006**: 未知識別碼 graceful degrade（安全後備）達 100%——無空白顯示、無崩潰
- **SC-007**: 本刀加入既有 dev stack 零回歸——API 服務維持健康、既有探針不受影響
- **SC-008**: 全契約守護檢查通過（凍結碼集合、訊息-非人話、保留碼永不發、文法合規）

## Assumptions

- 本刀為純回應/錯誤基礎設施：**不新增業務端點**；唯一可達錯誤路徑＝找不到 fallback。業務端點（契約的真實消費者）於後續刀出現
- 信封形、凍結 13 碼集合、HTTP-200 規則為**既凍結**（constitution §I.3／DESIGN §5.4・§7.3）；本刀忠實實作、不重決
- 訊息載識別碼為凍結契約之 DESIGN 級演進（**非** constitution amendment），與前端（wire＋i18n 權威 §I.1）協同、以 fork-delta（rev3-inline）追蹤
- 支援 UI 語言＝zh-CN（預設）＋en-US，對齊既有 locale 集合；固定碼 seed 識別碼為兩語提供翻譯
- 前端真實 app 請求層為唯一須接線之消費者（demo/替代請求層不在本刀）
- 「翻譯後錯誤顯示」端到端驗證分階段：機制於本刀以單元/component 測；首個自然 live 檢核點＝Auth/login 刀；per-entity 業務錯誤端到端＝首個 system_settings 刀——登 follow-up backlog
- 雖未新增建置單元（回應/錯誤模組併入既有後端建置單元），本刀為健康探針後**首批實質後端碼**→納一次 prod target build sanity（防建置打包缺口，rev2 教訓）
- 逐碼識別碼之確切用字（如條件段命名）於 plan 期定稿；規約之根集合與文法於本刀固定
- 單元測試策略：契約多屬型別/序列化層（本刀無業務邏輯純函式）；以型別/單元/component＋契約檢查守護（CLAUDE.md §3）；驗收以 C-V（curl／單元／component）覆蓋
