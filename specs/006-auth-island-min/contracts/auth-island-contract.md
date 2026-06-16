# Contract: Auth 島最小段（006 落定、跨 feature 權威）

> 本刀建立的不變式，後續 Auth/Token/Session 合刀（波3）、業務端點刀（波2+）、Menu 刀（波2）繼承。權威＝DESIGN §8.3／§4.1/§4.3／§5.3／§7.3／constitution §I.1/§I.3/§I.5/§I.7。

## 1. runtime 骨幹不變式
1. **AppState 單例**：`{ db: DatabaseConnection, jwt: JwtConfig, enforcer: Arc<RwLock<Enforcer>> }`；後續刀於此擴充（Redis/settings store 等）、不另起平行 state。
2. **config `_FILE` 優先**：secret 一律 env 直值 → `*_FILE`(讀檔) → fallback；拒 `change-me`、長度 ≥32。secret 接線 001 已 provisioned（compose+deploy/secrets）、消費刀只讀。
3. **boot enforcer**：`SeaOrmAdapter::new(db)` → `Enforcer::new(from_str(MODEL), adapter)` → `load_policy()`；policy 全量載入。reload/pub-sub invalidate＝波3 policy governance（本刀 boot 載一次）。

## 2. JWT / token 不變式
1. **HS256、兩把密鑰**：access 簽 `jwt_secret`、refresh 簽 `refresh_token_secret`；claims `{uid,sid,jti,rotation_chain,roles,iss,aud,exp,iat}`。
2. **claims.roles 僅 hint**：enforce/getUserInfo **一律 DB-fresh** 查 role（claims roles 不作授權依據、防角色過期漂移）。
3. **token_hash＝sha256(refresh)**（unique lookup、§4.1 forward-compat）；**非** argon2。`rotation_chain`/`used_at=NULL` forward-compat、本刀不 rotate。
4. **verify fail-CLOSED**：缺/壞簽/exp/aud → 3333（TokenExpired）。

## 3. enforce 不變式（§5.3、R-C）
1. **casbin model＝3-tuple RBAC**（sub/obj/act）；policy `v0=role / v1=obj / v2=act`（endpoint act=HTTP method｜menu='menu'｜button='button'）、v3-v5 空。model embedded `from_str`（不 from_file）。
2. **enforce_mw 通用 gate**：bearer（3333）→ is_current（7777）→ Casbin `enforce((role,path,method))`（5003、HTTP 403）。auth-only route（如 getUserInfo）跳過 policy 步。
3. **buttons**：getUserInfo 對 user roles `get_filtered_policy` 篩 `v2='button'` 取 v1（去重）；seed 確有 button policy（非 stub）。
4. **後續業務端點**：波2+ 於 router 掛 enforce_mw、policy 走 seeded `casbin_rule`；新增端點＝加 policy（migration/seed）+ 掛 mw、不改 enforce_mw 本體。

## 4. single-session 不變式（§4.3 first-mount、§I.7 凍結）
1. **pointer 真相在 DB**：`sys_user.current_session_id`；login `set_pointer(sid)` 永遠執行。
2. **is_current fail-OPEN**：讀 pointer 失敗 → 放行（不誤踢）；pointer != claims.sid → 7777。
3. **方向凍結**：is_current fail-OPEN（可用性）vs bearer verify fail-CLOSED（安全）——不得搞反（§I.7）。
4. **波3 擴充**：session_policy 三態 × runtime session_mode 熱切換在 006 gate 之上加 gating；8888（refresh 鏈撤）＝波3 refresh 端。本刀無條件跑 gate、不 bake session_mode。

## 5. login 原子性 / 審計不變式
1. **login 寫原子**：`set_pointer` + `sys_token` insert 綁同一 **plain** `DatabaseTransaction`（同成同敗）。
2. **login 非 op-log**：login 非 operator-attributed 業務 mutation → **不**經 005 `mutate_in_txn`；事件審計（誰幾時自哪 IP 登入）＝007 overlay（`sys_access_log`/`sys_login_attempt`）。
3. **1000 collapse**：帳號不存在／停用／密碼錯誤 → 同一 `LoginFailed(1000)`、msg `auth.login.failed`（不洩帳號存在）。

## 6. wire 不變式（§I.1/§I.3、R-E）
1. **DTO 對齊 base-web**：`LoginToken{token,refreshToken}`／`UserInfo{userId,userName,roles,buttons}`；camelCase（serde rename）。
2. **userId＝string**（i64→string 序列化邊界、2^53 fail-loud 守衛、⚠️r）。
3. **userName＝nick_name**（User→User01 alias 自然；nick_name null → fallback user_name）。
4. **envelope/碼**：遵 003 凍結（`Res{data,code,msg}`、business error HTTP 200、5003→403、4040→404）；1000/3333/7777/5003 用既有 `AppError` 變體（003 已建）。

## 7. error 不變式
1. **`From<DbErr>`**：本刀唯一新增 error 接線（DbErr→`Internal`/5000）；23505 unique-violation→2222（`Biz`）留波2 CRUD（login 不撞）。
2. **i18n**：msg 載穩定 key（`auth.login.failed` 等）、前端 `translateBackendMsg`+`$t` 譯（003 已 ship、006 零變動）。

## 8. 本刀邊界（OUT）
- 無 `/auth/refreshToken` 消費端點＋rotation/reuse＋cleanup-job（波3）；login 仍簽發 refresh 字串。
- 無 `/route/getUserRoutes`＋menu enforce＋dynamic route mode flip（波2 Menu）。
- 無 login 事件審計＋audit_ctx＋xdb（007）；無 Redis（波3）；無 login lockout（⚠️w）／alt-login·captcha（⚠️m）。
- 無 migration／schema／entity／base-web／i18n／compose/secret 變動（地基 001-003 已 provisioned）。
