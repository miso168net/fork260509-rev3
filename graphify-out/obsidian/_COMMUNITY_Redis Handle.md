---
type: community
cohesion: 0.17
members: 15
---

# Redis Handle

**Cohesion:** 0.17 - loosely connected
**Members:** 15 nodes

## Members
- [[.connect()]] - code - rust-api/server/src/redis.rs
- [[.del()]] - code - rust-api/server/src/redis.rs
- [[.get()]] - code - rust-api/server/src/redis.rs
- [[.incr()]] - code - rust-api/server/src/redis.rs
- [[.is_locked()]] - code - rust-api/server/src/redis.rs
- [[.mark_locked()]] - code - rust-api/server/src/redis.rs
- [[.publish()]] - code - rust-api/server/src/redis.rs
- [[.revoked_at_of()]] - code - rust-api/server/src/redis.rs
- [[.set_ex()]] - code - rust-api/server/src/redis.rs
- [[.set_revoked()]] - code - rust-api/server/src/redis.rs
- [[.subscribe_pubsub()]] - code - rust-api/server/src/redis.rs
- [[.take_suppressed()]] - code - rust-api/server/src/redis.rs
- [[.ttl_secs()]] - code - rust-api/server/src/redis.rs
- [[RedisHandle]] - code - rust-api/server/src/redis.rs
- [[redis.rs]] - code - rust-api/server/src/redis.rs

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/Redis_Handle
SORT file.name ASC
```
