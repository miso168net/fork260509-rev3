# Contract: migration-chain（002-rev2-schema-baseline）

## 1. m001~m004 行為契約（lib.rs vec 序＝執行序）

| 支 | up | down | 備註 |
|---|---|---|---|
| `m001_rev2_schema` | 10 表手寫終態 DDL（**dump 欄序忠實**）＋`sea_orm_adapter::up()`（8 欄＋unique constraint）＋同檔 ALTER casbin_rule 補 protected/created_at/created_by | DROP 10 表（含 index 隨滅）＋`sea_orm_adapter::down()` | sys_user 直接 BIGSERIAL（dump 形等價已驗、research R7）；INET 用 custom(Alias)；NOT NULL 特例：access_log.operator_id、token.user_id |
| `m002_rev2_seeds` | 92 列／6 表淨效果直接 INSERT（sequence-driven、user_role 雙向 subquery、casbin 免 subquery、argon2id 單一 hash、`ON CONFLICT DO NOTHING`） | DELETE 限定本支插入集（6 表全列——基線即全集） | UPDATE 淨值（nick_name=User01／status=1／home='home'／buttons／protected）直接入 INSERT、不重演修補 |
| `m003_user_role_fk` | `sys_user_role` ADD FK ×2（→sys_user.id／sys_role.id、`ON DELETE RESTRICT`） | DROP CONSTRAINT ×2 | ④ 拍板；其餘 11 表維持零 FK |
| `m004_demo_menu_seeds` | demo 選單 66 列（深度 4 段分批、parent_id subquery）＋menu policy 66 列（`'p','R_SUPER',<route_name>,'menu','','',''`） | **DELETE 限定 demo route_name 集**（sys_menu＋casbin 同）——不得照抄 rev2 m010 的 `v2='menu'` 全刪形（會波及基線 17 列） | ⚠️p；R4-D1~D4 裁定；document 8 頁 href 化 |

## 2. 檢查點語意

- **基線檢查點**＝m002 後、m003 前（`migration up -n 2`）——⚠️t 零差異斷言的唯一合法比對點。
- delta（m003/m004）套用後與 rev2 **必然有差**——不再跑零差異 diff、改跑 delta 斷言（C-V-4）。
- 部分套用中斷→重跑 `up` 自 seaql_migrations 續行（框架語意）；檢查點重入安全。

## 3. normalize 六規則（凍結；缺一假紅）

| # | 對象 | 規則 |
|---|---|---|
| 1 | `\restrict`／`\unrestrict` 行 | 過濾（pg_dump 17.6+ 每次隨機 token） |
| 2 | `seaql_migrations` | schema＋data 全排除（rev2 35 列 vs rev3 2 列、必然不同；DESIGN 附錄 F #12） |
| 3 | `sys_user.password` | 置換佔位（argon2 random salt、兩側必異）；可驗性另斷言（C-V-3 VERIFY-OK） |
| 4 | seed 時戳欄（created_at 等 default now() 實值） | data dump 置換佔位；兩側皆 seed 時刻、必異 |
| 5 | `setval` 行（data dump） | 置換佔位；序列終值另斷言（sys_user_id_seq last_value=3／is_called=true〔`last_value||','||is_called` 拼接形〕兩側一致） |
| 6 | COPY 段列順序（data dump） | 每個 COPY 區塊內資料行排序（pg_dump 按 heap ctid 輸出；前代經 35 支 migration 的 UPDATE 移位、本基線一次性 INSERT，物理列序必異＝dump 雜訊非資料差異；sort 後 id＋全欄仍逐列比對、不遮蓋實質差異——漏列/多列/欄值錯照樣紅）。**執行序：須在 #3/#4/#5 雜訊置換之後排序**（先固定佔位再 sort，否則兩側 hash／時刻字典序不同會 sort 後仍錯位） |

**判讀紀律**：diff 非零→先對照本表判「normalize 缺漏（假紅）」；確認非六規則範圍→真 drift→修 m001/m002 重跑。**禁止**為過 diff 而擴充 normalize 規則遮蓋實質差異（規則變更＝契約修訂、須留痕）。

> **第六規則為本刀執行期（C-V-2/C-V-3 暖身）發現的假紅源補列**：原五規則無法消除 pg_dump `--data-only` 的 COPY 物理列序雜訊——前代 pristine 重放庫經 35 支 migration（含 m033/m034 的 protected UPDATE）造成 heap ctid 位移（如 sys_menu ctid 序＝`7,8,1,2,6,3,4,5,9,10`、casbin 跳號），rev3 一次性 INSERT 的 ctid 序＝插入序；即使 m002 已修齊 id 配置（Layer 1），兩側 COPY 物理列序仍不同 → diff 仍假紅。此物理序為 UPDATE 產物、不可用 INSERT 順序重現，故 user 拍板方案 A（normalize 第六規則對 COPY 段排序消除此噪聲），契約修訂留痕於此。

## 4. 不變式總表（C-V 斷言來源）

- 基線：12 表（10 業務＋casbin＋seaql）；92 列＝3+3+3+10+72+1；p=72／g=0；protected casbin 19／menu 8；sys_user id={1,2,3}；hash 單一且 `$argon2id$v=19$` 前綴、驗得過 `123456`；零 FK；partial uniq ×3＋全表 uniq ×2＋一般 index 7。
- delta 後：FK=2（confdeltype='r'）；sys_menu 76；casbin 138（menu 維度 83）；基線 92 列原值不變。
