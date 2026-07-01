# Phase 0 Research: 024-password-policy

> 決策格式：**Decision** / **Rationale** / **Alternatives**。皆 act-on-code 接地（grounding workflow `wf_3fb30f20`，4 路：backend/frontend/constitution/deploy）。brainstorm 決策見 `docs/superpowers/024-password-policy.md` §3（D1~D9）；本檔補實碼細節與 clarify-deferred 定案。

## R1 — 特殊符號集定義（spec FR-007 deferred 定案）

- **Decision**：「特殊符號」＝**ASCII 可列印、非英數、非空白**字元 —— 即 OWASP 常見標點全集 `` !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~ ``。後端 predicate：`c.is_ascii_graphic() && !c.is_ascii_alphanumeric()`（等價集合、不含空白/控制字元）。**權威驗證在後端**；前端**零新常數**（本刀前端不驗密碼，那是刀2）。
- **Rationale**：前端接地確認 base-web **無**任何既有特殊符號慣例可對齊（`constants/reg.ts` 的 `REG_PWD=/^\w{6,18}$/` 反而排斥特殊字元；grep `specialChar/SPECIAL/symbol` 零命中）。OWASP ASVS 標點全集為業界對齊、涵蓋最廣、predicate 最簡（單一 `is_ascii_graphic && !alnum`）。
- **Alternatives**：①固定小集合 `!@#$%^&*` → 太窄、拒收常見符號；②含空白為特殊 → 語意爭議、排除；③含 Unicode 標點 → 過寬且 `is_ascii_graphic` 已界定清楚，YAGNI。

## R2 — `number` 型驗證範圍（spec FR-004 deferred 定案）

- **Decision**：`validate_value_type` 對 **bare `"number"`**（seed value_type 無冒號）以**整串比對** early-return（**不經 `split_once`**——否則 `Some(("number", _))` arm 對無冒號的 `"number"` 永不命中、靜默放行非法值）：`value.parse::<u32>()` 成功且 **`1..=1024`** → `Ok`；否則 `Err(AppError::Biz(Cow::Borrowed("biz.systemSettings.invalidValue")))`（2222）。前端 `NInputNumber :min="1" :max="1024"`。
- **Rationale**：正整數下限 1（長度/次數無 0 意義）；上限 1024 遠寬於任何合理密碼長度、純防呆。復用既有 biz 碼＝零新 i18n key。補掉 008 明文承認的 `number` passthrough 缺口（`handler/system_settings.rs` 註解「其他型…保守放行」）。
- **Alternatives**：無上限 → 失防呆；`i64`/負數容忍 → 長度負值無意義；每 key 專屬範圍（min 6..64 / max …）→ 跨欄語意、per-key 驗證拿不到 context（見 R3），YAGNI。

## R3 — min>max 誤設處理（spec edge case 定案）

- **Decision**：後端 **per-key 獨立驗證**（`update_setting` 一次改一鍵、無跨欄 context）；`validate_password_complexity` 對 `min>max` 天然 **reject-all**（任何密碼長度無法同時 `>=min` 且 `<=max`→ 回 `TooShort`/`TooLong`）。前端 `NInputNumber` 設 `:min/:max` 界為輕量防呆。**跨欄硬驗延後**（非本刀）。
- **Rationale**：per-key update 端點無兩鍵同時在手；reject-all 是安全 fallback（不當機、不靜默放行）。跨欄驗證需重構 update 端點收整組政策、超出本刀範圍。
- **Alternatives**：update 時讀另一鍵做跨欄驗 → 改動 update 端點語意（008 端點通用於所有 KV、不宜為密碼特化）、破壞單鍵契約，否決。

## R4 — 政策項預設值（brainstorm D4 定案）

- **Decision**：`password_min_length=8`、`password_max_length=64`、`password_require_uppercase/lowercase/digit/special=off`、`password_forbid_username=off`（全保守）。
- **Rationale**：刀1 原語 dormant（無 enforce）、預設不影響登入；admin 自行 opt-in。刀2 上線後 enforce 只作用於**新**密碼（既有 argon2 hash 登入不受影響）。
- **Alternatives**：預設開啟部分要求 → 刀2 上線可能意外擋既有密碼變更流程、且與「導入零回歸」相悖，否決。

## R5 — `from_settings` 輸入型（entity_access_lint 硬約束、load-bearing）

- **Decision**：`password_policy::from_settings` 吃**非-entity** 鍵值對（`&[(&str, &str)]` 或等價 iterator），**非** `entity::system_settings::Model`。消費者（刀2 change-password handler）從 `facade::system_settings::find_all()` 的 `Vec<Model>` **讀欄位**建鍵值對（type-inferred、不寫 `entity::` 字面）再餵入。`password_policy.rs` 全檔零 `entity::`。
- **Rationale**：接地確認 `entity_access_lint`（`server/tests/entity_access_lint.rs`）對 `model/facade/` **外**任何 `entity::` path-root **build-fail**；`find_all` 回 `Vec<entity::…::Model>`。若 `from_settings` 簽名或內文沾 `entity::` 即 lint 紅。以鍵值對為介面同時使純測極易（`from_settings(&[("password_min_length","8"), …])`）。
- **Alternatives**：①吃 handler 的 `SystemSettingItem` DTO → `auth` 逆向依賴 `handler`（層次倒置），否決；②facade 新增「回 DTO」fn → 多餘（消費者 map 即可）、YAGNI。

## R6 — `PolicyViolation` 形與非短路（spec FR-006 定案）

- **Decision**：`enum PolicyViolation { TooShort, TooLong, NeedUppercase, NeedLowercase, NeedDigit, NeedSpecial, SameAsUsername }`；`validate_password_complexity(&policy, plain, user_name) -> Result<(), Vec<PolicyViolation>>` **回全部違規**（逐條檢、非遇第一項就停）。長度用 `plain.chars().count()`（字元數、非位元組）、邊界含（`>=min && <=max`）；`SameAsUsername` ＝`plain.eq_ignore_ascii_case(user_name)`。
- **Rationale**：spec FR-006/SC-003 要求「一次列出所有未滿足條件」；刀2 wire 把 `Vec<PolicyViolation>` 映 `backend.biz.password.*` 一次回報 UI。純函式＝TDD 核心、逐 knob red→green。
- **Alternatives**：短路回首個違規 → UI 只能逐次提示、體驗差且違 FR-006，否決。

## R7 — 不建 runtime store（brainstorm D2 重申）

- **Decision**：政策 **load-on-demand**（刀2 每次改密碼 `find_all → from_settings` 現查 DB）；**不建 `AppState` 快取、不加 `settings:invalidate` watcher**。
- **Rationale**：密碼政策僅「改密碼」時讀（罕見、非熱路徑），不同於 `single_session_default` 每次登入讀。load-on-demand 永遠最新、零快取複雜度（Simplicity）。既有 `update_setting` 對 password key 仍 publish `settings:invalidate`＝無訂閱者 no-op（接地確認 watcher 只重載 `single_session_default`）。
- **Alternatives**：仿 single_session_default 建 AppState 快取＋watcher → 為罕讀政策付快取/失效複雜度，over-engineering，否決。

## R8 — 前端 number 分支存檔範式（naive gotcha）

- **Decision**：新增 `handleNumberUpdate(item, value)` 鏡像既有 `handleToggle`（改值→`fetchUpdateSystemSetting(key, String(value))`→toast `common.updateSuccess`→`getSettings()` refetch）。template `v-else-if item.valueType==='number'` → `<NInputNumber :value="Number(item.settingValue)" :min="1" :max="1024" :step="1" :update-value-on-input="false" @update:value="v => handleNumberUpdate(item, v)" />`。value 為 null（清空）時忽略。
- **Rationale**：接地發現 naive `NInputNumber` 預設 `update-value-on-input=true`（逐字觸發）→ 每敲一位打一次 API；`:update-value-on-input="false"` 使只在 blur/Enter/step 提交，對齊 enum「一次 commit 一次 update+refetch」語意。`Number()`/`String()` 轉換使 `SystemSetting.settingValue: string` 型零改。
- **Alternatives**：`@blur` 讀值存 → 可行但與 `@update:value`+false 等效、後者更貼齊 handleToggle 的 `@update:value` 風格；v-model 綁 store（theme-drawer 範式）→ 無 API 呼叫、不適 KV 頁。

## R9 — MODAL-WIRING gate（user 拍板）

- **Decision**：改 `system-settings/index.vue` 加 number 分支＝**落既有 MODAL-WIRING (e)**（user 拍板 A、2026-07-01）；constitution 不 bump、DECISIONS §1 釐清列収刀回填。
- **Rationale**：獨立 constitution grounding 判「補完 008 (e) 頁 by-`value_type` render dispatcher 之一臂」（單頁、純加、復用既有 wrapper、不動共用元件、零新 key），實質不同於 023 跨 7 頁新排序能力〔(f)〕。user 親決採「(e) 涵蓋」讀法。
- **Alternatives**：新用途 (g) amendment（bump v1.3.0）→ user 未選；治理若偏好逐 pattern 命名才需，本刀採 (A)。

## R10 — m009 migration 範式（brainstorm D1/D3 定案）

- **Decision**：`m009_seed_password_policy.rs` **seed-only**，仿 `m002_rev2_seeds` system_settings 片段：up＝7 列 `INSERT INTO system_settings (setting_key, setting_value, value_type, description) VALUES (...) ON CONFLICT (setting_key) DO NOTHING`；down＝`DELETE FROM system_settings WHERE setting_key IN (…7 keys…)`。骨架仿 `m008`（`#[derive(DeriveMigrationName)] pub struct Migration; impl MigrationTrait`）。註冊 `migration/src/lib.rs`：`mod m009_seed_password_policy;`（mod 區末）＋`Box::new(m009_seed_password_policy::Migration)`（vec 末）。**無 casbin seed**（D7、零新 gated route）。
- **Rationale**：接地確認 seed-only migration 有先例（m002/m004）；整目錄 COPY（`Dockerfile.rust-api.txt:43`）→ m009 自動入 prod image；migrate gate（`migration up`）自動套。up→down→up 可逆（三守恆）。
- **Alternatives**：把 seed 併進 m002 → 改既有 migration 破壞既落 migration 不可變原則，否決；新建表 → over-engineering（D1）。

## R11 — 驗證原語消費（brainstorm D9：刀1 dormant）

- **Decision**：本刀 `validate_password_complexity`／`from_settings` **僅單元測試證正確**、**不接任何 live 消費者**；刀2 `025-user-center` change-password handler 接線（`find_all → from_settings → validate_password_complexity → hash_password → 窄寫 password facade fn`）。
- **Rationale**：user 拍板①「政策先行」。刀1＝設定面（admin 可調、可測）＋已測待接原語；live enforce＝刀2。接地確認 `auth/password.rs`（hash/verify）與 policy 完全解耦、無交叉依賴。
- **Alternatives**：刀1 就接一個 dry-run 驗證端點 → 新增端點、破壞「零新端點」且刀2 才有真消費場景，YAGNI。

## 部署/CI 接地小結（非 constitution 對照項）

- **prod image build**：`deploy/Dockerfile.rust-api.txt:43` **整目錄 COPY** `migration/src` → m009 自動含入；本刀**無新 workspace crate**（`rust-api/Cargo.toml` members 6 個不變）→ 不觸發「新 crate→四處 COPY」紀律。「prod-image-build 強制紀律」經接地確認**非 constitution 條款**（brainstorm §7 誤列）、屬 CI/plan checklist。
- **migrate gate**：`docker-compose.prod.yml` migrate service `command:["migration","up"]` + `docker-compose.yml` `condition: service_completed_successfully` → m009 註冊 lib.rs 後由 gate 自動執行。
