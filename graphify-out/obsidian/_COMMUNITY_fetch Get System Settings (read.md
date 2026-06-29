---
type: community
cohesion: 1.00
members: 2
---

# fetch Get System Settings (read

**Cohesion:** 1.00 - tightly connected
**Members:** 2 nodes

## Members
- [[Api.SystemManage.SystemSetting DTO (KV setting)]] - code - base-web/src/typings/api/rev3-system-settings.d.ts
- [[fetchGetSystemSettings (read all system settings KV)]] - code - base-web/src/service/api/rev3-system-settings.ts

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/fetch_Get_System_Settings_read
SORT file.name ASC
```
