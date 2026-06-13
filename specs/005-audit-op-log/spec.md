# Feature Specification: audit-op-log（操作審計 op-log 同 txn 原子機制＋mutate_in_txn＋sys_operation_log sink）

**Feature Branch**: `005-audit-op-log`

**Created**: 2026-06-14

**Status**: Draft

**Input**: User description: "docs/superpowers/005-audit-op-log.md（波 0 第五刀 / audit 刀 ×2 之首 Phase 0 brainstorm；對應 rev2 011：`model/audit.rs` 的 `mutate_in_txn` 泛型 wrapper〔業務寫＋審計寫同 txn 原子〕＋`AuditEvent`/`AuditSerialize`＋`sys_operation_log` entity/facade〔append-only sink〕＋單一寫路徑 proof `sys_user::soft_delete`〔redact password〕；拍板：刀界 A 機制+proof／proof 單一 soft_delete／operator 顯式 param／AuditOperation 全 4／驗證 ii commit+rollback／無 migration／擴 entity crate +with-json；承接 DESIGN §5.2 同 txn 審計＋§3.2 append-only＋⚠️g 全新寫)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 業務變更與審計記錄原子綁定 (Priority: P1) 🎯 MVP

任何經由「審計包裝器」執行的資料變更，其**業務變更**與對應的**審計記錄**被綁進**同一筆資料庫交易**——要嘛兩者同時落庫成功、要嘛兩者同時不留痕。系統不存在「改了資料卻沒有審計」或「審計記了但資料沒改」的中間狀態。這讓後續每一個寫端刀的變更都自帶不可分割的審計，審計鏈從根上可信。

**Why this priority**: 這是審計的地基價值。若業務寫與審計寫不原子，審計記錄就不可信——可能漏記真實變更、或記下從未生效的假變更。後續所有寫路徑刀都站在這個原子保證上；即使本刀不含任何具體業務寫端，「原子審計機制就位」本身即交付可驗收的價值（同 envelope／soft-delete 的「機制先行、消費者隨後」）。

**Independent Test**: 對一筆種子資料做一次成功的「軟刪」變更，確認資料已變更且審計列已寫入；再以「變更後強制失敗」的路徑執行，確認資料未變更且審計無新列（整筆回滾）。

**Acceptance Scenarios**:

1. **Given** 一筆存在的目標列，**When** 經審計包裝器成功執行一次變更，**Then** 業務變更與審計記錄皆落庫。
2. **Given** 變更於審計寫入或其後失敗，**When** 交易結束，**Then** 業務變更與審計記錄皆不存在（整筆回滾、不留無審計的業務變更）。
3. **Given** 變更目標不存在（查無目標列），**When** 執行，**Then** 不寫審計、亦不視為錯誤（no-op）。

---

### User Story 2 - 審計快照不洩漏敏感資料 (Priority: P2)

審計記錄保存變更前後的資料快照，但**敏感欄位（如密碼）以遮蔽值（`"<redacted>"`）呈現、絕不存明文**。審計日誌能保留「誰對哪一列做了什麼」的完整脈絡，而不擴大敏感資料的曝露面。

**Why this priority**: 審計日誌常被廣泛查閱（稽核、事件調查），若快照含明文密碼即構成嚴重外洩面。遮蔽讓審計兼顧「可追溯」與「不放大機密曝露」。依附 US1 的快照機制（遮蔽發生在快照產生時）。

**Independent Test**: 對一筆含敏感欄的資料產生審計快照，檢視快照——敏感欄為遮蔽值、其餘非敏感欄照常保留（可在不連資料庫下檢視快照形）。

**Acceptance Scenarios**:

1. **Given** 一筆含敏感欄（密碼）的資料，**When** 產生其審計快照，**Then** 敏感欄呈現為遮蔽值、非明文。
2. **Given** 同一快照，**When** 檢視非敏感欄，**Then** 照常保留（不過度遮蔽）。

---

### User Story 3 - 審計記錄完整且只增不改 (Priority: P3)

每筆審計記錄**完整描述一次變更**：操作別、目標表、目標列、變更前快照、變更後快照、操作者、追蹤碼。審計 sink **只能新增、不可更新或刪除**（append-only、不可竄改）。

**Why this priority**: 審計的法遵價值＝可追溯 ＋ 不可竄改。完整欄位讓事後能還原「誰、對哪一列、做了什麼、前後為何」；append-only 讓審計記錄一旦寫入就不可被竄改或抹除。依附 US1（記錄內容）與 US2（快照遮蔽）。

**Independent Test**: 一次變更後檢視其審計記錄——含全部六要素且正確；審計 sink 的存取入口只暴露「新增」、無更新/刪除路徑。

**Acceptance Scenarios**:

1. **Given** 一次經審計的變更，**When** 檢視其審計記錄，**Then** 含操作別／目標表／目標列／變更前快照／變更後快照／操作者／追蹤碼。
2. **Given** 審計 sink 的存取入口，**When** 檢視其可用操作，**Then** 只有新增、無更新或刪除路徑。

---

### Edge Cases

- **審計寫入失敗**：業務變更必須一併回滾（不可留下無審計的業務變更）——原子鏈的核心失敗模式。
- **no-op 變更**（查無目標列）：不寫審計、不視為錯誤；交易正常結束、零變更。
- **敏感欄遮蔽遺漏**：審計快照若洩漏明文敏感值（如密碼）＝資料外洩，須被測試擋下。
- **審計基礎設施繞過 facade 觸碰資料表**：必須被既有的建置期守恆檢查擋下（結構保證、非靠紀律）。
- **操作者未知**：審計記錄須容忍操作者為空（系統／種子 actor），不驗其存在。
- **審計 sink 模型與 schema 漂移**：審計 sink 的資料模型欄位若與既有資料庫 schema 不符＝執行期解析失敗或型別謊言，須逐欄對齊權威 schema。
- **無遷移**：審計 sink 的資料表已存在於既有 schema，本刀不得新增遷移或改動 schema。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 提供「交易式審計包裝器」，把一次業務變更與其審計記錄綁進**同一資料庫交易**——同成功落庫、同失敗回滾。
- **FR-002**: 審計包裝器 MUST 在審計寫入失敗（或變更後任一步失敗）時，連同業務變更一併回滾——不得留下無審計的業務變更，亦不得留下對應不到業務變更的審計列。
- **FR-003**: 審計包裝器 MUST 容許「無變更（no-op）」結果——查無目標列時不寫審計、不視為錯誤，交易正常結束零變更。
- **FR-004**: 每筆審計記錄 MUST 含：操作別、目標表名、目標列識別（可空）、變更前快照（可空）、變更後快照（可空）、操作者（可空）、追蹤碼（可空）。
- **FR-005**: 審計快照 MUST 對敏感欄（如密碼）以遮蔽值呈現、不得保存明文；非敏感欄保留。
- **FR-006**: 審計 sink MUST 為 append-only——其存取入口只暴露「新增」、不得提供更新或刪除路徑。
- **FR-007**: 審計基礎設施的純邏輯層 MUST NOT 直接觸碰資料表（entity）——資料表存取一律經其 facade，由既有建置期守恆檢查維持。
- **FR-008**: 操作者資訊 MUST 由呼叫端**顯式提供**（本刀不自動從請求上下文／認證鏈抽取操作者）。
- **FR-009**: 審計／業務 facade MUST 回傳資料庫原生模型與原生錯誤型——不 re-export entity 型、不在此層映射為回應信封。
- **FR-010**: 本刀 MUST 提供**單一寫路徑 proof**（對使用者表的「軟刪」、經審計包裝器）證明上述機制；MUST NOT 含其餘寫路徑或使用者表以外的寫端。
- **FR-011**: 審計 sink 的資料模型 MUST 逐欄對齊既有權威 schema（欄名／型／可空／主鍵）——不得漂移。
- **FR-012**: 本刀 MUST NOT 含：第二審計軌（存取日誌／登入嘗試／區域查詢與其中介層）、操作者自動抽取（請求上下文）、審計讀取端點、使用者表以外的寫路徑、原生錯誤→回應信封映射、資料庫遷移。

### Key Entities *(include if feature involves data)*

| 實體 | 要點 |
|---|---|
| 交易式審計包裝器（`mutate_in_txn`） | 把「業務變更」與「審計寫入」綁進同一資料庫交易；純泛型、對所有資料表中立、**不直接觸碰 entity**；決定 commit／rollback 生命週期 |
| 審計事件（`AuditEvent`） | 一次變更的完整描述（操作別／目標表／目標列／前後快照／操作者／追蹤碼）；純資料、不含 entity 型 |
| 審計操作別（`AuditOperation`） | 封閉操作詞彙（新增／更新／軟刪／還原）；每項對應審計記錄的操作別字串契約 |
| 審計快照序列化（`AuditSerialize`） | 把資料列轉為審計用快照、遮蔽敏感欄；由各資料表的 facade 實作 |
| 操作審計日誌（`sys_operation_log`，archetype B） | 審計 sink；append-only（只增不改）；經其 facade 為唯一寫入閘；逐欄對齊既有 schema |
| 使用者軟刪寫路徑（proof） | 對使用者表的軟刪、經審計包裝器；本刀唯一寫路徑、作為機制證明 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 對經審計包裝器的業務變更，其業務變更與審計記錄的落庫結果一致——成功時兩者皆存在、失敗時兩者皆不存在；出現不一致（單存其一）的次數為 **0**（實機驗收）。
- **SC-002**: 審計快照中敏感欄以遮蔽值出現、明文敏感值出現次數為 **0**（可在不連資料庫下檢視快照形、純函式驗收）。
- **SC-003**: 審計 sink 無任何更新／刪除路徑——可用操作只有新增（append-only）。
- **SC-004**: 每筆審計記錄含完整六要素（操作別／目標表／目標列／前後快照／操作者／追蹤碼）。
- **SC-005**: 審計基礎設施不繞過 facade 觸碰資料表——既有建置期守恆檢查維持綠。
- **SC-006**: 加入審計基礎設施後後端建置成功；健康檢查端點維持原樣、不退化。
- **SC-007**: 殘留檢查——部署層與本刀新寫來源（審計包裝器／sink facade／entity）中前代專案 token 出現次數為 **0**（以「前代」描述參照）。

## Assumptions

- 凍結權威為不可違反邊界、本 spec 與之一致（衝突序：DECISIONS §1 ＞ DESIGN ＞ 本 spec）：DESIGN §5.2（mutation→op-log `mutate_in_txn` 同 txn 審計、`AuditSerialize` redact）＋§3.2（`sys_operation_log` archetype B append-only、facade 僅暴露 insert）＋§1.5 L4（FACADE 層含 `model/audit.rs`）；⚠️g／§I.5 RUSTAPI-SOURCE-ISOLATION（rust-api 全新寫、對前代 source 受控參照——讀允許拷貝禁止；audit/facade 不在拷貝例外清單，屬全新寫）。
- 既有權威 schema（前代終態 squash 落地）已含 `sys_operation_log`（10 欄、含 JSONB 前後快照欄與 INET 操作者位址欄）⇒ 本刀**無遷移、無 schema 變動**。
- 既有種子資料（使用者 `Super`/`Admin`/`User`）為實機驗收的真實資料來源。
- 操作者自動來源（請求上下文／bearer 認證鏈）、第二審計軌（存取日誌／登入嘗試／區域查詢與中介層）、審計讀取端點、使用者表以外的寫路徑、原生錯誤→回應信封映射，皆為**後續刀**（第二 audit 刀／Auth 島／各寫端刀；已於進度追蹤 backlog 登記）。
- 驗收以可獨立測純函式（敏感欄遮蔽）為主（test-first），資料庫端僅以一條有界實機 smoke 證「業務寫＋審計寫原子——成功同落、失敗同滅」此核心點（其餘留消費刀）。
- 現況後端為極簡 scaffold（健康檢查＋回應信封型）＋首批讀側 facade（前一刀 soft-delete 基建）；本刀為其**首個寫路徑**與**首個審計 sink**。
