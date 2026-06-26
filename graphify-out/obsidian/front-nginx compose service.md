---
source_file: "docker-compose.yml"
type: "code"
community: "User Management Views"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/User_Management_Views
---

# front-nginx compose service

## Connections
- [[base-web compose service]] - `depends_on` [EXTRACTED]
- [[front_nginx_certs volume]] - `depends_on` [INFERRED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/User_Management_Views