# Feature Specification: Audit Overlay（存取審計 + 登入嘗試 + 真實 client IP）

**Feature Branch**: `007-audit-overlay`

**Created**: 2026-06-15

**Status**: Draft

**Input**: User description: "@docs/superpowers/007-audit-overlay.md"（波 0 第二 audit 刀；brainstorm spec-design v2）

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 已認證請求的存取審計 (Priority: P1)

作為系統的安全稽核者／管理者，我要每一個「已認證」的請求都被記下一筆存取紀錄（哪位操作者、做了什麼〔方法＋路徑〕、結果如何、何時、來自哪個真實 client IP），這樣事後可以追溯「誰碰了什麼」。未認證的流量刻意不記——審計表只談「已識別的操作者」，不被匿名雜訊稀釋。

**Why this priority**: 存取審計是 audit 軌的核心、也是合規與可追溯性的地基。少了它，受權限保護的操作事後無從問責。

**Independent Test**: 帶有效憑證打一個受保護端點 → 恰好一筆存取紀錄、操作者正確、client IP 為真實來源；不帶／帶壞憑證打同端點 → 零存取紀錄。

**Acceptance Scenarios**:

1. **Given** 一個帶有效憑證的已認證請求, **When** 請求完成, **Then** 系統寫入恰好一筆存取紀錄，含操作者身分、方法、路徑、結果碼、真實 client IP、原始 forwarded 位址鏈、地區、追蹤 id、時間。
2. **Given** 一個未認證請求（無／壞／過期憑證，或健康檢查、公開路徑）, **When** 請求完成, **Then** 系統不寫入任何存取紀錄。
3. **Given** 存取紀錄寫入時資料庫暫時失敗, **When** 請求完成, **Then** 業務請求照常成功回應，僅該筆審計被靜默丟棄、不阻斷請求。

---

### User Story 2 - 登入嘗試審計 (Priority: P1)

作為安全稽核者，我要「每一次登入嘗試」——不論成功或失敗——都被記下一筆（嘗試的帳號、成功與否、若成功則對應操作者、真實 client IP、原始 forwarded 位址鏈、地區、追蹤 id、時間），這樣可分析失敗登入樣態（暴力破解／撞庫），也為未來的「登入失敗限流」備齊唯一資料源。

**Why this priority**: 登入是未認證入口、攻擊面最前線；失敗登入的 IP／帳號樣態是安全分析與未來限流的唯一依據。

**Independent Test**: 用錯密碼登入 → 恰好一筆登入嘗試紀錄（失敗、帶真實 client IP、無操作者）；用正確憑證登入 → 恰好一筆（成功、帶對應操作者）。

**Acceptance Scenarios**:

1. **Given** 一次失敗登入（帳號不存在／密碼錯／帳號停用）, **When** 登入流程結束, **Then** 系統寫入恰好一筆登入嘗試紀錄，標記為失敗、帶嘗試帳號與真實 client IP、操作者身分為空。
2. **Given** 一次成功登入, **When** 登入流程結束, **Then** 系統寫入恰好一筆登入嘗試紀錄，標記為成功、帶對應操作者身分與真實 client IP。
3. **Given** 登入嘗試紀錄寫入失敗, **When** 登入流程結束, **Then** 登入結果照常回應、不被審計失敗阻斷。

---

### User Story 3 - 反向代理後方的真實 client IP (Priority: P2)

作為安全稽核者，當系統部署在反向代理（其前可能再有 CDN／其它代理）後方時，我要審計紀錄裡的 client IP 是「真實終端使用者的 IP」、而不是代理的 IP，否則整條 IP 軌（以及未來的 per-IP 限流）在正式環境下全失去意義。同時，偽造的 forwarded 位址資訊（來自不可信來源）絕不能被採信。

**Why this priority**: 沒有它，US1／US2 在正式環境（代理後方）記下的 IP 全是代理 IP＝廢值；但「有記一筆」的骨架可先成立，故列 P2。

**Independent Test**: 模擬「真實 client → 可信代理 → 系統」的 forwarded 鏈 → 記下的 client IP ＝真實 client（非代理）；模擬不可信來源直連並偽造 forwarded 資訊 → 偽造值被忽略（採直連來源）。

**Acceptance Scenarios**:

1. **Given** 請求經由「已設定為可信」的代理鏈到達、forwarded 資訊含真實 client 與代理位址, **When** 系統決定 client IP, **Then** 取得的是真實 client IP（跳過所有可信代理 hop）。
2. **Given** 一個直連、且非可信來源的請求帶有偽造 forwarded 位址, **When** 系統決定 client IP, **Then** 偽造值被忽略、採用直連來源位址。
3. **Given** 可信代理集合未設定（如開發環境）, **When** 系統決定 client IP, **Then** 安全退回直連來源位址、不採信任何 forwarded 資訊。

---

### User Story 4 - 操作審計的操作者／追蹤補全 (Priority: P2)

作為安全稽核者，我要既有的「操作審計」紀錄（資料異動的前後快照）也帶上「是哪位操作者、從哪個真實 IP、屬哪條請求追蹤鏈」做的，這樣操作審計才完整、可問責。

**Why this priority**: 既有操作審計機制（前一刀）已留操作者／追蹤／IP 欄、但一直是空的；本刀把請求脈絡接上去、補全該欄。

**Independent Test**: 執行一個會留操作審計的資料異動 → 該筆操作審計帶非空的操作者身分、追蹤 id、真實操作者 IP。

**Acceptance Scenarios**:

1. **Given** 一位已認證操作者執行一個可審計的資料異動, **When** 異動完成, **Then** 對應的操作審計紀錄帶該操作者身分、請求追蹤 id、真實操作者 IP。

---

### Edge Cases

- 請求無任何 forwarded 位址資訊（直連）→ 採直連來源位址。
- forwarded 鏈含畸形／非位址的片段 → 略過該片段、繼續解析。
- client 位址為私有／內網網段 → 地區標為「內網」類非空標籤（不留空）。
- IPv4 與 IPv6 來源皆須正確解析。
- 未認證請求同時是登入請求 → 不記存取紀錄、但記登入嘗試紀錄（兩類紀錄互不相干）。
- 審計寫入失敗（資料庫抖動）→ 業務請求不受影響、該筆審計丟棄。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 對每一個「已認證」（請求帶可解析出操作者身分的有效憑證）的請求，寫入恰好一筆存取審計紀錄。
- **FR-002**: 系統 MUST NOT 對未認證請求（無／無效／過期憑證，含登入、健康檢查、公開路徑）寫入存取審計紀錄。
- **FR-003**: 存取審計紀錄 MUST 含：操作者身分、請求方法、請求路徑、結果碼、真實 client IP、原始 forwarded 位址鏈、地區標籤、追蹤 id、時間。
- **FR-004**: 系統 MUST 對每一條登入終端路徑（成功或任一失敗分支）寫入恰好一筆登入嘗試紀錄。
- **FR-005**: 登入嘗試紀錄 MUST 含：嘗試的帳號、成功與否、（成功時）對應操作者身分、真實 client IP、原始 forwarded 位址鏈、地區標籤、追蹤 id、時間；失敗紀錄的操作者身分為空。
- **FR-006**: 系統 MUST 由 forwarded 位址鏈解析真實 client IP，僅信任「顯式設定的可信代理集合」內的 hop；對來自集合外（不可信）來源的 forwarded 資訊一律不採信。
- **FR-007**: 當可信代理集合未設定、或直連來源不可信時，系統 MUST 安全退回採用直連來源位址（fail-safe），不採信任何 forwarded 資訊。
- **FR-008**: 系統 MUST 將原始 forwarded 位址鏈原文保存於審計紀錄，供鑑識回溯（即使解析後的 client IP 另存一欄）。
- **FR-009**: 系統 MUST 由解析後的 client IP 推導地區標籤；私有／內網來源 MUST 得到非空的「內網」類標籤。
- **FR-010**: 系統 MUST 為每個請求附上追蹤 id（沿用入站的請求 id 標頭，若無則自行產生）。
- **FR-011**: 系統 MUST 對未認證請求（含登入）也擷取真實 client IP，使未認證登入的登入嘗試紀錄仍帶有 IP、不因未認證而落空。
- **FR-012**: 所有審計寫入 MUST 為 best-effort：審計寫入失敗 MUST NOT 使業務請求失敗或受阻。
- **FR-013**: 系統 MUST 為既有操作審計紀錄補全操作者身分、真實操作者 IP、與請求追蹤 id。
- **FR-014**: 三類審計紀錄（存取／登入嘗試／操作）MUST 為 append-only、不可竄改（無更新或刪除路徑）。

### Key Entities *(include if feature involves data)*

- **存取審計紀錄 (Access Log Entry)**：一筆「已認證請求」的紀錄。屬性：操作者身分（必填）、方法、路徑、結果碼、真實 client IP、原始 forwarded 位址鏈、地區、追蹤 id、時間。未認證請求不落列。
- **登入嘗試紀錄 (Login Attempt Entry)**：一筆登入嘗試（成功或失敗）。屬性：嘗試帳號、成功與否、操作者身分（可空、失敗為空）、真實 client IP、原始 forwarded 位址鏈、地區、追蹤 id、時間。為未來「登入失敗限流」的資料源。
- **請求脈絡 (Request Context)**：每請求一份、跨三類審計共用的脈絡。屬性：真實 client IP、原始 forwarded 位址鏈、地區、追蹤 id、操作者身分（可空）。對所有請求（含未認證）建立。
- **操作審計紀錄 (Operation Log Entry)**：既有的資料異動審計（前後快照）。本刀為其補全操作者身分、真實操作者 IP、追蹤 id。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% 的已認證請求各產生恰好一筆存取審計紀錄；0% 的未認證請求產生存取審計紀錄。
- **SC-002**: 100% 的登入嘗試（成功與失敗）各產生恰好一筆登入嘗試紀錄。
- **SC-003**: 對經由可信代理鏈到達的請求，記下的 client IP 等於真實終端使用者 IP（非代理 IP）的比例為 100%；來自不可信來源的偽造 forwarded 資訊被採信的比例為 0%。
- **SC-004**: 每一筆有寫入的審計紀錄，其原始 forwarded 位址鏈皆可事後取出（鑑識可回溯）。
- **SC-005**: 因審計寫入失敗而導致業務請求失敗的次數為 0。
- **SC-006**: 本刀之後新產生的操作審計紀錄，在「由已認證操作者執行」時，皆帶非空的操作者身分與追蹤 id。
- **SC-007**: 內網／私有來源的審計紀錄其地區標籤為非空（標為內網類）。

## Assumptions

- 審計所需的資料表（存取審計、登入嘗試）已於既有 schema 基線（波 0 一次全建）存在；本刀**不新建資料表、不做 migration**——只改「client IP 欄存什麼值」與消費既有索引。
- 部署位於反向代理後方（其前可能再有 CDN／其它代理）；可信代理集合（含內網段與 CDN 位址段）由**部署設定提供**，預設為空（fail-safe → 採直連來源）。
- 既有的「操作審計同交易原子寫入」機制（前一刀）存在且可被本刀餵入請求脈絡。
- IP→地區的查詢資料可用（隨本刀帶入）。
- 真實 client IP 改由 forwarded 鏈解析，屬對既有設計藍圖（地區原規劃用直連位址）的**推進**；此偏離將於 `/speckit-plan` 的 Constitution Check 正式對齊、並於設計藍圖下次重鑄時摺合。
- 無前端／UI 變更；審計查詢讀端與 UI 屬後續波次（不在本刀）。
- 「登入失敗限流（lockout）」本體為未來功能（消費本刀備齊的登入嘗試資料），不在本刀範圍。
