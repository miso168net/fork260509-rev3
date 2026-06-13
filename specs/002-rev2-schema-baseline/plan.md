# Implementation Plan: rev2-schema-baseline（rev2 終態基線＋rev3 delta）

**Branch**: `002-rev2-schema-baseline` | **Date**: 2026-06-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-rev2-schema-baseline/spec.md`＋brainstorm `docs/superpowers/002-rev2-schema-baseline.md`（四項拍板＋⚠️v）

## Summary

rev2 35 支 migration squash 為 **2 支基線**：`m001_rev2_schema`（11 表終態忠實濃縮——10 手寫＋casbin_rule 委派 vendored adapter〔⚠️v〕；＋seaql 框架自建＝12 表口徑）＋`m002_rev2_seeds`（92 列／6 表淨效果、argon2id 單一 hash）；**rev3 delta 顯式 2 支**：`m003_user_role_fk`（④、RESTRICT）＋`m004_demo_menu_seeds`（⚠️p 66 條 demo 選單＋policy 全覆蓋 66 列）；sea-orm-adapter 整檔拷入（§I.5 例外）；pg_dump 雙庫 diff 零漂移閉環（pristine 重放＋`up -n 2` 檢查點＋normalize 六規則）＋delta 斷言＋up→down→up 守恆，001 dev stack 實機驗收。

## Technical Context

**Language/Version**: Rust 1.86.0（rust-toolchain pin、001 落值）＋SQL（PostgreSQL 17）＋Bash（tests/002 驗證 scripts）

**Primary Dependencies**: sea-orm-migration 1.1.20（既有）；**workspace 新增**：`casbin 2.20`（default-features=false、rev2 同形）＋`sea-orm 1.1.20`（**default-features=false＋最小 features 集——刻意偏離 rev2 defaults-on、time 不入圖**，research R3）＋`argon2 0.5.3`；`sea-orm-adapter` vendored path dep（§I.5 整檔拷貝）

**Storage**: PostgreSQL 17（postgres:17-alpine；001 stack＋拋棄式驗證容器）

**Testing**: 實機 acceptance（C-V：pristine 重放雙 diff＋delta 斷言＋up→down→up＋dev stack gate＋prod image build；contracts/verification-commands.md）。**無新增單元測試**——本刀為 migration／seed／驗證 scripts、無可獨立測純函式；adapter 自帶測試隨整檔拷入但不納驗收（需 DB fixture；其行為由 m001 委派執行＋零漂移 diff 實證覆蓋）；依 CLAUDE.md §3 紀律於此明示、tasks.md 同步聲明。

**Target Platform**: 001 交付 dev stack（migrate gate 自動套用）＋拋棄式容器（diff 驗證）

**Project Type**: schema baseline（migration 鏈＋vendored crate＋驗證基建）

**Performance Goals**: N/A（92＋66 列規模；⚠️a 拍板＝波 1 才議）

**Constraints**: 欄序忠實（dump 欄序＝diff 硬約束）；diff 檢查點＝m002 後 m003 前（`up -n 2`）；normalize 六規則缺一假紅；§I.4 push/merge 凍結至 finishing（⚠️u 紀律：tasks 不得排 push）；m004 down 限定 demo 集（不得波及基線）

**Scale/Scope**: migration ×4＋adapter crate（manifest＋src×5＋examples×4）＋workspace deps ×3＋Dockerfile COPY ×2 行＋tests/002 scripts ×4＋dump 基準檔；seed 92＋66 列、policy 66 列

## Constitution Check

*constitution-rev3 v1.0.0 §IV 九題逐答——Phase 0 前評估＋Phase 1 後複評均 PASS：*

| # | 題 | 判定 |
|---|---|---|
| 1 | 違反 §I.1 base-web 為權威？ | **PASS**——無業務 endpoint；m004 route_name 以 base-web route 樹為權威枚舉（research R4、66 條帳目核對） |
| 2 | 動 base-web inline？ | **PASS（未觸）**——交付全在 rust-api worktree＋outer tests/＋deploy/ COPY 行；base-web 唯讀 grep |
| 3 | menu 顯示走 Casbin enforce？ | **PASS（正面落地）**——m004 即 ⚠️p 實體化：demo 全進 sys_menu seed、初始僅 R_SUPER、可見性交 ROLE 勾選層（非隱藏）；policy 全覆蓋 66 列（R4-D3，含 depth-1 目錄——filter_routes 兩層 prune 實證） |
| 4 | wire 對齊 §I.3 typings 權威序？ | **PASS**——本刀無新 wire；seed 值與 typings 對齊（icon_type `'1'\|'2'`、R4 映射表）；wire 降級議題（localIcon/multiTab/href 不序列化）登 Menu 刀 backlog、不反向汙染 seed（R4-D4） |
| 5 | 從 rev2 source 拷貝 code？ | **PASS（雙模式合規）**——sea-orm-adapter 整檔拷貝＝§I.5 例外清單明文（⚠️v 拍板行使）；migration 35→4 squash＝受控參照重寫非照拷；防回歸條款查核：m004 採 ⚠️p 新形（rev2 隱藏取向已推翻、未帶回）✓ |
| 6 | 抵觸 §II 拍板 #1~#13？ | **PASS**——#1 帳號名 Super/Admin/User 落地（m002）；#5 ⚠️p 落地（m004）；#6 拷貝例外行使；⚠️k mNNN 檔名；⚠️r DB 一律 BIGSERIAL i64；無拍板需改變 |
| 7 | 觸 §III ★ 軌道？ | **PASS（未觸）**——不動 `views/manage/**`、無 inline、fork-delta 紀律不適用 |
| 8 | 新建業務表？ | **YES→PASS**——m001 建 11 表：A 表（user/role/menu/settings）§I.6 六審計欄**建表即帶**✓；B 三 log 表僅 created_at（archetype 例外）✓；C join 表零審計硬刪✓＋sys_token 僅 created_at✓；D casbin 治理欄建表即含（委派＋同檔 ALTER）✓；零 retrofit ✓ |
| 9 | 觸 §I.7 行為島？ | **PASS（未觸）**——sys_token 等表結構屬基線 schema；rotation／governance／single-session 狀態機＝波 3 |

**Gate 結論：9/9 PASS，無需 amendment、無 violation 待 justify。**

## Project Structure

### Documentation (this feature)

```text
specs/002-rev2-schema-baseline/
├── spec.md              # /speckit-specify ✅
├── plan.md              # 本檔
├── research.md          # Phase 0 ✅（R1~R10＋R4 衍生裁定 D1~D4＋移交 backlog）
├── data-model.md        # Phase 1 ✅（12 表 dump 行號座標＋seed 92 列值來源＋delta 模型）
├── quickstart.md        # Phase 1（從零驗證指南）
├── contracts/
│   ├── verification-commands.md   # C-V 驗收命令全集（§0 scripts I/O 表＋diff 閉環＋delta 斷言＋守恆＋prod build）
│   ├── migration-chain.md         # m001~m004 行為契約（up/down 效果、檢查點語意、normalize 規則）
│   └── demo-menu-enumeration.md   # m004 凍結枚舉（66 條＋映射權威＋不變式）——T012 轉錄權威
├── checklists/requirements.md     # 16/16 ✅
└── tasks.md             # /speckit-tasks 產出（非本命令）
```

### Source Code (repository root)

```text
fork260509-rev3/
├── rust-api/                          # worktree（兩段式 commit）
│   ├── Cargo.toml                     # workspace：members ＋ sea-orm-adapter；deps ＋ casbin/sea-orm/argon2（R3 宣告形）
│   ├── Cargo.lock                     # 更新後複驗 time 不入圖（R3 義務）
│   ├── sea-orm-adapter/               # 整檔拷貝（§I.5）：Cargo.toml＋src/{lib,adapter,entity,action,migration}.rs＋examples/×4
│   └── migration/
│       ├── Cargo.toml                 # ＋argon2＋sea-orm-adapter path dep
│       └── src/
│           ├── lib.rs                 # 掛 4 支（vec 序＝執行序）
│           ├── main.rs                # 順手：secret 讀檔失敗 eprintln（CHECKLIST §3.4）
│           ├── m001_rev2_schema.rs    # 10 表手寫終態＋casbin 委派＋ALTER 治理欄；對稱 down
│           ├── m002_rev2_seeds.rs     # 92 列／6 表淨效果；argon2id；冪等；down＝限定刪除
│           ├── m003_user_role_fk.rs   # FK ×2 RESTRICT；down＝卸 FK
│           └── m004_demo_menu_seeds.rs# 66 選單（深度分批）＋policy 66；down 限定 demo 集
├── deploy/Dockerfile.rust-api.txt     # Manifest／Source 段補 sea-orm-adapter COPY ×2 行
└── tests/002-rev2-schema-baseline/
    ├── rev2-schema-baseline.sql       # pristine 參考 schema dump 基準（normalize 後、git-tracked）
    ├── rev2-data-baseline.sql         # pristine 參考 6 表 seed data dump 基準（normalize 後、git-tracked）
    └── scripts/{pristine-replay.sh, normalize.sh, diff-baseline.sh, delta-assert.sh}   # I/O 契約＝verification-commands.md §0
```

## Phase 0：研究結論

見 [research.md](research.md)——R1 squash 紀律（欄序忠實）／R2 ⚠️v 委派＋拷貝清單／R3 manifest 宣告形實查（**workspace 須加 casbin＋sea-orm 條目；rev2 defaults-on＝time 根因；rev3 最小集 time-free 刻意偏離**）／R4 demo 枚舉定稿（66 條＋D1~D4 裁定＋移交 backlog）／R5 seed 值來源（protected 跨檔拆解）／R6 diff 工具鏈（normalize 六規則）／R7 sequence 等價已驗／R8 RESTRICT／R9 依賴增量／R10 三 grep 紀律。NEEDS CLARIFICATION＝0。

## Phase 1：設計產物

- [data-model.md](data-model.md)：12 表 dump 行號座標（全數親 grep 驗證）＋欄序忠實警告＋seed 92 列值來源＋delta 模型＋排除聲明
- [contracts/verification-commands.md](contracts/verification-commands.md)：C-V 全集——pristine 重放→`up -n 2` 檢查點雙 diff 零差異→續 up delta 斷言→up→down→up 守恆→dev stack gate 實機→**prod image build**（新增 workspace crate ⇒ 必含，CLAUDE.md §3 紀律）→冪等→time 複驗
- [contracts/migration-chain.md](contracts/migration-chain.md)：m001~m004 up/down 行為契約＋檢查點語意＋normalize 六規則凍結
- [contracts/demo-menu-enumeration.md](contracts/demo-menu-enumeration.md)：m004 凍結枚舉（66 條集合＋28 欄映射權威＋不變式）
- [quickstart.md](quickstart.md)：從零驗證指南

## 實作注意（移交 tasks）

1. **順序**：adapter 拷入＋workspace deps（cargo build 綠）→ m001~m004（每支可獨立 review）→ tests/002 scripts → diff 閉環實機 → delta 斷言 → 守恆 → dev stack gate → prod image build → 兩段式 commit（worktree 逐 task、outer pin 隨同 task bump——001 review 教訓：pin 不延後收口）
2. **m004 細節**：INSERT 按深度 4 段分批（parent_id subquery 先父後子）；down 限定 demo route_name 集；plugin menu_name 中文；document 8 頁 href 化（R4-D2）
3. **m002 細節**：sequence-driven 插入（不寫死 id）；user_role 雙向 subquery；casbin 列免 subquery；UPDATE 淨值直接入 INSERT
4. **push/merge 全凍結（§I.4／⚠️u）**：實作期 commit only；tasks.md 不得出現 push／merge 步驟
5. **失敗處置**：diff 非零＝先判 normalize 缺漏 vs 真 drift（Edge case「假紅＝驗證流程缺陷」）；真 drift 修 m001/m002 重跑、不調 normalize 遮差異
