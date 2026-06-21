# Feature Specification: XFF → real_ip 鑑識（跨拓樸真實客戶端 IP 解析＋四欄稽核鑑識）

**Feature Branch**: `013-xff-real-ip-forensics`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "`docs/superpowers/013-xff-real-ip-forensics.md`（Phase 0 brainstorm spec-design：把現況「單值 XFF 解析」重寫為兩層信任模型＋IIS 正規化＋CF-Connecting-IP 交叉驗證＋Cloudflare Tunnel 支援，並把『直連 peer／解析後 real_ip／原始鏈／可信度』四欄存入三張審計表、在審計中心全顯示且全可篩。設計細節與 12 個解析案例見 `docs/superpowers/000-rust-api-xff-real-ip-research.md`。拍板：C3 Tier-1 不硬 gate／C2 四欄全顯示〔順序 ip_confidence→peer_ip→real_ip→x_forwarded_for〕／C1 三模糊篩〔real_ip/peer_ip/x_forwarded_for〕＋一下拉篩〔ip_confidence〕。)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 跨拓樸正確解析真實客戶端 IP 並記錄鑑識 (Priority: P1) 🎯 MVP

不論請求經過幾層反向代理、CDN、Cloudflare Tunnel、或來源是帶雜訊的轉發標頭（IIS 把空格寫成 `+`、IP 帶 port），系統都能從轉發鏈中解析出**真實客戶端 IP**，並**忽略客戶端自行注入的假 IP**（永遠從最可信的入口端往外讀）；同時為每筆受稽核請求記下四項鑑識值：**直連 peer IP／解析後真實 client IP／原始轉發鏈／可信度**。

**Why this priority**: 「這個動作到底是哪個 IP 做的」是稽核與濫用調查的根本。現況單值解析在多反代/CDN/Tunnel 下會解錯或把假 IP 當真。把解析做對、把四項鑑識值記下來，本身就交付了正確歸因的核心價值，且不依賴審計中心 UI 即可驗證——是最小可交付核心。

**Independent Test**: 以一組代表性轉發鏈情境（直連／單層 CDN／多層反代／左段注入假 IP／Tunnel／IIS 格式）餵入系統，檢查每筆稽核紀錄存下的真實 client IP 與可信度符合預期；不需審計中心 UI 即可驗。

**Acceptance Scenarios**:

1. **Given** 請求經 CDN 轉入（鏈含 CDN 邊緣 IP），**When** 系統解析，**Then** 真實 client IP = CDN 邊緣左側第一個非 CDN IP，並記下四項鑑識值。
2. **Given** 客戶端在轉發鏈左段塞了多個假 IP，**When** 系統解析，**Then** 解析結果**不**受假 IP 影響（取信任邊界端、假 IP 永在結果左側碰不到）。
3. **Given** 轉發鏈帶 IIS 雜訊（`+` 編碼空格、IPv4 `ip:port`、IPv6 `ip%zone`），**When** 系統解析，**Then** 雜訊被正規化吃掉、仍正確解析。
4. **Given** 整條鏈都是我方受信基礎設施、找不到外部 client，**When** 系統解析，**Then** 退回直連 peer 並標記為**低可信**（不亂猜）。

---

### User Story 2 - 稽核員在審計中心檢視四欄鑑識 (Priority: P2)

稽核員（超級管理員）在審計中心三類日誌（操作異動／API 存取／登入嘗試）的每列，看得到四欄 IP 鑑識值，且**可信度以顏色標籤直覺呈現**（可靠歸因 vs 不可靠/異常一眼可分）。

**Why this priority**: 把鑑識值「存下來」之後，稽核員要能「看得到」才有調查價值；可信度著色讓稽核員快速分辨哪些歸因可信。

**Independent Test**: 以超管開審計中心 → 任一分頁 → 見每列依固定順序顯示四欄（可信度／直連 peer／真實 client／原始鏈），可信度欄有顏色區分；不依賴篩選即可驗。

**Acceptance Scenarios**:

1. **Given** 已有帶四欄鑑識的稽核紀錄，**When** 開啟審計中心任一分頁，**Then** 每列依序顯示「可信度 → 直連 peer → 真實 client → 原始轉發鏈」四欄。
2. **Given** 不同可信度的紀錄，**When** 檢視可信度欄，**Then** 各可信度以可區分的顏色標籤呈現（如「已驗證」與「不符/退回」明顯不同）。

---

### User Story 3 - 依 IP 與可信度篩選稽核紀錄 (Priority: P2)

稽核員能依鑑識欄縮小調查範圍：以**任一 IP 欄做模糊（部分比對）搜尋**（真實 client／直連 peer／原始鏈子字串），並以**可信度做精確篩選**（例如只看「不符」「退回」等低可信列做複查）。

**Why this priority**: 調查時要能「找出某 IP 相關的所有動作」或「揪出所有不可靠歸因複查」；篩選把大量稽核資料變成可操作的調查工具。

**Independent Test**: 在審計中心輸入某 IP 子字串→只回含該子字串的列；選某可信度→只回該可信度的列；皆可獨立驗。

**Acceptance Scenarios**:

1. **Given** 多筆不同 IP 的紀錄，**When** 對真實 client（或直連 peer、或原始鏈）輸入 IP 子字串搜尋，**Then** 只回含該子字串的列。
2. **Given** 多種可信度的紀錄，**When** 以可信度下拉選某一態篩選，**Then** 只回該可信度的列。
3. **Given** 未填任何篩選欄，**When** 查詢，**Then** 該空欄略過、不影響結果（不因空字串誤篩成 0 列）。

---

### User Story 4 - Cloudflare 驗證提升可信度並標記異常 (Priority: P2)

當請求**確實**經過 Cloudflare（由網路入口端證明、非靠可偽造的標頭判斷）時，系統拿 Cloudflare 提供的權威客戶端 IP 與位置解析結果**交叉驗證**：相符 → 標記為**最高可信**；不符 → **標記異常**供複查（但**不**用它覆蓋位置解析出的 real_ip）。

**Why this priority**: 兩個獨立訊號相符能把可信度拉到最高；不符則是設定漂移或攻擊的早期警報。這是在已正確的解析之上加一層可信度強化，不改變解析本身。

**Independent Test**: 模擬「確實經 CF」的請求（帶驗證旗標 + 權威 IP header），驗相符→最高可信、不符→異常標記；非經 CF 的請求一律忽略該 header。

**Acceptance Scenarios**:

1. **Given** 確實經 CF 的請求且權威 IP 與解析結果相符，**When** 系統驗證，**Then** 可信度標為「已驗證」（最高）。
2. **Given** 確實經 CF 但權威 IP 與解析結果不符，**When** 系統驗證，**Then** 可信度標為「不符」（異常）、且 real_ip 仍保留位置解析值。
3. **Given** 未經 CF（或無法證明經 CF）的請求帶了 CF 標頭，**When** 系統處理，**Then** 完全忽略該標頭（不採信可偽造來源）。

---

### User Story 5 - Cloudflare Tunnel 部署下仍正確解析 (Priority: P3)

在以 Cloudflare Tunnel 對外的部署（origin 無對外開埠、由 tunnel 連入）下，轉發鏈中**不會出現 CDN 邊緣 IP**、直連來源變成本機位址；系統仍能解析出真實 client IP，並在經驗證時標記為最高可信。

**Why this priority**: Tunnel 是常見且安全的部署模式，但它翻轉了拓樸假設；不支援會在此模式下解錯。優先級 P3 因為它是部署變體、建立在核心解析之上。

**Independent Test**: 以 Tunnel 形態的轉發鏈（真實 client → 本機 tunnel 入口 → 內網）餵入，驗解析出真實 client、可信度正確。

**Acceptance Scenarios**:

1. **Given** Tunnel 形態的請求（鏈中無 CDN 邊緣 IP、含本機 tunnel 入口與內網跳），**When** 系統解析，**Then** 正確解出真實 client IP（剝除內網/本機跳）。
2. **Given** 同上且經驗證，**When** 交叉驗證，**Then** 可信度標為「已驗證」。

---

### Edge Cases

- **左段注入假 IP**：客戶端自塞的假 IP 永遠在解析結果的左側、由右而左走碰不到 → 不影響歸因。
- **直連繞過 + 注入假 CDN IP**：若有人繞過信任入口直連並注入一個真 CDN IP 字串，解析可能解出假值，但會標為「位置錨定」而非「已驗證」；**主防線是網路層阻擋直連**（防火牆只放行 CDN 段／Tunnel 無對外開埠），此為部署前提。
- **自有 public IP 既是反代又是直連 client（無 CDN）**：屬本質性盲區——解析落到退回值並標**低可信**（該 IP 標記為可雙重身分）；可靠歸因此情境請走 CDN 路徑。
- **整鏈皆受信**：找不到外部 client → 退回直連 peer + 低可信。
- **信任設定缺檔/誤配**：fail-safe 退保守（不擴大信任、寧可解到較近端也不亂信）。
- **歷史稽核紀錄**：本功能前的舊紀錄沒有四欄鑑識值 → 維持空白（不回填）。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 從轉發標頭鏈解析真實客戶端 IP，且**由最可信（最近入口）端往外讀**、忽略客戶端可注入的條目。
- **FR-002**: 系統 MUST 容忍轉發標頭的格式雜訊（多餘空白、`+` 編碼空格、IPv4/IPv6 的 port 後綴）並仍正確解析。
- **FR-003**: 系統 MUST 依**operator 提供的信任設定**區分「我方基礎設施跳」（反向代理、內網、CDN 邊緣）與外部客戶端；信任設定 MUST 有安全預設（未設定/誤設時不擴大信任）。
- **FR-004**: 系統 MUST 為每次解析賦予一個**可信度**（共七種狀態之一），反映該 IP 是如何被判定的。
- **FR-005**: 當請求**確實經過 CDN**（由網路入口端證明，非由可偽造標頭判斷）時，系統 MUST 以 CDN 提供的權威客戶端 IP **交叉驗證**解析結果：相符提升可信度、不符標記異常；且 MUST NOT 用它覆蓋解析出的真實 IP。
- **FR-006**: 系統 MUST 為每筆受稽核請求記錄四項鑑識值——**直連 peer IP／解析後真實 client IP／原始轉發鏈／可信度**——並套用於三類稽核日誌（API 存取、登入嘗試、操作異動）。
- **FR-007**: 系統 MUST 支援 Cloudflare Tunnel 部署：當轉發鏈中無 CDN 邊緣 IP、直連來源為本機 tunnel 入口時，仍正確解析真實 client IP，並在經驗證時標最高可信。
- **FR-008**: 稽核員 MUST 能在審計中心檢視四項鑑識值（可信度以顏色直覺區分、四欄依固定順序呈現），並能依其篩選：對 IP 類欄位**模糊（部分比對）搜尋**、對可信度**精確（下拉）篩選**；未填的篩選欄 MUST 略過不影響結果。
- **FR-009**: 系統 MUST 保留既有稽核行為與地區（geo）推導；對既有稽核表的結構變更 MUST 可逆。
- **FR-010**: 系統 MUST NOT 因任何可偽造的標頭而採信「請求經過 CDN」；該判定僅能源自網路入口端不可偽造的事實（直連來源），其有效性以**部署層「origin 不可繞過信任入口直達」**為前提。

### Key Entities

- **稽核紀錄（三類：API 存取／登入嘗試／操作異動）**：每筆新增四項 IP 鑑識值——直連 peer IP、解析後真實 client IP、原始轉發鏈、可信度。新欄對歷史紀錄可為空。
- **信任拓樸設定（operator 維護）**：CDN 邊緣段（含「該 CDN 的權威客戶端 IP 標頭名」）、我方 public 反代段（含「可雙重身分」旗標）、內網段、特定反代↔內網綁定。安全預設為「未設定即不信任」。
- **IP 可信度**：七態列舉（如「已驗證 / 位置錨定 / 代理乾淨 / 代理軟降 / 直連 / 不符 / 退回」），標示解析的可信程度供稽核判讀與篩選。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 對一組代表性轉發鏈情境（直連、單層 CDN、多層反代、左段注入假 IP、Tunnel、IIS 格式等，≥12 種），解析出的真實 client IP 與預期相符率 **100%**。
- **SC-002**: 在網路信任邊界未被破壞的前提下，客戶端注入的假 IP **0%** 成為被歸因的 client IP。
- **SC-003**: **每一筆**受稽核請求都記下四項鑑識值（可於稽核日誌中驗證讀回正確），三類日誌皆然。
- **SC-004**: 稽核員能以可信度篩選出全部低可信（不符/退回）紀錄做複查、並能以任一 IP 欄搜尋到相關紀錄，結果正確。
- **SC-005**: 確實經 Cloudflare 的請求被標為最高可信；解析結果與 CDN 權威 IP 不符時被標記為異常供複查。
- **SC-006**: 對既有稽核表的結構變更**完全可逆**（套用 → 還原 → 再套用後資料庫一致、無殘留）。
- **SC-007**: 既有稽核日誌、地區推導、審計中心既有功能**零回歸**。

## Assumptions

- **部署前提（安全地基）**：origin 受保護、無法被繞過信任入口直達（regular 模式以防火牆只放行 CDN 段；tunnel 模式 origin 無對外開埠）。所有標頭信任與可信度等級皆**假設此網路層邊界未破**；本功能不負責防直連繞過（屬部署/網路層責任）。
- **operator 維護信任設定**：CDN 邊緣段、我方反代段等由 operator 自行設定並保持更新（CDN 官方 IP 清單不內建、由 operator 填）。
- **歷史紀錄不回填**：本功能前的稽核紀錄不具新鑑識值，維持空白。
- **建立在既有基建**：沿用既有稽核日誌寫入機制（007 audit overlay）與審計中心唯讀查詢 UI（012）；地區推導續以真實 client IP 為輸入（IPv4 為主、其餘降級為無）。
- **既有稽核表結構變更屬 archetype 破例**：對既有稽核日誌表動 IP 欄與改名，屬 Constitution §I.6「審計欄 archetype」凍結的破例，需於規劃（plan）階段通過 Constitution Check。
- **設計與案例來源**：完整解析演算法、12 個解析案例、信任地基、逐層改動設計見 `docs/superpowers/000-rust-api-xff-real-ip-research.md` 與 `docs/superpowers/013-xff-real-ip-forensics.md`。
- **明確不在範圍**：反爬蟲/限流、CDN IP 清單自動更新（cron）、True-Client-IP（CF Enterprise 限定）、IP range（`a-b`）/netmask 比對、其他審計遞延項（retention／CSV 匯出 等）。
