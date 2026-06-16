# Contract: i18n-key-convention（msg-i18n key 規約；003-envelope 落定、跨 feature 權威）

> 授權載體＝⚠️aa `BASE-WEB-I18N-WIRING ★` 軌道（constitution §III.2、v1.1.0）。承接 ⚠️y（msg=key、前端譯、後端語言無關）＋003 brainstorm 4 sub-拍板。**後續每個切片新增其 biz error key 一律循本規約**（locale + Schema 擴充、走本軌道）。

## 1. Key 文法（凍結）

`<root>.<entity>.<condition>`（各段 camelCase）。`entity` 對 per-entity 業務錯誤**必填**、矩陣級/通用可省為 `<root>.<condition>`（如 `common.success`、`biz.error`）。

**4 命名空間根**：
| root | 用途 |
|---|---|
| `common` | 通用（成功等） |
| `auth` | 登入/token/session |
| `biz` | 業務驗證（`2222`；per-entity 主場） |
| `system` | 基礎設施（internal/notFound/forbidden） |

**code-keyed（`error.2222`）否決**：`2222` 為所有業務錯誤共用碼，code-keyed 會把 per-entity 訊息全塌成同一句、違 ⚠️y「可區分 per-entity 的語意 key」。

## 2. 前綴歸屬 (c)：wire 去前綴、前端 locale 外包 `backend.`

- **wire `msg`**＝**去前綴**語意 key（如 `biz.role.notFound`）——curl/log/audit 乾淨、後端 key **不耦合**前端 locale 樹組織（§I.1：base-web 為 i18n 權威、自決擺哪層架）。
- **base-web locale**＝外包一層 top-level `backend`（實際 key＝`backend.biz.role.notFound`）；前端在唯一翻譯邊界補前綴：`$t('backend.' + msg)`。
- canonical 形＝`backend.<root>.<entity>.<condition>`（locale 端）；DESIGN §7.3 anchor 範例 `biz.role.notFound` 為**去前綴示意**（與 wire 一致）。

## 3. 13 固定碼 seed key（003 ship；雙語譯文）

| code | wire key（去前綴） | locale 實際 key | zh-CN | en-US |
|---|---|---|---|---|
| `0000` | `common.success` | `backend.common.success` | 请求成功 | Success |
| `1000` | `auth.login.failed` | `backend.auth.login.failed` | 用户名或密码错误 | Incorrect username or password |
| `2222` | `biz.error`（泛用） | `backend.biz.error` | 业务错误 | Operation failed |
| `3333` | `auth.token.expired` | `backend.auth.token.expired` | 登录已过期 | Login expired |
| `7777` | `auth.session.kicked` | `backend.auth.session.kicked` | 账号在他处登录 | Logged in elsewhere |
| `8888` | `auth.session.reLogin` | `backend.auth.session.reLogin` | 请重新登录 | Please log in again |
| `4040` | `system.notFound` | `backend.system.notFound` | 接口不存在 | Resource not found |
| `5003` | `system.forbidden` | `backend.system.forbidden` | 权限不足 | Permission denied |
| `5000` | `system.internal` | `backend.system.internal` | 服务器内部错误 | Internal server error |

- reserved `7778/8889/9998/9999`：後端永不發 → **無 key、不入 locale**。
- 逐碼 condition 命名可實作期微調（root + 文法不變）。

## 4. typed-key Schema（三處編輯、⚠️aa 軌道 (ii)(iii)）

`App.I18n.Schema`（`app.d.ts:313-849`）加 `backend` 型 → `I18nKey = GetI18nKey<Schema>`（`:857`）納 `backend.*`。**Schema 為手寫**（非 `typeof zhCN`）、langs 物件被 `: App.I18n.Schema`（`langs/zh-cn.ts:1`/`en-us.ts:1`）編譯強制 → 兩 langs 必補齊 `backend` 物件。helper（`locales/index.ts` 匯出）：
```ts
export function translateBackendMsg(msg: string): string {
  return $t(('backend.' + msg) as App.I18n.I18nKey);
}
```
- runtime 任意 key 需 `as App.I18n.I18nKey` cast（`$t` 9 overload 首參皆 `I18nKey` 有限聯集、`app.d.ts:861-871`）。
- **後續切片擴 per-entity key**：(a) `Schema.backend.biz` 加該 entity 型、(b)(c) 兩 langs 補譯文——循本規約、走 ⚠️aa 軌道。

## 5. graceful fallback（Clarifications 2026-06-16＝B）

未翻譯 key → **顯示原始 key 路徑字串**＝vue-i18n **11.4.2 原生未命中行為、零額外碼**（`core-base.mjs:1533` miss 回 `key`；`createI18n` 未設 `missing` handler）。波 1 前 per-entity key 未入 Schema/locale 即走此（過渡態、缺翻譯「大聲」暴露易抓修；不改顯通用訊息）。

## 6. 翻譯接線點（file:line；⚠️aa 軌道 (i)、fork-delta `rev3-inline`）

| 點 | file:line | 改動 | 涵蓋 |
|---|---|---|---|
| A | `service/request/index.ts:71` | `content: translateBackendMsg(response.data.msg)` | 7777 modal |
| B | `service/request/index.ts:64` | dedup push 翻譯後值 | （保 stack 鍵=顯示文字） |
| B′ | `service/request/index.ts:51` | dedup filter 比對翻譯後值 | 同上 |
| C | `service/request/index.ts:109` | `message = translateBackendMsg(error.response?.data?.msg) ?? message` | generic toast（1000/2222/5000） |

- **不**改 `shared.ts:54 showErrorMsg`（翻譯在讀取邊界、避免誤譯 axios 傳輸字串＋破 `:49` dedup）。
- **限制（R3、不修）**：`4040`/`5003`（HTTP 404/403）走 axios native error、`error.code≠BACKEND_ERROR`→ `:108` gate 跳過、envelope msg 未讀；本刀不拓寬（DESIGN §7.3 既認限制；enforce 刀再議）。
- 每處 fork-delta：修改型保留原行註解＋`// [rev3-inline I18N(i)] 原行: ...`；helper/Schema/langs 新增型檔頭/區塊標記圈界、含 `rev3-inline` token。

## 7. 三端對齊（§I.3）

(a) rust `Res`/`PageRes`/`AppError`（[envelope-contract.md](envelope-contract.md)）↔ (b) base-web `app.d.ts:901-908 Service.Response<T>`＋新 `backend` Schema ↔ (c) `service/request` 消費點（§6）——envelope 形＋key 型三端一致；mock 僅補充 fixture、不當 oracle。
