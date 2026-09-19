DROP TABLE IF EXISTS admin.communes CASCADE;
CREATE TABLE admin.communes (
    id SERIAL PRIMARY KEY,
    code_insee VARCHAR(5) NOT NULL,
    nom VARCHAR(100) NOT NULL,
    geom GEOMETRY(MultiPolygon, 2154) NOT NULL,
    CONSTRAINT uq_communes_insee UNIQUE (code_insee),
    CONSTRAINT chk_communes_geom_valid CHECK (ST_IsValid(geom))
);
INSERT INTO admin.communes (code_insee, nom, geom)
SELECT code_insee, nom_officiel, ST_Multi(ST_MakeValid(geom))
FROM admin.communes_raw
WHERE code_insee_du_departement = '45';
DROP TABLE IF EXISTS admin.communes_raw;

DROP TABLE IF EXISTS reseaux.troncons_routiers CASCADE;
CREATE TABLE reseaux.troncons_routiers (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(150),
    type_voie VARCHAR(50),
    commune_id INTEGER REFERENCES admin.communes(id),
    geom GEOMETRY(LineString, 2154) NOT NULL,
    CONSTRAINT chk_troncons_geom_valid CHECK (ST_IsValid(geom))
);
INSERT INTO reseaux.troncons_routiers (nom, type_voie, geom)
SELECT name, fclass, ST_MakeValid(geom)
FROM reseaux.troncons_raw WHERE geom IS NOT NULL;
DROP TABLE IF EXISTS reseaux.troncons_raw;

DROP TABLE IF EXISTS patrimoine.batiments CASCADE;
CREATE TABLE patrimoine.batiments (
    id SERIAL PRIMARY KEY,
    type_bati VARCHAR(50),
    commune_id INTEGER REFERENCES admin.communes(id),
    geom GEOMETRY(MultiPolygon, 2154) NOT NULL,
    CONSTRAINT chk_batiments_geom_valid CHECK (ST_IsValid(geom))
);
INSERT INTO patrimoine.batiments (type_bati, geom)
SELECT COALESCE(type, 'non renseigné'), ST_Multi(ST_MakeValid(geom))
FROM patrimoine.batiments_raw WHERE geom IS NOT NULL;
DROP TABLE IF EXISTS patrimoine.batiments_raw;

CREATE INDEX idx_communes_geom ON admin.communes USING GIST (geom);
CREATE INDEX idx_troncons_geom ON reseaux.troncons_routiers USING GIST (geom);
CREATE INDEX idx_batiments_geom ON patrimoine.batiments USING GIST (geom);
ANALYZE admin.communes;
ANALYZE reseaux.troncons_routiers;
ANALYZE patrimoine.batiments;

UPDATE reseaux.troncons_routiers t SET commune_id = c.id
FROM admin.communes c WHERE ST_Within(ST_Centroid(t.geom), c.geom);

UPDATE patrimoine.batiments b SET commune_id = c.id
FROM admin.communes c WHERE ST_Within(ST_Centroid(b.geom), c.geom);

CREATE INDEX idx_troncons_commune ON reseaux.troncons_routiers (commune_id);
CREATE INDEX idx_batiments_commune ON patrimoine.batiments (commune_id);

DROP MATERIALIZED VIEW IF EXISTS analyses.stats_par_commune;
CREATE MATERIALIZED VIEW analyses.stats_par_commune AS
SELECT c.code_insee, c.nom,
    COALESCE(r.km_routes, 0) AS km_routes,
    COALESCE(b.nb_batiments, 0) AS nb_batiments,
    ROUND(ST_Area(c.geom)::numeric / 1000000, 2) AS surface_km2
FROM admin.communes c
LEFT JOIN (SELECT commune_id, ROUND(SUM(ST_Length(geom))::numeric/1000,2) AS km_routes
    FROM reseaux.troncons_routiers GROUP BY commune_id) r ON r.commune_id = c.id
LEFT JOIN (SELECT commune_id, COUNT(*) AS nb_batiments
    FROM patrimoine.batiments GROUP BY commune_id) b ON b.commune_id = c.id;
CREATE UNIQUE INDEX idx_stats_insee ON analyses.stats_par_commune (code_insee);

CREATE SCHEMA IF NOT EXISTS secours;

DROP TABLE IF EXISTS secours.casernes_pompiers CASCADE;
CREATE TABLE secours.casernes_pompiers (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(150),
    commune_id INTEGER REFERENCES admin.communes(id),
    geom GEOMETRY(Point, 2154) NOT NULL,
    CONSTRAINT chk_casernes_geom_valid CHECK (ST_IsValid(geom))
);
INSERT INTO secours.casernes_pompiers (nom, geom)
SELECT COALESCE(name, 'Caserne sans nom'), ST_MakeValid(geom)
FROM secours.casernes_raw WHERE geom IS NOT NULL;
DROP TABLE IF EXISTS secours.casernes_raw;

CREATE INDEX idx_casernes_geom ON secours.casernes_pompiers USING GIST (geom);

UPDATE secours.casernes_pompiers p SET commune_id = c.id
FROM admin.communes c WHERE ST_Within(p.geom, c.geom);

CREATE INDEX idx_casernes_commune ON secours.casernes_pompiers (commune_id);

DROP MATERIALIZED VIEW IF EXISTS analyses.distance_caserne_par_commune;
CREATE MATERIALIZED VIEW analyses.distance_caserne_par_commune AS
SELECT c.code_insee, c.nom,
    ROUND((
        SELECT ST_Distance(ST_Centroid(c.geom), p.geom)
        FROM secours.casernes_pompiers p
        ORDER BY ST_Centroid(c.geom) <-> p.geom
        LIMIT 1
    )::numeric / 1000, 2) AS distance_km_caserne_proche
FROM admin.communes c;
CREATE UNIQUE INDEX idx_distance_caserne_insee ON analyses.distance_caserne_par_commune (code_insee);

CREATE EXTENSION IF NOT EXISTS pgrouting;

DROP TABLE IF EXISTS reseaux.reseau_routable CASCADE;
CREATE TABLE reseaux.reseau_routable AS
SELECT
    id, nom, type_voie,
    CASE type_voie
        WHEN 'motorway' THEN 110 WHEN 'motorway_link' THEN 70
        WHEN 'trunk' THEN 90 WHEN 'trunk_link' THEN 50
        WHEN 'primary' THEN 70 WHEN 'primary_link' THEN 50
        WHEN 'secondary' THEN 60 WHEN 'secondary_link' THEN 40
        WHEN 'tertiary' THEN 50 WHEN 'tertiary_link' THEN 40
        WHEN 'unclassified' THEN 40 WHEN 'residential' THEN 30
        WHEN 'living_street' THEN 15 WHEN 'service' THEN 20
        ELSE NULL
    END AS vitesse_kmh,
    geom
FROM reseaux.troncons_routiers
WHERE type_voie IN (
    'motorway','motorway_link','trunk','trunk_link','primary','primary_link',
    'secondary','secondary_link','tertiary','tertiary_link','unclassified',
    'residential','living_street','service'
);

DROP TABLE IF EXISTS reseaux.reseau_noeud CASCADE;
CREATE TABLE reseaux.reseau_noeud AS
SELECT (ST_Dump(ST_Union(geom))).geom AS geom FROM reseaux.reseau_routable;

ALTER TABLE reseaux.reseau_noeud ADD COLUMN id SERIAL PRIMARY KEY;
ALTER TABLE reseaux.reseau_noeud ADD COLUMN source INTEGER;
ALTER TABLE reseaux.reseau_noeud ADD COLUMN target INTEGER;
ALTER TABLE reseaux.reseau_noeud ADD COLUMN type_voie VARCHAR(50);
ALTER TABLE reseaux.reseau_noeud ADD COLUMN vitesse_kmh INTEGER;
ALTER TABLE reseaux.reseau_noeud ADD COLUMN cout_min DOUBLE PRECISION;

CREATE INDEX idx_reseau_noeud_geom ON reseaux.reseau_noeud USING GIST (geom);

CREATE TABLE reseaux._tmp_attrs AS
SELECT n.id AS noeud_id, a.type_voie, a.vitesse_kmh
FROM reseaux.reseau_noeud n
CROSS JOIN LATERAL (
    SELECT type_voie, vitesse_kmh FROM reseaux.reseau_routable r
    ORDER BY ST_PointOnSurface(n.geom) <-> r.geom LIMIT 1
) a;

UPDATE reseaux.reseau_noeud n SET type_voie = t.type_voie, vitesse_kmh = t.vitesse_kmh
FROM reseaux._tmp_attrs t WHERE t.noeud_id = n.id;
DROP TABLE reseaux._tmp_attrs;

UPDATE reseaux.reseau_noeud SET cout_min = ST_Length(geom) / 1000.0 / NULLIF(vitesse_kmh, 0) * 60;

SELECT pgr_createTopology('reseaux.reseau_noeud', 0.5, 'geom', 'id');

ALTER TABLE secours.casernes_pompiers ADD COLUMN IF NOT EXISTS noeud_proche BIGINT;

CREATE TABLE secours._tmp_noeuds AS
SELECT c.id AS caserne_id, v.id AS noeud_id
FROM secours.casernes_pompiers c
CROSS JOIN LATERAL (
    SELECT id FROM reseaux.reseau_noeud_vertices_pgr v
    ORDER BY c.geom <-> v.the_geom LIMIT 1
) v;

UPDATE secours.casernes_pompiers c SET noeud_proche = t.noeud_id
FROM secours._tmp_noeuds t WHERE t.caserne_id = c.id;
DROP TABLE secours._tmp_noeuds;

DROP TABLE IF EXISTS analyses.isochrones_casernes;
CREATE TABLE analyses.isochrones_casernes AS
SELECT c.id AS caserne_id, c.nom AS caserne_nom, dd.node, dd.agg_cost AS temps_min,
    CASE WHEN dd.agg_cost <= 15 THEN '0-15 min' WHEN dd.agg_cost <= 30 THEN '15-30 min'
         WHEN dd.agg_cost <= 45 THEN '30-45 min' ELSE '45-60 min' END AS tranche
FROM secours.casernes_pompiers c
CROSS JOIN LATERAL (
    SELECT * FROM pgr_drivingDistance(
        'SELECT id, source, target, cout_min AS cost, cout_min AS reverse_cost FROM reseaux.reseau_noeud',
        c.noeud_proche, 60, directed := false
    )
) dd;

DROP MATERIALIZED VIEW IF EXISTS analyses.zones_isochrones;
CREATE MATERIALIZED VIEW analyses.zones_isochrones AS
SELECT ic.caserne_id, ic.caserne_nom, ic.tranche,
    ST_ConvexHull(ST_Collect(v.the_geom)) AS geom
FROM analyses.isochrones_casernes ic
JOIN reseaux.reseau_noeud_vertices_pgr v ON v.id = ic.node
GROUP BY ic.caserne_id, ic.caserne_nom, ic.tranche;

DROP MATERIALIZED VIEW IF EXISTS analyses.temps_caserne_par_commune;
CREATE MATERIALIZED VIEW analyses.temps_caserne_par_commune AS
SELECT c.code_insee, c.nom, MIN(ic.temps_min) AS temps_min_caserne
FROM admin.communes c
JOIN LATERAL (
    SELECT id FROM reseaux.reseau_noeud_vertices_pgr
    ORDER BY ST_Centroid(c.geom) <-> the_geom LIMIT 1
) v ON true
JOIN analyses.isochrones_casernes ic ON ic.node = v.id
GROUP BY c.code_insee, c.nom;

CREATE UNIQUE INDEX idx_temps_caserne_insee ON analyses.temps_caserne_par_commune (code_insee);