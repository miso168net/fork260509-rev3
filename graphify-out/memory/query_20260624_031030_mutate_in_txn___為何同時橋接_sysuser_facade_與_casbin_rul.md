---
type: "query"
date: "2026-06-24T03:10:30.694442+00:00"
question: "mutate_in_txn() 為何同時橋接 SysUser Facade 與 Casbin Rule Facade？"
contributor: "graphify"
source_nodes: ["mutate_in_txn()", "set_role_dimension()", "set_role_endpoints()", "soft_delete()", "create()", "update()", "replace_roles_in_txn()", "reload_and_publish()", "load_policy()"]
---

# Q: mutate_in_txn() 為何同時橋接 SysUser Facade 與 Casbin Rule Facade？

## Answer

Expanded from vocab tokens [mutate,txn,casbin,facade,user,role,atomic,rule,policy,write,reload,dimension]. mutate_in_txn (model/audit.rs:84-97) 是 L4 審計核心唯一的原子寫 primitive（feature 005 引入）：conn.begin → 業務寫閉包 → 同 txn write_in_txn 寫 op-log → commit（任何 Err 前 rollback）。它是所有寫 facade 共用的 chokepoint——sys_user create/update/soft_delete、sys_casbin_rule set_role_dimension/set_role_endpoints、sys_role、sys_menu、sys_user_role、sys_casbin_policy_archive restore、system_settings update_by_key 全部 calls 它。因此 AST call graph 裡 mutate_in_txn(community 40, degree 18) 的 incoming calls 邊同時來自 SysUser facade 社群與 Casbin rule facade 社群、夾在中間成最高 betweenness 橋。兩 facade 彼此無直接相依，唯一結構連結就是共用此原子 seam。並非單一 mutate_in_txn 同時寫 user 與 casbin（各域獨立呼叫；但一次 user 寫的 mutate_in_txn 會原子涵蓋 user+sys_user_role+op-log）。casbin DB-first：直寫 entity::casbin_rule(delete_many+ActiveModel.insert) 於 mutate_in_txn 內、commit 後 reload_and_publish 跑 load_policy() 全量重載、刻意繞過 MgmtApi(add_policies/remove_filtered_policy 僅存於 adapter+test)、守 constitution §I.7 §4.2 DB-first(rev2-034 anti-pattern)。修正：sys_user 無 batch_soft_delete(只在 sys_role/sys_menu)、user 批刪是 handler 迴圈單列 soft_delete。

## Source Nodes

- mutate_in_txn()
- set_role_dimension()
- set_role_endpoints()
- soft_delete()
- create()
- update()
- replace_roles_in_txn()
- reload_and_publish()
- load_policy()