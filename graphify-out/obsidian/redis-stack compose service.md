---
source_file: "docker-compose.yml"
type: "code"
community: "User Management Views"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/User_Management_Views
---

# redis-stack compose service

## Connections
- [[redis_stack_data volume]] - `depends_on` [EXTRACTED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/User_Management_Views