# Feature Specification: soft-delete 基建（SoftDeletable＋facade 唯一管道＋entity_access_lint）

**Feature Branch**: `004-soft-delete-infra`

**Created**: 2026-06-16

**Status**: Draft

**Input**: User description: "docs/superpowers/004-soft-delete-infra.md（波 0 第四刀 Phase 0 brainstorm：soft-delete 面地基＋L2 entity 層＋L4 facade 護欄；4 項拍板＝D1 全 11 entity 一次建齊｜D2 B1 純 trait+lint+entity 零業務 facade｜D3 sea_orm 在此落地｜D4 entity_access_lint 新建；對應前代 009、權威 DESIGN §5.1/§1.5/§3.4/§8.1/§5.0/§9.4）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 統一 soft-delete 讀取機制 (Priority: P1) 🎯 MVP

每個採用 soft-delete 的資料實體都透過**單一、可重用的「只取未刪除列」查詢機制**存取；刪除是**標記**（設定刪除時間戳）而非實體移除——被標記的列從預設讀取中消失、但資料仍在。後續每個業務切片只要宣告自己的刪除時間戳欄位，即繼承此機制、無須各自重寫過濾邏輯。

**Why this priority**: 這是整個 soft-delete「面」的核心——後續每個會刪除的業務實體（使用者／角色／選單…）的讀取都站在「只取 active 列」之上。沒有它，每個切片各自手寫刪除過濾＝前代把 soft-delete 攤成多刀尾巴的覆轍。

**Independent Test**: 對一個採用 soft-delete 的實體，將某列標記為已刪除後，預設「取 active」查詢**不**含該列、未過濾查詢**仍**含該列。

**Acceptance Scenarios**:

1. **Given** 一個 soft-delete 實體有若干未刪除列，**When** 以 active 查詢讀取，**Then** 回傳全部未刪除列
2. **Given** 將其中一列標記為已刪除，**When** 以 active 查詢讀取，**Then** **不**含該列；以未過濾查詢讀取則**仍**含該列
3. **Given** 一個新業務實體宣告其刪除時間戳欄位，**When** 套用此機制，**Then** 無須改動機制本體即繼承 active 查詢

---

### User Story 2 - facade 唯一存取管道（自動守恆） (Priority: P2)

所有應用層程式碼對資料實體的存取**只能**經由 facade 層；任何在 facade 層以外直接觸碰實體的程式碼，由**自動化、建置即失敗**的檢查擋下。此護欄隨地基一起 ship，後續每個切片自始受其約束。

**Why this priority**: 「facade 為唯一存取閘」是資料存取紀律的地基——soft-delete／審計／敏感欄遮蔽等橫切保證全靠「繞不過 facade」成立。護欄必須在第一個業務切片之前就位、且可證明真的擋得住，否則紀律形同虛設。

**Independent Test**: 對只經 facade 存取的程式碼，檢查通過（綠）；對一段在 facade 以外直接存取實體的程式碼，檢查**失敗**；且檢查不誤殺框架子路徑、被註解掉的程式碼、字串字面，也不禁止傳遞已載入的模型值。

**Acceptance Scenarios**:

1. **Given** 程式碼僅在 facade 層觸碰實體，**When** 跑守恆檢查，**Then** 通過
2. **Given** 在 facade 以外引入一處直接實體存取，**When** 跑守恆檢查，**Then** 失敗並指出違規處
3. **Given** 框架子路徑／註解／字串中出現形似實體路徑的字樣，**When** 跑守恆檢查，**Then** **不**誤判為違規

---

### User Story 3 - 完整資料層（一次反射凍結 schema） (Priority: P3)

資料層**一次完整反射**已凍結 schema 的全部 11 張業務表，使後續每個業務切片只需新增自己的 facade、**永不**事後補建或改動實體定義（杜絕前代的 entity retrofit 債）。

**Why this priority**: 前瞻性地基價值——schema 已凍結（前一刀建齊），實體是其機械反射；一次建完讓資料層成為穩定底座、後續切片的 surprise 面積歸零。價值隨後續切片實現。

**Independent Test**: 全部 11 個實體模組皆能建置、欄位對齊凍結 schema；任取一個尚無 facade 的實體，後續切片能直接為它加 facade、不需先補實體定義。

**Acceptance Scenarios**:

1. **Given** 凍結 schema 的 11 張業務表，**When** 檢視資料層，**Then** 11 個實體模組俱在、欄位對齊
2. **Given** 一個後續業務切片要做某實體，**When** 它開工，**Then** 該實體定義已存在、只需加 facade

---

### Edge Cases

- **soft-delete 例外實體**：KV 設定實體雖帶刪除時間戳欄位，但**無刪除路徑**（其唯一鍵本身即全域唯一、無「未刪除」部分唯一約束）→ **不**納入 soft-delete 機制、其 facade 之後直讀。
- **不刪除的實體**：append-only 日誌（3 表）、授權規則表、授權封存表、關聯表、token 表等**不採** soft-delete → 它們在資料層中為求完整而存在、但不繼承 active 查詢機制。
- **守恆誤判防護**：檢查 MUST 不把框架子路徑、被註解／字串中的形似路徑誤判為違規；MUST 不禁止「已載入模型值在層間傳遞」。
- **空護欄風險**：守恆檢查本身 MUST 可證有效（綠 ＋ 能抓違規 雙證），不得因「目前無違規」而淪為 vacuous pass。
- **新建置單元打包**：新增資料層建置單元 MUST 不破壞**正式環境映像打包**（多階段打包須涵蓋新單元，否則開發期掛載會遮住缺口、拖到部署才爆）。
- **執行期資料連線**：本刀無查詢端點 → **不**接執行期資料連線啟動接線；活體驗證自行連線、以交易回滾進行、不污染既有種子資料。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 提供**單一可重用機制**，對採用 soft-delete 的實體只回傳未刪除列（active base query）；刪除為標記（設定刪除時間戳）、非實體移除。
- **FR-002**: soft-delete 機制 MUST 套用於**恰好**帶「刪除時間戳 ＋ 保留唯一性之部分唯一約束」的實體（使用者／角色／選單三者）；KV 設定實體為**例外**（有欄無刪除路徑、不納入）。
- **FR-003**: 應用層對資料實體的所有存取 MUST 僅經由 facade 層；facade 層以外的直接實體存取 MUST 由**自動化、建置即失敗**之檢查阻擋。
- **FR-004**: 該 facade 紀律檢查 MUST 不誤判框架子路徑、被註解之程式碼、字串字面為違規，且 MUST 不禁止已載入模型值在層間傳遞。
- **FR-005**: 資料層 MUST 完整反射已凍結 schema 之全部業務表（11 表 → 11 實體模組），使後續切片只新增 facade、永不事後補建或改動實體定義。
- **FR-006**: facade 紀律檢查 MUST **可證有效**——對合規程式碼通過、且對植入之違規能確實抓出（非 vacuous pass）。
- **FR-007**: soft-delete 讀取過濾 MUST 對**活體資料**可驗——被標記刪除之列自 active 查詢排除、於未過濾查詢仍在。
- **FR-008**: 本刀 MUST **不**引入業務端點、寫入／CRUD facade 方法、審計交易包裝、執行期資料連線啟動接線、或 schema 變更（各歸其後續刀）。
- **FR-009**: 新增資料層建置單元 MUST 不破壞正式環境映像打包——正式環境映像 MUST 能成功打包含新單元。

### Key Entities *(資料層一覽；逐欄定義屬 plan 期 data-model)*

| 實體 | archetype | soft-delete |
|---|---|---|
| 使用者 `sys_user` | A 業務 | ✅（部分唯一）|
| 角色 `sys_role` | A 業務 | ✅（部分唯一）|
| 選單 `sys_menu` | A 業務 | ✅（部分唯一）|
| KV 設定 `system_settings` | A 業務 | ❌ 例外（有欄無路徑）|
| 使用者-角色關聯 `sys_user_role` | 關聯 | ❌ |
| token `sys_token` | 行為島 | ❌ |
| 操作日誌 `sys_operation_log` | B append-only | ❌ |
| 存取日誌 `sys_access_log` | B append-only | ❌ |
| 登入嘗試 `sys_login_attempt` | B append-only | ❌ |
| 授權規則 `casbin_rule` | D 治理 | ❌ |
| 授權封存 `sys_casbin_policy_archive` | D 治理緩衝 | ❌ |

（框架內部遷移表不在資料層；soft-delete 機制僅套用於 3 個 ✅ 實體。）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 全部 3 個 soft-delete 實體 100% 暴露「只取 active」查詢、由活體測試證實。
- **SC-002**: 被標記刪除之列自 active 查詢排除達 100%（未過濾查詢仍回傳該列）。
- **SC-003**: facade 紀律檢查對合規碼通過、且對植入違規確實失敗——可證有效、非 vacuous。
- **SC-004**: 凍結 schema 全部 11 表 100% 於資料層具備對應實體；後續切片可直接加 facade、不需新建實體。
- **SC-005**: 本刀新增業務端點數 ＝ 0、schema migration 數 ＝ 0（範圍邊界守住）。
- **SC-006**: 正式環境映像可成功打包含新資料層單元（打包零回歸）。
- **SC-007**: 既有 dev stack 零回歸——健康探針不受影響、新碼編入執行中服務。

## Assumptions

- schema 已凍結（前一刀建齊）、刪除時間戳欄位已存在 → 本刀**無** migration、不建表。
- 資料存取框架依賴於本刀（首個資料層切片）加入後端建置單元；非提前耦合。
- soft-delete **寫入路徑**（設定刪除時間戳）＋ CRUD ＋ 逐實體查詢方法於各業務切片帶入；本刀只建讀取機制 ＋ 護欄 ＋ 實體定義。
- 活體驗證以交易回滾對既有種子資料進行、不持久變更。
- 本刀為首個資料層切片 → 執行期資料連線啟動接線延後至首個查詢端點切片；本刀服務入口不變。
- 審計交易包裝（同層另一橫切基建）屬審計切片、不在本刀。
- 支援平台 ＝ 既有 dev/prod 容器堆疊；活體測試與正式打包均於容器內進行。
