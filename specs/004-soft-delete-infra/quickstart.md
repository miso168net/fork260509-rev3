# Quickstart: 004-soft-delete-infra 驗證指南

> 從零驗證本刀（soft-delete 面地基＋L2 entity 層＋entity_access_lint 護欄）。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型模型＝[data-model.md](data-model.md)；不變式＝[contracts/soft-delete-lint-contract.md](contracts/soft-delete-lint-contract.md)。

## 前置
- dev stack 可起並全 healthy：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`（postgres 含 002 seed）。
- rust 一律容器內跑（host 無 toolchain）；改 `.rs` 先 force-touch（CLAUDE.md §8.2.1）；rust serial。

## 驗證流程（4 步）

1. **建置綠**（C-V-0）：容器內 `cargo build -p entity && cargo build -p server`（先 force-touch）→ 11 entity 模組（tstz/jsonb/INET feature 就位）＋server（`mod model`＋SoftDeletable＋3 impl）皆編譯綠；`entity` 為新 workspace member。

2. **lint 守恆綠＋自測**（C-V-1）：`cargo test -p server --test entity_access_lint` → lint 通過（facade 外無 `entity::`）＋scan fn 自測證明「抓得住違規（`entity::Foo`）／不誤殺（`sea_orm::entity::`、註解、字串、facade/ 豁免）」。

3. **find_active live smoke**（C-V-2）：stack healthy 後容器內 `cargo test -p server -- --ignored --test-threads=1 soft_delete` → txn 內 soft-delete sys_user id=1 → `find_active()` 排除、`find()` 含 → rollback（不動 seed）。

4. **prod build sanity**（C-V-3）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 成功（prod Dockerfile 已補 entity 的 Manifest＋Source COPY、無缺口）。

## 預期結果（對應 SC）

| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | SC-004/007 | 11 entity 反射 schema＋編譯綠、既有服務不回歸 |
| 2 | SC-003 | facade 唯一管道守恆綠＋可證有效 |
| 3 | SC-001/002 | active 查詢排除 soft-deleted 列（活體） |
| 4 | SC-006 | prod 映像打包含新 crate、零回歸 |

## 不在本刀（各歸其刀）
- 業務 facade 方法（soft_delete 寫/CRUD）→ 各業務刀；`AppState.db` runtime 接線 → 首個查 DB 端點刀。
- log entity 的 INET 讀寫 facade → audit 刀；casbin_rule facade → policy 刀；`mutate_in_txn` → audit 刀。
- 無 endpoint/wire/migration（SC-005 範圍邊界）。
