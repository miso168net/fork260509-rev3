# C-V Contract: verification-commands（004-soft-delete-infra）

> 實機驗收命令全集。rust 一律**容器內**跑（host 無 toolchain）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠（CLAUDE.md §8.2.1）。**rust 全程 serial**（共用 target、勿平行 cargo）。

## C-V-0 · entity＋server 建置綠

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find entity/src server/src -name "*.rs" -exec touch {} + && cargo build -p entity && cargo build -p server'
```
- 11 entity 模組編譯綠（with-chrono/with-json/with-ipnetwork feature 就位、型對映無 E0412）。
- server 含 `mod model`＋SoftDeletable trait＋3 impl 編譯綠（sea-orm＋entity dep 就位）。
- **新 workspace crate `entity`**：確認 `cargo metadata` 列出（`rust-api/Cargo.toml` members 含 entity）。

## C-V-1 · entity_access_lint 守恆綠＋自測擋違規

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test entity_access_lint'
```
- lint 通過（`server/src` 無 facade 外 `entity::` 使用）。
- **scan fn 自測**斷言（同檔 `#[test]`）：`entity::Foo`→flagged｜`sea_orm::entity::Bar`→not（前界檢查）｜`// entity::X`／`"entity::Y"`→not（抹白）｜`model/facade/` 路徑→exempt。**雙證**（綠＋擋得住）滿足 FR-006、非 vacuous。
> ⚠️ 整支 binary 用 `--test entity_access_lint`；看到「0 passed; N filtered out」＝filter 沒命中、非綠（CLAUDE.md §8.2.1）。

## C-V-2 · SoftDeletable find_active live smoke（txn-rollback）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && DATABASE_URL="$DATABASE_URL" cargo test -p server -- --ignored --test-threads=1 soft_delete'
```
（DATABASE_URL 由 dev 容器環境帶；live stack 須 `up -d --wait` 全 healthy、postgres 有 002 seed。）
- in-crate `#[ignore]`：開 txn → sys_user id=1 `UPDATE deleted_at=now()` → 斷言 `SysUser::find_active()` **不**含 id=1、`SysUser::find()` **含** id=1 → **rollback**（不動 002 seed）。
- `--test-threads=1` 防 live serial 偽失敗；txn-rollback 零殘留。
- 對應 SC-001（3 entity 暴露 active 查詢；sys_user 活體證、sys_role/sys_menu 由共用 trait＋compile 繼承）/ SC-002（刪除列排除）。

## C-V-3 · prod target image build sanity（新 workspace crate 紀律）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- **新 workspace crate `entity` ⇒ 必跑 prod build**（CLAUDE.md §3 Phase 1）。
- 驗 prod 多階段 Dockerfile 已補 entity 的 Manifest（`COPY rust-api/entity/Cargo.toml ./entity/`）＋Source（`COPY rust-api/entity/src ./entity/src`）COPY；無缺口（防 dev bind-mount 遮蓋、rev2 教訓）。對應 SC-006。

## 出口
C-V-0~3 全綠＝本刀 acceptance 通過；對應 spec SC-001~007（SC-005 範圍＝零端點/零 migration 由 diff 核；SC-007 既有 /health 不回歸＝stack 仍 healthy）。
