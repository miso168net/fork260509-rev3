# Feature Specification: soft-delete-infra（entity 存取 facade 基建＋SoftDeletable＋entity_access_lint）

**Feature Branch**: `004-soft-delete-infra`

**Created**: 2026-06-14

**Status**: Draft

**Input**: User description: "docs/superpowers/004-soft-delete-infra.md（波 0 第四刀 Phase 0 brainstorm；對應 rev2 009：新 `entity` crate＋`SoftDeletable` trait＋`model/facade/` 首批 facade〔getUserInfo 讀叢集 sys_user/sys_role/sys_user_role〕＋`entity_access_lint` build-failing 守恆 test；拍板：刀界 A 機制+proof／proof set option 3／驗證 ii 純測+bounded 实机 smoke／寫路徑+audit.rs defer audit 刀／無 migration；承接 DESIGN §5.1 triple-guard＋⚠️o handler 層組裝＋⚠️g 全新寫)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - entity 存取唯一管道由結構強制 (Priority: P1) 🎯 MVP

後端對任一資料表的存取**只能經過該表的 facade**；任何在 facade 以外直接觸碰 entity 層的程式碼，都被一道「守恆檢查」在建置期擋下、指出檔案與行號。這讓 soft-delete、稽核、授權等橫切關注點未來都有**單一施力點**——後續每一個 handler 刀都無法繞過 facade 直接操作資料表。

**Why this priority**: 這是本刀的地基價值。沒有「facade 是唯一存取閘」的結構保證，soft-delete 過濾、稽核寫入、application-RI 等都會被某處的直接 entity 存取繞過而失效。守恆檢查就位後，後續所有資料存取刀都站在這個前提上——是整個資料層紀律的根。即使不含任何具體表的 facade，「機制就位」本身即交付可驗收的價值（同 envelope「機制先行、消費者隨後」）。

**Independent Test**: 在 facade 目錄以外植入一筆直接 entity 存取樣本，守恆檢查在建置期失敗並指出位置；移除後建置通過；facade 目錄內的 entity 存取不被誤擋。守恆檢查對常見假命中（含 `entity` 子字串的識別字、註解內、字串內、生命週期/字元字面）不誤報。

**Acceptance Scenarios**:

1. **Given** 一段在 facade 目錄外直接存取 entity 層的程式碼，**When** 跑守恆檢查，**Then** 建置失敗、輸出違規的檔案與行號。
2. **Given** facade 目錄內的 entity 存取，**When** 跑守恆檢查，**Then** 通過、不誤擋。
3. **Given** 含 `entity` 子字串但非 entity 存取的識別字（如 `identity`/`my_entity`）、或出現在註解/字串/字元字面中的 `entity::`，**When** 跑守恆檢查，**Then** 不誤報。

---

### User Story 2 - soft-deleted 列預設不可見 (Priority: P2)

對「可軟刪」的業務表，其 facade 的查詢**預設只回傳未被軟刪的列**——已軟刪的列保留在資料庫（不實體刪除）但不出現在一般查詢結果。提供一個共用的「active 基底查詢」機制讓各可軟刪表的 facade 共用此過濾，不必每處重寫。

**Why this priority**: soft-delete 的語意核心＝「保留資料、預設隱藏」。把「只見 active 列」收進共用機制，讓所有可軟刪表的讀路徑一致、不漏過濾。依附 US1 的 facade 管道（過濾發生在 facade 內）。

**Independent Test**: 共用 active 基底查詢產生的查詢條件包含「未軟刪」過濾（可在不連資料庫下檢視查詢形）；實機上對一筆軟刪後的列，facade 的 active 查詢不回傳它、未軟刪列照常回傳。

**Acceptance Scenarios**:

1. **Given** 共用 active 基底查詢，**When** 檢視其產生的查詢條件，**Then** 含「軟刪標記為空（未刪）」的過濾。
2. **Given** 一筆已標記軟刪的列與若干未軟刪列，**When** 經可軟刪表 facade 的 active 查詢讀取，**Then** 只回傳未軟刪列、軟刪列不出現。
3. **Given** 一個**硬刪**的連結表（無軟刪標記欄），**When** 設計其 facade，**Then** 不套用 active 過濾機制（該機制僅適用可軟刪表）。

---

### User Story 3 - getUserInfo 讀叢集 facade 就位 (Priority: P3)

緊接的「使用者資訊組裝」（getUserInfo，屬後續 Auth 刀）所需的**讀取叢集**——使用者、使用者角色關聯、角色三者——各備妥 facade 讀閘：依名稱/ID 取 active 使用者、依使用者取其角色關聯、依角色 ID 集取 active 角色。組裝（使用者→角色→輸出形）本身屬後續 handler 邏輯、不在本刀。

**Why this priority**: 用本刀證明 facade/守恆機制在「真實的、緊接消費的讀叢集」上可用：兩個可軟刪表（使用者、角色）證 active 過濾、一個硬刪連結表證「facade 不綁 soft-delete」。讓後續 Auth 刀直接有讀閘可組裝。依附 US1/US2。

**Independent Test**: 對既有種子資料，依名稱取得 `Super` 使用者、依其 ID 取得角色關聯（非空）、依角色 ID 集取得 active 角色（含角色代碼）；對使用者軟刪後 active 查詢排除之。

**Acceptance Scenarios**:

1. **Given** 種子使用者 `Super`，**When** 依名稱經 facade 取 active 使用者，**Then** 命中且回傳該使用者資料。
2. **Given** `Super` 的使用者-角色關聯種子，**When** 依使用者 ID 經 facade 取角色關聯，**Then** 回傳非空角色 ID 集。
3. **Given** 上述角色 ID 集，**When** 依 ID 集經 facade 取 active 角色，**Then** 回傳含角色代碼的 active 角色。
4. **Given** 一筆軟刪後的使用者，**When** 依 ID 經 facade 的 active 查詢取，**Then** 不回傳它。

---

### Edge Cases

- **facade 外直接存取 entity**：必須被守恆檢查在建置期擋下（結構保證、非靠 code review 紀律）。
- **active 過濾漏失**：可軟刪表 facade 的 active 查詢若未過濾軟刪列＝洩漏已刪資料，須被測試擋下。
- **硬刪表誤套 soft-delete**：硬刪連結表（無軟刪標記欄）不得套 active 過濾機制；誤套＝編譯/語意錯。
- **entity 欄與 schema 漂移**：entity 模型欄位若與既有資料庫 schema 不符（欄名/型/可空）＝執行期解析失敗或型別謊言，須逐欄對齊權威 schema。
- **守恆檢查假命中**：含 `entity` 子字串的識別字、註解/字串/字元字面中的 `entity::` 不得誤報（否則守恆無法落地）。
- **新建置單元缺漏**：新增的 entity 建置單元若未補進正式環境映像的來源納入，開發期（整目錄掛載）驗不出、拖到部署才爆——須以正式環境映像建置驗收。
- **facade 回傳形**：facade 回傳資料庫原生模型（非經輸出形轉換）；輸出形（DTO）轉換屬後續 handler 刀。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 以結構強制「entity 層只能經 facade 存取」——提供一道建置期守恆檢查，掃描後端來源、對 facade 目錄以外的直接 entity 存取使建置失敗並指出檔案與行號；facade 目錄豁免。
- **FR-002**: 守恆檢查 MUST 不對假命中誤報（含 `entity` 子字串的識別字、註解內、字串內、字元字面、生命週期），且 MUST 自帶一個「植入違規樣本→確實失敗」的後設驗證（證守恆會擋、非空跑）。
- **FR-003**: 系統 MUST 提供共用的「active 基底查詢」機制，對可軟刪表產生「只取未軟刪列」的查詢；機制為最小面（提供軟刪標記欄存取＋active 基底查詢，**不含**還原/更新等寫側）。
- **FR-004**: 可軟刪業務表（使用者、角色）的 facade MUST 經 active 基底查詢過濾軟刪列——一般查詢預設不回傳已軟刪列。
- **FR-005**: 硬刪連結表（使用者-角色關聯，無軟刪標記欄）的 facade MUST NOT 套用 active 過濾機制——證 facade 管道為通用、不綁 soft-delete。
- **FR-006**: facade MUST NOT 對外曝露 entity 型別（不 re-export Entity）；MUST 以具型別參數收受、回傳資料庫原生模型。
- **FR-007**: 本刀 MUST 備妥「使用者資訊組裝」讀叢集三表的 facade 讀閘：依名稱取 active 使用者、依 ID 取 active 使用者、依使用者 ID 取角色關聯 ID 集、依角色 ID 集取 active 角色。
- **FR-008**: entity 模型 MUST 逐欄對齊既有權威 schema（欄名/型/可空/主鍵）——不得與資料庫實際結構漂移。
- **FR-009**: facade MUST 以資料庫原生錯誤型向上回傳錯誤、**不**在 facade 層映射為回應信封（信封/錯誤映射屬 handler 層、後續刀）。
- **FR-010**: 本刀 MUST NOT 含：軟刪/更新等**寫路徑**與其交易稽核包裝、使用者資訊的**組裝/輸出形轉換**、讀叢集三表以外的 facade、資料庫遷移（軟刪標記欄已存在於既有 schema）。
- **FR-011**: 新增的 entity 建置單元 MUST NOT 破壞正式環境映像的多階段建置——其來源納入須補齊、且以正式環境映像建置作為驗收門。

### Key Entities *(include if feature involves data)*

| 實體 | 要點 |
|---|---|
| facade（entity 存取唯一閘） | 每表一個；唯一合法的 entity 存取入口；不曝露 entity 型別；回傳資料庫原生模型；由守恆檢查強制 |
| active 基底查詢機制（soft-delete mixin） | 可軟刪表共用；提供「軟刪標記欄存取＋只取未軟刪列」的基底查詢；最小面、無寫側 |
| 守恆檢查（entity_access_lint） | 建置期掃描；facade 外直接 entity 存取＝建置失敗；含假命中防護與植入式後設驗證 |
| 使用者（可軟刪 archetype A） | 有軟刪標記；facade 依名稱/ID 取 active |
| 角色（可軟刪 archetype A） | 有軟刪標記；facade 依 ID 集取 active（含角色代碼） |
| 使用者-角色關聯（硬刪連結 archetype C） | 無軟刪標記；硬刪；plain facade 依使用者 ID 取角色關聯 ID 集 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 守恆檢查純測 100% 通過——植入違規樣本確實使建置失敗、移除後通過、facade 內存取不誤擋、假命中（識別字/註解/字串/字元字面）0 誤報。
- **SC-002**: 「active 基底查詢」產生的查詢條件含「未軟刪」過濾，可在**不連資料庫**下檢視查詢形驗證（純函式驗收、test-first）。
- **SC-003**: 實機驗收——對既有種子資料，軟刪一筆列後該列在 active 查詢中出現次數為 **0**；使用者資訊讀叢集三表（依名稱/ID 取使用者、依使用者取角色關聯、依 ID 集取角色）對種子全部命中。
- **SC-004**: facade 對外曝露 entity 型別的次數為 **0**（由守恆檢查自驗）；讀叢集三 facade 皆回傳資料庫原生模型。
- **SC-005**: 新增 entity 建置單元後，**正式環境映像建置成功**、多階段建置不退化。
- **SC-006**: 加入資料存取依賴後後端建置成功；健康檢查端點維持原樣、不退化。
- **SC-007**: 殘留檢查——部署層與本刀新寫來源（entity/facade/守恆檢查）中前代專案 token 出現次數為 **0**（以「前代」描述參照）。

## Assumptions

- 凍結權威為不可違反邊界、本 spec 與之一致（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本 spec）：DESIGN §5.1 soft-delete triple-guard（trait／facade 不 re-export／build-failing 守恆檢查）＋§1.6 archetype（使用者/角色＝可軟刪 A、使用者-角色關聯＝硬刪 C）；⚠️o（application-RI／組裝驗證維持 handler 層、不下沉 facade）；⚠️g／§I.5 RUSTAPI-SOURCE-ISOLATION（rust-api 全新寫、對前代 source 受控參照——讀允許拷貝禁止；soft-delete/facade/守恆檢查不在拷貝例外清單，屬全新寫）。
- 既有權威 schema（前一刀落地）為 entity 模型對齊基準；可軟刪表的軟刪標記欄**已存在**於 schema ⇒ 本刀**無遷移、無 schema 變動**。
- 既有種子資料（使用者 `Super`/`Admin`/`User`＋使用者-角色關聯＋角色）為實機驗收的真實資料來源。
- 寫路徑（軟刪/更新）＋交易稽核包裝、使用者資訊組裝/輸出形轉換、讀叢集以外的 facade、原生錯誤→回應信封的映射，皆為**後續刀**（稽核刀／Auth 刀；已於進度追蹤 backlog 登記）。
- 驗收以可獨立測純函式（守恆檢查＋active 查詢形）為主（test-first），資料庫端僅以一條有界實機 smoke 證「軟刪過濾真生效」此核心點（其餘留消費刀）。
- 現況後端服務為極簡 scaffold（健康檢查＋回應信封型，零既有資料存取）；本刀為其首個資料存取層、首個新增建置單元。
