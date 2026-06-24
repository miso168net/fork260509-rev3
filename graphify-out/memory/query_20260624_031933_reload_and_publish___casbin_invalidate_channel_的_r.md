---
type: "query"
date: "2026-06-24T03:19:33.708678+00:00"
question: "reload_and_publish → CASBIN_INVALIDATE_CHANNEL 的 redis pub/sub 失效廣播如何達成多實例 enforcer 一致性？"
contributor: "graphify"
source_nodes: ["reload_and_publish()", "spawn_policy_watcher()", "subscribe_pubsub()", "load_policy()", "publish()", "spawn_settings_watcher()"]
---

# Q: reload_and_publish → CASBIN_INVALIDATE_CHANNEL 的 redis pub/sub 失效廣播如何達成多實例 enforcer 一致性？

## Answer

圖盲點：publisher(reload_and_publish, community 240) 與 subscriber(spawn_policy_watcher, community 211) 分屬不同社群、無 call 邊；CASBIN_INVALIDATE_CHANNEL 非節點(AST 不抽 const)。耦合是執行期 redis channel 'casbin:policy:invalidate'(main.rs:41)、非 call edge、圖看不到、須讀碼。機制：寫端 casbin DB-first 在 mutate_in_txn commit 後→reload_and_publish(system_manage.rs:837-850)①本地 enforcer.write().load_policy() 失敗→Internal 5000(寫入實例不可降級)②best-effort publish channel 空字串(fail-OPEN)。每實例 boot 起 spawn_policy_watcher(main.rs:677-728) 訂專用 pub-sub 連線(redis.rs:122)、on_message 每則→load_policy reload(跨副本收斂)、redis None→不啟(單副本 fallback)、reconnect 先補一次 catch-up reload(main.rs:700 補 backoff 窗錯過的失效)、斷線→指數 backoff 1→30s 重訂閱(FR-008 不脫鉤)。順序保證:commit 早於 publish(system_manage.rs:1305→1308)、subscriber reload 必見已提交列。殘留 gap(誠實):①subscriber 某則 load_policy 失敗→fail-OPEN warn、無週期重試、stale 至下則訊息或 reconnect catch-up②寫端自身 load_policy 失敗→? 在 publish 前短路(845 早於 847)→DB 已 commit+寫端 in-memory stale+無 publish 發出+回 5000、不靠 self-receipt 自癒、只下次成功 mutate 或 reconnect 才收斂。權威:constitution §I.7 §4.2(:111 reload=全量 load_policy+PUBLISH)、§V.3(:239 fail-OPEN 方向反轉=MAJOR 修憲)、DECISIONS §2:122 015④跨副本 pub-sub+C-V-5 2-instance live(CLIENT KILL TYPE pubsub→~1s 重訂閱仍收斂)。同模式復用於 settings:invalidate(spawn_settings_watcher 重載 AtomicBool)。

## Source Nodes

- reload_and_publish()
- spawn_policy_watcher()
- subscribe_pubsub()
- load_policy()
- publish()
- spawn_settings_watcher()