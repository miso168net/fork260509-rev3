# Feature Specification: infra-deploy（rev3 部署地基）

**Feature Branch**: `001-infra-deploy`

**Created**: 2026-06-13

**Status**: Draft

**Input**: User description: "docs/superpowers/001-infra-deploy.md（rev3 波 0 第一刀 Phase 0 brainstorm：master compose 5 service＋deploy/ 裁剪帶入＋rust-api 最小 scaffold＋migrate gate；五項拍板＋⚠️t）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 一鍵啟動完整開發環境 (Priority: P1)

開發者在本機以單一啟動命令拉起 rev3 完整開發 stack：統一入口（front-nginx）、前端（base-web）、後端 API（rust-api）、資料庫（postgres）、快取（redis-stack）五個服務全部進入健康狀態；資料庫 schema 初始化步驟（migrate）在 API 啟動前自動完成。

**Why this priority**: 這是 rev3 全部後續開發刀的執行地基——沒有可一鍵啟動的 stack，後續每一刀的驗收（curl／CDP／psql）都無從進行；也是 DESIGN §8.4 波 0 出口條件「dev stack `up --wait` 全 healthy」的直接載體。

**Independent Test**: 乾淨 checkout＋本機生成機密後，執行 dev 啟動命令，等待退出碼 0；逐一檢查 5 服務健康狀態與 migrate 完成狀態；對 6 個連通點（入口 HTTP／HTTPS、API 直連、前端直連、資料庫、快取）逐項驗證。

**Acceptance Scenarios**:

1. **Given** 機密檔已生成、無容器在跑，**When** 執行 dev 組合啟動命令並等待，**Then** 命令以成功狀態結束，5 服務全部 healthy、migrate 顯示成功完成
2. **Given** stack 運行中，**When** 依序檢查入口 HTTP（:31080/health）、入口 HTTPS（:31443/health，自簽憑證）、API 直連（:31081/health）、前端（:31079）、資料庫（:35432）、快取（:36379），**Then** 六項全部回應正常
3. **Given** stack 運行中，**When** 查看服務啟動時序，**Then** migrate 在資料庫 healthy 之後執行、且在 API 服務啟動之前成功退出（閘門順序可證）
4. **Given** stack 已停止（資料卷保留），**When** 再次啟動，**Then** 啟動成功且先前寫入資料庫的測試資料仍在（持久化）

---

### User Story 2 - 統一入口路由 (Priority: P2)

使用者透過單一入口存取整個系統：根路徑到前端頁面、`/api/` 前綴到後端 API（前綴在轉發時剝離）、內部專用端點對外不可見。

**Why this priority**: 入口路由是 prod 拓撲的核心形狀（DESIGN §7.4 凍結形），後續所有「經真實 `/api` 路徑驗收」的刀（波 1 出口條件）都依賴它正確；但它依附於 US1 的 stack 存在，故為 P2。

**Independent Test**: stack 運行中，對入口發出四類請求（根路徑、`/api/health`、`/api/metrics`、`/health`）並驗證各自的路由行為。

**Acceptance Scenarios**:

1. **Given** stack 運行中，**When** 請求入口 `/api/health`，**Then** 回應為後端 API 的健康回覆 `ok`（證明前綴剝離轉發成立）
2. **Given** stack 運行中，**When** 請求入口 `/api/metrics`，**Then** 回應 404（內部端點對外遮蔽）
3. **Given** stack 運行中，**When** 請求入口根路徑，**Then** 回應前端頁面內容
4. **Given** stack 運行中，**When** 請求入口 `/health`，**Then** 入口自行回應 `ok`（不依賴後端）

---

### User Story 3 - 正式組態起停演練 (Priority: P3)

維運者以 prod 組態（對外 80/443、HTTP 強制轉 HTTPS、憑證自具名卷載入）啟動同一套 stack 做部署演練，並能乾淨停止。

**Why this priority**: prod 組態與 dev 共享同一基底定義，本刀一併帶入可防兩組態漂移；但實際對外部署（真實憑證、網域）不在本階段，僅需起停演練成立。

**Independent Test**: 將開發憑證植入憑證卷後以 prod 組合啟動，驗證全服務 healthy 與 80→443 轉向行為，然後乾淨停止。

**Acceptance Scenarios**:

1. **Given** 憑證已植入具名卷，**When** 以 prod 組合啟動並等待，**Then** 命令成功、服務 healthy
2. **Given** prod stack 運行中，**When** 停止 stack，**Then** 全部容器乾淨退出、無懸掛資源

---

### Edge Cases

- 機密檔未生成即啟動：依賴該機密的服務應快速失敗且錯誤訊息可指向缺失的檔案，而非無聲卡住
- migrate 失敗（如資料庫不可達）：API 服務不得啟動（閘門保護），整體啟動以失敗收場而非帶病運行
- standalone base-web compose 與 master stack 同時啟動：前端埠號相同必然衝突——屬已知限制，操作上擇一運行（文件註明）
- prod 組態但憑證卷為空：入口服務啟動失敗屬預期行為（憑證植入是 prod 啟動前置步驟）
- 重複執行啟動命令：冪等，不產生重複資源或錯誤

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統 MUST 以單一命令組合啟動完整開發 stack（統一入口、前端、後端 API、資料庫、快取五服務＋一次性 schema 初始化步驟），並在全部健康後成功返回
- **FR-002**: 啟動順序 MUST 受閘門保護：資料庫與快取健康 → schema 初始化步驟成功完成 → 後端 API 啟動 → 入口最後就緒
- **FR-003**: 統一入口 MUST 將根路徑導向前端、`/api/` 前綴導向後端 API（轉發時剝離前綴）、`/api/metrics` 對外回 404、`/health` 由入口自答
- **FR-004**: 後端 API MUST 提供健康檢查端點（純文字回應，不走業務回應信封——對齊 constitution §I.3 universal 例外）
- **FR-005**: 全部機密 MUST 以檔案方式注入容器、不進版控；系統 MUST 提供機密生成腳本與範例檔，缺失機密時相關服務快速失敗
- **FR-006**: dev 與 prod 組態 MUST 共享同一基底定義（基底層不含對外埠號與環境專屬掛載）；prod 組態 MUST 將 HTTP 強制轉向 HTTPS（健康檢查路徑除外）
- **FR-007**: 資料庫與快取資料 MUST 經具名卷持久化（停止再啟動後資料保留），卷命名遵循 workspace 慣例（CLAUDE.md §8.2.2）
- **FR-008**: schema 初始化機制 MUST 就位且本階段空跑成功（零 schema 變更、成功退出）；初始化項目命名慣例（短編號 `mNNN_<name>`，拍板 ⚠️k）於結構中確立
- **FR-009**: 自既有部署資產（rev2）沿用的內容 MUST 完成 rev3 命名與埠號轉換（服務前綴、埠號段 2X→3X、卷前綴、快取映像鎖定數字版〔拍板 ⚠️d〕），轉換後 rev2 指涉歸零（目前無豁免項——部署層交付物不引用倉庫永久名）
- **FR-010**: 系統 MUST 提供後端 API 的獨立啟動組態（standalone，供單服務開發場景），與 master 組態並存

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 開發者自乾淨 checkout 起，最多兩個準備步驟（生成機密、生成開發憑證）＋一個啟動命令，即可達到全服務就緒
- **SC-002**: 啟動完成後，6 項連通檢查（入口 HTTP／HTTPS、API 直連、前端、資料庫、快取）100% 通過
- **SC-003**: 啟動時序證據可查：schema 初始化在 API 服務之前成功完成（閘門行為可驗證）
- **SC-004**: 停止後再啟動，資料庫內測試資料 100% 保留
- **SC-005**: prod 組態起停演練成功：憑證植入 → 啟動全 healthy → 乾淨停止，全程無錯誤
- **SC-006**: 部署資產中 rev2 指涉為零（目前無豁免項）
- **SC-007**: 經統一入口的 API 路徑往返成功（`/api/health` 回 `ok`），且內部端點（`/api/metrics`）對外不可達

## Assumptions

- rev2 outer repo 於本機可存取（裁剪帶入的素材來源；DESIGN 波 -1 既定策略「自 rev2 outer repo 帶入後依附錄 A 改名」）
- Docker 與 Docker Compose 版本沿 rev2 驗證過的環境（Docker 29.x／Compose v5.x），WSL2 mirrored networking（`127.0.0.1` 自 host 可達）
- 業務 schema 與 seed 屬 002 刀（拍板 ⚠️t：rev2 終態 squash 基線），本刀後端 API 僅提供健康檢查、不連資料庫；schema 初始化步驟連資料庫但空跑
- 前端 dev 模式沿用既有 standalone 定義（已實機驗證），本刀僅將其納入 master 組態
- 埠號段 3XXXX 於本機空閒（與 rev2 stack 2XXXX 並存不衝突）
- JWT 類機密本刀「接而不讀」（接線就位、消費屬後續 Auth 刀）
- 本刀為純 wiring／infra，無可獨立測試之純函式——驗收由實機 acceptance 全覆蓋（測試策略聲明將依 CLAUDE.md §3 紀律於 plan／tasks 明示）
