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