# 003-envelope — Phase 0 brainstorm（2026-06-16）

> 波 0 第三刀（rev2 008「統一回應信封」重寫，§I.5 受控參照＝rewrite 非照拷）；凍結前提＝⚠️e／⚠️f／⚠️y（[DECISIONS §1](../INTEGRATION-DECISIONS.md)）。本檔＝`/speckit-specify` 的 input（user 手動執行、不在本流程觸發）。
> **named aspect：「error envelope ＋ msg-i18n key 規約」一體設計**（scope A 完整縱切：rust-api 生產端＋key 規約＋base-web 消費端一刀內 ship）。
> 本次 4 項 sub-拍板（§2，登本檔表、不鑄新 ⚠️ 碼）：scope A 完整縱切｜4 命名空間根＋文法、code-keyed 否決｜locale 外包一層 `backend.`｜前綴歸屬 (c) 後端發無前綴 key。

---

## 1. 研究 ground truth（act-on-code 接地＋凍結契約雙錨）

- **rust-api 現況**：`server/src/` **僅 `main.rs`＋`/health`**（plain-text）；envelope／error／handler／i18n **全不存在**。故 003 全新建 `envelope.rs`＋`error.rs`，且 **003 本身無任何 biz endpoint**（純 L1 序列化/錯誤層，§1.5 DAG side-track，只依 serde＋axum `IntoResponse`）——003 唯一存在的 msg ＝ **13 碼矩陣的固定 default**。
- **凍結信封契約**（constitution §I.3／DESIGN §5.4・§7.3，不可動）：`Res<T>{data,code,msg}`（`code` 為 string、序列化序 data→code→msg、錯誤時 `data:null` 不省略）＋`PageRes<T>{current,size,total,records}`（camelCase、JSON number、無 `pages`／`success`、空頁 `records:[]`）；13 碼整組凍結（含 4 reserved）；`5000`→HTTP 200，**僅 `4040`→404／`5003`→403 破信封**（前端 msg 顯示通道僅 200 生效，⚠️e）。
- **⚠️y（2026-06-16 已決）**：`msg` 由人話改載**穩定 i18n key**；base-web 以 `$t(msg)` 翻譯、後端**語言無關**（產 key 不在地化）；graceful fallback（vue-i18n 未命中回傳 key 字串）。原文「key 命名規約／error 命名空間於刀 1（system_settings）定」**本次提前至 003 落定**（見 §2.1／§4，待回填 DECISIONS ⚠️y 列注記）。
- **base-web 消費端實況**（act-on-code）：真實 app 服務層（`service/api/{auth,route,system-manage}.ts`）只走 **`@sa/axios`（`service/request`）**；`service-alova/` 僅 soybean demo 頁用、**整合不碰**。msg 目前一律 **verbatim 顯示**（`onBackendFail` modal `content`、`shared.ts` `showErrorMsg` toast、`onError` 非 200 extract）。`.env` 行為分組：SUCCESS=`0000`／LOGOUT=`8888,8889`（靜默登出、不顯 msg）／MODAL_LOGOUT=`7777,7778`（modal 顯 msg）／EXPIRED_TOKEN=`9999,9998,3333`（刷新、不顯 msg）。
- **i18n 實況**：vue-i18n 11（`legacy:false`、composition）；typed key `GetI18nKey<App.I18n.Schema>`（`app.d.ts`）；locale `langs/{zh-cn,en-us}.ts`，top-level 根＝`system/common/request/theme/route/page/form/dropdown/icon/datatable`——**無任何 code→訊息對映**，`request.*` 為模板語意（部分 demo 描述、部分行為導向訊息），**不複用**。

## 2. 本次拍板（user 親決 2026-06-16）

1. **scope A 完整縱切**：003 一刀內 ship「規約＋兩端接線」——rust-api 產 key-bearing msg＋key 文法/命名空間＋base-web `$t` 接線＋locale 命名空間＋fallback＋contract test。波 1 system_settings 之後**只依規約加自己的 per-entity biz key**。＝**提前落定 ⚠️y「key 規約留刀 1」的部分**（規約在 003、首批 per-entity key 值仍在波 1）。
2. **key 文法＝`<root>.<entity>.<condition>`（camelCase）＋ 4 命名空間根 `{common, auth, biz, system}`**；`entity` 對 per-entity 業務錯誤必填、矩陣級/通用可省（`common.success`／`biz.error`）。**code-keyed（`error.2222`）否決**：`2222` 為所有業務錯誤共用碼，code-keyed 會把 per-entity 訊息全塌成同一句、違 ⚠️y「可區分 per-entity 的語意 key」初衷（亦修正探勘期 `$t('error.${code}')` 誤讀）。
3. **base-web locale 外包一層 top-level `backend`**：key 落 `backend.<root>...`（如 `backend.biz.role.notFound`）；與 soybean 模板根（`common.`／`request.` 等）隔離→fork-delta 邊界乾淨、upstream rebase 衝突面最小。
4. **`backend.` 前綴歸屬＝(c) 後端發無前綴語意 key**：wire `msg`＝`biz.role.notFound`（＝⚠️y anchor 原形、curl/log/audit 乾淨、後端 key **不耦合**前端 locale 樹）；base-web 在**唯一翻譯點**補前綴（`$t('backend.'+msg)`）。符合 §I.1「base-web 為 wire＋i18n 權威、自決擺哪層架」。代價＝前端一行加工。
   > canonical 形＝`backend.<root>.<entity>.<condition>`（locale 端）／wire 端去前綴；DESIGN §7.3 anchor 範例 `biz.role.notFound` 為去前綴示意——spec 落地時於 DECISIONS ⚠️y 列注記避免日後對不上。

## 3. 設計總形（已核可）

**§3.1 交付物**
- **rust-api（既有 `server` crate 內新增模組、非新 workspace crate）**：`server/src/envelope.rs`＋`server/src/error.rs`＋`main.rs` 接線（`.fallback`→`AppError::NotFound`）；in-crate `#[cfg(test)]` contract test（純型別、無 DB）。
- **base-web（fork-delta `rev3-inline`）**：`locales/langs/{zh-cn,en-us}.ts` 新增 `backend` 命名空間（13 固定碼譯文）＋`app.d.ts` `Schema` 補 `backend` 型別＋`service/request/` 翻譯接線（helper `translateBackendMsg`）＋base-web 單元/component test。
- `specs/003-envelope/contracts/`：C-V（`cargo test`／curl `4040`／base-web test）；端到端 CDP 列波 1（§3.5）。

**§3.2 envelope.rs ＋ error.rs（producer，⚠️y：只產 key）**
- `Res<T>{data,code,msg}`＋`PageRes<T>`：serde derive、固定欄序、`IntoResponse` 預設 HTTP 200；`4040`→404／`5003`→403 特例。
- `AppError` enum：**僅 9 個可發碼變體**（0000 走成功路徑、其餘見 §3.3 表），各變體烤入 `(code:&'static str, key:&'static str, http)`；**reserved 4 碼無對應變體 ＝ 型別層保證後端永不發出**。`AppError::Biz(key)` 承載 per-entity key（未指定＝泛用 `biz.error`）。
- `From<DbErr> for AppError` 基礎映射（預設→`Internal`/5000；unique violation pg `23505`→`Biz`/2222 helper 備妥〔`DbErr::sql_err()`→`SqlErr::UniqueConstraintViolation` 偵測〕）——003 **無 caller**、由後續 entity 刀首次行使；spec 期確認最小範圍避免 overbuild。

**§3.3 13 碼 → key 落點（wire 去前綴；locale 端＝`backend.`＋此 key）**

| code | 變體 | wire key | zh-CN（矩陣現有人話） | en-US（新撰） | 前端是否顯示 |
|---|---|---|---|---|---|
| `0000` | Success | `common.success` | 请求成功 | Success | 否（走 data） |
| `1000` | LoginFailed | `auth.login.failed` | 用户名或密码错误 | Incorrect username or password | toast |
| `2222` | BizError | `biz.error`（泛用；per-entity 覆寫） | 业务错误 | Operation failed | toast |
| `3333` | TokenExpired | `auth.token.expired` | 登录已过期 | Login expired | 否（刷新） |
| `7777` | ModalLogout7777 | `auth.session.kicked` | 账号在他处登录 | Logged in elsewhere | modal |
| `8888` | Logout8888 | `auth.session.reLogin` | 请重新登录 | Please log in again | 否（靜默登出） |
| `4040` | NotFound | `system.notFound` | 接口不存在 | Resource not found | onError（非 200） |
| `5003` | PermissionDenied | `system.forbidden` | 权限不足 | Permission denied | onError（非 200） |
| `5000` | Internal | `system.internal` | 服务器内部错误 | Internal server error | toast |
| `7778`／`8889`／`9998`／`9999` | reserved | —（後端永不發、無 key） | （矩陣留 default_msg 供前端 .env 辨識行為） | — | — |

> 逐碼 condition 命名（`reLogin` vs `expired`、`kicked` 等）可 spec 期微調；root 集合與文法已定。

**§3.4 base-web consumer（locale ＋ 接線 ＋ typed-key ＋ fallback）**
- locale：`backend` 命名空間植入上表 13 key 之 zh-CN／en-US；`App.I18n.Schema` 補 `backend` 型別→`GetI18nKey` 自動納入 typed key。
- 接線：所有顯示 backend msg 之處改以 helper 翻譯——`onBackendFail` modal `content`（`service/request/index.ts`）、generic-code 的 `showErrorMsg` toast（`shared.ts`）、`onError` 非 200 extract；**精確接線點 spec 期 act-on-code 定案**（控制流逐行核）。`service-alova/` demo 層不碰。
- **typed-key tension**：`$t` 鎖 `I18nKey` union、wire msg 為 runtime string→薄 helper `translateBackendMsg(msg)` 內部 `$t(('backend.'+msg) as App.I18n.I18nKey)`；13 固定 key 已入 Schema 命中即譯。
- **graceful fallback**：波 1 前的 per-entity key（未入 Schema/locale）未命中→vue-i18n 回傳 key 路徑字串（不炸）；helper 是否對未命中改顯通用「操作失敗」spec 期定（預設＝回傳 key 字串）。

**§3.5 驗證閉環（C-V 骨架）**
1. **rust-api contract test**（in-crate `#[cfg(test)]`、純型別無 DB→一般 `cargo test`、`server` 為 bin-only 不可 `use server::`）：① 每個 `AppError` 變體 →（code, key, http）對齊凍結矩陣；② `msg` 形狀斷言＝語意 key regex（無 CJK 漢字）鎖「msg 是 key 非人話」；③ emitted code 集合 ⊆ 9 允許碼（reserved 4 碼型別層不存在＝編譯期保證）。
2. **curl**：打不存在路由→`.fallback`→驗 `4040` 信封形＋key（`4040`＝HTTP 404、僅驗 wire 形）。
3. **base-web 單元/component test**：`translateBackendMsg` 對 13 固定 key 命中譯文、對未知 key 走 fallback。
4. **誠實缺口（CLAUDE.md §3「CDP smoke defer 風險自覺」「curl≠modal」）**：003 **無任何 200-path endpoint**，唯一可達後端錯誤＝`.fallback`→`4040`（HTTP 404、走 axios `onError` 非 `onBackendFail`、curl 可驗 wire 形）；200-path 顯示點（onBackendFail modal／generic toast）**003 無 live trigger**，故 consumer 端在 003 以上述 (3) 單元/component test 覆蓋。端到端分**兩階梯、各歸其刀 acceptance**（**非全部 defer 波 1**）：
   - **i18n 顯示機制首個端到端＝波 0 Auth 刀**：login 失敗發碼 `1000`＝`auth.login.failed`（003 已鍵固定碼）→ generic toast 經 `$t` 翻譯顯示，為 i18n 顯示路徑（命中譯文）首個自然 CDP 檢核點（fallback 路徑由 (3) 單元覆蓋）；列 **Auth 刀 acceptance**。
   - **per-entity `2222` biz 錯誤首個端到端＝波 1 system_settings**：首個真 biz endpoint 發 per-entity key（如 `biz.systemSettings.*`、超出 13 固定碼）→ 列 **波 1 acceptance**＋登 follow-up backlog。

**§3.6 已知坑（spec 必載）**
- **prod image build**：003 **未新增 workspace crate**（envelope/error 入既有 `server` crate）→「新增 crate ⇒ acceptance 必含 prod build」紀律字面 N/A；但 003 為 health 後**首批實質 server 碼**，建議 acceptance 仍含一次 prod target build（防 dev bind-mount 遮 prod COPY 缺口，rev2 教訓）。
- **non-200 雙路徑**：`4040`/`5003` 走 axios native error（`onError`）非 `onBackendFail`，其 key 翻譯點與 200-path 不同——接線時兩路都要覆蓋、莫漏 `onError`。
- **vite 熱載**：base-web 新增 service/locale 檔若 vite 沒熱載→`SyntaxError: does not provide an export`／key 顯舊值；活體前 `restart base-web`（CLAUDE.md §8.2.1）。
- **`components.d.ts` 漏網**：若接線過程 view 首次用新 naive-ui 元件→`git add` 連 `src/typings/components.d.ts`（CLAUDE.md §4.1）；本刀預期不新增元件、仍 `git status` 確認。

## 4. spec 期義務（CLAUDE.md §3 Phase 0 research 紀律適用性）

- **facade／wire 鏈 grep**：本刀無 biz endpoint→facade grep **N/A**；但 **wire 3 端對齊**仍適用於 envelope 形——對照（a）rust `Res`/`PageRes`/`AppError` 真實型，（b）base-web `app.d.ts` `Service.Response<T>`＋`backend` Schema，（c）`service/request` 消費點；3 端 envelope 形與 key 型須一致。
- **constitution Check（plan.md 必答）**：§I.1（base-web 為 wire＋i18n 權威→i18n 規約屬其契約演進、§III fork-delta `rev3-inline`）｜§I.3（envelope 凍結形忠實實作；msg=key 為 DESIGN 級演進、**非** constitution amendment）｜§I.5（rev2 008 ＝rewrite 非照拷）。§I.6（審計欄）／§I.7（行為島）本刀 N/A。
- **DECISIONS 回填義務**：⚠️y 列加注「key 規約於 003 落定（scope A）、刀 1 僅套用」＋指向本檔；CHECKLIST 拍板索引同步（feature 收尾時，§7.5 流程）。
- **CDP defer 登記**：§3.5(4) 兩階梯端到端須在 spec `contracts/` 明示——i18n 顯示機制端到端歸**波 0 Auth 刀** acceptance（login `1000`）、per-entity `2222` biz 端到端歸**波 1 system_settings** acceptance＋follow-up backlog。

## 5. 交棒

→ user 手動 `/speckit-specify`（input＝本檔）；`before_specify` pre-hook 自動建 `003-envelope` feature branch。**不**在本 brainstorm 流程觸發 specify（CLAUDE.md §3）。
