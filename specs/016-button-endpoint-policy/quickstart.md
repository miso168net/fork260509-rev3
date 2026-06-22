# Quickstart 驗證指引：Button-Endpoint 授權治理（016）

> 端到端驗證三維 RBAC runtime 編輯（button＋endpoint）。完整指令見 [contracts/verification-commands.md](./contracts/verification-commands.md)；設計見 [plan.md](./plan.md)／[research.md](./research.md)／[data-model.md](./data-model.md)。

## 前置
- dev stack 起：`DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"; $DC up -d --wait`。
- 帳號（§8.1）：Super/Admin/User，密碼 `123456`。
- **零 migration、零新 crate**：6 編輯端點 policy＋button/endpoint policy＋button JSON 全 m002 已備（`git diff migration/` 必空）。

## 核心驗證情境（對應 US/SC）

### 1. button 維度編輯（US1、SC-001）
1. Super 登入取 token。
2. `GET /systemManage/getAllButtons` → 回全部按鈕 `{code,label}`（自 sys_menu.buttons）。
3. `POST /systemManage/updateRoleButton {roleId, buttonCodes:[...]}` 撤某 button → psql 證 `casbin_rule` v2='button' 該列消失 + `sys_casbin_policy_archive` 有該列。
4. 該角色使用者 `getUserInfo` → buttons 不含撤的；回收桶 restore → 回現役。
- **期**：按鈕授權即時生效、可復原、原子。

### 2. endpoint 維度編輯 + 鎖出守門（US2、SC-002/003）★
1. `GET /systemManage/getAllEndpoints` → 回 registry `Endpoint[]{path,method}`。
2. `POST /systemManage/updateRoleEndpoints {roleId, endpoints:[...]}` 撤某【非保護】(path,method) → psql 證該列消失 + archive；該 role 對該 endpoint enforce 被拒。
3. **鎖出守門**：撤含【protected】endpoint（如 `updateRoleEndpoints`/`getRoleMenu`）→ 整批 `2222 biz.role.endpointProtected`、**零變更**、恢復路徑保留。
- **期**：端點授權即時生效、可復原；受保護核心**永遠改不掉**（無硬鎖出）。

### 3. 治理統一 + 跨副本（US3、SC-004/005/006）
1. 回收桶 `getArchivedPolicies` → button/endpoint 撤的皆列出、`dimension` 欄顯 button/endpoint（v2-推導）、`?dimension=endpoint` filter 命中 endpoint archive。
2. gate：Rejected/no-op → 不 reload 不 publish；Applied（含空-diff）→ reload+publish。
3. 2-instance（`$DC --profile multi up -d rust-api-2 --wait`）：A 改 button/endpoint → B `getUserInfo`/enforce 收斂；CLIENT KILL pubsub → 重訂閱仍收斂。

### 4. CDP 三維編輯 UI（SC-006）
- ★ 先 `$DC restart base-web`（驗 i18n、vite locale cache）。
- Super → `/manage/role` → edit drawer → 三鈕（選單/按鈕/端點授權）→ button/endpoint modal 真打讀寫 → psql 證。

### 5. 零回歸 + prod build（SC-007/008）
- `cargo test -p server -- --ignored --test-threads=1`（menu 011/015 + button/endpoint 新測全綠）＋非 ignored 全套。
- `git diff migration/` 空；`pnpm typecheck`；`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api`。

## DoD（§4.2 5 invariants ↔ C-V）
① DB-first→C-V-2/3｜② protected-reject〔endpoint 鎖出〕→C-V-3｜③ gate→C-V-4｜④ 原子+審計→C-V-2/3｜⑤ 跨副本→C-V-6。UI→C-V-7、policy-gate→C-V-5、零回歸+prod→C-V-8。
