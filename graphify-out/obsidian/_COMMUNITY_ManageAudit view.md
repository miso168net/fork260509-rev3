---
type: community
cohesion: 1.00
members: 2
---

# ManageAudit view

**Cohesion:** 1.00 - tightly connected
**Members:** 2 nodes

## Members
- [[ManageAudit view (super-only audit center, 3-tab page)]] - code - base-web/src/views/manage/audit/index.vue
- [[Rationale NCard displayblock breaks flex-height chain, table body collapses to 0px inside NTabs]] - rationale - base-web/src/views/manage/audit/index.vue

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/ManageAudit_view
SORT file.name ASC
```
