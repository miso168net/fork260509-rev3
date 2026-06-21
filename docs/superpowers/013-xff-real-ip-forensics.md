# 013 · XFF → real_ip Forensics — spec-design（Phase 0 brainstorm）

> **性質**：spec-kit feature **013** 的 Phase 0 brainstorm spec-design（CLAUDE.md §3 階段 0 產物）。本檔聚焦**需求 / 範圍 / 驗收 / 審計面 / 實作單元 / 已拍板選擇**；演算法、12 個案例、信任地基、逐層改動細節見 `docs/superpowers/000-rust-api-xff-real-ip-research.md`（下稱 **research**）。
> **下一步**：手動跑 `/speckit-specify`（階段 1；`before_specify` pre-hook 建 feature branch `013-xff-real-ip-forensics`）。
> **接地 pin**：rust-api `fca64a0`（research §8 現況快照）。

---

## 1. Feature 一句話

把 rust-api 既有「單值 XFF 解析」重寫成**兩層信任模型 + IIS 正規化 + CF-Connecting-IP 交叉驗證 + Cloudflare Tunnel 支援**，並把「直連 peer / 解析後 real_ip / 原始鏈 / 可信度」**四欄**存入三張審計表、在 012 審計中心**全顯示且全可篩**做鑑識。

## 2. 問題 / 動機（簡，詳 research §1–2）

現況 `resolve_client_ip`（`server/src/audit_ctx.rs`）是**單一信任集 rightmost-untrusted**：無 CDN 位置錨、無 IIS 正規化、無可信度、**直連 peer 算了即丟**。面對多層反代 / CDN / 自有 public IP 雙重身分 / IIS 雜訊 / Cloudflare Tunnel 等真實拓樸會解錯或丟資訊。對應 DECISIONS §2 的 **D11 遞延刀**。

## 3. Scope

### 3.1 In scope
- IIS-aware 正規化（research §3.1）
- 兩層解析回 `(real_ip, confidence)`：peer-gate / **Tier-1 CDN 位置錨〔不硬 gate〕** / my-public+binding 走訪（research §3.2）
- CF-Connecting-IP overlay + nginx `geo` 閘（research §3.3 / §6）
- Cloudflare Tunnel 支援（research §13）
- 結構化 TOML 信任 config（research §5）
- 四欄 forensic 儲存 × 三審計表 + `m006` migration（research §7 / §8.3）
- 012 審計中心 IP 鑑識面：四欄全顯示 + 三模糊篩 + 一下拉篩（§7）

### 3.2 Out of scope / deferred
- 反爬蟲 / 限流（原 PHP 下半、research §2 擱置）
- CF IP 段**內建 + cron 自動更新**（決：全手動 config、operator 自填自更）
- True-Client-IP（CF Enterprise 限定）
- IP 範圍 `a-b` / netmask 比對（原 PHP 有、CF 清單用不到）
- 012 其他遞延項（retention / CSV 匯出 等）

## 4. 設計綱要（已定案；詳見 research §3–8）

- **解析**：normalize →〔A peer-gate→`DIRECT`〕〔B CDN 位置錨：最右 CDN 左一非 CDN→`CDN_ANCHORED`，**不要求 X-CF-Verified**〕〔C Tier-2：由右而左 skip `internal_default ∪ my_public ∪ binding.internal`、第一個非受信→`PROXY_CLEAN`／`PROXY_SOFT`〕〔整鏈受信→`FALLBACK`(peer)〕→ overlay。
- **CF overlay**（top-level、**不改 real_ip**）：`X-CF-Verified=1` 且 `CF-Connecting-IP` 有值 → `CDN_VERIFIED`(相符)／`CDN_MISMATCH`(不符)。
- **confidence 七態**：`cdn_verified / cdn_anchored / proxy_clean / proxy_soft / direct / cdn_mismatch / fallback`。
- **config**：TOML `TrustModel{ cdn(+connecting_ip_header) / my_public(+dual_role) / internal_default / bindings }`、boot-only、缺檔 fallback flat `TRUSTED_PROXY_CIDRS`。
- **儲存**：三表四欄、`real_ip`=現 `client_ip`/`operator_ip` 改名、新欄 nullable、`m006` 可逆。
- **nginx**：`geo $remote_addr` 蓋 `X-CF-Verified`（CF 邊緣段 ∪ cloudflared ingress）、轉發/strip `CF-Connecting-IP`、**不啟 realip**。
- **威脅模型**：header 可偽造，信任建在**網路層「origin 不可繞過直達」**（regular=防火牆 allowlist CF；tunnel=無 public inbound）。

## 5. Functional Requirements

- **FR-1 正規化**：XFF 切分吃 `[\s,+]`、per-token trim、剝 port（v4 `:port`、v6 `%zone` 與 `[..]:port`）、validate、drop invalid。
- **FR-2 兩層解析回 `(real_ip, confidence)`**：peer-gate(`DIRECT`)／CDN 位置錨〔最右 CDN 左一非 CDN、**不要求 X-CF-Verified**〕(`CDN_ANCHORED`)／Tier-2 skip-set 第一個非受信(`PROXY_CLEAN`)／整鏈受信回 peer(`FALLBACK`)。
- **FR-3 Tier-2 迭代 + 軟評分**：my-public 連續多跳逐點 skip；binding 相鄰內網不符 / `dual_role` 命中 → `PROXY_SOFT`（不停線、保留 positional real）。
- **FR-4 CF overlay**（不改 real_ip）：`X-CF-Verified=1` ∧ `CF-Connecting-IP=cip` ∧ base∈{anchored,clean,soft} → `cip==real ? CDN_VERIFIED : CDN_MISMATCH`。
- **FR-5 信任 config**：TOML `TrustModel` boot 載入（CIDR 欄字串收 + post-load `parse::<IpNetwork>()`）；缺檔 fallback flat env；誤配 fail-safe 退保守。
- **FR-6 儲存四欄 × 三表**：`peer_ip`／`real_ip`(←`client_ip`)／`x_forwarded_for`／`ip_confidence`（operation_log 對應 `operator_*`）；新欄 nullable；entity 與 `m006` 同步。
- **FR-7 nginx**：`geo $remote_addr`→`X-CF-Verified`（CF 邊緣段 ∪ cloudflared ingress）；verified 才轉 `CF-Connecting-IP`、否則 strip；不啟 realip；既有 `X-Real-IP`/`X-Forwarded-For`/`X-Forwarded-Proto`/`X-Request-Id` 不 regress。
- **FR-8 region/xdb**：繼續對 `real_ip` 解析（語意不變、IPv4-only 降級不變）。
- **FR-9 012 審計面**：四欄全顯示（順序見 §7）+ 三模糊篩 + 一下拉篩；honest wire（nullable 顯 null 不 skip）；`ip_host_like` 套 `real_ip`/`peer_ip`。
- **FR-10 migration m006 可逆**：up rename+add、down 嚴格反序；m001 凍結。

## 6. Success Criteria（驗收）

- **SC-1**：純測涵蓋 normalize（混切 / 剝 v4·v6 port / garbage drop）、兩層四分支、`dual_role` 軟評分、overlay 矩陣；8 個既有 `resolve_client_ip` 測重映射到 `(IpAddr,Confidence)`。
- **SC-2**：live smoke（容器內、`DATABASE_URL`、`--test-threads=1`）以 psql 證三表四欄真寫入（best-effort warn-drop、不可只看 HTTP 200）。
- **SC-3**：migration `up→down→up` 可逆 + fresh DB 全鏈 `m001..m006`。
- **SC-4**：research §4 的 **12 案例** real_ip + confidence 符合預期（轉成解析測）。
- **SC-5**：012 CDP 驗——四欄按 §7 順序顯示 + `ip_confidence` NTag 著色 + 三模糊篩（real_ip/peer_ip/xff）+ `ip_confidence` 下拉篩 都運作；filter 改名後仍發 API（curl 帶空 param 抓守門回歸）。
- **SC-6**：**prod target image build** 編得過（新 `toml` workspace dep、multi-stage COPY 無缺口）。
- **SC-7**：零回歸（既有 nginx header / 007 audit live path / `ip_host_like` / 012 既有行為）。

## 7. 012 審計中心 IP 鑑識面（C1/C2 拍板）

**顯示 column（四欄全顯示、左→右順序）**：
```
ip_confidence  →  peer_ip  →  real_ip  →  x_forwarded_for
（可信度 NTag）   （直連 peer）  （解析真值）   （原始鏈）
```
- 三分頁同序；**operation 分頁**用 `operator_` 前綴對應（`operator_ip_confidence` / `operator_peer_ip` / `operator_real_ip` / `operator_x_forwarded_for`）。
- 四欄佔據現有「單一 IP column」位置展開；相對其他欄（operation/method/status·operator·time·payload）就近擺、scroll-x 視寬度上調。
- `ip_confidence` 以 **NTag 依七態著色**（如 `cdn_verified` 綠／`cdn_mismatch`·`fallback` 紅灰）。

**搜尋 filter（型別分流）**：

| 欄 | 篩法 |
|---|---|
| `real_ip` | **模糊** — IP `host(col)::text LIKE`（現有 clientIp 搜尋改名） |
| `peer_ip` | **模糊** — IP `host(col)::text LIKE`（沿同一 seam、net-new） |
| `x_forwarded_for` | **模糊** — 文字 `LOWER(col) LIKE`（搜原始鏈子字串；012 現已有） |
| `ip_confidence` | **下拉精確** — enum 7 值 `eq`（非模糊；篩低可信列做複查） |

## 8. 實作單元（10 層、research §8.2；階段 2 由 Workflow 編執行單元）

`L1` 解析核心｜`L2` config 載入｜`L3` state+main｜`L4` entity×3｜`L5` migration m006｜`L6` op-log threading｜`L7` 012 讀端 handler+facade｜`L8` base-web typings+view+i18n｜`L9` nginx｜`L10` compose env。
> 相依：L4↔L5 必同 commit；L1→L2→L3 序；L6/L7 依 L1 的 `Confidence`/`IpForensics`；L8 依 L7 wire（含 §7 的欄順序/篩選）；L9/L10 獨立可平行。實際執行單元由階段 2 `executing-plans` 依 tasks.md 真實相依重組。

## 9. 已拍板的設計選擇

**brainstorming 拍板（user）**：
- **C3** Tier-1 CDN 錨 = **不硬 gate**（維持位置錨；防注入假 CDN IP 靠網路層主防線 + `CDN_ANCHORED`≠`CDN_VERIFIED` in-band 訊號）。
- **C2** 顯示 column = **四欄全顯示**（順序見 §7）。
- **C1** 搜尋 filter = **三模糊（real_ip/peer_ip/x_forwarded_for）+ 一下拉（ip_confidence）**（§7）。

**engineering 預設（已定）**：
- `ip_confidence` = **TEXT**（直存 enum 小字串、entity `Option<String>` 直映、無 i16 映射層）
- `AuditOperator` 維持 **`Copy`**（peer/real 走 operator、xff/confidence 走 AuditEvent）→ 不動 16 facade 簽名
- confidence wire = **literal union**（對齊 rust serde 7 字串）
- `dual_role` 降級規則：Tier-2 走過 `dual_role` IP 又解出更左值 → `PROXY_SOFT`

## 10. 留待 plan/impl 階段定（非 feature-shaping、無 user 拍板）

- `TRUST_MODEL_FILE` 確切 env 名 / TOML 路徑 / dev·prod bind-mount point（`deploy/` 下、預設值即可）
- `toml` crate 確切版本 pin（0.8 parse-only、Cargo.lock 釘版、容器內驗 1.86 編得過、§6 全域紀律 surface）
- CF edge CIDR 集（operator config 自填官方 list + cloudflared docker bridge 實際段；code 不內建）

## 11. Constitution / 紀律對齊

- **審計表 ALTER**＝Constitution §I.6 archetype 既有審計表的破例（六審計欄未觸、本案動 IP 欄 + 改名）；須對齊 DESIGN §3.2（審計欄 archetype）/ §3.4（schema 演進紀律）。`/speckit-plan` 的 Constitution Check 須過。
- **新 workspace dep `toml`** → `contracts/verification-commands.md` 必含 **prod target image build**（§3 Phase 1 紀律、SC-6）。
- **階段 2 紀律**：rust 全程 serial、容器內 `docker exec` build/test（live `--test-threads=1`）、base-web `--no-verify`、★ **絕不 `push`/`merge` until `finishing-a-development-branch`**。
- **逐單元兩段式 commit + bump submodule pin**（S9）。

## 12. References

- **research**：`docs/superpowers/000-rust-api-xff-real-ip-research.md`（演算法 / 12 案例 / 信任地基 / 逐層改動 / m006 DDL / nginx geo / config）
- DECISIONS §2（012-audit-log-query 遞延項 **D11**）
- DESIGN §3.2（審計欄 archetype）/ §3.4（schema 演進紀律）
- Constitution §I.6（archetype A 審計欄）
