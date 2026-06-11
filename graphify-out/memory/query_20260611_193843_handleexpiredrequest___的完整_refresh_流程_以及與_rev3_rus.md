---
type: "query"
date: "2026-06-11T19:38:43.606471+00:00"
question: "handleExpiredRequest() 的完整 refresh 流程,以及與 rev3 rust-api rotation 的對接面"
contributor: "graphify"
source_nodes: ["handleExpiredRequest()", "handleRefreshToken()", "fetchRefreshToken()", "request", "useAuthStore"]
---

# Q: handleExpiredRequest() 的完整 refresh 流程,以及與 rev3 rust-api rotation 的對接面

## Answer

Expanded via vocab: [expired, refresh, token, retry, request, backend, code, fail, axios, auth, fetch, logout]; DFS 追蹤。完整鏈:onRequest 掛 Bearer(index.ts L28-33)→isBackendSuccess 比對 code==='0000'(L34-38)→onBackendFail 三段分流(L39-99):8888/8889(LOGOUT_CODES)靜默 resetStore;7777/7778(MODAL_LOGOUT_CODES)modal+beforeunload 防刷新;9999/9998/3333(EXPIRED_TOKEN_CODES)→handleExpiredRequest(shared.ts L30-42,single-flight:state.refreshTokenPromise 共享、1s 後清)→handleRefreshToken(L14-28):localStg 讀 refreshToken→POST /auth/refreshToken(api/auth.ts L30,回 {token,refreshToken})→成功雙寫 localStg、失敗 resetStore→成功後重掛新 Authorization 並 instance.request(response.config) 原樣重放(index.ts L90-95);onError 對 expired/modal 碼靜音(L101-126)。死迴圈防護雙保險:前端註解(L87)+rev3 設計書 §4.1「handler 絕不回 3333/9999/9998」。與 rust-api 對接面(INTEGRATION-DESIGN-rev3.md):§4.1 rotation 狀態機(sys_token:token_hash UNIQUE/rotation_chain per-login uuid/active→used 冪等/used 超 30s GRACE 或 used_at NULL→Reuse 撤整鏈→8888);跨 tab 競態由後端 30s grace 的 Benign 分支吸收(前端 single-flight 只擋同 tab、1s 即清);apifoxToken header(index.ts L17)為 mock 平台殘留、§11.4 拍板 rust-api 忽略 unknown header、base-web 不動。

## Source Nodes

- handleExpiredRequest()
- handleRefreshToken()
- fetchRefreshToken()
- request
- useAuthStore