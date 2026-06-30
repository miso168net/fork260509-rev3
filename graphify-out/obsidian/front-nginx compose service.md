---
source_file: "docker-compose.yml"
type: "code"
community: "manage/user/index.vue (user list page)"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/manage/user/indexvue_user_list_page
---

# front-nginx compose service

## Connections
- [[base-web compose service]] - `depends_on` [EXTRACTED]
- [[front_nginx_certs volume]] - `depends_on` [INFERRED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/manage/user/indexvue_user_list_page