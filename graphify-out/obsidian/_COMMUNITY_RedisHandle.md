---
type: community
cohesion: 0.24
members: 10
---

# RedisHandle

**Cohesion:** 0.24 - loosely connected
**Members:** 10 nodes

## Members
- [[.connect()]] - code - rust-api/server/src/redis.rs
- [[.del()]] - code - rust-api/server/src/redis.rs
- [[.get()]] - code - rust-api/server/src/redis.rs
- [[.publish()]] - code - rust-api/server/src/redis.rs
- [[.revoked_at_of()]] - code - rust-api/server/src/redis.rs
- [[.set_ex()]] - code - rust-api/server/src/redis.rs
- [[.set_revoked()]] - code - rust-api/server/src/redis.rs
- [[.subscribe_pubsub()]] - code - rust-api/server/src/redis.rs
- [[RedisHandle]] - code - rust-api/server/src/redis.rs
- [[redis.rs]] - code - rust-api/server/src/redis.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/RedisHandle
SORT file.name ASC
```
