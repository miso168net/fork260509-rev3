---
type: community
cohesion: 0.18
members: 20
---

# Auth Store & Tokens

**Cohesion:** 0.18 - loosely connected
**Members:** 20 nodes

## Members
- [[auth.ts]] - code - base-web/src/hooks/business/auth.ts
- [[clearAuthStorage()]] - code - base-web/src/store/modules/auth/shared.ts
- [[getAuthorization()]] - code - base-web/src/service/request/shared.ts
- [[getAuthorization() (2)]] - code - base-web/src/service-alova/request/shared.ts
- [[getToken()]] - code - base-web/src/store/modules/auth/shared.ts
- [[handleExpiredRequest()]] - code - base-web/src/service/request/shared.ts
- [[handleRefreshToken()]] - code - base-web/src/service/request/shared.ts
- [[handleRefreshToken() (2)]] - code - base-web/src/service-alova/request/shared.ts
- [[index.ts (35)]] - code - base-web/src/store/modules/auth/index.ts
- [[localStg]] - code - base-web/src/utils/storage.ts
- [[localforage (3)]] - code - base-web/src/utils/storage.ts
- [[sessionStg]] - code - base-web/src/utils/storage.ts
- [[shared.ts (4)]] - code - base-web/src/service/request/shared.ts
- [[shared.ts (5)]] - code - base-web/src/service-alova/request/shared.ts
- [[shared.ts (6)]] - code - base-web/src/store/modules/auth/shared.ts
- [[showErrorMsg()]] - code - base-web/src/service/request/shared.ts
- [[showErrorMsg() (2)]] - code - base-web/src/service-alova/request/shared.ts
- [[storage.ts (2)]] - code - base-web/src/utils/storage.ts
- [[useAuth()]] - code - base-web/src/hooks/business/auth.ts
- [[useAuthStore]] - code - base-web/src/store/modules/auth/index.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Auth_Store__Tokens
SORT file.name ASC
```

## Connections to other communities
- 9 edges to [[_COMMUNITY_Service Request Layer]]
- 6 edges to [[_COMMUNITY_index.ts]]
- 6 edges to [[_COMMUNITY_route.ts]]
- 6 edges to [[_COMMUNITY_Theme Token Engine]]
- 5 edges to [[_COMMUNITY_Router Guard Flow]]
- 5 edges to [[_COMMUNITY_User & Captcha APIs]]
- 3 edges to [[_COMMUNITY_index.ts]]
- 3 edges to [[_COMMUNITY_Tab Management Utils]]
- 2 edges to [[_COMMUNITY_loading.ts]]
- 2 edges to [[_COMMUNITY_SVG Icons & Route Utils]]
- 1 edge to [[_COMMUNITY_Composable Hooks]]

## Top bridge nodes
- [[index.ts (35)]] - degree 24, connects to 9 communities
- [[storage.ts (2)]] - degree 19, connects to 8 communities
- [[localStg]] - degree 14, connects to 7 communities
- [[useAuthStore]] - degree 12, connects to 5 communities
- [[shared.ts (4)]] - degree 11, connects to 1 community