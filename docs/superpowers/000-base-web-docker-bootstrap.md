# 000 · base-web docker bootstrap（rev3）

> rev3 workspace 第一個跑起來的 service（base-web standalone 容器化）＋ mock API wire ground truth 捕獲與對映紀錄。
> 編號 `000` = pre-spec-kit / workspace foundation 階段（同 rev2 慣例，非 spec-kit feature、沒走 SDD/TDD 鏈）。
>
> **與 rev2 同名文件的分工**：rev2 `fork260509-rev2/docs/superpowers/000-base-web-docker-bootstrap.md`（1165 行）
> = 容器化 6 輪 debug 全史 + CDP gotchas 首發地 + 持久記憶（其 §8）。本檔**不重複** rev2 內容、僅引用段號；
> rev3 增量 = mock API 捕獲三目標與 13 端點對映表（rev2 該檔無此範圍）+ rev3 as-built 差異。

---

## 1. 任務範圍（2026-06-12）

| 目標 | 內容 | 狀態 |
|---|---|---|
| 前置 | base-web standalone 容器化（`docker-compose.base-web.yml`，dev 熱重載 :31079） | ✅ commit `309099d` |
| 目標 1 | CDP 9229 操作 `http://127.0.0.1:31079`，DevTools Network 記錄 base-web↔mock 流量全貌 | ✅ `base-web-capture.json`（12 筆/7 端點） |
| 目標 2 | CDP 遍巡 `https://s.apifox.cn/35c8727a-d3ab-47e9-8863-ef8e37df6887`，收集 13 白名單端點的請求參數/返回響應 | ✅ `apifox-cdp-harvest.json` + `apifox-webfetch-spec.json` |
| 目標 3 | 目標 1+2 整理成完整對映表、與 `docs/INTEGRATION-DESIGN.md` 的 rust-api 設計比對 | ✅ 本檔 §5–§6 |

> 補充：CDP 未覆蓋的 6 端點以 curl 直打 mock 補齊（`mock-curl-supplement.json`），13/13 端點均有實測資料。
> 過程事故：原 session（Claude Code 2.1.173）工具結果抖動、capture script 與部分中間檔未落地，
> 後續 session 重建（capture script 重建版已實測，§3.2）。

## 2. 容器化落地（as-built）

> **另有 example 視覺參考實例**（2026-06-15 新增）：rev3 另建 `docker-compose.example.yml` 跑 **example 分支＋官方 mock**（port 31076、獨立 project `rev3-admin-example`）做視覺對照——rev3 worktree base-web cutover 到 rust-api 後仍可隨時對比 mock 原貌。本檔描述的 `docker-compose.base-web.yml` **base-web-dev（31079、連 mock）行為不變**；同批另為該檔補上 dev/prod profiles＋`base-web-prod` 服務（與本節 dev 捕獲態無關）。見 [CLAUDE.md §8.2](../../CLAUDE.md)。

`docker-compose.base-web.yml`（workspace root，捕獲時 44 行）。與 rev2 standalone compose 的差異：

| 項目 | rev2 | rev3 |
|---|---|---|
| node image | `node:20.19-alpine` | `node:26-alpine` |
| host port | `127.0.0.1:21079` | `127.0.0.1:31079`（皆 loopback 限定，差異僅 port 號） |
| profile | dev / prod 雙 profile | **dev-only**（prod multi-stage Dockerfile 留待 §8.2 整套 stack feature） |
| service 名 | `base-web-dev` / `base-web-prod` | `base-web-dev` |
| project name | `rev2-admin` | `name: rev3-admin`（volume auto-prefix 同步） |

rev2 六輪 debug 的教訓**直接內建**（不再踩）：array-form `command:`（rev2 §4 第 1 輪）、
`npm install -g pnpm@10` 跳過 corepack（第 2/3 輪）、`npm_config_store_dir=/pnpm-store` + named volume
防 store 污染 worktree（第 5 輪，rev2 §2.7）、`CI=true` 防 confirm prompt 卡死（第 6 輪）。

```bash
docker compose -f docker-compose.base-web.yml up -d        # 啟動（首次 ~3-5 分鐘）
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:31079/   # 驗證
docker compose -f docker-compose.base-web.yml down         # 停止（volume 保留）
```

## 3. CDP 9229 操作參考

### 3.1 gotchas

**沿用 rev2 000 文件 §5.6–§5.8**（要點一行版，細節看 rev2 該檔）：
- **§5.6** page id 必須完整 32 字元 hex；截短 → WS reject close 1006 + 空 error message。
- **§5.7** `edge://`/`chrome://` internal pages 不可 attach；新 tab 先 navigate 到任一 http URL（id 會換）。
- **§5.8** `/json` 列的是**所有** targets；操作的 tab 不一定是 user 親眼看的 tab——讓 user 開專用 tab。

**rev3 本次新增**：
- **origin 不等價**：`localhost:31079` 與 `127.0.0.1:31079` 是**不同 origin**，localStorage/token 不共享。
  本次實測兩個 tab（`localhost` 工作 tab 有 Super token、`127.0.0.1` tab 是乾淨 /login）狀態不同。
  CDP smoke 選 tab 時先確認 origin 與 storage 狀態，`Storage.clearDataForOrigin` 的 origin 參數也要對準。
- **apifox 雲端 mock 有 Token 鑑權**：直打 `https://mock.apifox.cn/m1/3109515-0-default/*` 必帶 header
  `apifoxToken: XL299LiMEDZ0H5h3A29PxwQXdMJqWyY2`（starter 公開內建值，出處 `base-web/src/service/request/index.ts:17`，
  alova 端 `src/service-alova/request/index.ts:37` 同值），否則 HTTP 500 + `{"apifoxError":{"code":401,...}}`。
- **mock 不是純靜態**，至少兩個端點有條件邏輯（實測，`mock-curl-supplement.json` round1 vs round2）：
  - `GET /route/getUserRoutes`：無 `Authorization: Bearer <token>` → `{"data":null,"code":"3333","msg":"用户已失效或不存在"}`；帶 login 取得的 token → 200 完整 `{routes,home}`。
  - `POST /auth/refreshToken`：dummy refreshToken → `{"data":null,"code":"8888","msg":"用户状态失效，请重新登录"}`；帶真 refreshToken → `{token,refreshToken}`。
- **mock 頻率限制**：連打可能回 5xx；curl 批次每筆間隔 ≥3 秒（本次補抓全程無 5xx）。

### 3.2 CDP node scripts（`tests/000-base-web-docker-bootstrap/scripts/`）

免 npm install（host node v24 內建 `globalThis.WebSocket`）。4 個腳本：

| 腳本 | 用途 | 驗證狀態 |
|---|---|---|
| `cdp-capture-api.mjs` | **Network domain 捕 mock API 流量** → JSON（schema 對齊 `base-web-capture.json`）；`--reload` 自動觸發 fresh 流量 | ✅ rev3 實測（2026-06-12；2026-06-13 再用於 getUserList 補抓） |
| `cdp-nav.mjs` | navigate + dump form elements + screenshot | ✅ rev3 實測（2026-06-13，nav /login 與 /manage/user 全鏈通過） |
| `cdp-login.mjs` | 點 quick-login（超级管理员）+ 等 URL 變 + screenshot | ✅ rev3 實測（2026-06-13，click/URL poll/error path 全驗；happy path 由 ③ 同款邏輯覆蓋。**gotcha**：mock 限流時 login 回「timeout of 10000ms exceeded」toast、但請求常在 toast 後背景完成跳轉——重試前先讀當前 URL） |
| `cdp-clear-and-relogin.mjs` | 清 `localhost:31079` origin storage + 完整 fresh login flow | ✅ rev3 實測（2026-06-13，fresh login → /home、1824 elements 與 rev2 §5.3 deterministic 值一致） |

```bash
# 取完整 32 字元 page id（⚠️ 不要截短；篩 type=page + 目標 URL）
PAGE_ID=$(curl -s http://127.0.0.1:9229/json | python3 -c "
import json, sys
pages = [p for p in json.load(sys.stdin) if p['type']=='page' and 'localhost:31079' in p['url']]
print(pages[0]['id']) if pages else sys.exit(1)
")

S=tests/000-base-web-docker-bootstrap/scripts
node $S/cdp-capture-api.mjs "$PAGE_ID" /tmp/capture.json 60000 --reload   # 捕流量 60 秒
node $S/cdp-nav.mjs   "$PAGE_ID" http://localhost:31079/login /tmp/login.png
node $S/cdp-login.mjs "$PAGE_ID" 超级管理员 /tmp/postlogin.png
node $S/cdp-clear-and-relogin.mjs "$PAGE_ID" 超级管理员 /tmp                # fresh re-verify
```

> 早上 session 的原始 capture script 因工具抖動事故未落地；`cdp-capture-api.mjs` 為等價重建版
> （差異：`page` 欄用 document URL，原版為人工階段標記如 `login:pre`、`/manage/user:modal`）。

## 4. mock API 捕獲執行紀錄

### 4.1 raw 資料檔（`tests/000-base-web-docker-bootstrap/`，git-tracked）

| 檔 | 來源 | 內容 |
|---|---|---|
| `base-web-capture.json` | CDP Network 捕獲（**base-web 真實流量**，static route mode、Super quick-login + 逛 /manage/*） | 12 筆 / 7 distinct 端點、真實 response body |
| `apifox-cdp-harvest.json` | CDP 遍巡 s.apifox.cn 13 端點頁 innerText | 文件頁原始文字 |
| `apifox-webfetch-spec.json` | WebFetch 結構化整理（method 人工修正） | 13 端點 req/resp 規格 + 型別標註 |
| `mock-curl-supplement.json` | curl 直打 mock 補抓（**非瀏覽器流量**） | 缺口 6 端點 ×（無認證失敗路徑 + 認證成功路徑） |
| `getuserlist-cdp-capture.json` | CDP 補抓（2026-06-13，已登入 /manage/user reload） | `getUserList` 瀏覽器流量（原 capture 被 ERR_ABORTED 吃掉的缺口）＋同輪 getUserInfo |

### 4.2 覆蓋說明

- CDP 實測覆蓋 7/13：`getUserInfo`(×6)、`login`、`getRoleList`、`getAllPages`、`getMenuList/v2`、`getAllRoles`，
  外加 1 筆 `getUserList` 被 `net::ERR_ABORTED` 吃掉（modal 早關或競態；curl 已補成功路徑）。
- `/route/*` 三端點無瀏覽器流量的原因：capture 時 `routeMode=static`（`.env` `VITE_AUTH_ROUTE_MODE` 出廠預設）——
  static mode 下前端不打 `/route/getUserRoutes`/`getConstantRoutes`。**rev3 接 rust-api 時切 dynamic**
  （DESIGN §6.4 BASE-WEB-ADAPT 軌道），屆時這三條變日常流量、CDP smoke 須重抓。
- `refreshToken`/`auth/error` 屬異常路徑觸發，瀏覽器日常流量自然不出現；curl 補抓。

## 5. ★ 13 端點對映表（目標 3）

四端來源：**①** apifox 文件（`apifox-webfetch-spec.json`）/ **②** mock 實測（capture + curl supplement）/
**③** base-web 宣告（`src/service/api/*.ts` + `src/typings/api/*.d.ts`，= wire 唯一權威，DESIGN §7 權威序）/
**④** rev3 rust-api 設計（DESIGN §7.1 endpoint 全集）。

| # | method path | apifox id | base-web fn（axios） | res `data` 型別（typings） | 實測來源 | 對齊 |
|---|---|---|---|---|---|---|
| 1 | POST `/auth/login` | 100526985 | `fetchLogin` | `Api.Auth.LoginToken` `{token,refreshToken}` | CDP（Super/123456 → 0000） | ✅ |
| 2 | GET `/auth/getUserInfo` | 120399825 | `fetchGetUserInfo` | `Api.Auth.UserInfo` `{userId:string,userName,roles[],buttons[]}` | CDP ×6 | ⚠️ 見 §5.2-3 |
| 3 | POST `/auth/refreshToken` | 120415125 | `fetchRefreshToken` | `Api.Auth.LoginToken` | curl（8888 失敗 + 0000 成功） | ⚠️ 見 §5.2-7 |
| 4 | GET `/auth/error` | 158477619 | `fetchCustomBackendError` | —（echo code/msg） | curl（echo 確認） | ⚠️ mock-only，rust-api 無此 route（DESIGN §7.1） |
| 5 | GET `/route/getConstantRoutes` | 158516240 | `fetchGetConstantRoutes` | `Api.Route.MenuRoute[]` | curl（4 筆 login/403/404/500） | ✅（§5.2-6） |
| 6 | GET `/route/getUserRoutes` | 120415303 | `fetchGetUserRoutes` | `Api.Route.UserRoute` `{routes[],home}` | curl（3333 失敗 + 200 成功） | ✅ |
| 7 | GET `/route/isRouteExist` | 120415373 | `fetchIsRouteExist` | `boolean` | curl（true） | ✅ |
| 8 | GET `/systemManage/getRoleList` | 145344387 | `fetchGetRoleList` | `RoleList` = `PaginatingQueryRecord<Role>` | CDP（id:1 number） | ✅ |
| 9 | GET `/systemManage/getUserList` | 149754769 | `fetchGetUserList` | `UserList` = `PaginatingQueryRecord<User>` | CDP（ERR_ABORTED）+ curl（成功） | ✅（流量待補，§7） |
| 10 | GET `/systemManage/getAllRoles` | 145409928 | `fetchGetAllRoles` | `AllRole[]` = `Pick<Role,'id'\|'roleName'\|'roleCode'>[]` | CDP（1008 筆） | **❌ mock 回 string id**（§5.2-1） |
| 11 | GET `/systemManage/getMenuList/v2` | 157945109 | `fetchGetMenuList` | `MenuList` = `PaginatingQueryRecord<Menu>` | CDP（total:6） | ⚠️ apifox 文件漏分頁包（§5.2-2） |
| 12 | GET `/systemManage/getAllPages` | 157988353 | `fetchGetAllPages` | `string[]` | CDP（16 筆） | ✅ |
| 13 | GET `/systemManage/getMenuTree` | 158414289 | `fetchGetMenuTree` | `MenuTree[]` `{id,label,pId,children?}` | curl（id/pId number） | ✅ |

> alova-only 端點（`sendCaptcha`/`verifyCaptcha`/`addUser`/`updateUser`/`deleteUser`/`batchDeleteUser`，
> `src/service-alova/api/*`）apifox 文件未定義、不經 axios 主線 —— 與 DESIGN §7.1「alova 7 endpoint 不入本表」一致，本表不收。
> （口徑差：本檔 6 條 = `service-alova/api/` 函式口徑；DESIGN 的 7 = alova mock 模組口徑，多 1 條 `/mock/getLastTime` 由 `views/alova/**` 直用 alova instance、無 api 層函式。）

### 5.1 全鏈一致確認（mock 實測 ↔ typings ↔ DESIGN §7）

- **信封**：`{data, code, msg}`、`code` 為字串 `"0000"`、msg 簡中 —— 與 §7.3 `Res<T>` 一致。業務失敗碼也走 HTTP 200（3333/8888 實測）。
- **分頁形**：`{records, current, size, total}` 欄位集合與 `Common.PaginatingQueryRecord<T>` ↔ rust `PageRes<T>` 一致（getRoleList/getUserList/getMenuList/v2 三端點實測；JSON key 序非契約）。
- **id 型別**（⚠️r 拍板「逐欄位忠實 typings」的 mock 佐證）：`CommonRecord.id`/`Menu.parentId`/`MenuTree.id/pId` 實測皆 JSON **number**（getRoleList id:1、getMenuList parentId:0、getMenuTree pId:0）；`UserInfo.userId` 實測 **string**（"1"）—— 與 typings 宣告及 ⚠️r 拍板完全一致。唯一例外見 §5.2-1。
- **碼表**：實測出現的 `0000`/`3333`/`8888` 語意（成功/token 失效/重新登录）與 §7.3 13 碼矩陣一致。
- **帳號**：`Super`/`123456` quick-login 實測成功 —— 與 CLAUDE.md §8.1 rev3 權威名一致。

### 5.2 差異發現（依嚴重度）

1. **`getAllRoles` mock 回 string id** ❌：實測 `[{"id":"1","roleName":...}]`（1008 筆全 string），
   但 typings `AllRole.id` = number（`Pick<Role,'id'|...>`、`Role` 基於 `CommonRecord`）、且**同一 mock 專案**的
   getRoleList/getUserList/getMenuList 實測 id 都是 number。apifox 文件 schema 更是漏列 id 欄。
   三端三個樣 —— rev2 025-I1 type-lie 同款火種。**裁決**（§7 權威序①）：typings 為準，rev3 rust-api `AllRole.id` 回 **number**；
   mock 此處是範本瑕疵 —— 佐證 §7.2 拍板⑤「CDP/mock capture 只當補充回歸 fixture、**不當 shape oracle**」。
2. **`getMenuList/v2` apifox 文件漏外層分頁包** ⚠️：文件 schema 區只寫 `{records:[...]}`（`apifox-webfetch-spec.json`
   該端點的「★ 注意:無外層 current/size/total 分頁包」註記是對 apifox 頁面的忠實轉錄、但**與實測矛盾**）；
   mock 實測回 `{records, current:1, size:10, total:6}`、typings `MenuList = PaginatingQueryRecord<Menu>` 亦有分頁欄。
   裁決：typings + 實測為準（有分頁包）；apifox 可視化頁 schema 顯示不全。
3. **`getUserInfo` apifox 文件把 data 內容寫成 root**：實測外層仍是 `{data,code,msg}` 信封（spec 檔已註記）。讀 apifox 文件時注意此慣性。
4. **`/auth/error` 為 mock-only**：rust-api 不實作（DESIGN §7.1 明載）；echo 行為實測確認（query `code=8888&msg=testmsg` 原樣回信封）。
5. **mock 有條件邏輯**（§3.1）：`getUserRoutes` 驗 Authorization、`refreshToken` 驗 token 值 —— 失敗碼 3333/8888 與碼表一致；寫 contract test 時這兩條的失敗路徑 mock 也能對照。
6. **`getConstantRoutes` 實測含 `props:true` 欄**（login 路由）：apifox 文件 MenuRoute 形未列；typings `MenuRoute extends ElegantConstRoute` 本就允許 —— 文件不全、無矛盾。
7. **`refreshToken` 成功回應的 JWT payload `userName=Soybean`**：mock 範本殘留（login 簽的是 Super）。提醒：**勿拿 mock JWT payload 內容當 ground truth**；rev3 rust-api 真簽發無此問題。

## 6. 與 INTEGRATION-DESIGN 比對結論

- **§7.1 endpoint 全集表的 13 條 base-web 白名單端點與本對映表逐條吻合**（含 `/auth/error` mock-only 標記）；
  rust-api 另有的寫端/治理端點（add/update/delete、getRole{Menu,Button,Endpoints} 等）不在 mock 文件範圍、由 §7.1 自管。
- **⚠️r「逐欄位忠實 typings」拍板獲 mock 實測佐證**（§5.1 id 型別段）；`getAllRoles` 的 mock string id 反例
  正好示範「mock 不可當 shape oracle」—— 與 §7.2 C+ 拍板（typings-as-oracle + CDP capture 降為回歸 fixture）互證。
- **本次 capture 是 static route mode 快照**：接線切 dynamic（§6.4）後 `/route/*` 行為以 rust-api 實作為準、
  本 capture 的 mock `getUserRoutes` 樹僅供形狀參考（內容是 soybean demo 選單、非 rev3 sys_menu seed）。
- 無發現需要回填 DESIGN 的新差異 —— 上述發現全部落在 DESIGN 既有拍板的射程內（⚠️r/C+/mock-only 標記），本檔作為佐證紀錄即可。

## 7. Follow-up backlog

- [x] ✅（2026-06-13）`getUserList` 的 CDP 瀏覽器流量補抓 —— `getuserlist-cdp-capture.json`（mock 版；rust-api 版屆時由接線 feature 的 CDP smoke 覆蓋）。
- [ ] dynamic route mode 切換後重抓 `/route/*` 真實瀏覽器流量（§4.2；屆時對象是 rust-api、非 mock）。
- [x] ✅（2026-06-13）`cdp-nav.mjs`/`cdp-login.mjs`/`cdp-clear-and-relogin.mjs` 三支重測全通過（§3.2 表、含 mock 限流 gotcha）。
- [ ] standalone compose 與 §8.2 整套 stack 的整合/退場 —— 沿 rev2 000 文件 §6.3 的「演化」路線（master compose 落地時 service 定義遷移）。
