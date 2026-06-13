# Feature Specification: rev2-schema-baseline（rev2 終態基線＋rev3 delta）

**Feature Branch**: `002-rev2-schema-baseline`

**Created**: 2026-06-13

**Status**: Draft

**Input**: User description: "docs/superpowers/002-rev2-schema-baseline.md（波 0 第二刀 Phase 0 brainstorm：⚠️t 拍板產物——m001 rev2 終態 squash＋m002 seed 92 列／6 表＋m003 FK＋m004 demo 選單種子；四項拍板＋⚠️v）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 一鍵達到 rev2 終態基線且零漂移可證 (Priority: P1)

開發者在 001 交付的 stack 上執行既有的 schema 初始化步驟（migrate gate），空資料庫即達到前代（rev2）系統的終態：12 表（含政策表與框架追蹤表）全部就位、基線種子資料（6 表 92 列，含 3 個預設帳號與授權政策）全數載入；並有可重複執行的驗證流程證明「rev3 基線＝rev2 終態」**零漂移**（與前代純淨參考庫雙向比對零差異）。

**Why this priority**: 這是 ⚠️t 拍板的直接載體——後續所有業務刀（envelope／soft-delete／audit／Auth／data islands）都建立在「schema 已是 rev2 終態」的前提上；零漂移驗證閉環是「忠實 squash」宣稱的唯一可信證據。

**Independent Test**: 對空庫執行初始化至基線檢查點，與前代純淨參考庫做正規化後的結構與種子資料雙向比對，零差異即過；基線計數不變式（92 列／6 表、protected 數）逐項可查。

**Acceptance Scenarios**:

1. **Given** 空資料庫（或僅含框架追蹤表的 001 遺留狀態），**When** 執行 schema 初始化至基線檢查點，**Then** 12 表口徑全數就位（10 業務表＋政策表＋框架追蹤表）、種子 92 列／6 表全中
2. **Given** rev3 基線庫與前代純淨參考庫（由前代既有資產重放產生），**When** 執行正規化後的結構比對與 6 表種子資料比對，**Then** 雙向零差異（正規化規則涵蓋隨機 token、框架追蹤表內容、密碼雜湊、時間戳、序列值）
3. **Given** 基線已就位，**When** 檢查預設帳號，**Then** `Super`／`Admin`／`User` 三帳號存在、共用單一執行期生成之 argon2id 雜湊、皆可驗證通過密碼 `123456`
4. **Given** 基線已就位，**When** 檢查授權政策計數，**Then** 政策列 72（全為 p 型、無 g 型）、受保護政策 19 列、受保護選單 8 列

---

### User Story 2 - rev3 改良 delta 顯式分離可審 (Priority: P2)

維運者／審計者能清楚區分「前代忠實基線」與「rev3 拍板改良」：join 表參照完整性（④ FK）與 demo 頁選單種子（⚠️p，初始僅授超級管理員）各為**獨立步驟**，套用於基線之後、可獨立追溯與驗證。

**Why this priority**: delta 顯式分離是 ⚠️t 拍板的後半——混入基線會讓零漂移驗證失效，也讓「rev3 改了什麼」不可審計；但它依附於 US1 的基線存在，故為 P2。

**Independent Test**: 基線檢查點通過後續套 delta 步驟，逐項斷言：join 表 FK ×2 存在、demo 選單與其政策列數符合枚舉定稿數、基線既有列未被 delta 改動。

**Acceptance Scenarios**:

1. **Given** 基線檢查點已通過，**When** 套用 delta 步驟，**Then** join 表（使用者-角色）具備對兩主表的參照完整性約束，其餘表維持零 FK
2. **Given** delta 已套用，**When** 檢查 demo 頁選單種子，**Then** 全部 demo 頁進入選單資料、可見性政策初始僅授超級管理員角色；與基線選單（10 列）及其政策（17 列）雙層不重疊
3. **Given** delta 已套用，**When** 重查基線計數不變式，**Then** 基線 92 列原值不變（delta 僅新增、不改寫基線列）

---

### User Story 3 - 回滾與重複執行安全 (Priority: P3)

維運者能安全地回滾與重複執行 schema 初始化：每一步皆有對稱回滾；完整回滾後重新執行，終態與單次執行完全一致；對已初始化的資料庫重複執行不產生重複資料或錯誤。

**Why this priority**: 波 0 出口條件明列「migration up→down→up 守恆」；這是後續所有 migration 工序的信心基礎，但不阻擋基線本身的價值交付。

**Independent Test**: 對同一資料庫執行「初始化→完整回滾→再初始化」三段，每段成功且終態通過 US1 的零漂移驗證；再次重複執行確認冪等。

**Acceptance Scenarios**:

1. **Given** 已完整初始化的資料庫，**When** 執行完整回滾，**Then** 全部表（含政策表）乾淨移除、回滾成功結束
2. **Given** 回滾後的空庫，**When** 重新初始化，**Then** 成功且終態與首次初始化等價（零漂移驗證重跑仍綠）
3. **Given** 已初始化的資料庫，**When** 重複執行初始化，**Then** 成功返回、無重複資料、無錯誤（冪等）

---

### Edge Cases

- **diff 假紅源**：兩側獨立執行必然產生不同的隨機 token 行、密碼雜湊、時間戳與序列狀態值——正規化規則 MUST 明定並覆蓋，否則零漂移驗證不可信（假紅＝驗證流程缺陷、非交付物缺陷）
- **欄位順序漂移**：結構比對對欄位順序敏感——基線 DDL 必須重現前代歷史疊加後的欄位順序，邏輯重排即假紅
- **demo 選單枚舉重疊**：demo 種子若與基線選單／政策重複，違反「基線不變」不變式——枚舉定稿時必須排除基線既有集合
- **前代參考資產不可用**：純淨參考庫重放依賴前代 repo 與既有映像於本機可用（前置假設）；不可用時零漂移驗證無法執行、驗收不得豁免改用其他證據
- **部分套用狀態**：初始化在基線與 delta 之間中斷時，重新執行應從中斷點續行至完整終態（框架追蹤表語意）

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 以單次初始化使空資料庫達到前代終態 schema——12 表口徑（10 業務表＋政策表＋框架追蹤表；政策表由單一 schema 來源建立〔⚠️v〕、框架追蹤表由框架自建）；基線維持前代事實：零 FK、3 個 soft-delete 部分唯一約束、2 個全表唯一約束、7 個一般索引、審計欄四變體分布
- **FR-002**: 基線種子 MUST 為前代終態淨效果——**92 列／6 表**（使用者 3、角色 3、使用者-角色 3、選單 10、政策 72、系統設定 1），歷史回填修補（暱稱別名、狀態值、首頁鍵、按鈕註冊表、保護旗標）以淨值直接寫入、不重演修補過程
- **FR-003**: 系統 MUST 提供零漂移驗證流程——於**基線檢查點**（delta 套用前）與前代純淨參考庫（由前代既有資產重放產生）做結構＋6 表種子資料雙向比對，正規化後零差異；正規化規則明定（隨機 token 行、框架追蹤表內容、密碼雜湊、時間戳、序列狀態值）
- **FR-004**: rev3 改良 MUST 與基線顯式分離為獨立步驟：join 表參照完整性（④拍板）與 demo 頁選單種子（⚠️p 拍板）各自獨立、可獨立審計；delta 僅新增、不改寫基線列
- **FR-005**: 預設帳號 MUST 為 `Super`／`Admin`／`User`（§I.3 凍結命名）、共用單一執行期生成之 argon2id 雜湊、皆可驗證通過 `123456`；種子不寫死識別碼（依序列產生，空表確定性落 1／2／3）
- **FR-006**: demo 頁選單種子 MUST 初始僅授超級管理員角色（⚠️p：可見性下放交角色勾選層治理）；枚舉以前端 route 樹為權威定稿
- **FR-007**: 每個 migration MUST 具對稱回滾；完整鏈 up→down→up 守恆（回滾後重建終態與單次執行等價）
- **FR-008**: 對已初始化資料庫重複執行 MUST 冪等（成功返回、無重複資料）
- **FR-009**: 政策表 schema MUST 維持單一來源（⚠️v 拍板：委派 vendored adapter 建基底＋治理欄擴充同步；不得另立手寫 DDL 形成雙來源）
- **FR-010**: 本刀新增 workspace 成員後，建置完整性 MUST 由 prod target image build 驗證（CLAUDE.md §3 紀律——防 dev bind-mount 遮蔽建置缺口）

### Key Entities *(資料基線一覽；逐欄定義屬 plan 期 data-model)*

| 群組 | 表 | 要點 |
|---|---|---|
| A 業務主表 | sys_user(16)・sys_role(12)・sys_menu(28)・system_settings(10) | 完整審計 6 欄＋soft-delete；前三者配部分唯一約束 |
| join | sys_user_role(2) | 複合 PK、硬刪、零審計；delta 後帶 FK ×2 |
| C 狀態機 | sys_token(9) | token_hash 全表唯一＋3 索引 |
| B append-only | sys_operation_log(10)・sys_access_log(10)・sys_login_attempt(9) | 僅 created_at；不得有 update／delete 欄 |
| D 治理 | casbin_rule(11) ⇄ sys_casbin_policy_archive(13) | 政策表＝adapter 基底 8 欄＋治理 3 欄；archive 帶 2 索引 |
| 框架 | seaql_migrations | 框架自建、不入 migration、排除於比對 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 基線檢查點的結構比對與 6 表種子資料比對，正規化後**雙向 100% 零差異**
- **SC-002**: 基線計數不變式全中：92 列／6 表、政策 p 型 72／g 型 0、受保護政策 19、受保護選單 8、預設帳號識別碼 1／2／3
- **SC-003**: up→down→up 三段全綠，且重建後零漂移驗證重跑仍綠（終態等價）
- **SC-004**: 預設帳號雜湊驗證 `123456` 通過率 3/3
- **SC-005**: delta 斷言全綠：join 表 FK ×2 存在、demo 選單／政策列數＝枚舉定稿數、基線 92 列原值不變
- **SC-006**: 001 交付的 dev stack 上 migrate gate 自動套用全鏈後，API 服務照常進入健康狀態（基線對既有 stack 零破壞）
- **SC-007**: prod target image build 成功（新增 workspace 成員的建置缺口為零）
- **SC-008**: 重複執行初始化第二次成功返回且資料列數不變（冪等 100%）

## Assumptions

- 前代（rev2）outer repo 與其既有容器映像於本機可用——純淨參考庫重放與源碼對照的素材來源（DESIGN 既定）
- 001 交付的 dev stack 為本刀驗證基建（migrate gate、容器內資料庫工具鏈 17.10——host 端工具版本不相容已實證、一律走容器內）
- demo 頁枚舉數量於 plan 期以 base-web route 樹定稿（本 spec 不鎖數）；⚠️c 三頁（alova/request・alova/scenes・function/request）為枚舉子集；echo／captcha 端點之政策隨端點交付刀、不在本刀
- join 表 FK 的刪除行為工程預設為限制式（RESTRICT——主表走 soft-delete、硬刪不應發生），plan 期確認
- 業務 API 與 entity 層不在本刀（schema 的程式消費者＝後續刀）；vendored adapter 之拷貝屬 §I.5 明文例外、xdb 不在本刀
- 雜湊參數沿 vendored 函式庫預設（argon2id v=19）；對照前代活庫實證一致
- 依賴鎖檔變動後複驗 time crate 不在依賴圖（在圖時依既載對策補 pin）
- 本刀為 schema／seed／驗證基建，無業務邏輯純函式——單元測試策略於 plan 期依 CLAUDE.md §3 紀律明示；驗收以實機 C-V 全覆蓋
