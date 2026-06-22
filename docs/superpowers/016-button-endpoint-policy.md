# 016-button-endpoint-policy — Phase 0 brainstorm spec-design

> **波 3 殿後刀**（行為島＋policy 全完成）。把 011 鋪的 `set_role_dimension`（menu 維度寫側）＋015 補完的治理島（archive/restore/protected/gate/跨副本）**延伸到 button 與 endpoint 兩維度**，補完三維 RBAC runtime 編輯。
> **零 migration、零新 crate**（6 端點 policy＋button/endpoint seed 全波0 m002 已備）。
> 接地：3-agent 平行 act-on-code（rust casbin 結構／base-web UI＋typings／DESIGN 意圖），2026-06-22。

---

## 0. 核心目標（一句話）

讓**超級管理員**在 `/manage/role` runtime 編輯「**哪個角色能用哪些操作按鈕、能呼叫哪些 API 端點**」（menu 可見性已 011/015 做完），三維授權編輯全納入 015 治理島的安全保證（DB-first／受保護核心防誤撤／可復原回收桶／精準重載／跨副本收斂）。

---

## 1. Scope（user 拍板 C，2026-06-22）

| 做 | 不做 |
|---|---|
| ✅ **button 維度** runtime 編輯（role×button code，如 `user:add`） | ❌ **un-protect/re-protect**（延續 015 A 拍板：受保護核心不可經 UI 撤銷，做它須 §V.2 amend） |
| ✅ **endpoint 維度** runtime 編輯（role×(path,method)，如 `/systemManage/getUserList`×GET） | ❌ 漸進 **rollout 系統**（接地證實「rollout」＝hard-replace 語意、已是 `set_role_dimension` 行為，非另一套 canary/灰度） |
| ✅ 兩維度皆納入 015 治理島（archive/restore/protected-reject/gate/跨副本） | ❌ 任何 migration／新 entity／新 crate |

> DESIGN「三維授權」＝`casbin_rule` 單表三業務維度（v2=`'menu'`／`'button'`／HTTP method）。menu 已 011/015 完成、016 補 button＋endpoint。

---

## 2. 接地關鍵事實（決定設計）

### 2.1 casbin_rule 三維度結構（m002 seed、72 筆）
| 維度 | v2 | v1 | seed 數 | protected | 套 `set_role_dimension`？ |
|---|---|---|---|---|---|
| menu | `'menu'`（固定） | route_name | 17 | 4（R_SUPER 核心頁） | ✅ 已做 |
| **button** | `'button'`（固定） | button_code（`entity:action` 或 `B_CODEn`） | 16 | **0** | ✅ **直接套**（v2 固定） |
| **endpoint** | **HTTP method（GET/POST/DELETE，會變）** | path（`/systemManage/...`） | 39 | **15** | ❌ **套不上**（v2 非固定 dimension） |

### 2.2 治理基建已備（復用）
- `set_role_dimension(conn, role_code, dimension, desired_objs, meta, role_id)`：**dimension-agnostic**（`sys_casbin_rule.rs`）。menu/button 皆「固定 v2＋diff v1 集」，直接套；endpoint 是 (path,method) 雙鍵集，**套不上**。
- 015 治理島 helper **皆維度無關、可復用**：`insert_archived`（archive-move）／`sys_casbin_policy_archive::{list,restore}`（按 v2 filter）／`reload_and_publish`（gate）／`spawn_policy_watcher`（跨副本）／protected-reject（`set_role_dimension` 內）。
- `buttons_for_roles`（`auth/enforce.rs`）讀 v2='button'→getUserInfo `buttons:string[]`；前端 `hasAuth(code)` 消費。

### 2.3 端點與 UI 半成品（016 只需接線、零 migration）
- **6 端點全 m002 已 seed**（protected=true、R_SUPER）：`getAllButtons`/`getRoleButton`/`updateRoleButton`（rev2 022）＋`getAllEndpoints`/`getRoleEndpoints`/`updateRoleEndpoints`（rev2 023）。**route 未註冊、handler 未實作** → 016 只【註冊 route＋實作 handler＋bump `AS_BUILT_ROUTES` 37→43】。
- **15 protected endpoint** 涵蓋恢復路徑（`getRole/updateRoleEndpoints`、`getRole/updateRoleMenu`、`getArchivedPolicies/restorePolicy`、`getSystemSettings/updateSystemSetting` 等治理＋自編輯端點）。
- base-web `button-auth-modal.vue` **已存在但全 mock**（hardcoded 10 顆按鈕＋checks [1..5]＋submit console.log），入口已在 `role-operate-drawer`；結構鏡像已接真的 `menu-auth-modal`。`endpoint-auth-modal` **須新建**。buttons 嵌 `sys_menu.buttons` JSON（非獨立表）。

---

## 3. 設計

### 3.1 button 寫側 — 撿現成（復用 011＋015）
- handler `getAllButtons`／`getRoleButton`／`updateRoleButton`。
- `updateRoleButton` → `set_role_dimension(role, "button", desired_codes, ...)`：**011 寫側＋015 archive/restore/protected/gate 全免費繼承**（dimension-agnostic）。
- `getRoleButton` → 讀 role v2='button' 的 v1 codes（鏡像 `getRoleMenu`、dimension=button）。
- `getAllButtons` → registry：自 `sys_menu.buttons` JSON 萃取所有 `{code, label}`（字典序）。
- **protected**：button 0 protected → 撤按鈕只隱藏 UI（API 存取靠 endpoint 維度另計）→ **無鎖出風險、零 migration**。

### 3.2 endpoint 寫側 — 新建 `set_role_endpoints`（★ 唯一新核心邏輯）
- 新 facade `set_role_endpoints(conn, role_code, desired: &[(path, method)], meta, role_id) -> Result<SetEndpointsOutcome, SetEndpointsError>`：
  - 讀 current = `casbin_rule WHERE v0=role AND v2 ∈ {HTTP methods}`（endpoint 列辨識＝v2 屬 HTTP method 白名單；不用 `NOT IN ('menu','button')` 以免脆弱）。
  - diff → to_revoke／to_grant 的 (path, method) 配對。
  - **protected-reject**（復用 pattern）：to_revoke 含 protected 列 → `Rejected`、帶被擋 (path,method)、零變更（在任何寫之前）。
  - **archive-move**（復用 015 `insert_archived`）：被撤列搬 archive（同 txn 原子）。
  - grant insert + 同 txn 審計 + 回 outcome。
- handler `updateRoleEndpoints` → `set_role_endpoints`；Applied → `reload_and_publish`（gate 復用）；Rejected → skip。
- `getRoleEndpoints` → 讀 role 的 (path,method) 配對。
- `getAllEndpoints` → registry：所有可授權 (path,method)。**設計細節（plan 定）**：union（distinct endpoint policies across roles、R_SUPER 為超集≈完整）或 canonical const；採 union＋caveat 註記未授權任何角色之端點不顯（實務 R_SUPER 全有）。

> archive/restore/protected/gate/跨副本 **不重寫**——`set_role_endpoints` 只是 diff 邏輯改雙鍵，治理 helper 全沿用 015。

### 3.3 ★ 鎖出安全（endpoint 核心風險、零 migration 解）
- 既有 **15 protected endpoint seed 剛好涵蓋恢復路徑** → `set_role_endpoints` 接 protected-reject 後：**撤任何 protected endpoint → 整批 Rejected 零變更** → 超管**永遠改不掉自己的恢復路徑**（`getRole/updateRoleEndpoints` 等）＝**無硬鎖出**。
- `getUserInfo`（auth-only、無 policy）／`login`／`refreshToken`（public）本就不靠 endpoint policy → 安全。
- 非 protected endpoint（`getUserList`/`addUser`…）可撤但**可逆**（經 protected 的 `updateRoleEndpoints` 改回）。
- **不額外 protect 全部 super endpoint**（會犧牲編輯彈性、且恢復路徑已護）→ 維持零 migration。**C-V 驗**：撤 protected endpoint→Rejected＋恢復路徑可達。

### 3.4 回收桶三維辨識（修正 §3.19 follow-up 做法、零 churn）
- **不改 `archive_reason`**（避免動 015 測試與既有語意）。
- 回收桶 `dimension` 欄改**由 v2 推導**：`match v2 { 'menu'|'button' => 原值, _ => 'endpoint' }`（endpoint 的 v2=method 收斂成 'endpoint'）。
- list facade `?dimension=endpoint` filter → `v2 ∈ {HTTP methods}`（特例）。

### 3.5 base-web（三維編輯 UI）
- `button-auth-modal.vue` **un-mock**（鏡像 `menu-auth-modal`：watch visible→`fetchGetRoleButton`＋`fetchGetAllButtons`→submit `fetchUpdateRoleButton`）。
- **新** `endpoint-auth-modal.vue`（鏡像 button/menu、樹狀顯 (path,method)〔可按 path 群組〕、hard-replace 提交）。
- `role-operate-drawer` 三鈕（選單／按鈕／端點授權）。
- rev3 typings/service 6 wrapper＋i18n（`page.manage.role.*` 補 button/endpoint auth 標籤、先 Schema 後 locale）。
- ★ **加新 i18n 後必 restart base-web 才能 CDP 驗**（vite 快取 locale module；本刀教訓、見 memory）。

### 3.6 fold-ins（user 已 opt-in）
- **typings 收斂**：`roleDesc`（§3.14）、User `nickName`/`userPhone`/`userEmail`（§3.12）補 rev3-owned honest `string | null`（declaration-merge、不動 frozen `system-manage.d.ts`、沿讀端型謊收斂慣例）。**§3.13 Menu.buttons 接地證實已對齊＝no-op、不做**。
- **menuProtected 訊息泛化**（§3.14）：endpoint 入 scope 後有意義（15 protected endpoint）——`set_role_endpoints` 的 `Rejected` 帶被擋 (path,method)，handler 可 surface「哪些受保護端點」（i18n 參數化或回 detail）。
- **archive_reason 維度區分**（§3.19）：改採 §3.4 的 v2-推導，**不動 archive_reason**（比原案乾淨）。

---

## 4. §4.2 五 invariants 對三維（全沿用、維度無關）
- ① **DB-first**：button/endpoint 寫側只動 `casbin_rule`/archive、**絕不** MgmtApi。
- ② **protected-reject**：button（0 protected、moot）／endpoint（15 protected、鎖出守門）。
- ③ **PolicyMutated gate**：`updateRoleButton`/`updateRoleEndpoints` Applied（含空-diff）→`reload_and_publish`；Rejected→skip。
- ④ **原子＋審計**：revoke/grant/archive/op-log 同 txn；restore 審計記 `{role,target,dimension}`。
- ⑤ **跨副本收斂**：button/endpoint 改動 publish `casbin:policy:invalidate`、watcher reload（復用 015、維度無關）。

---

## 5. 拍板（本刀）
1. **scope C＝button＋endpoint 完整 runtime 編輯**（user 2026-06-22）。
2. **un-protect 不做、延伸至 button/endpoint**（延續 015 A 拍板；endpoint 15 protected 維持不可經 UI 撤銷＝鎖出守門）。
3. **回收桶維度用 v2-推導、不改 archive_reason**（取代 §3.19 原案、零 churn 不破 015 測試）。
4. **endpoint 鎖出靠既有 15 protected seed、零 migration**（不額外 protect 全部 super endpoint）。

---

## 6. 執行單元（rough、待 /speckit-plan 細化）
- **U1 button 寫側**：`getAllButtons`（registry 自 menu.buttons JSON）／`getRoleButton`／`updateRoleButton`（reuse `set_role_dimension("button")`）handler＋button live（archive 免費繼承驗）。
- **U2 endpoint facade**：新 `set_role_endpoints`（(path,method) 雙鍵 diff＋archive＋protected-reject＋審計＋gate）＋endpoint live（含鎖出 Rejected）。
- **U3 endpoint handlers＋routes＋AS_BUILT**：3 endpoint handler＋6 route 註冊＋`AS_BUILT_ROUTES` 37→43＋回收桶 dimension filter/display（v2-推導）。
- **U4 base-web**：button-auth un-mock＋endpoint-auth-modal 新建＋drawer 3 鈕＋rev3 typings/service 6 wrapper＋i18n（restart 後 CDP 驗）。
- **U5 typings 收斂 fold-in**（roleDesc／User honest null）。
- **U6 verification**：零回歸＋2-instance（button/endpoint 跨副本收斂）＋CDP（menu/button/endpoint 三 modal 真打）＋prod build＋holistic。

---

## 7. 零 migration / 零新 crate 確認
- button policy（16）＋endpoint policy（39、含 15 protected）＋6 治理端點 policy seed **全 m002 已備**。
- 016 只：註冊 6 route＋實作 handler＋新 `set_role_endpoints` facade＋`AS_BUILT_ROUTES` 37→43（測試常數、非 migration）＋base-web。
- **`git diff migration/` 必空**（FR：零 schema 變更）。

---

## 8. 風險 / open（plan 期解）
- **endpoint registry source**（getAllEndpoints union vs canonical const）——/speckit-plan research 定。
- **`set_role_endpoints` (path,method) 雙鍵 diff 正確性**——live 測覆蓋。
- **鎖出守門**——C-V 撤 protected endpoint→Rejected＋恢復路徑可達（必驗）。
- **(path,method) wire 形狀**——base-web endpoint-auth-modal 顯示/勾選/提交的 honest typing（rev3-owned）。
- **buttons JSON→{code,label} 萃取**——getAllButtons 來源 sys_menu.buttons 解析。

---

## 9. 驗收形狀（C-V outline、plan 期細化為 contracts）
- **button**：`updateRoleButton`→casbin v2='button' 改＋撤的進 archive＋`getUserInfo.buttons` 反映。
- **endpoint**：`updateRoleEndpoints`→casbin (path,method) 改＋撤的進 archive＋enforce 反映（撤的端點該 role→403/5003）。
- **鎖出**：撤 protected endpoint→Rejected 零變更、恢復路徑可達。
- **回收桶**：button/endpoint archive 顯 dimensionType（v2-推導）＋`?dimension=endpoint` filter。
- **gate**：Applied→reload+publish；Rejected→skip。
- **2-instance**：button/endpoint 改 A→B 跨副本收斂（復用 015 watcher）。
- **CDP**：menu/button/endpoint 三 modal 真打＋三維編輯閉環（★ 先 restart base-web）。
- **零回歸**（全 ignored＋non-ignored 綠）＋migration 零-diff＋**prod target image build**。

---

> **next**：本 brainstorm 收後 → 手動 `/speckit-specify`（`before_specify` pre-hook 起 `016-button-endpoint-policy` feature branch）→ `/speckit-plan`（research 期 act-on-code 重新 grounding 上述 file:line、定 endpoint registry source）→ `/speckit-tasks` → `/speckit-analyze` → 階段 2 `executing-plans`＋Workflow。
