# C-V Contract: verification-commands（004-soft-delete-infra）

> 驗收＝容器 `cargo build`＋純 `cargo test`（守恆 lint＋regression＋meta＋query-shape，**零 DB**）＋**prod target image build（新 entity crate、mandatory）**＋bounded 实机 smoke（`#[ignore]`、postgres+migrate）＋殘留 grep。
> host 無 cargo → 一律 rust:1.86 容器（001/002/003 同形）；warm cargo cache 重用、target 卷 cv004-target。

容器形（純測共用）：
```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv004-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'
```

## C-V-1 · 建置驗（新 entity crate＋server 加 sea-orm/entity 後）

```bash
eval $RUN cargo build --bins --offline
# 期：entity crate 編譯、server 連結 sea-orm/entity、facade/trait/lint 編譯綠
grep -c 'name = "sea-orm"' rust-api/Cargo.lock     # 期 ≥1（已在 lock）
grep -E '^members' rust-api/Cargo.toml             # 期含 "entity"
# fail → entity crate 漏 member／server 漏 dep／facade import 錯（回查 R3/R4）
```

## C-V-2 · 純單元測試（test-first；零 DB、不含 #[ignore]）

```bash
eval $RUN cargo test -p server --offline
# 期全綠，涵蓋（contracts/entity-access-contract.md）：
#  §1 SoftDeletable find_active query-shape：sys_user/sys_role 的 SQL 含 "deleted_at" IS NULL（render 不執行）
#  §3 entity_access_lint：facade 外 entity:: 擋下；facade 內 pass；false-positive 0 誤報；meta-test 植入違規偵出
# 註：#[ignore] live smoke 不在此跑（DB-free）
# fail → query-shape 紅＝對 R2 校 find_active 形；lint 紅＝對 contract §3 校掃描/豁免
```

## C-V-3 · prod target image build（**新 workspace crate、mandatory**）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期：builder COPY entity crate（Manifest＋Source 段補齊）後 cargo build --release --bins 綠
# ★ 新 entity crate ⇒ Dockerfile.rust-api.txt 必補：
#   COPY rust-api/entity/Cargo.toml ./entity/   （Manifest 段）
#   COPY rust-api/entity/src ./entity/src        （Source 段）
# fail → builder 缺 entity COPY 行（dev bind-mount 遮住、僅 prod build 暴露——R5 紀律、Dockerfile :10-15）
```

## C-V-4 · bounded 实机 smoke（`#[ignore]`、postgres+migrate、m002 seed）

```bash
# 起 postgres + migrate one-shot（套 m001-m004、含 m002 seed Super/Admin/User + sys_user_role + sys_role）
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait postgres migrate
# 在 compose network 內跑 #[ignore] live tests（DATABASE_URL 指 postgres service；creds 取 deploy/secrets）
#   DATABASE_URL=postgres://<user>:<pw>@postgres:5432/<db>
docker run --rm --network rev3-admin_default \
  -v "$PWD/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv004-target:/app/target \
  -e RUSTUP_TOOLCHAIN=1.86.0 -e DATABASE_URL="postgres://<user>:<pw>@postgres:5432/<db>" \
  rust:1.86-slim-bookworm cargo test -p server -- --ignored --test-threads=1
# 期（contracts/entity-access-contract.md §4）：
#  find_active_by_name("Super") 命中／stamp deleted_at 後 find_active_by_id 排除（過濾真生效）
#  find_role_ids_by_user_id(Super) 非空／find_active_by_ids([R_SUPER]) 得 code=="R_SUPER"
# 隔離：stamp 後 teardown 還原 seed（或拋棄式列）
# 註：<user>/<pw>/<db>/network 名由 deploy/secrets + COMPOSE_PROJECT_NAME=rev3-admin 解析（plan/tasks 落值）
```

## C-V-5 · 殘留 grep（部署層零豁免；rust-api 新寫內容錨定）

```bash
# 部署層零 rev2/舊 port（不變）：
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
# rust-api 新寫源碼（entity/facade/soft_delete/lint 全新寫、無 rev2 token；以「前代」描述參照）：
grep -rinE "rev2|21079|21080|21081|21443" rust-api/entity/src/ rust-api/server/src/model/ rust-api/server/tests/entity_access_lint.rs 2>/dev/null && echo "❌" || echo "✅"
# 期：✅ ✅

# 清理（拋棄式 target 卷）：
docker volume rm cv004-target 2>/dev/null
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null
```

## 驗收不變式總表（C-V 斷言來源）

- C-V-1：entity crate 入 members、sea-orm/entity dep 加、build 綠。
- C-V-2：find_active query-shape 含 `"deleted_at" IS NULL`；lint 擋 facade 外 entity::／0 誤報／meta-test 偵出。
- C-V-3：**prod image build 綠（entity crate COPY 補齊、multi-stage 不退化）**。
- C-V-4：实机 soft-delete 過濾排除 stamped 列；getUserInfo 三表讀鏈對 m002 seed 命中。
- C-V-5：部署層＋entity/facade/lint 內容零 rev2 token。
