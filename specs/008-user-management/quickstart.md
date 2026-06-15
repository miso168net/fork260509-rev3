# Quickstart: User Management（008）驗收 run 指南

> Phase 1 output。證明 feature end-to-end 可行的可跑驗收場景。命令細節見 [contracts/verification-commands.md](./contracts/verification-commands.md)；型/欄位見 [data-model.md](./data-model.md)。**不含實作碼**（實作見 tasks.md）。

## Prerequisites

1. **dev stack 起**（rust-api ＋ postgres ＋ front-nginx ＋ base-web）：
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
   ```
   （冷卷首啟 base-web≈140s／rust-api≈240s 編譯期 healthcheck 會 flap、待穩後重跑 `up --wait`；見 CLAUDE.md §8.2.1。）
2. **PG 連線**：`PG_URL`＝`postgresql://<user>:<pw>@127.0.0.1:35432/<db>`（pw 見 `deploy/secrets/`）。
3. **CDP cutover（C-V-6 用）**：建 gitignored `base-web/.env.test.local`：
   ```
   VITE_SERVICE_BASE_URL=http://rust-api:31081
   ```
   （shadow 掉 apifox mock；`*.local` gitignored、不動 committed `.env.test`；BASE-WEB-ADAPT 紀律。）

## 驗收場景（對應 C-V）

| # | 場景 | 命令 | 預期 |
|---|---|---|---|
| 1 | build＋MSRV | C-V-1 `cargo build -p server --locked` | 綠、無新 crate |
| 2 | 純單測 | C-V-2 `cargo test -p server` | filter SQL 形／enum 映射／2^53 guard／種子謂詞／dup 判定全綠 |
| 3 | live smoke | C-V-3 `--ignored --test-threads=1 live_smoke_user_crud` | Insert/Update/SOFT_DELETE 列＋role-delta＋no-op 零 audit（Q2）＋dup 2222（Q3）＋種子 2222 |
| 4 | curl 全鏈（Super） | C-V-4 login→getUserList→addUser→psql 驗 audit roles→dup | list 回真資料；audit `payload_after->'roles'` 在；同名→`2222` |
| 5 | 權限 gate | C-V-5 login User→addUser | envelope `5003`（enforce_mw、只 R_SUPER 可寫） |
| 6 | CDP modal（cutover） | C-V-6 .env.test.local→rust-api、tests/000 CDP、限 /manage/user | 登入→/manage/user→開 modal 填表單（含角色下拉）→add/edit/delete 走真 rust-api→modal 關+列表刷新 |
| 7 | p95 server-side | C-V-7 curl -w ×20 | list p95 < 0.3s／write < 0.5s（排冷啟）；psql 驗 batch 避 N+1 |
| 8 | lint stand-up | C-V-8 `cargo test endpoint_coverage_lint` | 每 gated route 有 ≥1 policy（綠） |

## 關鍵驗收斷言（implementer 必達）

- **wire 零 type-lie**：getUserList/getAllRoles 回 `id` 為 JSON **number**（含 getAllRoles、不跟 mock string、⚠️r）；`userGender`/`status` 為 `"1"|"2"|null`；`userRoles` 為 roleCode 字串陣列。
- **audit composite**：addUser/updateUser 的 op-log `payload` 含 `roles` 前後；deleteUser 的 `payload_before` 15 欄**無 roles**（Q1）；password 恆 redact。
- **業務拒 = 2222**（dup user_name〔★ Q3 pre-check、非 5000〕／role 解不到／值域／soft-deleted 更新／種子刪）；enforce 拒 = **5003**；其餘 HTTP 200 信封。
- **種子保護**：deleteUser/batchDelete `id∈{1,2,3}`→2222；但**可改名/改 role/改 status**（只擋刪）。
- **MODAL-WIRING**：`index.vue`/`user-operate-drawer.vue` 三 stub 接上新 `rev3-system-manage.ts` wrapper（updateUser 併 id）；原行註解保留＋`rev3-inline` 標記；既有 `system-manage.ts` 不改。

## Done（feature acceptance）
C-V-1~8 全綠 ＋ 7 user-story acceptance scenarios（spec §User Scenarios）通過 ＋ 10 SC 達標 ＋ Constitution Check（plan §Constitution Check）維持 PASS。
