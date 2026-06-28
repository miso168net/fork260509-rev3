# Phase 0 Research: 021-login-lockout-redis-cache

**Branch**: `021-login-lockout-redis-cache` | **Date**: 2026-06-28 | 接地自 act-on-code（as-built 為準）

> 固化 brainstorm（`docs/superpowers/021-login-lockout-redis-cache.md`）§8「研究待固化」+ clarify（Q1 distinct-source 可選／Q2 告警規則遞延）的實作接地。所有 file:line 為 worktree as-built。

---

## D1 — 分層 gate 插入點：L1 在 `since` 計算與 DB count 之前（login 起手）

- **Decision**：`handler/auth.rs::login`（:211-281）起手、在現有 `since=now-900s`（:226-230）與兩個 `count_failed_by_*_since`（:231/:238）**之前**，加 L1 Redis 負快取查：`state.redis` 取 handle → `get("lockout:ip:{ip}")` / `get("lockout:user:{name}")` 任一命中 → 直接回 `Err((None, AppError::Biz("auth.login.locked")))`（鏡像現有鎖定回傳 :246）、**不進 L2 count、不進 login_inner、不寫稽核**（②b）。miss → 走 L2 既有 DB gate（完全不動 :231-249）。
- **Rationale**：把「已生效鎖定」短路在最昂貴的 DB COUNT 之前 → 鎖後成本 O(1)；L2（真相層）與 `is_locked_out`（:68-69）純函式完全不動 → 零回歸風險集中在 L1 疊加層。
- **接地**：login `State(state): State<AppState>`（:212）已持 `state.redis`；handler 取 redis 範式 `if let Some(h) = state.redis.as_ref().as_ref() { h.xxx().await }`（`auth/enforce.rs:346/374`）；`AppState.redis: Arc<Option<RedisHandle>>`（`state.rs:38`）。鎖定回傳形 `Err((Option<i64>, AppError))`（:246/:252、operator=None）。

## D2 — 雙維度快取 key：依觸發維度寫（D1 brainstorm 拍板）

- **Decision**：L2 達門檻時，依**觸發維度**各自 `set_ex`：`ip_fails >= PER_IP_THRESHOLD(20)` → `set_ex("lockout:ip:{ip}", "1", 900)`；`user_fails >= PER_USER_THRESHOLD(5)` → `set_ex("lockout:user:{name}", "1", 900)`（兩維皆觸發則各寫）。L1 查兩 key（OR）。
- **Rationale**：只記 `real_ip` 擋不住分散式打單帳號——新 bot IP 不在 ip 快取、照樣 fall through 觸發 per-user COUNT；`lockout:user:{name}` 才能短路後續任意 IP 的該帳號嘗試（FR-002）。Redis 記憶體＝O(不同被鎖 key)，分散式打 Super 只長 1 個 `user:Super` key。
- **接地**：consts `PER_USER_THRESHOLD=5`/`PER_IP_THRESHOLD=20`/`PER_*_WINDOW_SECS=900`（`auth.rs:55-63`）；`is_locked_out = ip_fails>=20 || user_fails>=5`（:68-69）——L2 可直接由 `ip_fails`/`user_fails` 判定各維度是否觸發以決定 set 哪個 key。key value 用 `"1"`（占位、存在即鎖；非如 denylist 存時刻——本刀不需時刻比對、純存在性）。

## D3 — 固定 TTL=900s、命中不 refresh（D2 brainstorm 拍板＝b）

- **Decision**：`set_ex` TTL＝900（＝19 窗 `PER_USER_WINDOW_SECS`）；L1 命中時**只 `incr` 計數 + 拒、不 refresh `lockout:*` 的 TTL**。
- **Rationale**：攻擊停止後 ~900s 內 `lockout:*` key 自然過期 + 既有 5 筆觸發失敗列 age-out（②b 鎖中不寫新失敗列）→ DB 重判得 count<門檻 → 自動解鎖（FR-007、無 admin 介入）。refresh-on-hit 否決（攻擊者每 <900s 戳一下即永久鎖死 Super、加劇帳號-DoS）。
- **接地**：TTL 常數沿用 `PER_USER_WINDOW_SECS=900`；redis `set_ex(key,val,ttl_secs:u64)`（`redis.rs:78`）。

## D4 — ②b：Redis 快取命中時不寫 `sys_login_attempt`

- **Decision**：login 現有「單一寫點」`sys_login_attempt::write`（:256）**只在 L2 路徑（Redis miss）執行**——含上鎖前累積失敗、與**觸發鎖那一發**（FR-006 上鎖前歷程＋上鎖事件留存）。L1 命中（已鎖）路徑**早 return、不到 :256**（②b、FR-004 反轉）。
- **Rationale**：鎖後洪水若逐筆寫＝寫入放大＋攻擊者 DoS 稽核表＋使 D3 退化（窗被鎖中寫滿、過期即 re-lock）。L1 早 return 天然達成「鎖後不寫」。
- **接地**：寫點 `auth.rs:256`（`let _ = facade::sys_login_attempt::write(...)` best-effort）；L1 在 :226 前 return → 不經 :256。

## D5 — ②c：節流壓制麵包屑（Redis 計數 → obs log；count 必需、distinct-source 可選）

- **Decision**：L1 命中時 `incr("lockout:suppressed:{locked_key}")`（帶 TTL，如 900s 自清）累計；**節流 ≤1/60s/key**——`get("lockout:flushed:{locked_key}")` 不存在才 flush：讀+重置計數（GETDEL `lockout:suppressed:{key}`）→ `tracing::warn!(target:"security.lockout", locked_key, dimension, suppressed=n, "...")` → 018 loki → `set_ex("lockout:flushed:{key}","1",60)`。**clarify Q1**：必需「壓制次數」；distinct-source 來源廣度（HLL `PFADD`/`PFCOUNT`）**可選/遞延**（不做 v1）。
- **Rationale**：保留「遭攻擊量級」鑑識訊號又不逐筆灌稽核表（FR-005）；落 obs log 零 migration、不污染 per-user COUNT、可 grafana 查/alert（FR-011）。**clarify Q2**：本刀只發此可告警訊號、**具體告警規則配置遞延 ops/obs**（不出 alert rule）。
- **接地**：obs json subscriber（018）已就緒；`tracing::warn!(key, error=%e, "...")` 結構化欄範式遍佈 `redis.rs:69/81/91/116`。redis `AsyncCommands` 提供 `incr`/`get_del`/`expire`（`redis.rs` 用 `AsyncCommands`、`conn.get`/`set_ex`/`del` 同源）。

## D6 — redis facade 加 `incr`（+ take-suppressed）：鏡像既有 fail-OPEN 範式

- **Decision**：`server/src/redis.rs` 加最小方法：`incr(key)`（INCR + 確保 TTL；可 `incr` 後若回 1 則 `expire`，或每次 set TTL）／`take_suppressed(key) -> i64`（GETDEL 讀+清；miss→0）。皆 fail-OPEN：error 吞成降級值（`incr` 失敗→不阻斷拒絕路徑；`take`→0）。可選再包語意 helper `mark_locked(key,ttl)`/`is_locked(key)->bool`（薄包 set_ex/get）。
- **Rationale**：facade 現有 get/set_ex/del/publish 已是 fail-OPEN 範式（:64-118），新增循同款（`let mut conn=self.conn.clone(); match conn.incr(...).await { Ok→.., Err→warn+降級 }`）。
- **接地**：`RedisHandle{client,conn:MultiplexedConnection}`（:27-32）、`AsyncCommands`（:19）；既有 method 全 `#[allow(dead_code)]`+fail-OPEN（:63-93）；`set_revoked`/`revoked_at_of`（:98-110）為「語意包薄封 set_ex/get」範例 → lockout 語意包同款。

## D7 — ★ 有意識反轉 019 FR-004/FR-008（as-built、非違憲）

- **Decision**：019 FR-004（每終局結果 exactly-one 列）/FR-008（gated 列 sticky 審計）於「L1 快取命中短路」情形**不成立**——鎖後不逐筆寫、改 ②c 節流摘要。**非** constitution 不變式（§I.6 archetype B 只規範 append-only/不可竄改、未規範「每嘗試必寫」）→ 不違憲。
- **Rationale**：019 的「gated 也寫」在洪水下變負債（見 D4）。屬 019 spec-level 演進。
- **收尾處理**：比照 020 對 011 data-model 的 as-built 勘誤——`specs/019-login-lockout/spec.md` FR-004/008 加 forward-pointing as-built 註記（保留原文）、權威更正登 DECISIONS §1（plan/收尾時）。
- **接地**：019 FR-004/008 措辭見 `specs/019-login-lockout/spec.md`；單一寫點 `auth.rs:256`「含 gated」註解（:244/:255）即被本刀 L1 早-return 覆寫於鎖後。

## D8 — fail-OPEN 降級鏈（Redis-down → L2 既有 DB gate）

- **Decision**：`state.redis.as_ref().as_ref()` 為 `None`（Redis 連不上、boot 降級）→ L1 整段跳過、直走 L2 既有 DB gate（鎖定仍由 DB 滑動窗 count 正確執行、只是少了加速）；個別 Redis op（get/incr/set_ex）失敗→降級吞、不阻斷主流程（拒絕/放行由 DB 決定）。**DB 維持鎖定單一真相**（FR-008、§I.7 §4.3 persist-then-cache）。
- **接地**：`AppState.redis: Arc<Option<RedisHandle>>`（`state.rs:38`、boot `connect` 連不上→`None`、`redis.rs:37-58`）；handler `if let Some(h)=...` 守門範式（enforce.rs:346）。

## 接地事實速查（file:line）

| 主題 | 位置 | 事實 |
|---|---|---|
| login gate | `handler/auth.rs:211-281` | `since`(:226-230)→2 COUNT(:231/:238、unwrap_or(0))→`is_locked_out`(:245)→`login_inner`/Err→單一寫點 `write`(:256) |
| 鎖定 consts/判定 | `auth.rs:55-69` | `PER_USER_THRESHOLD=5`/`PER_IP_THRESHOLD=20`/`PER_*_WINDOW_SECS=900`；`is_locked_out=ip>=20\|\|user>=5`；`is_locked_out_for_test`(:74) |
| COUNT 無 LIMIT | `model/facade/sys_login_attempt.rs:66-97` | `.count(conn)`＝`SELECT COUNT(*)`、無 LIMIT；`idx_login_attempt_ip_time`/`_user_time` |
| 寫點 | `sys_login_attempt.rs:51` | 單 INSERT、archetype B append-only（本刀只在 Redis-miss 路徑呼） |
| redis facade | `server/src/redis.rs:34-149` | `RedisHandle`(MultiplexedConnection+AsyncCommands)：get(:64)/set_ex(:78)/del(:88)/set_revoked(:98)/revoked_at_of(:106)/publish(:113)/subscribe_pubsub(:122)；全 fail-OPEN、`tracing::warn!(key,error=%e,..)` |
| handler→redis | `auth/enforce.rs:346/374` | `if let Some(h)=state.redis.as_ref().as_ref(){ h.set_revoked(..).await }` |
| AppState.redis | `state.rs:38` | `Arc<Option<RedisHandle>>`（Redis-down→None） |
| obs log | 018 json subscriber（已就緒） | `tracing::warn!(target:..,field=..)` → loki `\|json` 攤平、grafana 查/alert |
| nginx limit_req | `deploy/nginx/nginx.conf:85`/`conf.d/_locations.inc:19` | `$binary_remote_addr` 5r/s burst40 /api/（第一線、限連線 IP、非聚合 per-user） |

## schema/crate/route
- **0 migration**（reuse `sys_login_attempt`+索引、Redis key 非 DB、②c 落 obs log）、**0 新 crate**、**0 新 route**（沿用 `/auth/login`、wire 不變）。
- prod build gate 仍跑（無新 crate、驗 multi-stage 無破口）。
