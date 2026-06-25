---
source_file: "docker-compose.yml"
type: "code"
community: "Community 154"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_154
---

# alloy compose service (obs-min docker-SD log collector, profiles:[obs], user:root)

## Connections
- [[alloy_data volume]] - `references` [EXTRACTED]
- [[loki compose service (obs-min log storage, profilesobs, 72h retention)]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_154