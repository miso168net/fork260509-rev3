---
type: "query"
date: "2026-06-24T03:44:13.091399+00:00"
question: "014 U2 lock-then-redecide TOCTOU 如何閉合 refresh-token rotation 的 reuse race (SC-002)？"
contributor: "graphify"
source_nodes: ["rotate_locked_or_revoke()", "find_by_hash_for_update()", "decide_rotation()", "issue_rotated_pair()", "revoke_chain()", "revoke_all_user_chains()", "denylist_gate()", "mark_used()"]
---

# Q: 014 U2 lock-then-redecide TOCTOU 如何閉合 refresh-token rotation 的 reuse race (SC-002)？

## Answer

decide_rotation(session.rs:73-95) 純函式四態(active->Rotate/used-grace<30s->Benign/used超grace·NULL·revoked·未知->Reuse/無->NotFound)。refresh_token 非 txn pre-read 當快篩→Rotate|Benign 進 rotate_locked_or_revoke(auth.rs:384)：begin txn→find_by_hash_for_update(.lock_exclusive()=FOR UPDATE)→對鎖住的列重跑 decide_rotation→鎖後 Rotate→mark_used+issue_rotated_pair(新列沿用同 rotation_chain auth.rs:272)+commit；鎖後翻 Reuse→rollback+revoke_chain+8888 絕不重鑄。冪等 filter(mark_used WHERE status=active)只防 rotate-vs-rotate(UPDATE 舊列)、不防 mint-vs-revoke(mint 是獨立 INSERT、舊列 status 管不到)；故須鎖後重判把權威判決搬到鎖住的列。對抗驗證細修(D nuanced)：ordering(b) revoke 先 commit→鎖讀見 revoked→Reuse 滴水不漏(live test toctou_revoked_chain 證 active count==0)。ordering(a) mint 先 commit：sibling-reuse 路徑 B 的 revoke 在重判後另開 fresh txn(snapshot 後於 A commit)→chain-wide UPDATE 掃到新列、安全；但 postgres 預設 READ COMMITTED 下、若併發 U4 revoke_all_user_chains 的 UPDATE snapshot 早於 A 的 INSERT→該 statement 掃不到新列→DB 層短暫殘留 active 孤兒。此殘窗非靠 chain-wide UPDATE 閉合、而靠 defense-in-depth：U4 orchestrator(revoke_user_sessions, enforce.rs:317) 先寫 Redis denylist(set_revoked)再撤 DB；denylist_gate(enforce.rs:290) iat<=revoked_at 同秒 fail-secure→A 剛鑄的 token 下次 refresh/access 即被殺。grace tradeoff:used-grace內 Benign 重鑄、U4 revoke_all_user_chains 撤 status<>revoked(含 used、異於 login revoke_other_chains 只撤 active)以閉 SC-004。channel:refresh 絕不回 3333(防 auto-refresh loop)、reuse/invalid->8888、單一 session 被頂->7777。權威 constitution §I.7 §4.1/§4.4。圖盲點:find_by_hash_for_update 在圖上只被測試呼叫、缺 production rotate_locked_or_revoke 邊(全路徑 qualified call 漏抓)。

## Source Nodes

- rotate_locked_or_revoke()
- find_by_hash_for_update()
- decide_rotation()
- issue_rotated_pair()
- revoke_chain()
- revoke_all_user_chains()
- denylist_gate()
- mark_used()