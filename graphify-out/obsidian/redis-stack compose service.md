---
source_file: "docker-compose.yml"
type: "code"
community: "App Bootstrap & Service Stack"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/App_Bootstrap__Service_Stack
---

# redis-stack compose service

## Connections
- [[redis_stack_data volume]] - `depends_on` [EXTRACTED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/App_Bootstrap__Service_Stack