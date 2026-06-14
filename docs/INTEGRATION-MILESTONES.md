# rev3 commit 里程碑永久紀錄（INTEGRATION-MILESTONES）

> **append-only、不在 SOP hook 注入**（避免 CHECKLIST 膨脹）。三區、§2/§3 與 CHECKLIST 同號區鏡像對應：
> 「§1 commit 里程碑表」收每筆 docs／feature commit 一行（表尾 append）；
> 「§2」收 CHECKLIST §2 完成波的收縮節（✅ 標題＋blockquote 摘要;批次搬入後 CHECKLIST 永遠聚焦當前波）；
> 「§3」收 CHECKLIST §3 已完成 follow-up 節的細節（批次搬入）。
> 歸檔流程見 [CLAUDE.md §7.5](../CLAUDE.md)。**與 [DECISIONS §2](INTEGRATION-DECISIONS.md) 的分工**：波次 as-built **詳帳**在 DECISIONS §2（權威）；本檔 §2 只收 CHECKLIST 的一行式快照歸檔，查波次細節一律去 DECISIONS。

---

## §1 commit 里程碑表

| commit | 日期 | 主題 |
|---|---|---|
| `f8e0728` | 2026-06-11 | Spec-Kit presets / extensions / skills 落地 |
| `f6c4939` | 2026-06-11 | .gitignore 補強 — 排除 Claude 憑證與 fork 子專案 |
| `e006b7c` | 2026-06-11 | CLAUDE.md 從 rev2 改寫為 rev3（身分／⏳ 目標態／port 3XXXX） |
| `8ebce10` | 2026-06-11 | CLAUDE.md 微調 — pre-hook 檔名、§7 跨檔引用改語意錨 |
| `2ec9cda` | 2026-06-11 | 註冊 base-web/rust-api 為 submodule（worktree+submodule 雙重身分落地） |
| `0713db4` | 2026-06-12 | CLAUDE.md 拔除 worktree/submodule 已落地 ⏳ |
| `03a1b01` | 2026-06-12 | bump base-web 到 dd771540 — x_fork.branch-origin.md 分支來源紀錄 |
| `fb87a67` | 2026-06-12 | bump rust-api 到 f73ef10 — x_fork.branch-origin.md 分支來源紀錄 |
| `7fd1ac6` | 2026-06-12 | 設計權威 INTEGRATION-DESIGN-rev3.md 入 docs/ |
| `88f9011` | 2026-06-12 | DESIGN 拍板回填 — 官方權威序＋六項拍板＋對賬修補 |
| `8f66fe0` | 2026-06-12 | graphify rev3 首次建圖（2060 nodes／311 communities／83.7x） |
| `46591c4` | 2026-06-12 | 000：保存 base-web/apifox mock API 捕獲原始資料 |
| `309099d` | 2026-06-12 | base-web standalone dev compose |
| `aea0e18` | 2026-06-12 | 000：補抓 mock 缺口端點＋CDP scripts git-track |
| `e898421` | 2026-06-12 | 000：13 端點對映表＋設計書比對文件落地 |
| `4aa7c89` | 2026-06-12 | INTEGRATION-DESIGN-rev3.md 歸位改名 INTEGRATION-DESIGN.md |
| `4724549` | 2026-06-12 | C 方案落地 — DESIGN 凍結藍圖＋INTEGRATION-DECISIONS.md 伴生活帳 |
| `4300b54` | 2026-06-12 | CHECKLIST/MILESTONES 落地 — 注入活檔成形、波 -1 文件層收齊 |
| `9d8303f` | 2026-06-12 | 外檔引用全面查驗修正 — ⏳ 同步現實＋DESIGN amendment 動線勘誤 |
| `e8e1a99` | 2026-06-12 | §7.1 改定 — rev2 研究三檔不移植不重作 |
| `ed2a789` | 2026-06-12 | SessionStart hook 落地 — 自 rev2 原樣承接（零改動） |
| `71cdd61` | 2026-06-12 | §7.5 歸檔 — MILESTONES append＋CHECKLIST 進展滾動 |
| `4ec9cc6` | 2026-06-12 | MILESTONES 三區化收整 — user 鏡像設計補一致性 |
| `612ddcd` | 2026-06-12 | 波 -1 constitution 重鑄項加 §V.2 提案位置搬家註記 |
| `167db96` | 2026-06-12 | **constitution-rev3 v1.0.0 凍結** — 13 項拍板融入（含 ⚠️s fork-delta 紀律）；波 -1 出口四項全綠、**波 -1 全完成** |
| `c9ffad5` | 2026-06-13 | **001-infra-deploy 全綠收刀（波 0 第一刀）** — master compose 5 service＋migrate gate＋dev/prod override＋deploy/ 全套＋rust-api scaffold（worktree `5d69c06`）；C-V-0~8 實機全綠（SC-001~007）、捕獲 redis `--dir` 持久化真 bug 並修；merge --no-ff、feature branch 保留 |
| `9233ae0` | 2026-06-13 | **002-rev2-schema-baseline 全綠收刀（波 0 第二刀）** — 前代 35 支 migration squash 為 4 支基線（m001 schema 11 表終態〔10 手寫＋casbin 委派 vendored adapter＋ALTER 治理欄〕／m002 seed 92 列 6 表〔argon2id 單一 hash〕／m003 user_role FK ×2 RESTRICT／m004 demo 選單 66＋policy 全 R_SUPER）＋sea-orm-adapter 整檔拷入（§I.5、worktree `91cfc80`）；tests/002 四支驗證 scripts（normalize 六規則）＋2 基準檔；C-V-0~9 實機全綠（SC-001~008）、修 m002 兩層 seed drift（id 順序 bug＋normalize 第六規則 row-order 正規化〔user 拍板方案 A、契約留痕 migration-chain.md §3〕）；merge --no-ff、feature branch 保留 |
| `7960a73` | 2026-06-13 | **003-envelope 全綠收刀（波 0 第三刀）** — envelope.rs（`Res<T>{data,code,msg}`＋`PageRes<T>`＋`BizCode` 13 碼矩陣〔code/msg 逐字凍結⚠️f＋http_status() 單一真相〕）＋error.rs（`AppError` struct＋8 公開建構子〔4 保留碼無建構子＝⚠️f 結構保證〕＋集中 IntoResponse、Internal→200⚠️e、internal detail 僅進 Display 不入 body）;非新 crate（server 內 2 模組、worktree `6808adb`）;test-first TDD 18/18＋prod release build＋C-V 1-5 全綠;四階段 subagent review（spec×4＋quality×4＋final）全過、rev2 enum/500 陷阱已避;merge --no-ff、feature branch 保留、**未 push** |
| `65f4bbe` | 2026-06-14 | **005-audit-op-log 全綠收刀＋merge（波 0 第五刀／audit 刀之首、未 push）** — `model/audit.rs`（全新寫⚠️g、零 `entity::` 守 lint③）：`AuditOperation` 全4＋`as_str`／`AuditOperator`／`AuditEvent` 7 欄／`AuditSerialize` trait／`mutate_in_txn<R,F,Fut>` 泛型 wrapper（業務寫＋審計寫綁同一 `DatabaseTransaction`：`Some(event)` 同 txn 寫+commit、`None` no-op、`Err` 整筆回滾）＋`facade/sys_operation_log.rs`（append-only sink、唯一構造 op-log ActiveModel：`audit_active_model` 純映射〔`operator_ip` None→NotSet 避 PG 42804、`Some(ip)` 分支 defer 第二 audit 刀〕＋`write_in_txn`）＋`facade/sys_user.rs` `impl AuditSerialize`（redact `password`→`"<redacted>"`、15 欄排除 `current_session_id`、timestamps to_rfc3339）＋單一寫路徑 proof `soft_delete(db,id,operator:i64)->Result<bool,DbErr>`（包 `mutate_in_txn`：active→寫 deleted_at+deleted_by+SoftDelete 審計 Ok(true)／no-op→Ok(false) 不寫）＋`soft_delete_query` helper;擴 entity crate（`sys_operation_log` Model 10 欄鏡像 m001＋sea-orm +`with-json`、無 migration）＋Cargo.lock 補齊 003/004 遺留 16 筆 sea-orm optional-dep stanza（feature-gated 未編譯、time=0.3.47 user 拍板接受、time pin 註解校正＝清 §3.4/§3.5 backlog）;test-first TDD（`audit_json` redact＋`audit_active_model` SQL-build 純測、零 DB、todo!() red→green）＋3 場景 bounded 实机 smoke（#[ignore]、拋棄式 user 900001/900003＋hard_clean：commit 恰好 1 筆 redacted 審計〔operator_id==1 SC-004〕／no-op 不寫／審計 INSERT 失敗整 txn 回滾、orchestrator 親驗綠）;`entity_access_lint` 守恆續綠（audit.rs 零 entity::）;12 task／4 unit subagent-driven（spec+quality review 各過＋final READY TO MERGE）;7 SC／12 FR 全滿足;worktree `61af75f`、merge `65f4bbe` 回 rev3-admin-root、feature branch 保留、**三 ref 已 push（2026-06-14）**：rev3-admin-root（`b577ae5..beb116f`）／005 保留分支／rev3-admin-rust-api fork（`9cf3f7e..61af75f`） |
| `e8334d7` | 2026-06-14 | **004-soft-delete-infra 全綠收刀＋merge＋push（波 0 第四刀）** — 新 `entity` crate（sys_user 16／sys_role 12／sys_user_role 2 複合 PK 逐欄鏡像 m001、`with-chrono` 僅加於 entity crate〔time 不入圖、chrono 已在 lock〕）＋`SoftDeletable` trait（active 過濾 minimal、無寫側）＋`model/facade/` 三 facade（user/role soft-deletable impl＋`find_active_by_*`／user_role plain 硬刪 `find_role_ids_by_user_id`、不 re-export Entity、回 raw Model/DbErr）＋`entity_access_lint` build-failing 守恆（兩階段抹白掃描〔phase1 抹白註解/字串防 brace-stack 污染＋phase2 local 回掃判 path root〕＋meta-test＋false-pos/neg regression 22 test、⚠️g 全新寫非拷貝〔3 vs 27 push 結構證據〕）＋bounded 实机 smoke（#[ignore]、m002 seed 證 soft-delete 真排除 stamped 列）＋Dockerfile entity COPY（prod image build mandatory、RED→GREEN 證 gate）;triple-guard（trait／facade 不 re-export／build-failing lint）三防護就位;test-first TDD、DB-free 20+1ignored+22／live --ignored 1／prod build 全綠（orchestrator 親測）;7 SC 全 met／11 FR 全滿足（FR-010 排除零洩漏）;7 單元 subagent-driven（spec+quality review 各過＋final READY TO MERGE）;worktree `9cf3f7e`、merge `e8334d7` 回 rev3-admin-root、feature branch 保留、三 ref 已 push（rev3-admin-root／004 保留分支／rev3-admin-rust-api fork） |
| `2c5a2a1` | 2026-06-14 | **006-auth-island-min 全綠收刀＋merge（波 0 第六刀／Auth 島最小段、未 push）** — stateless 認證地基：`auth/{jwt,bearer,password,enforce}`（全新寫⚠️g、HS256 stateless JWT〔Claims 剝 sid/jti、leeway=0、JWT_ISS/AUD=rev3-admin〕＋bearer 抽取＋argon2＋casbin per-route enforce〔MODEL 三欄精確無 glob／`build_enforcer`〔`SeaOrmAdapter::new` 消費 owned db、boot db.clone()〕／`enforce_mw` 即時角色 DB 重查〔**不信 claims.roles**〕／role-lookup DbErr **fail-closed 5003+tracing::error**〔非 3333 非 internal、刻意不 `?`〕／剝 7777 single-session gate〕＋`buttons_for_roles`）＋`handler/auth`（login〔argon2＋停用 gate＋發 token pair、三種憑證失敗一致 1000〔anti-enum〕、DB/簽發系統錯誤 5000〕／getUserInfo〔`user_id` i64→string＋2^53 fail-loud、nick_name‖user_name、DB-fresh roles〕／refreshToken〔stateless re-sign、失敗→**8888 反迴圈鐵律**絕不 3333〕）＋`state.rs`（`AppState{db,jwt,enforcer}`、`JwtConfig` _FILE 讀 jwt secret〔`file_or_env` 共用〕、剝 redis/session_mode）＋error `From<DbErr>`/`<casbin::Error>`＋facade `roles_for_user`＋main boot 重寫（db→build_enforcer(db.clone())→AppState、/health 保留不退化、3 public auth route）；**非新 crate**（server 內加模組）；deps +`jsonwebtoken 9`（MSRV：jwt9→simple_asn1→time 進**真 compile graph**、time 0.3.47 需 rustc 1.88、pin `simple_asn1 0.6.3`/`time 0.3.37`〔實機證 unpin 即 build fail〕）；**無 migration**；test-first 純測 52＋lint 22〔jwt/bearer/argon2/enforce-decision/2^53/refresh-反迴圈〕＋enforce-proof live〔Super→200/User→403·5003/bad→3333〕＋全棧 curl〔login 0000／失敗一致 1000／userId string／refresh 壞 8888／getUserInfo 3333〕＋**CDP browser smoke**〔base-web 攔截器解析真 rust-api envelope：SOY_token/SOY_refreshToken 真 JWT〔iss=rev3-admin/user_id=1/R_SUPER〕＋/login→/home、**SC-006**〕全綠；C-V-1~7 全過〔prod image build 防 sea-orm-adapter COPY-gap 綠〕；8 unit subagent-driven（spec+quality review 各過＋final holistic READY TO MERGE）；8 SC／13 FR 全滿足；**發現**：seed 實有 16 筆 v2='button' policy〔research R3.3「buttons 現空」假設錯、getUserInfo 回真按鈕、code 正確、註解校正〕／005 audit live_smoke 非 parallel-safe〔`--test-threads=1`、列 follow-up〕；worktree `e71cb07`、merge `2c5a2a1` 回 rev3-admin-root、feature branch 保留、**未 push** |

---

## §2 Roadmap & Phase 狀態 — 完成＋歸檔

>（收 [CHECKLIST §2](INTEGRATION-CHECKLIST.md) 完成波的快照收縮行，累積數波後批次搬入；as-built 詳帳在 DECISIONS §2、此處只存一行式快照。目前空。）

---

## §3 Follow-up Backlog — 完成＋歸檔

>（收 [CHECKLIST §3](INTEGRATION-CHECKLIST.md) 已完成 `### 3.X` follow-up 節，累積數節後批次搬入、原處留收合指標。目前空。）

