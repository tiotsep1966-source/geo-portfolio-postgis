--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 16.2

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
-- Name: admin; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA admin;


ALTER SCHEMA admin OWNER TO postgres;

--
-- Name: analyses; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA analyses;


ALTER SCHEMA analyses OWNER TO postgres;

--
-- Name: patrimoine; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA patrimoine;


ALTER SCHEMA patrimoine OWNER TO postgres;

--
-- Name: reseaux; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA reseaux;


ALTER SCHEMA reseaux OWNER TO postgres;

--
-- Name: secours; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA secours;


ALTER SCHEMA secours OWNER TO postgres;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: pgrouting; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgrouting WITH SCHEMA public;


--
-- Name: EXTENSION pgrouting; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgrouting IS 'pgRouting Extension';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
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
-- Name: communes_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: postgres
--

ALTER SEQUENCE admin.communes_id_seq OWNED BY admin.communes.id;


--
-- Name: casernes_pompiers; Type: TABLE; Schema: secours; Owner: postgres
--

CREATE TABLE secours.casernes_pompiers (
    id integer NOT NULL,
    nom character varying(150),
    commune_id integer,
    geom public.geometry(Point,2154) NOT NULL,
    noeud_proche bigint,
    CONSTRAINT chk_casernes_geom_valid CHECK (public.st_isvalid(geom))
);


ALTER TABLE secours.casernes_pompiers OWNER TO postgres;

--
-- Name: distance_caserne_par_commune; Type: MATERIALIZED VIEW; Schema: analyses; Owner: postgres
--

CREATE MATERIALIZED VIEW analyses.distance_caserne_par_commune AS
 SELECT c.code_insee,
    c.nom,
    round(((( SELECT public.st_distance(public.st_centroid(c.geom), p.geom) AS st_distance
           FROM secours.casernes_pompiers p
          ORDER BY (public.st_centroid(c.geom) OPERATOR(public.<->) p.geom)
         LIMIT 1))::numeric / (1000)::numeric), 2) AS distance_km_caserne_proche
   FROM admin.communes c
  WITH NO DATA;


ALTER MATERIALIZED VIEW analyses.distance_caserne_par_commune OWNER TO postgres;

--
-- Name: isochrones_casernes; Type: TABLE; Schema: analyses; Owner: postgres
--

CREATE TABLE analyses.isochrones_casernes (
    caserne_id integer,
    caserne_nom character varying(150),
    node bigint,
    temps_min double precision,
    tranche text
);


ALTER TABLE analyses.isochrones_casernes OWNER TO postgres;

--
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
-- Name: troncons_routiers; Type: TABLE; Schema: reseaux; Owner: postgres
--

CREATE TABLE reseaux.troncons_routiers (
    id integer NOT NULL,
    nom character varying(150),
    type_voie character varying(50),
    commune_id integer,
    geom public.geometry(LineString,2154) NOT NULL,
    vitesse_kmh double precision,
    temps_min double precision,
    source bigint,
    target bigint,
    CONSTRAINT chk_troncons_geom_valid CHECK (public.st_isvalid(geom))
);


ALTER TABLE reseaux.troncons_routiers OWNER TO postgres;

--
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
-- Name: reseau_noeud_vertices_pgr; Type: TABLE; Schema: reseaux; Owner: postgres
--

CREATE TABLE reseaux.reseau_noeud_vertices_pgr (
    id bigint NOT NULL,
    cnt integer,
    chk integer,
    ein integer,
    eout integer,
    the_geom public.geometry(Point,2154)
);


ALTER TABLE reseaux.reseau_noeud_vertices_pgr OWNER TO postgres;

--
-- Name: temps_caserne_par_commune; Type: MATERIALIZED VIEW; Schema: analyses; Owner: postgres
--

CREATE MATERIALIZED VIEW analyses.temps_caserne_par_commune AS
 SELECT c.code_insee,
    c.nom,
    min(ic.temps_min) AS temps_min_caserne
   FROM ((admin.communes c
     JOIN LATERAL ( SELECT reseau_noeud_vertices_pgr.id
           FROM reseaux.reseau_noeud_vertices_pgr
          ORDER BY (public.st_centroid(c.geom) OPERATOR(public.<->) reseau_noeud_vertices_pgr.the_geom)
         LIMIT 1) v ON (true))
     JOIN analyses.isochrones_casernes ic ON ((ic.node = v.id)))
  GROUP BY c.code_insee, c.nom
  WITH NO DATA;


ALTER MATERIALIZED VIEW analyses.temps_caserne_par_commune OWNER TO postgres;

--
-- Name: zones_isochrones; Type: MATERIALIZED VIEW; Schema: analyses; Owner: postgres
--

CREATE MATERIALIZED VIEW analyses.zones_isochrones AS
 SELECT ic.caserne_id,
    ic.caserne_nom,
    ic.tranche,
    public.st_convexhull(public.st_collect(v.the_geom)) AS geom
   FROM (analyses.isochrones_casernes ic
     JOIN reseaux.reseau_noeud_vertices_pgr v ON ((v.id = ic.node)))
  GROUP BY ic.caserne_id, ic.caserne_nom, ic.tranche
  WITH NO DATA;


ALTER MATERIALIZED VIEW analyses.zones_isochrones OWNER TO postgres;

--
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
-- Name: batiments_id_seq; Type: SEQUENCE OWNED BY; Schema: patrimoine; Owner: postgres
--

ALTER SEQUENCE patrimoine.batiments_id_seq OWNED BY patrimoine.batiments.id;


--
-- Name: reseau_noeud; Type: TABLE; Schema: reseaux; Owner: postgres
--

CREATE TABLE reseaux.reseau_noeud (
    geom public.geometry,
    id integer NOT NULL,
    source integer,
    target integer,
    type_voie character varying(50),
    vitesse_kmh integer,
    cout_min double precision
);


ALTER TABLE reseaux.reseau_noeud OWNER TO postgres;

--
-- Name: reseau_noeud_id_seq; Type: SEQUENCE; Schema: reseaux; Owner: postgres
--

CREATE SEQUENCE reseaux.reseau_noeud_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE reseaux.reseau_noeud_id_seq OWNER TO postgres;

--
-- Name: reseau_noeud_id_seq; Type: SEQUENCE OWNED BY; Schema: reseaux; Owner: postgres
--

ALTER SEQUENCE reseaux.reseau_noeud_id_seq OWNED BY reseaux.reseau_noeud.id;


--
-- Name: reseau_noeud_vertices_pgr_id_seq; Type: SEQUENCE; Schema: reseaux; Owner: postgres
--

CREATE SEQUENCE reseaux.reseau_noeud_vertices_pgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE reseaux.reseau_noeud_vertices_pgr_id_seq OWNER TO postgres;

--
-- Name: reseau_noeud_vertices_pgr_id_seq; Type: SEQUENCE OWNED BY; Schema: reseaux; Owner: postgres
--

ALTER SEQUENCE reseaux.reseau_noeud_vertices_pgr_id_seq OWNED BY reseaux.reseau_noeud_vertices_pgr.id;


--
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
-- Name: troncons_routiers_id_seq; Type: SEQUENCE OWNED BY; Schema: reseaux; Owner: postgres
--

ALTER SEQUENCE reseaux.troncons_routiers_id_seq OWNED BY reseaux.troncons_routiers.id;


--
-- Name: casernes_pompiers_id_seq; Type: SEQUENCE; Schema: secours; Owner: postgres
--

CREATE SEQUENCE secours.casernes_pompiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE secours.casernes_pompiers_id_seq OWNER TO postgres;

--
-- Name: casernes_pompiers_id_seq; Type: SEQUENCE OWNED BY; Schema: secours; Owner: postgres
--

ALTER SEQUENCE secours.casernes_pompiers_id_seq OWNED BY secours.casernes_pompiers.id;


--
-- Name: communes id; Type: DEFAULT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes ALTER COLUMN id SET DEFAULT nextval('admin.communes_id_seq'::regclass);


--
-- Name: batiments id; Type: DEFAULT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments ALTER COLUMN id SET DEFAULT nextval('patrimoine.batiments_id_seq'::regclass);


--
-- Name: reseau_noeud id; Type: DEFAULT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud ALTER COLUMN id SET DEFAULT nextval('reseaux.reseau_noeud_id_seq'::regclass);


--
-- Name: reseau_noeud_vertices_pgr id; Type: DEFAULT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud_vertices_pgr ALTER COLUMN id SET DEFAULT nextval('reseaux.reseau_noeud_vertices_pgr_id_seq'::regclass);


--
-- Name: troncons_routiers id; Type: DEFAULT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers ALTER COLUMN id SET DEFAULT nextval('reseaux.troncons_routiers_id_seq'::regclass);


--
-- Name: casernes_pompiers id; Type: DEFAULT; Schema: secours; Owner: postgres
--

ALTER TABLE ONLY secours.casernes_pompiers ALTER COLUMN id SET DEFAULT nextval('secours.casernes_pompiers_id_seq'::regclass);


--
-- Name: communes communes_pkey; Type: CONSTRAINT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes
    ADD CONSTRAINT communes_pkey PRIMARY KEY (id);


--
-- Name: communes uq_communes_insee; Type: CONSTRAINT; Schema: admin; Owner: postgres
--

ALTER TABLE ONLY admin.communes
    ADD CONSTRAINT uq_communes_insee UNIQUE (code_insee);


--
-- Name: batiments batiments_pkey; Type: CONSTRAINT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments
    ADD CONSTRAINT batiments_pkey PRIMARY KEY (id);


--
-- Name: reseau_noeud reseau_noeud_pkey; Type: CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud
    ADD CONSTRAINT reseau_noeud_pkey PRIMARY KEY (id);


--
-- Name: reseau_noeud_vertices_pgr reseau_noeud_vertices_pgr_pkey; Type: CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud_vertices_pgr
    ADD CONSTRAINT reseau_noeud_vertices_pgr_pkey PRIMARY KEY (id);


--
-- Name: troncons_routiers troncons_routiers_pkey; Type: CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers
    ADD CONSTRAINT troncons_routiers_pkey PRIMARY KEY (id);


--
-- Name: casernes_pompiers casernes_pompiers_pkey; Type: CONSTRAINT; Schema: secours; Owner: postgres
--

ALTER TABLE ONLY secours.casernes_pompiers
    ADD CONSTRAINT casernes_pompiers_pkey PRIMARY KEY (id);


--
-- Name: idx_communes_geom; Type: INDEX; Schema: admin; Owner: postgres
--

CREATE INDEX idx_communes_geom ON admin.communes USING gist (geom);


--
-- Name: idx_distance_caserne_insee; Type: INDEX; Schema: analyses; Owner: postgres
--

CREATE UNIQUE INDEX idx_distance_caserne_insee ON analyses.distance_caserne_par_commune USING btree (code_insee);


--
-- Name: idx_stats_insee; Type: INDEX; Schema: analyses; Owner: postgres
--

CREATE UNIQUE INDEX idx_stats_insee ON analyses.stats_par_commune USING btree (code_insee);


--
-- Name: idx_temps_caserne_insee; Type: INDEX; Schema: analyses; Owner: postgres
--

CREATE UNIQUE INDEX idx_temps_caserne_insee ON analyses.temps_caserne_par_commune USING btree (code_insee);


--
-- Name: idx_batiments_commune; Type: INDEX; Schema: patrimoine; Owner: postgres
--

CREATE INDEX idx_batiments_commune ON patrimoine.batiments USING btree (commune_id);


--
-- Name: idx_batiments_geom; Type: INDEX; Schema: patrimoine; Owner: postgres
--

CREATE INDEX idx_batiments_geom ON patrimoine.batiments USING gist (geom);


--
-- Name: idx_reseau_noeud_geom; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX idx_reseau_noeud_geom ON reseaux.reseau_noeud USING gist (geom);


--
-- Name: idx_troncons_commune; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX idx_troncons_commune ON reseaux.troncons_routiers USING btree (commune_id);


--
-- Name: idx_troncons_geom; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX idx_troncons_geom ON reseaux.troncons_routiers USING gist (geom);


--
-- Name: reseau_noeud_source_idx; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX reseau_noeud_source_idx ON reseaux.reseau_noeud USING btree (source);


--
-- Name: reseau_noeud_target_idx; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX reseau_noeud_target_idx ON reseaux.reseau_noeud USING btree (target);


--
-- Name: reseau_noeud_vertices_pgr_the_geom_idx; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX reseau_noeud_vertices_pgr_the_geom_idx ON reseaux.reseau_noeud_vertices_pgr USING gist (the_geom);


--
-- Name: troncons_routiers_source_idx; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX troncons_routiers_source_idx ON reseaux.troncons_routiers USING btree (source);


--
-- Name: troncons_routiers_target_idx; Type: INDEX; Schema: reseaux; Owner: postgres
--

CREATE INDEX troncons_routiers_target_idx ON reseaux.troncons_routiers USING btree (target);


--
-- Name: idx_casernes_commune; Type: INDEX; Schema: secours; Owner: postgres
--

CREATE INDEX idx_casernes_commune ON secours.casernes_pompiers USING btree (commune_id);


--
-- Name: idx_casernes_geom; Type: INDEX; Schema: secours; Owner: postgres
--

CREATE INDEX idx_casernes_geom ON secours.casernes_pompiers USING gist (geom);


--
-- Name: isochrones_casernes fk_isochrone_caserne; Type: FK CONSTRAINT; Schema: analyses; Owner: postgres
--

ALTER TABLE ONLY analyses.isochrones_casernes
    ADD CONSTRAINT fk_isochrone_caserne FOREIGN KEY (caserne_id) REFERENCES secours.casernes_pompiers(id);


--
-- Name: isochrones_casernes fk_isochrone_noeud; Type: FK CONSTRAINT; Schema: analyses; Owner: postgres
--

ALTER TABLE ONLY analyses.isochrones_casernes
    ADD CONSTRAINT fk_isochrone_noeud FOREIGN KEY (node) REFERENCES reseaux.reseau_noeud_vertices_pgr(id);


--
-- Name: batiments batiments_commune_id_fkey; Type: FK CONSTRAINT; Schema: patrimoine; Owner: postgres
--

ALTER TABLE ONLY patrimoine.batiments
    ADD CONSTRAINT batiments_commune_id_fkey FOREIGN KEY (commune_id) REFERENCES admin.communes(id);


--
-- Name: reseau_noeud fk_noeud_source; Type: FK CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud
    ADD CONSTRAINT fk_noeud_source FOREIGN KEY (source) REFERENCES reseaux.reseau_noeud_vertices_pgr(id);


--
-- Name: reseau_noeud fk_noeud_target; Type: FK CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.reseau_noeud
    ADD CONSTRAINT fk_noeud_target FOREIGN KEY (target) REFERENCES reseaux.reseau_noeud_vertices_pgr(id);


--
-- Name: troncons_routiers troncons_routiers_commune_id_fkey; Type: FK CONSTRAINT; Schema: reseaux; Owner: postgres
--

ALTER TABLE ONLY reseaux.troncons_routiers
    ADD CONSTRAINT troncons_routiers_commune_id_fkey FOREIGN KEY (commune_id) REFERENCES admin.communes(id);


--
-- Name: casernes_pompiers casernes_pompiers_commune_id_fkey; Type: FK CONSTRAINT; Schema: secours; Owner: postgres
--

ALTER TABLE ONLY secours.casernes_pompiers
    ADD CONSTRAINT casernes_pompiers_commune_id_fkey FOREIGN KEY (commune_id) REFERENCES admin.communes(id);


--
-- Name: casernes_pompiers fk_caserne_noeud; Type: FK CONSTRAINT; Schema: secours; Owner: postgres
--

ALTER TABLE ONLY secours.casernes_pompiers
    ADD CONSTRAINT fk_caserne_noeud FOREIGN KEY (noeud_proche) REFERENCES reseaux.reseau_noeud_vertices_pgr(id);


--
-- Name: SCHEMA admin; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA admin TO sig_lecture;


--
-- Name: SCHEMA analyses; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA analyses TO sig_lecture;


--
-- Name: SCHEMA patrimoine; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA patrimoine TO sig_lecture;


--
-- Name: SCHEMA reseaux; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA reseaux TO sig_lecture;


--
-- PostgreSQL database dump complete
--

