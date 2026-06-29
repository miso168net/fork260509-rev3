---
source_file: "docker-compose.yml"
type: "code"
community: "grafana compose service (obs UI,"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/grafana_compose_service_obs_UI
---

# alloy compose service (obs-min docker-SD log collector, profiles:[obs], user:root)

## Connections
- [[alloy_data volume]] - `references` [EXTRACTED]
- [[loki compose service (obs-min log storage, profilesobs, 72h retention)]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/grafana_compose_service_obs_UI