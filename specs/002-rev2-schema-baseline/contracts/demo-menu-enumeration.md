# Contract: demo-menu-enumeration（m004 凍結枚舉；R4 定稿 2026-06-13）

> 66 條＝generatedRoutes 51（`base-web/src/router/elegant/routes.ts`）＋customRoutes 15（`base-web/src/router/routes/index.ts`）。
> 帳目核對：generatedRoutes 64＝constant 5（login/403/404/500/iframe-page）＋基線重疊 8（home/manage/manage_user/manage_role/manage_menu/manage_user-detail/function/function_toggle-auth）＋demo 51 ✓。
> **轉錄紀律**：m004 逐列落值前，每列須回 route 源檔親驗 meta（本表為凍結集合與要點、非逐欄權威）；欄位映射規則＝research.md R4。
> 結構：目錄 16／頁 50；深度 0×8、1×39、2×18、3×1。policy 全覆蓋 66 列（R4-D3）。

## generatedRoutes 51 條

| route_name | 型 | parent | 要點（meta） |
|---|---|---|---|
| about | 頁 | — | o=10、icon fluent:book-information-24-regular |
| alova | 目錄 | — | o=7、icon carbon:http |
| alova_request | 頁 | alova | o=1（⚠️c） |
| alova_scenes | 頁 | alova | o=3、icon cbi:scene-dynamic（⚠️c） |
| function_hide-child | 目錄 | function（基線） | o=2、無 component、顯式 redirect=首子 |
| function_hide-child_one | 頁 | function_hide-child | hideInMenu、activeMenu=function_hide-child |
| function_hide-child_three | 頁 | function_hide-child | 同上 |
| function_hide-child_two | 頁 | function_hide-child | 同上 |
| function_multi-tab | 頁 | function（基線） | multiTab、hideInMenu、activeMenu=function_tab |
| function_request | 頁 | function（基線） | o=3、icon carbon:network-overlay（⚠️c） |
| function_super-page | 頁 | function（基線） | o=5、meta.roles=['R_SUPER']（dynamic mode 不消費、照實 seed 對應欄位形） |
| function_tab | 頁 | function（基線） | o=1、icon ic:round-tab |
| multi-menu | 目錄 | — | o=8、無 icon |
| multi-menu_first | 目錄 | multi-menu | o=1 |
| multi-menu_first_child | 頁 | multi-menu_first | — |
| multi-menu_second | 目錄 | multi-menu | o=2 |
| multi-menu_second_child | 目錄 | multi-menu_second | — |
| multi-menu_second_child_home | 頁 | multi-menu_second_child | **depth-3（最深）** |
| plugin | 目錄 | — | o=7、icon clarity:plugin-line、**menu_name 中文「插件示例」** |
| plugin_barcode／copy／excel／map／pdf／pinyin／print／swiper／typeit／video | 頁 ×10 | plugin | excel 帶 keepAlive；無 order |
| plugin_charts | 目錄 | plugin | — |
| plugin_charts_antv／echarts／vchart | 頁 ×3 | plugin_charts | vchart＝**localIcon visactor**（icon_type=2） |
| plugin_editor | 目錄 | plugin | — |
| plugin_editor_markdown／quill | 頁 ×2 | plugin_editor | — |
| plugin_gantt | 目錄 | plugin | — |
| plugin_gantt_dhtmlx／vtable | 頁 ×2 | plugin_gantt | vtable＝localIcon visactor |
| plugin_icon | 頁 | plugin | **localIcon custom-icon** |
| plugin_tables | 目錄 | plugin | — |
| plugin_tables_vtable | 頁 | plugin_tables | localIcon visactor |
| pro-naive | 目錄 | — | o=7 |
| pro-naive_form | 目錄 | pro-naive | — |
| pro-naive_form_basic／query／step | 頁 ×3 | pro-naive_form | — |
| pro-naive_table | 目錄 | pro-naive | — |
| pro-naive_table_remote／row-edit | 頁 ×2 | pro-naive_table | — |
| user-center | 頁 | — | hideInMenu |

## customRoutes 15 條（`src/router/routes/index.ts`——不在 routes.ts、勿漏）

| route_name | 型 | parent | 要點 |
|---|---|---|---|
| exception | 目錄 | — | o=7 |
| exception_403／404／500 | 頁 ×3 | exception | component=view.403 等（復用 _builtin view） |
| document | 目錄 | — | o=2 |
| document_project | 頁 | document | o=1、localIcon logo、**props.url 形→href 化（R4-D2）** |
| document_project-link | 頁 | document | o=2、localIcon logo、href 形原樣 |
| document_video | 頁 | document | o=2、localIcon logo、href 形原樣 |
| document_vue／vite／unocss／naive／pro-naive／antd／alova | 頁 ×7 | document | o=3/4/5/6/6/7/7、**props.url 形→href 化（R4-D2）**；alova 帶 localIcon alova |

## 不變式

- 入選恰 66；⚠️c 三頁（alova_request／alova_scenes／function_request）在集內。
- 與基線雙層不重疊：route_name 不與 m002 的 10 條撞；policy v1 不與 m002 的 17 列撞。
- props.url 形 ×8 全部 href 化（外開）；href 原生形 ×2；其餘無 href。
- localIcon ×8（visactor×3、custom-icon、logo×3、alova）→ icon_type=2；其餘 iconify → icon_type=1（無 icon 者 NULL）。
- 頂層 order 撞號（alova/plugin/pro-naive/exception 皆 o=7）照 meta 原樣、不調。
- m004 down：sys_menu 與 casbin 皆**限定本表 66 個 route_name**刪除。
