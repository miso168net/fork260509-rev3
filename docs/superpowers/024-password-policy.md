# 024-password-policy — Phase 0 Brainstorm（spec-design）

> **波4 後獨立刀**（023-list-column-sort 收刀 2026-07-01 後）。本刀為「密碼複雜度政策 ＋ 個人中心」**2 刀組的第 1 刀（政策先行）**；第 2 刀＝`025-user-center`（個人中心 profile 檢視/編輯 ＋ 改密碼，消費本刀驗證原語）。
> **3 拍板（本檔 brainstorm 對話定、2026-07-01）**：①**切法＝2 刀・政策先行**（政策是「改密碼」的前置、又是可複用基礎建設，先做不空轉、各自可獨立驗收）；②**手機/信箱「驗證」按鈕＝純 UI 佔位**（真實 SMS／SAML2-Google 綁定屬未來；佔位鈕放刀2、本刀不碰）；③**政策項目＝完整 7 項**（最小/最大長度 ＋ 需大寫/小寫/數字/特殊符號 ＋ 禁止密碼＝帳號）。
> **本檔來歷**：延伸 **008-system-settings** 建立的 `system_settings` KV 機制（讀全列＋單鍵改＋by-`value_type` render＋同 txn op-log＋super-only）；只加「數字型政策列＋`number` 型驗證＋純驗證原語」，**不動既有端點/授權/entity/schema**。作 `/speckit-specify` 的 input。
> **凍結權威**：DESIGN §5.6（`system_settings` 熱 KV／CRUD 骨架，008 已落）＋constitution facade-only entity 存取（`entity_access_lint`）＋003 envelope/biz 碼契約＋審計 6 欄成對（§I.6）。**本刀零新端點／零新 wire／零新 i18n key／零 schema／零新 workspace crate**。
> **衝突序：DECISIONS §1 ＞ DESIGN ＞ 本檔**（跨檔引用一律用穩定 §錨、不用揮發行號；本檔不引用本機 memory）。

---

## 1. 目標一句話

複用 008 的 `system_settings` KV 表新增 **7 個密碼複雜度政策列**（admin 可在既有 `/manage/system-settings` 頁調整），並提供一個**已完整單元測試、待接**的純驗證原語 `validate_password_complexity`；補掉 008 已明文承認的「`number` 型 passthrough 不驗」缺口。本刀完成後 admin 即可設定政策、後端持有驗證能力；**實際 enforce（改密碼時套政策）由刀2 接線**。

## 2. Context（探索蒐集、act-on-code 親驗）

### 2.1 延伸的 008 機制（已落地、不重做）
- **entity `system_settings`**（archetype A）：PK `setting_key`（varchar 無序列）／`setting_value`／`value_type`／`description?`／6 審計欄。m001 建表、m002 seed 1 列 `('single_session_default','off','enum:on,off','全站單一-session 預設')`。**本刀不動 schema/entity**。
- **端點 ×2 已在**（super-only、`enforce_mw`＋`require_policy`）：`GET /systemManage/getSystemSettings`（`find_all`→flat 陣列）、`POST /systemManage/updateSystemSetting`（`find_by_key`→查無 `biz.systemSettings.notFound`→`validate_value_type`→`update_by_key`＋同 txn op-log→commit 後 best-effort `publish("settings:invalidate", key)`）。handler `server/src/handler/system_settings.rs`、facade `server/src/model/facade/system_settings.rs`。**本刀復用此兩端點、零新端點**。
- **`validate_value_type(value_type, value)`（純函式，`handler/system_settings.rs`）**：目前只有 `enum:` 分支；**`number`/`string`/`json` 明文「保守放行」（passthrough 不驗）**＝008 承認的缺口。已有 `#[cfg(test)] mod value_type_tests` 可擴。
- **`update_setting` 已對任何 key publish `settings:invalidate`**（fail-OPEN、無訂閱者即 no-op）；watcher 端目前只重載 `single_session_default`→`AppState`。

### 2.2 密碼現況（無任何複雜度檢查）
- 工具 `server/src/auth/password.rs`：`hash_password`（argon2id、random salt、PHC 字串）＋`verify`。**純密碼學、無長度/字元類別檢查**。
- 設密碼點：登入只 `verify`；admin `add_user` 硬編初始密碼 `"123456"`→hash（使用者不輸入）；admin `update_user` **刻意不動 password**。**全庫零密碼政策掛點**。
- 前端唯一密碼規則 `REG_PWD=/^\w{6,18}$/`（`constants/reg.ts`），只用於 SoybeanAdmin 內建 demo 登入頁、**未接真後端**。

### 2.3 前端 system-settings 頁現況（`views/manage/system-settings/index.vue`）
- `parseEnumValues(valueType)`：`enum:a,b`（**恰兩成員**）→ `[a,b]`；其餘回 `null`。
- template：`v-if parseEnumValues(...)` → `NSwitch`（值＝第一成員時 ON）；`v-else` → **唯讀顯示** `settingValue`（無可編輯數字/文字控件）。
- 直接路徑 import `@/service/api/rev3-system-settings`（不經 barrel）；型 `Api.SystemManage.SystemSetting{settingKey,settingValue,valueType,description?}`。

### 2.4 缺口盤點（本刀要補）
1. **無密碼政策列**：`system_settings` 僅 1 列，無任何 `password_*`。
2. **`number` 型不驗**：`validate_value_type` passthrough → 存 `password_min_length="abc"/-1` 後端不擋（2.1）。
3. **前端無數字控件**：非 enum 型只唯讀顯示（2.3），數字政策改不了。
4. **無驗證原語**：全庫無 `validate_password_complexity`／`PasswordPolicy`。

### 2.5 消費者
- **直接（本刀）**：admin 讀/改 7 項密碼政策（既有 super-only 頁）。
- **下游**：刀2 `025-user-center` 改密碼端點 `find_all → from_settings → validate_password_complexity → hash → write`；未來 admin 建/重設密碼、密碼歷史/到期等（§11）。

## 3. 設計決策表（brainstorm 對話定、描述式、非新 ⚠️ 碼）

| # | 決策 | 結論 | 理由／否決 |
|---|---|---|---|
| D1 | 儲存機制 | **複用 `system_settings` KV、加 7 列**（m009 seed-only、非 schema） | 唯一泛用 KV 表、`single_session_default` 同範式；不新建表/端點。否決專屬 `sys_password_policy` 表（少量純量欄位＝over-engineering，違 Simplicity）|
| D2 | runtime store / watcher | **不建 `AppState` 快取／不加 watcher**；政策 **load-on-demand**（刀2 改密碼時現查 DB） | 密碼政策僅「改密碼」時讀（罕見、非熱路徑），不同於 `single_session_default` 每次登入讀；load-on-demand 永遠最新、零快取複雜度。既有 `update_setting` 對 password key 仍會 publish `settings:invalidate`＝無害 no-op（無 watcher 消費）|
| D3 | 政策項目 | **完整 7 項**：`password_min_length`／`password_max_length`（number）＋`password_require_uppercase`／`_lowercase`／`_digit`／`_special`／`password_forbid_username`（enum:on,off） | user 拍板③；涵蓋長度/大小寫/特殊符號＋max＋禁同帳號。機制可再擴（加 key 即可）|
| D4 | 預設值 | **全部保守**：min=8／max=64／所有 `require_*`=off／`forbid_username`=off | 刀1 無強制消費者、預設不影響登入；admin 自行 opt-in；刀2 上線後 enforce 只作用於**新**密碼（既有 argon2 hash 登入不受影響）|
| D5 | `number` 型驗證 | `validate_value_type` 補 **`number` 分支**：正整數、範圍 `1..=1024`，違→**既有** `biz.systemSettings.invalidValue`（2222） | 補 008 承認的 passthrough 缺口；復用既有 biz 碼＝**零新 i18n key**；順手讓 `number` 型全域可驗 |
| D6 | 驗證原語形 | 新純模組 `server/src/auth/password_policy.rs`：`struct PasswordPolicy` ＋ `from_settings(items)->PasswordPolicy`（純 parse）＋ `validate_password_complexity(&policy,plain,user_name)->Result<(),Vec<PolicyViolation>>`（純）；`PolicyViolation` enum（TooShort/TooLong/NeedUpper/NeedLower/NeedDigit/NeedSpecial/SameAsUsername） | 純函式＝TDD 核心可完整單元測試；DB 存取仍走既有 `facade::system_settings::find_all`（facade-only 不破）；violation enum 供刀2 wire 映 i18n |
| D7 | 端點／授權 | **零新端點**：沿用既有 super-only get/update（`enforce_mw`＋`require_policy`） | 政策設定面已被既有兩端點覆蓋；**不需 m009 casbin seed**（無新 gated route）。否決另開專屬政策端點 |
| D8 | 前端形 | `index.vue` 加 **`number` render 分支**（`NInputNumber`＋存檔呼既有 `fetchUpdateSystemSetting`）；5 個 enum 政策**沿用既有 `NSwitch`、零改** | 最小擴充；填「非 enum 唯讀」缺口；`enum:on,off` 政策免前端工＝自動 render。min>max 屬 admin 誤設：前端 `NInputNumber` 設界輕量防呆，後端仍 per-key 驗證（跨欄硬驗延後，§11）|
| D9 | 驗證原語消費 | 刀1 **dormant**（僅單元測試證正確）、刀2 接改密碼端點 live enforce | user 拍板①「政策先行」；刀1＝設定面＋已測待接原語；live enforce＝刀2 |

## 4. 元件設計（act-on-code、既有 seam 名）

### 4.1 `rust-api/migration/src/m009_seed_password_policy.rs`（新、seed-only、D1/D3/D4）
- raw SQL（沿 m002 範式）：**up** ＝ 7 列 `INSERT INTO system_settings (setting_key,setting_value,value_type,description) VALUES (...)`（idempotent，如 `ON CONFLICT (setting_key) DO NOTHING`）；**down** ＝ `DELETE FROM system_settings WHERE setting_key IN (...7 keys...)`。
- 7 列（key／value／value_type／description）：`password_min_length`／`8`／`number`／密碼最小長度；`password_max_length`／`64`／`number`／密碼最大長度；`password_require_uppercase`／`off`／`enum:on,off`／需含大寫字母；`_lowercase`／`off`／`enum:on,off`／需含小寫字母；`_digit`／`off`／`enum:on,off`／需含數字；`_special`／`off`／`enum:on,off`／需含特殊符號；`password_forbid_username`／`off`／`enum:on,off`／禁止密碼與帳號相同。
- `migration/src/lib.rs` migrator vec push `Box::new(m009_seed_password_policy::Migration)`。up→down→up 可逆（三守恆）。

### 4.2 `handler/system_settings.rs`（改：`validate_value_type` 補 `number` 分支、D5）
- 於既有 `match value_type.split_once(':')` 前/內加 `number` 判定：`value_type=="number"` → `value.parse::<u32>()` 成功且 `1..=1024` → `Ok`，否則 `Err(Biz("biz.systemSettings.invalidValue"))`。其餘型維持保守放行。
- 擴既有 `mod value_type_tests`：`number` 合法（`"12"`）／非數字（`"abc"`）／零・負（`"0"`/`"-1"`）／超界（`"9999"`）。

### 4.3 `rust-api/server/src/auth/password_policy.rs`（新、純邏輯、TDD 核心、D6）
- `struct PasswordPolicy{ min_length:usize, max_length:usize, require_upper/lower/digit/special:bool, forbid_username:bool }`。
- `fn from_settings(items:&[SystemSettingItem]) -> PasswordPolicy`：純 parse（`"on"`→true、`number`→usize、缺鍵→D4 預設）；**不觸 DB**（消費者先 `facade::system_settings::find_all` 再餵入）。
- `fn validate_password_complexity(policy:&PasswordPolicy, plain:&str, user_name:&str) -> Result<(),Vec<PolicyViolation>>`：逐 knob 檢（長度用 `chars().count()`；special＝非英數字元；`forbid_username`＝case-insensitive equal）。回全部違規（非短路）供 UI 一次列出。
- `enum PolicyViolation`（7 變體，對映刀2 `backend.biz.password.*` i18n）。`auth/mod.rs` 掛 `pub mod password_policy;`。**零 `entity::`**（守 `entity_access_lint`）。

### 4.4 `base-web/src/views/manage/system-settings/index.vue`（改：`number` render 分支、D8）
- template 加 `v-else-if item.valueType==='number'` → `NInputNumber`（`:min=1 :max=1024`）＋存檔（`@update:value`/blur → `fetchUpdateSystemSetting(item.settingKey, String(val))` → toast + refetch，沿 `handleToggle` 範式）。`enum` 分支不動。
- 7 列顯示文字用 DB seed `description`（沿 `single_session_default` 現有做法、中文 description、**無新 i18n key**）。

### 4.5 facade（復用、無新增）
- 消費既有 `facade::system_settings::find_all`（刀2 loader 用）；本刀不新增 facade fn。`get_system_settings` 端點回形已含 7 新列（seed 後自動出現、零 handler 改）。

## 5. wire / 碼 / i18n

- **零新 wire／零新端點／零新 typings**：7 政策列走既有 `getSystemSettings`／`updateSystemSetting`（`SystemSetting` 型已涵蓋）。
- **零新 i18n key**：`number` 非法值復用既有 `biz.systemSettings.invalidValue`（D5）；政策說明用 DB `description`。
- `PolicyViolation`→i18n 映射（`backend.biz.password.*`）**屬刀2**（改密碼 wire 才需要）；本刀 violation 僅 Rust enum、單元測試斷言變體。

## 6. 範圍邊界

**IN**：m009 seed 7 政策列（可逆）／`validate_value_type` `number` 分支＋純測／`auth/password_policy.rs`（`PasswordPolicy`＋`from_settings`＋`validate_password_complexity`＋`PolicyViolation`，完整單元測試）／前端 `number` render 分支／C-V（純測＋curl/psql 持久化＋number 非法→2222＋CDP admin 編輯）／三守恆＋typecheck＋migration up→down→up。

**OUT（刀2 `025-user-center`）**：改密碼端點（舊密碼 verify→套政策→寫 password）／個人中心 profile GET/update／user-center 頁本體／手機·信箱驗證按鈕 UI 佔位／把 `validate_password_complexity` 接進 live 消費者／前端依政策動態組密碼 rule／`backend.biz.password.*` i18n。

**OUT（未來 feature）**：政策套用到 admin 建 user/重設密碼（現 addUser 硬編 123456）／密碼歷史·到期／弱密碼字典·常見密碼黑名單／min≤max 跨欄硬驗（本刀僅前端輕量防呆＋原語對 min>max 保守 reject）／政策 runtime store（僅在成為熱路徑時才需，現不需，D2）。

**MOOT（already-done、不重做）**：`system_settings` entity/schema/seed 機制（008/004/m001/m002）／get·update 端點＋`require_policy`（008）／`settings:invalidate` publish（014）／審計 6 欄成對·`mutate_in_txn`（005/§I.6）／`auth/password.rs` hash/verify。

## 7. Constitution Check 留痕（`/speckit-plan` 對齊用）

- **facade-only**：`password_policy.rs` 純邏輯零 `entity::`；DB 存取走 `facade::system_settings::find_all`→`entity_access_lint` 恆綠。
- **端點守恆**：零新 route→`endpoint_coverage_lint` registry 不變、零 casbin seed（D7）；`enforce_mw`/`require_policy`/`audit_mw` 零改。
- **三守恆**：`entity_access_lint`＋`endpoint_coverage_lint`＋migration up→down→up（m009 可逆）全綠。
- **無 constitution amendment**：既有 §5.6（system_settings KV）／§I.6（審計成對）／003 envelope 皆既授；本刀不新增軌道、不改授權模型。
- **無新 workspace crate**：只在既有 `server`／`migration` crate 加模組/檔案 → **不觸發 prod-image-build 強制紀律**（惟 plan 須 grep 確認 prod Dockerfile 對 `migration/src` 為整目錄 COPY，m009 自動含入；migration 於 prod migrate gate 執行）。

## 8. Functional Requirements / Success Criteria（草案、`/speckit-specify` 細化）

- **FR-001** admin(super) 於 `/manage/system-settings` 見 7 政策列（含說明）。**FR-002** 5 個 on/off 政策以開關可改、min/max 長度以數字欄可改、皆持久化（同 txn op-log）。
- **FR-003** min/max 長度存非正整數/超界（`abc`/`-1`/`0`/`>1024`）→ `biz.systemSettings.invalidValue`(2222)、不寫入。**FR-004** `validate_value_type` `number` 分支正確（正整數 in-range pass、其餘 reject）。
- **FR-005** `validate_password_complexity` 對 7 knob 各自正確判定（長度上下界、四字元類、禁同帳號；回全部違規非短路）。**FR-006** `from_settings` 正確 parse（on/off→bool、number→usize、缺鍵→預設）。
- **FR-007** 零 schema 變更／零 entity 改／零新端點／零新 casbin seed／零 base-web 既有檔破壞性改（只擴 render 分支）／`enforce_mw`·`audit_mw`·既有 `single_session_default` 開關零回歸。**FR-008** m009 up→down→up 可逆。
- **SC**：SC-001 admin 見 7 新列（5 開關＋2 數字）、切換/改值持久（CDP＋psql）。SC-002 min_length 存 `abc`/`-1`/`0`/`9999`→2222 invalidValue（curl＋純測）。SC-003 `validate_password_complexity` 逐 knob 純測全綠。SC-004 `from_settings` 純測全綠。SC-005 三守恆＋typecheck＋migration up→down→up 全綠。SC-006 零回歸（`single_session_default` 開關仍運作、login/getUserInfo/enforce 不變）。

## 9. C-V 驗收（草案、live 一律 `--test-threads=1` serial；rust 容器內 `docker exec`）

- **C-V-1** `validate_password_complexity` 純測（逐 knob red→green：長度上下界、缺各字元類、密碼＝帳號、全通過）→ FR-005/SC-003。
- **C-V-2** `from_settings` 純測（on/off/number parse、缺鍵預設）→ FR-006/SC-004。
- **C-V-3** `validate_value_type` `number` 分支純測（擴既有 `value_type_tests`）→ FR-004/SC-002。
- **C-V-4** live curl/psql：GET `getSystemSettings` 回含 7 新列；POST `updateSystemSetting`(`password_min_length`,`12`) 持久（psql 驗 DB）；POST(`abc`/`-1`)→2222 invalidValue → FR-002/FR-003/SC-002。
- **C-V-5** CDP browser：super 登入→`/manage/system-settings`→見 5 開關＋2 數字欄→切一開關＋改 min_length→refetch 回 server 真值（斷言持久）→ SC-001。
- **C-V-6** 三守恆（`entity_access_lint`／`endpoint_coverage_lint`／migration up→down→up）＋`pnpm typecheck` → SC-005。
- **C-V-7** 零回歸（`single_session_default` 開關運作、login/getUserInfo/enforce 不變、base-web 既有頁不破）→ SC-006。
- **C-V-8** prod image build（無新 crate、輕；確認 m009＋`password_policy.rs` 編入 prod target、migration 於 prod migrate gate 跑）→ build 面。

## 10. Files（BUILD vs ALREADY）

**BUILD（新/改）**：`rust-api/migration/src/m009_seed_password_policy.rs`（新）＋`migration/src/lib.rs`（註冊）／`rust-api/server/src/auth/password_policy.rs`（新）＋`server/src/auth/mod.rs`（掛 mod）／`rust-api/server/src/handler/system_settings.rs`（改：`validate_value_type` `number` 分支＋擴測）／`base-web/src/views/manage/system-settings/index.vue`（改：`number` render 分支）。

**ALREADY（不動）**：`entity/src/system_settings.rs`＋schema/seed（008/004/m001/m002）／get·update 端點＋`require_policy`（008）／`settings:invalidate` publish（014）／`mutate_in_txn`·審計 6 欄（005/§I.6）／`auth/password.rs`（hash/verify）／`rev3-system-settings.ts`·`SystemSetting` 型（008 wire）。

## 11. forward-compat / 下游

- **刀2 `025-user-center`**：改密碼端點 `find_all → from_settings → validate_password_complexity(policy,plain,user_name) → hash_password → 窄寫 password facade fn`（operator＝`claims.uid`、不信 body id、auth-only）；`PolicyViolation`→`backend.biz.password.*` wire i18n；前端改密碼區塊向 `getSystemSettings` 取政策動態組 rule（UX）＋後端權威把關（雙保險）；profile GET/update ＋ 手機/信箱驗證按鈕 UI 佔位。
- **未來**：政策套用到 admin 建 user/重設密碼；密碼歷史（`password_history` 表）·到期（`password_changed_at`）；弱密碼字典；首登強制改密。
- **plan-phase 接地清單**：special-char 集合確切定義（非英數 vs 明確字元集）／min≤max 跨欄處理（前端界 vs 原語行為）／prod Dockerfile `migration/src` COPY 確認／`NInputNumber` 界值／`from_settings` 對非法既存值（理論上被 D5 擋，但 defensive 預設）／setting `description` 是否日後 i18n（本刀維持與 `single_session_default` 一致＝DB 中文、不 i18n）。
