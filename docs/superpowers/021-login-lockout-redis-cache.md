# 021-login-lockout-redis-cache — spec-design（Phase 0 brainstorm）

> CLAUDE.md §3 階段 0 產物。交棒 → 手動 `/speckit-specify`（input＝本檔）起 `021-login-lockout-redis-cache` feature branch。
> 日期：2026-06-28。來源：Redis 使用全盤調查（rust-api）→ 發現 019-login-lockout 的 **DB 讀取/寫入放大風險** → user 提「鎖中記 Redis」方向 → 本 brainstorm 收斂。承接 [019-login-lockout](019-login-lockout.md)（被硬化的機制）；**帳號-DoS / IP 信任白名單 / CAPTCHA 切為 019 §4.2 既登記之獨立 future feature、不在本刀**（本刀僅留 forward-compat seam）。

---

## 1. 背景與目標

**問題（DB 壓力放大、攻擊面）**：019 login lockout 在 `login_inner` 前置對 PostgreSQL `sys_login_attempt` 做 **2 個 `SELECT COUNT(*)`（per-ip／per-user、無 LIMIT、各走複合索引）** ＋ 每次嘗試 **1 個 INSERT** 稽核列（成功與否、**含 gated 嘗試**＝sticky 審計）。在攻擊下，gate 成本**隨攻擊量無上限放大**：

- **第一線（已有）＝nginx `limit_req`**：`$binary_remote_addr` 5r/s burst40 套 `/api/`。→ **單一 IP 暴力**被擋在 5r/s、DB 壓力極小（**非問題**）。
- **真正的洞＝分散式打同一帳號（per-user 維度）**：botnet 多 IP（每 IP 低於 per-ip 門檻 20、不觸發 per-ip 鎖），聚合衝同一 `attempted_user_name`（如 `Super`）。nginx per-IP 限制**擋不住聚合速率**。該 username 在 15 分窗累積至數千萬列、每次 `count_failed_by_user_since` 的無-LIMIT COUNT 掃整坨 × 高聚合速率 → **PG CPU 飽和**；且**鎖中仍 count + 仍 INSERT**（正回饋）→ 數萬列/秒灌稽核表（WAL／表膨脹／autovacuum 追不上）→ **DB 飽和影響全系統**（非僅登入）。

**核心病灶**：lockout 自身成本與攻擊量成正比 → 「防爆破機制」變成「DB（與稽核表）放大器」（rate-limiter 設計經典陷阱：限流器必須比被保護的資源便宜）。

**目標**：讓 gate 成本與攻擊量無關（**鎖後 O(1)**），同時堵掉「讀取放大＋寫入放大＋稽核表被灌」三面，保留鑑識訊號與既有 fail-open；**DB 維持鎖定真相、Redis 為加速層**（掛了退回現有 DB gate、不破壞正確性）。

**範圍**：login gate 多一層 Redis 負快取（deny 層）＋鎖中寫入處置＋鑑識麵包屑。**非**：IP 信任白名單／CAPTCHA／帳號-DoS 緩解（019 §4.2、獨立 future、本刀僅留 seam）。

---

## 2. 拍板紀錄（user 親決 2026-06-28 brainstorm）

- **D1 快取兩維度（不只 real_ip）**：被判鎖時，依**觸發維度**寫 Redis——per-ip 觸發→`lockout:ip:{real_ip}`、per-user 觸發→`lockout:user:{name}`；每請求查兩 key、命中任一即短路。**理由**：只記 `real_ip` 擋不住分散式打單帳號——第 6 發來自**新 bot IP**（不在 ip 快取裡）、照樣 fall through 觸發 per-user COUNT；**per-user 才是放大向量**。記 `user:{name}` 後第 6 發起所有 IP 全在 Redis 命中。
- **D2 固定 TTL（③＝b）**：TTL＝窗 900s、**命中不 refresh**。→ 攻擊停止後 ~900s 內 key 過期 ＋ 真實失敗列 age-out → **自動解鎖（無需 admin 介入）**；不把鎖偷偷升級成「可被永久維持」（顧及帳號-DoS、白名單未上前的寬容）。**否決** refresh-on-hit（攻擊者每 <900s 戳一下即可永久鎖死 `Super`）。
- **D3 鎖中不逐筆寫 ＋ 節流麵包屑（②＝②b＋②c）**：
  - **②b**：被 Redis 快取命中短路的嘗試**不寫** `sys_login_attempt`；走到 DB gate 的嘗試（Redis miss、含**觸發鎖那一發**）照樣寫 → 稽核保留「上鎖前完整過程 ＋ 上鎖事件」、鎖後洪水不灌稽核表。
  - **②c**：鎖中 Redis `INCR lockout:suppressed:{key}` 累計（＋可選 `PFADD` HLL 估不同來源 IP 數）；**節流 ≤1 次/60s/key**（`lockout:flushed:{key}` TTL=60 當閘）flush 成**結構化安全 log 事件**（`target=security.lockout`、欄 `{key,dimension,suppressed,distinct_ips,window}`）→ 018 loki（**非** `sys_login_attempt` 列）。
  - **★ 有意識反轉 019 FR-004/FR-008**（gated 列逐筆 sticky 寫）→ 鎖後改節流摘要；**理由**：洪水下逐筆寫＝寫入放大 ＋ 攻擊者順便 DoS 稽核表 ＋ 使 D2 退化成永久鎖（窗被鎖中寫滿、過期即 re-lock）。

**工程拍板（我決、記錄；非 user 拍板級）**：
- **②c 落 loki log（非稽核表列）**：① **零 migration**（`sys_login_attempt` 無「數量」欄、塞「壓制 N 次」需加欄）；② **不污染鎖判定**（`success=false` 摘要列會被 per-user COUNT 算進、攪亂自癒時序）；③ 量級訊號本就屬 obs（可在 grafana alert）。稽核表保留「上鎖前真實逐筆 ＋ 上鎖事件」、量級訊號歸 obs——分工。
- **redis facade 小幅加 `incr`**（現有 get/set_ex/del/publish/subscribe、缺 incr；②c 需）；可選 `pfadd`/`pfcount`（distinct-IP HLL）。
- **不加 bounded-count(LIMIT)**：快取結構性使 COUNT 永遠只掃近乎空的窗（窗要變大前快取已短路）→ 無需改 COUNT 查詢。
- **reuse 019 政策值**：per-user 5／per-ip 20／窗 900s（＝TTL）；門檻/窗不變（runtime 可調仍 defer、019 §4.2）。
- **forward-compat seam**：gate 最頂端預留 trusted-IP bypass 插入點（**本刀不實作**；白名單 future feature 放此、跳過 Redis＋DB）。

---

## 3. Phase 0 研究實證（act-on-code 接地 @ 2026-06-28）

> 已核（exact 行號於 `/speckit-plan` research.md 再固化）：

- **login gate**（`handler/auth.rs:211-281`）：`since=now-900s`（:226-230）→ `count_failed_by_ip_since(&state.db, IpNetwork::from(ctx.client_ip), since)`（:231）＋ `count_failed_by_user_since(&state.db, &req.user_name, since)`（:238）→ `if is_locked_out(ip_fails,user_fails)` 短路 `Err((None, Biz("auth.login.locked")))` 否則 `login_inner`（:245-249）→ **單一寫點** `sys_login_attempt::write`（:256、含 gated、best-effort 吞 DbErr）。fail-OPEN：count DbErr→`.unwrap_or(0)`（:237/:241）。
- **consts/判定**（`auth.rs:55-69`）：`PER_USER_THRESHOLD=5`／`PER_IP_THRESHOLD=20`／`PER_USER_WINDOW_SECS=PER_IP_WINDOW_SECS=900`；`is_locked_out = ip_fails>=20 || user_fails>=5`；已有 `is_locked_out_for_test` 純測 seam（:74）。
- **COUNT 無 LIMIT**（`model/facade/sys_login_attempt.rs:66-97`）：`count_failed_by_*_since` ＝ `Entity::find().filter(RealIp/AttemptedUserName.eq).filter(Success.eq(false)).filter(CreatedAt.gte(since)).count(conn)`＝`SELECT COUNT(*)`、**無 LIMIT**（掃全部符合窗的列）；走 `idx_login_attempt_ip_time`／`idx_login_attempt_user_time`。`write`（:51）單 INSERT、archetype B append-only（D-04：`real_ip` 必 `IpNetwork::from(IpAddr)` 與寫端同款轉換）。
- **nginx limit_req**（`deploy/nginx/nginx.conf:85` + `conf.d/_locations.inc:19`）：`limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s` + `limit_req zone=auth_limit burst=40 nodelay` 套 `/api/`。→ 限**連線 IP**（CDN 後＝CDN edge IP）的 auth 速率、非聚合 per-user。
- **redis facade**（`server/src/redis.rs`）：`RedisHandle`（`MultiplexedConnection` + 獨立 `aio::PubSub`）暴露 `get`(:64)／`set_ex`(:78)／`del`(:88)／`set_revoked`／`revoked_at_of`／`publish`(:113)／`subscribe_pubsub`(:122)；**無 `incr`／`pfadd`／`pfcount`**（本刀 ②c 需加 incr、可選 pfadd/pfcount）。全 fail-OPEN（連不上→`None` 降級、個別 op 失敗→warn 吞）。`AppState.redis: Arc<Option<RedisHandle>>`（Redis-down → `None`）。
- **obs log（018）**：json tracing subscriber → loki 已就緒；`tracing::warn!(target:..., field=...)` 結構欄位 → loki `|json` 攤平、可 grafana 查/alert。

---

## 4. 設計細節

> 一刀 `021-login-lockout-redis-cache`、規模小-中。**執行單元（待 `/speckit-tasks` firm）**：單一 rust 執行單元為主（login gate 分層 + redis facade `incr` + obs log）；**無 base-web、無 migration**。

### 4.1 分層 gate（login 起手多一層、RUSTAPI-SOURCE-ISOLATION）

```
login(ip, name):
  # L0 [未來 seam] if trusted_ip(ip): bypass        ← 本刀不實作、結構預留（gate 最頂端）
  # L1 Redis 負快取（fast path、O(1)）；locked_key = 命中的 lockout key（ip:{ip} 或 user:{name}；兩者皆命中時各記）
  if redis.get("lockout:ip:"+ip).is_some() || redis.get("lockout:user:"+name).is_some():
       redis.incr("lockout:suppressed:"+locked_key)              # ②c 累計（帶 TTL）
       # 可選：redis.pfadd("lockout:supip:"+locked_key, ip)       # distinct-IP HLL
       if redis.get("lockout:flushed:"+locked_key).is_none():    # ②c 節流 ≤1/60s
            warn!(target:"security.lockout", locked_key, dimension, suppressed=N, distinct_ips)  # → loki
            redis.set_ex("lockout:flushed:"+locked_key, "1", 60)
       return Err(Biz("auth.login.locked"))                       # ②b：不寫 sys_login_attempt
  # L2 既有 DB gate（Redis miss＝真相、原邏輯不動）
  ip_fails   = count_failed_by_ip_since(...)    # 現有、unwrap_or(0)
  user_fails = count_failed_by_user_since(...)  # 現有、unwrap_or(0)
  if is_locked_out(ip_fails, user_fails):
       if ip_fails   >= PER_IP_THRESHOLD:   redis.set_ex("lockout:ip:"+ip,    "1", 900)   # D2 固定 TTL、不 refresh
       if user_fails >= PER_USER_THRESHOLD: redis.set_ex("lockout:user:"+name, "1", 900)
       r = Err(Biz("auth.login.locked"))                          # 觸發那發
  else:
       r = login_inner(...)                                       # 現有 6 路徑
  sys_login_attempt::write(...)                                   # ②b：Redis-miss 路徑照寫（含觸發那發）
  return r
```

### 4.2 關鍵性質
- 鎖後每請求＝1-2 個 Redis GET（**O(1)、與攻擊量無關**）；**DB COUNT 結構性永遠便宜**（窗要變大前快取已短路 → COUNT 只掃近乎空窗、連 bounded-count 都不必加）。
- **Redis 記憶體＝O(不同被鎖 key 數)**：分散式打 `Super` 只長 1 個 `user:Super` key（幾百萬次攻擊也是一個 key）。
- **自癒**：D2 固定 TTL + ②b 不寫 → 攻擊停止後 ~900s 內 key 過期、真實失敗列 age-out、**自動解鎖**。
- **fail-OPEN**：Redis 不可達→L1 跳過、退回 L2 既有 DB gate（鎖不壞、只少加速）；個別 op 失敗→降級吞。**DB 維持單一真相**。

### 4.3 nginx／schema／obs
- nginx 不動（既有 `limit_req` 仍為第一線）；**零 migration**（reuse `sys_login_attempt` + 既有索引）；**零新 crate／零新 route**；redis facade `+incr`（可選 `+pfadd/pfcount`）；obs `+1` 結構化 log 事件（可選 `+1` grafana alert rule「lockout 壓制中」）。

---

## 5. v1 不做（defer）
- **IP 信任白名單／CAPTCHA／帳號-DoS 緩解**（019 §4.2 已登記、獨立 future feature）：本刀僅留 L0 seam。**註**：本刀把鎖做得更可靠（Redis 不像 DB 會 fail-open-under-load）→ 帳號-DoS 更穩定生效 → **更需白名單**，故列為緊接候選 feature。
- **refresh-on-hit TTL**（永久鎖語意）——否決（D2）。
- **bounded-count(LIMIT)**——快取已使其多餘。
- **runtime 可調門檻／per-IP 白名單／reset-on-success／鎖定專屬審計欄**（019 §4.2 既登記）。
- **distinct-IP HLL（PFADD/PFCOUNT）** 為**可選**（forensic nice-to-have、非必要、plan 時定）。

---

## 6. 出口條件
- [ ] 鎖後嘗試（Redis 命中）對 DB 的 query 數＝**0**（不 COUNT、不 INSERT）。
- [ ] 分散式打單帳號：per-user 觸發後 `lockout:user:{name}` 短路所有後續 IP（per-user COUNT 一窗最多跑 ~5 次、之後歸零）。
- [ ] D2 固定 TTL：攻擊停止後 ≤900s 自動解鎖（無 admin 介入）。
- [ ] ②c 麵包屑：鎖中節流 ≤1/60s/key 出結構化 log（含 `suppressed` 計數）→ loki 可查。
- [ ] fail-OPEN：Redis-down → 退回 019 既有 DB gate、鎖正確性不破。
- [ ] 零回歸：未鎖路徑行為與 019 完全一致（`login_inner` 6 路徑、稽核寫、雙語 toast `auth.login.locked`）。
- [ ] 0 migration／0 新 crate／0 新 route；Constitution 9 問複檢無違規。

## 7. 測試／驗收策略（TDD）
- **純函式測**：`is_locked_out` 不變（已有）；新「快取決策」邏輯（哪維度 set、key 組裝、節流判定）抽純函式 test-first。
- **live 測**（容器內 Redis+DB、in-crate `#[ignore]`+env-gate、`--test-threads=1`）：鎖→set `lockout:*`→後續嘗試短路（驗 **0 DB 寫** ＋ breadcrumb INCR/log）；TTL 過期→Redis miss→DB 重判；**Redis-down→退 DB gate**（fail-open）；per-user 分散式→`user:` key 短路（多「IP」變體）。
- **acceptance（curl/psql + 量測）**：「被鎖嘗試 0 DB query」（instrument／psql `pg_stat_*` 前後差／或 live 測直驗）；分散式 per-user 短路；雙語 toast 不變（沿 019；**本刀無 i18n 新鍵、沿用 `auth.login.locked`**，故 vite stale-locale 風險不適用）。
- **prod build gate**：無新 crate、仍跑驗 multi-stage 無破口。

## 8. Phase 0 research 待固化（交 `/speckit-plan` research.md）
- redis facade `incr`（與可選 `pfadd`/`pfcount`）的確切簽名/錯誤通道（鏡像 `set_ex` 的 fail-OPEN 降級）。
- login gate 分層插入點（L1 在 `since` 計算前）；`tripped_key`/`dimension` 在 L2 如何決定（ip_fails≥20 / user_fails≥5 各自 set；兩維皆觸發時 set 兩 key）。
- 觸發那發的 cache set 與 audit write 順序（write 為 best-effort、與任何 txn 無關；確認無交互、set 在 write 前後皆可）。
- obs log target/欄位規約（與 018 既有 security 事件慣例一致）＋是否本刀加 grafana alert rule（可選）。
- key 命名/TTL 常數（`lockout:ip:` / `lockout:user:` / `lockout:suppressed:` / `lockout:flushed:`；TTL=900/60）落 const。
- ②c flush 時 INCR 計數的讀取+重置（`GETDEL` vs `GET`+`DEL`；distinct-IP 若做的 `PFCOUNT` 讀取+TTL）。
- Constitution 9 問：auth 島行為改 ＋ redis 用 ＋ obs log——確認無 §I.7/§4.2/migration 違規；**②b 反轉 019 FR 須在 spec 明記為刻意**。

## 9. 與 019 的落差/勘誤紀錄（act-on-code 接住、供勘誤評估）
- 本刀**反轉 019 FR-004（每終局結果 exactly-one 列）/ FR-008（gated 列 sticky 審計）** 於「Redis 快取命中短路」情形（鎖後不逐筆寫、改 ②c 節流摘要）。019 spec 該兩 FR 於本刀落地後屬 **as-built 勘誤候選**（同 020 對 011 的處理：加 forward-pointing as-built 註記、保留原文、權威更正登 DECISIONS §1）。`/speckit-plan` 時評估。〔**收尾勘誤 (2026-06-28、3 獨立 reviewer grep 實證)**：「exactly-one per terminal result」之擁有者為 **007-audit-overlay FR-004（:108）/SC-002（:137）**、**非** 019 FR-004（019 FR-004＝真實 client IP 防偽、021 未碰）；本刀真正反轉＝**007 FR-004/SC-002 ＋ 019 FR-008**，as-built 註記已加於該三處、權威詳 [DECISIONS §1（021）](../INTEGRATION-DECISIONS.md)。本 Phase 0 brainstorm 為史料、不改正文、僅附此勘誤指標。〕
- 帳號-DoS 緩解（IP 白名單/CAPTCHA）為 019 §4.2 既登記 future；本刀把鎖做硬後，緩解需求升高、宜緊接排程（見 §5 註）。
