# Quickstart: 003-envelope 驗證指南

> 從零驗證本刀（統一信封＋msg-i18n key 規約）端到端可運作。完整斷言＝[contracts/verification-commands.md](contracts/verification-commands.md)；型模型＝[data-model.md](data-model.md)；契約＝[contracts/envelope-contract.md](contracts/envelope-contract.md)＋[contracts/i18n-key-convention.md](contracts/i18n-key-convention.md)。

## 前置

- 001 dev stack 可起（`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait`）。
- rust 一律容器內跑（host 無 toolchain）；改 `.rs` 先 force-touch（CLAUDE.md §8.2.1）。

## 驗證流程（5 步）

1. **rust 契約測**（C-V-0）：容器內 `cargo build -p server && cargo test -p server`（先 force-touch）→ in-crate `#[cfg(test)]` 全綠：碼/key/http 對齊 13 碼矩陣、`Res`/`PageRes` serde 形、msg-是-key（無 CJK）、emitted ⊆ 9 可發碼、reserved 4 碼型別層不存在（編譯期）。

2. **curl 信封形**（C-V-1）：`curl -w '%{http_code}' http://127.0.0.1:31081/no-such-route` → **HTTP 404** ＋ `{"data":null,"code":"4040","msg":"system.notFound"}`（唯一可達錯誤路徑；msg＝去前綴 key）。

3. **base-web typecheck**（C-V-2）：容器內 `pnpm typecheck` 過——確認 `app.d.ts` Schema 加 `backend` 後、兩 langs（zh-cn/en-us）`backend` 物件補齊（`: App.I18n.Schema` annotation 編譯強制）。

4. **base-web helper 行為**（C-V-2）：component/unit——`translateBackendMsg('auth.login.failed')` → 當前語言譯文；`translateBackendMsg('biz.unknown.x')` → 回傳 `backend.biz.unknown.x`（原始 key 字串、Clarifications B、vue-i18n 11.4.2 原生未命中）。

5. **prod build sanity**（C-V-3）：`docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api` 成功（首批實質 server 碼＋serde 直接 dep、防 prod COPY/dep 缺口）。

## 預期結果（對應 SC）

| 步 | 對應 SC | 通過 |
|---|---|---|
| 1 | SC-001/002/003/004/008 | 信封形+碼集合+http+msg-是-key+reserved 不發 |
| 2 | SC-001/002 | `4040` wire 形+去前綴 key |
| 3 | SC-005 | Schema+雙語 backend 命名空間齊（typecheck 過） |
| 4 | SC-005/006 | 固定 key 命中譯文 + 未知 key graceful（顯原始 key） |
| 5 | SC-007 | prod build 成功、既有 stack 零回歸 |

## 不在本刀（階梯、見 C-V-4）

- 「翻譯後 biz 錯誤跳 modal/toast」端到端 CDP：無 biz endpoint → 波 0 Auth/login 刀（`1000` toast）首檢、波 1 system_settings（per-entity `2222`）per-entity。登 follow-up。
- `4040`/`5003` 之前端 msg 顯示：今日 axios native error 不讀 envelope msg（R3 限制、不修）。
