# Verification Commands (C-V contracts): 017-audit-center-enhancement

**Date**: 2026-06-23 | 對應 spec §5 + research 風險。容器內跑（host 無 toolchain）；rust live `--test-threads=1`；CDP≠curl（UI 軌須 CDP）。
變數：`RA="docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api sh -c"`；`BW=... exec -T base-web`；token 走 `curl :31081/auth/login`。

---

## C-V-0 build / lint / typecheck

```
$RA 'cd /app && find server/src -name "*.rs" -exec touch {} + && cargo build -p server 2>&1 | tail'
# 兩 lint（★ endpoint_coverage_lint 數【不變】＝零新端點佐證；entity_access_lint）
$RA 'cd /app && cargo test -p server --test endpoint_coverage_lint --test entity_access_lint 2>&1 | tail'
$BW pnpm typecheck
```
**Pass**：build Finished、兩 lint green（lint 端點數與 016 相同）、typecheck exit 0。

## C-V-1 rust 純函式單元測（test-first 可）

```
$RA 'cd /app && cargo test -p server parse_http_status_class with_roles csv_ records_to_csv parse_export 2>&1 | tail -20'
```
涵蓋：
- `parse_http_status_class`：2xx/4xx/5xx→正確半開區間；空/None→None；**無法識別非空→None（不 Err）**（FR-012）。
- `with_roles`：插 "roles"、**排序**、空→`[]`（非 null）；非 Object 輸入原樣返回。
- `csv_escape_field`/`records_to_csv`：欄含逗號/雙引號/換行→正確 quote+`""`；整檔前綴 UTF-8 BOM；表頭穩定英文 key。
- `parse_export`："true"/"1"→true、其餘/空→false。
**Pass**：全 passed（看到 "0 passed" 即 filter 沒命中、警覺）。

## C-V-2 curl（wire 層；★ 含空 param 守門、curl≠modal）

```
# 取 Super token
T=$(curl -s :31081/auth/login -H 'Content-Type: application/json' -d '{"userName":"Super","password":"123456"}' | grep -oE '"token":"[^"]+"' | head -1 | sed 's/.*"token":"//;s/"//')
A=$(curl -s :31081/auth/login -d '{"userName":"Admin","password":"123456"}' -H 'Content-Type: application/json' | ... )  # Admin token（非 Super）
# C-1 class filter 收窄
curl -s ":31081/systemManage/getAccessLog?httpStatusClass=4xx" -H "Authorization: Bearer $T"   # records 僅 400-499
curl -s ":31081/systemManage/getAccessLog?httpStatusClass=" -H "Authorization: Bearer $T"       # 空 param→不報錯、視為未篩（守門）
curl -s ":31081/systemManage/getAccessLog?httpStatusClass=xyz" -H "Authorization: Bearer $T"    # 無法識別→不報錯、未篩（FR-012）
curl -s ":31081/systemManage/getAccessLog?httpStatusClass=4xx&httpStatus=200" -H "Authorization: Bearer $T"  # F3 AND 並存：records 為空（證交集非覆蓋；FR-011/SC-006）
# C-3 export（三表）Super 200 回 CSV
curl -s ":31081/systemManage/getAccessLog?export=true" -H "Authorization: Bearer $T" | head -c 200   # envelope data 為 CSV 字串（含 BOM）
curl -s ":31081/systemManage/getOperationLog?export=true" -H "Authorization: Bearer $T" | head -c 300 # 含 rolesBefore/rolesAfter 欄
curl -s ":31081/systemManage/getLoginAttempt?export=true" -H "Authorization: Bearer $T" | head -c 200
# C-3 FR-009 非 Super export 403
curl -s -o /dev/null -w '%{http_code}' ":31081/systemManage/getAccessLog?export=true" -H "Authorization: Bearer $A"  # 403
```
**Pass**：class 收窄正確、空/無法識別不報錯、export 回 `{"code":"0000","data":"<csv...>"}`、op-log export 含 rolesBefore/rolesAfter、非 Super 403。

## C-V-3 psql（op-log roles delta；★ trace_id 隔離、非列數斷言）

```
# 經真 server 帶自身 trace_id 跑 add/update/delete user（live smoke、--test-threads=1），再 psql 驗該 trace_id 的 op-log payload
$RA 'cd /app && DATABASE_URL=... cargo test -p server -- --ignored --test-threads=1 add_user_create_roundtrip update_user_preserves delete_user_soft_delete op_log_atomic 2>&1 | tail'   # F1：擴充既有測之實際測名（子字串 filter）；看到 "0 passed / N filtered out" 即 filter 沒命中（bare-filter 假綠）
# 或直接 psql 查特定 trace_id 列的 payload_before/after->>'roles'
docker compose ... exec -T postgres psql -U postgres -d <db> -c \
  "select operation, payload_before->'roles' rb, payload_after->'roles' ra, (payload_after ? 'current_session_id') sid_kept from sys_operation_log where trace_id='<self-trace>' and entity_table='sys_user';"   # F8：sid_kept 應 t（with_roles 未覆蓋既有欄、FR-013 forensic 零回歸）
```
**Pass**：update 列 `rb`=改前角色集、`ra`=改後（scenario 1）；add 列 `ra`=初始角色、`rb` null/缺（INSERT before=None、scenario 2）；delete 列 `rb`=刪前角色、`ra`=`[]`（scenario 3）；未動角色 update 列 `rb`==`ra`（集合、scenario 4）。**斷言限自身 trace_id**（共享 seed entity_id append-only、勿絕對列數）。

## C-V-4 CDP（UI 軌；curl 看不到）

CDP（注入 Super token→navigate :31080，沿 tests/000 scripts 範式）：
- **C-1**：/manage/audit → API 存取分頁 → 選 class「4xx」→ 列表僅 4xx；清除→還原。
- **C-3**：三 tab 各按「匯出」→ 觸發 `.csv` 下載（驗 Blob 產生、檔名 `<table>_<ts>.csv`、內容首 bytes 含 BOM）；篩選後匯出＝當前篩選結果；total>1萬時 toast「僅匯出前 1 萬列」。
- **C-4 顯示**：op-log 分頁展開某角色變更紀錄 → payload 顯 roles_before/after；零 console error。
**Pass**：三項 UI 行為正確、零 console error/exception。

## C-V-5 回歸 / 結構

```
$RA 'cd /app && git diff <base>..HEAD -- migration/ | wc -l'          # 0（零 migration）
# prod target image build（即使零新 crate、仍驗無破口）
docker compose -f docker-compose.yml -f docker-compose.prod.yml build rust-api 2>&1 | tail
$RA 'cd /app && cargo test -p server 2>&1 | grep "test result"'        # 既有 audit 測零回歸
$BW pnpm typecheck                                                      # base-web 零回歸
```
**Pass**：migration diff 空、prod build 成功、既有 unit 測全綠、typecheck 綠、既有 audit 分頁/篩選行為不變。

---

## 排序紀律（tasks 用）
- **C-4 先於 C-3 op-log roles 欄**（C-3 的 rolesBefore/After CSV 欄抽自 C-4 enrich 的 payload）；或 C-3 容忍 payload 無 roles（顯空）。
- rust 全程 serial（共用 target）；base-web commit `--no-verify`；每寫端兩段式 commit→bump pin。
