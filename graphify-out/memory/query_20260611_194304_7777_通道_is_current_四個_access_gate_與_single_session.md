---
type: "query"
date: "2026-06-11T19:43:04.939880+00:00"
question: "7777 通道:is_current 四個 access gate 與 single-session 狀態機(§4.3)的完整鏈路"
contributor: "graphify"
source_nodes: ["fetchGetUserInfo()", "fetchGetUserRoutes()", "fetchIsRouteExist()", "useAuthStore", "request"]
---

# Q: 7777 通道:is_current 四個 access gate 與 single-session 狀態機(§4.3)的完整鏈路

## Answer

Expanded via vocab: [user, info, routes, exist, guard, modal, session, current, store, settings, single]。寫入端(login,rev2 handler/auth.rs L127-161):create_chain_head→resolve_policy(session_policy{inherit,on,off}×runtime session_mode 熱切換)=on 時 revoke_other_chains→set_pointer 永遠執行(寫 sys_user.current_session_id 持久真相+Redis sess:{uid} 熱快取,persist-then-cache)。讀取端 5 個 is_current 呼叫點(rev2 as-built,與設計書 §4.3 完全吻合):①auth/enforce.rs:73 enforce_mw(所有受保護業務路由)②handler/auth.rs:267 getUserInfo ③handler/route.rs:50 getUserRoutes ④handler/route.rs:139 isRouteExist=4 access gate;⑤handler/auth.rs:345 refresh rotate 前 pointer-first=第5掛點。is_current(auth/session.rs:156):Redis GET→miss 則 DB 讀+rehydrate→兩層皆掛 fail-OPEN(不誤踢);policy off→恆 true(多裝置)。比對失敗→BizCode::ModalLogout7777('账号在他处登录',envelope.rs)。前端接手:三 gate 呼叫者=store/modules/auth/index.ts:149(fetchGetUserInfo)/store/modules/route/index.ts:212(fetchGetUserRoutes)/:306(fetchIsRouteExist);7777 入 MODAL_LOGOUT_CODES→service/request/index.ts:61-84 modal+beforeunload 防刷新逃逸→確認後 logoutAndCleanup→resetStore。雙通道互補(belt-and-suspenders):被踢 session 若僥倖過 gate(fail-open 窗口),其 refresh 仍撞被 revoke 的 rotation_chain→Reuse→8888 乾淨登出。

## Source Nodes

- fetchGetUserInfo()
- fetchGetUserRoutes()
- fetchIsRouteExist()
- useAuthStore
- request