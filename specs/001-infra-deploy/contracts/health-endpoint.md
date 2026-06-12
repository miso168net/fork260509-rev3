# Contract: health-endpoint ＋ entrypoint dispatcher（001-infra-deploy）

## GET /health（rust-api）

| 項 | 值（凍結） |
|---|---|
| 方法／路徑 | `GET /health` |
| 回應 | HTTP 200、`Content-Type: text/plain`、body `ok` |
| envelope | **不走** `Res<T>` 信封——constitution §I.3 universal 例外明文（`/health` plain text） |
| bind | `0.0.0.0:31081`（容器內） |
| 對外可見性 | 直連 `:31081/health`（dev debug）＋經入口 `/api/health`（strip 轉發）皆可達；本端點無 auth |
| HEALTHCHECK 消費 | Dockerfile runtime stage：`curl -fsS http://127.0.0.1:31081/health`（10s/3s/5s/3——對齊 rev2 health-endpoint 契約 timing 不可變） |

## entrypoint dispatcher（runtime image）

```
entrypoint.sh {server|migration|cleanup-job}
  server       → exec /usr/local/bin/server          （CMD 預設）
  migration …  → exec /usr/local/bin/migration "$@"  （prod migrate: command ["migration","up"]）
  cleanup-job …→ exec /usr/local/bin/cleanup-job "$@"（本刀留 case 殼；binary 屬波 3）
  其他         → usage 訊息、exit 64
```

- dev image 不走 dispatcher（ENTRYPOINT＝cargo-watch）；dev migrate 以 compose 層 entrypoint override `cargo run --bin migration` ＋ `command: ["up"]`（不改 Dockerfile，rev2 FR-007 同款）。
