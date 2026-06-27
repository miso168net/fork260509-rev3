# Implementation Plan: 角色刪除授權歸檔（020-role-delete-policy-archive）

**Branch**: `020-role-delete-policy-archive` | **Date**: 2026-06-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/020-role-delete-policy-archive/spec.md`

## Summary

修 P-011-1（HIGH）：角色軟刪不清其 casbin 授權 + code 可重用 + casbin 以 code 為鍵 → 重建同 code 的新角色靜默繼承舊授權。**技術途徑**：角色軟刪（單筆/批次）的**同一交易**內，把該 code 的全部 casbin p-policy（全維、含 protected）archive-move（復用 `insert_archived`、reason=`role_soft_delete`）+ 自 `casbin_rule` 移除；commit 後 archived>0 則 `reload_and_publish`。回收桶（`getArchivedPolicies`）含這些列但 `restorable=false`、`restorePolicy` 拒復原（2222 `biz.policy.notRestorable`）。**FR-005+FR-012 統一為讀時 `created_at` 衍生判定**（restorable = 撤銷類 reason AND 存在 active 角色 code=v0 且 created_at<archived_at），**零 archive 列 mutation、零 migration**（完全遵守 §I.6 archetype D）。base-web 回收桶頁加 restorable 條件化復原鈕 + reason 友善標籤 + i18n。

## Technical Context

**Language/Version**: Rust（rust-api，MSRV 1.86）＋ TypeScript/Vue 3（base-web）
**Primary Dependencies**: sea-orm（facade-only entity 存取）／axum／casbin enforce（in-tree）；base-web naive-ui + vue-i18n
**Storage**: PostgreSQL（既有 `casbin_rule`／`sys_casbin_policy_archive`／`sys_role`，**零 schema 變更**）；Redis（既有 pub-sub `casbin:policy:invalidate`，不新增）
**Testing**: cargo test（in-crate `#[ignore]`+env-gate live 測、純函式測；rust-api 容器內 `--test-threads=1`）；curl/psql/CDP acceptance（contracts C-V）；prod image build gate
**Target Platform**: Linux container stack（dev compose）
**Project Type**: web（rust-api 後端 + base-web 前端）
**Performance Goals**: N/A（治理操作、非熱路徑；getArchivedPolicies 加 active-role created_at 批次查＝per-page 一次、可忽略）
**Constraints**: 零 migration／零新 crate／零新 route；對 base-web 僅授權軌道 inline；§I.6 archive archetype D 不 mutate；**並發＝lock-then-redecide**（restore/delete 同 `sys_role` 列 `FOR UPDATE`、C1）；**時鐘單調假設**（created_at 衍生實例判別、C2=A、spec Assumptions 已記）
**Scale/Scope**: 2 執行單元（U1 rust：archive-on-delete + 回收桶後端衍生／守門；U2 base-web：回收桶顯示/不可復原 + i18n）；rust-api ~3 動點（facade helper、soft_delete/batch 擴充、getArchivedPolicies/restorePolicy 衍生+守門）+ base-web 1 view + i18n

## Constitution Check

*GATE：Phase 0 前必過；Phase 1 後複檢。對照 constitution v1.1.2 §IV 九問。*

1. **§I.1 base-web 為權威**：✅ 不縮減；無新 base-web 用到但 rust-api 缺的 endpoint。本刀於既有 `getArchivedPolicies` response 加 `restorable` 欄、base-web `ArchivedPolicy`（rev3 wrapper 型）對應加（ADAPT 軌、逐欄忠實）。
2. **動 base-web inline？MODAL-WIRING？**：✅ 動 `views/manage/policy-archive/modules/policy-archive-table.vue`（015 既有回收桶頁＝MODAL-WIRING (e) 既有產物）——operate 欄依 `restorable` 條件化復原鈕（鏡像 (b) 動作鈕可見性 gating）＋`archiveReason` 友善標籤（顯示）。**在 MODAL-WIRING 授權邊界內、非新 inline 位置**；i18n 新鍵走 BASE-WEB-I18N-WIRING (ii)/(iii)。依 §III fork-delta `rev3-inline` 紀律（修改型原行註解、新增型圈界）。
3. **menu Casbin enforce／⚠️p**：✅ N/A（不動 menu 顯示/demo seed）。
4. **§I.3 wire 對齊**：✅ envelope 不變；`restorable: boolean` 逐欄忠實（base-web typings 對應）；restorePolicy 拒＝`2222`（業務碼、HTTP 200 信封）+ `msg=biz.policy.notRestorable`（⚠️y i18n key）；13 碼矩陣不動。
5. **rev2 拷貝？**：✅ 無；新 facade helper 全新寫（RUSTAPI-SOURCE-ISOLATION）；不帶回已推翻行為。
6. **§II 拍板 #1~#13？**：✅ 無抵觸。
7. **§III ★ 軌道？邊界內？**：✅ MODAL-WIRING（回收桶頁 restore 控制 + reason 顯示）＋ BASE-WEB-I18N-WIRING（`backend.biz.policy.notRestorable` + `page.manage.policyArchive.*` 標籤、Schema+locale 雙語）。皆授權內、循 fork-delta 紀律。
8. **新建業務表 (migration)？**：✅ **無**（零 migration）。archive/casbin/sys_role 皆既有；FR-012 刻意採 D4 讀時衍生（非加欄/mutate）正為避免動 §I.6 archetype D 與 schema。
9. **§I.7 行為島（policy governance §4.2）？invariants 保持？**：✅ DB-first（寫 DB→reload）✓；reload＝`load_policy()`+PUBLISH（復用 `reload_and_publish`）✓；PolicyMutated gate（archived==0 skip reload）✓；revoke 與審計同 txn（archive 於 soft_delete 同 txn、角色 SoftDelete op-log + archive 列 archived_at/by 為 forensic）✓。**protected 注記**：role-delete archive「全維含 protected」**不違** §4.2「protected 列拒撤→Rejected」——該 invariant 治理的是 **live 角色的逐條 UI revoke 流程**（防誤鎖核心存取）；角色刪除為**另一獨立、且另有守門（seeded/in-use/self）**的整角色操作。且**可刪（非種子）角色實務上不持有 protected 列**（protected 僅 seed 於不可刪的種子角色、runtime grant 一律 protected=false）→ 實際 archive 零 protected 列、invariant 未被觸動、無反轉。**最強理由（C11）**：唯一 protected 持有者 `R_SUPER` ∈ `SEEDED_ROLE_CODES`、`role_delete_guard` 直接 2222 拒刪 → archive helper **從不跑在 protected 持有者上**（雙重不觸 §4.2）。**並發（C1）**：restore/delete 同 `sys_role` 列 `FOR UPDATE`（lock-then-redecide）維持 §I.7「revoke 與審計同 txn 原子」於並發下不破（防 restore-during-delete TOCTOU 留 orphan live 授權）。

**結論：9/9 PASS、0 Amendment 需求、0 Complexity Tracking 違規。**（base-web inline 屬 MODAL-WIRING/I18N-WIRING 授權內；FR-012 採零-mutation 衍生避開 §I.6/migration。）

## Project Structure

### Documentation (this feature)

```text
specs/020-role-delete-policy-archive/
├── plan.md              # 本檔
├── research.md          # Phase 0（4 線 act-on-code 接地 + D1~D8 決策）
├── data-model.md        # Phase 1（entity 角色 + ★ restorability 衍生規則 + 真值表）
├── quickstart.md        # Phase 1（驗證指南）
├── contracts/
│   └── verification-commands.md   # C-V-0~11（curl/psql/CDP + lint + prod gate）
├── checklists/
│   └── requirements.md  # spec 品質檢核（specify 產、12/12）
└── tasks.md             # Phase 2（/speckit-tasks 產、非本步）
```

### Source Code（worktrees；皆既有檔／新 facade helper，無新目錄）

```text
rust-api/server/src/
├── model/facade/
│   ├── sys_role.rs                 # soft_delete:302 / batch_soft_delete:344 擴充（同 txn 呼 archive helper）
│   ├── sys_casbin_rule.rs          # 新 helper archive_all_role_policies（讀 v0=code 全維→insert_archived→delete_many）
│   └── sys_casbin_policy_archive.rs# insert_archived:32 復用；restore 加 NotRestorable 判（D4 衍生）
└── handler/system_manage.rs        # delete_role:1208 / batch_delete_role:1239（守門後 archive + reload_and_publish）；
                                    #   ArchivedPolicyItem:387 加 restorable；get_archived_policies:1844 衍生；restore_policy:1888 守門

base-web/src/
├── views/manage/policy-archive/modules/policy-archive-table.vue  # operate 條件化 + reason 標籤（MODAL-WIRING）
├── typings/api/rev3-system-manage.d.ts  # ArchivedPolicy +restorable（ADAPT）
├── typings/app.d.ts                # App.I18n.Schema +backend.biz.policy.notRestorable +page.manage.policyArchive labels（I18N-WIRING iii）
└── locales/langs/{zh-cn,en-us}.ts  # 對應雙語譯文（I18N-WIRING ii）
```

**Structure Decision**：沿用既有 rust-api facade-only + base-web 軌道結構；無新目錄/crate/表。U1 rust（archive-on-delete + 回收桶後端：衍生 restorable + restorePolicy 守門 + reload）／U2 base-web（顯示/不可復原 + i18n）。原子整合姿態＝extend soft_delete/batch_soft_delete（D1）。

## Complexity Tracking

> 無 Constitution 違規需證成（9/9 PASS、零 migration、軌道內）。本表空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| （無） | — | — |
