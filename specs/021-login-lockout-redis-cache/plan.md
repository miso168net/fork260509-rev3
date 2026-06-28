# Implementation Plan: 登入鎖定快取層（021-login-lockout-redis-cache）

**Branch**: `021-login-lockout-redis-cache` | **Date**: 2026-06-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/021-login-lockout-redis-cache/spec.md`

## Summary

硬化 019-login-lockout：對「已生效鎖定」在 login gate 最前端加一層 **Redis 負快取（deny 層）**，使分散式打單帳號（per-user 維度）下「已鎖定嘗試」的評估成本由「隨窗成長的無-LIMIT COUNT＋每次 INSERT」降為 **O(1)**（1-2 個 Redis GET），堵掉 DB 讀取/寫入放大與稽核表被灌。**DB 維持鎖定真相**（既有滑動窗失敗計數），Redis 為非權威加速層、掛了退回 019 既有 DB gate（fail-OPEN）。**技術途徑**：login 起手查 `lockout:ip:{ip}` / `lockout:user:{name}`（D1 雙維度）→ 命中即拒（②b 不寫稽核 + ②c 節流麵包屑→loki log）；miss 走既有 DB gate、達門檻則 `set_ex` 觸發維度的 key（D2 固定 TTL=900s 不 refresh→攻擊停自癒）。**clarify firm**：鑑識麵包屑必需「壓制次數」（distinct-source 可選/遞延）、本刀只發可告警訊號（告警規則配置遞延 ops/obs）。**0 migration／0 新 crate／0 新 route**；redis facade 小幅加 `incr`（+ 計數讀取/重置）；**有意識反轉 019 FR-004/FR-008**（鎖後不逐筆寫稽核、改節流摘要）。

## Technical Context

**Language/Version**: Rust（rust-api、MSRV 1.86）— **無 base-web 改動**

**Primary Dependencies**: `redis`（既有 `RedisHandle` facade、`MultiplexedConnection`/`AsyncCommands`）／axum／`tracing`（018 json subscriber → loki）；sea-orm（既有 `sys_login_attempt` facade）

**Storage**: PostgreSQL（既有 `sys_login_attempt` ＋兩複合索引、**零 schema 變更**、L2 鎖定真相）；Redis（既有 facade、+`incr`；L1 非權威鎖定快取 + ②c 計數）

**Testing**: cargo test（純函式 test-first；in-crate `#[ignore]`+env-gate live 測、容器內 `--test-threads=1`、需 Redis+DB）；curl/psql/量測 acceptance（contracts C-V）；prod image build gate

**Target Platform**: Linux container stack（dev compose）

**Project Type**: web（rust-api 後端 only；**無 frontend 改動**）

**Performance Goals**: 鎖後每嘗試評估＝**O(1)**（1-2 Redis GET、無 DB query/write）；②c 寫入有上限（≤1 摘要 log/60s/key）；DB COUNT 結構性永遠只掃近乎空窗

**Constraints**: 0 migration／0 新 crate／0 新 route；對 base-web 零改動（login wire 不變、reuse `auth.login.locked`）；全程 **fail-OPEN**（沿 §I.7／019）；reuse 019 政策值（per-user 5／per-ip 20／窗 900s＝TTL）；redis facade +`incr`；**有意識反轉 019 FR-004/FR-008**（鎖後不逐筆寫稽核）

**Scale/Scope**: 1 rust 執行單元（login gate L1 cache 層 + redis facade `incr`/計數 helper + ②c obs log）；動點＝`handler/auth.rs`（login gate 分層）+ `server/src/redis.rs`（+`incr`/take-suppressed）+（可能）`model/facade/sys_login_attempt.rs` 不變（L2 既有 count 沿用）

## Constitution Check

*GATE：Phase 0 前必過；Phase 1 後複檢。對照 constitution v1.1.2 §IV 九問。*

1. **§I.1 base-web 為權威**：✅ N/A — **零 base-web 改動**、無新 endpoint（login `/auth/login` wire 不變、沿用 019 行為）。rust-api 未缺 base-web 用到的 endpoint。
2. **動 base-web inline？MODAL-WIRING？**：✅ N/A — 不動任何 base-web；**無 i18n 新鍵**（鎖定 toast 沿用既有 `auth.login.locked`），故不觸 MODAL-WIRING／BASE-WEB-I18N-WIRING。
3. **menu Casbin enforce／⚠️p**：✅ N/A（不動 menu）。
4. **§I.3 wire 對齊**：✅ login endpoint wire **完全不變**——同 envelope `{data,code,msg}`、鎖定仍回 **`2222`**（BizError）+ `msg=auth.login.locked`（既有 i18n key）。**無新 wire／無新碼**；13 碼矩陣不動。`/health`/`/metrics` envelope 例外不涉。
5. **rev2 拷貝？**：✅ 無；L1 cache 層全新寫（RUSTAPI-SOURCE-ISOLATION）；不帶回已推翻行為。
6. **§II 拍板 #1~#13？**：✅ 無抵觸（2222 reuse 對齊 #10；不動 alt-login/captcha #2/#13）。
7. **§III ★ 軌道？邊界內？**：✅ 僅 **RUSTAPI-SOURCE-ISOLATION**（rust 整棵樹）；**無** ★ base-web 軌道（無 UI／i18n inline）。obs log 為 rust 端。
8. **新建業務表 (migration)？**：✅ **無**（零 migration）。reuse 既有 `sys_login_attempt`（archetype B append-only）＋兩既有索引；Redis key 非 DB；②c 落 obs log 非 DB 列（避免動 schema 與污染鎖定 COUNT）。
9. **§I.7 行為島？invariants 保持？**：✅ login lockout **非** §I.7 三台狀態機（token rotation／policy governance／single-session）之一、不動其 invariants。**對齊 §I.7 哲學**：(a) **fail-OPEN** 全程保持（FR-008、Redis/DB 抖動降級放行、沿 §I.7／019/007）；(b) **§4.3 persist-then-cache 範式**——鎖定真相在 DB（滑動窗 count）、Redis 為**非權威快取**（掛了退回 DB gate、lazy 重建），與 single-session pointer「真相在 DB、Redis 僅快取、可失憶」同構。**§I.6 archetype B 不破**：`sys_login_attempt` 仍只 INSERT（append-only、不可竄改）、本刀只是**鎖後 INSERT 更少列**（非加 update/delete 欄、非竄改）→ archetype B 規則維持。**★ 注**：本刀**有意識反轉 019 spec 的 FR-004（exactly-one per terminal result）/FR-008（gated 列 sticky 審計）**——此二者為 **019 spec 設計選擇、非 constitution 不變式**，反轉不違憲；屬對 019 的 as-built 演進（見 research D7、收尾比照 020 對 011 加 as-built 註記）。

**結論：9/9 PASS、0 Amendment 需求、0 Complexity Tracking 違規。**（無 base-web／無 migration／無新 crate／無新 route／無新 wire；Redis 用對齊 §I.7 §4.3 非權威快取＋fail-OPEN；019 FR-004/008 反轉為 spec-level as-built、非憲法面。）

## Project Structure

### Documentation (this feature)

```text
specs/021-login-lockout-redis-cache/
├── plan.md              # 本檔
├── research.md          # Phase 0（act-on-code 接地 + D1~D8 決策）
├── data-model.md        # Phase 1（既有 entity + Redis key 模型 + gate 狀態轉移）
├── quickstart.md        # Phase 1（驗證指南）
├── contracts/
│   └── verification-commands.md   # C-V-0~N（curl/psql/量測 + 純函式/live 測 + prod gate）
├── checklists/
│   └── requirements.md  # spec 品質檢核（specify 產、16/16）
└── tasks.md             # Phase 2（/speckit-tasks 產、非本步）
```

### Source Code（rust-api worktree；皆既有檔，無新目錄/crate/表）

```text
rust-api/server/src/
├── handler/auth.rs                 # login(:211-281) 分層 gate：L1 Redis 負快取（查 lockout:ip/user → 命中拒 + ②c 麵包屑 + ②b 不寫）→ L2 既有 DB gate（miss、不動）+ 達門檻 set_ex 觸發維度 key；is_locked_out(:68) 不變；新「快取決策」純函式 + #[cfg(test)] 測
├── redis.rs                        # +incr（鏡像 set_ex/get fail-OPEN 範式）+ take-suppressed（讀+重置、GETDEL）+ lockout key helper（lockout:ip:/user:/suppressed:/flushed:）；++可選 set_locked/is_locked 語意包
└── model/facade/sys_login_attempt.rs  # L2 既有 count_failed_by_*_since 沿用（不變）；write(:51) 沿用（僅 Redis-miss 路徑呼）
```

**Structure Decision**：沿用既有 rust-api 結構；**無 base-web／無 migration／無新 crate／無新 route／無新 wire**。單一 rust 執行單元（login gate 分層 + redis facade incr/計數 + ②c obs log）。L2 既有 DB gate 與 `is_locked_out` 純函式完全不動（真相層）；本刀只在其前疊加 L1 快取層 + 改鎖後寫入處置。

## Complexity Tracking

> 無 Constitution 違規需證成（9/9 PASS、0 migration/crate/route、軌道內）。本表空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| （無） | — | — |
