# Feature Specification: Audit Center Enhancement

**Feature Branch**: `017-audit-center-enhancement`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: 見 `docs/superpowers/017-audit-center-enhancement.md`（Phase 0 brainstorm spec-design）。源：INTEGRATION-CHECKLIST §3.C 審計中心 enhancement 三個 doable 子項（C-1 http_status class filter／C-3 CSV 匯出／C-4 op-log 角色 delta），user 拍板組一刀。

審計中心（`/manage/audit`、超級管理員專用、三分頁：操作異動／API 存取／登入嘗試）目前只能線上分頁瀏覽。本功能補三項 forensic／operational 可視性缺口，使審計者能更有效地篩選、留存、與追溯敏感變更。

## Clarifications

### Session 2026-06-23

- Q: op-log 匯出 CSV 的 `roles_before`/`roles_after` 如何呈現？ → A: 加專屬 `roles_before`／`roles_after` 兩欄（自前後快照抽出），payload 完整內容仍保留為獨立欄供 forensic。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 角色變更可事後追溯 (Priority: P1)

身為稽核者（超級管理員），當任何使用者的角色被新增/修改/停用/刪除時，我要能在操作異動紀錄裡找到一筆紀錄，明確看出「誰、在何時、把哪個使用者的角色從哪一組改成哪一組」，以滿足權限變更的問責與資安稽核。

**Why this priority**: 這是目前**唯一的資安問責盲點**——角色授予是最敏感的權限操作，但現行操作紀錄的前後快照不含角色集，導致「誰把某 user 變成管理員」事後查不到。補上它直接關閉一個可稽核性漏洞，價值最高。

**Independent Test**: 單獨實作即可交付價值——對任一使用者改角色後，到操作異動分頁展開該筆紀錄，能看到 roles-before / roles-after。不依賴 C-1/C-3。

**Acceptance Scenarios**:

1. **Given** 某 user 目前角色為 {R_USER_COMMON}，**When** 管理員編輯該 user 角色改為 {R_ADMIN}，**Then** 操作異動產生一筆紀錄，其前快照角色＝{R_USER_COMMON}、後快照角色＝{R_ADMIN}，且含操作者、目標 user、時間。
2. **Given** 新建一個帶初始角色的 user，**When** 建立完成，**Then** 該筆紀錄後快照含初始角色集、前快照角色為空。
3. **Given** 某 user 目前有角色，**When** 該 user 被停用或刪除，**Then** 該筆紀錄前快照保留其當時角色集（刪除後快照角色為空）。
4. **Given** 編輯 user 但未動角色（僅改其它欄），**When** 提交，**Then** 前後快照角色集相同（不誤報變更）。

---

### User Story 2 - 審計紀錄可匯出離線分析/留存 (Priority: P2)

身為稽核者，我要能把任一審計分頁（操作異動／API 存取／登入嘗試）的紀錄匯出成 CSV 檔，且匯出的是我**當前篩選條件下**的結果，以便離線分析、報表、或合規留存。

**Why this priority**: 線上分頁無法做跨頁彙整/離線分析/長期留存；匯出是合規與調查的常見剛需。次於 P1（問責盲點）但高於便利性篩選。

**Independent Test**: 在任一分頁設好篩選 → 按「匯出」→ 取得一個 CSV 檔，內容＝當前篩選結果（受上限約束）。不依賴 C-1/C-4。

**Acceptance Scenarios**:

1. **Given** 在 API 存取分頁套用了某篩選，**When** 點「匯出」，**Then** 下載一個 CSV 檔，其資料列＝該篩選結果、欄位對應該分頁顯示欄。
2. **Given** 篩選結果超過 1 萬列，**When** 匯出，**Then** 檔案含前 1 萬列，且使用者被告知「僅匯出前 1 萬列」。
3. **Given** 紀錄含中文（如操作者名、路徑），**When** 用試算表軟體（Excel）開啟匯出檔，**Then** 中文正確顯示不亂碼。
4. **Given** 非超級管理員，**When** 嘗試匯出，**Then** 被拒（與瀏覽審計的存取限制一致）。
5. **Given** 篩選結果為 0 列，**When** 匯出，**Then** 取得僅含表頭的 CSV（不報錯）。
6. **Given** 操作異動分頁有角色變更紀錄，**When** 匯出 CSV，**Then** 檔案含專屬 `roles_before`／`roles_after` 欄（除既有欄與 payload 欄外），可直接分析角色 delta 而無需解析 payload JSON。

---

### User Story 3 - 依 HTTP 狀態類別快速篩 API 存取紀錄 (Priority: P3)

身為稽核者，在 API 存取分頁，我要能用「2xx／4xx／5xx」類別一鍵篩選，快速聚焦成功/用戶端錯誤/伺服器錯誤的請求，而不必逐一輸入精確狀態碼。

**Why this priority**: 純操作便利性增強（既有單值精確篩仍可用）；價值實在但低於問責與匯出。

**Independent Test**: 在 API 存取分頁選「4xx」→ 列表只剩 400–499 的紀錄。不依賴 C-3/C-4。

**Acceptance Scenarios**:

1. **Given** API 存取分頁有各種狀態碼紀錄，**When** 選類別「4xx」，**Then** 只顯示狀態碼 400–499 的列。
2. **Given** 已選類別「5xx」，**When** 清除類別（選「全部」），**Then** 回到不依狀態篩的結果。
3. **Given** 類別與精確狀態值同時設定，**When** 查詢，**Then** 兩者皆套用（交集；屬罕見但合理）。

### Edge Cases

- 匯出結果超過上限（1 萬列）→ 截斷至前 1 萬列並告知使用者。
- 匯出 0 列 → 僅表頭的 CSV，不報錯。
- CSV 儲存格含逗號／引號／換行／結構化內容（操作紀錄的前後快照）→ 正確轉義、不破壞欄位對齊。
- 角色變更紀錄中角色集未變（如僅停用）→ 前後角色集相同、不誤報。
- HTTP 狀態類別傳入空值或無法識別 → 視為未篩選（不報錯）。
- 操作紀錄前後快照中的 session 識別碼 → 依拍板**保留**（不遮蔽）。

## Requirements *(mandatory)*

### Functional Requirements

**角色變更稽核（US1）**
- **FR-001**: 系統 MUST 在使用者角色被變更時，於操作異動紀錄記錄變更前角色集與變更後角色集。
- **FR-002**: 角色變更稽核 MUST 涵蓋使用者全生命週期的變更途徑：建立（含初始角色）、編輯角色、停用、刪除（含批次刪除）。
- **FR-003**: 稽核者 MUST 能由單一操作異動紀錄判讀：操作者、目標使用者、變更前角色集、變更後角色集、發生時間。
- **FR-004**: 角色集為空時 MUST 以空集合（非「無資料」）表示，以區分「無角色」與「未記錄」。

**審計匯出（US2）**
- **FR-005**: 系統 MUST 讓使用者將三個審計分頁（操作異動／API 存取／登入嘗試）各自匯出為 CSV。
- **FR-005a**: 操作異動（op-log）之 CSV 匯出 MUST 額外提供專屬 `roles_before`／`roles_after` 欄（自前後快照抽出），供角色 delta 直接分析；payload 完整內容仍保留為獨立欄（clarification 2026-06-23）。★as-built 勘誤（2026-07-02、REVIEW-20260702 F-11）：CSV 實際表頭為 camelCase `rolesBefore`／`rolesAfter`（與其餘 14 欄 camelCase 慣例一致、data-model 已載）；本 FR 之 snake_case 字面指「專屬兩欄」語意、非表頭字面。
- **FR-006**: 匯出內容 MUST 反映使用者當前套用的篩選條件（所見即所匯）。
- **FR-007**: 單次匯出 MUST 上限 1 萬列；當符合列數超過上限時，系統 MUST 告知使用者僅匯出前 1 萬列。
- **FR-008**: 匯出之 CSV MUST 能於常見試算表軟體正確開啟，且非 ASCII（中文）內容不亂碼。
- **FR-009**: 匯出 MUST 受與「瀏覽審計」相同的存取限制（超級管理員）。

**狀態類別篩選（US3）**
- **FR-010**: 系統 MUST 讓使用者於 API 存取分頁以 HTTP 狀態類別（2xx／4xx／5xx）篩選。
- **FR-011**: 類別篩選 MUST 與既有單值精確狀態篩選並存（不取代）。
- **FR-012**: 未提供或無法識別的狀態類別 MUST 視為未篩選（不回傳錯誤）。

**跨切（不可回歸／約束）**
- **FR-013**: 既有審計瀏覽、分頁、與篩選行為 MUST 維持不變（零回歸）。
- **FR-014**: 本功能 MUST 不改動資料庫結構（無 schema/migration）。

### Key Entities *(include if feature involves data)*

- **操作異動紀錄（Operation Log record）**：每筆敏感寫操作一列，含操作者、目標、操作類型、**前快照／後快照**（結構化內容）、時間。本功能於使用者寫操作的前後快照加入角色集。
- **API 存取紀錄（Access Log record）**：每次已認證請求一列，含操作者、方法、路徑、HTTP 狀態、IP 鑑識欄、時間。狀態類別篩選作用於此。
- **登入嘗試紀錄（Login Attempt record）**：每次登入嘗試一列。
- **角色集（Role set）**：使用者所屬角色代碼之集合；於角色變更前後各取一份快照。
- **CSV 匯出檔（CSV export artifact）**：依當前篩選產出的可下載審計資料檔（受 1 萬列上限約束）。op-log 匯出額外含專屬 `roles_before`／`roles_after` 欄。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% 的使用者角色變更（建立/編輯/停用/刪除）皆產生一筆含「前角色集、後角色集、操作者、目標、時間」的可查紀錄。
- **SC-002**: 稽核者能由單筆紀錄回答「誰把哪個使用者的角色從 X 改為 Y、何時」，無需跨多筆紀錄拼湊。
- **SC-003**: 稽核者能在任一審計分頁以單一動作（按匯出）取得反映當前篩選的 CSV 檔。
- **SC-004**: 匯出檔於 Excel 開啟時中文 100% 正確顯示（不亂碼）。
- **SC-005**: 匯出列數超過 1 萬時，使用者每次都被告知截斷（不靜默丟資料）。
- **SC-006**: 稽核者能以單一動作（選類別）將 API 存取列表收窄到指定狀態類別，結果僅含該範圍狀態碼。
- **SC-007**: 既有審計三分頁的瀏覽/分頁/既有篩選行為零回歸。
- **SC-008**: 非超級管理員無法匯出或瀏覽審計資料。

## Assumptions

- 審計中心與其匯出 MUST 維持超級管理員專用（沿用既有存取控制）。
- 本功能不需資料庫結構變更：角色快照寫入既有的彈性結構化前後快照欄；篩選與匯出皆為查詢層行為。
- CSV 以可下載檔案形式交付（UTF-8、單次上限 1 萬列）。
- 操作紀錄前後快照中的 session 識別碼**保留不遮蔽**（拍板 D3，供 forensic session 關聯）。
- 角色變更稽核覆蓋以「該使用者寫操作確實產生操作異動紀錄」為前提（建立/編輯/刪除途徑既已記錄操作異動）。
- 既有三審計分頁為本專案自建頁面（可直接增強）。

## Out of Scope

- 模糊文字搜尋的索引優化（pg_trgm/GIN）——規模相關、需資料庫擴充，延後。
- 審計/封存資料的保留期與清除（retention/purge）——與日誌保留政策一併處理，延後。
- 匯出格式擴充（Excel/JSON 等）——本期僅 CSV。
- 操作異動／登入嘗試以外維度的狀態類別篩選——狀態類別僅適用 API 存取（其餘無狀態欄）。
