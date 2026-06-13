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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: casbin_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.casbin_rule (
    id bigint NOT NULL,
    ptype character varying(18) NOT NULL,
    v0 character varying(125) NOT NULL,
    v1 character varying(125) NOT NULL,
    v2 character varying(125) NOT NULL,
    v3 character varying(125) NOT NULL,
    v4 character varying(125) NOT NULL,
    v5 character varying(125) NOT NULL,
    protected boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint
);


--
-- Name: casbin_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.casbin_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: casbin_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.casbin_rule_id_seq OWNED BY public.casbin_rule.id;


--
-- Name: sys_access_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_access_log (
    id bigint NOT NULL,
    operator_id bigint NOT NULL,
    method text NOT NULL,
    path text NOT NULL,
    http_status integer NOT NULL,
    client_ip inet NOT NULL,
    x_forwarded_for text,
    region text,
    trace_id text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sys_access_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_access_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_access_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_access_log_id_seq OWNED BY public.sys_access_log.id;


--
-- Name: sys_casbin_policy_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_casbin_policy_archive (
    id bigint NOT NULL,
    ptype character varying(18) NOT NULL,
    v0 character varying(125) NOT NULL,
    v1 character varying(125) NOT NULL,
    v2 character varying(125) NOT NULL,
    v3 character varying(125) DEFAULT ''::character varying NOT NULL,
    v4 character varying(125) DEFAULT ''::character varying NOT NULL,
    v5 character varying(125) DEFAULT ''::character varying NOT NULL,
    created_at timestamp with time zone,
    created_by bigint,
    archived_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    archived_by bigint,
    archive_reason character varying(32) NOT NULL
);


--
-- Name: sys_casbin_policy_archive_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_casbin_policy_archive_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_casbin_policy_archive_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_casbin_policy_archive_id_seq OWNED BY public.sys_casbin_policy_archive.id;


--
-- Name: sys_login_attempt; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_login_attempt (
    id bigint NOT NULL,
    attempted_user_name text NOT NULL,
    success boolean NOT NULL,
    operator_id bigint,
    client_ip inet NOT NULL,
    x_forwarded_for text,
    region text,
    trace_id text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sys_login_attempt_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_login_attempt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_login_attempt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_login_attempt_id_seq OWNED BY public.sys_login_attempt.id;


--
-- Name: sys_menu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_menu (
    id bigint NOT NULL,
    parent_id bigint,
    route_name character varying NOT NULL,
    menu_type smallint,
    menu_name character varying NOT NULL,
    route_path character varying,
    component character varying,
    icon character varying,
    icon_type smallint,
    i18n_key character varying,
    "order" integer,
    status smallint,
    hide_in_menu boolean,
    keep_alive boolean,
    constant boolean,
    multi_tab boolean,
    href character varying,
    active_menu character varying,
    fixed_index_in_tab integer,
    query jsonb,
    buttons jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    protected boolean DEFAULT false NOT NULL
);


--
-- Name: sys_menu_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_menu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_menu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_menu_id_seq OWNED BY public.sys_menu.id;


--
-- Name: sys_operation_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_operation_log (
    id bigint NOT NULL,
    operation character varying(20) NOT NULL,
    entity_table character varying(64) NOT NULL,
    entity_id bigint,
    payload_before jsonb,
    payload_after jsonb,
    operator_id bigint,
    operator_ip inet,
    trace_id character varying(64),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sys_operation_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_operation_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_operation_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_operation_log_id_seq OWNED BY public.sys_operation_log.id;


--
-- Name: sys_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_role (
    id bigint NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    deleted_at timestamp with time zone,
    role_desc character varying,
    status smallint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_by bigint,
    deleted_by bigint,
    updated_at timestamp with time zone,
    home character varying
);


--
-- Name: sys_role_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_role_id_seq OWNED BY public.sys_role.id;


--
-- Name: sys_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_token (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash character varying(64) NOT NULL,
    rotation_chain character varying(36) NOT NULL,
    status character varying(20) NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sys_token_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_token_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_token_id_seq OWNED BY public.sys_token.id;


--
-- Name: sys_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_user (
    id bigint NOT NULL,
    user_name character varying NOT NULL,
    password character varying NOT NULL,
    deleted_at timestamp with time zone,
    nick_name character varying,
    user_gender smallint,
    user_phone character varying,
    user_email character varying,
    status smallint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_by bigint,
    deleted_by bigint,
    updated_at timestamp with time zone,
    current_session_id character varying(36),
    session_policy character varying(20) DEFAULT 'inherit'::character varying NOT NULL
);


--
-- Name: sys_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sys_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sys_user_id_seq OWNED BY public.sys_user.id;


--
-- Name: sys_user_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sys_user_role (
    user_id bigint NOT NULL,
    role_id bigint NOT NULL
);


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_settings (
    setting_key character varying(64) NOT NULL,
    setting_value character varying NOT NULL,
    value_type character varying NOT NULL,
    description character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_at timestamp with time zone,
    updated_by bigint,
    deleted_at timestamp with time zone,
    deleted_by bigint
);


--
-- Name: casbin_rule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.casbin_rule ALTER COLUMN id SET DEFAULT nextval('public.casbin_rule_id_seq'::regclass);


--
-- Name: sys_access_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_access_log ALTER COLUMN id SET DEFAULT nextval('public.sys_access_log_id_seq'::regclass);


--
-- Name: sys_casbin_policy_archive id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_casbin_policy_archive ALTER COLUMN id SET DEFAULT nextval('public.sys_casbin_policy_archive_id_seq'::regclass);


--
-- Name: sys_login_attempt id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_login_attempt ALTER COLUMN id SET DEFAULT nextval('public.sys_login_attempt_id_seq'::regclass);


--
-- Name: sys_menu id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_menu ALTER COLUMN id SET DEFAULT nextval('public.sys_menu_id_seq'::regclass);


--
-- Name: sys_operation_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_operation_log ALTER COLUMN id SET DEFAULT nextval('public.sys_operation_log_id_seq'::regclass);


--
-- Name: sys_role id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_role ALTER COLUMN id SET DEFAULT nextval('public.sys_role_id_seq'::regclass);


--
-- Name: sys_token id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_token ALTER COLUMN id SET DEFAULT nextval('public.sys_token_id_seq'::regclass);


--
-- Name: sys_user id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_user ALTER COLUMN id SET DEFAULT nextval('public.sys_user_id_seq'::regclass);


--
-- Name: casbin_rule casbin_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.casbin_rule
    ADD CONSTRAINT casbin_rule_pkey PRIMARY KEY (id);


--
-- Name: sys_access_log sys_access_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_access_log
    ADD CONSTRAINT sys_access_log_pkey PRIMARY KEY (id);


--
-- Name: sys_casbin_policy_archive sys_casbin_policy_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_casbin_policy_archive
    ADD CONSTRAINT sys_casbin_policy_archive_pkey PRIMARY KEY (id);


--
-- Name: sys_login_attempt sys_login_attempt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_login_attempt
    ADD CONSTRAINT sys_login_attempt_pkey PRIMARY KEY (id);


--
-- Name: sys_menu sys_menu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_menu
    ADD CONSTRAINT sys_menu_pkey PRIMARY KEY (id);


--
-- Name: sys_operation_log sys_operation_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_operation_log
    ADD CONSTRAINT sys_operation_log_pkey PRIMARY KEY (id);


--
-- Name: sys_role sys_role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_role
    ADD CONSTRAINT sys_role_pkey PRIMARY KEY (id);


--
-- Name: sys_token sys_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_token
    ADD CONSTRAINT sys_token_pkey PRIMARY KEY (id);


--
-- Name: sys_token sys_token_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_token
    ADD CONSTRAINT sys_token_token_hash_key UNIQUE (token_hash);


--
-- Name: sys_user sys_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_user
    ADD CONSTRAINT sys_user_pkey PRIMARY KEY (id);


--
-- Name: sys_user_role sys_user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sys_user_role
    ADD CONSTRAINT sys_user_role_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (setting_key);


--
-- Name: casbin_rule unique_key_sea_orm_adapter; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.casbin_rule
    ADD CONSTRAINT unique_key_sea_orm_adapter UNIQUE (ptype, v0, v1, v2, v3, v4, v5);


--
-- Name: idx_casbin_archive_archived_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_casbin_archive_archived_at ON public.sys_casbin_policy_archive USING btree (archived_at);


--
-- Name: idx_casbin_archive_role_dim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_casbin_archive_role_dim ON public.sys_casbin_policy_archive USING btree (v0, v2);


--
-- Name: idx_login_attempt_ip_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_attempt_ip_time ON public.sys_login_attempt USING btree (client_ip, created_at);


--
-- Name: idx_login_attempt_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_login_attempt_user_time ON public.sys_login_attempt USING btree (attempted_user_name, created_at);


--
-- Name: idx_sys_token_chain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sys_token_chain ON public.sys_token USING btree (rotation_chain);


--
-- Name: idx_sys_token_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sys_token_expires_at ON public.sys_token USING btree (expires_at);


--
-- Name: idx_sys_token_user_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sys_token_user_active ON public.sys_token USING btree (user_id) WHERE ((status)::text = 'active'::text);


--
-- Name: sys_menu_route_name_active_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sys_menu_route_name_active_uniq ON public.sys_menu USING btree (route_name) WHERE (deleted_at IS NULL);


--
-- Name: sys_role_code_active_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sys_role_code_active_uniq ON public.sys_role USING btree (code) WHERE (deleted_at IS NULL);


--
-- Name: sys_user_user_name_active_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sys_user_user_name_active_uniq ON public.sys_user USING btree (user_name) WHERE (deleted_at IS NULL);


--
-- PostgreSQL database dump complete
--


