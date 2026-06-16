# rev3 整合決策與實施帳（INTEGRATION-DECISIONS）

> 本檔 = [`INTEGRATION-DESIGN.md`](INTEGRATION-DESIGN.md)（凍結藍圖）的**伴生活帳**：藍圖只被引用，所有「會動的」都記這裡。
> - **§1 決策紀錄表** — 全書待決／拍板唯一清單（原 DESIGN 附錄 G 整表遷入 @ 2026-06-12）
> - **§2 實施階段** — 波次執行 as-built 帳（計畫的設計在 DESIGN §8.4、執行的帳在此；rev2 DESIGN §10 的外移對應物）
>
> **優先序**：本檔 §1 > DESIGN 本文 — 衝突時以本檔為準；DESIGN 本文的「待決N／⚠️x」字樣以本檔現況為準。
> **分工**：CHECKLIST（hook 注入）持「當前波快照＋拍板項一行索引」；MILESTONES 收 commit 里程碑流水＋CHECKLIST §2/§3 完成內容的鏡像歸檔（其 §2 只存一行式快照、波次詳帳仍在本檔 §2）；完整職責分工見 CLAUDE.md §7。
> **本檔不被 hook 注入**——會長無妨（表格帳本性質，與 MILESTONES 同類）。

---

## §1 決策紀錄表（全書唯一清單；user 親決前不入凍結集）

> **編輯紀律**：新增 ⚠️／待決必登本表；拍板後該列改「✅ 已決（日期）＋結論全文」，**不回填 DESIGN 本文**（DESIGN 重鑄時批次摺合、版本 +0.1、該列補標「已併入 vX.Y」）；DESIGN 勘誤不經本表、直接最小 patch。「最晚決策點」= 再不決就 block 哪一步；「所在章」指 DESIGN 章節。文中「待決⑥」泛指 ⑥a~⑥d 四子項。

| # | 決策點 | 工程預設 ⚠️ | 所在章 | 最晚決策點 |
|---|---|---|---|---|
| 待決① | router 結構：維持 flat-in-main 還是重整 `router/` 樹 | ✅ 已決(2026-06-13)：**flat-in-main 沿用**（rev2 as-built 已驗證模式：全部 route 逐條 `.route()` 寫 `main.rs`、`endpoint_coverage_lint` 鎖「main.rs==ENDPOINT_REGISTRY==seed」三源一致；lint 直接沿用、零 scaffold 改寫）。重整 `router/` 樹被否（lint 第一源從單檔變多檔、丟已驗證模式） | §1.5・§8.1 | ✅ 已決 |
| 待決② | wire contract 機器化（OpenAPI／contract test／維持 grep） | ✅ 已決(2026-06-12)：**C+ typings-as-oracle** — typings 抽 JSON Schema 當裁判（唯讀、不動官方檔）＋ coverage gate（router 每條 route 必有 contract case、缺＝CI 紅）＋ 碼表 table-driven（§7.3）＋ CDP capture 降為補充回歸 fixture ＋ lie ledger（顯式覆寫帳本、初始空）；B 案留「endpoint 增速再評」 | §7.2 | ✅ 已決 |
| 待決③ | 縱切第一刀：User 直刀 vs `system_settings` 打樣 | ✅ 已決(2026-06-16)：**B — `system_settings` 打樣為第一刀**（user 親決、推翻前次 A=User 直刀傾向）。以最輕、低風險、欄少的 `system_settings` 便宜排練 §8.1 全管線（migration→facade→handler→enforce→wire→frontend）、骨架先打通再上最重的 User 刀。⇒ 波 1 第一刀＝system_settings 打樣（此 rationale 為 B 原始價值 prop、user 實際理由待補） | §8.3 | ✅ 已決 |
| 待決④ | 選擇性 FK | ✅ 已決(2026-06-13)：**採工程預設 — 僅 join 表 `sys_user_role` 加 FK、其餘 11 表維持零**（join 表純關聯＋硬刪＋無 soft-delete 互動 → FK 零代價高收益、DB 層擋懸空列；log/token/casbin 維零——soft-delete 與 system-actor null 語意與 FK 相棘；零 FK 處 application-RI 義務照 §3.3 集中清單） | §3.1 | ✅ 已決 |
| 待決⑤ | §3/§5 凍結邊界：哪些進 constitution、哪些留設計書 | ✅ 已決(2026-06-12)：**採工程預設** — archetype（§3.2 四變體 A/B/C/D 整組）+ 行為島 invariants（§4 三台狀態機）+ wire 碼表（§5.4/§7.3，含 PageRes 形與 envelope 例外）入凍結（constitution §I.6/§I.7/§I.3）；欄級字典與常數值（grace 秒數等）留設計書。配套：constitution §V.3 分級 — §I.7 方向性不變式反轉=MAJOR、其餘 invariant 細項調整=MINOR | §3・§9 章首注 | ✅ 已決 |
| 待決⑥a | user-facing 儀表板 | rev3 v1 = 固定儀表板、0 新表（§2 表 #1） | §2 | 入波排程時（不 block 波 0-3） |
| 待決⑥b | 報表匯出 PDF/CSV | rev3 v1 = 同步匯出、0 新表（§2 表 #2） | §2 | 同 ⑥a |
| 待決⑥c | AES-256 靜態加密 | rev3 v1 = 磁碟/tablespace 層（§2 表 #3） | §2 | prod 部署定稿前（加密卷屬部署期決策） |
| 待決⑥d | 合規姿態升級 | 維持現姿態（§2 表 #4） | §2 | 對外／多租戶觸發時 |
| ⚠️a | 效能／可用性數字 | ✅ 已決(2026-06-16)：**批准保守預設**——list 讀 p95<300ms／寫(含同 txn 審計) p95<500ms／login p95<1s（argon2id 主成本）／可用性 99.5%/月（容許計畫性維護、恢復＝重啟容器）。對齊 §1.3「≤50 並發 admin 後台、不設吞吐 SLA」；波 1 起為驗收目標、`/speckit-plan` C-V 納入 | §1.3 | ✅ 已決 |
| ⚠️b | 審計查詢讀端 + UI 補做 | ✅ 已決(2026-06-16)：**做、排波 2 殿後刀**——補三 log 表（`sys_operation_log`/`sys_access_log`/`sys_login_attempt`）查詢讀端 + Super-only manage UI（MODAL-WIRING use (e)）；排序在波 2 核心 data-island（Menu→Role；`system_settings` 已移波 1 第一刀〔待決③〕）**之後**（read-only reporting、可殿後讓核心 CRUD 先清波 2）。落地需：3 讀 route + R_SUPER policy seed + 新 sys_menu seed（審計頁）+ §5.8 讀端 filter 索引（operation/access 需補、login 已就緒）+ wire 從零設計（rev2 零讀端、無 mock 可鏡像） | §1.2・§5.0 | ✅ 已決 |
| ⚠️c | `/auth/error` | ✅ 已決(2026-06-12)：**翻案 — 做**（echo 端點）。配套完整包：`alova/request`＋`alova/scenes`＋`function/request` 三 demo 頁進 sys_menu seed（初始僅勾 R_SUPER、下放交 ROLE 勾選層）；端點補 `/auth/error`＋`sendCaptcha`/`verifyCaptcha`（stub 雙模、⚠️m captcha 依賴就此解決）＋`/mock/getLastTime`（回 `{time}`）；§1.4 兩條「不做」同步翻案 | §1.4・§6.1 | ✅ 已決 |
| ⚠️d | redis-stack image tag | ✅ 已決(2026-06-13)：**建 stack 當下即 pin 數字版**（infra/deploy 刀寫 compose 時查當下 stable 直接 pin;升版走顯式 bump commit;對齊 §1.6 版本鎖點哲學） | §1.6 | ✅ 已決 |
| ⚠️e | `5000` 的 HTTP status 配對 | ✅ 已決(2026-06-12)：**一律 HTTP 200 信封**（對齊前端 msg 顯示通道僅 200 生效＋「business error 走 200」總則）；`AppError::Internal`→HTTP 500 mapping 標 test-only 或刪除；contract test 鎖 `5000`→200 | §5.4・§7.3 | ✅ 已決 |
| ⚠️f | 13 碼矩陣整組凍結（含 4 保留碼） | ✅ 已決(2026-06-12)：**整組凍結**（保留碼是前端 `.env` 分組實值、刪碼違 §I.1）；contract test 斷言「後端從不發出 7778/8889/9998/9999」 | §7.3 | ✅ 已決 |
| ⚠️g | constitution 重鑄措辭（§I.5 `axum-casbin`＋§9.6 Q5 rev1 指涉） | ✅ 已決(2026-06-12)：`axum-casbin` 重鑄為「enforce 層全新寫（in-tree、無獨立 crate）」；Q5/§I.5 對 rev2 source 立場＝**受控參照** — 讀允許（grep/閱讀對照驗證）、拷貝禁止（重新打字消化）、**防回歸條款**（rev3 拍板已推翻的行為不得帶回）；工具 crate `sea-orm-adapter`/`xdb` 例外自 rev2 整檔拷貝 | §9.2・§9.6 | ✅ 已決 |
| ⚠️h | 排程性拍板重議（§9.3 表之拍板 §11.2/§11.8/§11.13） | 重議走 amendment、不默改 | §9.3 | 重議觸發時 |
| ⚠️i | L4 授權模式 | ✅ 已決(2026-06-12)：**窄邊界精神的 rev3 起點映射** — i-1：MODAL-WIRING ★ v1.0.0 即授五用途 (a)~(e)（rev2 五次擴邊已驗證過的邊界、⚠️q 整批移植立即需要；**新用途 (f) 起仍走 amendment**）；i-2：BUILD-CONFIG ★ **不收錄**（⚠️p 後議題消解、軌道清單 5→4〔1★〕，日後需 build 改動走 amendment 新授） | §9.5 | ✅ 已決 |
| ⚠️j | rust-api 源倉 | ✅ 已決(2026-06-12)：**沿用倉、換分支**——`fork260509-rev2-anew-rust-api` 倉名（含 rev2）為永久名保留、分支改 `rev3-admin-rust-api`（已落地） | 附錄 A | ✅ 已決 |
| ⚠️k | migration 檔名 | ✅ 已決(2026-06-13)：**短編號 `mNNN_<name>`**（如 `m001_create_sys_user`;NNN 遞增、sea-orm 依檔名序執行;語意在檔名、無長零串——rev2 live 稽核實證 8 條引用多打一個 0 的抄錄必錯,附錄 C） | 附錄 C | ✅ 已決 |
| ⚠️l | settings 多 key 熱讀 | 需要時把單鍵 swap 推廣為 keyed map（設計變更、非預設） | §5.6 | 不阻塞（需要時） |
| ⚠️m | §1.2 尾巴（alt-login stub 4 + captcha 2）入波或重議 | 入波（§8.2 待拍板刀位）；重議則走 §9.5 amendment。**註(2026-06-12)**：captcha 2 端點已隨 ⚠️c 完整包拍定（stub 雙模、alova/scenes 需要）— 本項殘餘範圍縮為 alt-login 4 流程 stub 的入波排程 | §1.2・§8.2 | 波 3 排程前 |
| ⚠️n | 三 log 表 DB retention 政策 | rev3 v1 僅容量監控、retention defer | §1.3・§10.5 | 不阻塞（容量警示觸發時） |
| ⚠️o | application-RI 驗證下沉 facade 層 | ✅ 已決(2026-06-16)：**hybrid 分層**——intra-entity 純 ref 檢查（如 `sys_menu` reparent 3+1 guard）下沉 facade 自驗（slim model-層 error enum、不依賴 `AppError`→無層級倒置；handler 映 biz 2222）；跨 facade／需 context／restore-skip（grant role-code 解析、archive restore 不驗）留 handler orchestrate；DB 能擋者（unique）續走 `DbErr`→handler `sql_err()` 映碼。取代「全 handler 層驗」舊取向。接受代價：少數自驗 method 多一個 error enum＋handler match（受控）；換得 intra-entity RI 集中/繞不過、且避開 full facade-down 的層級倒置／restore 衝突／跨 facade 耦合。機制與分層詳見 DESIGN §3.3。user 親決 | §3.3 | ✅ 已決 |
| ⚠️p | demo menu 隱藏機制 | ✅ 已決(2026-06-12)：**翻案 — 全部 demo 頁進 sys_menu seed、初始僅勾給 R_SUPER**；「隱藏機制」議題消解（hideInMenu／pageExcludePatterns 皆不啟用），可見性全交 ROLE 勾選層（casbin menu 維度）治理下放。推翻 rev2 §11.5 的隱藏取向（constitution-rev3 重鑄時同步改寫、⚠️g 同梱）。配套盤點 **✅ 完成（2026-06-12）**：API 依賴者共 4 頁＝⚠️c 完整包三頁＋`plugin/excel`（用既有官方端點 `getUserList`、零新端點）；其餘 demo 頁純前端；`demoRequest` 線路 vanilla 閒置。詳 §6.1 表 | §6.1 | ✅ 已決 |
| ⚠️q | worktree 內容起點（base-web／rust-api 帶不帶 rev2 程式碼） | ✅ 已決(2026-06-12)：base-web=**clean-slate 血緣**（自 `example` 衍生、已落地）＋**整批移植** `rev2-admin-base-web` 完成接線＋rev2→rev3 改名（附錄 A.2）；rust-api 依 §8 波次**從零重寫**（已落地、`main`@Initial commit） | §8.4 波 -1・附錄 A | ✅ 已決 |
| ⚠️r | id 序列化策略（rev2「id 全字串」凍結存廢） | ✅ 已決(2026-06-12)：**廢除字串凍結 — 逐欄位忠實 typings**。DB 一律 i64 自增（BIGSERIAL）；僅在 rust-api **序列化邊界**對 typings 宣告 string 的欄位轉換（`MenuRoute.id`・`userId`）；其餘（`CommonRecord.id`/`parentId`/`MenuTree.id/pId`/`Role.id`、write payload `ids`）回 JSON number；serializer 加 2^53 fail-loud 守衛。**推翻 rev2 constitution §I.3／§11.10 的 string 拍板**（刻意偏離、constitution-rev3 重鑄時與 ⚠️g 同梱處理）；rev2 025-I1 類 type-lie 自此根除、lie ledger 初始為空 | §7.2・§9.2・§9.3 | ✅ 已決 |
| ⚠️s | fork-delta 執行紀律（授權後 inline／改值的變動方式） | ✅ 已決(2026-06-12)：**雙模式＋統一標記**（起因：upstream example 常態更新、rebase 須快速定位 fork 差異）— 修改型（MODAL-WIRING (a)(b)、ADAPT `.env` 改值等）**原行註解保留**緊鄰新行＋標記；新增型（(c)(d)(e) 插入/新檔）標記圈界、新檔僅檔頭一行；標記統一含 `rev3-inline` token（grep＝完整 fork patch set）；**rebase 同步紀律**（解衝突時註解原行更新為 upstream 現行版）；⚠️q 整批移植時修改型逐處補 example 原行註解（B 案）。落 constitution §III fork-delta 紀律＋§I.1＋Check Q2；inline_coverage_lint 候選登 CHECKLIST §3.3 | constitution §III（§9.4 重鑄時摺合） | ✅ 已決 |
| ⚠️t | schema 交付模型（逐刀建表 vs 波 0 一次全建） | ✅ 已決(2026-06-13)：**rev2 終態 squash 基線＋rev3 delta 顯式分離，波 0 一次全建**——002 刀以 `m001_rev2_schema.rs`（12 表終態忠實濃縮〔口徑：m001 實建 11——10 手寫＋casbin 委派 adapter；＋seaql 框架自建＝12，002 analyze L2 勘誤〕、零 FK 原樣）＋`m002_rev2_seeds.rs`（seed 淨效果——**勘誤 2026-06-13/002 brainstorm**：原文「17 條」對不上任何實數口徑〔seed 檔名 16 支／含 INSERT 20 支〕，重錨定＝**92 列／6 表**：sys_user 3・sys_role 3・sys_user_role 3・sys_menu 10・casbin_rule 72・system_settings 1，UPDATE 回填淨值併入終態列；源碼＋活庫雙驗）落地 rev2 基線（`mNNN_<name>` 短編號〔⚠️k〕、35→2 squash＝重寫非照拷〔§I.5 受控參照〕）；rev3 拍板 delta 顯式 m003+（④ FK、⚠️p/⚠️c seed 擴充）；**pg_dump 雙庫互 diff 驗證閉環**（參考庫＝pristine 重放、normalize 規則與 diff 範圍見 002 brainstorm §3.5——argon2id／`\restrict`／seaql_migrations／timestamps・setval 正規化）。後刀 migration 工序改「驗表已在＋補刀特有 seed」。屬 §8 交付序調整（§8.6 不構成設計變更）；§3.4「同刀建表」字面讓位其防 retrofit 精神（一次全建更強滿足）。誕生於 001 brainstorm（docs/superpowers/001-infra-deploy.md §2） | §3.4・§8.1・§8.2 | ✅ 已決 |
| ⚠️u | constitution §IV 缺 §I.4 工作流對應題（**amendment 提案**） | ✅ 已決(2026-06-16)：**不採納、日後不再議**——維持 constitution §IV 現 9 題、不增第 10 題（「plan/tasks 是否把 push/merge 排入實作期」）、不 bump。原提案(2026-06-13)背景：001 `/speckit-analyze` 發現 T021 曾排 worktree push、9 題結構上抓不到。**push/merge 不入實作期的紀律已固化於 CLAUDE.md §3**（★核心紀律＋階段 2「絕不 push/merge」）＋§I.4 凍結令＋人工 review 已足，constitution §IV 增題冗餘；本項 close | constitution §IV | ✅ 已決 |
| ⚠️v | casbin_rule 建表方式（委派 adapter vs 直接 CREATE；牽動 sub-crate 刀時序） | ✅ 已決(2026-06-13)：**委派式——m001 內 `sea_orm_adapter::up()` 建 8 欄基底＋同檔 ALTER 補 3 治理欄成 11 欄終態；sea-orm-adapter sub-crate 併入 002**（§I.5 拷貝例外整檔拷貝、`casbin = 2.20` pin 隨刀；**xdb 留 audit 刀**首個消費者帶入；**sub-crate 獨立刀消解**）。保「單一 schema 來源」紀律（rev2 m005 注記原則）＋與 Auth 刀 runtime `SeaOrmAdapter::new` 的 if_not_exists 自建一致。直接 CREATE 案被否：雙 schema 來源＋`unique_key_sea_orm_adapter` CONSTRAINT 細節手抄對齊成本＋adapter 升版 drift 隱患。誕生於 002 brainstorm（docs/superpowers/002-rev2-schema-baseline.md §2） | §3.1・§8.2 | ✅ 已決 |
| ⚠️w | login lockout（登入失敗限流）刀位 + 設計 | 預設：**做**——消費 audit-overlay 刀備齊的 `sys_login_attempt` 的 `(client_ip,created_at)`／`(attempted_user_name,created_at)` 索引（DESIGN §5.8／附錄 F「服務 login lockout 內部查詢」、rev2 FR-008），login 前置 count 時窗內 fail 數→超閾值回 lockout 碼擋提交＋前端顯示「鎖定 N 分鐘」。**資料源由 audit-overlay 刀備齊、本 ⚠️w 為消費 gate**；per-ip lockout 因 audit-overlay 備齊真實 client IP 而可行（per-ip／per-user〔兩索引都備〕／both＝排程時定）。設計待決：①刀位/wave（有狀態 auth 行為→波 3 候選；只讀資料、可提前獨立排）②政策值（X 次/N 分鐘）③login-attempt 失敗寫可靠度（best-effort 夠 defense-in-depth）。誕生於 audit-overlay brainstorm（user 親提 2026-06-14、v2 2026-06-15） | §5.0・§8.2 | 做（刀位/設計待排程時定） |
| ⚠️x | endpoint_coverage_lint 是否為波 0 出口硬條件（三守恆之一） | ✅ 已決(2026-06-14)：**波 0 換波豁免**——`endpoint_coverage_lint`（鎖 main.rs router==ENDPOINT_REGISTRY==seed、target `EXPECTED_ROUTE_COUNT=35` gated route，DESIGN §7.1／§8.4）**結構上需首個受保護業務端點存在才能立**；波 0（地基刀群）**零 gated 業務端點**、無法在波 0 達成。故 user 親決：波 0 出口三守恆**豁免** endpoint_coverage_lint、**移交波 1 第一刀**（首個 gated endpoint wiring 時一併立、enforce_mw route_layer 首掛，§3.9／§3.6）；波 0 餘二守恆（entity_access_lint／migration up→down→up）照常。本碼 ⚠️x 正式登記此豁免（與 ⚠️w login lockout 分開） | §8.4・§3.9 | ✅ 已決 |
| ⚠️y | biz-error `msg` 多語系策略 | ✅ 已決(2026-06-16)：**A — 前端翻譯（`msg` 改載穩定 i18n key）**。wire `Res<T>{data,code,msg}` 的 `msg` 由人話改載**穩定 key**（如 `biz.role.notFound`）；base-web（soybean v2.2.0＋vue-i18n 11、現代 typed i18n）將 `onBackendFail`/`showErrorMsg` 改以 `$t(msg)` 翻譯、locale 補 error 命名空間；後端**語言無關**（產 key、不在地化）。base-web 為 wire＋i18n 權威（§I.1）→ 屬其契約演進；base-web 改動走 §III fork-delta（⚠️s `rev3-inline` 標記）。**graceful fallback**：vue-i18n `$t` 未命中 key 回傳原字串 → 過渡期未鍵化的 msg 仍可顯示。**接受代價**：後端 log/curl/audit 的 `msg` 變 key（人話可讀性降）——以此換「單一 i18n 家（base-web）＋後端語言無關」。否決 B（後端在地化）：免後端另養訊息 catalog＋雙邊翻譯漂移。key 命名規約／error 命名空間於刀 1（system_settings 首批 biz error）brainstorm 定。誕生於 ⚠️o 範例 msg 討論。user 親決 | §7.3・§5.4 | ✅ 已決 |

---

## §2 實施階段（rev3 波次 as-built 帳）

> 骨架衍生自 DESIGN §8.4 交付波次（波次定義／出口條件在彼、執行紀錄在此）。
> **回填紀律**：波／Phase 完成後，as-built（feature 清單＋merge SHA＋日期）回填本節對應波；CHECKLIST「Roadmap & Phase 狀態」該波收縮為一行指本節。本節**永久留此、DESIGN 重鑄不摺**（執行帳不屬於藍圖 — rev2 §10 的 65 次補丁教訓）。

### 波 -1 — repo 建構 ✅ 全完成（2026-06-12）

- ✅ outer repo＋worktree/submodule 註冊（`2ec9cda`；⚠️j／⚠️q 拍板已落地）
- ✅ CLAUDE.md-rev3／.gitignore 家族／.specify spec-kit 殼
- ✅ 設計書入 docs/（`7fd1ac6`）＋拍板回填（`88f9011`）＋歸位改名 INTEGRATION-DESIGN.md（`4aa7c89`）＋C 方案文件體系（DECISIONS/CHECKLIST/MILESTONES，`4724549`/`4300b54`）
- ✅ graphify 首次建圖（`8f66fe0`，2060 nodes/311 communities）
- ✅ base-web standalone 容器化＋mock wire ground truth 捕獲與對映（000：`46591c4`/`309099d`/`aea0e18`/`e898421`）
- ✅ SessionStart hook（`.claude/settings.json`＋`hook-git-submodule-SOP.sh`；自 rev2 原樣承接、workspace-agnostic 零改動、實測健檢＋CHECKLIST 注入跑通，`ed2a789`）
- ✅ constitution-rev3 v1.0.0 重鑄凍結（`167db96`，獨立 commit；§9 快照 carry＋13 項拍板融入＋§V.2 提案位置=DECISIONS §1＋⚠️s fork-delta 紀律；雙輪驗證〔忠實度 8 項＋操作性 4 項〕後凍結）
- ✅ 出口條件四項全綠（2026-06-12 驗）：session 健檢綠（hook 實測）／constitution v1.0.0 獨立 commit／設定・部署層 grep rev2 歸零（豁免：`fork260509-rev2-anew-rust-api` 倉永久名〔⚠️j〕與史料引用；`.gitignore`/`.graphifyignore` 2 處註解殘影同輪修正）／`/speckit-*` 指令可用（scripts＋skills 在位）

### 波 0 — 地基（未開始）

### 波 1 — 第一刀（未開始；刀位待決③）

### 波 2 — data islands（未開始）

### 波 3 — 行為島＋policy（未開始）

### 波 4 — observability（未開始）
