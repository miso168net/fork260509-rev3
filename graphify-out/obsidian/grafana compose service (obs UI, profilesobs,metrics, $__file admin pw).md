---
source_file: "docker-compose.yml"
type: "code"
community: "grafana compose service (obs UI,"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/grafana_compose_service_obs_UI
---

# grafana compose service (obs UI, profiles:[obs,metrics], $__file admin pw)

## Connections
- [[grafana_admin_password secret]] - `references` [EXTRACTED]
- [[grafana_data volume]] - `references` [EXTRACTED]
- [[loki compose service (obs-min log storage, profilesobs, 72h retention)]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/grafana_compose_service_obs_UI