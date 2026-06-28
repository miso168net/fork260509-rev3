# Implementation Plan: IP 存取控制閘（022-ip-access-control）

**Branch**: `022-ip-access-control` | **Date**: 2026-06-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/022-ip-access-control/spec.md`（brainstorm 接地 `docs/superpowers/022-ip-access-control.md`）

## Summary

通用 **IP 白/黑名單存取控制閘**：在 rust-api 全域中介層（`ipgate_mw`、疊 `audit_mw` 內側、real_ip 解析後）對**每個請求**的真實來源 IP 比對 CIDR 規則——**白名單命中→放行 ＞ 黑名單命中→阻擋（HTTP 403）＞ 其餘→放行（default-allow）**。**DB `sys_ip_rule` 為真相**，boot 載入 in-process `ArcSwap<RuleSet>`（純記憶體、lock-free、μs 級判定、DoS-resilient），改規則 publish `ipgate:invalidate` → watcher 重讀 DB 熱刷新（鏡像 settings watcher）。全程 **fail-OPEN**（§I.7）；寫端自鎖防護 + loopback/私網結構豁免；白名單**順便接 021 L0 seam 跳 lockout**（兌現 019 §4.2／021 FR-012）。附 **admin 手動解鎖**（reset-marker、per-dimension `since`、不刪 archetype-B append-only 列）。**CF Tunnel 繞 nginx 部署正式化**＋強化 `resolve_client_ip`（**窄 `tunnel` 信任條目** + 採信 `CF-Connecting-IP`、非 blanket internal）。**1 migration（m007、破 rev3 連 4 刀 0-migration streak）**、6 新 route、新 base-web 管理頁。

## Technical Context

**Language/Version**: Rust（rust-api、MSRV 1.86）＋ TypeScript/Vue 3（base-web、soybean v2 + naive-ui）

**Primary Dependencies**: `axum`（middleware layer）／`sea-orm`（`with-ipnetwork`、`IpNetwork.contains` CIDR 比對）／`arc-swap`（**已在 Cargo.lock 1.9.1〔transitive〕、本刀提升為 server crate direct dep、零版本 churn**）／`redis`（既有 facade、pub/sub invalidate）／`casbin`（require_policy 守門）／`tracing`（②c obs→loki）

**Storage**: PostgreSQL — **新表 `sys_ip_rule`**（archetype 受管實體 + soft-delete + 稽核 shadow；`cidr: IpNetwork`、partial unique `(cidr,rule_type) WHERE deleted_at IS NULL`、**migration m007**）。既有 `sys_login_attempt`（archetype B append-only、reset-marker 不刪列）、Redis（in-process ArcSwap 之分發門鈴 + 021 lockout key + reset-marker）。

**Testing**: cargo test（純函式 test-first〔CIDR 比對/gate 決策/013 fallback/restore 衝突/寫端自鎖〕；in-crate `#[ignore]`+env-gate live 測、容器內 `--test-threads=1`、需 DB+Redis）；curl/psql/redis-cli + CDP acceptance（contracts C-V）；**migration up→down→up**；**prod image build gate**（新 migration+新 route、雖非新 workspace crate 仍驗 multi-stage）。

**Target Platform**: Linux container stack（dev compose；prod 經 nginx 或 **cloudflared tunnel** ingress）

**Project Type**: web（rust-api 後端 + base-web 前端管理頁）

**Performance Goals**: 每請求判定＝**O(規則數) 純記憶體位元比對**（μs 級、lock-free ArcSwap load、零 DB/redis roundtrip）；被擋成本有界、與攻擊量無關（DoS-resilient、021 同課）；規則熱生效 ≤5s（redis invalidate→watcher 重讀）。

**Constraints**: **default-allow + fail-OPEN**（§I.7、載不進→放行）；白優先於黑（集合比對、非 first-match、無 priority 欄）；blocked **reuse `AppError::PermissionDenied`〔5003/HTTP 403〕、不新增 13-碼**（保 ⚠️f）；CF-CIP 採信限**窄 tunnel-origin + 不可內網偽造**（cold-review B2）；reset-marker per-dimension（cold-review B3）；被擋零 DB 寫**限未認證**（認證被擋留 1 列 access-log、cold-review B1）；rust 全程 serial；base-web `--no-verify`。

**Scale/Scope**: 4 執行單元（U1 rust 地基／U2 rust 閘／U3 rust CRUD+解鎖／U4 base-web）＋ docs；動點＝新 `entity/sys_ip_rule`＋`facade/sys_ip_rule`＋`migration/m007`＋新 `ipgate.rs`（RuleSet/ArcSwap/load/watcher）＋`audit_ctx.rs`（tunnel fallback）＋`auth.rs`（per-dim since + L0 seam）＋`main.rs`（layer+watcher+routes）＋`handler/system_manage.rs`（6 CRUD+unlock）＋`enforce.rs`/`endpoint_coverage_lint`（lint bump 44→50、36→42）＋base-web（新 view/service/typings/i18n）。

## Constitution Check

*GATE：Phase 0 前必過；Phase 1 後複檢。對照 constitution v1.1.2 §IV 九問。*

1. **§I.1 base-web 為權威**：✅ 新管理頁＝base-web view，rust-api 提供其消費的 6 新 endpoint（wire 由 base-web 契約定、rust 對齊）。
2. **動 base-web inline？MODAL-WIRING？**：✅ 新 view + add/edit/unlock modal＝MODAL-WIRING **(e) 新管理頁＋其 modules/***（**非 (c)**——(c) 嚴限「角色×權限 runtime 編輯器」鏡像 menu/button-auth-modal；本刀 modal〔dimension+value／cidr+rule_type〕非此物）；service wrapper＝BASE-WEB-WRAPPER（`rev3-system-manage.ts` 新檔）；i18n＝**`backend.*` biz key＝BASE-WEB-I18N-WIRING、`page.manage.ipRule.*`＋`route.manage_ip-rule`＝MODAL-WIRING (e)**；typings＝BASE-WEB-ADAPT。皆授權軌道內。
3. **menu Casbin enforce／⚠️p**：✅ 新管理頁 menu policy seed `('p','R_SUPER','manage_ip-rule','menu',...)`（⚠️p R_SUPER）；hasAuth gating；6 route `require_policy` 守門。
4. **§I.3 wire 對齊**：✅ 6 新 endpoint〔envelope `{data,code,msg}`〕；**blocked＝reuse `AppError::PermissionDenied`（5003/HTTP 403/`system.forbidden`）、非新 13-碼**（不破 ⚠️f）。CRUD 三端對齊（rust DTO↔base-web service+typings↔view）由 research §wire 釘。
5. **rev2 拷貝？**：✅ 無；全新寫（RUSTAPI-SOURCE-ISOLATION）。
6. **§II 拍板 #1~#13？**：✅ 無抵觸（blocked 5003 reuse 對齊 ⚠️f；不動 alt-login/captcha）。
7. **§III ★ 軌道？邊界內？**：✅ RUSTAPI-SOURCE-ISOLATION（rust 樹）＋ MODAL-WIRING/BASE-WEB-WRAPPER/BASE-WEB-I18N-WIRING/BASE-WEB-ADAPT（base-web）。obs ②c 為 rust 端。
8. **新建業務表 (migration)？**：✅ **新表 `sys_ip_rule`＝合規**（新【受管業務實體】、archetype 受管+soft-delete+稽核 shadow、**非 retrofit 審計欄**〔⚠️ac 釐清：新表/新 domain 欄合規〕）。本刀第一個 migration（m007），破 rev3 連 4 刀 0-migration streak＝合規必要（無法用既有 KV `system_settings` 表多列 CRUD 規則）。
9. **§I.7 行為島？invariants 保持？**：✅ IP 閘**非** §I.7 三台狀態機之一；**全 fail-OPEN**（§I.7）。觸 021〔白名單跳 lockout + reset-marker per-dim `since`〕＝對既有 lockout 的 **fail-OPEN + DB-truth 一致演進**（reset-marker 不刪 archetype-B append-only 列、§I.6 不破）。觸 013〔窄 tunnel CF-CIP fallback〕＝對 real_ip 解析的**刻意、窄範圍** as-built 演進（收尾加 013 as-built 註記）。

**結論：9/9 PASS、0 Amendment 需求、0 Complexity Tracking 違規。**（1 合規 migration；blocked reuse 既有 5003 不破碼表；013/021 觸碰皆一致演進。）

## Project Structure

### Documentation (this feature)

```text
specs/022-ip-access-control/
├── plan.md              # 本檔
├── research.md          # Phase 0（act-on-code 接地 + D1~Dn 決策、含 5 deferred 釘死）
├── data-model.md        # Phase 1（sys_ip_rule entity + RuleSet + gate 狀態 + reset-marker）
├── quickstart.md        # Phase 1（驗證指南）
├── contracts/
│   └── verification-commands.md   # C-V-0~N（curl/psql/redis-cli + CDP + 純函式/live + migration + prod gate）
├── checklists/requirements.md     # spec 品質（specify 產、16/16）
└── tasks.md             # Phase 2（/speckit-tasks 產、非本步）
```

### Source Code（repository root）

```text
rust-api/
├── entity/src/sys_ip_rule.rs                 # 新 entity（id/cidr:IpNetwork/rule_type/order/description/稽核+soft-del）
├── migration/src/m007_create_sys_ip_rule.rs  # 新 migration（CREATE TABLE + partial unique + casbin seed〔6 route+menu〕）
├── server/src/
│   ├── ipgate.rs                             # 新：RuleSet{allow,deny:Vec<IpNetwork>} + load_active 解析 + spawn_ipgate_watcher + STRUCTURAL_EXEMPT const
│   ├── state.rs                              # +ip_rules: Arc<ArcSwap<RuleSet>>
│   ├── main.rs                               # boot 載入 + spawn watcher + .layer(ipgate_mw) + 6 route+require_policy
│   ├── middleware/ipgate_mw（或 ipgate.rs 內）# 閘：path/結構豁免→白→黑(②c obs+403)→default-allow、fail-OPEN(.get Option)
│   ├── audit_ctx.rs                          # 013 強化：TrustModel +tunnel 欄、resolve_client_ip Fallback+peer∈tunnel→CF-CIP
│   ├── config.rs                             # TrustModel +tunnel: Vec<IpNetwork>（trust-model.toml parse）
│   ├── handler/auth.rs                       # L0 seam 白名單跳 lockout + per-dim since（reset-marker）
│   ├── handler/system_manage.rs              # 6 CRUD/unlock handler（require_policy + 寫端自鎖 + op-log）
│   ├── model/facade/sys_ip_rule.rs           # 新 facade（load_active/list/create/update/soft_delete/restore）
│   ├── redis.rs                              # reset-marker reuse set_revoked/revoked_at_of 範式（或加薄包）
│   ├── auth/enforce.rs                       # ALL_ENDPOINT_POLICIES 36→42
│   └── tests/endpoint_coverage_lint.rs       # AS_BUILT_ROUTES 44→50
└── deploy/trust-model.toml                   # +[[tunnel]] 範例條目（窄 cloudflared origin）

base-web/src/
├── views/manage/ip-rule/index.vue            # 新管理頁（列表含已刪+Deleted欄+搜索分頁+CRUD+復原+解鎖 modal）
├── service/api/rev3-system-manage.ts         # +6 service wrapper
├── typings/api/system-manage.d.ts            # +IpRule/IpRuleSearchParams/... 型
└── locales/langs/{zh-cn,en-us}.ts            # +backend.*.* biz key + page.manage.ipRule.* + route.*

docs/                                          # CF Tunnel 拓樸正式化（收口）
├── INTEGRATION-DESIGN.md                     # 新節「部署入口拓樸/信任邊界」+ §1.0 勘誤
├── INTEGRATION-DECISIONS.md                  # §1 新碼 ⚠️ae
└── （CLAUDE.md §8.2 第4模式 tunnel / CHECKLIST §4.2 分模式 1/2）
```

**Structure Decision**：沿用既有 rust-api facade-only + base-web 軌道結構；新增 1 entity/1 facade/1 migration/1 新模組（ipgate）+ 1 新 base-web view。閘為獨立 middleware layer（單一職責、可測）；013/021 觸碰為最小手術（窄 fallback／per-dim since）。

## Complexity Tracking

> 無 Constitution 違規需證成（9/9 PASS）。1 migration 為合規必要（新受管實體、§8/⚠️ac），非破例。本表空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| （無） | — | — |
