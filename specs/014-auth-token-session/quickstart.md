# Quickstart 驗證指南：Auth/Token/Session 合刀

> 端到端驗證本刀可運作。精確命令見 [contracts/verification-commands.md](./contracts/verification-commands.md)；schema/型見 [data-model.md](./data-model.md)；接地/決策見 [research.md](./research.md)。

## 前置
- dev stack 起：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`
- 預設帳號 `Super/Admin/User`，密碼 `123456`。
- **本刀新增 Redis 依賴**：rust-api 連 redis-stack（`APP_REDIS_URL_FILE` secret 既存）；首次需確認 rust-api boot log 連 Redis 成功（或 best-effort 降級 warn）。

## 1. token rotation（US1、SC-001/002）
login 取 `token`+`refreshToken` → 以 refresh 打 `/auth/refreshToken`：

| 情境 | 動作 | 期望 |
|---|---|---|
| 正常輪替 | 以有效 refresh 換 | 新 pair；舊列 `status='used'` |
| 雙擊容忍 | 同 refresh grace(30s) 內再送 | 仍發新對、不撤（Benign）|
| 盜用重放 | 對已輪替/已撤/隔 grace 的 refresh 重送 | code `8888`、整 `rotation_chain` `status='revoked'` |

psql 驗鏈狀態見 C-V-3。

## 2. single-session（US2、SC-003）
008 設定頁切 `single_session_default`（on/off）；009 編輯 user 設 `session_policy`（inherit/on/off）：
- effective on → B 裝置登入後 A 下個請求 `7777`（modal 登出）；effective off → 多裝置並存。
- per-user `session_policy='on'`（全域 off）→ 該 user 仍單一登入（覆寫蓋全域）。

## 3. 硬即時撤銷（US3、SC-004）
持有效 access token 的 user → `updateUser(status=2)` 或 `deleteUser` → 該 token 下個請求立即 `8888`（不分 policy、不等過期）；`redis-cli GET revoked:user:{uid}` 存在。re-enable→新 login 正常。

## 4. ★ 多實例驗證（US4、SC-005/006）
```bash
$DC --profile multi up -d rust-api-2 --wait   # :31082、共享 DB+Redis
```
A 切 `single_session_default`→B 收斂；A login→B 踢；kill Redis pubsub→watcher 重訂閱。完了 `--profile multi down rust-api-2`。詳 C-V-6。

## 5. cleanup-job（US5、SC-007）
`cargo run -p cleanup-job`（dry-run 只 count）→ `-- --execute`（刪過期）→ 再跑冪等。

## 6. 零回歸（SC-009/010）
`/health` 200；006 login/getUserInfo/enforce・009 CRUD・008 設定・013 audit 不破；**無新 migration**（up→down→up 仍綠）；`pnpm typecheck` 綠；**prod target image build 過**（新 cleanup-job crate + Redis crate 編入、C-V-9）。

> 完整 acceptance（含 §I.7 §4.1/§4.3 invariants 逐條驗、CDP 兩通道、prod build）走 contracts 的 C-V-0~10。
