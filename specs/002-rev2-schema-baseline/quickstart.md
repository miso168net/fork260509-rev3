# Quickstart: 002-rev2-schema-baseline 驗證指南

> 從零到「基線零漂移＋delta 斷言」全綠；完整命令與期望輸出見 [contracts/verification-commands.md](contracts/verification-commands.md)（C-V-0~9）、行為契約見 [contracts/migration-chain.md](contracts/migration-chain.md)。

## 前置需求

- rev2 資產本機可用：`fork260509-rev2/` repo（源碼對照）＋`rev2-admin-rust-api:latest` image（pristine 重放）
- 001 dev stack 可啟（migrate gate 實機驗收用）；docker 可建拋棄式容器（`cv002-*`、結束即清）
- pg_dump 一律容器內跑（17.10；host 16 打 17 server 會被拒——只影響 dump、host psql 查詢不受限）

## 驗證主線（依序）

```bash
# 1. 建置（adapter 拷入＋workspace deps 後）＋ time 複驗
cd rust-api && cargo build --bins && cd .. && grep -c 'name = "time"' rust-api/Cargo.lock   # 期 0

# 2. pristine 參考庫（rev2 35 支重放 → normalize dump）           ……C-V-2
# 3. rev3 基線檢查點（up -n 2 → 雙 diff 零差異＋計數不變式）        ……C-V-3 ★⚠️t 核心斷言
# 4. delta（續 up → FK/demo/基線不變斷言）                        ……C-V-4
# 5. 守恆（down -n 4 → 僅剩框架表 → 重建 → diff 重跑仍綠）          ……C-V-5
# 6. 冪等（再 up → exit 0、列數不變）                              ……C-V-6
bash tests/002-rev2-schema-baseline/scripts/pristine-replay.sh
bash tests/002-rev2-schema-baseline/scripts/diff-baseline.sh      # 內含 up -n 2＋normalize＋雙 diff
bash tests/002-rev2-schema-baseline/scripts/delta-assert.sh
```

期望：`SCHEMA 零差異 ✅`＋`SEED 零差異 ✅`＋全部計數不變式 PASS。**diff 非零先判假紅 vs 真 drift**（migration-chain.md §3 判讀紀律）。

## dev stack 實機＋建置紀律

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait    # migrate gate 自動套 4 支……C-V-7
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api # 新 crate COPY 驗……C-V-8（必跑）
```

## 收尾

```bash
docker rm -f cv002-rev2-pg cv002-rev3-pg && docker network rm cv002-net        # 拋棄式資源清理
```
