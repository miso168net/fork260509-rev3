---
source_file: "docker-compose.yml"
type: "code"
community: "manage user index.vue (user list"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/manage_user_indexvue_user_list
---

# front-nginx compose service

## Connections
- [[base-web compose service]] - `depends_on` [EXTRACTED]
- [[front_nginx_certs volume]] - `depends_on` [INFERRED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/manage_user_indexvue_user_list