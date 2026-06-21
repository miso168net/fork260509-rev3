# Phase 1 Data Model: XFF → real_ip 鑑識

> schema 變更接地自 `docs/superpowers/000-rust-api-xff-real-ip-research.md` §8（現況盤點 @ pin `fca64a0`）。

## 1. 審計表四欄 forensic（三表）

三張既有 append-only 審計日誌表，各新增/改名鑑識欄。新欄 **nullable**（歷史列無法回填、誠實標 unknown）；`real_ip` 由現有 `client_ip`/`operator_ip` 改名（維持原 nullability）。

| 表 | 改名 | 新增 | 既有保留 |
|---|---|---|---|
| `sys_access_log` | `client_ip` → `real_ip`（INET, NOT NULL） | `peer_ip`（INET, NULL）、`ip_confidence`（TEXT, NULL） | `x_forwarded_for`（TEXT, NULL） |
| `sys_login_attempt` | `client_ip` → `real_ip`（INET, NOT NULL） | `peer_ip`（INET, NULL）、`ip_confidence`（TEXT, NULL） | `x_forwarded_for`（TEXT, NULL） |
| `sys_operation_log` | `operator_ip` → `operator_real_ip`（INET, NULL） | `operator_peer_ip`（INET, NULL）、`operator_x_forwarded_for`（TEXT, NULL）、`operator_ip_confidence`（TEXT, NULL） | （原無 xff 欄、本案新增 `operator_x_forwarded_for`） |

**欄語意**：`peer_ip`＝直連 TCP peer（REMOTE_ADDR／反代·CDN 出口）；`real_ip`＝解析後真 client；`x_forwarded_for`＝原始鏈逐字（鑑識/重算）；`ip_confidence`＝七態之一。
**archetype 守則**：三表為 §I.6 archetype B（append-only）；本案只加 domain 欄、**未加** `updated_*`/`deleted_*`、不可竄改性不變。

## 2. m006 delta migration（rename + add、嚴格可逆）

`migration/src/m006_audit_ip_forensics.rs`（`execute_unprepared` raw SQL、鏡像 m005 pattern；`lib.rs` append `mod` + `Box::new` 入 `migrations()`）。

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

-- DOWN（嚴格反序：先 DROP IF EXISTS 新欄、再 RENAME 回）
ALTER TABLE sys_operation_log  DROP COLUMN IF EXISTS operator_ip_confidence;
ALTER TABLE sys_operation_log  DROP COLUMN IF EXISTS operator_x_forwarded_for;
ALTER TABLE sys_operation_log  DROP COLUMN IF EXISTS operator_peer_ip;
ALTER TABLE sys_operation_log  RENAME COLUMN operator_real_ip TO operator_ip;
ALTER TABLE sys_login_attempt  DROP COLUMN IF EXISTS ip_confidence;
ALTER TABLE sys_login_attempt  DROP COLUMN IF EXISTS peer_ip;
ALTER TABLE sys_login_attempt  RENAME COLUMN real_ip TO client_ip;
ALTER TABLE sys_access_log     DROP COLUMN IF EXISTS ip_confidence;
ALTER TABLE sys_access_log     DROP COLUMN IF EXISTS peer_ip;
ALTER TABLE sys_access_log     RENAME COLUMN real_ip TO client_ip;
```
- `m001` **凍結不改**（PG `RENAME COLUMN` 自動跟改 m001 `idx_login_attempt_ip_time` 內欄參照、不需手動 drop/recreate index）。
- `ip_confidence` 選 **TEXT**（直存 enum 小字串、entity `Option<String>` 直映）。

## 3. entity Model 同步（與 m006 同刀）

`entity/src/sys_{access_log,login_attempt,operation_log}.rs`（`DeriveEntityModel` 反射 DB 欄名、欄名須與 m006 一致、否則 runtime SQL 指錯欄）：
- access/login：`client_ip:IpNetwork`(NN) → `real_ip:IpNetwork`(NN)；+ `peer_ip:Option<IpNetwork>` + `ip_confidence:Option<String>`。
- operation：`operator_ip:Option<IpNetwork>` → `operator_real_ip:Option<IpNetwork>`；+ `operator_peer_ip:Option<IpNetwork>` + `operator_x_forwarded_for:Option<String>` + `operator_ip_confidence:Option<String>`。
- `peer_ip` 走既有 `with-ipnetwork`（entity `Cargo.toml` 已啟、無新依賴）。

## 4. 解析期型（in-memory）

```rust
// audit_ctx.rs
enum Confidence { CdnVerified, CdnAnchored, ProxyClean, ProxySoft, Direct, CdnMismatch, Fallback }
impl Confidence { fn as_str(&self) -> &'static str { /* cdn_verified / cdn_anchored / proxy_clean / proxy_soft / direct / cdn_mismatch / fallback */ } }

struct IpForensics { peer: IpAddr, real: IpAddr, xff: Option<String>, confidence: Confidence }
// RequestContext 加 peer_ip:IpAddr + ip_confidence:Confidence（或內含 IpForensics）；audit_mw 一次建、傳三 sink。
// AuditOperator 維持 #[derive(Copy)]：只帶 peer/real(Option<IpNetwork>)；xff/confidence 走 AuditEvent（避免動 16 facade）。
```

## 5. 信任 config 型（TrustModel、TOML、boot-only）

```rust
// config.rs（CIDR 欄以 String 接收、post-load parse::<IpNetwork>()；誤配 fail-safe）
struct TrustModel {
    cdn: Vec<CdnEntry>,            // Tier-1 位置錨
    my_public: Vec<MyPublicEntry>,// Tier-2 我方反代 public
    internal_default: Vec<IpNetwork>,
    bindings: Vec<Binding>,       // 少數特例：某 public 專屬內網
}
struct CdnEntry    { networks: Vec<IpNetwork>, connecting_ip_header: Option<String> }  // CF→"CF-Connecting-IP"
struct MyPublicEntry { networks: Vec<IpNetwork>, dual_role: bool }
struct Binding     { public: IpNetwork, internal: Vec<IpNetwork>, dual_role: bool }
```
TOML 範例見 quickstart.md。`AppState.trusted_proxy_cidrs:Vec<IpNetwork>` → `trust_model:Arc<TrustModel>`。

## 6. wire DTO（012 讀端、honest wire）

三 Item（`OperationLogItem`/`AccessLogItem`/`LoginAttemptItem`）+ base-web `rev3-system-manage.d.ts` 對應：
- access/login：`clientIp`→`realIp:string`（NN）；+ `peerIp:string|null`、`ipConfidence:<7 literal>|null`；`xForwardedFor:string|null`（既有）。
- operation：`operatorIp`→`operatorRealIp:string|null`；+ `operatorPeerIp:string|null`、`operatorXForwardedFor:string|null`、`operatorIpConfidence:<7 literal>|null`。
- IP 序列化 `IpNetwork.ip().to_string()`（去 mask）；nullable 顯 `null` **不** `skip_serializing_if`。
- SearchParams：`clientIp`→`realIp`、`operatorIp`→`operatorRealIp`；+ `peerIp`(模糊)、`ipConfidence`(下拉精確)；`xForwardedFor`(模糊、既有)。

## 7. Validation rules（自 FR）

- FR-1：normalize 後每 token 必為合法 `IpAddr`、否則 drop（不進鏈）。
- FR-2/3：解析必回七態之一；Tier-2 binding 相鄰不符 / dual_role → `PROXY_SOFT`（不停線）。
- FR-4：overlay 僅在 `X-CF-Verified==1` 且 base∈{anchored,clean,soft} 才動 confidence；real_ip 不變。
- FR-5：TrustModel 任一 CIDR token 壞 → 該集合 fail-safe 退保守（不擴大信任）。
- FR-6：三表四欄、`real_ip` NN（沿 client_ip）、其餘 nullable。
- FR-9：search 空字串守門（未填欄略過、不誤篩 0 列）。
