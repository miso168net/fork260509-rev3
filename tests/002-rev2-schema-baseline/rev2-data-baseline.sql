--
-- PostgreSQL database dump
--


-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: casbin_rule; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.casbin_rule (id, ptype, v0, v1, v2, v3, v4, v5, protected, created_at, created_by) FROM stdin;
1	p	R_SUPER	/systemManage/getUserList	GET				f	<TS_REDACTED>	\N
10	p	R_SUPER	manage_role	menu				t	<TS_REDACTED>	\N
11	p	R_SUPER	manage_menu	menu				t	<TS_REDACTED>	\N
12	p	R_SUPER	/systemManage/getRoleList	GET				f	<TS_REDACTED>	\N
13	p	R_ADMIN	/systemManage/getRoleList	GET				f	<TS_REDACTED>	\N
14	p	R_SUPER	/systemManage/getAllRoles	GET				f	<TS_REDACTED>	\N
15	p	R_ADMIN	/systemManage/getAllRoles	GET				f	<TS_REDACTED>	\N
16	p	R_USER_COMMON	/systemManage/getAllRoles	GET				f	<TS_REDACTED>	\N
17	p	R_SUPER	/systemManage/addUser	POST				f	<TS_REDACTED>	\N
18	p	R_SUPER	/systemManage/updateUser	POST				f	<TS_REDACTED>	\N
19	p	R_SUPER	/systemManage/deleteUser	DELETE				f	<TS_REDACTED>	\N
2	p	R_ADMIN	/systemManage/getUserList	GET				f	<TS_REDACTED>	\N
20	p	R_SUPER	/systemManage/batchDeleteUser	DELETE				f	<TS_REDACTED>	\N
21	p	R_SUPER	/systemManage/addRole	POST				f	<TS_REDACTED>	\N
22	p	R_SUPER	/systemManage/updateRole	POST				f	<TS_REDACTED>	\N
23	p	R_SUPER	/systemManage/deleteRole	DELETE				f	<TS_REDACTED>	\N
24	p	R_SUPER	/systemManage/batchDeleteRole	DELETE				f	<TS_REDACTED>	\N
25	p	R_SUPER	/systemManage/getMenuList/v2	GET				f	<TS_REDACTED>	\N
26	p	R_SUPER	/systemManage/getAllPages	GET				f	<TS_REDACTED>	\N
27	p	R_SUPER	/systemManage/getMenuTree	GET				f	<TS_REDACTED>	\N
28	p	R_SUPER	/systemManage/addMenu	POST				f	<TS_REDACTED>	\N
29	p	R_SUPER	/systemManage/updateMenu	POST				f	<TS_REDACTED>	\N
3	p	R_SUPER	home	menu				f	<TS_REDACTED>	\N
30	p	R_SUPER	/systemManage/deleteMenu	DELETE				f	<TS_REDACTED>	\N
31	p	R_SUPER	/systemManage/batchDeleteMenu	DELETE				f	<TS_REDACTED>	\N
32	p	R_SUPER	/systemManage/getRoleMenu	GET				t	<TS_REDACTED>	\N
33	p	R_SUPER	/systemManage/updateRoleMenu	POST				t	<TS_REDACTED>	\N
34	p	R_SUPER	/systemManage/getRoleHome	GET				f	<TS_REDACTED>	\N
35	p	R_SUPER	/systemManage/updateRoleHome	POST				f	<TS_REDACTED>	\N
36	p	R_SUPER	B_CODE1	button				f	<TS_REDACTED>	\N
37	p	R_SUPER	B_CODE2	button				f	<TS_REDACTED>	\N
38	p	R_SUPER	B_CODE3	button				f	<TS_REDACTED>	\N
39	p	R_SUPER	user:add	button				f	<TS_REDACTED>	\N
4	p	R_ADMIN	home	menu				f	<TS_REDACTED>	\N
40	p	R_SUPER	user:edit	button				f	<TS_REDACTED>	\N
41	p	R_SUPER	user:delete	button				f	<TS_REDACTED>	\N
42	p	R_ADMIN	B_CODE2	button				f	<TS_REDACTED>	\N
43	p	R_ADMIN	B_CODE3	button				f	<TS_REDACTED>	\N
44	p	R_ADMIN	user:edit	button				f	<TS_REDACTED>	\N
45	p	R_USER_COMMON	B_CODE3	button				f	<TS_REDACTED>	\N
46	p	R_SUPER	function	menu				f	<TS_REDACTED>	\N
47	p	R_ADMIN	function	menu				f	<TS_REDACTED>	\N
48	p	R_USER_COMMON	function	menu				f	<TS_REDACTED>	\N
49	p	R_SUPER	function_toggle-auth	menu				f	<TS_REDACTED>	\N
5	p	R_USER_COMMON	home	menu				f	<TS_REDACTED>	\N
50	p	R_ADMIN	function_toggle-auth	menu				f	<TS_REDACTED>	\N
51	p	R_USER_COMMON	function_toggle-auth	menu				f	<TS_REDACTED>	\N
52	p	R_SUPER	/systemManage/getAllButtons	GET				t	<TS_REDACTED>	\N
53	p	R_SUPER	/systemManage/getRoleButton	GET				t	<TS_REDACTED>	\N
54	p	R_SUPER	/systemManage/updateRoleButton	POST				t	<TS_REDACTED>	\N
55	p	R_SUPER	/systemManage/getAllEndpoints	GET				t	<TS_REDACTED>	\N
56	p	R_SUPER	/systemManage/getRoleEndpoints	GET				t	<TS_REDACTED>	\N
57	p	R_SUPER	/systemManage/updateRoleEndpoints	POST				t	<TS_REDACTED>	\N
58	p	R_SUPER	role:add	button				f	<TS_REDACTED>	\N
59	p	R_SUPER	role:edit	button				f	<TS_REDACTED>	\N
6	p	R_SUPER	manage_user	menu				f	<TS_REDACTED>	\N
60	p	R_SUPER	role:delete	button				f	<TS_REDACTED>	\N
61	p	R_SUPER	menu:add	button				f	<TS_REDACTED>	\N
62	p	R_SUPER	menu:edit	button				f	<TS_REDACTED>	\N
63	p	R_SUPER	menu:delete	button				f	<TS_REDACTED>	\N
64	p	R_SUPER	/systemManage/getDeletedMenus	GET				t	<TS_REDACTED>	\N
65	p	R_SUPER	/systemManage/restoreMenu	POST				t	<TS_REDACTED>	\N
66	p	R_SUPER	/systemManage/getSystemSettings	GET				t	<TS_REDACTED>	\N
67	p	R_SUPER	/systemManage/updateSystemSetting	POST				t	<TS_REDACTED>	\N
68	p	R_SUPER	/systemManage/updateUserSessionPolicy	POST				t	<TS_REDACTED>	\N
69	p	R_SUPER	manage_system-settings	menu				t	<TS_REDACTED>	\N
7	p	R_ADMIN	manage_user	menu				f	<TS_REDACTED>	\N
70	p	R_SUPER	/systemManage/getArchivedPolicies	GET				t	<TS_REDACTED>	\N
71	p	R_SUPER	/systemManage/restorePolicy	POST				t	<TS_REDACTED>	\N
72	p	R_SUPER	manage_policy-archive	menu				t	<TS_REDACTED>	\N
8	p	R_SUPER	manage_user-detail	menu				f	<TS_REDACTED>	\N
9	p	R_ADMIN	manage_user-detail	menu				f	<TS_REDACTED>	\N
\.


--
-- Data for Name: sys_menu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sys_menu (id, parent_id, route_name, menu_type, menu_name, route_path, component, icon, icon_type, i18n_key, "order", status, hide_in_menu, keep_alive, constant, multi_tab, href, active_menu, fixed_index_in_tab, query, buttons, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by, protected) FROM stdin;
1	\N	home	2	home	/home	layout.base$view.home	mdi:monitor-dashboard	1	route.home	1	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	t
10	2	manage_policy-archive	2	manage_policy-archive	/manage/policy-archive	view.manage_policy-archive	mdi:recycle	1	route.manage_policy-archive	5	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	t
2	\N	manage	1	manage	/manage	layout.base	carbon:cloud-service-management	1	route.manage	9	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	t
3	2	manage_user	2	manage_user	/manage/user	view.manage_user	ic:round-manage-accounts	1	route.manage_user	1	1	\N	\N	\N	\N	\N	\N	\N	\N	[{"code": "user:add", "desc": "新增用户"}, {"code": "user:edit", "desc": "编辑用户"}, {"code": "user:delete", "desc": "删除用户"}]	<TS_REDACTED>	\N	\N	\N	\N	\N	t
4	2	manage_role	2	manage_role	/manage/role	view.manage_role	carbon:user-role	1	route.manage_role	2	1	\N	\N	\N	\N	\N	\N	\N	\N	[{"code": "role:add", "desc": "新增角色"}, {"code": "role:edit", "desc": "编辑角色"}, {"code": "role:delete", "desc": "删除角色"}]	<TS_REDACTED>	\N	\N	\N	\N	\N	t
5	2	manage_menu	2	manage_menu	/manage/menu	view.manage_menu	material-symbols:route	1	route.manage_menu	3	1	\N	t	\N	\N	\N	\N	\N	\N	[{"code": "menu:add", "desc": "新增菜单"}, {"code": "menu:edit", "desc": "编辑菜单"}, {"code": "menu:delete", "desc": "删除菜单"}]	<TS_REDACTED>	\N	\N	\N	\N	\N	t
6	2	manage_user-detail	2	manage_user-detail	/manage/user-detail/:id	view.manage_user-detail	\N	\N	route.manage_user-detail	\N	1	t	\N	\N	\N	\N	manage_user	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	t
7	\N	function	1	function	/function	layout.base	icon-park-outline:all-application	1	route.function	6	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	f
8	7	function_toggle-auth	2	function_toggle-auth	/function/toggle-auth	view.function_toggle-auth	ic:round-construction	1	route.function_toggle-auth	4	1	\N	\N	\N	\N	\N	\N	\N	\N	[{"code": "B_CODE1", "desc": "超级管理员可见"}, {"code": "B_CODE2", "desc": "管理员可见"}, {"code": "B_CODE3", "desc": "管理员或普通用户可见"}]	<TS_REDACTED>	\N	\N	\N	\N	\N	f
9	2	manage_system-settings	2	manage_system-settings	/manage/system-settings	view.manage_system-settings	mdi:cog	1	route.manage_system-settings	4	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	<TS_REDACTED>	\N	\N	\N	\N	\N	t
\.


--
-- Data for Name: sys_role; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sys_role (id, code, name, deleted_at, role_desc, status, created_at, created_by, updated_by, deleted_by, updated_at, home) FROM stdin;
1	R_SUPER	超级管理员	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	home
2	R_ADMIN	管理员	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	home
3	R_USER_COMMON	普通用户	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	home
\.


--
-- Data for Name: sys_user; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sys_user (id, user_name, password, deleted_at, nick_name, user_gender, user_phone, user_email, status, created_at, created_by, updated_by, deleted_by, updated_at, current_session_id, session_policy) FROM stdin;
1	Super	<ARGON2_REDACTED>	\N	Super	\N	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	\N	inherit
2	Admin	<ARGON2_REDACTED>	\N	Admin	\N	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	\N	inherit
3	User	<ARGON2_REDACTED>	\N	User01	\N	\N	\N	1	<TS_REDACTED>	\N	\N	\N	\N	\N	inherit
\.


--
-- Data for Name: sys_user_role; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sys_user_role (user_id, role_id) FROM stdin;
1	1
2	2
3	3
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.system_settings (setting_key, setting_value, value_type, description, created_at, created_by, updated_at, updated_by, deleted_at, deleted_by) FROM stdin;
single_session_default	off	enum:on,off	全站單一-session 預設	<TS_REDACTED>	\N	\N	\N	\N	\N
\.


--
-- Name: casbin_rule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.casbin_rule_id_seq', <SETVAL_REDACTED>);


--
-- Name: sys_menu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sys_menu_id_seq', <SETVAL_REDACTED>);


--
-- Name: sys_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sys_role_id_seq', <SETVAL_REDACTED>);


--
-- Name: sys_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sys_user_id_seq', <SETVAL_REDACTED>);


--
-- PostgreSQL database dump complete
--


