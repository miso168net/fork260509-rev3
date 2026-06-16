# C-V Contract: verification-commands（003-envelope）

> 實機驗收命令全集。rust 一律**容器內**跑（host 無 toolchain）：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠（CLAUDE.md §8.2.1）。base-web commit `--no-verify`；改 service/locale 後若 vite 沒熱載 → `restart base-web`。

## C-V-0 · rust in-crate 契約測（純型別/serde、無 DB → 一般 `cargo test`、無 `#[ignore]`）

```bash
# force-touch 防假綠 → build → test（in-crate #[cfg(test)] mod，server bin-only）
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo build -p server && cargo test -p server'
```
斷言（in-crate test 覆蓋；對照 [envelope-contract.md](envelope-contract.md) §4）：
1. 每 `AppError` 變體 →（code, key, http）對齊 13 碼矩陣（9 可發碼）。
2. `Res<T>` serde：欄序 `data`→`code`→`msg`、錯誤 `data:null` 不省略、`code` 為 string。`PageRes`：無 `pages`/`success`、空頁 `records:[]`。
3. `IntoResponse`：9 可發碼除 `4040`→404／`5003`→403 外皆 200。
4. **msg 是 key 非人話**：每變體 key 符 `^[a-z][a-zA-Z]*(\.[a-zA-Z]+)+$`（無 CJK）。
5. **reserved guard**：`7778/8889/9998/9999` 無 `AppError` 變體＝**編譯期**保證（型別層、非 runtime；test 列舉 emitted ⊆ 9 佐證）。
> ⚠️ 看到「0 passed; N filtered out」＝filter 沒命中、非綠（CLAUDE.md §8.2.1）。

## C-V-1 · curl `4040` wire 形（唯一可達後端錯誤路徑）

```bash
# dev stack up 後，打不存在路由 → .fallback → AppError::NotFound
curl -s -o /tmp/cv003-404.json -w '%{http_code}\n' http://127.0.0.1:31081/no-such-route
# 期望：HTTP 404 ＋ body {"data":null,"code":"4040","msg":"system.notFound"}
cat /tmp/cv003-404.json | jq -e '.data==null and .code=="4040" and .msg=="system.notFound"'
```
- 驗 wire 形＋去前綴 key（`4040`＝HTTP 404、msg 前端不顯示＝R3 限制、本步僅驗 wire）。

## C-V-2 · base-web typecheck ＋ component/unit（helper 命中+fallback）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T base-web \
  sh -c 'cd /app && pnpm typecheck'      # Schema 加 backend + 兩 langs 補齊（annotation 強制）須過
```
component/unit 斷言（`translateBackendMsg`）：
1. 13 固定 key（如 `auth.login.failed`）→ 當前語言譯文（zh-CN/en-US 各驗）。
2. 未知 key（如 `biz.unknown.xxx`）→ **回傳原始 key 路徑字串**（`backend.biz.unknown.xxx`、Clarifications B、vue-i18n 原生）。
3. 翻譯點：modal content（`:71`）顯翻譯後文字；onError（`:109`）generic toast 顯翻譯後文字；dedup stack 鍵＝翻譯後文字（`:64`/`:51`）。

## C-V-3 · prod target image build sanity

```bash
# 首批實質 server 碼（+serde/serde_json 直接 dep）→ 驗 prod multi-stage 無 COPY/dep 缺口
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 本刀**未新增 workspace crate**（envelope/error 入既有 server crate）→「新增 crate ⇒ prod build」紀律字面 N/A；但首批實質 server 碼＋Cargo.toml dep 變動 → 仍跑一次 prod build 防 dev bind-mount 遮缺口（rev2 教訓、spec Assumptions）。

## C-V-4 · i18n 顯示端到端（階梯、**非本刀**、登 follow-up）

- **本刀無 200-path biz endpoint** → 「翻譯後錯誤跳 modal/toast」端到端 CDP smoke **003 無法驗**（唯一可達＝C-V-1 的 `4040`、HTTP 404 不顯示）。
- **階梯**（各歸其刀 acceptance）：
  - **波 0 Auth/login 刀**：login 失敗發 `1000`＝`auth.login.failed`（本刀已鍵固定碼）→ generic toast 經 `$t` 翻譯顯示＝i18n 顯示路徑**首個自然端到端 CDP 檢核點**（fallback 路徑由 C-V-2 單元覆蓋）。
  - **波 1 system_settings 刀**：首個真 biz endpoint 發 per-entity `2222` key（如 `biz.systemSettings.*`）→ per-entity 端到端。
- **curl≠modal**：curl（C-V-1）只驗 wire 形、不等於 base-web modal/toast 對齊；端到端對齊待上述階梯 CDP（CLAUDE.md §3）。**登 follow-up backlog**。

## 出口

C-V-0~3 全綠（C-V-4 階梯登記、非本刀阻塞）＝本刀 acceptance 通過；對應 spec SC-001~008。
