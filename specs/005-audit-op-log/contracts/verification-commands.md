# C-V Contract: verification-commands（005-audit-op-log）

> 驗收＝容器 `cargo build`（entity +with-json）＋純 `cargo test`（redact＋SQL-build，**零 DB**）＋bounded 实机 smoke（`#[ignore]`、postgres+migrate、拋棄式 user）＋殘留 grep＋/health 不退化。
> **非新 crate**（擴 entity crate）⇒ **無 mandatory prod image build**（異於 004）；C-V-1 build 即驗 with-json 編譯。
> host 無 cargo → 一律 rust:1.86 容器（001/002/003/004 同形）；warm cargo cache 重用、target 卷 cv005-target。

容器形（純測共用）：
```bash
RUN='docker run --rm -v "'"$PWD"'/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv005-target:/app/target -e RUSTUP_TOOLCHAIN=1.86.0 rust:1.86-slim-bookworm'
```

## C-V-1 · 建置驗（entity +with-json／server +audit 後）

```bash
eval $RUN cargo build --bins --offline
# 期：entity crate +with-json 編譯（sys_operation_log JSONB Model 解析）、server model/audit.rs＋facade 編譯綠
grep -n 'with-json' rust-api/entity/Cargo.toml                 # 期含 with-json
grep -c 'name = "serde_json"' rust-api/Cargo.lock              # 期 ≥1（已在 lock、無新下載）
# fail → with-json 漏／Model JSONB 欄型錯（回查 R1/R3/R4）；若 --offline 失敗（不該、serde_json 已 lock）移除 --offline 並註明
```

## C-V-2 · 純單元測試（test-first；零 DB、不含 #[ignore]）

```bash
eval $RUN cargo test -p server --offline
# 期全綠，涵蓋（contracts/audit-contract.md §3）：
#  ① audit_json redact：sys_user Model audit_json password=="<redacted>"、其餘欄保留
#  ② audit_active_model SQL-build：INSERT INTO "sys_operation_log"＋核心欄；operator:None 時 operator_ip 欄略過（NotSet、避 42804）
#  ＋既有 004 lint 22 test／query-shape 仍綠（facade 新增不破壞 lint③；no_raw_entity_outside_facade 綠）
# 註：#[ignore] live smoke 不在此跑（DB-free）
# fail → redact 紅＝對 R2.3 校 audit_json 欄；SQL-build 紅＝對 R2.2 校 audit_active_model（operator_ip NotSet）
```

## C-V-3 · with-json 編譯確認（非新 crate、無 mandatory prod build）

```bash
# 擴 entity crate（非新 workspace member）⇒ 不觸 CLAUDE.md §3「新 crate ⇒ prod build」紀律、無 Dockerfile COPY 改動。
# C-V-1 的 cargo build 已驗 with-json 編譯；此處僅複述：不需 prod target image build。
# （若日後對 prod 保險：docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api 應仍綠、但非 acceptance 門。）
echo "非新 crate、C-V-1 build 綠即涵蓋 with-json acceptance"
```

## C-V-4 · bounded 实机 smoke（`#[ignore]`、postgres+migrate、拋棄式 user）

```bash
# 起 postgres + migrate one-shot（套 m001-m004；sys_operation_log 表 + sys_user seed 在）
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait postgres migrate
# 解析實際 compose 網路名（★ rev3-admin_rev3_net，非 stale 的 _default——top-level networks: rev3_net ＋ project prefix）
NET=$(docker network ls --format '{{.Name}}' | grep rev3 | head -1)   # 期 rev3-admin_rev3_net
DB_URL=$(cat deploy/secrets/database_url.txt)                         # postgres://soybean:<pw>@postgres:5432/soybean_admin_rust
docker run --rm --network "$NET" \
  -v "$PWD/rust-api":/app -w /app -v rev3-admin_rust_api_cargo_cache:/usr/local/cargo -v cv005-target:/app/target \
  -e RUSTUP_TOOLCHAIN=1.86.0 -e DATABASE_URL="$DB_URL" \
  rust:1.86-slim-bookworm cargo test -p server -- --ignored --test-threads=1
# 期（contracts/audit-contract.md §4）：
#  ① commit 原子：soft_delete(900001) → 恰好 1 筆 redacted 審計（password=<redacted>）＋user 軟刪
#  ② no-op：不存在/已刪 → Ok(false)、不寫審計
#  ③ rollback 原子：審計 INSERT 失敗（entity_table 超長）→ Err、user UPDATE 回滾（deleted_at None）、審計 0 列
#  拋棄式 user（id 9xxxxx）＋hard_clean 隔離、不碰 m002 seed
# fail → rollback 紅＝對 contract §4 校 mutate_in_txn txn 邊界
```

## C-V-5 · 殘留 grep（部署層零豁免；rust-api 新寫內容錨定）

```bash
# 部署層零 rev2/舊 port（不變）：
grep -rinE "rev2|21079|21080|21081|21443|25432|26379" docker-compose*.yml deploy/ && echo "❌" || echo "✅"
# rust-api 新寫源碼（audit.rs/op-log facade/sys_user 寫側/entity 全新寫、無 rev2 token；以「前代」描述參照）：
grep -rinE "rev2|21079|21080|21081|21443" rust-api/server/src/model/audit.rs rust-api/server/src/model/facade/sys_operation_log.rs rust-api/entity/src/sys_operation_log.rs 2>/dev/null && echo "❌" || echo "✅"
# sys_user.rs 本刀新增段（soft_delete/AuditSerialize）零 rev2（既有 004 段不在此查範圍、本刀只查不引入新 rev2）：
grep -nE "rev2" rust-api/server/src/model/facade/sys_user.rs && echo "（檢視：應僅既有/無新增 rev2 token）" || echo "✅ sys_user 零 rev2"
# 期：✅ ✅ ✅

# 清理（拋棄式 target 卷）：
docker volume rm cv005-target 2>/dev/null
docker compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null
```

## C-V-6 · /health 不退化（universal 例外、靜態確認）

```bash
# 本刀僅加 mod audit、不碰 /health：
grep -nE 'async fn health|"ok"' rust-api/server/src/main.rs    # 期：health 簽名與 "ok" 不變
# （SC-006 子準則、對齊 003/004 C-V；by construction 已保障、此為 belt-and-suspenders）
```

## 驗收不變式總表（C-V 斷言來源）

- C-V-1：entity +with-json 編譯、server +audit build 綠。
- C-V-2：audit_json redact password＝`"<redacted>"`；audit_active_model SQL-build INSERT op-log＋operator_ip NotSet 略過；既有 lint③/query-shape 仍綠。
- C-V-3：非新 crate、無 mandatory prod build（C-V-1 涵蓋 with-json）。
- C-V-4：实机 commit 寫恰好 1 筆 redacted／no-op 不寫／審計 INSERT 失敗整 txn 回滾（業務寫＋審計寫原子）。
- C-V-5：部署層＋audit/op-log facade/entity 內容零 rev2 token。
- C-V-6：`/health` plain text "ok" 不變（mod audit 加入不退化、SC-006 子準則）。
