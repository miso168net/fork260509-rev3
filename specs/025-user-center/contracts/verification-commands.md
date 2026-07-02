# Verification Commands (C-V): 025-user-center

> rust 命令一律容器內；live 測 `--test-threads=1` serial。`DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"`；`EXEC="$DC exec -T rust-api"`。改 `.rs` 後 force-touch（避 stale-mtime）。加 i18n 鍵後 CDP 前先 `$DC restart base-web`（vite stale-locale）。DB 連線 `postgres://soybean:***@…/soybean_admin_rust`（`deploy/secrets/database_url`）。token 由 Super/123456 或既有 CDP 腳本取。設 `API=http://127.0.0.1:31080/api`、`T=<token>`。

## C-V-1 · live changePassword（消費 024）→ FR-005~009 / SC-002/003
```bash
# happy：舊密對 + 新密合規（先確認政策放行）→ 200、psql password PHC 變、新密可 login
curl -fsS "$API/userCenter/changePassword" -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  -d '{"oldPassword":"123456","newPassword":"<合規新密>","confirmPassword":"<合規新密>"}'
# 舊密錯→2222 biz.password.oldMismatch；confirm 不符→2222 biz.password.mismatch；新密違政策→2222 biz.password.tooWeak
# psql 驗 password 欄變、sys_operation_log 末列 operator_id=自己、payload password=<redacted>
```

## C-V-2 · live updateProfile → FR-002/003/004 / SC-001/007（operator=claims.uid、不信 body id）
```bash
curl -fsS "$API/userCenter/updateProfile" -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  -d '{"userGender":1,"nickName":"我的昵称","userPhone":"13800000000","userEmail":"me@x.com"}'
$DC exec -T postgres psql -U soybean -d soybean_admin_rust -tAc \
  "SELECT nick_name,user_gender,user_phone,user_email,updated_by FROM sys_user WHERE id=<自己id>"   # 值變、updated_by=自己
# 反證：user_name/password/status 不變（psql 比對）
```

## C-V-3 · getProfile（含 created/updated 語意；as-built U-polish 校正）→ FR-001/011/012 / SC-006
```bash
curl -fsS "$API/userCenter/getProfile" -H "Authorization: Bearer $T"
# 回 userName/roles[code]/gender/nick/phone/email/createdAt/createdBy/updatedAt/updatedBy
# createdBy/updatedBy 語意（共用 classify_operator）：NULL→"system"；==自己→"self"；其他→"admin"
# updatedAt＝raw 最後修改時間（rfc3339）；從未修改→null
# 反證：回應【不含】任何 operator uid/姓名
```

## C-V-4 · CDP（4 塊 + 動態 rule + 佔位 + i18n；as-built U-polish 版面）→ SC-001/004/005/006
- restart base-web 後 super 登入 → `/user-center`：見 4 塊【修改密码→邮箱→手机→基本资料】（塊狀 2 欄、標題左＋保存右）。
- 基本资料：账号/角色/创建时间/修改时间＝**唯讀純文字**（非輸入框）；创建/修改时间渲染三情境（見 contract §2 表）：全 NULL→`（系统创建）`+`未修改`、admin→`（管理员创建）`+`（管理员修改）`、self→bare 時間無標註。改昵称/性別 → 該塊保存【只送自己欄位】→ refetch 持久。
- 修改密码：验证方式 radio（●旧密码／○邮箱验证码／○手机验证码〔佔位〕）；旧密码路徑真改密（動態 rule 隨政策、admin 改 min_length 後前端 rule 反映）；選 邮箱/手机验证码 + 保存 → toast「功能建置中」。
- 邮箱/手机：值 input（col1）＋發送驗證碼/驗證碼/驗證（col2 佔位、點擊 toast 建置中）；值仍可改可存（各塊保存只送自己欄位）。
- 斷言 i18n 非 raw key（`page.userCenter.*`、`backend.biz.password.*` 皆譯文）。

## C-V-5 · 三守恆 + AS_BUILT + typecheck → 守恆
```bash
$EXEC sh -c 'cd /app && cargo test -p server --test entity_access_lint'      # facade-only（含 2 窄寫 fn）
$EXEC sh -c 'cd /app && cargo test -p server --test endpoint_coverage_lint'  # AS_BUILT 54、4 auth-only 無 seed 需求
$EXEC migration down && $EXEC migration up                                   # 零 migration、僅確認未破
$DC exec -T base-web sh -c 'cd /app && pnpm typecheck'
```

## C-V-6 · 零回歸 → SC-008
- `getUserInfo`（仍 4 欄）/login/enforce 不變；既有 manage 頁不破；password_policy 喚醒後 024 system-settings 政策設定仍運作。

## C-V-7 · prod image build（無新 crate）→ build 面
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api
```
- 確認 `handler/user_center.rs`＋sys_user facade 2 窄寫 fn＋喚醒的 password_policy 編入 prod target。

---
**SC 對映**：SC-001→C-V-2/C-V-4；SC-002/003→C-V-1；SC-004→C-V-4；SC-005→C-V-4；SC-006→C-V-3/C-V-4；SC-007→C-V-1/2（operator=自己、不信 body id）；SC-008→C-V-5/C-V-6。
