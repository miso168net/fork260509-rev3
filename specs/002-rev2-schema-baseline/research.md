# Research: 002-rev2-schema-baseline（Phase 0）

**Date**: 2026-06-13 ｜ **Input**: spec.md＋docs/superpowers/002-rev2-schema-baseline.md（brainstorm 4 路研究）＋plan 期實查（R3 manifest／R4 路由枚舉）

## R1 · 素材策略與 squash 紀律

- **Decision**: 35→4 squash＝重寫非照拷（§I.5 受控參照）；對照源權威序＝活庫 dump（`/tmp/rev2-schema-dump.sql` 717 行、可重生）＞rev2 migration 源碼＞任何轉述。**欄序忠實**：m001 DDL 照 dump 欄序（歷史疊加序）、不得邏輯重排——欄序不同＝schema diff 必紅。逐表座標見 data-model.md。
- **Rationale**: pg_dump diff 是零漂移唯一可信證據；欄序／索引名／constraint 名全是 diff 敏感面。

## R2 · casbin_rule 委派式＋adapter 拷貝（⚠️v 拍板落地）

- **Decision**: m001 內 `sea_orm_adapter::up()` 建 8 欄基底＋同檔 ALTER 補 protected/created_at/created_by 3 治理欄（11 欄終態；down＝`sea_orm_adapter::down()`、ALTER 隨表滅）。adapter 整檔拷貝自 `fork260509-rev2/rust-api/sea-orm-adapter/`（§I.5 例外）：`Cargo.toml`＋`src/{lib,adapter,entity,action,migration}.rs` ×5＋`examples/` ×4（rbac conf/csv——隨整檔拷貝帶入、dev-only）。
- **Rationale**: 單一 schema 來源（rev2 m005 注記原則）；與 Auth 刀 runtime `SeaOrmAdapter::new` 的 if_not_exists 自建一致。

## R3 · adapter manifest 宣告形實查（spec 期義務——**修正 brainstorm 依賴面聲明**）

- **實查結果**（rev2 `sea-orm-adapter/Cargo.toml` 全文讀）：deps 全為 **`workspace = true` 繼承形**——`async-trait`／`casbin`／`sea-orm`（＋`features=["macros"]`、`default-features=false` 旗標）。⇒ rev3 workspace.dependencies **必須新增 2 條目**：`casbin`、`sea-orm`（async-trait 已有）。
- **⚠️ rev2 的 time 根因確認**: rev2 workspace `sea-orm = { version="1.1.20", features=[...] }` 為 **defaults-on**（default features 含 `with-time`）→ time 入圖；member 的 `default-features=false` 對 defaults-on 的 workspace 條目**無效**（cargo 繼承規則）。brainstorm「adapter 不引 time」的前提（member 旗標生效）不成立——**time 是否入圖取決於 rev3 workspace 條目怎麼寫**。
- **Decision（刻意偏離 rev2、記錄之）**: rev3 workspace 寫 **`sea-orm = { version = "1.1.20", default-features = false, features = ["macros", "sqlx-postgres", "runtime-tokio-rustls"] }`**＋`casbin = { version = "2.20", default-features = false }`（後者同 rev2 形）。最小 features 集＝adapter 自身 feature map 所需（postgres＋runtime-tokio-rustls＋macros），**time 不入圖**；member 旗標與 workspace 一致、無 cargo warning。
- **義務**: lock 變動後 `grep -c 'name = "time"' Cargo.lock` 複驗＝0；若後刀（entity）改 defaults-on，屆時補 `time --precise 0.3.37` pin（workspace Cargo.toml 既有注記）。`cargo build` 綠＝最小集足以編譯 adapter 的最終裁決；不足則逐 feature 補（記錄偏離）。
- **dev-dependencies**: adapter 的 `tokio features=["full"]`（dev only）——workspace tokio 條目 features 可加法疊加、無需改。

## R4 · demo 頁枚舉定稿（⚠️p；m004 ground truth）

- **權威**: `base-web/src/router/elegant/routes.ts`（generatedRoutes 64 條）＋**`base-web/src/router/routes/index.ts`（customRoutes 15 條——exception×4＋document×11，不在 routes.ts、易漏）**；constant 判別＝`meta.constant`。
- **帳目**: generatedRoutes 64＝constant 5（login/403/404/500/iframe-page）＋基線重疊 8（home/manage/manage_user/manage_role/manage_menu/manage_user-detail/function/function_toggle-auth）＋demo 51；總 demo＝51＋15＝**66 條**（目錄 16／頁 50；最深 4 層）。基線另 2 條（manage_system-settings／manage_policy-archive）rev3 樹不存在、不撞。⚠️c 三頁（`alova_request`/`alova_scenes`/`function_request`）在集內 ✓。完整樹狀清單與 meta 要點＝R4 報告（嵌入 tasks 期逐列轉錄；本檔存帳目與規則）。
- **衍生裁定 D1~D4**（plan 期工程落值、/speckit-analyze 與 user 審查點）：
  - **D1 範圍＝66 條全集**——⚠️p「全部」字面＋可見性交 ROLE 層治理精神；customRoutes 一併入。
  - **D2 document 8 頁 `props:{url}` 形**：sys_menu 無欄可表達 compile-time props → **href 化**（url 入 `href` 欄、外開新分頁；零 schema 變更、零 wire 依賴）；iframe 內嵌復原（props 欄位／wire 擴充）登 Menu 刀 backlog。另 2 頁本就 href 形、原樣。
  - **D3 policy 粒度＝全覆蓋 66 列**（每 demo 節點一列 `('p','R_SUPER',<route_name>,'menu','','','')`）：rev2 `filter_routes` 只查兩層——depth-1 目錄**必須**有 policy（沒列整支被剪）、頂層目錄與 depth-2+ 不被 enforce（多餘列無害）；全覆蓋對 filter 未來遞迴化前向相容。嚴格最小集 41 列被否（隱性耦合 filter 實作細節）。
  - **D4 wire 降級照實 seed**：localIcon×8（icon_type=2）／multiTab×1／href×2 依 schema 忠實落欄——rev2 wire `RouteMeta` 不序列化這些欄屬 Menu 刀接線議題、不反向汙染 seed；登 backlog（RouteMeta 擴充＋`menu_node_to_route` 讀 icon_type）。
- **實作注意**: ①m004 INSERT 按深度分批（4 層→4 段、parent_id subquery 先父後子）②中層目錄 component=NULL（前端 falsy guard＋transform 自動 redirect、已驗安全）③`plugin` 的 menu_name 是中文「插件示例」④頂層 order 撞號（7×4）照 meta 原樣 seed（cosmetic）⑤**m004 down 不得照抄 rev2 m010 形**（`DELETE WHERE v2='menu'` 會連基線 17 列一起刪）——限定 `v1 IN (<demo 66 route_name>)`；sys_menu 同理限定 route_name 集。

## R5 · seed 92 列值來源與不變式拆解

- 逐表座標＝data-model.md §3。**protected 拆解**（單看一支 migration 會對不上活庫）：casbin 19＝m033 標 16＋m035 新插自帶 3；menu 8＝m034 UPDATE 7＋m035 INSERT 自帶 1。sys_menu 10 列＝m018×6＋m022×2＋m029×1＋m035×1（m029 檔名只暗示 settings、實際含選單列——易漏座標）。`sys_role.status=1` 來源 m016:49、`sys_user.status=1` 來源 m014:66。
- argon2：0.5.3、單一 PHC hash 三帳號共用（源碼＋活庫 `COUNT(DISTINCT password)=1` 雙證）；PHC 字元集無單引號、SQL-literal 安全（rev2 m002 注記 carry；**僅限此靜態 seed、禁用於 user 輸入**）。

## R6 · diff 閉環工具鏈

- **pristine 重放**: 拋棄式 network＋`postgres:17-alpine` 容器＋rev2 既有 image `rev2-admin-rust-api:latest` 跑 `migration up`（dispatcher 形）→ 35 支重放→參考庫。rev3 側同形拋棄式 pg＋`cargo run --bin migration up -n 2`（sea-orm-migration CLI 原生支援 `-n`）停在 m002 檢查點。
- **雙 dump**: 兩側皆容器內 `pg_dump 17.10`（host 16 版打 17 server 實測被拒）；schema＝`--schema-only --no-owner`；seed data＝`--data-only --no-owner -t` ×6 表。
- **normalize 規則（全集、缺一假紅）**: ①`\restrict`/`\unrestrict` 隨機 token 行過濾（pg_dump 17.6+）②排除 seaql_migrations（schema＋data）③argon2 hash 正規化（sys_user.password 欄置換為佔位）④timestamps 正規化（created_at 等 seed 時戳）⑤`setval` 行正規化（值斷言另做：兩側 sys_user_id_seq 皆 last_value=3/is_called=true）⑥COPY 段資料行排序（data dump；pg_dump 按 heap ctid 輸出、前代 UPDATE 移位 vs 本基線 INSERT 序物理列序必異＝噪聲；須在 ③④⑤ 雜訊置換後 sort——本刀 C-V-2/C-V-3 暖身發現的假紅源補列、user 拍板方案 A、留痕 migration-chain.md §3）。
- **scripts 落點**: `tests/002-rev2-schema-baseline/scripts/`（pristine-replay.sh／normalize.sh／diff-baseline.sh／delta-assert.sh）；dump 基準檔頂層。

## R7 · sys_user sequence 等價（已驗 2026-06-13）

- rev2 m014 raw SQL 本含 `OWNED BY`；dump 形（CREATE SEQUENCE 無 AS 子句＋OWNED BY＋DEFAULT nextval）與 BIGSERIAL 產物**完全同形**——m001 直接 BIGSERIAL、零 diff 風險。殘餘互驗＝setval 終值斷言（R6 ⑤）。

## R8 · FK ON DELETE 落值

- **Decision**: `ON DELETE RESTRICT`（×2）。Rationale：user/role 走 soft-delete、硬刪不應發生——RESTRICT 把「不應發生」升為 DB 層保證；CASCADE 會靜默刪關聯（違 §3.3 application-RI 精神）。ON UPDATE 不設（id 不變更）。

## R9 · migration crate 依賴增量

- `argon2 = "0.5.3"`（workspace＋migration crate；依賴鏈 base64ct/blake2/cpufeatures/password-hash、不引 time）＋`sea-orm-adapter = { path = "../sea-orm-adapter" }`（migration crate；m001 委派用）。
- 順手項（CHECKLIST §3.4 既登）：migration main.rs secret 讀檔失敗補 eprintln 警示。

## R10 · CLAUDE.md §3 Phase 0 三 grep 紀律適用性

| 紀律 | 本刀 |
|---|---|
| ① facade 真實返回型 grep | **N/A**——無業務 endpoint |
| ② wire 鏈 3 端對齊 grep | **N/A**（無新 wire）；seed 值與 typings 對齊已做（icon_type `'1'\|'2'`、R4 映射表對照 typings） |
| ③ data-model file:line 對照 | **已執行**——data-model.md 逐表 dump 行號＋migration 檔座標、全數親 grep 驗證 |

## 移交後刀 backlog（tasks 期登 CHECKLIST §3）

- Menu 刀：RouteMeta 擴充（localIcon/multiTab/href 序列化＋`menu_node_to_route` 讀 icon_type）；iframe props 內嵌復原評估（D2）；`filter_routes` 遞迴化評估（D3 配套）。**影響面帳目**：href 欄落值實為 **×10**（原生 2＋D2 href 化 8）——RouteMeta href 序列化接線同吃全 10 列、勿按原生 ×2 低估。
- rev2 回灌情報：rev2 workspace sea-orm defaults-on＝time 入圖根因（rev3 R3 已實證）——rev2 維護時可同步收斂。
