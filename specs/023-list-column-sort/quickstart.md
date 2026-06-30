# Quickstart：列表欄位排序（023-list-column-sort）

端到端驗證指引。完整斷言見 [`contracts/verification-commands.md`](contracts/verification-commands.md)、wire 形見 [`contracts/sort-wire-contract.md`](contracts/sort-wire-contract.md)、欄位白名單見 [`data-model.md`](data-model.md)。

## 前置

```bash
# dev stack（首啟冷編譯 base-web ~140s / rust-api ~240s，flap 屬正常）
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
# 套 m008 index migration（migrate gate 自動套；或手動）
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T rust-api cargo run -p migration -- up
```

預設帳號 `Super/Admin/User`、密碼 `123456`。

## 驗證流程（對應 user story）

1. **US1 單欄 server-side 排序**：`/manage/user` 點欄頭 → 整資料集排序（非僅當前頁）。curl 軌 = C-V-2；3-state（第一下反序）CDP = C-V-7。
2. **US2 多欄點擊序優先**：依序點多欄 → 主/次排序。curl = C-V-3、CDP = C-V-7.3。
3. **US3 一鍵清除**：工具列「清除排序」鈕 → 全清回預設。CDP = C-V-7.4。
4. **US4 跨頁保留**：排序 → 離開 → 返回 → 還原。CDP = C-V-7.5（localStorage per route.name）。
5. **FR-016 匯出反映排序**：審計頁 `export=true&sort=...` → CSV 列序依排序。curl = C-V-6。
6. **無效排序拒絕**：非白名單欄/方向/重複 → 2222。curl = C-V-5。
7. **零回歸**：未排序時各列表逐列等同導入前。curl = C-V-4。

## 索引可逆

m008（`idx_login_attempt_created_at`）up→down→up 全綠：C-V-8。

## CDP 前必做

跑 CDP 在地化斷言前 **`docker compose ... restart base-web`**（避 vite stale-locale 使 `common.clearSort` 顯 raw key）；斷言 label 文字非 raw key。

## 收尾

實作走 `superpowers:executing-plans`（**非 `/speckit-implement`**）；兩段式 commit + bump submodule pin（§4.1）；push/merge 需 user 同意。
