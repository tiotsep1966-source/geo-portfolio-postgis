# Géo-Portfolio — Base de données spatiale PostgreSQL/PostGIS

Base de données géospatiale multi-couches (limites administratives, réseau routier, bâti,
casernes de pompiers) construite sur le département du Loiret (45), à partir de sources
officielles et communautaires croisées : IGN ADMIN EXPRESS COG et OpenStreetMap (extrait Geofabrik).

## Schéma entité-relation

![ERD](erd.png)

## Modèle de données

- `admin.communes` — limites communales du Loiret (325 communes), source IGN ADMIN EXPRESS COG
- `reseaux.troncons_routiers` — réseau routier, source OpenStreetMap (Geofabrik)
- `patrimoine.batiments` — bâti, source OpenStreetMap (Geofabrik)
- `secours.casernes_pompiers` — casernes de pompiers, source OpenStreetMap (Geofabrik)
- `analyses.stats_par_commune` — vue matérialisée agrégeant km de routes, nombre de
  bâtiments et surface par commune
- `analyses.distance_caserne_par_commune` — vue matérialisée calculant la distance de
  chaque commune à la caserne de pompiers la plus proche

Chaque tronçon routier, bâtiment et caserne est rattaché à sa commune via une clé
étrangère `commune_id`, peuplée par jointure spatiale (`ST_Within` sur le centroïde
ou le point) après import — cette relation n'existe pas nativement dans les données sources.

## Cas d'usage : couverture territoriale des secours

En croisant les données de communes avec les positions des casernes de pompiers
(OpenStreetMap), la base identifie les communes du Loiret les plus éloignées d'une
caserne — un indicateur pertinent pour l'analyse de la couverture opérationnelle
des secours, à l'image des missions confiées aux géomaticiens de SDIS.

```sql
SELECT nom, distance_km_caserne_proche
FROM analyses.distance_caserne_par_commune
ORDER BY distance_km_caserne_proche DESC
LIMIT 15;
```

Cette analyse repose sur une nouvelle table `secours.casernes_pompiers`, rattachée
aux communes selon la même logique de jointure spatiale que les routes et le bâti.

## Points techniques

- Système de coordonnées : Lambert-93 (EPSG:2154)
- Contraintes de validité géométrique (`ST_IsValid`) sur toutes les tables
- Index spatiaux GIST sur toutes les colonnes géométriques
- Rôles séparés lecture (`sig_lecture`) / édition (`sig_edition`)
- Pipeline d'import entièrement automatisé et reproductible (voir `scripts/`)

## Reproduire ce projet

1. Créer une base PostgreSQL avec l'extension PostGIS activée
2. Télécharger les données sources :
   - [IGN ADMIN EXPRESS COG](https://cartes.gouv.fr) (format GeoPackage ou Shapefile)
   - [Geofabrik – Centre-Val de Loire](https://download.geofabrik.de/europe/france/centre-val-de-loire.html)
3. Adapter les chemins dans `scripts/import_pipeline.ps1`
4. Exécuter : `powershell -ExecutionPolicy Bypass -File scripts/import_pipeline.ps1`

## Exemple de requête d'analyse

```sql
SELECT nom, km_routes, nb_batiments, surface_km2
FROM analyses.stats_par_commune
ORDER BY nb_batiments DESC
LIMIT 10;
```

## Auteur

**Alain Georges Tiossep Tsepeng**
[LinkedIn](https://www.linkedin.com/in/alain-georges-tiossep-tsepeng-1129b416b/)