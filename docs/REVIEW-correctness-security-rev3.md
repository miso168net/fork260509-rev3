# REVIEW-correctness-security-rev3：rev3 整合碼 correctness + security 審查

**日期**：2026-06-25
**範圍**：rev3 整合碼（rust-api 全新寫 + base-web rev3-inline delta），spec-compliance（[REVIEW-001-019](REVIEW-001-019.md)）**之外**的 correctness bug 與可利用 security 弱點。
**方法**：兩輪 Workflow fan-out——correctness（13 風險區）＋ security（9 風險區），每區 finder 套用角度 → 每候選 1-vote 對抗式查證（CONFIRMED / PLAUSIBLE / REFUTED）。**靜態審查**（並發護欄、不跑 cargo/pnpm/CDP）。
**為何用 Workflow 而非 `/code-review`/`/security-review` skill**：兩 skill 皆 diff-based 於當前 branch，但實際碼在 submodule worktree、被 gitlink 遮住（outer diff 為空/僅 docs）——skill 的 diff-model 不適配本 repo 結構，故以同等角度方法論 fan-out 到 worktree 碼。

## 總結

| 輪 | CONFIRMED | PLAUSIBLE | REFUTED |
|---|---|---|---|
| correctness | 13（3 high / 6 med / 4 low） | 18 | 6 |
| security | 4（3 high〔同根 CSV injection〕/ 1 low） | 17 | 2 |

**真缺陷集中於少數可修點**；多數 PLAUSIBLE 為 hardening/edge 或 spec 已拍板取捨。下方依「建議修先後」triage（已去重跨輪重複項）。

---

## 🔴 高優先（建議修）

### H-1 [SEC, CONFIRMED high] 審計 CSV 匯出 formula/CSV injection
- **檔**：`rust-api/server/src/handler/system_manage.rs:550-556`（`csv_escape_field`）
- **問題**：`csv_escape_field` 只做 RFC4180 quote-escaping（包 `"`、`"`→`""`），**未中和試算表公式觸發字元** `= + - @`、leading TAB/CR。攻擊者可控欄位原樣寫入 CSV cell。
- **威脅**：★ **未認證可注入**——`attempted_user_name`（login 失敗即寫、未認證可控）、`X-Forwarded-For` header（逐字存鑑識）、`trace_id`、`region` 皆流入三審計表 CSV。admin 匯出後用 Excel/Sheets 開啟 → 公式執行（資料外洩 / DDE 命令）。
- **修**：cell 若以 `= + - @ \t \r` 開頭，前綴單引號 `'`（OWASP CSV injection 標準緩解）後再 RFC4180 quote。單一 helper 修一處覆蓋三表。
- **狀態（2026-06-25 已閉合）**：`csv_escape_field` 首字 ∈ `{= + - @ \t \r}` 前綴 `'` 再走既有 RFC4180 quote（單一 helper 覆三表 export）。單元測 `csv_escape_field_neutralizes_formula_triggers` 綠。rust-api `6017732`。

### H-2 [COR, CONFIRMED high] self-lock 守門可繞過（representation 不一致）
- **檔**：`rust-api/server/src/handler/system_manage.rs:631-632`（`self_lock_violation`）+ `:974`（update_user）
- **問題**：守門用字面字串 `new_status == Some("2")` 比對，但持久化 status 走 `i16::parse`（接受 `"02"/"002"/"+2"`）。超管送 `{status:"02"}` 可繞過防自鎖、自我停用。
- **修**：守門前先 parse-normalize（與持久化同款 `i16` 解析）再比對，而非字面字串。
- **狀態（2026-06-25 已閉合）**：`self_lock_violation` 改 `normalize_enum_filter(new_status)==Ok(Some(2))`（與持久化 `map_enum` 同款 i16 normalize）；`"02"/"002"/"+2"` 皆擋、畸形值 normalize 失敗→與持久化端一致放行。單元測 ×3 綠。rust-api `6017732`。

### H-3 [COR, CONFIRMED high] policy watcher「fail-OPEN」實為 fail-CLOSED deny-all
- **檔**：`rust-api/server/src/main.rs:714-728`（`spawn_policy_watcher` reload）
- **問題**：casbin `Enforcer::load_policy()` **先 clear in-memory model 再讀 adapter**；adapter DB 暫錯時 model 已清空、未重填 → enforcer 變【空策略＝全拒】。但程式註解寫「fail-OPEN 忽略」——語意與實效相反（實為 deny-all）。invalidate 訊息來時若 DB 抖動 → 全站授權暫時全拒，直到下次成功 reload。
- **修**：reload 失敗時保留舊 policy（先 load 到暫存 enforcer 成功才 swap，或失敗時觸發重試/不 clear）；至少修正註解並加 retry。
- **狀態（2026-06-25 已閉合）**：新增 `reload_enforcer_preserving`——先 `build_fresh().await?`（失敗早退、現役 enforcer 不取 write lock、live model 從未被 clear）、成功才 `*guard=fresh` 整顆原子替換；watcher reconnect 補 reload 與收 invalidate 兩處皆改經 helper；註解校正為實情。單元測 `auth_reload_preserving_{failure_keeps_old_policy,success_swaps_policy}`（MemoryAdapter、無 DB）綠、主線二次自驗確認 failure 後 R_SUPER 仍允許。rust-api `cda07e9`。

### H-4 [COR, CONFIRMED high] 審計日期範圍 end-of-day off-by-one（前後端同病）
- **檔**：base-web `views/manage/audit/modules/{login-attempt,access-log,operation-log}-table.vue` 的 `onDateRangeChange`；rust `system_manage.rs:453-471`（`parse_audit_date`）
- **問題**：daterange 結束時戳直接 `new Date(value[1]).toISOString()` / `parse_audit_date` 把 `createdTo` date 解析成當日 **00:00:00**，`CreatedAt.lte(created_to)` → 排除結束當天全部紀錄；單日選取 → 0 筆。
- **修**：`createdTo` 補到當日 23:59:59.999（或改 `< 隔日 00:00`）；前端 NDatePicker 設 `:default-time` 或後端 parse 補 end-of-day。
- **狀態（2026-06-25 已閉合）**：後端 `parse_audit_date` 對 date-only `End` 補 23:59:59.999999999、對完整 RFC3339 as-is（已修）；前端三 `*-table.vue` `onDateRangeChange` 對 `createdTo` 補 `setHours(23,59,59,999)`（已修，與後端 RFC3339-as-is 不重複調整）。前後端兩半皆閉合。

---

## 🟠 中優先

| # | 輪/票 | 檔 | 問題 | 修向 |
|---|---|---|---|---|
| M-1 | COR C-med | `sys_casbin_rule.rs` set_role_endpoints:301-373 | 寫接受任意 method 字串、讀只認大寫白名單 → 小寫/`HEAD` 造隱形 orphan 列、再寫 UNIQUE 撞 5000 且 UI 不可撤（curl 繞 base-web 才觸發） | handler 驗證/normalize method 為大寫白名單之一、拒非法 |
| M-2 | COR C-med | `sys_user.rs` soft_delete:60-95 | 用 `find_by_id`（含已刪）→ 對已刪 user 重刪覆蓋 `deleted_at/deleted_by`+重發審計 | soft_delete 前守 `deleted_at IS NULL`、已刪則 no-op |
| M-3 | COR C-med | `sys_user.rs:255` + update_user | `am.status = Set(fields.status)` 無條件；省略 status → `Set(None)` 寫 NULL（session_policy 有 Some-only 守、status 沒） | status 改 Some-only 條件設（對齊 session_policy） |
| M-4 | COR C-med | `redis.rs:122-135` subscribe_pubsub | 重連無 timeout（`connect()` 有）→ SYN-blackhole 永久 hang、watcher backoff 永不觸發 | 包 `tokio::time::timeout(5s)`（鏡像 connect()） |
| M-5 | COR C-med | `main.rs:557-588` prometheus ::pair() | 裸 pair 無 group_patterns → 404 請求 endpoint label 退回原始 URI → 掃描不存在路徑＝metric 無界基數膨脹（記憶體） | 用 builder + `with_group_patterns_as` 或對 unmatched 歸一 label |
| M-6 | SEC P-med | `system_manage.rs` update_role_{endpoints,button,menu} | grant 路徑零「no-escalation/單調性」守門：持編輯端點之角色可授自己任意端點（deleteUser/addRole…）→ 提權至 super；protected 只擋撤銷不擋授予。現僅靠 seed 慣例（編輯端點限 R_SUPER）非程式不變量 | 加 grant 守門（operator 只能授自己已有的端點／禁自授／或明示登記此信任邊界） |
| M-7 | SEC P-med | `audit_ctx.rs:329-338` | CF-Connecting-IP/X-CF-Verified 防偽完全外包 nginx；繞過 nginx 直連 :31081（同 bridge 容器/誤配對外）可自帶偽 header 污染鑑識欄+per-ip 計數 | 確保 backend port 不對外（部署）+ 文件化信任邊界；或 peer 再核 |
| M-8 | SEC P-med | `deploy/nginx/conf.d/prod.conf:19-23` | prod 缺 CSP/Referrer-Policy/Permissions-Policy（只 HSTS+X-Frame+X-Content-Type）；admin SPA 無 CSP 防線 | prod.conf 補 CSP 等 header（與 §3.A prod 硬化合併） |
| M-9 | SEC P-med | `deploy/nginx/nginx.conf` | edge 無 limit_req/limit_conn → 未認證可無節流暴打 /api/auth/login（lockout 之外的網路層防線缺） | nginx 加 limit_req zone（public 端點）；與 §3.A 合併 |

---

## 🟡 低/已知/已拍板取捨（不建議現修、登記可見性）

- **[accepted] lockout fail-OPEN**（count DbErr→unwrap_or(0)→放行）：spec D-07/FR-010 明示接受（DB 抖動不擋登入入口）。
- **[accepted] per-user lockout DoS**（未認證鎖他人帳號 ≤15 分）：spec line 19/Edge/FR-009 拍板取捨、滑動窗自動解。
- **[accepted] IPv6 per-ip 規避**（/128 精確比對、/64 輪換規避）：**已登記 [CHECKLIST §4.2](INTEGRATION-CHECKLIST.md)**（本次 security 獨立再證、與該 backlog 一致）。
- **[accepted] 寬 internal_default 信任**（10/8 等私網當受信 proxy）：013 spec 明示「網路信任邊界破壞」排除於範圍外。
- **login timing oracle**（not-found 不跑 argon2、exists 跑 → 帳號枚舉 side-channel）：spec 防枚舉僅涵蓋內容可觀測欄位、未涵蓋 timing。緩解＝not-found 跑 dummy argon2 拉平。**新登記項**（非 spec 接受、屬殘留 side-channel、low）。
- **/auth/refreshToken 無節流**（refresh 端 lockout 不覆蓋）：條件式 DoS、需持有效 refresh token。hardening（與 M-9 nginx rate-limit 合併可緩解）。
- **op-log payload PII**（user_phone/user_email 進 op-log payload、僅 password redact）：隱私可見性，視合規需求決定是否 redact。
- **trace_id log-injection**（x-request-id 未濾控制字元 → 進 log/CSV）：與 H-1 CSV injection 同源上游、修 H-1 + trace_id 濾 CR/LF 一併。
- **CONFIRMED low（correctness）**：Tier-1 CDN 錨左掃不驗 untrusted（audit_ctx:158-167）、XFF take(32) 含空 token 預算（:217）、lockout count 非原子 race（門檻可微幅穿越）、m004 down 非對稱 casbin DELETE（誤刪他角色 runtime 授的 demo route policy）。
- **PLAUSIBLE 其餘**：reparent_check TOCTOU、roles_of_user 未濾 soft-deleted 角色（authz 用）、wire_id 2^53 邊界差一、batch sentinel DbErr 脆弱、denylist TTL(1h)<refresh(7d)、pruneNullParams 數字 0、route store 同名覆蓋、roleId `||-1` falsy-0、TLS ssl_protocols 未顯式硬化、/metrics exact-match 依賴 nginx 正規化等。

---

## 修復建議優先序

1. ✅ **H-1~H-4 全閉合（2026-06-25）**＝CSV injection／self-lock 繞過／watcher deny-all／date off-by-one；TDD +8 rust 單元測、179 passed 零回歸、主線獨立自驗。rust-api `6017732`+`cda07e9`、base-web `f334feec`、outer pin `55dec914`。
2. **M-1~M-5**＝correctness medium、逐項小修 → 登 [CHECKLIST §3.E](INTEGRATION-CHECKLIST.md) 本版觸發時做。
3. **M-6~M-9**＝security/prod 硬化 → 登 [CHECKLIST §3.A／§4.2](INTEGRATION-CHECKLIST.md)（部分與既有 prod 硬化合併）。
4. 🟡 區登記可見性、依合規/部署需求排程（含新登 timing oracle／op-log PII／trace_id log-injection）。

> 註：本兩輪為**靜態審查**（不跑 cargo/CDP）；修復後須各以對應測試/CDP 驗。findings 全文（含 PLAUSIBLE 完整 reasoning）見 workflow 輸出。spec-compliance 視角見 [REVIEW-001-019](REVIEW-001-019.md)。
