---
source_file: "docker-compose.yml"
type: "code"
community: "manage/user/index.vue (user list page)"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/manage/user/indexvue_user_list_page
---

# postgres compose service

## Connections
- [[cleanup-job compose service (expired token sidecar)]] - `depends_on` [EXTRACTED]
- [[migrate compose service (one-shot schema gate)]] - `depends_on` [EXTRACTED]
- [[postgres_data volume]] - `depends_on` [EXTRACTED]
- [[rust-api compose service]] - `depends_on` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/manage/user/indexvue_user_list_page