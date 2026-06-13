# 002-rev2-schema-baseline — Phase 0 brainstorm（2026-06-13）

> 波 0 第二刀；⚠️t 拍板產物（[DECISIONS §1](../INTEGRATION-DECISIONS.md)）。本檔＝`/speckit-specify` 的 input（user 手動執行、不在本流程觸發）。
> 拍板四項：⚠️v 委派式＋adapter 併入｜seed 口徑 92 列勘誤｜pristine 重放｜m003+ 全包。

---

## 1. 研究 ground truth（4 路平行研究、源碼＋活庫雙驗）

- **rev2 35 支 migration → 終態 12 表**（10 業務＋casbin_rule＋seaql_migrations〔框架自建、不入 migration〕）；疊加鏈最深 sys_user（001→003→008→014→027、16 欄終態）。
- **活庫實證**（rev2-admin-postgres-1、pg_dump 17.10 schema dump 717 行）：**零 FK**（含 sys_user_role）；partial unique ×3（`WHERE deleted_at IS NULL`）＋全表 unique ×2（`sys_token_token_hash_key`／casbin `unique_key_sea_orm_adapter`）；一般 index 7；audit archetype 四變體分布與 DESIGN §3.2／constitution §I.6 一致。
- **seed 淨效果實數**：**92 列／6 表**＝sys_user 3・sys_role 3・sys_user_role 3・sys_menu 10・casbin_rule 72（p=72、g=0）・system_settings 1；UPDATE 回填淨值＝nick_name `User→User01`、status=1、home='home'、buttons registry、protected（casbin 19 列＋menu 8 列）。⚠️t 原文「17 條」對不上任何口徑→**勘誤重錨定**（已回填 DECISIONS ⚠️t 列）。
- **casbin_rule 在 rev2**：m005 委派 `sea_orm_adapter::up()` 建 8 欄基底（檔內注記「單一 schema 來源＝adapter、避免 drift」）＋m031 事後 ALTER 加 3 治理欄→11 欄終態；`unique_key_sea_orm_adapter` 為 **UNIQUE CONSTRAINT**（非裸 index）；runtime `SeaOrmAdapter::new` 亦自呼 `migration::up`（if_not_exists no-op）。
- **argon2 seed**：runtime 生成（`SaltString::generate`＋`Argon2::default()`、plaintext `123456`、**3 帳號共用單次 hash**——源碼單次 `hash_password` 呼叫＋活庫 `COUNT(DISTINCT password)=1` 雙證；研究中「3 筆互異」一說已被直接證據否定）；PHC 字串 SQL-literal 安全（rev2 m002 注記）。
- **依賴面**：argon2 0.5.3 不引 time；sea-orm-adapter 的 sea-orm `default-features=false` 不引 time——**time 目前不在 rev3 lock（count=0）**、002 免 pin 加工、lock 變動後複驗即可。
- **diff 工具面**：host pg_dump 16 打 17 server 被拒→雙端一律容器內 pg_dump 17.10；pg_dump 17.6+ 輸出含**每次隨機 `\restrict` token 行**→normalize 必過濾。

## 2. 本次拍板（user 親決 2026-06-13）

1. **⚠️v casbin_rule 建表＝委派式、sea-orm-adapter 併入 002**（新列已登 DECISIONS §1）：m001 內委派 `sea_orm_adapter::up()`＋同檔 ALTER 補 3 治理欄；adapter 整檔拷貝（§I.5 例外）＋`casbin = 2.20` pin 隨刀；**xdb 留 audit 刀**（首個消費者）帶入；**sub-crate 獨立刀消解**（CHECKLIST 波 0 清單同步改）。直接 CREATE 案被否：雙 schema 來源＋CONSTRAINT 細節手抄對齊成本＋adapter 升版 drift 隱患。
2. **seed 口徑重錨定＝92 列／6 表**：m002 驗收口徑改以實數為準（明細見 §1）；DECISIONS ⚠️t 列補勘誤注記、結論不變。
3. **diff 參考庫＝pristine 重放**：拋棄式 postgres:17-alpine＋rev2 既有 image 重放 35 支→純淨參考庫；活庫降級 sanity 交叉。
4. **m003+ delta 範圍＝照 ⚠️t 全包**：m003 FK＋m004 ⚠️p 全 demo 頁 seed（⚠️c 三頁為子集）。

## 3. 設計總形（已核可）

**§3.1 交付物**
- `rust-api/migration/src/`：`m001_rev2_schema`／`m002_rev2_seeds`／`m003_user_role_fk`／`m004_demo_menu_seeds`（lib.rs vec 序＝執行序）
- `rust-api/sea-orm-adapter/`：rev2 整檔拷貝＋workspace member＋`casbin = 2.20`；migration crate 加 `argon2 = 0.5.3`
- `tests/002-rev2-schema-baseline/`：pristine 重放／normalize／diff scripts（`scripts/`）＋dump 基準檔
- `deploy/Dockerfile.rust-api.txt`：Manifest／Source 段補 adapter COPY ×2 行（**新增 workspace crate ⇒ acceptance 必含 prod image build**，CLAUDE.md §3 紀律）

**§3.2 m001_rev2_schema（11 表終態忠實濃縮）**
- 10 表手寫終態 DDL（35 支疊加鏈壓平）＋casbin_rule 委派 adapter＋同檔 ALTER 3 治理欄（11 欄終態）
- 忠實基線：零 FK、partial unique ×3＋全表 unique `sys_token_token_hash_key`、一般 index 7、audit archetype 照活庫（§3.3 精確化：`sys_access_log.operator_id`／`sys_token.user_id` NOT NULL）、INET `custom(Alias)`、`unique_key_sea_orm_adapter` 由 adapter 建（CONSTRAINT 形自動對齊）
- sys_user 直接 BIGSERIAL 建表（rev2 retrofit 鏈不重演；**dump 形等價已驗 2026-06-13**——rev2 m014 raw SQL 本含 `OWNED BY`，dump 出 CREATE SEQUENCE〔無 AS 子句〕＋OWNED BY＋DEFAULT nextval 三段與 BIGSERIAL 完全同形）；對稱 `down()`（波 0 出口 up→down→up 守恆）

**§3.3 m002_rev2_seeds（92 列／6 表淨效果）**
- 直接 INSERT 終態值（UPDATE 回填鏈不重演、淨值入 INSERT）；§3.4 紀律②：sequence-driven 插入（空表確定性落 id 1/2/3）、user_role 雙向 subquery 解析（user_name／role code）——casbin 列**免 subquery**（v0＝role code 字串、created_by＝NULL）；argon2id runtime hash；冪等 `ON CONFLICT DO NOTHING`
- 終態斷言數字：casbin protected=true **19** 列、sys_menu protected=true **8** 列

**§3.4 m003＋m004（rev3 delta 顯式分離）**
- m003：`sys_user_role` FK ×2（→sys_user.id／sys_role.id；④拍板；ON DELETE 行為 spec 期定——對照 §3.3 義務、傾向 RESTRICT〔user/role 走 soft-delete、硬刪不應發生〕）
- m004：⚠️p 全 demo 頁 sys_menu seed＋menu 維度 casbin policy（僅 R_SUPER）；枚舉源＝**spec 期 grep base-web route tree 定稿**；⚠️c 三頁（alova/request・alova/scenes・function/request）為子集；echo／captcha 端點 policy 隨端點刀

**§3.5 驗證閉環（C-V 骨架）**
1. pristine 重放（rev2 image＋拋棄式 pg）→ 參考庫
2. **diff 檢查點＝m002 後、m003 前**（⚠️t 零差異斷言對象＝m001+m002）：rev3 側拋棄式 pg `migration up -n 2` 停在基線 → 雙 dump（容器內 pg_dump 17.10）→ normalize（`\restrict` 過濾／排除 seaql_migrations／argon2 hash・timestamps・setval 正規化）→ **schema diff＋6 表 seed data diff 雙零差異**
3. 同一拋棄式 pg 續 `up`（m003/m004）→ **delta 斷言**（FK ×2 存在〔pg_constraint〕、demo menu／policy 列數、protected 數不變式）——delta 套用後與 rev2 必然有差、**不再跑零差異 diff**
4. up→down→up 守恆（m001~m004 全鏈）＋dev stack migrate gate 實機（m001~m004 一次 up、rust-api healthy）＋活庫 sanity＋prod image build（adapter COPY 驗）＋lock 變動後 time 複驗

**§3.6 已知坑（spec 必載）**
- **欄序忠實**：pg_dump 的 CREATE TABLE 欄序＝歷史疊加序（如 sys_user：id→user_name→password→deleted_at→nick_name→m014 9 欄→m027 2 欄）——m001 手寫 DDL **必須照 dump 欄序、不得邏輯重排**（欄序不同＝schema diff 必紅）
- sys_user sequence：dump 形等價已驗（見 §3.2）；殘餘互驗＝setval 終值（pristine=3/is_called 與 rev3 sequence-driven 結果一致；data dump 的 `setval` 行入 normalize）
- m002 的 sys_menu 10 列＋menu 維度 policy 17 列，與 m004 demo 擴充集（menu rows＋policy rows）**雙層不重疊**邊界
- adapter 拷入後 `cargo build`＋Dockerfile prod build 雙驗；adapter Cargo.toml 依賴宣告形 spec 期核（直接 version dep vs `workspace = true`——後者牽動 rev3 workspace.dependencies 是否需加 sea-orm 條目）；xdb 不入本刀（[[bench]] 坑屬 audit 刀）
- 順手項（CHECKLIST §3.4）：migration main.rs secret 讀檔失敗補 eprintln 警示（rev2 同形缺陷）

## 4. spec 期義務（CLAUDE.md §3 Phase 0 research 紀律適用性）

- facade／wire 鏈 grep：**N/A**（本刀無業務 endpoint）
- **data-model 對照（本刀為實）**：data-model.md 逐表 file:line 對照源＝rev2 migration 源碼＋活庫 dump＋DESIGN 附錄 F；不得盲信本檔轉述
- **demo 頁枚舉 ground truth**：grep base-web route tree（static routes）、逐 route 出 sys_menu 欄位值；數量 spec 期定稿
- constitution Check Q8（新建業務表→§I.6 六審計欄、append-only／join 例外）本刀必答；§I.5 適用「受控參照」（squash＝重寫非照拷）＋adapter 拷貝例外

## 5. 交棒

→ user 手動 `/speckit-specify`（input＝本檔）；`before_specify` pre-hook 自動建 `002-rev2-schema-baseline` feature branch（commit hooks 已全 mandatory）。
