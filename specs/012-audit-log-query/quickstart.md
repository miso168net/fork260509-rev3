# Quickstart: 012-audit-log-query 驗收指南

> 唯讀審計查詢＋審計中心。驗收全集＝[contracts/verification-commands.md](contracts/verification-commands.md)（C-V-0~9）；跨 feature 不變式＝[contracts/audit-log-query-contract.md](contracts/audit-log-query-contract.md)；元件/型＝[data-model.md](data-model.md)。本檔＝可跑的端到端驗證流程，不含實作碼。

## 前置
- dev stack healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（rust-api/base-web/postgres/front-nginx）。
- **m005 已套用**（migrate gate 自動或 `cargo run -p migration -- up`）：psql 驗 `manage_audit` sys_menu 1 列＋3 audit GET casbin policy（R_SUPER）＋manage_audit menu policy（v2='menu'）＋operation/access filter 索引 4 條。
- 帳號：`Super`/`Admin`/`User`、`123456`。現有資料（讀端對象）：sys_operation_log 41／sys_access_log 723／sys_login_attempt 213 列級。

## 驗證流程（對應 C-V、rust 容器內、改 .rs 先 force-touch、live `--test-threads=1`+DATABASE_URL）

1. **build**（C-V-0）：`cargo build -p server -p migration --locked` 綠（含 m005、無新 crate）。
2. **lint**（C-V-2）：`endpoint_coverage_lint`（`[&str;34]`、3 audit 端點 policy-governed⊆m005 seed、registered==as-built）＋`entity_access_lint`（handler/main 零 path-root entity::）皆綠。
3. **純測**（C-V-1、若抽純函式）：filter/normalize/IP-expr builder/operator-name 解析 純測「N passed」。
4. **live 讀端**（C-V-3、**唯讀無污染**）：3 端點分頁＋filter——空字串守門回全部、operation/success/method 精確、created_at 範圍、**文字模糊**（path/帳號/region/entity_table）、**★ IP 模糊**（operator_ip/client_ip `host()::text LIKE` 部分比對命中＝本刀首要驗）、**operator by 名**（含已刪）、operator enrich（名/系統空/已刪仍顯示名）。
5. **policy-gate**（C-V-4）：Admin/User 對 3 讀端→403（envelope 5003）不洩資料；Super→200 PageRes。
6. **★ m005 可逆**（C-V-5）：`migrate down -n 1`→ manage_audit menu/4 policy/4 索引消失、既有日誌表不動；`migrate up`→ 重建。
7. **typecheck**（C-V-6）：base-web `pnpm typecheck` 綠（3 honest `XxxLogItem`、nullable→`｜null`、無 type-lie）；commit `--no-verify`。
8. **CDP**（C-V-7、經 :31080/api）：Super→/manage/audit→3 tab 各真發 request＋分頁＋filter（含部分 IP/帳號模糊、日期範圍、operator by 名）＋op-log payload 行展開＋operator 名顯示＋**hasAuth super-only**（非 super 不見審計中心 menu）。**唯讀無 cleanup**。
9. **零回歸**（C-V-8）：`/health` ok；diff 既有日誌表 entity／enforce_mw／require_policy／From<DbErr>／008-011 未改；migration 僅 seed+index 無業務表；base-web frozen（route store/transform/system-manage.ts/auth.ts/request）未改。
10. **prod build**（C-V-9）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 綠（m005 編入 migrate stage、無新 crate）。

## 出口
C-V-0~9 全綠＝acceptance 通過（spec SC-001~009）。**唯讀無污染、無新 crate、m005 delta 無新業務表且 up→down→up 可逆。★ IP 模糊 `host()::text LIKE` 無 codebase 先例、impl/驗收首要點。**
