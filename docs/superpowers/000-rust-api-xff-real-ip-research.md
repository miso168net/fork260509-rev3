# 000 · rust-api XFF → real_ip 解析：研究與改動設計

> **目的**：把 rust-api 的「X-Forwarded-For（XFF）→ 真實 client IP（real_ip）」解析，從目前的「單一信任集 rightmost-untrusted」升級成一套能正確處理**多層反代 / CDN / 自有 public IP 雙重身分 / IIS 雜訊 / Cloudflare Tunnel**的模型，並把解析結果連同**直連 peer、原始鏈、可信度**一起存入審計日誌做鑑識。
> **本檔性質**：pre-spec-kit 研究與改動設計（`000` foundation namespace、非 spec-kit feature）。**全文自含**，不依賴其他討論稿。成案後另開正式 feature `013-`。
> **接地快照**：2026-06-20｜rust-api pin `fca64a0`｜base-web pin `1764154e`（§8 的 `file:line` 為當下快照、會隨 commit rot）。

---

## 1. 問題：取得「真實 client IP」為什麼難

一個請求到 rust-api 時，TCP 層只看得到**直連 peer**（通常是我方最內層 nginx）。真正的客戶端 IP 藏在 `X-Forwarded-For` 這串「每一跳代理各自往右追加」的鏈裡。難點：

1. **鏈是半可信的**：右段（我方基建逐跳依真實 TCP peer 追加）偽造不了；左段（客戶端送進來的）**任何人都能亂塞**。
2. **CDN 與自有反代混雜**：流量可能 `client → Cloudflare → 我方反代A → 我方反代B → app`，要從一串 IP 裡認出哪個才是 client。
3. **自有 public IP 身兼兩角**：同一個我方 public IP，有時是反代節點、有時是「我自己用瀏覽器直連的客戶端」——天真的「取第一個 public IP」會張冠李戴。
4. **格式雜訊**：IIS 記 XFF 會把空格寫成 `+`、且帶 port（IPv4 `ip:port`、IPv6 `ip%port`）。
5. **Cloudflare Tunnel 翻轉拓樸**：用 `cloudflared` 時，鏈裡**根本沒有 CDN 邊緣 IP**，直連 peer 變成 `127.0.0.1`。
6. **可信度要可被審計**：解析結果要附帶「我多有把握」，讓事後鑑識能篩掉不可靠的歸因。

---

## 2. 信任地基（先講，因為一切都建在它上面）

**所有 header（XFF、CF-Connecting-IP 等）都沒有密碼學完整性、任何人都能設。** 它們之所以「可信」，唯一來源是一個**網路層前提**：

> **origin 不可被繞過信任入口直達。** 只要有人能直連我方 nginx，他就能偽造整條 XFF 與所有 CDN header。

這個前提靠部署達成，分兩種模式：

| 模式 | 信任入口 | 怎麼擋直連 |
|---|---|---|
| **regular**（CDN 邊緣 → nginx） | CDN 邊緣 IP | 防火牆只放行 CDN 官方 IP 段連入 origin（或 mTLS Authenticated Origin Pulls） |
| **tunnel**（cloudflared 外連 → nginx） | cloudflared 本機（`127.0.0.1`…） | **結構性無 public inbound**——cloudflared 對外建連、origin 沒對外開埠 |

**唯一偽造不了的事實 = TCP 層的 `$remote_addr`**（誰真的連上我方邊緣）。因此「這個請求是否真的經過 CDN」這個判斷，**必須由看得到真實連線的 nginx 來下**（見 §6），rust-api 不自己去爬可偽造的 XFF 來判。

> 下面所有解析與 confidence，都**假設這個信任邊界沒被破**。它們做的是「在已可信的流量裡分配歸因」，**不負責**防直連繞過——那是網路層的責任。

---

## 3. 解析模型

三步：**正規化 → 兩層位置解析 →（可選）CF-Connecting-IP 交叉驗證**。

### 3.1 正規化（IIS-aware）

把原始 XFF 字串切成乾淨的 IP 序列：

- 以 `[\s,+]+` 切分（吃逗號、空白、IIS 的 `+`＝空格編碼）。
- 每個 token：`trim` → 剝 port（IPv4 `1.2.3.4:443`、IPv6 `2001:db8::1%55`、標準 `[2001:db8::1]:443`）→ 驗證為合法 IP → 失敗就丟棄。
- 把**直連 peer**（`$remote_addr`）接在序列最右端（最可信的一跳）。

### 3.2 兩層位置解析 → `(real_ip, base_confidence)`

定義 `trusted = cdn ∪ my_public ∪ internal_default ∪ Σ binding.internal`（皆 CIDR-capable）。由右而左走：

```
A. peer ∉ trusted                         → (peer, DIRECT)          # 沒過任何受信 proxy，peer 即客戶端
B. 鏈中存在 CDN 段（Tier-1 位置錨）        → 最右 CDN 的【左邊第一個非 CDN】= real_ip, CDN_ANCHORED
C. 否則（Tier-2，含 Tunnel）              → 由右而左，逐點 skip：
     internal_default ∪ my_public ∪ binding.internal（連續多跳就一直 skip）
     第一個「皆非」= real_ip               → PROXY_CLEAN（綁定相鄰不符 / dual_role → PROXY_SOFT）
     跑完沒命中（整鏈受信）                → (peer, FALLBACK)
```

兩個關鍵性質：
- **Tier-1（CDN 錨）不需要 my_public 清單**：CDN 右側的一切「依位置」即視為我方、盲剝即可——所以就算某個我方 public 反代漏設清單，via-CDN 的解析仍正確（**錨免疫漏設**）。
- **Tier-2 必須有 my_public 清單**：沒有 CDN 當位置錨，只能靠清單認出「哪些 public IP 是我的」來定邊界。reverse proxy 連續串多點時，要**逐點反覆比對、一路 skip** 到第一個非我方 IP。

### 3.3 CF-Connecting-IP 交叉驗證（overlay、強化可信度、**不取代**解析）

Cloudflare 會放一個 `CF-Connecting-IP` header＝它在 TCP 層看到的真實訪客 IP（單一值、CF 覆寫掉客戶端自帶值）。我們拿它**交叉驗證**位置解析出的 `real_ip`，只調 confidence、不改 real_ip：

```
若 nginx 蓋了 X-CF-Verified:1（§6 證明真的經過 CF）且 CF-Connecting-IP=cip 有值 且 base 是 {CDN_ANCHORED,PROXY_CLEAN,PROXY_SOFT}：
    cip == real_ip → CDN_VERIFIED（最高：位置 + CF 權威兩個獨立訊號相符）
    cip != real_ip → CDN_MISMATCH（異常：保留 positional real_ip、留痕報警、該查 config）
```

此 overlay 在 **direct-CF（Tier-1）和 Tunnel（Tier-2）皆通用**——因為它只看 nginx 蓋的 `X-CF-Verified` 旗標，不依賴鏈裡有沒有 CDN IP。

### 3.4 confidence 七態

| 狀態 | 信賴 | 何時 |
|---|---|---|
| `CDN_VERIFIED` | **最高** | Tier-1/Tier-2 解出後，CF-Connecting-IP 交叉相符 |
| `CDN_ANCHORED` | 中（見註） | Tier-1 由 CDN 位置錨解出，但**沒有** CF 交叉驗證 |
| `PROXY_CLEAN` | 高 | Tier-2 解出、所有跳都合預期 |
| `PROXY_SOFT` | 中 | Tier-2 解出，但走過綁定相鄰不符 / dual_role IP |
| `DIRECT` | 高 | 無受信 proxy、peer 即 TCP 客戶端（偽造不了） |
| `CDN_MISMATCH` | 低 | CF-Connecting-IP 與位置解析**不符**＝異常 |
| `FALLBACK` | 低 | 整鏈受信、解不出真 client，退回 peer |

> **註（CDN_ANCHORED 的雙面性）**：在「有設 CF 驗證」的部署裡，正常 CF 流量應升到 `CDN_VERIFIED`；若停在 `CDN_ANCHORED`（鏈裡有 CDN IP、卻沒 CF 驗證），可能是「客戶端注入了假 CDN IP + 直連繞過」（見案例 5）→ 應視為**可疑**。是否要「Tier-1 的 CDN 錨硬性要求 X-CF-Verified 才成立」是一個 open 設計選擇（§8）。

---

## 4. ★ 案例集：一眼看懂 XFF 解析效果

### 4.0 範例環境

**範例 IP（皆文件保留段）**：

| 角色 | IP |
|---|---|
| 真實訪客（公網 client） | `203.0.113.9` |
| 我方反代 public（`my_public`） | `198.51.100.7`（pub_a，**dual_role**）、`198.51.100.8`（pub_b） |
| Cloudflare 邊緣（`cdn`） | `162.158.108.56`（∈ `162.158.0.0/15`） |
| 我方內網（`internal_default`） | `10.0.0.5`（int_a）、`172.20.0.3`（nginx docker＝rust-api 的 peer） |
| cloudflared（tunnel ingress） | `127.0.0.1` |
| 客戶端亂塞 / 攻擊者 | `1.2.3.4`（塞的假 victim）、`45.13.99.99`（攻擊者真 IP） |

**範例信任 config**（§5 詳述）：`cdn = 162.158.0.0/15（連接 header＝CF-Connecting-IP）`、`my_public = 198.51.100.0/24`、`internal_default = 10/8,172.16/12,192.168/16,127/8,::1`、`binding: 198.51.100.8 → 10.0.0.0/24`、`dual_role: 198.51.100.7`。

> 讀法：每案列 **直連 peer**、**XFF（左→右）**、相關 header、由右而左的走訪、最後 **⇒ real_ip + confidence**。

---

**案例 1 — 直連、無受信 proxy**
- peer = `203.0.113.9`（∉ trusted）｜XFF：（有也忽略）
- 走：`peer ∉ trusted` → DIRECT
- ⇒ **`203.0.113.9` / `DIRECT`**（peer 就是 TCP 來源、偽造不了）

**案例 2 — 標準 Cloudflare（regular）**
- peer = `172.20.0.3`（nginx）｜XFF：`203.0.113.9, 162.158.108.56`｜header：`X-CF-Verified:1`、`CF-Connecting-IP:203.0.113.9`
- 走：鏈 `203.0.113.9, 162.158.108.56, 172.20.0.3` → Tier-1 最右 CDN＝`162.158.108.56`、左一個非 CDN＝`203.0.113.9`（CDN_ANCHORED）→ overlay：cip==real → 升級
- ⇒ **`203.0.113.9` / `CDN_VERIFIED`**

**案例 3 — CDN + 多層我方反代（錨免疫漏設）**
- peer = `172.20.0.3`｜XFF：`203.0.113.9, 162.158.108.56, 198.51.100.7, 10.0.0.5`
- 走：Tier-1 最右 CDN＝`162.158.108.56`、左一個非 CDN＝`203.0.113.9`（CDN 右側的 `198.51.100.7/10.0.0.5/172.20.0.3` 全部**依位置盲剝**、不需在清單裡）
- ⇒ **`203.0.113.9` / `CDN_VERIFIED`**（有 CF 驗證時）。**重點：CDN 右側盲剝，漏設某我方 public 也不影響。**

**案例 4 — 客戶端注入假 IP（左段）**
- peer = `172.20.0.3`｜XFF：`1.2.3.4, 9.9.9.9, 203.0.113.9, 162.158.108.56`（前兩個是客戶端送給 CF 前自塞的）
- 走：Tier-1 最右 CDN＝`162.158.108.56`、左一個非 CDN＝`203.0.113.9`；注入的 `1.2.3.4/9.9.9.9` 在 real 左邊、**碰不到**
- ⇒ **`203.0.113.9` / `CDN_VERIFIED`**。**安全：由右而左 + 信任邊界，客戶端注入永遠在 real 左側。**

**案例 5 — 直連繞過 + 注入假 CDN（攻擊 vs 防線）**
- 場景：攻擊者**繞過 CF、直連 nginx**，XFF 注入 `1.2.3.4, 162.158.0.1`（假 victim + 查表得到的真 CF IP 字串）、自帶假 `CF-Connecting-IP:1.2.3.4`
- nginx：`$remote_addr=45.13.99.99`（攻擊者真 IP，∉ CF）→ **X-CF-Verified 留空、CF-Connecting-IP 被 strip**；append `45.13.99.99` → 傳給 rust-api 的 XFF＝`1.2.3.4, 162.158.0.1, 45.13.99.99`，peer＝`172.20.0.3`
- 走（現設計）：鏈 `1.2.3.4, 162.158.0.1, 45.13.99.99, 172.20.0.3` → Tier-1 最右 CDN＝注入的 `162.158.0.1`、左一個＝`1.2.3.4` → real=`1.2.3.4`、base=`CDN_ANCHORED`；overlay 沒套（X-CF-Verified≠1）
- ⇒ **`1.2.3.4` / `CDN_ANCHORED`**
- **三道防線**：① **網路層（主防線）**——若 origin 擋直連（防火牆 / tunnel），此攻擊**根本發不出**（攻擊者連不上 nginx）；本案是「假設網路層已破」才成立。② **in-band 訊號**——結果是 `CDN_ANCHORED` 而非 `CDN_VERIFIED`：在有設 CF 驗證的部署裡，「有 CF IP 卻沒 CF 驗證」即異常旗標。③ **open 選擇**——若把「Tier-1 CDN 錨硬性要求 X-CF-Verified」（見 §8），則本案 Tier-1 不 fire、退 Tier-2 解出攻擊者真 IP `45.13.99.99`、注入完全失效（代價：用 CF 但沒設 nginx 閘時會解不出，須取捨）。

**案例 6 — 無 CDN、直連我方多層反代**
- peer = `172.20.0.3`｜XFF：`203.0.113.9, 198.51.100.7, 10.0.0.5`（client → pub_a → 內網 → app）
- 走：無 CDN → Tier-2 由右而左：`172.20.0.3`(internal→skip) → `10.0.0.5`(internal→skip) → `198.51.100.7`(my_public→skip) → `203.0.113.9`(皆非→回)
- ⇒ **`203.0.113.9` / `PROXY_SOFT`**（`198.51.100.7` 是 dual_role → 降級；若非 dual_role 則 `PROXY_CLEAN`）

**案例 7 — my-public 連續串多點（iterate skip）**
- peer = `172.20.0.3`｜XFF：`203.0.113.9, 198.51.100.7, 198.51.100.8`（兩個 public 連續、中間無內網）
- 走：Tier-2：`172.20.0.3`(skip) → `198.51.100.8`(my_public→skip) → `198.51.100.7`(my_public→**再比一次**→skip) → `203.0.113.9`(回)
- ⇒ **`203.0.113.9` / `PROXY_SOFT`**。**重點：my-public 連續多跳要逐點反覆比、一路 skip，不能只跳一格。**

**案例 8 — per-proxy binding 軟評分**
- peer = `172.20.0.3`｜XFF：`203.0.113.9, 198.51.100.8, 192.168.5.5`
- 走：Tier-2：`172.20.0.3`(skip) → `192.168.5.5`(internal→skip，但記 prev) → `198.51.100.8`(my_public，綁定要求其後置內網∈`10.0.0.0/24`、實際相鄰是 `192.168.5.5`**不符** → **軟降級**、續 skip) → `203.0.113.9`(回)
- ⇒ **`203.0.113.9` / `PROXY_SOFT`**。**綁定不符不炸線、只降可信、留痕可查。**

**案例 9 — dual_role 盲區（我方 public 自己當 client）**
- 場景 A（無 CDN 直連）：peer = `172.20.0.3`｜XFF：`198.51.100.7, 10.0.0.5`（`198.51.100.7` 這次是「我用它直連瀏覽」）
  - 走：Tier-2：`172.20.0.3`(skip) → `10.0.0.5`(skip) → `198.51.100.7`(my_public **且 dual_role**→skip) → 跑完沒命中 → `(peer, FALLBACK)`
  - ⇒ **`172.20.0.3` / `FALLBACK`**（盲區：解不出真 client＝`198.51.100.7`，誠實標低可信）
- 場景 B（同一台走 CDN）：XFF：`198.51.100.7, 162.158.108.56`、`X-CF-Verified:1`、`CF-Connecting-IP:198.51.100.7`
  - 走：Tier-1 錨 `162.158.108.56`、左一個＝`198.51.100.7` → overlay 相符
  - ⇒ **`198.51.100.7` / `CDN_VERIFIED`** ✓
- **結論：自有 IP 的可靠歸因走 CDN（場景 B 解得對）；直連（場景 A）是 inherent 盲區，dual_role 旗標讓它落到低可信、不亂猜。**

**案例 10 — IIS 格式（`+` + port）**
- peer = `172.20.0.3`｜XFF（IIS 風）：`115.164.87.108,+162.158.108.56:13814,+10.60.251.251:37427`
- 正規化：切分吃 `+`、剝 port → `115.164.87.108, 162.158.108.56, 10.60.251.251`
- 走：Tier-1 最右 CDN＝`162.158.108.56`、左一個＝`115.164.87.108`
- ⇒ **`115.164.87.108` / `CDN_ANCHORED`**（無正規化則整串 parse 失敗、CDN 偵測落空）

**案例 11 — Cloudflare Tunnel（超級特例）**
- 場景：visitor → CF →（tunnel）→ cloudflared（`127.0.0.1`）→ nginx → rust-api
- peer = `172.20.0.3`｜XFF：`203.0.113.9, 127.0.0.1`｜header：`X-CF-Verified:1`（nginx `$remote_addr=127.0.0.1` ∈ cloudflared ingress）、`CF-Connecting-IP:203.0.113.9`
- 走：**鏈中無 CF 邊緣 IP** → Tier-1 不 fire → Tier-2：`172.20.0.3`(skip) → `127.0.0.1`(loopback∈internal_default→skip) → `203.0.113.9`(回，PROXY_CLEAN) → overlay 相符 → 升級
- ⇒ **`203.0.113.9` / `CDN_VERIFIED`**。**重點：tunnel 鏈裡沒 CF IP，靠 Tier-2 + CF overlay 拿到高可信；前提是 loopback ∈ internal_default。**

**案例 12 — 全鏈受信（fallback）**
- peer = `172.20.0.3`｜XFF：`198.51.100.8, 10.0.0.5`（整串都是我方）
- 走：Tier-2 全部 skip、跑完沒命中
- ⇒ **`172.20.0.3` / `FALLBACK`**（解不出 foreign client，誠實退 peer + 標低可信）

---

## 5. 信任 config 結構（TOML、boot-only）

解析需要四種清單 + 兩種旗標，env 表達不了（per-proxy 綁定、per-cdn header），故用**結構化 TOML 檔**，開機載入一次（誤配 fail-safe 回空、不靜默）：

```toml
# cdn：Tier-1 位置錨。條目可宣告「權威 client-IP header」供交叉驗證。
[[cdn]]
range = "162.158.0.0/15"          # Cloudflare 邊緣段（operator 自填、自行更新；不內建）
connecting_ip_header = "CF-Connecting-IP"

# my_public：Tier-2 我方反代 public 出口。dual_role=此 IP 也可能當直連 client。
[[my_public]]
range = "198.51.100.7"
dual_role = true
[[my_public]]
range = "198.51.100.8"

# internal_default：常見私網段（含 loopback，tunnel 必需）。
internal_default = ["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","127.0.0.0/8","::1"]

# bindings：少數特例——某 public 專屬的後置內網（軟驗證、不符只降 confidence）。
[[bindings]]
public = "198.51.100.8"
internal = ["10.0.0.0/24"]
```

- **CF 段不內建、無 cron**：operator 自填 `cloudflare.com/ips-v4|v6`、自行更新（保留現有「空集 fail-safe」哲學）。空 `cdn` → 無 Tier-1 錨 + 無 CF 驗證、流量自動退 Tier-2/direct。
- 現有 `TRUSTED_PROXY_CIDRS` env 降為 fallback（無 TOML 檔時的最簡相容）。

---

## 6. CF 驗證與 Cloudflare Tunnel（兩種部署模式）

**鐵律**：rust-api **絕不**自己用 XFF 判「是否經過 CF」（XFF 可注入、見案例 5）。判斷權在**看得到真實連線的 nginx**。

**nginx 權威閘**：用 `$remote_addr`（真實 TCP peer、偽造不了）判定，命中「CF 邊緣段 ∪ cloudflared ingress」才認證：

```nginx
# ★ 用 geo 不用 map：map 不支援原生 CIDR 比對、CDN 邊緣段是 CIDR（geo 是 http-context、內建）
geo $remote_addr $cf_verified {
    default              0;
    # regular：CF 官方邊緣段（CIDR）
    162.158.0.0/15       1;
    104.16.0.0/13        1;
    # tunnel：cloudflared 本機 ingress
    127.0.0.1/32         1;
    ::1/128              1;
}
# 非 CF 源就把客戶端自帶的 CF-Connecting-IP strip 成空（只有 verified=1 才放行）
map $cf_verified $cf_cip_safe { 1 $http_cf_connecting_ip; default ""; }

# location /api/ 內（轉發 + 蓋旗標；不啟 realip、不覆寫 $remote_addr）：
proxy_set_header X-CF-Verified     $cf_verified;
proxy_set_header CF-Connecting-IP  $cf_cip_safe;
```

| | regular（CF 邊緣→nginx） | tunnel（cloudflared→nginx） |
|---|---|---|
| nginx `$remote_addr` | CF 邊緣 IP | `127.0.0.1` / cloudflared 本機 |
| 鏈裡有 CF 邊緣 IP？ | 有 → Tier-1 | **無** → Tier-2 |
| 防直連 | 防火牆 allowlist CF 段 | origin 無 public inbound（結構性） |
| 取 real_ip | Tier-1 錨 + overlay | Tier-2 skip 內網 + overlay |

- **不啟** nginx `realip` 的 `$remote_addr` 覆寫（社群常見做法）——那會把鏈壓扁、犧牲我們對多 CDN/my-public/IIS/混合拓樸的解析力。nginx 只**轉發 header + 蓋旗標**，解析全留 rust-api。
- True-Client-IP（CF Enterprise 限定、非企業可偽造）→ **不依賴**，用 CF-Connecting-IP。

---

## 7. 儲存：四欄 forensic 模型（三表）

目前審計只存一欄「解析後 IP」+ 原始 XFF；遺失了「直連 peer」與「可信度」。改為四欄，套用三張審計表：

| 欄（access/login） | 欄（operation） | 型 | 語意 |
|---|---|---|---|
| `peer_ip` | `operator_peer_ip` | INET | 直連 peer（誰實體連上來＝反代/CDN 出口） |
| `real_ip`（← `client_ip` 改名） | `operator_real_ip`（← `operator_ip` 改名） | INET | 解析後真 client |
| `x_forwarded_for`（已有） | `operator_x_forwarded_for` | TEXT | 原始鏈逐字（鑑識/重算） |
| `ip_confidence` | `operator_ip_confidence` | smallint∨enum | §3.4 七態 |

- **三表統一**（access_log / login_attempt / operation_log），forensic 模型一致。
- 解析時把四值 bundle 成一個 `IpForensics{peer, real, xff, confidence}`，**一次傳**給三個 sink（op_log 走 `AuditOperator` threading）。
- 新欄 **nullable**（歷史列無法回填、誠實標 unknown）；migration 可逆。
- **命名翻轉注意**：現 `client_ip`/`operator_ip` 存的是「解析後真值」（即新的 `real_ip`），改名要連 handler/wire/前端一起動（§8）。

---

## 8. rust-api 現況 → 改動設計

> 由 6 區平行盤點 + 逐層合成接地，pin `fca64a0`（`file:line` 為快照、會 rot）。

### 8.1 現況關鍵接地

rust-api 已有一套**單值** XFF 解析（`server/src/audit_ctx.rs`）：`resolve_client_ip(peer, xff, &[IpNetwork]) -> IpAddr`，三層（peer-gate → rightmost-untrusted → fail-safe），**單一信任集** `TRUSTED_PROXY_CIDRS`（env、`config.rs`），無 confidence、無 CDN 錨、無 IIS normalize（只 `split(',')`）。直連 peer（`ConnectInfo<SocketAddr>`）算出後**丟棄**。

要改的面：
- **解析+中介層** `audit_ctx.rs`：`resolve_client_ip`、`RequestContext{operator_id,client_ip,x_forwarded_for,region,trace_id}`、`audit_mw`、`to_audit_operator`、**8 個純測**。
- **config/state/main**：`config.rs`(env-only、無 toml) / `state.rs`(`trusted_proxy_cidrs:Vec<IpNetwork>`) / `main.rs`(`into_make_service_with_connect_info::<SocketAddr>()`)。
- **三 sink**：`AccessLogEvent`(audit_mw 後段) / `LoginAttemptEvent`(`handler/auth.rs`) / op-log `AuditOperator{id,ip:Option<IpNetwork>}`(write 在 `facade/sys_operation_log.rs::write_in_txn`)。
- **op-log threading**：`to_audit_operator` 有 **16 個呼叫點**（`system_manage.rs`×15 + `system_settings.rs`×1）。
- **三審計 entity** + **m001** 欄定義；**012 讀端** handler wire DTO + 3 facade list + `ip_host_like`（3 處字面 col 名）；**base-web** wire typings + audit 三分頁 view + i18n；**nginx** `/api/` proxy。

### 8.2 逐層改動（10 層）

| 層 | 改什麼（接地） |
|---|---|
| **L1 解析核心**（`audit_ctx.rs`） | 新 `normalize_xff_tokens(&str)->Vec<IpAddr>`（split `[\s,+]`、剝 port、drop invalid）；`resolve_client_ip` 回傳 `IpAddr`→`(IpAddr,Confidence)`、`trusted:&[IpNetwork]`→`&TrustModel`、body 改四分支；新 `enum Confidence`(7 態 as_str)；新 `apply_cf_overlay(base,cip,verified,real)->Confidence`(top-level、direct/tunnel 皆適用) |
| **L2 config**（`config.rs`+Cargo） | 新 dep `toml`(parse-only、釘版驗 1.86)；新 `TrustModel{cdn,my_public,internal_default,bindings}`(CIDR 欄以 String 收、post-load `parse::<IpNetwork>()` 驗)；`load_trust_model()` 讀 `TRUST_MODEL_FILE`、缺檔 fallback flat env |
| **L3 state+main** | `AppState.trusted_proxy_cidrs`→`trust_model:Arc<TrustModel>`；ConnectInfo wiring 不動 |
| **L4 entity ×3** | 與 m006 同步改欄（DeriveEntityModel 反射）：access/login `client_ip`→`real_ip` + `peer_ip`/`ip_confidence`(Option)；operation `operator_ip`→`operator_real_ip` + 3 新欄 |
| **L5 migration m006** | 新 `m006_audit_ip_forensics.rs`(execute_unprepared、鏡像 m005、可逆)；`lib.rs` append。DDL 見 §8.3 |
| **L6 op-log threading** | RequestContext 加 `peer_ip`/`ip_confidence`；**AuditOperator 維持 `Copy`**(只塞 Copy 型 peer/real，xff/confidence 走 AuditEvent)→ **不動 16 facade 簽名**(漏斗收斂、非 broadcast)；`write_in_txn` 映 4 欄 |
| **L7 012 讀端** | handler wire DTO + 3 facade：`client_ip`→`real_ip`/`operator_ip`→`operator_real_ip` 改名 + 加 peer/confidence 欄(honest wire、Option 不 skip)；`ip_host_like` 3 處字面 col 名同改 |
| **L8 base-web** | d.ts 3 Item + SearchParams 改名+加欄；audit 三分頁 column/render(confidence 宜 NTag 著色)；app.d.ts Schema(先擴) + 雙 locale(同 commit) |
| **L9 nginx** | `geo $remote_addr $x_cf_verified`(**geo 非 map**、命中集 = CF 邊緣段 ∪ cloudflared ingress) + `map` strip 偽造 CF-Connecting-IP + `proxy_set_header` 轉發；**不啟 realip**(§6) |
| **L10 compose** | 加 `TRUST_MODEL_FILE` env + bind-mount TOML；`TRUSTED_PROXY_CIDRS` 留 degraded fallback |

### 8.3 migration m006（rename + add、嚴格可逆）

```sql
-- UP（逐句 execute_unprepared、INET 寫字面）
ALTER TABLE sys_access_log     RENAME COLUMN client_ip TO real_ip;
ALTER TABLE sys_access_log     ADD COLUMN peer_ip INET;
ALTER TABLE sys_access_log     ADD COLUMN ip_confidence TEXT;
ALTER TABLE sys_login_attempt  RENAME COLUMN client_ip TO real_ip;
ALTER TABLE sys_login_attempt  ADD COLUMN peer_ip INET;
ALTER TABLE sys_login_attempt  ADD COLUMN ip_confidence TEXT;
ALTER TABLE sys_operation_log  RENAME COLUMN operator_ip TO operator_real_ip;
ALTER TABLE sys_operation_log  ADD COLUMN operator_peer_ip INET;
ALTER TABLE sys_operation_log  ADD COLUMN operator_x_forwarded_for TEXT;
ALTER TABLE sys_operation_log  ADD COLUMN operator_ip_confidence TEXT;
-- DOWN 嚴格反序（先 DROP IF EXISTS 新欄、再 RENAME 回）；PG RENAME 自動跟改 m001 idx 內欄參照
```
> `ip_confidence` 選 **TEXT**（直存 enum 小字串、entity `Option<String>` 直映、無 i16 映射層）。m001 凍結不改。

### 8.4 測試計畫（重點）

- **純函式**：`normalize_xff_tokens`（`+`/空白/逗號混切、剝 v4/v6 port、drop garbage 各邊界）；`resolve_client_ip` 把 8 個現有測重映射到 `(IpAddr,Confidence)` tuple + 補 CDN-anchored/Tier-2/dual_role-soft/Tunnel/Fallback；`apply_cf_overlay`(verified×cip×base 矩陣)。
- **config**：`load_trust_model` 合法/壞 token fail-safe/缺檔 fallback。
- **容器內 build**：force-touch 防 `/mnt/d` stale-mtime；新 `toml` 驗 1.86 編得過；**prod target image build**（新 workspace dep、§ 紀律）。
- **live smoke**（容器內、`DATABASE_URL`、`--test-threads=1`）：psql 驗三表四欄真寫入（best-effort warn-drop、不能只看 HTTP 200）；`ip_host_like` 改名後 host() 斷言；append-only 用 trace_id/delta 隔離（勿斷言絕對列數）。
- **migration** up→down→up 可逆 + fresh DB 全鏈 m001..m006。
- **CDP/curl** 012 讀端：wire JSON 含新欄（honest null）、三分頁 column + confidence NTag + filter 改名後仍發 API（curl 帶空 param 抓守門回歸）。

### 8.5 回歸面（重點）

- 007 `audit_ctx` live path：resolve 回傳型改 → region/xdb 要明確取 `.0` 餵 xdb（別誤餵 peer/bundle）；ConnectInfo peer 抽取漏掉 → 500。
- **8 純測全失效**（對 IpAddr 單值斷言）→ 重映射 + 補新測。
- **012 三分頁**：base-web 三端對齊（d.ts / view / app.d.ts Schema + 雙 locale）任一漏 = type lie / typecheck red。
- **`ip_host_like` 共用 seam**：3 處字面 col 名漏改 → `host(col)::text` 指不存在欄 **runtime error**（curl 才抓、build 不報）。
- **entity ↔ m006 同步**：DeriveEntityModel 欄名 runtime 才綁、只改一邊 → SQL 指錯欄。
- op-log threading：AuditOperator 維持 Copy（走 AuditEvent 帶 String 欄）→ 不觸發 16 facade 重驗。
- nginx 既有 `X-Real-IP`/`X-Forwarded-For`/`X-Forwarded-Proto`/`X-Request-Id` 不可 regress；改後 `force-recreate` 非 restart、先 `nginx -t`。

### 8.6 剩餘 open questions（spec 前要拍）

1. **`ip_confidence` 型別**：TEXT（傾向、直存小字串）vs smallint（省 byte 但增映射層）。
2. **op-log threading Copy 策略**：AuditOperator 維持 Copy（建議、~4 檔）vs flatten 失 Copy（~10 檔、重驗 16 facade）。
3. **peer_ip / ip_confidence 是否新增搜尋 filter**（per-column 搜尋對象是拍板級、別靜默打包）。`real_ip` 改名是必須。
4. **x_forwarded_for / peer_ip 是否在 view 顯示為 column**（現 xForwardedFor 是 filter-only；要看原鏈須【新增 column】）。
5. **confidence wire 型**：base-web `ipConfidence` 用 literal enum union vs `string|null`（對齊 rust serde 實輸出）。
6. **`TRUST_MODEL_FILE` 路徑與容器掛載**（env 名、TOML 放哪、dev/prod bind-mount point；dev 空 TOML→fallback→all direct 是否預期）。
7. **`toml` crate 確切版本 pin**（subtree winnow/serde_spanned 驗 1.86、Cargo.lock 防禦釘版）。
8. **CF edge CIDR 集確切清單**（Cloudflare 官方 list + cloudflared docker bridge 實際段）。
9. **dual_role 軟評分降級的確切判定規則**（my_public.dual_role 與 binding.dual_role 命中時的降級邏輯）。
10. **★（案例 5 衍生）Tier-1 CDN 錨是否硬性要求 X-CF-Verified**：硬 gate → 注入假 CDN IP 攻擊失效（退 Tier-2 解出攻擊者真 IP），代價＝用 CF 但沒設 nginx 閘時 Tier-2 會誤把 CF 邊緣 IP 當 real_ip；vs 維持位置錨 + 靠網路層防直連 + `CDN_ANCHORED`≠`CDN_VERIFIED` 當 in-band 訊號。

---

## 9. 參考來源（外部）

- **Cloudflare + nginx real IP guide** — `https://klab.tw/2026/06/cloudflare-nginx-real-ip-guide/`：CF-Connecting-IP 機制、`ngx_http_realip_module`、CF IP 清單（`cloudflare.com/ips-v4|v6`）、防直連偽造三層（網路 allowlist／Authenticated Origin Pulls／Cloudflare Tunnel）、True-Client-IP 僅 Enterprise。
- **CF community：real IP w/ Argo Tunnel + NPM** — `https://community.cloudflare.com/t/real-ip-using-argo-tunnel-and-nginx-proxy-manager/355271`（2022）：albert 證實「CF-Connecting-IP 帶 visitor IP、只在真經過 CF 時可信、且『只放行 CF IP』主要適用 regular 而非 tunnel」；bschmitt 實證「tunnel 下 nginx `$remote_addr` 變 `127.0.0.1`、real IP 在 XFF」。
- 佐證：`https://www.sindastra.de/p/3670/how-to-restore-remote-ip-in-nginx-behind-a-cloudflare-tunnel`、`https://github.com/NginxProxyManager/nginx-proxy-manager/issues/1358`、`https://github.com/ergin/nginx-cloudflare-real-ip`。
- RFC 7239（Forwarded HTTP Extension）的精神：右段可信、左段半可信。
