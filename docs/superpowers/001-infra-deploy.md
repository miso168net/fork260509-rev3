# 001 · infra-deploy 刀 — Phase 0 brainstorm 決策

> rev3 波 0 第一刀（rev3 首個 spec-kit feature）。brainstorm 完成於 2026-06-13；
> 本檔 = CLAUDE.md §3 階段 0 產出（spec-design），交棒 `/speckit-specify`（user 手動執行）。
> 對應 DESIGN §8.2 跨切地基「Infra/deploy」、rev2 001-007/010 對應。

---

## 1. 一句話

裁剪帶入 rev2 部署層＋最小 rust-api scaffold，實機達成「dev stack 5 service `up --wait` 全 healthy＋migrate gate 驗通」。

## 2. brainstorm 拍板（user 親決，2026-06-13）

| # | 分叉 | 拍板 |
|---|---|---|
| 1 | 完成定義 | **B 實機驗收**——在本機實際 `up --wait`、證據貼出，非僅配置就緒 |
| 2 | 服務範圍 | **A 5 service 全包**＋rust-api 最小 scaffold，一刀閉環 |
| 3 | 素材策略 | **A 裁剪帶入**——拷 rev2 outer compose/deploy、裁掉範圍外 service、token 改名（`rev2-`→`rev3-`、port 2X→3X、卷 prefix）；`grep rev2` 歸零驗收。DESIGN 波 -1「自 rev2 outer repo 帶入後依附錄 A 改名」既定策略的執行；outer 檔不屬 RUSTAPI-SOURCE-ISOLATION 禁區 |
| 4 | dev/prod 邊界 | **A 全帶**——base＋dev.yml＋prod.yml＋dev-certs＋generate scripts；acme 留 prod profile 殼。驗收分級：dev 硬出口／prod baseline 起停 sanity／acme 不驗 |
| 5 | migrate gate | **空 migrator＋gate 全接**——migration crate 空跑成功退出，`postgres→migrate→rust-api` 閘鏈本刀實機驗證；`mNNN_<name>` 慣例（⚠️k）在 crate 結構立好 |

**衍生拍板（⚠️t，登 DECISIONS §1）**：schema 交付模型——rev2 12 表終態 squash 為兩支忠實基線 migration（`m001_rev2_schema` / `m002_rev2_seeds`）＋rev3 delta 顯式分離（m003+：④ FK、⚠️p/⚠️c seed 擴充），於波 0 **002 刀**一次全建；後刀 migration 工序改「驗表已在＋補刀特有 seed」。屬 §8 交付序調整（§8.6：不構成設計變更）；§3.4「同刀建表」字面讓位於其防 retrofit 精神（一次全建更強滿足）。

## 3. 交付物（三組）

**(1) compose ×4（workspace root）**
- `docker-compose.yml`（master base）：front-nginx／base-web／rust-api／postgres／redis-stack＋`migrate` one-shot；**裁掉** obs 五件套/exporters/pushgateway（波 4）、cleanup-job（波 3）；acme 留 prod profile 殼
- `docker-compose.dev.yml`／`docker-compose.prod.yml`（override：host port、bind-mount、cert、build target）
- `docker-compose.rust-api.yml`（standalone niche aid、與 master 並存；base-web standalone 已在、僅對齊）

**(2) deploy/ 裁剪子集**
- `Dockerfile.rust-api.txt`（multi-stage builder→runtime）＋`entrypoint.rust-api.sh`
- `nginx/`（`nginx.conf`＋`conf.d/{dev,prod,_locations.inc}`）
- `generate-dev-cert.sh`＋`dev-certs/`、`generate-secrets.sh`＋`secrets/*.example`＋README（真實 `.txt` 本機生成、gitignore）
- 不帶：grafana-provisioning／loki／alloy／prometheus（波 4）、cleanup secrets（波 3）

**(3) rust-api 最小 scaffold（worktree、從零重寫、兩段式 commit 啟動）**
```
rust-api/
├── Cargo.toml            # workspace = ["server", "migration"]
├── server/               # axum：GET /health → "ok"（plain text、§I.3 universal 例外）
└── migration/            # sea-orm 空 migrator（vec![]）；README 立 mNNN_<name> 慣例
```

## 4. 結構與接線（carry rev2 踩坑紀律）

- **base 層禁 host ports**（R1：dev/prod 疊加 list append 衝突）、禁 dev/prod 專屬 volume——全在 override 層
- **base-web service 不放 image/build/command**（H1：dev=node vite／prod=nginx build 異質）；rust-api 放 build＋target（override 覆寫 target）
- 卷無顯式 `name:`、靠 `name: rev3-admin` auto-prefix（§8.2.2 正典 7 卷）
- **gate 鏈**：`postgres(healthy)＋redis(healthy) → migrate(completed) → rust-api(healthy) → front-nginx(healthy)`（base-web 平行）
- nginx（§7.4 凍結形）：`location /api/` 尾斜線 strip → rust-api:31081；`= /api/metrics` 擋塊 404；`/` → base-web:31079；`= /health` 自答；dev 31080+31443(自簽)／prod 80→443
- healthcheck 容器內用 `127.0.0.1`（alpine localhost→IPv6 坑，rev2 教訓）
- secrets ×6 file-based 掛 `/run/secrets/`；jwt 兩支本刀「接而不讀」（Auth 刀消費）；redis tag **pin 數字版**（⚠️d，寫 compose 時查當下 stable）
- server 本刀不連 DB；migrate 連（`APP_DATABASE_URL_FILE`）

## 5. 驗收（實機、分級）

**硬出口（dev）**：
1. `up -d --wait`（dev 組合）退出 0：5 service healthy＋migrate completed
2. gate 鏈時序證據（migrate 先於 rust-api，compose ps/logs）
3. curl 組：`:31080/health`／`:31443/health`(自簽)／`:31081/health`／`:31079`／`pg_isready :35432`／`redis ping :36379`
4. proxy 鏈：`:31080/api/health` → strip → `ok`；`/api/metrics` → 404
5. `docker compose config` dev/prod 兩組合法；`grep rev2` 歸零（倉永久名豁免）

**軟驗（prod baseline）**：cert seed → `up --wait` 起停 sanity → down。**不驗**：acme、base-web↔mock 業務流量。

**測試策略**：純 wiring/infra、無可測純函式——**無單元測試**、C-V acceptance 全覆蓋（依 CLAUDE.md §3 紀律於 plan/tasks 明示）。

## 6. 風險

- 裁剪殘留 → `config` 全組合＋grep 雙保險
- port 撞：standalone base-web（31079）與 master 同 port——驗收前先 down standalone
- rust-api 冷 build 數分鐘屬預期（cargo cache 卷 carry）
- 兩段式 commit：scaffold 為 rust-api worktree 首批 code，push 前依 §4.1 徵 user 同意

## 7. 002 刀預告（002-rev2-schema-baseline，本刀不做）

- `m001_rev2_schema.rs`（rev2 12 表終態忠實濃縮、零 FK 原樣）＋`m002_rev2_seeds.rs`（17 條 seed 淨效果；argon2id runtime hash、subquery 解 id）
- rev3 delta 顯式分離：m003+（④ `sys_user_role` FK、⚠️p demo menu seed＋⚠️c 三頁、…）
- **驗證閉環**：雙乾淨 postgres——rev2 35 條 vs rev3 m001+m002——`pg_dump` 互 diff 應零差異（argon2id 除外）
- 開放點（002 自己的 brainstorm 處理）：`casbin_rule` 建表方式——rev2 m005 委派 sea-orm-adapter schema vs 直接 CREATE 終態（含 m031 治理欄）；牽動 sub-crate 刀時序

## 8. 交棒

下一步＝user 手動執行 `/speckit-specify`（input＝本檔）；實作期一律 `superpowers:executing-plans`、push/merge 凍結至 finishing（CLAUDE.md §3 鐵紀律）。
