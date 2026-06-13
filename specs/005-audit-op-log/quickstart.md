# Quickstart: 005-audit-op-log 驗證指南

> 從零到「redact＋SQL-build 純測綠＋实机 smoke（commit/no-op/rollback 原子）綠」；完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)（C-V-1~6）、契約見 [contracts/audit-contract.md](contracts/audit-contract.md)。

## 前置需求

- rust-api worktree 可建（host 無 cargo → rust:1.86 容器、001-004 同形；warm cargo cache 重用、target 卷 cv005-target）。
- 擴 entity crate（+`sys_operation_log` Model、sea-orm +`with-json`；serde_json 已在 lock〔003〕、無新下載）＋server `model/audit.rs`。
- 实机 smoke 需 postgres+migrate（m001 含 sys_operation_log 表＋sys_user seed）；純測階段**無 DB**。
- **非新 crate**（擴 entity crate）⇒ 無 Dockerfile 改動、無 mandatory prod build（異於 004）。

## 驗證主線（依序）

```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv005-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'

# 1. 建置（entity +with-json／server +audit 後）                      ……C-V-1
eval $RUN cargo build --bins --offline
grep -n 'with-json' rust-api/entity/Cargo.toml                       # 期含

# 2. 純單元測試（test-first：audit_json redact ＋ audit_active_model SQL-build；零 DB） ……C-V-2
eval $RUN cargo test -p server --offline

# 3. bounded 实机 smoke（postgres+migrate、#[ignore]、拋棄式 user）    ……C-V-4
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait postgres migrate
NET=$(docker network ls --format '{{.Name}}' | grep rev3 | head -1)  # rev3-admin_rev3_net
DB_URL=$(cat deploy/secrets/database_url.txt)
docker run --rm --network "$NET" -v "$PWD/rust-api":/app -w /app \
  -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv005-target:/app/target \
  -e RUSTUP_TOOLCHAIN=1.86.0 -e DATABASE_URL="$DB_URL" \
  rust:1.86-slim-bookworm cargo test -p server -- --ignored --test-threads=1

# 4. 殘留 grep（部署層＋audit/op-log facade/entity 零 rev2 token）      ……C-V-5
grep -rinE "rev2" rust-api/server/src/model/audit.rs rust-api/server/src/model/facade/sys_operation_log.rs rust-api/entity/src/sys_operation_log.rs && echo "❌" || echo "✅"
```

期望：`cargo build` 綠（entity +with-json）＋純 `cargo test` 全綠（`audit_json` redact password＝`"<redacted>"`／`audit_active_model` SQL-build INSERT op-log＋operator_ip NotSet 略過／既有 004 lint③ 22 test 仍綠）＋实机 smoke 綠（commit 寫恰好 1 筆 redacted／no-op 不寫／審計 INSERT 失敗整 txn 回滾）＋grep ✅。

## test-first TDD 紀律

純函式（`audit_json` redact＋`audit_active_model` SQL-build）**先寫測（red）再實作（green）**——red 對 R2 rev2 參照形（research R2.2/R2.3）校形、**不調測試遷就實作**。txn 原子（尤其 **rollback**：審計 INSERT 失敗→業務 UPDATE 也回滾）由 §4 bounded 实机 smoke 證（compile/render 證不了的唯一核心點）。

## ⚠️ operator_ip INET / PG 42804 注意

`audit_active_model` 內 `operator_ip` **None→`NotSet`**（略過欄、DB 填 NULL）；`Set(None)` 會送 `NULL::text`、INET 無法隱式轉型（PG error 42804）。本刀 operator 永遠 `ip:None`、不觸 `Some(ip)` text-binding 路徑（真實 INET 值寫入 defer 第二 audit 刀）。

## 收尾

```bash
docker volume rm cv005-target 2>/dev/null                                       # 拋棄式 target 卷
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null # 停 smoke 用 stack
```
