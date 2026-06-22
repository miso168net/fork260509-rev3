#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 016 U3 T021 / C-V-6：button＋endpoint 授權變更【跨副本一致收斂】live smoke（US3、SC-005、FR-008）。
#
# 鏡像 015 C-V-6（2-instance）延伸到 button/endpoint 兩維度。流程（皆經真實 handler、驅動
# reload_and_publish→PUBLISH casbin:policy:invalidate→副本 B watcher SUBSCRIBE→load_policy）：
#   ① 副本 A(:31081) updateRoleButton 撤 R_USER_COMMON 的 B_CODE3
#        → psql 證 casbin_rule 該 button 列消失
#        → 副本 B(:31082) User getUserInfo buttons 不含 B_CODE3（watcher 收斂）。
#   ② 副本 A restorePolicy 復原該 button
#        → 副本 B User getUserInfo buttons 重含 B_CODE3。
#   ③ 副本 A updateRoleEndpoints 撤 R_USER_COMMON 的 (/systemManage/getAllRoles, GET)
#        → psql 證 casbin_rule 該 endpoint 列消失
#        → 副本 B User 呼叫 getAllRoles 被拒（5003/HTTP403、enforce 依最新收斂）。
#   ④ 副本 A restorePolicy 復原該 endpoint
#        → 副本 B User 呼叫 getAllRoles 恢復 200。
#   ⑤ redis CLIENT KILL TYPE pubsub → 兩副本 watcher 應重訂閱
#        → 再撤 B_CODE3 → 副本 B 仍收斂（韌性、非永久脫鉤）→ 復原。
#
# ★ snapshot-restore guard：不動 R_SUPER 自身核心；只改 R_USER_COMMON（測 role）。所有變更
#   皆於收尾還原（撤→restore 對稱、或 byte-restore 兜底）；id-snapshot casbin op-log 清理保 012 t_cas==2。
# ★ 收尾 --profile multi down；dev DB 零殘留。
#
# 用法（workspace root 執行）：bash tests/016-button-endpoint-policy/scripts/cv6-2instance-convergence.sh
# 前置：dev stack up；本腳本自起 rust-api-2（若未起）。
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

DC="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
A="http://127.0.0.1:31081"   # 副本 A（cargo-watch、含本刀新碼）
B="http://127.0.0.1:31082"   # 副本 B（cargo run、shared pg/redis、watcher 收斂端）
PSQL="$DC exec -T postgres psql -U soybean -d soybean_admin_rust -tAc"
ROLE="R_USER_COMMON"
ROLE_ID=3
BUTTON="B_CODE3"
EP_PATH="/systemManage/getAllRoles"
EP_METHOD="GET"

fail() { echo "✗ FAIL: $*" >&2; FAILED=1; }
ok()   { echo "✓ $*"; }
FAILED=0

# ── token 取得（curl /auth/login）──
login() { # $1=user
  curl -fsS -X POST "$A/auth/login" -H 'Content-Type: application/json' \
    -d "{\"userName\":\"$1\",\"password\":\"123456\"}" 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["token"])'
}

# getUserInfo buttons（副本指定）
buttons_of() { # $1=base_url $2=token
  curl -fsS -X GET "$1/auth/getUserInfo" -H "Authorization: Bearer $2" 2>/dev/null \
    | python3 -c 'import sys,json; print(",".join(json.load(sys.stdin)["data"]["buttons"]))'
}

# updateRoleButton（副本 A、Super token）
set_buttons() { # $1=super_token $2=json_array_codes
  curl -s -X POST "$A/systemManage/updateRoleButton" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -d "{\"roleId\":$ROLE_ID,\"buttonCodes\":$2}" 2>/dev/null
}
# updateRoleEndpoints（副本 A、Super token）
set_endpoints() { # $1=super_token $2=json_endpoints_array
  curl -s -X POST "$A/systemManage/updateRoleEndpoints" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -d "{\"roleId\":$ROLE_ID,\"endpoints\":$2}" 2>/dev/null
}
# restorePolicy（副本 A、Super token、id=String）
restore_policy() { # $1=super_token $2=archive_id
  curl -s -X POST "$A/systemManage/restorePolicy" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -d "{\"id\":\"$2\"}" 2>/dev/null
}

# 等待副本 B 收斂（watcher 非同步、poll 至條件成立或逾時）
wait_until() { # $1=desc $2=timeout_s $3...=cmd（exit 0＝成立）
  local desc="$1"; local timeout="$2"; shift 2
  local i=0
  while [ "$i" -lt "$timeout" ]; do
    if "$@"; then return 0; fi
    sleep 1; i=$((i+1))
  done
  fail "收斂逾時（${timeout}s）：$desc"
  return 1
}

echo "═══ 016 C-V-6 2-instance 跨副本收斂 ═══"

# ── 0. 確保 rust-api-2 healthy ──
echo "── 0. 等待副本 B(:31082) healthy ──"
i=0
until curl -fsS "$B/health" >/dev/null 2>&1; do
  i=$((i+1)); [ "$i" -gt 360 ] && { echo "✗ 副本 B 未就緒（冷編逾時）"; exit 2; }
  sleep 2
done
ok "副本 B 就緒"

# ── token ──
SUPER=$(login Super)
USERTOK_A=$(login User)   # User token（兩副本共用同 jwt secret、可跨副本驗）
[ -z "$SUPER" ] && { echo "✗ Super 登入失敗"; exit 2; }
[ -z "$USERTOK_A" ] && { echo "✗ User 登入失敗"; exit 2; }
ok "token 取得（Super／User）"

# baseline 紀錄（收尾比對）
BASELINE_TCAS=$($PSQL "SELECT count(*) FROM sys_operation_log WHERE entity_table ~ 'casbin';")
echo "baseline casbin op-log = $BASELINE_TCAS"

# ─────────────────────────────────────────────────────────────────────────────
# ① button 撤銷跨副本收斂
# ─────────────────────────────────────────────────────────────────────────────
echo "── ① A 撤 $ROLE 的 $BUTTON → B getUserInfo 收斂 ──"
B_BEFORE=$(buttons_of "$B" "$USERTOK_A")
echo "撤前 副本B User buttons = [$B_BEFORE]"
set_buttons "$SUPER" '[]' >/dev/null
# psql 證 A 側 casbin_rule 該 button 列消失
LIVE=$($PSQL "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v0='$ROLE' AND v2='button' AND v1='$BUTTON';")
[ "$LIVE" = "0" ] && ok "psql：casbin_rule $BUTTON 列已撤" || fail "casbin_rule $BUTTON 列未撤（count=$LIVE）"
# 副本 B getUserInfo 收斂（watcher）
wait_until "B buttons 不含 $BUTTON" 15 bash -c "
  curl -fsS -X GET '$B/auth/getUserInfo' -H 'Authorization: Bearer $USERTOK_A' 2>/dev/null \
  | python3 -c 'import sys,json; b=json.load(sys.stdin)[\"data\"][\"buttons\"]; sys.exit(0 if \"$BUTTON\" not in b else 1)'
" && ok "副本 B getUserInfo buttons 收斂（已不含 $BUTTON）"

# ② restore button → B 收斂回
echo "── ② A restore $BUTTON → B 收斂回 ──"
ARCH_ID=$($PSQL "SELECT id FROM sys_casbin_policy_archive WHERE v0='$ROLE' AND v1='$BUTTON' AND v2='button' ORDER BY id DESC LIMIT 1;")
ARCH_ID=$(echo "$ARCH_ID" | tr -d '[:space:]')
[ -n "$ARCH_ID" ] && ok "取得 button archive id=$ARCH_ID" || fail "button archive 未產生"
restore_policy "$SUPER" "$ARCH_ID" >/dev/null
wait_until "B buttons 重含 $BUTTON" 15 bash -c "
  curl -fsS -X GET '$B/auth/getUserInfo' -H 'Authorization: Bearer $USERTOK_A' 2>/dev/null \
  | python3 -c 'import sys,json; b=json.load(sys.stdin)[\"data\"][\"buttons\"]; sys.exit(0 if \"$BUTTON\" in b else 1)'
" && ok "副本 B getUserInfo buttons 恢復（重含 $BUTTON）"

# ─────────────────────────────────────────────────────────────────────────────
# ③ endpoint 撤銷跨副本收斂（enforce）
# ─────────────────────────────────────────────────────────────────────────────
echo "── ③ A 撤 $ROLE 的 ($EP_PATH,$EP_METHOD) → B enforce 收斂被拒 ──"
# 撤前 副本 B User 呼 getAllRoles 應 200
CODE_BEFORE=$(curl -s -o /dev/null -w '%{http_code}' -X GET "$B$EP_PATH" -H "Authorization: Bearer $USERTOK_A")
[ "$CODE_BEFORE" = "200" ] && ok "撤前 副本B User 呼 getAllRoles=200" || fail "撤前應 200、實得 $CODE_BEFORE"
# A 撤該 endpoint（desired=[] 表 R_USER_COMMON endpoint 全撤；此 role 僅此 1 endpoint）
set_endpoints "$SUPER" '[]' >/dev/null
LIVE_EP=$($PSQL "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v0='$ROLE' AND v1='$EP_PATH' AND v2='$EP_METHOD';")
[ "$LIVE_EP" = "0" ] && ok "psql：casbin_rule ($EP_PATH,$EP_METHOD) 列已撤" || fail "endpoint 列未撤（count=$LIVE_EP）"
# 副本 B enforce 收斂：User 呼 getAllRoles 應 403（5003）
wait_until "B getAllRoles 被拒" 15 bash -c "
  c=\$(curl -s -o /dev/null -w '%{http_code}' -X GET '$B$EP_PATH' -H 'Authorization: Bearer $USERTOK_A')
  [ \"\$c\" = '403' ]
" && ok "副本 B enforce 收斂（getAllRoles 被拒 403）"

# ④ restore endpoint → B 恢復 200
echo "── ④ A restore endpoint → B enforce 恢復 ──"
ARCH_EP=$($PSQL "SELECT id FROM sys_casbin_policy_archive WHERE v0='$ROLE' AND v1='$EP_PATH' AND v2='$EP_METHOD' ORDER BY id DESC LIMIT 1;")
ARCH_EP=$(echo "$ARCH_EP" | tr -d '[:space:]')
[ -n "$ARCH_EP" ] && ok "取得 endpoint archive id=$ARCH_EP" || fail "endpoint archive 未產生"
restore_policy "$SUPER" "$ARCH_EP" >/dev/null
wait_until "B getAllRoles 恢復 200" 15 bash -c "
  c=\$(curl -s -o /dev/null -w '%{http_code}' -X GET '$B$EP_PATH' -H 'Authorization: Bearer $USERTOK_A')
  [ \"\$c\" = '200' ]
" && ok "副本 B enforce 恢復（getAllRoles=200）"

# ─────────────────────────────────────────────────────────────────────────────
# ⑤ CLIENT KILL TYPE pubsub → watcher 重訂閱韌性
# ─────────────────────────────────────────────────────────────────────────────
echo "── ⑤ CLIENT KILL TYPE pubsub → 重訂閱後仍收斂 ──"
REDIS_PW=$(cat deploy/secrets/redis_password.txt 2>/dev/null)
KILLED=$($DC exec -T redis-stack redis-cli -a "$REDIS_PW" --no-auth-warning CLIENT KILL TYPE pubsub 2>/dev/null | tr -d '[:space:]')
ok "CLIENT KILL TYPE pubsub → killed=$KILLED 個訂閱連線"
sleep 3   # 給 watcher 重連時間（reconnect loop）
# 再撤 button 驗收斂仍運作
set_buttons "$SUPER" '[]' >/dev/null
wait_until "kill 後 B 仍收斂（buttons 不含 $BUTTON）" 20 bash -c "
  curl -fsS -X GET '$B/auth/getUserInfo' -H 'Authorization: Bearer $USERTOK_A' 2>/dev/null \
  | python3 -c 'import sys,json; b=json.load(sys.stdin)[\"data\"][\"buttons\"]; sys.exit(0 if \"$BUTTON\" not in b else 1)'
" && ok "★ 重訂閱韌性：CLIENT KILL pubsub 後 watcher 重訂閱、仍跨副本收斂"
# 復原
ARCH_ID2=$($PSQL "SELECT id FROM sys_casbin_policy_archive WHERE v0='$ROLE' AND v1='$BUTTON' AND v2='button' ORDER BY id DESC LIMIT 1;")
ARCH_ID2=$(echo "$ARCH_ID2" | tr -d '[:space:]')
restore_policy "$SUPER" "$ARCH_ID2" >/dev/null
wait_until "復原 B 重含 $BUTTON" 15 bash -c "
  curl -fsS -X GET '$B/auth/getUserInfo' -H 'Authorization: Bearer $USERTOK_A' 2>/dev/null \
  | python3 -c 'import sys,json; b=json.load(sys.stdin)[\"data\"][\"buttons\"]; sys.exit(0 if \"$BUTTON\" in b else 1)'
" && ok "副本 B 最終恢復（重含 $BUTTON）"

# ─────────────────────────────────────────────────────────────────────────────
# 收尾：byte-restore 兜底 + op-log 清理 + 驗 baseline
# ─────────────────────────────────────────────────────────────────────────────
echo "── 收尾：還原 + 清理 + 驗 baseline ──"
# byte-restore 兜底：確保 R_USER_COMMON button=[B_CODE3]、endpoint=[(getAllRoles,GET)] 回原狀
# （正常 restore 已對稱；此處清任何 archive 殘留 + 確認 live 集回原狀）
NOW_BTN=$($PSQL "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v0='$ROLE' AND v2='button' AND v1='$BUTTON';")
NOW_EP=$($PSQL "SELECT count(*) FROM casbin_rule WHERE ptype='p' AND v0='$ROLE' AND v1='$EP_PATH' AND v2='$EP_METHOD';")
[ "$NOW_BTN" = "1" ] && ok "live $BUTTON 回原狀" || fail "live $BUTTON 未回原狀（count=$NOW_BTN）"
[ "$NOW_EP" = "1" ] && ok "live endpoint 回原狀" || fail "live endpoint 未回原狀（count=$NOW_EP）"

# 清 archive 殘留（本 role、本刀 reason；restore 應已消費、此為兜底）
$PSQL "DELETE FROM sys_casbin_policy_archive WHERE v0='$ROLE' AND archive_reason IN ('role_dimension_revoke','role_endpoint_revoke');" >/dev/null
# id-snapshot op-log 清理：清本測經真實 handler 落的 casbin op-log（保 012 t_cas==2）。本測對
# R_USER_COMMON 產兩類 casbin op-log：
#   (a) UPDATE（set_role_button/endpoints）：entity_id=role_id（3）。
#   (b) RESTORE（restorePolicy）：entity_id=NULL、payload_after.role=本 role（restore 審計 by-design）。
# 兩類皆以「entity_table='casbin_rule' AND 本 role」精準定位清除（baseline 的 2 列 entity_id≠3 且
# payload role≠R_USER_COMMON、不誤刪）。
$PSQL "DELETE FROM sys_operation_log WHERE entity_table='casbin_rule' AND (entity_id=$ROLE_ID OR payload_after->>'role'='$ROLE');" >/dev/null

ARCH_RESIDUE=$($PSQL "SELECT count(*) FROM sys_casbin_policy_archive WHERE v0='$ROLE';")
TCAS_AFTER=$($PSQL "SELECT count(*) FROM sys_operation_log WHERE entity_table ~ 'casbin';")
[ "$ARCH_RESIDUE" = "0" ] && ok "archive 殘留 0" || fail "archive 殘留 $ARCH_RESIDUE"
[ "$TCAS_AFTER" = "$BASELINE_TCAS" ] && ok "★ 012 baseline 保持（t_cas=$TCAS_AFTER）" || fail "t_cas 漂移（baseline=$BASELINE_TCAS、after=$TCAS_AFTER）"

# --profile multi down（停 rust-api-2）
echo "── 停 rust-api-2（--profile multi down rust-api-2）──"
$DC --profile multi stop rust-api-2 >/dev/null 2>&1
$DC --profile multi rm -f rust-api-2 >/dev/null 2>&1
ok "rust-api-2 已停"

echo "═══════════════════════════════════════"
if [ "$FAILED" = "0" ]; then echo "✓✓ C-V-6 全綠：button＋endpoint 跨副本收斂 + 重訂閱韌性"; exit 0;
else echo "✗✗ C-V-6 有失敗項"; exit 1; fi
