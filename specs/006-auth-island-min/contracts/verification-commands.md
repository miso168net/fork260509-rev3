# C-V Contract: verification-commands（006-auth-island-min）

> 實機驗收命令全集。rust 一律**容器內**跑：`docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api <cmd>`。改 `.rs` 後先 **force-touch** 防 WSL2 `/mnt/d` stale-mtime 假綠。**rust 全程 serial**。**含 prod target image build（C-V-5、加 dep、research R-I）**。
> 預設帳號（m002 seed）：`Super`/`Admin`/`User`、密碼 `123456`；角色 `R_SUPER`/`R_ADMIN`/`R_USER_COMMON`。

## C-V-0 · server 建置綠 ＋ time-pin 判定

```bash
# ★ 加 jsonwebtoken 後第一件事：判 time real/inert
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && cargo tree -i time 2>&1 | head -20'
# 若 time 經 simple_asn1 入真 graph → cargo update -p time --precise 0.3.37 + pin simple_asn1 0.6.3
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo build -p server'
```
- `config`/`state`/`auth/{jwt,bearer,password,enforce}`/`handler/auth`/`facade/{sys_token,sys_user_role}`＋main.rs 編譯綠。
- 新 dep（jsonwebtoken/uuid/sha2/argon2-ws/casbin-ws/sea-orm-adapter-path）解析綠、time-pin 不撞 1.86 MSRV。

## C-V-1 · 純函式測（無 DB、test-first 精神）

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo test -p server auth'
```
- **JWT**：sign→verify roundtrip（claims 還原）＋過期（exp 過）reject＋壞簽（換密鑰）reject＋錯 aud reject。
- **argon2**：對已知 PHC（`Argon2::default().hash_password("123456")` 產）verify true、錯密碼 false。
- **claims 解析**：Claims serde roundtrip。
- **Casbin enforce decision seam**：embedded MODEL ＋ in-memory policy（或 seeded fixture）→ `enforce(("R_SUPER","/systemManage/deleteUser","DELETE"))==true`、`enforce(("R_USER_COMMON","/systemManage/deleteUser","DELETE"))==false`。
> ⚠️ 看到「0 passed; N filtered out」＝filter `auth` 沒命中＝非綠。

## C-V-2 · live curl 鏈（stack healthy、DATABASE_URL 自連）

```bash
# 經 front-nginx /api strip（對外 /api/auth/* → 容器內 /auth/*）；或直連 rust-api :31081/auth/*
BASE=http://127.0.0.1:31080/api   # front-nginx；或 http://127.0.0.1:31081 直連（無 /api）
# (a) login 成功
curl -fsS -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}'
#   → 200 信封 code "0000" data {token, refreshToken}
# (b) getUserInfo（bearer）
TOKEN=...   # 從 (a) 取
curl -fsS "$BASE/auth/getUserInfo" -H "Authorization: Bearer $TOKEN"
#   → code "0000" data {userId(string), userName, roles[含 R_SUPER], buttons[非空]}
# (c) login User → userName=User01 alias
curl -fsS -X POST "$BASE/auth/login" -H 'Content-Type: application/json' -d '{"userName":"User","password":"123456"}' # 取 token → getUserInfo → userName=="User01"
# (d) 1000 壞密碼 / 不存在帳號（不可區分）
curl -s -X POST "$BASE/auth/login" -d '{"userName":"Super","password":"WRONG"}'      # code "1000" msg "auth.login.failed"
curl -s -X POST "$BASE/auth/login" -d '{"userName":"NOPE","password":"x"}'           # 同 code "1000" 同 msg（不洩存在）
# (e) 3333 bearer fail（缺/壞 token）
curl -s "$BASE/auth/getUserInfo"                                                       # code "3333"
curl -s "$BASE/auth/getUserInfo" -H "Authorization: Bearer bad.token.x"               # code "3333"
# (f) 7777 single-session（同帳號二次 login、舊 token 被踢）
T1=$(login Super);  T2=$(login Super);  curl -s "$BASE/auth/getUserInfo" -H "Authorization: Bearer $T1"  # code "7777"（舊）
curl -fsS "$BASE/auth/getUserInfo" -H "Authorization: Bearer $T2"                      # "0000"（新）
# (g) psql 驗 sys_token 寫入 + current_session_id 更新
psql "host=127.0.0.1 port=35432 ..." -c "SELECT count(*) FROM sys_token WHERE user_id=1; SELECT current_session_id FROM sys_user WHERE id=1;"
```
- 對應 SC-001（login/1000）／SC-002（getUserInfo roles/buttons/alias）／SC-003（3333）／SC-004（7777）／SC-008（atomic 寫入）。
- **5003（permission-denied）**：006 無 policy-governed 業務端點（getUserInfo auth-only）→ 5003 由 **C-V-1 enforce seam 測**證（R_USER_COMMON deny `/systemManage/deleteUser`），curl 軌不另構造合成端點（避免 scope creep）。

## C-V-3 · CDP（§3.6 i18n 端到端首檢核）

```text
base-web 瀏覽器（front-nginx :31080）→ 登入頁輸錯密碼 → 送出 →
  攔截器收 code "1000"/msg "auth.login.failed" → translateBackendMsg → $t("backend.auth.login.failed") →
  toast 顯示在地化「用户名或密码错误」（zh-cn）/「Incorrect username or password」（en-us）。
```
- CDP node script（`tests/000-.../scripts/`）驅動：填 Super/錯密碼 → submit → 斷言 toast 文字＝在地化字串（非 raw key）。對應 SC-006。
> i18n 譯文＋translateBackendMsg＋攔截器接線皆 003 已 ship → 006 只需後端發 1000=auth.login.failed（既有變體）。

## C-V-4 · entity_access_lint 守恆綠

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api \
  sh -c 'cd /app && find server/src server/tests -name "*.rs" -exec touch {} + && cargo test -p server --test entity_access_lint'
```
- 既有 004 守恆續綠：`auth/`/`handler/`/`config`/`state` 零 path-root `entity::`（entity 存取全在 `model/facade/`）。對應 FR-007 facade 唯一管道延續。
> ⚠️「0 passed; N filtered out」＝非綠。

## C-V-5 · prod target image build（★ 加 dep 紀律、R-I）

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- prod multi-stage（builder COPY 全 4 crate Manifest+Source、`--locked`）含新 dep（jsonwebtoken/uuid/sha2/casbin/sea-orm-adapter）編譯綠；time-pin 在 prod toolchain（rust:1.86）亦不撞。
- model.conf 用 embedded `from_str`（adapter examples 不 COPY、無 from_file 缺檔坑）。對應 SC-007（無回歸）＋ R-I。
> dev bind-mount 遮 prod 編譯破口 → **必跑此條**、勿只靠 C-V-0 dev build（004 教訓）。

## C-V-6 · SC-007 零回歸 ＋ SC-009 範圍核

```bash
curl -fsS http://127.0.0.1:31081/health    # 回 "ok"（既有探針不變）
cd rust-api && git diff --name-only 004後..HEAD | grep -iE "migration|entity/|\.sql" && echo "⚠️違規" || echo "✅ 零 migration/entity"
# diff 確認：零 base-web 變動、零 i18n、零 compose/secret 變動、零新 binary
```
- 對應 SC-007（/health 零回歸、零 schema/migration）／SC-009（零 refresh 端點/menu/事件審計/多會話設定/alt-login）。

## 出口
C-V-0~6 全綠＝本刀 acceptance 通過；對應 spec SC-001~009。**含 prod build（C-V-5、加 dep）**。
