# Data Model: 001-infra-deploy

**本刀無資料模型。**

- 業務 schema（12 表）與 seed 依拍板 ⚠️t 屬 **002-rev2-schema-baseline 刀**（`m001_rev2_schema`＋`m002_rev2_seeds` 終態 squash；DECISIONS §1）。
- 本刀 migration crate 為**空 migrator**（`migrations() → vec![]`）：`migration up` 連線資料庫後僅由 sea-orm-migration 框架建立 `seaql_migrations` 追蹤表（DESIGN 附錄 F #12——框架表、非業務主表、不受 constitution §I.6 審計欄標準約束、不入 §8.8 drift 基線）即成功退出。
- CLAUDE.md §3 Phase 0 research 紀律之 data-model file:line 對照 grep：**N/A**（research.md R10）。
