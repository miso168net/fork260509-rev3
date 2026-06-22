# Phase 1 Data Model: Button-Endpoint 授權治理（三維 RBAC runtime 編輯）

> 接地 pin rust-api `2ad2029`。**本刀零 migration**——下列 schema 全已存在（`casbin_rule` 三維 + `sys_casbin_policy_archive` + `sys_menu.buttons` JSON + 6 編輯端點 policy seed 全 m002）；新增者僅 in-memory 解析型（`SetEndpointsOutcome/Error`）、prod registry const、wire DTO（honest）。

## 1. 既有持久化 schema（零變更、讀寫）

### casbin_rule — 三維單表（archetype D 治理變體、§I.6）
`entity/src/casbin_rule.rs:9-22`（11 欄）：`id:i64` / `ptype:String` / `v0-v5:String` / `protected:bool`(NN) / `created_at:DateTimeWithTimeZone`(NN) / `created_by:Option<i64>`。
**三維編碼（v2 為維度判別軸）**：
| 維度 | v0 | v1 | v2 | v3-v5 | 用途 | enforce 入口 |
|---|---|---|---|---|---|---|
| menu | role_code | route_name | `'menu'` | `''` | 選單可見性 | `menu_routes_for_roles` 讀 |
| **button** | role_code | **button_code**（`user:add` 式） | `'button'` | `''` | 按鈕可見性 | `buttons_for_roles` 讀（v2='button'） |
| **endpoint** | role_code | **path**（`/systemManage/...`） | **HTTP method**（GET/POST/DELETE…） | `''` | API 存取 | `require_policy`/enforce 查 (role,path,method) |
- 本刀：button 走 `set_role_dimension(role,"button",codes)`（固定-v2）；endpoint 走新 `set_role_endpoints(role,&[(path,method)])`（雙鍵、v2=method 變動）。**兩者皆寫【真實 enforce 列】**（button v2='button'、endpoint v1=path/v2=method）。

### sys_casbin_policy_archive — 13 欄、既有（015 首消費、本刀維度延伸）
`entity/src/sys_casbin_policy_archive.rs:8-23`：ptype/v0-v5/`created_at:Option`/created_by/archived_at(NN)/archived_by/archive_reason(NN,32)。**維度無關**：menu/button/endpoint revoke 列皆原樣搬入（v1/v2 照搬）→ 回收桶維度由 v2 推導（§3）。

### sys_menu.buttons — JSON、既有（button registry 來源）
`entity/src/sys_menu.rs:31`：`buttons:Option<Json>`；seed 形 `[{"code":"user:add","desc":"新增用户"},…]`（`m002:209-240`）。getAllButtons 自全 active menu 萃取 `{code, label:=desc}`。

### 6 編輯端點 policy seed（`m002:148-153`、全 protected R_SUPER）+ 15 protected endpoint
- 6 編輯端點：getAllButtons/getRoleButton/updateRoleButton/getAllEndpoints/getRoleEndpoints/updateRoleEndpoints（GET×4／POST×2、protected=true）。
- 15 protected endpoint（鎖出守門、research §接地 #4）：含 getRole/updateRoleEndpoints、getRole/updateRoleMenu、getArchivedPolicies/restorePolicy、getSystemSettings/updateSystemSetting 等恢復/治理路徑。

## 2. in-memory 解析型（本刀新）

```rust
// model/facade/sys_casbin_rule.rs（endpoint 寫側）
pub struct SetEndpointsOutcome { pub changed: bool }
pub enum SetEndpointsError { Db(DbErr), Rejected(Vec<(String,String)>) /* 被擋 (path,method) */ }
// set_role_endpoints<C:TransactionTrait>(conn, role_code:&str, desired:&[(String,String)], meta, role_id)
//   -> Result<SetEndpointsOutcome, SetEndpointsError>
//   single mutate_in_txn: read-current(v2∈methods) → diff(path,method) → protected-reject(BEFORE writes)
//     → revoke(insert_archived + DELETE 同 txn) → grant(insert) → op-log(changed)
```
- button 寫端**不新型**（復用 `set_role_dimension("button")` 的 SetDimensionOutcome/Error）。
- endpoint 列辨識常數：`const HTTP_METHODS:&[&str]=&["GET","POST","PUT","DELETE","PATCH"]`（read-current/list-filter/registry 判別用）。

## 3. registry（本刀新、prod 常數/JSON 解析、非 schema）

```rust
// enforce.rs（或 facade）：endpoint registry（完整、穩定、lint 防漂移）
pub(crate) const ALL_ENDPOINT_POLICIES: &[(&str,&str)] = &[
  ("/systemManage/getUserList","GET"), … /* 全部可授權 (path,method)、含本刀 6 個 */ ];
// all_buttons(db): 讀全 active sys_menu.buttons JSON → Vec<Button{code,label}> 字典序去重
```
- `endpoint_coverage_lint` 加 assertion：`ALL_ENDPOINT_POLICIES` ⊇ main.rs registered policy-governed endpoint（防漂移）。

## 4. 回收桶三維辨識（v2-推導、不改 archive_reason）

```
list dimension 顯示：dimensionType(v2) = match v2 { "menu"|"button" => v2, _ => "endpoint" }
list dimension filter：?dimension=endpoint → WHERE v2 IN (HTTP_METHODS)；=menu/button → v2.eq
restore：復用 015 restore（維度無關、(ptype,v0-v5) 7-col pre-check + created_at coerce + 審計{role,target,dimension}）
```
- archive_reason 保持 diagnostic（menu/button="role_dimension_revoke"、endpoint="role_endpoint_revoke"）；**回收桶不靠 archive_reason 分維度**（靠 v2-推導）。

## 5. PolicyMutated gate（§4.2 ③、維度無關復用）

```
updateRoleButton  Ok(Applied,含空-diff) → reload_and_publish   // set_role_dimension("button")
updateRoleEndpoints Ok(Applied,含空-diff) → reload_and_publish  // set_role_endpoints
*  Err(Rejected) → skip（不 reload 不 publish）
跨副本：reload_and_publish PUBLISH casbin:policy:invalidate；spawn_policy_watcher SUBSCRIBE→load_policy（015 既有、維度無關收斂）
```

## 6. wire DTO（honest、§I.3 對齊、無新碼）

- **GET getAllButtons**（R_SUPER）→ `Button[]`：`Button{ code:string, label:string }`（字典序）。
- **GET getRoleButton?roleId**（R_SUPER）→ `string[]`（該角色 button code 集、⚠️r roleId number）。
- **POST updateRoleButton** `{roleId:number, buttonCodes:string[]}` → `null`；Applied/空-diff→`0000`、Rejected→`2222`（button 0 protected、實務不觸）。
- **GET getAllEndpoints**（R_SUPER）→ `Endpoint[]`：`Endpoint{ path:string, method:string, label?:string }`（registry 全集）。
- **GET getRoleEndpoints?roleId**（R_SUPER）→ `Endpoint[]`（該角色已授權 (path,method)）。
- **POST updateRoleEndpoints** `{roleId:number, endpoints:Endpoint[]}` → `null`；Applied/空-diff→`0000`、Rejected（含 protected）→`2222` `biz.role.endpointProtected`（帶被擋 (path,method)）。
- id ⚠️r 域（roleId number）；無新碼（`0000`/`2222` 凍結 13 碼）。

## 7. Validation rules（自 FR）
- **FR-001/012**：button grant/revoke→casbin v2='button'；revoke→archive（同 txn 原子）；button 0 protected（撤僅影響可見性、可逆）。
- **FR-002**：endpoint grant/revoke→casbin (path,method) 真實列；revoke→archive；enforce 即時反映（撤的端點該 role 403/5003）。
- **FR-003/006**：revoke→insert_archived+DELETE 同 txn；restore 三態（復用 015）；審計同 txn。
- **FR-004/SC-003**：endpoint protected-reject BEFORE 任何寫（撤 protected→整批 Rejected 零變更）；恢復路徑（15 protected）恆保留＝無硬鎖出。
- **FR-005**：回收桶統一三維（v2-推導 dimensionType）＋filter（endpoint 特例）。
- **FR-007**：gate——Applied（含空-diff）reload+publish、Rejected skip。
- **FR-008**：watcher 跨副本收斂（button/endpoint 維度無關復用 015）。
- **FR-009**：6 端點 R_SUPER（m002 seed、require_policy）。
- **FR-010/SC-007**：menu 維度（011/015）零回歸；archive_reason 並存不破基線。
- **FR-011/SC-008**：zero migration（`git diff migration/` 空；button/endpoint/6 端點 policy 全波0）。

## 8. typings 收斂 fold-in（D5、最低優先）
- `RoleListItemRev3 = Omit<Role,'roleDesc'> & { roleDesc: string | null }`（rev3-owned、honest）；service getRoleList 回型改用。
- User nickName/userPhone/userEmail→rev3-owned honest（擴 UserListItemRev3 或新讀型）。
- **§3.13 Menu.buttons no-op**（已對齊）。declaration-merge 加法、不動 frozen `system-manage.d.ts`。
