--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 16.2

-- Started on 2026-09-09 12:52:47

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 85789)
-- Name: admin; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA admin;


ALTER SCHEMA admin OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 85792)
-- Name: analyses; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA analyses;


ALTER SCHEMA analyses OWNER TO postgres;

--
-- TOC entry 9 (class 2615 OID 85791)
-- Name: patrimoine; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA patrimoine;


ALTER SCHEMA patrimoine OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 85790)
-- Name: reseaux; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA reseaux;


ALTER SCHEMA reseaux OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 118066)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 4265 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 225 (class 1259 OID 256597)
-- Name: communes; Type: TABLE; Schema: admin; Owner: postgres
--

CREATE TABLE admin.communes (
    id integer NOT NULL,
    code_insee character varying(5) NOT NULL,
    nom character varying(100) NOT NULL,
    geom public.geometry(MultiPolygon,2154) NOT NULL,
    CONSTRAINT chk_communes_geom_valid CHECK (public.st_isvalid(geom))
);


ALTER TABLE admin.communes OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 256596)
-- Name: communes_id_seq; Type: SEQUENCE; Schema: admin; Owner: postgres
--

CREATE SEQUENCE admin.communes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE admin.communes_id_seq OWNER TO postgres;

--
-- TOC entry 4266 (class 0 OID 0)
-- Dependencies: 224
-- Name: communes_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: postgres
--

ALTER SEQUENCE admin.communes_id_seq OWNED BY admin.communes.id;


--
-- TOC entry 229 (class 1259 OID 256734)
-- Name: batiments; Type: TABLE; Schema: patrimoine; Owner: postgres
--

CREATE TABLE patrimoine.batiments (
    id integer NOT NULL,
    type_bati character varying(50),
    commune_id integer,
    geom public.geometry(MultiPolygon,2154) NOT NULL,
    CONSTRAINT chk_batiments_geom_valid CHECK (public.st_isvalid(geom))
);


ALTER TABLE patrimoine.batiments OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 256663)
-- Name: troncons_routiers; Type: TABLE; Schema: reseaux; Owner: postgres
--

CREATE TABLE reseaux.troncons_routiers (
    id integer NOT NULL,
    nom character varying(150),
    type_voie character varying(50),
    commune_id integer,
    geom public.geometry(LineString,2154) NOT NULL,
    CONSTRAINT chk_troncons_geom_valid CHECK (public.st_isvalid(geom))
);


ALTER TABLE reseaux.troncons_routiers OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 256763)
-- Name: stats_par_commune; Type: MATERIALIZED VIEW; Schema: analyses; Owner: postgres
--

CREATE MATERIALIZED VIEW analyses.stats_par_commune AS
 SELECT c.code_insee,
    c.nom,
    COALESCE(r.km_routes, (0)::numeric) AS km_routes,
    COALESCE(b.nb_batiments, (0)::bigint) AS nb_batiments,
    round(((public.st_area(c.geom))::numeric / (1000000)::numeric), 2) AS surface_km2
   FROM ((admin.communes c
     LEFT JOIN ( SELECT troncons_routiers.commune_id,
            round(((sum(public.st_length(troncons_routiers.geom)))::numeric / (1000)::numeric), 2) AS km_routes
           FROM reseaux.troncons_routiers
          GROUP BY troncons_routiers.commune_id) r ON ((r.commune_id = c.id)))
     LEFT JOIN ( SELECT batiments.commune_id,
            count(*) AS nb_batiments
           FROM patrimoine.batiments
          GROUP BY batiments.commune_id) b ON ((b.commune_id = c.id)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW analyses.stats_par_commune OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 256733)
-- Name: batiments_id_seq; Type: SEQUENCE; Schema: patrimoine; Owner: postgres
--

CREATE SEQUENCE patrimoine.batiments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE patrimoine.batiments_id_seq OWNER TO postgres;

--
-- TOC entry 4267 (class 0 OID 0)
-- Dependencies: 228
-- Name: batiments_id_seq; Type: SEQUENCE OWNED BY; Schema: patrimoine; Owner: postgres
--

ALTER SEQUENCE patrimoine.batiments_id_seq OWNED BY patrimoine.batiments.id;


--
-- TOC entry 226 (class 1259 OID 256662)
-- Name: troncons_routiers_id_seq; Type: SEQUENCE; Schema: reseaux; Owner: postgres
--

CREATE SEQUENCE reseaux.troncons_routiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE reseaux.troncons_routiers_id_seq OWNER TO postgres;

--
-- TOC entry 4268 (class 0 OID 0)
-- Dependencies: 226
-- Name: troncons_routiers_id_seq; Type: SEQUENCE OWNED BY; Schema: reseaux; Owner: postgres
--

ALTER SEQUENCE reseaux.troncons_routiers_id_seq OWNED BY reseaux.troncons_routiers.id;


--
-- TOC entry 4083 (class 2604 OID 256600)
-- Name: communes id; Type: DEFAULT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes ALTER COLUMN id SET DEFAULT nextval('admin.communes_id_seq'::regclass);


--
-- TOC entry 4085 (class 2604 OID 256737)
-- Name: batiments id; Type: DEFAULT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments ALTER COLUMN id SET DEFAULT nextval('patrimoine.batiments_id_seq'::regclass);


--
-- TOC entry 4084 (class 2604 OID 256666)
-- Name: troncons_routiers id; Type: DEFAULT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers ALTER COLUMN id SET DEFAULT nextval('reseaux.troncons_routiers_id_seq'::regclass);


--
-- TOC entry 4093 (class 2606 OID 256605)
-- Name: communes communes_pkey; Type: CONSTRAINT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes
    ADD CONSTRAINT communes_pkey PRIMARY KEY (id);


--
-- TOC entry 4096 (class 2606 OID 256607)
-- Name: communes uq_communes_insee; Type: CONSTRAINT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes
    ADD CONSTRAINT uq_communes_insee UNIQUE (code_insee);


--
-- TOC entry 4102 (class 2606 OID 256742)
-- Name: batiments batiments_pkey; Type: CONSTRAINT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments
    ADD CONSTRAINT batiments_pkey PRIMARY KEY (id);


--
-- TOC entry 4100 (class 2606 OID 256671)
-- Name: troncons_routiers troncons_routiers_pkey; Type: CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers
    ADD CONSTRAINT troncons_routiers_pkey PRIMARY KEY (id);


--
-- TOC entry 4094 (class 1259 OID 256749)
-- Name: idx_communes_geom; Type: INDEX; Schema: admin; Owner: postgres
--

CREATE INDEX idx_communes_geom ON admin.communes USING gist (geom);


--
-- TOC entry 4105 (class 1259 OID 256770)
-- Name: idx_stats_insee; Type: INDEX; Schema: analyses; Owner: postgres
--

CREATE UNIQUE INDEX idx_stats_insee ON analyses.stats_par_commune USING btree (code_insee);


--
-- TOC entry 4103 (class 1259 OID 256762)
-- Name: idx_batiments_commune; Type: INDEX; Schema: patrimoine; Owner: postgres
--

CREATE INDEX idx_batiments_commune ON patrimoine.batiments USING btree (commune_id);


--
-- TOC entry 4104 (class 1259 OID 256752)
-- Name: idx_batiments_geom; Type: INDEX; Schema: patrimoine; Owner: postgres
--

CREATE INDEX idx_batiments_geom ON patrimoine.batiments USING gist (geom);


--
-- TOC entry 4097 (class 1259 OID 256761)
-- Name: idx_troncons_commune; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX idx_troncons_commune ON reseaux.troncons_routiers USING btree (commune_id);


--
-- TOC entry 4098 (class 1259 OID 256750)
-- Name: idx_troncons_geom; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX idx_troncons_geom ON reseaux.troncons_routiers USING gist (geom);


--
-- TOC entry 4107 (class 2606 OID 256743)
-- Name: batiments batiments_commune_id_fkey; Type: FK CONSTRAINT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments
    ADD CONSTRAINT batiments_commune_id_fkey FOREIGN KEY (commune_id) REFERENCES admin.communes(id);


--
-- TOC entry 4106 (class 2606 OID 256672)
-- Name: troncons_routiers troncons_routiers_commune_id_fkey; Type: FK CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers
    ADD CONSTRAINT troncons_routiers_commune_id_fkey FOREIGN KEY (commune_id) REFERENCES admin.communes(id);


--
-- TOC entry 4261 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA admin; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA admin TO sig_lecture;


--
-- TOC entry 4262 (class 0 OID 0)
-- Dependencies: 10
-- Name: SCHEMA analyses; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA analyses TO sig_lecture;


--
-- TOC entry 4263 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA patrimoine; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA patrimoine TO sig_lecture;


--
-- TOC entry 4264 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA reseaux; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA reseaux TO sig_lecture;


-- Completed on 2026-09-09 12:52:47

--
-- PostgreSQL database dump complete
--

