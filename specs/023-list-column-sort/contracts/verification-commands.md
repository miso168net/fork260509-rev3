# Verification Commands（C-V）：列表欄位排序

curl≠modal 紀律：curl 驗 wire、CDP 驗實渲染。rust 全程容器內（host 無 toolchain）、serial。
dev 容器內跑：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。

> 注意（容器內假綠三坑）：改 `.rs` 後先 force-touch（`find server/src -name '*.rs' -exec touch {} +`）；跑整支 test binary 用 `--test <name>`（bare filter 0 命中假綠）；live 測 in-crate `#[ignore]` + env-gate。

## C-V-0 · build + 零回歸（gate）

```
# rust：force-touch 後 build + 全測（serial）
docker compose ... exec -T rust-api sh -c 'cd /app && find server/src migration/src -name "*.rs" -exec touch {} + && cargo build -p server -p migration && cargo test -p server'
# base-web：typecheck（pre-commit hook 在 alpine 壞、自驗用 typecheck）
docker compose ... exec -T base-web pnpm typecheck
```
期望：build 綠、既有測試零回歸、typecheck 綠。

## C-V-1 · 純函式單元（rust）

```
docker compose ... exec -T rust-api sh -c 'cd /app && cargo test -p server --lib -- sort'
```
涵蓋：`parse_sort_spec`（空→[]／非法方向→Err／重複欄→Err／正常多 token 有序）＋每個 `resolve_<entity>_sort`（白名單命中映正確 Column／未白名單欄→Err）。

## C-V-2 · 單欄排序（curl，整資料集）

```
# 取 token（Super）
TOKEN=$(curl -fsS localhost:31081/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | jq -r .data.token)
# userName 升冪：第一列應為全表 userName 最小
curl -fsS "localhost:31081/systemManage/getUserList?current=1&size=10&sort=userName:asc" -H "Authorization: Bearer $TOKEN" | jq '.data.records[0].userName'
```
期望：回 200、`records` 依 userName 升冪、第一列為整資料集（非僅前頁）極值（與 psql 全表 min 比對）。

## C-V-3 · 多欄排序（curl，點擊序＝優先序）

```
curl -fsS "localhost:31081/systemManage/getUserList?sort=status:asc,userName:desc" -H "Authorization: Bearer $TOKEN" | jq '.data.records[] | {status,userName}'
```
期望：先 status 升、同 status 內 userName 降。

## C-V-4 · 空 sort → 預設排序（逐列等同現況）

```
curl -fsS "localhost:31081/systemManage/getUserList?sort=" -H "Authorization: Bearer $TOKEN" | jq '.data.records[].id'   # 應 id desc（現況）
```
期望：與未帶 sort 完全一致（user=id desc）。對每端點各驗一次（保留各自預設）。

## C-V-5 · 非法排序 → 2222（curl 帶空/惡意 param）

```
curl -fsS "localhost:31081/systemManage/getUserList?sort=password:asc" -H "Authorization: Bearer $TOKEN" | jq '.code'   # 未白名單欄
curl -fsS "localhost:31081/systemManage/getUserList?sort=userName:sideways" -H "Authorization: Bearer $TOKEN" | jq '.code'  # 非法方向
curl -fsS "localhost:31081/systemManage/getUserList?sort=userName:asc,userName:desc" -H "Authorization: Bearer $TOKEN" | jq '.code'  # 重複欄
```
期望：三者皆 `code=="2222"`、wire `msg=="biz.common.invalidSort"`、HTTP 200、無錯排資料、無 5000。
**CDP（analyze F2）**：瀏覽器主動觸發非法排序（或直接渲染該 wire error），驗 toast 顯**在地化文字**（譯自 `backend.biz.common.invalidSort`）、**非 raw key**（restart base-web 後驗）—— curl 只驗 wire msg、不抓前端鍵錯位。

## C-V-6 · 匯出反映排序（curl，僅審計頁）

```
curl -fsS "localhost:31081/systemManage/getOperationLogList?export=true&sort=operation:asc" -H "Authorization: Bearer $TOKEN" | jq -r '.data.csv' | head -3
```
期望：CSV 內容列序依 `sort`（operation 升冪）。user/role/ip-rule 無匯出、不驗。

## C-V-7 · CDP browser smoke（curl≠modal，實渲染）

前置：**`restart base-web`**（避 vite stale-locale 使 `common.clearSort` 顯 raw key）。CDP 注入 Super token、navigate `/manage/user`。
斷言：
1. 點「使用者名稱」欄頭一次 → ▼降（**naive-ui 原生第一下反序**）、list 重抓、第一列變。
2. 再點 → ▲升；第三點 → 取消（指示消失、回預設）。
3. 多欄：點 A 再點 B → A 主、B 次（驗 DOM 列序）。
4. `#suffix`「清除排序」鈕：label 文字非 raw key（`PAGE_HAS_RAWKEY:false`、斷言顯「清除排序」）；按下 → 全清、回預設。
5. **持久化**：排序後 navigate 離開再回 `/manage/user` → 排序與箭頭還原。
6. 至少再抽一個審計頁（access_log）驗多欄 + 清除。
7. **FR-006/analyze F5**：在非第 1 頁時點欄頭 → pagination 跳回第 1 頁。
8. **FR-015/analyze F6**：注入含失效（非白名單）欄的 persisted sort → 返回該頁 → 其餘有效排序生效、失效欄被丟棄、**無 error**。
9. **FR-014/analyze F9**：多欄排序時 header **無優先序號碼 badge**（框架保證、順手斷言）。
10. **analyze F3（audit tab 持久化獨立）**：`/manage/audit` 排序某 tab（如 operation by createTime）→ 切另一 tab → 切回 → 各 tab 排序**獨立保留**、不互相污染（驗複合 storageKey `manage_audit:<tab>`）。

## C-V-8 · migration up→down→up（m008 可逆）

```
docker compose ... exec -T rust-api sh -c 'cd /app && cargo run -p migration -- up && cargo run -p migration -- down -n 1 && cargo run -p migration -- up'
# 驗索引存在
docker compose ... exec -T postgres psql -U postgres -d <db> -c "\di idx_login_attempt_created_at"
```
期望：up/down/up 皆綠、索引最終存在、down 時被 drop。

## C-V-9 · Constitution 對齊抽驗

- envelope/PageRes/id 序列化未變（既有 contract/lint 測零回歸）。
- 未指定 sort 時 7 端點回傳逐列等同現況（C-V-4 擴及各端點）。
