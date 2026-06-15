# Quickstart: Role Management（009）驗收 run 指南

> Phase 1 output。證明 feature end-to-end 可行的可跑驗收場景。命令細節見 [contracts/verification-commands.md](./contracts/verification-commands.md)；型/欄位見 [data-model.md](./data-model.md)。**不含實作碼**（實作見 tasks.md）。

## Prerequisites

1. **dev stack 起**（rust-api ＋ postgres ＋ front-nginx ＋ base-web）：
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
   ```
   （冷卷首啟 base-web≈140s／rust-api≈240s 編譯期 healthcheck 會 flap、待穩後重跑 `up --wait`；見 CLAUDE.md §8.2.1。）
2. **PG 連線**：`PG_URL`＝`postgresql://<user>:<pw>@127.0.0.1:35432/<db>`（pw 見 `deploy/secrets/`）。
3. **CDP cutover（C-V-6 用、008 已建可複用）**：gitignored `base-web/.env.test.local`：
   ```
   VITE_SERVICE_BASE_URL=http://rust-api:31081
   ```
   （shadow apifox mock；`*.local` gitignored、不動 committed `.env.test`；BASE-WEB-ADAPT。**改後重啟 base-web 容器**。）

## 驗收場景（對應 C-V）

| # | 場景 | 命令 | 預期 |
|---|---|---|---|
| 1 | build＋MSRV | C-V-1 `cargo build -p server --locked` | 綠、無新 crate |
| 2 | 純單測 | C-V-2 `cargo test -p server` | filter SQL 形／enum 映射／2^53 guard／種子謂詞／dup 判定／lint scan_tests 全綠 |
| 3 | live smoke | C-V-3 `--ignored --test-threads=1 live_smoke_role` | Insert/Update/SOFT_DELETE 列＋leaf payload（無 roles）＋no-op 零 audit＋dup 2222＋23505 race 2222＋種子 2222＋模糊 filter |
| 4 | curl 全鏈（Super） | C-V-4 login→getRoleList→addRole→psql 驗 audit→dup→updateRole（code 不變）→delete | list 回真資料；op-log Insert leaf；同碼→`2222`；roleCode 不可變；種子刪→`2222` |
| 5 | 讀寫分權 gate | C-V-5 Admin 讀 ok/寫 5003、User 讀 5003 | R_ADMIN getRoleList→`0000`、addRole→`5003`；R_USER_COMMON getRoleList→`5003` |
| 6 | CDP modal（cutover） | C-V-6 .env.test.local→rust-api、tests/000 CDP、限 /manage/role | 登入→/manage/role→列表載真 3 角色（空字串 filter 守門）→drawer add/edit（roleCode disabled）/delete 走真 rust-api→drawer 關+列表刷新 |
| 7 | p95 server-side | C-V-7 curl -w ×20 | list p95 < 0.3s／write < 0.5s（排冷啟） |
| 8 | lint bump | C-V-8 `cargo test endpoint_coverage_lint` | EXPECTED=11、每 gated route 有 ≥1 policy（綠） |

## 關鍵驗收斷言（implementer 必達）

- **wire 零 type-lie**：getRoleList 回 `id` 為 JSON **number**（⚠️r、2^53 guard）；`status` 為 `"1"|"2"|null`；`roleName/roleCode/roleDesc` camelCase。
- **leaf audit**：addRole/updateRole/deleteRole 的 op-log `payload` **只含 role 自身 12 欄、無 roles key、無 password**（vs 008 composite/redact）；updateRole before/after 顯示 name/desc/status 變、**roleCode 不變**。
- **業務拒 = 2222**（dup roleCode〔★ pre-check + 23505 race catch、皆 2222 非 5000〕／值域／soft-deleted 更新／種子刪／batch 含種子／惡形 ids）；enforce 拒 = **5003**；其餘 HTTP 200 信封。
- **種子保護**：deleteRole/batchDelete `id∈{1,2,3}`→2222；但**可改 name/desc/status**（只擋刪、FR-012）。
- **roleCode 不可變**（FR-006）：後端 update 不寫 code 欄；前端 drawer edit 時 roleCode `:disabled`。
- **inert on removal**（SC-006）：軟刪 role 自動不計入 user 有效角色（既有 `roles_for_user`→`find_active_by_ids` active 濾、本刀不改）；**停用（status=2）≠ 撤權**（active filter 僅濾 deleted_at、R6）。
- **MODAL-WIRING (a)**：`role/index.vue`（delete/batchDelete）+`role-operate-drawer.vue`（handleSubmit add/update、roleCode disabled）接上新 `rev3-system-manage.ts` wrapper（update 併 id）；原行註解保留＋`rev3-inline` 標記；既有 `system-manage.ts`/`auth.ts`/`route.ts` 不改。**(c) auth-modal 屬 OUT**（需 sys_menu）。

## Done（feature acceptance）
C-V-0~8 全綠 ＋ 6 user-story acceptance scenarios（spec §User Scenarios）通過 ＋ 10 SC 達標 ＋ Constitution Check（plan §Constitution Check）維持 PASS。
