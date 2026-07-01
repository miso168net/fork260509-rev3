# Verification Commands (C-V): 024-password-policy

> 約定：rust 命令一律容器內（host 無 toolchain）；live 測 `--test-threads=1` serial。
> `DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`；`EXEC="$DC exec -T rust-api"`。
> 改 `.rs` 後先 `$EXEC sh -c 'cd /app && find server/src -name \"*.rs\" -exec touch {} +'`（避 WSL2 stale-mtime 假綠）。
> 具體 DB 連線 / token 取得由 implementer 依 `deploy/secrets/*` 與既有 CDP 腳本（`tests/000-.../scripts/`）填實。

## C-V-1 · `validate_password_complexity` 純測（TDD 核心）→ FR-005 / SC-003

```bash
$EXEC sh -c 'cd /app && cargo test -p server --lib password_policy -- --nocapture'
```
- 逐 knob red→green：長度下界（`chars().count() < min`→TooShort）、上界（>max→TooLong）、缺各字元類（require_* on 但無對應類→NeedX）、密碼＝帳號（大小寫不敏感→SameAsUsername）、全通過（Ok）、**回全部違規非短路**（min>max ⇒ 同時 TooShort+TooLong）。
- 特殊符號（R1）：`"abc!"` 含 special、`"abcd"` 不含（require_special on 時後者 NeedSpecial）。

## C-V-2 · `from_settings` 純測 → FR-006 / SC-004

- 同 `password_policy` test binary：`on`→true / `off`/缺鍵→false；`number`→usize / 缺鍵→預設（min=8,max=64）；不可解析→預設。

## C-V-3 · `validate_value_type` number 分支純測（擴既有 `value_type_tests`）→ FR-004 / SC-002

```bash
$EXEC sh -c 'cd /app && cargo test -p server --lib value_type_tests'
```
- 合法 `"12"/"1"/"1024"`→ok；`"abc"/"0"/"-1"/"1025"/""`→Err、`err.code()=="2222"`、`err.key()=="biz.systemSettings.invalidValue"`。

## C-V-4 · Live curl/psql（super）→ FR-002/FR-003 / SC-001/SC-002

前置：以 Super/123456 登入取 access token（`POST /api/auth/login`）。設 `T=<token>`、`API=http://127.0.0.1:31080/api`。

```bash
# (a) GET 回含 7 password_* 列
curl -fsS "$API/systemManage/getSystemSettings" -H "Authorization: Bearer $T" | \
  grep -o 'password_[a-z_]*' | sort -u        # 期望 7 個 key

# (b) 合法改值持久
curl -fsS "$API/systemManage/updateSystemSetting" -H "Authorization: Bearer $T" \
  -H 'Content-Type: application/json' -d '{"settingKey":"password_min_length","settingValue":"12"}'
$DC exec -T postgres psql -U <user> -d <db> -tAc \
  "SELECT setting_value FROM system_settings WHERE setting_key='password_min_length'"   # 期望 12

# (c) 非法值→2222、值不變
for v in abc -1 0 9999; do
  curl -fsS "$API/systemManage/updateSystemSetting" -H "Authorization: Bearer $T" \
    -H 'Content-Type: application/json' -d "{\"settingKey\":\"password_min_length\",\"settingValue\":\"$v\"}"
done      # 每筆期望 {"code":"2222","msg":"biz.systemSettings.invalidValue",...}；psql 驗值仍 12
```

## C-V-5 · CDP browser（curl≠modal）→ SC-001

- Super 登入 → 導航 `/manage/system-settings`（複用 `tests/000-.../scripts/cdp-nav.mjs`）。
- 斷言：頁面 **5 個 NSwitch + 2 個 NInputNumber**（`document.querySelectorAll('.n-input-number').length === 2`、switch ≥ 5）。
- 操作：改 `password_min_length` 數字欄（blur 提交）+ 切一個 `password_require_*` 開關 → refetch 後值持久（重新 dump 驗）。

## C-V-6 · 三守恆 + typecheck → SC-005

```bash
$EXEC sh -c 'cd /app && cargo test -p server --test entity_access_lint'      # password_policy.rs 零 entity::
$EXEC sh -c 'cd /app && cargo test -p server --test endpoint_coverage_lint'  # 零新 route、registry 不變
$EXEC migration down && $EXEC migration up                                   # m009 up→down→up 可逆
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'
```

## C-V-7 · 零回歸 → SC-006

- `single_session_default` 開關仍運作（GET 有該列、toggle 生效）。
- `/auth/login`、`/auth/getUserInfo`、enforce 不變（既有 smoke）。
- base-web 既有 system-settings 頁 enum 開關列不破。

## C-V-8 · Prod image build（輕、無新 crate）→ build 面

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認 `m009_seed_password_policy.rs`（整目錄 COPY `migration/src`、`Dockerfile.rust-api.txt:43`）+ `password_policy.rs` 編入 prod target；migration binary 含 m009。

---

**SC 對映**：SC-001→C-V-4(a)/C-V-5；SC-002→C-V-3/C-V-4(c)；SC-003→C-V-1；SC-004→C-V-2；SC-005→C-V-6；SC-006→C-V-7。
