# Contract: 操作審計 op-log 機制（005 落定、跨 feature 權威）

> 本刀建立的不變式，後續每個寫端業務切片繼承。權威＝DESIGN §5.2／§3.2／§10.4／constitution §I.6（archetype B）／§I.5。

## 1. mutate_in_txn 原子不變式
1. **業務寫＋審計寫同 txn**：經 `mutate_in_txn` 的變更，與其 op-log insert **綁同一 `DatabaseTransaction`**——同時 commit 或同時 rollback。**恆**不可分割（FR-001／SC-001/002）。
2. **no-op 不寫審計**：閉包回 `(txn, _, None)`（如查無目標）→ 不寫 op-log、txn 正常 commit、無副作用、非 error（FR-006）。
3. **失敗整滾**：閉包或 op-log 寫回 `Err(DbErr)` → 整 txn rollback、業務與審計一起不留。
4. **泛型 conn**：`C: TransactionTrait`——production `&DatabaseConnection`、測試/組合 `&DatabaseTransaction`（nested savepoint）；後者使 live 驗證以外層 rollback 隔離、不污染 seed。
5. **後續切片擴充**：新寫路徑於 facade 加 fn、包 `mutate_in_txn`、宣告自己的 `AuditEvent`（operation/target/before/after）即繼承原子審計；**不改 `audit.rs` 機制本體**（表中立、FR-002／SC-006）。

## 2. AuditSerialize / redact 不變式
1. **敏感欄遮蔽**：審計 before/after 快照對指定敏感欄（`password`）遮蔽為 `"<redacted>"`、其餘欄保留（FR-003／SC-003）。
2. **impl 在 facade**：`AuditSerialize` 宣告於 `audit.rs`（trait、純）、impl 於各 entity facade（可碰 entity::、手構 json）；新 entity 的遮蔽清單由其消費刀於 impl 時宣告。
3. **operation 詞彙封閉**：`AuditOperation`∈{Insert, Update, SoftDelete, Restore}、`as_str()` 為 operation 欄 DB 字串契約（INSERT/UPDATE/SOFT_DELETE/RESTORE）；定義一次、各刀復用、不擴張。

## 3. op-log sink 不變式（archetype B、§I.6）
1. **append-only**：`facade/sys_operation_log.rs` 只暴露 `write_in_txn`（insert）；**無** update/delete fn；不可竄改（FR-004／SC-004）。
2. **facade 唯一管道**：op-log `entity::sys_operation_log` 的構造/寫入只在 `facade/`（繼承 004 `entity_access_lint`；`audit.rs` 機制本體零 `entity::`、FR-007）。
3. **欄映射**：`AuditEvent`→op-log 欄（operation.as_str()／entity_table／entity_id／payload_before·after（Json）／operator.id→operator_id／operator.ip→operator_ip／trace_id）；`id`/`created_at` 由 DB 生成。

## 4. operator 不變式
1. **顯式參數（本刀）**：operator（`AuditOperator{id, ip}`）由呼叫端顯式傳入；自 `RequestContext` 自動抽取屬後續 audit_ctx／Auth 島刀。
2. **可空**：`operator_id` 可 null（容忍 system/seed/未認證 actor、不驗存在、§3.3 義務零 FK）。
3. **ip 最終型**：`AuditOperator.ip: Option<IpNetwork>`（一次對 op-log `operator_ip` 最終型）；本刀 proof 傳 `None`、overlay 刀填真 IP（避免 String→INET retrofit）。
4. **§I.6 成對**：soft-delete 寫 `deleted_at` 必與 `deleted_by` 成對（`deleted_by`=operator.id）。

## 5. 本刀邊界（OUT）
- 無 overlay sink（access/login log）、無 audit_ctx 中介層、無 xdb、無 operator 自動來源、無 op-log 讀端、無其餘寫路徑、無 `DbErr→AppError`、無 endpoint/wire、無 migration、無 runtime DB 接線、無新 crate（各歸其刀）。
