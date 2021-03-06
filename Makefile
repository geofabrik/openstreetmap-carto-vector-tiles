all: buildall

buildall: reindexshapefiles postgresql-indexes osm-carto.tm2source/data.yml osm-carto.tm2/project.xml

osm-carto.tm2source/data.yml: project.mml Makefile
	python convert_ymls.py --input project.mml --tm2source --zoom 14 --output osm-carto.tm2source/data.yml
	ln -s ../data/ ./osm-carto.tm2source/ 2> /dev/null || true

osm-carto-shapefiles.tm2source/data.yml: project.mml Makefile
	mkdir osm-carto-shapefiles.tm2source || true
	python convert_ymls.py --input project.mml --only-shapefiles --tm2source --zoom 14 --output osm-carto-shapefiles.tm2source/data.yml
	ln -s ../data/ ./osm-carto-shapefiles.tm2source/ 2> /dev/null || true

osm-carto-postgis.tm2source/data.yml: project.mml Makefile
	mkdir osm-carto-postgis.tm2source || true
	python convert_ymls.py --input project.mml --only-postgis --tm2source --zoom 14 --output osm-carto-postgis.tm2source/data.yml
	ln -s ../data/ ./osm-carto-postgis.tm2source/ 2> /dev/null || true

osm-carto.tm2/project.xml: project.mml *.mss Makefile
	python convert_ymls.py --input project.mml --tm2 --output osm-carto.tm2/project.yml
	ln -s `pwd`/symbols/ ./osm-carto.tm2/ 2>/dev/null || true
	cd ./osm-carto.tm2/ && ln -s ../*mss ./ 2>/dev/null || true
	cp osm-carto.tm2/project.yml osm-carto.tm2/project.mml
	echo "Generating Mapnik XML. This can take 5 minutes"
	./node_modules/.bin/carto -a "3.0.0" ./osm-carto.tm2/project.mml > ./osm-carto.tm2/project.xml

%.index: %.shp
	./node_modules/.bin/mapnik-shapeindex.js --shape_files $*.shp || true

reindexshapefiles: data/simplified-land-polygons-complete-3857/simplified_land_polygons.index data/land-polygons-split-3857/land_polygons.index data/antarctica-icesheet-polygons-3857/icesheet_polygons.index data/antarctica-icesheet-outlines-3857/icesheet_outlines.index data/ne_110m_admin_0_boundary_lines_land/ne_110m_admin_0_boundary_lines_land.index ./data/world_boundaries/builtup_area.index ./data/world_boundaries/places.index ./data/world_boundaries/world_bnd_m.index ./data/world_boundaries/world_boundaries_m.index

postgresql-indexes: add-indexes.sql
	PGOPTIONS='--client-min-messages=error' psql -d gis -f add-indexes.sql >/dev/null || true

postgresql-fix-geometry:
	# TODO later versions of osm2pgsql use 3857 instead of 900913 SRS
	psql -d gis -c "DELETE FROM planet_osm_polygon WHERE ST_GeometryType(way) NOT IN ('ST_Polygon', 'ST_MultiPolgyon');"
	psql -d gis -c "ALTER TABLE planet_osm_polygon ALTER COLUMN way TYPE geometry(MultiPolygon, 3857) USING ST_Multi(way);"

install-node-modules:
	# Bit of a hack, Don't know how to make make rely on existance of a directory
	[ ! -d node_modules ] && npm install tilelive-tmsource tilelive-tmstyle tilejson tilelive-http tilelive-vector tessera carto@">=0.16" tilelive-file || true

tessera-serve-vector-tiles.json: tessera-serve-vector-tiles.json.tmpl
	PWD=$(pwd)
	sed "s|PWD|${PWD}|" tessera-serve-vector-tiles.json.tmpl > tessera-serve-vector-tiles.json

tessera: install-node-modules buildall tessera-serve-vector-tiles.json
	MAPNIK_FONT_PATH=$$(find /usr/share/fonts/ -type f | sed 's|/[^/]*$$||' | uniq | paste -s -d: -) ./node_modules/.bin/tessera -c tessera-serve-vector-tiles.json

mapbox-studio-classic: buildall
	#MAPNIK_FONT_PATH=$$(find /usr/share/fonts/ -type f | sed 's|/[^/]*$$||' | uniq | paste -s -d: -)
	python convert_ymls.py --input project.mml --tm2 --source --output osm-carto.tm2/project.yml

kosmtik: buildall
	python convert_ymls.py --input project.mml --tm2 --source --output osm-carto.tm2/project.yml
	@echo "Now run"
	@PWD=$(pwd)
	@echo "\n    ./index.js serve ${PWD}/osm-carto.tm2/project.yml\n"

clean:
	rmdir osm-carto.tm2/data/ || true
	rm -f osm-carto.tm2/*
	rm -f osm-carto.tm2source/*
	rm -f osm-carto-shapefiles.tm2source/*
	rm -f osm-carto-postgis.tm2source/*
