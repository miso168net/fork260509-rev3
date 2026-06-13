# Quickstart: 004-soft-delete-infra 驗證指南

> 從零到「守恆 lint＋query-shape＋meta 純測綠＋prod image build 綠＋bounded 实机 smoke 綠」；完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)（C-V-1~5）、契約見 [contracts/entity-access-contract.md](contracts/entity-access-contract.md)。

## 前置需求

- rust-api worktree 可建（host 無 cargo → rust:1.86 容器、001/002/003 同形；warm cargo cache 重用、target 卷 cv004-target）。
- 新 `entity` crate＋server 加 `sea-orm`(workspace)＋`entity`(path)（sea-orm 已在 lock〔002〕、無新下載）。
- 实机 smoke 需 postgres+migrate（m002 seed）；純測階段**無 DB**。

## 驗證主線（依序）

```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv004-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'

# 1. 建置（entity crate＋server sea-orm/entity 後）                 ……C-V-1
eval $RUN cargo build --bins --offline
grep -E '^members' rust-api/Cargo.toml          # 期含 "entity"

# 2. 純單元測試（test-first：lint+regression+meta+query-shape；零 DB）  ……C-V-2
eval $RUN cargo test -p server --offline

# 3. prod image build（新 entity crate、multi-stage 不退化、mandatory）  ……C-V-3
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api

# 4. bounded 实机 smoke（postgres+migrate、#[ignore]）               ……C-V-4
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait postgres migrate
#   （在 compose network 內帶 DATABASE_URL 跑 cargo test -- --ignored，見 C-V-4）

# 5. 殘留 grep（部署層＋entity/facade/lint 零 rev2 token）            ……C-V-5
grep -rinE "rev2" rust-api/entity/src/ rust-api/server/src/model/ && echo "❌" || echo "✅"
```

期望：`cargo build` 綠＋純 `cargo test` 全綠（守恆 lint 擋 facade 外 `entity::`／0 誤報／meta-test 偵出植入違規；`find_active` query-shape 含 `"deleted_at" IS NULL`）＋prod image build 綠（entity COPY 補齊）＋实机 smoke 綠（soft-delete 過濾排除 stamped 列、getUserInfo 三表讀鏈命中 m002 seed）＋grep ✅。

## test-first TDD 紀律

純函式（守恆 lint＋`find_active` query-shape）**先寫測（red）再實作（green）**——red 對 R2 rev2 參照形（`docs/superpowers/004-soft-delete-infra.md`／research R2）校形、**不調測試遷就實作**。facade DB 行為（過濾真生效）由 §4 bounded 实机 smoke 證（compile/render 證不了的唯一核心點）。

## 收尾

```bash
docker volume rm cv004-target 2>/dev/null                                       # 拋棄式 target 卷
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null # 停 smoke 用 stack
```
