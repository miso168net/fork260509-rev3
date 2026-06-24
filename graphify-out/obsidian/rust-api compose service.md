---
source_file: "docker-compose.yml"
type: "code"
community: "App Bootstrap & Service Stack"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/App_Bootstrap__Service_Stack
---

# rust-api compose service

## Connections
- [[front-nginx compose service]] - `depends_on` [EXTRACTED]
- [[migrate compose service (one-shot schema gate)]] - `depends_on` [EXTRACTED]
- [[postgres compose service]] - `depends_on` [EXTRACTED]
- [[redis-stack compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/App_Bootstrap__Service_Stack