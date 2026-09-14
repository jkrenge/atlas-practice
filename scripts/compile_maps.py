"""Compile local source snapshots. Run with .venv/bin/python scripts/compile_maps.py."""

import hashlib
import json
from pathlib import Path

import shapefile
from shapely import make_valid
from shapely.geometry import shape, mapping, MultiPolygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'data/sources'


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n')


def feature(identifier, name, geometry, **properties):
    return {'type': 'Feature', 'id': identifier,
            'properties': {'name': name, **properties}, 'geometry': geometry}


def pack(identifier, name, area_type, features, source, geometry_asset='areas.geojson'):
    folder = ROOT / 'maps' / identifier
    manifest = {
        'schemaVersion': 2, 'id': identifier, 'name': name, 'areaType': area_type,
        'coordinateSystem': 'OGC:CRS84', 'geometryAsset': geometry_asset,
        'sourceId': source,
        'areas': [{'id': f['id'], 'name': f['properties']['name']}
                  for f in features if f['properties'].get('quizEligible', True)],
    }
    if identifier == 'us-states':
        manifest['referenceSvgAsset'] = 'map.svg'
        manifest['referenceSvgGeoreferenced'] = False
    write(folder / 'map.json', manifest)
    if geometry_asset == 'areas.geojson':
        write(folder / geometry_asset, {'type': 'FeatureCollection', 'features': features})
    return {'id': identifier, 'name': name, 'manifest': f'{identifier}/map.json',
            'areaCount': len(manifest['areas'])}


def records(filename):
    with shapefile.Reader(str(SOURCES / filename)) as reader:
        yield from reader.iterShapeRecords()


def verify_sources():
    expected = json.loads((ROOT / 'data/source-checksums.json').read_text())
    for filename, checksum in expected.items():
        actual = hashlib.sha256((SOURCES / filename).read_bytes()).hexdigest()
        if actual != checksum:
            raise ValueError(f'Source checksum mismatch: {filename}')


def focused_neighborhoods(local, boroughs):
    # Keep Manhattan intact. Outside Manhattan, use the explicit practice groups.
    result = [f for f in local if f['properties']['borough'] == 'Manhattan']
    sources = {'nyc-pediacities': {f['id']: f for f in local},
               'nyc-boroughs': {f['id']: f for f in boroughs}}
    for group in json.loads((ROOT / 'data/nyc-learning-groups.json').read_text()):
        members = [sources[group['sourceId']][i] for i in group['sourceAreaIDs']]
        geometry = (members[0]['geometry'] if len(members) == 1 else
                    mapping(unary_union([shape(f['geometry']) for f in members])))
        result.append(feature(group['id'], group['name'], geometry,
                              borough=group['borough'], sourceId=group['sourceId'],
                              sourceAreaIDs=group['sourceAreaIDs'], quizEligible=True))
    return result


def main():
    verify_sources()
    catalog = []
    admin = {'USA': [], 'DEU': []}
    for row in records('ne_10m_admin_1_states_provinces.zip'):
        p = row.record.as_dict()
        if p['adm0_a3'] in admin:
            admin[p['adm0_a3']].append(feature(
                p['iso_3166_2'], p['name'], row.shape.__geo_interface__,
                nameEnglish=p['name_en'], quizEligible=p['iso_3166_2'] != 'US-DC'))
    for country, identifier, name in [('USA', 'us-states', 'United States'),
                                      ('DEU', 'germany-states', 'Germany')]:
        catalog.append(pack(identifier, name, 'state', admin[country], 'natural-earth-admin1'))

    boroughs = []
    for row in json.loads((SOURCES / 'nyc-boroughs.geojson').read_text())['features']:
        p = row['properties']
        boroughs.append(feature('NYC-BORO-' + p['borocode'], p['boroname'], row['geometry'],
                                boroughCode=p['borocode'], quizEligible=True))
    catalog.append(pack('nyc-boroughs', 'New York City boroughs', 'borough',
                        boroughs, 'nyc-boroughs'))

    nta = json.loads((SOURCES / 'nyc-nta.geojson').read_text())
    neighborhoods = []
    for row in nta['features']:
        p = row['properties']
        neighborhoods.append(feature('NYC-' + p['nta2020'], p['ntaname'], row['geometry'],
                                     borough=p['boroname'], ntaType=p['ntatype'],
                                     quizEligible=p['ntatype'] == '0'))
    catalog.append(pack('nyc-neighborhoods', 'New York City', 'neighborhood',
                        neighborhoods, 'nyc-nta2020'))

    countries = []
    for row in records('ne_50m_admin_0_countries.zip'):
        p = row.record.as_dict()
        countries.append(feature('NE-' + str(p['NE_ID']), p['NAME_EN'] or p['NAME'],
                                 row.shape.__geo_interface__, continent=p['CONTINENT'],
                                 sourceType=p['TYPE'], adminCode=p['ADM0_A3'],
                                 quizEligible=p['TYPE'] in ('Sovereign country', 'Country')))
    catalog.append(pack('world-countries', 'World', 'country', countries, 'natural-earth-countries'))
    for continent in ['Africa', 'Asia', 'Europe', 'North America', 'South America', 'Oceania']:
        selected = [f for f in countries if f['properties']['continent'] == continent]
        identifier = continent.lower().replace(' ', '-') + '-countries'
        catalog.append(pack(identifier, continent, 'country', selected,
                            'natural-earth-countries', '../world-countries/areas.geojson'))


    cities = []
    for row in records('ne_10m_populated_places.zip'):
        p = row.record.as_dict()
        if p['ADM0_A3'] == 'USA':
            cities.append(feature('NE-' + str(p['NE_ID']), p['NAME'], row.shape.__geo_interface__,
                                  stateName=p['ADM1NAME'], sourceId='natural-earth-places',
                                  sourcePopulationMax=p['POP_MAX'],
                                  sourceScaleRank=p['SCALERANK']))
    write(ROOT / 'data/us-cities.geojson', {'type': 'FeatureCollection', 'features': cities})

    # Preserve the original candidate geometry, then build a repaired learning pack.
    groups = {}
    for row in json.loads((SOURCES / 'nyc-pediacities-neighborhoods.geojson').read_text())['features']:
        if row['geometry'] is None:
            continue
        if row['geometry']['type'] != 'Polygon':
            raise ValueError('Expected Polygon in the pinned Pediacities source')
        p = row['properties']
        entry = groups.setdefault(p['@id'], {'properties': p, 'parts': []})
        if entry['properties'] != p:
            raise ValueError(f"Conflicting candidate properties: {p['@id']}")
        entry['parts'].append(row['geometry']['coordinates'])
    candidates = []
    for identifier, entry in groups.items():
        parts = entry['parts']
        geometry = {'type': 'Polygon' if len(parts) == 1 else 'MultiPolygon',
                    'coordinates': parts[0] if len(parts) == 1 else parts}
        candidates.append({'type': 'Feature', 'id': identifier,
                           'properties': entry['properties'], 'geometry': geometry})
    write(ROOT / 'data/candidates/nyc-neighborhoods.geojson',
          {'type': 'FeatureCollection', 'features': candidates})
    local = []
    repairs = []
    for candidate in candidates:
        geometry = shape(candidate['geometry'])
        if not geometry.is_valid:
            fixed = make_valid(geometry)
            if fixed.geom_type == 'GeometryCollection':
                fixed = MultiPolygon([part for part in fixed.geoms if part.geom_type == 'Polygon'])
            if not fixed.is_valid or fixed.geom_type not in ('Polygon', 'MultiPolygon'):
                raise ValueError(f"Invalid repaired neighborhood: {candidate['id']}")
            repairs.append({'id': candidate['id'], 'method': 'shapely.make_valid',
                            'originalAreaDegreesSquared': geometry.area, 'repairedAreaDegreesSquared': fixed.area})
            geometry = fixed
        p = candidate['properties']
        local.append(feature(candidate['id'], p['neighborhood'], mapping(geometry),
                             borough=p['borough'], quizEligible=True))
    focused = focused_neighborhoods(local, boroughs)
    catalog.append(pack('nyc-neighborhoods-focused', 'NYC neighborhoods', 'area', focused, 'nyc-learning-areas'))
    write(ROOT / 'maps/catalog.json', {'schemaVersion': 2, 'maps': catalog})
    write(ROOT / 'data/nyc-neighborhood-repairs.json', repairs)
    print(json.dumps(catalog, indent=2))
    print(f'US city and town points: {len(cities)}')
    print(f'NYC practice areas: {len(focused)}; source neighborhoods: {len(local)}; repaired geometries: {len(repairs)}')


if __name__ == '__main__':
    main()
