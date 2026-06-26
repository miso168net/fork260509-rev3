---
type: community
cohesion: 0.29
members: 7
---

# grafana compose service

**Cohesion:** 0.29 - loosely connected
**Members:** 7 nodes

## Members
- [[alloy compose service (obs-min docker-SD log collector, profilesobs, userroot)]] - code - docker-compose.yml
- [[alloy_data volume]] - concept - docker-compose.yml
- [[grafana compose service (obs UI, profilesobs,metrics, $__file admin pw)]] - code - docker-compose.yml
- [[grafana_admin_password secret]] - concept - docker-compose.yml
- [[grafana_data volume]] - concept - docker-compose.yml
- [[loki compose service (obs-min log storage, profilesobs, 72h retention)]] - code - docker-compose.yml
- [[loki_data volume]] - concept - docker-compose.yml

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/grafana_compose_service
SORT file.name ASC
```
