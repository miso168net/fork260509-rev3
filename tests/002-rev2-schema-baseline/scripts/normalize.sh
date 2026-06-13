#!/usr/bin/env bash
# normalize.sh — pg_dump 凍結形正規化（migration-chain.md §3 六規則）
#
# 用法：
#   normalize.sh schema [file]   # 套規則 #1 #2（schema-only dump）
#   normalize.sh data   [file]   # 套規則 #1 ~ #6（data-only dump）
#   無 file → 讀 stdin
#
# 純過濾、無副作用、結果 → stdout。
# 規則只濾「必異雜訊」（pristine 重放下兩側等價的隨機/時刻欄／物理列序），
# 禁止為過 diff 而擴充規則遮蓋實質差異（規則變更＝契約修訂，須留痕 migration-chain.md §3）。
#
# 六規則（凍結；缺一假紅）：
#   #1 \restrict / \unrestrict 行              （pg_dump 17.6+ 每次隨機 token）         schema+data
#   #2 seaql_migrations schema+data 全排除      （前代 35 列 vs rev3 2 列必異）          schema+data
#   #3 sys_user.password argon2 置換佔位        （argon2 random salt 兩側必異）           data only
#   #4 seed 時戳欄 default now() 實值置換佔位    （兩側皆 seed 時刻必異）                  data only
#   #5 setval 行置換佔位                        （序列終值另由 VERIFY 斷言）             data only
#   #6 COPY 段資料行排序                        （pg_dump 按 heap ctid 輸出、物理列序   data only
#                                                 因前代 UPDATE 移位 vs 本基線 INSERT 序必異）
#
# **規則執行序紀律**：#6 必須最後做（在 #3/#4/#5 之後）——先把 password/時戳/setval 等
# 兩側必異的雜訊置換成固定佔位、再對 COPY 段排序，否則兩側 hash/時刻字典序不同會導致
# sort 後仍錯位。#6 只在每個 COPY 區塊內部排序資料行（header 與 \. 邊界不動、不同表各自獨立）。

set -euo pipefail

MODE="${1:-}"
FILE="${2:-}"

case "$MODE" in
  schema|data) ;;
  *)
    echo "normalize.sh: 用法 normalize.sh schema|data [file]（無 file 讀 stdin）" >&2
    exit 2
    ;;
esac

# 輸入來源：有 file 讀檔、否則讀 stdin
read_input() {
  if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      echo "normalize.sh: 找不到輸入檔 $FILE" >&2
      exit 2
    fi
    cat -- "$FILE"
  else
    cat
  fi
}

# ── 規則 #1：\restrict / \unrestrict 行過濾（schema+data 皆套）──
strip_restrict() {
  grep -vE '^\\(un)?restrict ' || true
}

# ── 規則 #2：seaql_migrations 全排除（schema+data 皆套）──
# pg_dump 以「--\n-- Name: <obj>; Type: ...\n--」三行 header 起頭每個物件區塊（schema），
# data dump 則為「-- Data for Name: <obj>; Type: TABLE DATA」（COPY 段）或
# 「-- Name: <seq>; Type: SEQUENCE SET」（setval 段）。兩種 header 皆是區塊邊界。
# 凡 header 行的物件名提及 seaql_migrations 的整個區塊（CREATE TABLE / ALTER OWNER /
# CONSTRAINT pkey / Data for Name COPY 段等）皆刪，延伸到下一個 header 前。
strip_seaql() {
  awk '
    # 偵測區塊 header：「-- Name: ...」或「-- Data for Name: ...」行
    /^-- (Data for )?Name: / {
      # header 行命中 seaql_migrations → 進入排除態、否則退出排除態
      if ($0 ~ /seaql_migrations/) { skip = 1 } else { skip = 0 }
    }
    # 非排除態才輸出（排除態吞掉整段，直到下一個 header 重判）
    skip != 1 { print }
  '
}

# ── 規則 #3：sys_user COPY 區塊內 password（argon2）置換佔位（data only）──
# sys_user COPY header 後的 stdin 資料列為 tab 分隔；password 是第 3 欄
# （COPY public.sys_user (id, user_name, password, ...)）。只在 sys_user COPY
# 區塊（header → 終止符 \. ）內鎖定 argon2 token 置換，不誤殺其他欄/其他表。
redact_password() {
  awk -F'\t' '
    BEGIN { OFS = "\t"; in_user = 0 }
    /^COPY public\.sys_user / { in_user = 1; print; next }
    in_user == 1 && /^\\\.$/   { in_user = 0; print; next }
    in_user == 1 {
      # 第 3 欄為 password；若是 argon2 雜湊則置換佔位（NULL=\N 不動）
      if ($3 ~ /^\$argon2/) { $3 = "<ARGON2_REDACTED>" }
      print
      next
    }
    { print }
  '
}

# ── 規則 #4：seed 時戳欄（default now() 實值）置換佔位（data only）──
# COPY 資料列內的時戳格式：YYYY-MM-DD HH:MM:SS[.ffffff]+00（含微秒與 tz）。
# 兩側皆 seed 時刻必異 → 整串置換為固定佔位；只命中此精確格式、不誤殺其他欄。
redact_seed_ts() {
  sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?\+[0-9]{2}/<TS_REDACTED>/g'
}

# ── 規則 #5：setval 行置換佔位（data only）──
# SELECT pg_catalog.setval('public.<seq>', <n>, <bool>); — 序列終值另由 VERIFY 斷言，
# 此處整行置換（保留 seq 名、抹掉值）以免兩側因序列細節假紅。
redact_setval() {
  sed -E "s/^SELECT pg_catalog\.setval\(('[^']+'), .*\);/SELECT pg_catalog.setval(\1, <SETVAL_REDACTED>);/"
}

# ── 規則 #6：COPY 段資料行排序（data only；必須最後做）──
# pg_dump --data-only 以 heap 物理（ctid）序輸出 COPY 區塊內資料行；前代經 35 支
# migration（含 protected 的 UPDATE）造成 ctid 移位、本基線一次性 INSERT 的 ctid＝插入序，
# 兩側物理列序必異＝dump 雜訊（非資料差異）。對「每個 COPY ... FROM stdin; 到 \. 之間」
# 的資料行 LC_ALL=C sort（byte 序、跨環境穩定）；header 行與 \. 邊界原樣、不同表的 COPY
# 區塊各自獨立排序。排序後 id＋全欄仍逐列比對——漏列/多列/欄值錯照樣紅，不遮蓋實質差異。
# 用 awk 的 `print | cmd` 把區塊資料行送進獨立 sort、遇 \. 前 close() flush 排序結果，
# 確保排序輸出落在 header 之後、\. 之前，且表邊界不亂。
sort_copy_blocks() {
  awk '
    BEGIN { in_copy = 0; sort_cmd = "LC_ALL=C sort" }
    # COPY ... FROM stdin; → 輸出 header、進入收集態（開該區塊專屬 sort pipe）
    /^COPY .* FROM stdin;$/ { print; in_copy = 1; next }
    # 區塊終止符 \. → 先 close sort（flush 已排序資料行到 stdout）、再輸出 \.、退出收集態
    in_copy == 1 && /^\\\.$/ { close(sort_cmd); print; in_copy = 0; next }
    # 收集態：資料行送進該區塊 sort（暫不輸出，待 \. 前 flush）
    in_copy == 1 { print | sort_cmd; next }
    # 非收集態：原樣輸出
    { print }
  '
}

if [ "$MODE" = "schema" ]; then
  read_input | strip_restrict | strip_seaql
else
  # data：#1 #2 #3 #4 #5 #6 全套（#6 最後做、在雜訊置換之後排序）
  read_input | strip_restrict | strip_seaql | redact_password | redact_seed_ts | redact_setval | sort_copy_blocks
fi
