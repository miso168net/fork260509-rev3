# Quickstart: 003-envelope 驗證指南

> 從零到「序列化 golden＋13 碼矩陣＋AppError 映射＋⚠️e/⚠️f 結構斷言全綠」；完整命令見 [contracts/verification-commands.md](contracts/verification-commands.md)（C-V-1~5）、wire 契約見 [contracts/envelope-wire-contract.md](contracts/envelope-wire-contract.md)。

## 前置需求

- rust-api worktree 可建（host 無 cargo → rust:1.86 容器、001/002 同形；卷 cv003-cargo／cv003-target）。
- 依賴增量：workspace ＋ server crate 加 `serde`(derive)／`serde_json`／`thiserror`；axum 改 `features=["json"]`。
- **無 DB／stack 容器需求**（envelope 純型別／序列化）。

## 驗證主線（依序）

```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v cv003-cargo:/usr/local/cargo -v cv003-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'

# 1. 建置（deps＋axum json feature 後）                          ……C-V-1
eval $RUN cargo build --bins
grep -c 'name = "serde"' rust-api/Cargo.lock   # 期 ≥1

# 2. 單元測試（test-first：golden＋matrix＋AppError＋⚠️e/⚠️f）      ……C-V-2
eval $RUN cargo test

# 3. prod build sanity（server crate multi-stage 不退化）          ……C-V-3
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api

# 4. /health 不退化（universal 例外、靜態確認）                    ……C-V-4
grep -nE 'async fn health|"ok"' rust-api/server/src/main.rs

# 5. 殘留 grep（部署層零 rev2／envelope-error 零 rev2 token）       ……C-V-5
grep -rinE "rev2" rust-api/server/src/envelope.rs rust-api/server/src/error.rs && echo "❌" || echo "✅"
```

期望：`cargo build` 綠＋`cargo test` 全綠（序列化 golden 逐 byte／13 碼 table-driven／AppError 8 建構子映射／Internal→200 無 500〔⚠️e〕／保留碼無建構子〔⚠️f〕／internal 不洩漏）＋prod build 綠＋/health 不變＋grep ✅。

## test-first TDD 紀律

envelope 全是可獨立測純函式／序列化——**先寫測試（red）再實作（green）**：①序列化 golden（對 contracts/envelope-wire-contract.md §1）②13 碼 matrix（§2）③AppError 映射（§3）④⚠️f 結構（§4）。red 時對 rev2 grep 座標（research.md R1）／base-web typings（R2）校形，**不調測試遷就實作**。

## 收尾

```bash
docker volume rm cv003-cargo cv003-target 2>/dev/null   # 拋棄式卷清理
```
