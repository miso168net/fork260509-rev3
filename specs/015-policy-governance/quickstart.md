# Quickstart 驗證指南：Policy 治理島（授權規則回收桶）

> 跑驗收的最短路徑。詳細指令見 [contracts/verification-commands.md](./contracts/verification-commands.md)；data 細節見 [data-model.md](./data-model.md)。

## 前置
```bash
bash deploy/generate-dev-cert.sh                                            # 首次
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
# 帳號：Super/Admin/User，密碼 123456（CLAUDE §8.1）；確認 rust-api 已重編新碼（cargo watch log）
```

## 1. 授權回收桶：撤銷可復原（US1、SC-001/002）
- 撤銷某角色某非受保護授權 → psql `sys_casbin_policy_archive` 有該列（含 archived_at/by/reason）、`casbin_rule` live 無（**同 txn 原子**）。
- restore → casbin_rule 回該列、archive 刪、op-log 審計 `{role,target,dimension}`；restore **已 live** → `0000` NoOp（不重複、不審計）；restore **假 id** → `2222`、零變更。→ **C-V-2**

## 2. 受保護核心防誤撤（US1、SC-003）
- 撤銷一批含受保護核心 → 整批 `Rejected` `2222`、現役與 archive **零變更**（011 零回歸；判定在任何寫之前）。→ **C-V-3**

## 3. 精準重載（US3、SC-004）
- Rejected / restore NoOp / restore NotFound → **不** reload、**不** 廣播；Applied（**含空-diff** set_role_dimension）/ restore Applied → reload + 廣播。→ **C-V-3**

## 4. ★ 多副本跨副本收斂（US2、SC-005）
- `$DC --profile multi up -d rust-api-2 --wait`；副本 A revoke → 副本 B enforce 依最新被拒（`casbin:policy:invalidate` watcher 收斂）；A restore → B 放行；`CLIENT KILL TYPE pubsub` → 重訂閱、後續仍收斂。→ **C-V-5**

## 5. 授權回收桶頁（US1、SC-006）
- Super → `/manage/policy-archive` → 列出已撤授權 + restore 鈕（真打 endpoint、非 fake data）；Admin/User 無此頁、直呼 → `5003`。建 view 後 §3.13 console error 消解。→ **C-V-6**

## 6. 零回歸 + 零 migration（SC-007/008）
- `role_menu_loop` teardown 加 archive 清理 → `--ignored` 全套綠（byte-identity 不破）；`git diff migration/` 空；migration up→down→up 綠；prod target image build 綠；base-web typecheck 綠。→ **C-V-7**

---

**對外碼速查**：archive-move/restore Applied → `0000`；restore NoOp（已 live）→ `0000`；restore NotFound（假 id）/ 撤銷含受保護 Rejected → `2222`；非 R_SUPER → `5003`。（凍結 13 碼矩陣、無新碼。）
