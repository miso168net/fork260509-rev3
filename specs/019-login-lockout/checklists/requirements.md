# Specification Quality Checklist: 登入鎖定（login-lockout）

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-06-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- 所有拍板（D1~D3 維度/政策值/訊息、E1~E8 工程決策）已於 Phase 0 brainstorm（`docs/superpowers/019-login-lockout.md`）由 user 親決或工程拍板定案 → **零 [NEEDS CLARIFICATION]**。
- 政策值（5/15min per-user、20/15min per-ip）為**業務政策**值、非實作細節，故保留於 FR/SC（可測、技術中立）。
- 刻意保留於規格邊界外（HOW，留 `/speckit-plan`）：rust handler 插點、count SQL／索引、envelope 碼（2222 復用）、i18n key、表名／const 命名——皆不出現於本 spec。
- 已驗 Constitution 對齊面向（正式 9 項檢於 `/speckit-plan`）：0 新表（§I.6 無 retrofit 不觸）、2222 復用不破 §I.3 ⚠️f 13 碼凍結、fail-OPEN 鏡像既有 `is_current`／`denylist_gate` 範式（不反轉 §I.7 方向性、不需 Amendment）、BASE-WEB-I18N-WIRING ★ 既授權軌道（§III.2 (ii)）。

### 獨立 reviewer 冷讀裁定（fresh-agent、2026-06-25）

派獨立 reviewer（fresh-agent 冷讀、避作者盲區）核對 spec ↔ brainstorm ↔ constitution。裁定後採納/駁回：
- **採納 FR-015**：補「不存在帳號失敗亦計入門檻」——顯式化 FR-011 防枚舉的成立機制（brainstorm §3 line 59）。
- **採納 SC-004 改寫**：由「枚舉成功率為 0」改「回應欄位比對不變式」（更直接可測）。
- **採納 FR-008 輕補**：加「審計留痕、鎖定列與真失敗列無從區分」（forensic 完整＋防枚舉一致，brainstorm E3）。
- **駁回 reviewer Section C 實作洩漏指控**：其引「sys_login_attempt 表／兩複合索引／硬碼 consts／dimension-blind」均為 **brainstorm 行內容、非本 spec**（grep 實證 spec 零洩漏命中）。
- **駁回「補 i18n key 名／訊息文字」**：i18n key 名屬 HOW（留 plan）；訊息文字 FR-012 本即有。
- **plan 層待驗（非 spec 缺口）**：§III.2 i18n key 確為 `backend.auth.login.locked` 且走既授權 requestInterceptor 軌道（brainstorm §8 research #3）。

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
