$DB = "geo_portfolio"
$USER = "postgres"
$PGPASSWORD_VAL = "postgres"
$DATA = "C:\geo_portfolio\data"
$PSQL = "C:\Program Files\QGIS 3.40.2\bin\psql.exe"

$env:PGPASSWORD = $PGPASSWORD_VAL

Write-Host "Import des communes..."
ogr2ogr -f "PostgreSQL" "PG:host=localhost dbname=$DB user=$USER password=$PGPASSWORD_VAL" "$DATA\communes\admin_express.gpkg" commune -nln admin.communes_raw -lco GEOMETRY_NAME=geom -t_srs EPSG:2154 -overwrite

Write-Host "Import des routes..."
ogr2ogr -f "PostgreSQL" "PG:host=localhost dbname=$DB user=$USER password=$PGPASSWORD_VAL" "$DATA\osm\centre.gpkg" gis_osm_roads_free -nln reseaux.troncons_raw -lco GEOMETRY_NAME=geom -t_srs EPSG:2154 -overwrite

Write-Host "Import des batiments..."
ogr2ogr -f "PostgreSQL" "PG:host=localhost dbname=$DB user=$USER password=$PGPASSWORD_VAL" "$DATA\osm\centre.gpkg" gis_osm_buildings_a_free -nln patrimoine.batiments_raw -lco GEOMETRY_NAME=geom -t_srs EPSG:2154 -overwrite

Write-Host "Nettoyage, contraintes, jointures et vue d'analyse..."
& $PSQL -U $USER -d $DB -f "C:\geo_portfolio\sql\02_nettoyage_et_jointures.sql"

Write-Host "Pipeline termine."