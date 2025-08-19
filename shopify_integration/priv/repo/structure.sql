--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: shopify_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shopify_orders (
    id bigint NOT NULL,
    shopify_order_id character varying(255) NOT NULL,
    shop_domain character varying(255) NOT NULL,
    customer_name character varying(255),
    total_price numeric(10,2),
    currency character varying(255),
    order_status character varying(255),
    created_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: shopify_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shopify_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shopify_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shopify_orders_id_seq OWNED BY public.shopify_orders.id;


--
-- Name: shopify_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopify_orders ALTER COLUMN id SET DEFAULT nextval('public.shopify_orders_id_seq'::regclass);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: shopify_orders shopify_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopify_orders
    ADD CONSTRAINT shopify_orders_pkey PRIMARY KEY (id);


--
-- Name: shopify_orders_order_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shopify_orders_order_status_index ON public.shopify_orders USING btree (order_status);


--
-- Name: shopify_orders_shop_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shopify_orders_shop_domain_index ON public.shopify_orders USING btree (shop_domain);


--
-- Name: shopify_orders_shopify_order_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX shopify_orders_shopify_order_id_index ON public.shopify_orders USING btree (shopify_order_id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250816220025);
