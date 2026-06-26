---
source_file: "rust-api/server/src/model/facade/sys_token.rs"
type: "code"
community: "Session & Token Rotation"
location: "L151"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Session__Token_Rotation
---

# toctou_revoked_chain_locks_to_reuse_no_rebake()

## Connections
- [[decide_rotation()]] - `calls` [INFERRED]
- [[find_by_hash()]] - `calls` [EXTRACTED]
- [[find_by_hash_for_update()]] - `calls` [EXTRACTED]
- [[insert_token()]] - `calls` [EXTRACTED]
- [[revoke_chain()]] - `calls` [EXTRACTED]
- [[sys_token.rs_1]] - `contains` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Session__Token_Rotation