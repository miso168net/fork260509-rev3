# C-V Contract: verification-commands（003-envelope）

> envelope 是純型別／序列化刀——驗收＝容器 `cargo build`＋`cargo test`（序列化 golden＋13 碼 matrix＋AppError 映射＋⚠️e/⚠️f 結構斷言）＋prod build sanity＋殘留 grep。**無 DB／stack 容器需求**（與 002 相反）。
> host 無 cargo → 一律 rust:1.86 容器（001/002 同形）；卷 cv003-cargo／cv003-target。

容器形（共用）：
```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v cv003-cargo:/usr/local/cargo -v cv003-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'
```

## C-V-1 · 建置驗（deps＋axum json feature 後）

```bash
eval $RUN cargo build --bins
# 期：serde/serde_json/thiserror 入鎖、axum json feature 啟用、build 綠
grep -c 'name = "serde"' rust-api/Cargo.lock        # 期 ≥1
grep -c 'name = "serde_json"' rust-api/Cargo.lock   # 期 ≥1
grep -c 'name = "thiserror"' rust-api/Cargo.lock    # 期 ≥1
# fail → axum 未啟 json feature（Json 編譯炸）／dep 未加（回查 R3）
```

## C-V-2 · 單元測試（test-first；序列化 golden＋矩陣＋結構斷言）

```bash
eval $RUN cargo test
# 期全綠，涵蓋（contracts/envelope-wire-contract.md）：
#  §1 序列化 golden 逐 byte（Res::ok/ok_msg/err/err_msg/泛型T/PageRes/分頁承載；無 success／data:null／空[]）
#  §2 13 碼 table-driven（code/msg/http_status 逐碼；Internal.http_status()==200；count(500)==0 ＝⚠️e）
#  §3 AppError 8 建構子 into_response() 的 (status, body) 對映；internal("boom") body 不含 "boom"（內部不洩漏）
#  §4 ⚠️f：可發出碼集合大小==8、皆≠保留碼（4 保留碼無建構子＝編譯期保證）
# fail → golden 紅＝對 rev2 grep/base-web typings 校形（不調 golden）；矩陣紅＝對凍結表校 code/msg/status
```

## C-V-3 · prod build sanity（非新 crate、但確認 server crate multi-stage 不退化）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
# 期：builder COPY server crate src 後 cargo build --release 綠（serde/json feature 加入不破壞 multi-stage）
# 註：envelope 非新 workspace crate → 無新 COPY 行需求（不同於 002 sea-orm-adapter）；Dockerfile 不需改
# fail → server crate prod build 炸＝feature/dep 在 release profile 缺（對照 C-V-1 dev build 落差）
```

## C-V-4 · /health 不退化（universal 例外）

```bash
# main.rs 加 mod 後 health handler 不變、仍 plain text：
grep -nE 'async fn health|"ok"' rust-api/server/src/main.rs    # 期：health 簽名與 "ok" 不變
# （C-V-7 dev stack 起動驗 /health 屬後續刀；本刀靜態確認 health 未被信封化）
```

## C-V-5 · 殘留 grep（部署層零豁免；rust-api 內容錨定豁免）

```bash
# 部署層零豁免（不變）：
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
# rust-api server 側（envelope 全新寫、無 rev2 字樣；13 碼 code/msg 簡中字串非 rev2 token）：
grep -rinE "rev2|21079|21080|21081|21443" rust-api/server/src/envelope.rs rust-api/server/src/error.rs 2>/dev/null && echo "❌" || echo "✅"
# 期：✅ ✅（envelope/error 內容註解用「前代」描述 rev2 參考、不留 rev2 token）

# 清理：
docker volume rm cv003-cargo cv003-target 2>/dev/null
```

## 驗收不變式總表（C-V 斷言來源）

- C-V-1：serde/serde_json/thiserror 入鎖、build 綠。
- C-V-2：序列化 golden 逐 byte 全綠；13 碼 matrix 全綠；Internal→200／無 500（⚠️e）；保留碼無建構子／可發出集==8（⚠️f）；internal 不洩漏。
- C-V-3：prod build 綠（server crate 不退化）。
- C-V-4：/health plain text 不變。
- C-V-5：部署層零 rev2／envelope-error 內容零 rev2 token。
