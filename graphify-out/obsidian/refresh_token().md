---
source_file: "rust-api/server/src/handler/auth.rs"
type: "code"
community: "Auth & Casbin Enforce"
location: "L357"
tags:
  - graphify/code
  - graphify/EXTRACTED
  - community/Auth__Casbin_Enforce
---

# refresh_token()

## Connections
- [[auth.rs]] - `contains` [EXTRACTED]
- [[denylist_gate()]] - `calls` [INFERRED]
- [[is_current()]] - `calls` [INFERRED]
- [[revoke_chain_and_logout()]] - `calls` [EXTRACTED]
- [[rotate_locked_or_revoke()]] - `calls` [EXTRACTED]

#graphify/code #graphify/EXTRACTED #community/Auth__Casbin_Enforce