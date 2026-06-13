---
type: "query"
date: "2026-06-13T07:11:57.087355+00:00"
question: "m001 的 casbin_rule 委派如何串起 sea-orm-adapter、治理欄、與 m002 seed？"
contributor: "graphify"
source_nodes: ["casbin_rule table", "SeaOrmAdapter", "up()", "CasbinRule", "Model", "Migration"]
---

# Q: m001 的 casbin_rule 委派如何串起 sea-orm-adapter、治理欄、與 m002 seed？

## Answer

Expanded from original query via graph vocab: [casbin, rule, adapter, sea, orm, migration, schema, policy]. 委派鏈（皆 community 57 為主，跨 69/333/106）：m001 Migration.up()（m001_rev2_schema.rs:202）不手寫 casbin_rule 8 欄基底，委派 sea_orm_adapter::up()（sea-orm-adapter/src/migration.rs:19）建 8 欄+unique constraint→產出 casbin_rule table；m001 同檔 ALTER 補 3 治理欄（protected/created_at/created_by，adapter-invisible）。runtime 端 SeaOrmAdapter（adapter.rs:10）經 entity Model（entity.rs:7）操作同一 casbin_rule——故 migration 建的 schema 與 runtime adapter 共用此表（委派確保 m001 build 對齊 SeaOrmAdapter::new 的 if_not_exists 自建，⚠️v 單一 schema 來源拍板）。m002 Migration.up()（m002_rev2_seeds.rs:32）INSERT 72 policy 列進 m001 建的 casbin_rule（seed 依賴 m001 schema）。down 對稱：m001.down()（:845）→ sea_orm_adapter::down()（:58）drop 表。社群橋接 57（migration 執行）↔69（runtime adapter）↔333（entity Model）↔106（schema idents）。

## Source Nodes

- casbin_rule table
- SeaOrmAdapter
- up()
- CasbinRule
- Model
- Migration