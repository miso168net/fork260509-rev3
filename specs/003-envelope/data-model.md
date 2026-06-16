# Data Model: 003-envelope

> 本刀為**序列化/錯誤層**——**無持久實體、無 migration、無 DB**（R6/R7）。本檔模型＝(1) rust-api wire 型（新建）、(2) base-web i18n Schema delta（三處編輯）、(3) helper 簽名。逐欄權威＝凍結契約 [contracts/envelope-contract.md](contracts/envelope-contract.md)＋規約 [contracts/i18n-key-convention.md](contracts/i18n-key-convention.md)。rust 命名為**新建**（本刀定義、非 grep 既有）；base-web 命名全 file:line 親驗（research R2/R4）。

## 1. rust-api wire 型（`server/src/envelope.rs`、新建）

### `Res<T>`（統一信封）
| 欄 | 型 | 規則 |
|---|---|---|
| `data` | `T`（成功）／`null`（錯誤、不省略） | serde 序列化序**第一**；錯誤時 `serde_json::Value::Null` 或 `Option<T>=None` 顯式序列化 |
| `code` | `String`（如 `"0000"`） | 序列化序**第二**；非 number |
| `msg` | `String`（去前綴語意 key、如 `biz.role.notFound`） | 序列化序**第三**；⚠️y 語言無關 key |
- `#[derive(Serialize)]`；欄序＝宣告序（serde 預設）。`impl IntoResponse for Res<T>` → 預設 `StatusCode::OK`（200）。
- 成功建構：`Res::ok(data)`（code=`"0000"`、msg=`common.success`）；列表→`Res::ok(PageRes{..})`。

### `PageRes<T>`（分頁區塊、包在 `Res<T>.data`）
| 欄 | 型 | 規則 |
|---|---|---|
| `current` | `u64` | JSON number、camelCase |
| `size` | `u64` | 同上 |
| `total` | `u64` | 真總數 |
| `records` | `Vec<T>` | 空頁 `[]`（不省略）；**無** `pages`／`success` |

## 2. rust-api error 型（`server/src/error.rs`、新建）

### `AppError`（僅 9 個可發碼變體；reserved 4 碼**無變體**＝型別層保證永不發出）
| 變體 | code | wire key | http |
|---|---|---|---|
| `Success`（通常走 `Res::ok` 非 AppError） | `0000` | `common.success` | 200 |
| `LoginFailed` | `1000` | `auth.login.failed` | 200 |
| `Biz(key: Cow<'static,str>)` | `2222` | 入參 key（未指定＝`biz.error`） | 200 |
| `TokenExpired` | `3333` | `auth.token.expired` | 200 |
| `ModalLogout` | `7777` | `auth.session.kicked` | 200 |
| `Logout` | `8888` | `auth.session.reLogin` | 200 |
| `NotFound` | `4040` | `system.notFound` | **404** |
| `PermissionDenied` | `5003` | `system.forbidden` | **403** |
| `Internal` | `5000` | `system.internal` | 200 |

- 每變體烤 `(code: &'static str, key: &'static str, http: StatusCode)`（`Biz` 之 key 為入參）。
- `impl IntoResponse for AppError`：建 `Res{data:null, code, msg:key}` ＋對應 `http`（預設 200、僅 `NotFound`→404／`PermissionDenied`→403）。
- **reserved `7778`/`8889`/`9998`/`9999`**：**無對應變體** → 後端無法構造、編譯期保證永不發出（FR-003/FR-011）。
- 逐碼 condition 命名（`reLogin`/`kicked`/`expired` 等）可微調、見 envelope-contract.md；root 集合+文法已定。
- **`From<DbErr>` 不在本刀**（R7：server 今日無碼產 `DbErr`、不加 sea-orm dep；首個產 `DbErr` 切片帶入）。

## 3. base-web i18n Schema delta（⚠️aa 軌道、三處編輯）

### (iii) `src/typings/app.d.ts` — `App.I18n.Schema`（`:313-849`）加 `backend` 型
```
backend: {
  common: { success: string };
  auth:   { login: { failed: string }; token: { expired: string };
            session: { kicked: string; reLogin: string } };
  biz:    { error: string };          // 泛用 2222 預設；per-entity 由後續切片擴此型
  system: { notFound: string; forbidden: string; internal: string };
};
```
- 加入後 `I18nKey = GetI18nKey<Schema>`（`:857`）自動納入 `backend.common.success`…等 typed key。
- **語言物件被 `: App.I18n.Schema` annotation 編譯強制**（`langs/zh-cn.ts:1`/`en-us.ts:1`）→ 下方 (ii) 兩 langs **必須**補齊 `backend` 物件、否則 type error。

### (ii) `src/locales/langs/{zh-cn,en-us}.ts` — 加 `backend` 物件（13 固定碼譯文）
- 鍵結構鏡像上方 Schema；值＝[i18n-key-convention.md](contracts/i18n-key-convention.md) 雙語表（zh-CN＝矩陣現有人話、en-US 新撰）。

### (iii) helper（`src/locales/index.ts` 匯出）
```
export function translateBackendMsg(msg: string): string {
  return $t(('backend.' + msg) as App.I18n.I18nKey);   // 前端補 backend. 前綴（前綴歸屬 (c)）
}
```
- runtime 任意 key 需 `as App.I18n.I18nKey` cast（`$t` 9 overload 首參皆 `I18nKey` 有限聯集、`app.d.ts:861-871`）。
- 命中（13 固定 key）→ 譯文；未命中（波 1 前 per-entity key）→ vue-i18n 11.4.2 原生回傳原始 key 路徑字串（Clarifications B、R5、零額外碼）。

## 4. 消費端接線（`src/service/request/index.ts`、(i) 範圍）
| 點 | file:line | 改動 |
|---|---|---|
| A modal content | `:71` | `content: translateBackendMsg(response.data.msg)` |
| B dedup push | `:64` | push 翻譯後值（保 stack 鍵=顯示文字） |
| B′ dedup filter | `:51` | filter 比對翻譯後值 |
| C onError extraction | `:109` | `message = error.response?.data?.msg ? translateBackendMsg(error.response.data.msg) : message`（truthy-guard：有 backend msg 才譯、否則保 axios fallback；**勿** `?? message`——helper 必回 string、`??` 不 fallback） |
- `shared.ts:54 showErrorMsg` **不改**（翻譯在讀取邊界、避免誤譯傳輸字串＋破 dedup、R2）。
- 全處走 fork-delta `rev3-inline`（修改型保留原行註解+token）。

## 5. 排除聲明
- 無持久實體／無 entity crate／無 migration（本刀不觸 DB）。
- `service-alova/`＋`demoRequest` 不碰（demo-only、R2）。
- `4040`/`5003` 之 `onError` 顯示拓寬**不在本刀**（R3 限制）。
