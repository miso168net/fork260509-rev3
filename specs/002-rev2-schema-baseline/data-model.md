# Data Model — 002-rev2-schema-baseline

> **權威序聲明**：本檔是**座標圖、不是權威**。權威序＝①活庫 dump（`/tmp/rev2-schema-dump.sql`、pg_dump 17.10、717 行；volatile——若不存在以 `docker exec rev2-admin-postgres-1 pg_dump -U soybean -d soybean_admin_rust --schema-only > /tmp/rev2-schema-dump.sql` 重生〔rev2 stack 須在跑〕；亦見 quickstart 前置與 C-V-0）＞②rev2 migration 源碼（`/mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api/migration/src/m20260529_0000NN_*.rs`，下稱 `mNNN`）＞③本檔。implementer 寫 m001/m002 時**逐表打開 dump 行範圍與 migration 源碼對照**，不得只抄本檔。
> **勘誤紀律**：本檔任何座標／數字與 dump 或源碼不符 → 以 dump／源碼為準、回頭最小 patch 本檔並在 PR 注記；不得反向「改 dump 遷就文件」。
> 第三對照源：DESIGN 附錄 F（`docs/INTEGRATION-DESIGN.md:849-865`，逐表 PK/業務欄/索引，live 稽核 2026-06-09 零 drift）。

## 1. 基線 12 表對照表（m001 目標終態）

dump 行號＝`/tmp/rev2-schema-dump.sql` 的 CREATE TABLE 區塊；憲法/約束行號另列於下表後。欄數為 dump 實數。

| 表 | 欄數 | PK | uniques（名稱＋條件） | 一般 index | archetype | rev2 migration 疊加鏈 | dump 行 |
|---|---|---|---|---|---|---|---|
| `sys_user` | 16 | `id` BIGSERIAL | `sys_user_user_name_active_uniq`（partial：`user_name WHERE deleted_at IS NULL`，dump:709） | — | A 業務 | m001→m003→m008→m014→m027 | 392-409 |
| `sys_role` | 12 | `id` BIGSERIAL | `sys_role_code_active_uniq`（partial：`code WHERE deleted_at IS NULL`，dump:702） | — | A 業務 | m006→m016→m021 | 309-322 |
| `sys_menu` | 28 | `id` BIGSERIAL | `sys_menu_route_name_active_uniq`（partial：`route_name WHERE deleted_at IS NULL`，dump:695） | — | A 業務＋D 治理（`protected`） | m018→m034 | 209-238 |
| `system_settings` | 10 | `setting_key` varchar(64)（**無序列**） | 無（PK 即總體唯一、**無 partial-uniq** — §3.2 例外） | — | A 業務 | m028 | 451-462 |
| `sys_user_role` | 2 | **複合** `(user_id, role_id)`（dump:623） | — | — | C-join（**零審計欄**、硬刪） | m007 | 439-442 |
| `sys_token` | 9 | `id` BIGSERIAL | `sys_token_token_hash_key`（UNIQUE constraint `token_hash`，dump:607） | `idx_sys_token_chain`（dump:674）・`idx_sys_token_expires_at`（dump:681，m030 補）・`idx_sys_token_user_active`（**partial 非 uniq**：`user_id WHERE status='active'`，dump:688） | C-狀態機（僅 `created_at`） | m026→m030 | 352-362 |
| `sys_operation_log` | 10 | `id` BIGSERIAL | — | — | B append-only | m004 | 268-279 |
| `sys_access_log` | 10 | `id` BIGSERIAL | — | — | B append-only | m011 | 84-95 |
| `sys_login_attempt` | 9 | `id` BIGSERIAL | — | `idx_login_attempt_ip_time`（`client_ip, created_at`，dump:660）・`idx_login_attempt_user_time`（`attempted_user_name, created_at`，dump:667） | B append-only | m012 | 169-179 |
| `casbin_rule` | 11 | `id` BIGSERIAL | `unique_key_sea_orm_adapter`（UNIQUE constraint `(ptype,v0..v5)` 7 欄，dump:639） | — | D 治理 | m005（**委派 adapter DDL**）→m031 | 30-42 |
| `sys_casbin_policy_archive` | 13 | `id` BIGSERIAL | — | `idx_casbin_archive_archived_at`（dump:646）・`idx_casbin_archive_role_dim`（`v0, v2`，dump:653） | D 治理-restore-buffer | m032 | 125-139 |
| `seaql_migrations` | 2 | `version`（dump:543） | — | — | 框架表 | sea-orm 框架自建 | 72-75 |

**特例注記**（implementer 必讀）：

- **INET custom type**：`sys_access_log.client_ip`／`sys_login_attempt.client_ip`（皆 NOT NULL）／`sys_operation_log.operator_ip`（nullable）為 PostgreSQL `inet` — SeaORM 需 custom 處理：**對照** rev2 m004/m011/m012 的 `custom(Alias::new("inet"))` 寫法**重新實作**（§I.5 受控參照：讀允許、拷貝禁止——migration 不在拷貝例外清單）。
- **NOT NULL 特例**：`sys_access_log.operator_id` **NOT NULL**（dump:86；同名欄在 `sys_login_attempt` 是 nullable，dump:173）；`sys_token.user_id` **NOT NULL**（dump:354）。
- **`sys_token` 時間欄**：`issued_at`/`expires_at` NOT NULL、唯 `used_at` nullable（NULL 語意參與 fail-closed 判定，見 DESIGN 附錄 F #6）。
- **`casbin_rule` = adapter 8 欄＋治理 3 欄**：前 8 欄（`id` + `ptype` varchar(18) + `v0..v5` varchar(125)，含 `unique_key_sea_orm_adapter`）由 adapter DDL 定義 — 對照 `/mnt/d/AnewSpaces/x_Project/fork260509-rev2/rust-api/sea-orm-adapter/src/migration.rs:19-56`（`pub async fn up`）；後 3 欄（`protected` bool NN default false、`created_at` tstz NN default now、`created_by` bigint）由 m031 ALTER 補（adapter-invisible）。
- **`sys_casbin_policy_archive` 的 `v3..v5`**：default `''`（dump:131-133；與 `casbin_rule` 的 NOT NULL 無 default 不同形）。

## 2. 欄序忠實警告（schema diff 硬約束）

dump 的 CREATE TABLE 欄序＝**歷史疊加序**（create 欄在前、各次 ALTER ADD COLUMN 依時序排後）。m001 squash 後產出的表**欄序必須逐欄等同 dump**、不得按邏輯分群重排 — 驗收用 schema diff 比對、欄序不同即 fail。示例（`sys_user`，dump:392-409 實序；這是要對齊的目標、可逐字抄）：

```
id, user_name, password,                                  ← m001 create
deleted_at,                                               ← m003
nick_name,                                                ← m008
user_gender, user_phone, user_email, status,
created_at, created_by, updated_by, deleted_by, updated_at, ← m014（注意 updated_at 在 deleted_by 後）
current_session_id, session_policy                        ← m027
```

其餘 11 表同理：欄序一律抄 dump 對應行範圍，不憑 archetype 直覺排。

## 3. seed 資料模型（m002 — 92 列 / 6 表）

m002 = rev2 全部 seed 段（散在 15+ 支 migration 的 INSERT＋後續 UPDATE）squash 成**淨值一次寫入**。各表列數＝rev2 活庫實測（2026-06-13 psql count）：

| 表 | 列數 | 值來源座標（rev2 migration） |
|---|---|---|
| `sys_user` | 3 | m002（INSERT＋argon2id hash，`m..002:14-16`） |
| `sys_role` | 3 | m006（INSERT，`m..006:55-58`） |
| `sys_user_role` | 3 | m007（INSERT，`m..007:38`；1→1、2→2、3→3） |
| `casbin_rule` | 72 | m009/m010/m013/m015/m017/m019/m020/m021/m022/m023/m024/m025/m029/m033/m035 各 seed 段（**轉錄省力法**：以 C-V-2 pristine 重放庫的 data dump `COPY casbin_rule` 段為 72 列逐列轉錄源、15 支源檔降為交叉核對——首輪命中率優先，diff 閉環為兜底） |
| `sys_menu` | 10 | m018（home/manage＋manage 4 子頁＝6 列，`m..018:113,125-130`）＋m022（function＋function_toggle-auth＝2 列，`m..022:23`）＋m029（manage_system-settings 1 列，`m..029:32`）＋m035（manage_policy-archive 1 列，`m..035:35`） |
| `system_settings` | 1 | m029（`single_session_default`=`off`、`value_type`=`enum:on,off`） |

**不變式**（m002 寫完後 psql 驗）：

- `casbin_rule`：**p=72／g=0**（user↔role 走 `sys_user_role`、不用 casbin g 列）；**protected=19**（m033 三段 UPDATE 標 16 列〔3 menu＋7 GET＋6 POST，`m..033:24-37`〕＋m035 標新插 3 列〔`m..035:57`〕）。
- `sys_menu`：**protected=8**（m034 UPDATE 7 列〔`m..034:38`〕＋m035 INSERT 自帶 protected=true 1 列〔`m..035:36`〕）；`function`/`function_toggle-auth`（id 7/8）不受保護。
- `sys_user`：id 1/2/3（`Super`/`Admin`/`User`）**sequence-driven**（不顯式指定 id、靠插入序）；3 列共用**同一個 runtime 生成 argon2id hash**（random salt、每次重跑字串不同、皆驗得過 `123456`；活庫 `count(DISTINCT password)=1` 實證）。
- **UPDATE 淨值併入清單**（rev2 後置 UPDATE → m002 直接寫淨值）：`nick_name`＝`Super`/`Admin`/**`User01`**（`m..008:29-31`；id 3 是 alias 非 `User`）；`sys_user.status=1`（`m..014:66`）；`sys_role.status=1`（`m..016:49`）；`sys_role.home='home'`（`m..021:33`）；`manage_user.buttons` registry（`m..022` 段 (2)）；上列 protected 旗標。

## 4. delta 模型（rev3 新增）

- **m003 — FK ×2**：`sys_user_role.user_id → sys_user.id`、`sys_user_role.role_id → sys_role.id`；皆 **ON DELETE RESTRICT**（工程預設；活庫 dump **無任何 FOREIGN KEY**＝rev2 終態無 FK、故此為純 delta、不影響 m001 基線 diff）。
- **m004 — demo menu**：集合凍結＋映射權威＝**`contracts/demo-menu-enumeration.md`**（66 條＋28 欄映射表；衍生裁定背景在 research.md R4）、本檔不重複（單一來源紀律）。

## 5. 排除聲明

`seaql_migrations`（dump:72-75）為 sea-orm 框架自建表：**不寫入任何 migration**、schema diff 比對時**整表排除**（rev2 實況 applied=35 條、rev3 依自身 migration 計，兩邊必然不同）。
