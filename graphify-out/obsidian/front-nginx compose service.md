---
source_file: "docker-compose.yml"
type: "code"
community: "App Bootstrap & Service Stack"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/App_Bootstrap__Service_Stack
---

# front-nginx compose service

## Connections
- [[base-web compose service]] - `depends_on` [EXTRACTED]
- [[front_nginx_certs volume]] - `depends_on` [INFERRED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/App_Bootstrap__Service_Stack