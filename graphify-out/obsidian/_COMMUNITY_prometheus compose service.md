---
type: community
cohesion: 1.00
members: 2
---

# prometheus compose service

**Cohesion:** 1.00 - tightly connected
**Members:** 2 nodes

## Members
- [[prometheus compose service (metrics scrape+storage, profilesmetrics, 15d retention)]] - code - docker-compose.yml
- [[prometheus_data volume]] - concept - docker-compose.yml

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/prometheus_compose_service
SORT file.name ASC
```
