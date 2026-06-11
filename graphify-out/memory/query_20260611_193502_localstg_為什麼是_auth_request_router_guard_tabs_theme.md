---
type: "query"
date: "2026-06-11T19:35:02.745242+00:00"
question: "localStg 為什麼是 Auth、Request、Router Guard、Tabs、Theme 五大子系統的共同橋接點?"
contributor: "graphify"
source_nodes: ["localStg", "useAuthStore", "request", "handleExpiredRequest()"]
---

# Q: localStg 為什麼是 Auth、Request、Router Guard、Tabs、Theme 五大子系統的共同橋接點?

## Answer

Expanded from original query via vocab: [local, stg, storage, auth, token, refresh, request, guard, route, tab, theme, settings]. localStg (base-web/src/utils/storage.ts L5) = createStorage<StorageType.Local>('local', storagePrefix) 型別化 localStorage 包裝;key 契約在 src/typings/storage.d.ts 的 StorageType.Local(token/refreshToken/lang/themeSettings/themeColor/darkMode/globalTabs/overrideThemeFlag/...)。14 條 EXTRACTED import 邊全指向它:auth store(shared.ts getToken/clearAuthStorage 讀刪 token+refreshToken)、service/request/shared.ts(getAuthorization 讀 token L7;handleExpiredRequest 讀 refreshToken L17、寫回新 token L20-21;service-alova 鏡像同邏輯)、router/guard/route.ts(L27/L87 isLogin=Boolean(localStg.get('token')) 直讀、不經 Pinia)、tab store(L63 讀/L352 寫 globalTabs)、theme(shared.ts L20 themeSettings、L24-29 overrideThemeFlag vs BUILD_TIME 版本化)。另有 locales(lang)、plugins/loading.ts(L9-10 在 Vue mount 前讀 themeColor/darkMode)、app store(mixSiderFixed)。核心洞見:token 有三個彼此獨立的讀者(auth store、request 層、router guard),localStorage 才是事實上的共享 auth 狀態、Pinia 只是其中一個視圖;refresh rotation 由 request 層寫 key、guard 下一次導航直接讀到 — 跨子系統協調走 storage key 而非 store API。

## Source Nodes

- localStg
- useAuthStore
- request
- handleExpiredRequest()