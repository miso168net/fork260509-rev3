# Quickstart 驗證指南: 019-login-lockout

> 端到端驗證「登入失敗節流」端到端可運作。完整 acceptance 指令見 [contracts/verification-commands.md](contracts/verification-commands.md)；本檔為 run/驗證導引、不含實作碼。

## 前置

```bash
cd /mnt/d/AnewSpaces/x_Project/fork260509-rev3
export DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
$DC up -d --wait          # 冷卷首啟 flap 屬正常、待穩重跑（CLAUDE.md §8.2.1）
curl -fsS :31081/health   # rust-api 200
```

> 已 build：dev rust-api 走 `cargo watch` 自動重編；改碼後確認 log 有重編完成 + 新行為再驗（§8.2.1 stale-mtime/force-touch 坑）。

## 場景 1 — per-user 鎖（FR-001、SC-001、US1）

```bash
U="lockout_probe_$RANDOM"
for i in $(seq 1 5); do curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"$U\",\"password\":\"x\"}"; echo; done
# 預期：前 5 次 code "1000"
curl -s :31081/auth/login -H 'Content-Type: application/json' -d "{\"userName\":\"$U\",\"password\":\"x\"}"; echo
# 預期：第 6 次 code "2222"、msg "auth.login.locked"
```
**通過**：第 6 次回 2222；換帳號仍 1000（隔離）。

## 場景 2 — 防枚舉（FR-011/015、SC-004、US1-3）

不存在帳號連續嘗試 → 一樣鎖、一樣訊息（與真實帳號無從區分）。對真實帳號（如 `Admin`，**勿用會擋到後續測試**——測完需等窗滑出或用拋棄式）與不存在帳號各跑場景 1，比對：除「帳號是否存在」外，回應碼/msg/是否被擋一致。

## 場景 3 — per-ip 鎖（FR-002、SC-002、US2）

見 [C-V-4](contracts/verification-commands.md)：同來源跨 ≥20 個拋棄式帳號各 1 次失敗 → 第 21 次任一帳號 2222。**用 test-only 短窗 const 跑**、免把測試 IP 對全帳號鎖 15 分。

## 場景 4 — 滑動窗自動解 + sticky（FR-006/008、SC-003/007、US3）

純函式 + in-crate `#[ignore]` live（[C-V-1](contracts/verification-commands.md)/[C-V-6](contracts/verification-commands.md)）：
- 寫舊失敗列（`created_at` 窗外）→ count 不計 → 未鎖（自動解、不等 15 分）。
- gated 列（鎖中嘗試）亦 success=false 寫入 → count 含之 → 持續攻擊不解（sticky）。

## 場景 5 — fail-OPEN（FR-010、SC-006、US3）

count query 失敗（DbErr）→ gate 視為 0 → 照常進 login_inner（不擋合法登入）。由 in-crate live 或注入故障驗；屬縱深防禦，登入入口可用性優先。

## 場景 6 — 鎖中 toast 在地化（FR-013、US1）

CDP（[C-V-7](contracts/verification-commands.md)）：經 `:31080` 對拋棄式帳號失敗達門檻 → login form 跳在地化 toast（zh-cn/en-us 各驗）。curl 直送看不到在地化、必走 browser 軌。

## 零回歸（FR-014）

```bash
$DC exec -T rust-api sh -c 'cd /app && cargo test -p server -- --test-threads=1'   # 既有 unit 全綠
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'                              # i18n Schema 對齊
curl -s :31081/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}'   # 0000（未污染 IP/窗）
```

## 通過判準
[contracts/verification-commands.md](contracts/verification-commands.md) C-V-0~9 全綠；3 US / 15 FR / 7 SC 覆蓋；13 碼矩陣不變。
