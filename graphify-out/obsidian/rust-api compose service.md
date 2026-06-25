---
source_file: "docker-compose.yml"
type: "code"
community: "Community 5"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Community_5
---

# rust-api compose service

## Connections
- [[front-nginx compose service]] - `depends_on` [EXTRACTED]
- [[migrate compose service (one-shot schema gate)]] - `depends_on` [EXTRACTED]
- [[postgres compose service]] - `depends_on` [EXTRACTED]
- [[redis-stack compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Community_5