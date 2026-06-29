---
type: community
cohesion: 0.70
members: 5
---

# Endpoint Auth Modal (role x

**Cohesion:** 0.70 - tightly connected
**Members:** 5 nodes

## Members
- [[Api.SystemManage.Endpoint DTO (path + method)]] - code - base-web/src/typings/api/rev3-system-manage.d.ts
- [[EndpointAuthModal (role x API endpoint authorization tree)]] - code - base-web/src/views/manage/role/modules/endpoint-auth-modal.vue
- [[fetchGetAllEndpoints()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchGetRoleEndpoints()]] - code - base-web/src/service/api/rev3-system-manage.ts
- [[fetchUpdateRoleEndpoints()]] - code - base-web/src/service/api/rev3-system-manage.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Endpoint_Auth_Modal_role_x
SORT file.name ASC
```

## Connections to other communities
- 3 edges to [[_COMMUNITY_rev3-system-manage.ts]]
- 1 edge to [[_COMMUNITY_Button Auth Modal (role x]]
- 1 edge to [[_COMMUNITY_Role Operate Drawer (role add]]

## Top bridge nodes
- [[fetchUpdateRoleEndpoints()]] - degree 4, connects to 2 communities
- [[EndpointAuthModal (role x API endpoint authorization tree)]] - degree 5, connects to 1 community
- [[fetchGetAllEndpoints()]] - degree 3, connects to 1 community
- [[fetchGetRoleEndpoints()]] - degree 3, connects to 1 community