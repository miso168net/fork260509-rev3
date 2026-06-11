---
type: "query"
date: "2026-06-11T19:48:40.596806+00:00"
question: "§4.2 policy governance 狀態機:casbin_rule⇄archive、PolicyMutated 條件化 reload 的完整鏈路"
contributor: "graphify"
source_nodes: ["request", "fetchGetUserRoutes()"]
---

# Q: §4.2 policy governance 狀態機:casbin_rule⇄archive、PolicyMutated 條件化 reload 的完整鏈路

## Answer

狀態:policy 列 live in casbin_rule ⇄ archived in sys_casbin_policy_archive。transitions(rev2 as-built):grant=INSERT live(帶 protected 治理保護位,facade/sys_casbin_rule.rs L43-64);revoke=protected 守衛先行(L119-121:protected→RevokeOutcome::Rejected 列原封不動)、否則快照 INSERT archive+DELETE live 同 txn;restore=反向 move(L156 RestoreOutcome;L169 回插 live 時 protected=false——protected 列從不入 archive;NoOp=policy 已 live→0000 視為成功、archive 列仍消費、無審計;假 archiveId→2222 無審計);set_role_dimension(role,dim,desired)=diff 後批次 revoke+grant 單 txn,三維度入口=auth/{menu,button,endpoint}_auth.rs。reload 條件化:policy_governance.rs L81 mutate_and_reload 泛型 wrapper——commit 後僅 result.mutated() 為真才 reload_and_publish(L97-98,035 US2;Rejected/NoOp/NotFound 跳過);reload_and_publish(L109)=寫鎖內全量 load_policy(enforcer=DB 讀投影)+PUBLISH casbin:policy:invalidate(policy_watcher.rs 訂閱、跨實例收斂);PolicyGovernanceError::Reload=commit 成功但 load_policy 失敗(DB 超前 in-memory)。端點(main.rs):/systemManage/{getRoleMenu,updateRoleMenu(L334,344),getRoleButton,updateRoleButton(L374,384),getArchivedPolicies,restorePolicy}(rev2 034)。前端 wire:rev2 base-web rev2-system-manage.ts:179 fetchRestorePolicy;rev3 vanilla 對應落點=views/manage/role/modules/{menu,button}-auth-modal.vue(MODAL-WIRING 軌道)。三機閉環:治理寫→reload→enforce_mw 用新 policy,而 enforce_mw 同時是 7777 通道 gate ①;對外碼 Applied→0000/Rejected→2222(business 碼、非 auth 碼)。

## Source Nodes

- request
- fetchGetUserRoutes()