# Phase 0 Research: 003-envelope

> 接地源＝Phase 0 三路 act-on-code workflow（base-web 請求層／base-web i18n＋typed-key／rust-api scaffold＋deps），全 file:line 親驗 2026-06-16。凍結契約源＝constitution §I.3／DESIGN §7.3。**NEEDS CLARIFICATION = 0**。

## R1 — 凍結 wire 契約（不可動、忠實實作）

**Decision**：信封 `Res<T>{data,code,msg}`（`code` string、序列化序 data→code→msg、錯誤 `data:null` 不省略）＋`PageRes<T>{current,size,total,records}`（camelCase、無 `pages`/`success`、空頁 `records:[]`）；13 碼整組凍結；`5000`→HTTP 200，僅 `4040`→404／`5003`→403 破信封。
**Rationale**：constitution §I.3（NON-NEGOTIABLE）＋DESIGN §7.3；⚠️e（5000→200）／⚠️f（13 碼凍結）已決。
**Alternatives**：無——凍結權威，本刀只忠實實作、不重決。

## R2 — base-web 請求層 ground truth ＋ 翻譯插入點（file:line）

**Decision**：翻譯接線點＝(A) `service/request/index.ts:71`（modal-logout `content:`）＋(C) `index.ts:109`（`onError` 的 `message = error.response?.data?.msg`）＋(B/B′) `index.ts:64`/`:51`（modal dedup-stack push/filter，companion，保持 stack 鍵＝顯示文字）。翻譯**不**放 `shared.ts:54 showErrorMsg`（會誤譯 axios 傳輸字串＋破壞 `:49` 的 dedup `includes`）。
**Rationale**（grep 證實）：
- envelope 消費型＝`app.d.ts:901-908` `Service.Response<T>{code,msg,data}`；`transform`（`index.ts:25-27`）成功時剝信封回 `data.data`，故 `code/msg` 僅在攔截器 hooks 可見。
- `isBackendSuccess`（`index.ts:34-38`）：`String(code)===VITE_SERVICE_SUCCESS_CODE`（`.env:32`＝`0000`）。
- `onBackendFail`（`index.ts:39-100`）：logout（55-59、不顯）／modal-logout（62-84、`content:` 71 顯 raw msg）／expired（88-97、不顯）／fallthrough `return null`（99）。
- generic（1000/2222/5000）：HTTP 200＋code≠0000 → `@sa/axios`（`packages/axios/src/index.ts:68-74`）合成 `BACKEND_ERROR` AxiosError（response 附帶）→ `onError`（`index.ts:101-126`）`:109` 讀 `error.response.data.msg` → `:125 showErrorMsg`（toast）。
- `showErrorMsg`（`shared.ts:44-64`）：`window.$message?.error(message)`（`:54`）、dedup 鍵＝message 字串（`:49`）。
- 真實 app 服務層（`service/api/{auth,route,system-manage}.ts:1`）全 import `@/service/request`（createFlatRequest）；`service-alova/` 僅 `views/alova/**` demo 用、**本刀不碰**；`demoRequest` 亦 demo、不碰。
**Alternatives**：放 `showErrorMsg` 統一翻譯——否決（誤譯非 backend 字串＋破 dedup）。

## R3 — 傳輸錯誤路徑限制（load-bearing 發現、修正 FR-008）

**Decision**：`4040`/`5003`（HTTP 404/403）今日前端**不顯示 envelope msg** → 本刀**不修復**；003 只翻譯實際顯示路徑（7777 modal＋generic toast 1000/2222/5000）。
**Rationale**（act-on-code）：真實非 200 傳輸錯誤走 `@sa/axios` 的 onRejected 分支（`packages/axios/src/index.ts:80`）、其 `error.code`＝`'ERR_BAD_REQUEST'` 等、**非** `BACKEND_ERROR`；故 `onError` `:108` 的 `if (error.code === BACKEND_ERROR_CODE)` gate 跳過、`:109` 不讀 envelope msg、`message` 留 axios 字串。此即 DESIGN §7.3 既載「HTTP 4xx 不 surface msg、existing fact not bug」。`5003` 由 enforce middleware 發、enforce 是後續刀（本刀無）。
**Alternatives**：拓寬 `:108` gate 讓 404/403 也讀 envelope msg——否決於本刀（超出最小信封接線＋與 ⚠️e「顯示走 200」設計衝突；留對應切片決定，登 follow-up）。

## R4 — base-web i18n / typed-key（Schema 手寫 → 三處編輯）

**Decision**：加 `backend` 命名空間須**三處**：(1) `typings/app.d.ts` 的 `App.I18n.Schema`（`:313-849`）加 `backend` 型、(2) `locales/langs/zh-cn.ts`、(3) `langs/en-us.ts` 各加 `backend` 物件。helper `translateBackendMsg(msg)` 自 `@/locales` 匯出、內部 `$t(('backend.'+msg) as App.I18n.I18nKey)`。
**Rationale**（file:line）：`Schema` 是**手寫 type alias**（非 `typeof zhCN`）；`I18nKey = GetI18nKey<Schema>`（`app.d.ts:857`）；langs 物件被 `: App.I18n.Schema` annotation（`langs/zh-cn.ts:1`/`en-us.ts:1`）編譯強制 → 加 Schema 後兩 langs 必須補齊（否則 type error）。`$t`＝`i18n.global.t as App.I18n.$T`（`locales/index.ts:22`）、9 overload 首參皆 `key: I18nKey`（`app.d.ts:861-871`）→ runtime 字串需 `as App.I18n.I18nKey` cast。canonical import `import { $t } from '@/locales'`（82 檔）→ helper 同自 `@/locales` 匯出。
**Alternatives**：Schema 用 `backend: Record<string,…>` index-signature（免逐 key 列舉）——本刀採**列舉 13 固定碼 seed key**（編譯檢查 seed 齊全＋兩語譯文必備）＋helper cast 容 runtime 任意 key；後續切片增 per-entity key 時擴列舉。index-sig 留未來若 catalogue 過大再議。

## R5 — graceful fallback ＝ 原生未命中行為（驗證 Clarifications 決策 B）

**Decision**：未翻譯 key → 顯示原始 key 字串＝vue-i18n **原生預設、零額外碼**。
**Rationale**（FACT）：`vue-i18n 11.4.2`（`package.json:85`）；`createI18n`（`locales/index.ts:6-11`）未設 `missing`/`missingWarn` handler → `@intlify/core-base@11.4.2 core-base.mjs:1533` miss 回傳 `key`（路徑字串）。helper 直接 `$t(cast)` 即得此行為、無需自寫 fallback。dev 期 console 出 `NOT_FOUND_KEY` warn（不影響回傳值；可選 `missingWarn:false` 靜音、非必要）。
**Alternatives**：通用「操作失敗」fallback——Clarifications 2026-06-16 否決（決策 B）。

## R6 — rust-api scaffold ＋ deps（greenfield、純加模組）

**Decision**：`envelope.rs`＋`error.rs` 為既有 `server` crate 內**純新增模組**（`main.rs` 加 `mod`＋`.fallback(handler_404)`）；**無新 workspace crate**。`server/Cargo.toml` 須加直接 dep `serde`（derive）＋`serde_json`（lock 已 pin 1.0.228/1.0.150、無版本 churn、建議先入 `[workspace.dependencies]` 再 `{workspace=true}`）。contract test 為 **in-crate `#[cfg(test)]`**（`server` bin-only、無 lib.rs、`server/tests/` 無法 `use server::`）、純型別無 DB → 一般 `cargo test`（無 `#[ignore]`）。
**Rationale**（file:line）：`server/src/` **僅 `main.rs`**（greenfield、無 entity/facade/tests——CLAUDE.md §8.1 7-entity 敘述對不上現 worktree @ 91cfc80）；`main.rs:19` router 僅 `.route("/health")`、無 `.fallback`；`axum 0.7.9`（`Json` 免 feature flag；`.fallback()` 收 Handler 非 value→需小 `async fn handler_404()->AppError`）；server deps 僅 axum/tokio/tracing（`server/Cargo.toml:11-15`、無 serde/serde_json/sea-orm）；grep 證實全 rust-api 無 `Res`/`AppError`/`IntoResponse`（從零建）。
**Alternatives**：靠 axum 透傳的 serde——否決（`#[derive(Serialize)]` 需 server 直接 dep serde）。

## R7 — `From<DbErr>` 範圍裁定（延後、避免 overbuild）

**Decision**：003 **不**含 `From<DbErr> for AppError`、**不**加 sea-orm 到 server。
**Rationale**：server 內**今日無任何碼產生 `DbErr`**（無 entity/facade/handler；grep：`DbErr` 僅在 migration/adapter）；為零-caller 的 impl 加 sea-orm dep＝提前耦合 DB、違 §2 simplicity（「不為不可能情境寫錯誤處理」）。呼應 brainstorm §3.2「確認最小範圍避免 overbuild」。
**Alternatives**：本刀即建 `From<DbErr>`＋`sql_err()` 23505→2222——延後至首個產 `DbErr` 的切片（facade/handler 刀）帶入（該刀加 sea-orm 到 server＋映射）。`sql_err`/`SqlErr` 全 repo 今零用、屆時從頭建。

## R8 — msg-i18n key 規約（003 落定、scope A）

**Decision**：文法 `<root>.<entity>.<condition>`（camelCase）＋4 根 `{common,auth,biz,system}`；wire `msg`＝**去前綴**語意 key（如 `biz.role.notFound`）、base-web locale **外包一層 `backend.`**（前綴歸屬 (c)：後端發去前綴、前端 `$t('backend.'+msg)` 補）；13 固定碼 seed key＋zh-CN/en-US 譯文見 [contracts/i18n-key-convention.md](contracts/i18n-key-convention.md)。
**Rationale**：⚠️y（msg=key）＋003 brainstorm 4 sub-拍板（DECISIONS §1 ⚠️y 注記）；code-keyed（`error.2222`）否決（共用碼塌縮 per-entity 訊息）。授權載體＝⚠️z `BASE-WEB-I18N-WIRING ★` 軌道（constitution §III、v1.1.0）。
**Alternatives**：見 brainstorm；本刀承接已決。

## 三-grep 紀律（CLAUDE.md §3）落地

- **facade/entity 返回型 grep**：N/A（本刀無 biz endpoint、無 entity/facade）。
- **wire 3 端對齊**：(a) rust `Res`/`PageRes`/`AppError`（本刀新建、見 data-model）↔ (b) base-web `app.d.ts:901-908 Service.Response<T>`＋新 `backend` Schema ↔ (c) `service/request` 消費點（R2 file:line）——envelope 形與 key 型三端一致。
- **命名對照 grep**：base-web 側全 file:line 親驗（R2/R4）；rust 側為新建、命名於 data-model 定義。
- **CDP smoke defer 自覺**：見 spec FR-012＋[contracts/verification-commands.md](contracts/verification-commands.md)（i18n 顯示端到端＝波 0 Auth 刀 login 1000、per-entity 2222＝波 1）。
