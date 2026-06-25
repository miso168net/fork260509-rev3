---
source_file: "docker-compose.yml"
type: "code"
community: "Community 154"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_154
---

# loki compose service (obs-min log storage, profiles:[obs], 72h retention)

## Connections
- [[alloy compose service (obs-min docker-SD log collector, profilesobs, userroot)]] - `depends_on` [EXTRACTED]
- [[grafana compose service (obs UI, profilesobs,metrics, $__file admin pw)]] - `depends_on` [EXTRACTED]
- [[loki_data volume]] - `references` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_154