"""Validate the pinned map data. Run with .venv/bin/python scripts/validate_data.py."""

import json
import math
import xml.etree.ElementTree as ET

from shapely import make_valid, coverage_is_valid, get_num_coordinates
from shapely.geometry import shape, MultiPolygon, Point, Polygon
from shapely.ops import unary_union
from shapely.validation import explain_validity

from compile_maps import ROOT, verify_sources, records
from simplify_maps import LIMITS, MAX_AREA_CHANGE

US_STATES = set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN '
                'MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA '
                'WA WV WI WY'.split())
GERMAN_STATES = set('BB BE BW BY HB HE HH MV NI NW RP SH SL SN ST TH'.split())
EXPECTED_COUNTS = {
    'nyc-neighborhoods-focused': 53, 'us-states': 50, 'germany-states': 16, 'nyc-boroughs': 5, 'nyc-neighborhoods': 197,
    'world-countries': 204, 'africa-countries': 53, 'asia-countries': 48,
    'europe-countries': 48, 'north-america-countries': 26,
    'south-america-countries': 12, 'oceania-countries': 14,
}
GEOMETRY_COUNTS = {'nyc-neighborhoods-focused': 53, 'us-states': 51, 'germany-states': 16, 'nyc-boroughs': 5,
                   'nyc-neighborhoods': 262, 'world-countries': 242}
SOURCE_IDS = {'natural-earth-admin1-land', 'nyc-learning-areas', 'natural-earth-countries-land', 'nyc-boroughs', 'nyc-nta2020'}


def check(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return json.loads(path.read_text())


def asset(folder, relative):
    path = (folder / relative).resolve()
    check(path.is_relative_to(ROOT) and path.is_file(), f'Missing or external asset: {path}')
    return path


def unique(items, label):
    identifiers = [item['id'] for item in items]
    check(all(isinstance(i, str) and i for i in identifiers), f'Invalid ID: {label}')
    check(len(identifiers) == len(set(identifiers)), f'Duplicate ID: {label}')
    return set(identifiers)


def positions(geometry):
    if geometry['type'] == 'Point':
        yield geometry['coordinates']
        return
    check(geometry['type'] in ('Polygon', 'MultiPolygon'), 'Unsupported area geometry')
    polygons = ([geometry['coordinates']] if geometry['type'] == 'Polygon'
                else geometry['coordinates'])
    check(bool(polygons), 'Empty polygon array')
    for polygon in polygons:
        check(bool(polygon), 'Missing exterior ring')
        for ring in polygon:
            check(len(ring) >= 4 and ring[0] == ring[-1], 'Short or unclosed ring')
            yield from ring


def collection(path, *, points=False, name_key='name', known_invalid=frozenset()):
    data = read(path)
    check(data['type'] == 'FeatureCollection' and data['features'], f'Empty collection: {path}')
    features = data['features']
    unique(features, path)
    bounds = [180, 90, -180, -90]
    invalid = set()
    for f in features:
        check(f['type'] == 'Feature', f'Invalid feature: {path}')
        check(bool(f['properties'][name_key].strip()), f"Empty name: {f['id']}")
        g = f['geometry']
        check((g['type'] == 'Point') == points, f"Wrong geometry type: {f['id']}")
        for p in positions(g):
            check(len(p) == 2 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in p),
                  f"Invalid position: {f['id']}")
            lon, lat = p
            check(-180 <= lon <= 180 and -90 <= lat <= 90, f"Out-of-range position: {f['id']}")
            bounds = [min(bounds[0], lon), min(bounds[1], lat),
                      max(bounds[2], lon), max(bounds[3], lat)]
        geometry = shape(g)
        check(not geometry.is_empty, f"Empty geometry: {f['id']}")
        if not geometry.is_valid:
            invalid.add(f['id'])
            check(f['id'] in known_invalid, f"Invalid geometry {f['id']}: {explain_validity(geometry)}")
    check(invalid == set(known_invalid), f'Known candidate issues changed: {path}')
    print(f'{path.relative_to(ROOT)}: {len(features)} features; bounds {bounds}')
    return features, bounds


def check_focused_neighborhoods(candidates):
    focused = read(ROOT / 'maps/nyc-neighborhoods-focused/areas.geojson')['features']
    by_id = {f['id']: f for f in focused}
    manhattan = [f for f in candidates if f['properties']['borough'] == 'Manhattan']
    check(len(manhattan) == 37, 'Manhattan source count changed')
    carves = read(ROOT / 'data/nyc-carve-outs.json')
    carved = {c['id'] for c in carves}
    check({f['id'] for f in focused if f['properties']['borough'] == 'Manhattan'} ==
          {f['id'] for f in manhattan} | carved, 'Manhattan neighborhood set changed')
    boroughs = read(ROOT / 'maps/nyc-boroughs/areas.geojson')['features']
    shores = {f['properties']['name']: f for f in boroughs}
    for f in focused:
        shore = shores[f['properties']['borough']]
        check(f['properties']['shorelineSourceId'] == 'nyc-boroughs' and
              f['properties']['shorelineAreaID'] == shore['id'], 'Missing official shoreline provenance')
        check(shape(f['geometry']).difference(shape(shore['geometry'])).area < 1e-12,
              f"Practice area extends outside official borough land: {f['id']}")
    # Hand-drawn areas: each cuts its outline out of one source area, and the two still cover it.
    outlines = {}
    for c in carves:
        f = by_id[c['id']]
        check(all(f['properties'][key] == c[key] for key in
                  ('name', 'borough', 'sourceId', 'sourceAreaIDs', 'outlineSource')) and
              c['outlineSource'] == 'hand-drawn' and len(c['sourceAreaIDs']) == 1, 'Carve-out metadata mismatch')
        source = next(m for m in manhattan if m['id'] == c['sourceAreaIDs'][0])
        land = shape(source['geometry']).intersection(shape(shores[c['borough']]['geometry']))
        outline = Polygon(c['outline'])
        outlines[source['id']] = outline
        check(shape(f['geometry']).symmetric_difference(land.intersection(outline)).area < 1e-12 and
              0.05 < shape(f['geometry']).area / land.area < 0.5, f"Carve-out geometry changed: {c['name']}")
        check(shape(f['geometry']).union(shape(by_id[source['id']]['geometry'])).symmetric_difference(land).area < 1e-12,
              f"Carve-out and its source no longer cover the source area: {c['name']}")
    for f in manhattan:
        expected_geometry = shape(f['geometry']).intersection(shape(shores['Manhattan']['geometry']))
        if f['id'] in outlines:
            expected_geometry = expected_geometry.difference(outlines[f['id']])
        check(shape(by_id[f['id']]['geometry']).symmetric_difference(expected_geometry).area < 1e-12 and
              by_id[f['id']]['properties']['name'] == f['properties']['neighborhood'],
              f"Manhattan inland boundary or name changed: {f['id']}")

    groups = read(ROOT / 'data/nyc-learning-groups.json')
    check(unique(groups, 'NYC practice groups') == set(by_id) - {f['id'] for f in manhattan} - carved,
          'Practice group IDs do not match the focused map')
    check({g['name'] for g in groups} == {'Bed-Stuy', 'DUMBO', 'Williamsburg', 'Greenpoint',
          'Park Slope', 'Prospect Heights', 'Downtown Brooklyn', 'Crown Heights', 'Prospect Park', 'West Brooklyn', 'South & East Brooklyn', 'Long Island City',
          'Queens (other areas)', 'The Bronx', 'Staten Island'}, 'Unexpected practice areas')
    for name, source_name in [('Bed-Stuy', 'Bedford_Stuyvesant'), ('DUMBO', 'DUMBO'),
                              ('Williamsburg', 'Williamsburg'), ('Greenpoint', 'Greenpoint'),
                              ('Park Slope', 'Park_Slope'), ('Prospect Heights', 'Prospect_Heights'),
                              ('Downtown Brooklyn', 'Downtown_Brooklyn'), ('Crown Heights', 'Crown_Heights'),
                              ('Prospect Park', 'Prospect_Park'),
                              ('Long Island City', 'Long_Island_City')]:
        group = next(g for g in groups if g['name'] == name)
        identifier = 'http://nyc.pediacities.com/Resource/Neighborhood/' + source_name
        check(group['id'] == identifier and group['sourceAreaIDs'] == [identifier],
              f'Requested neighborhood must stay separate: {name}')
    sources = {'nyc-pediacities': {f['id']: f for f in candidates},
               'nyc-boroughs': {f['id']: f for f in read(ROOT / 'maps/nyc-boroughs/areas.geojson')['features']}}
    used = []
    for group in groups:
        f = by_id[group['id']]
        ids = group['sourceAreaIDs']
        check(bool(ids) and len(ids) == len(set(ids)), 'Empty or duplicate group members')
        check(all(f['properties'][key] == group[key] for key in
                  ('name', 'borough', 'sourceId', 'sourceAreaIDs')), 'Group metadata mismatch')
        members = [sources[group['sourceId']][i] for i in ids]
        if group['sourceId'] == 'nyc-pediacities':
            used.extend(ids)
            check(all(m['properties']['borough'] == group['borough'] for m in members),
                  'Practice group crosses boroughs')
        else:
            check((group['name'], ids) in [('The Bronx', ['NYC-BORO-2']),
                  ('Staten Island', ['NYC-BORO-5'])], 'Wrong official borough boundary')
        if len(members) == 1:
            expected_geometry = shape(members[0]['geometry']).intersection(shape(shores[group['borough']]['geometry']))
            check(shape(f['geometry']).symmetric_difference(expected_geometry).area < 1e-12,
                  'Single area inland boundary changed')
        else:
            shapes = [make_valid(shape(m['geometry'])) for m in members]
            shapes = [MultiPolygon([p for p in g.geoms if p.geom_type == 'Polygon'])
                      if g.geom_type == 'GeometryCollection' else g for g in shapes]
            check(shape(f['geometry']).symmetric_difference(unary_union(shapes).intersection(
                shape(shores[group['borough']]['geometry']))).area < 1e-12,
                  f"Group does not preserve member coverage: {group['name']}")
    expected = {f['id'] for f in candidates if f['properties']['borough'] in ('Brooklyn', 'Queens')}
    check(len(used) == len(set(used)) and set(used) == expected,
          'Brooklyn/Queens source areas must each belong to one group')
    print('NYC: 38 Manhattan areas (Seaport hand-drawn from the Financial District) and 15 other areas; original membership and inland boundaries; official shorelines.')


def check_land_sources():
    # Compare every generated state/country feature with the pinned source.
    # Source identities, membership and land coverage must survive lake clipping.
    us_base = {r.record.as_dict()['iso_3166_2']: shape(r.shape.__geo_interface__)
               for r in records('ne_10m_admin_1_states_provinces_lakes.zip')
               if r.record.as_dict()['adm0_a3'] == 'USA'}
    states = {r.record.as_dict()['iso_3166_2']: shape(r.shape.__geo_interface__)
              for r in records('ne_10m_admin_1_states_provinces.zip')
              if r.record.as_dict()['adm0_a3'] == 'DEU'}
    countries = {'NE-' + str(r.record.as_dict()['NE_ID']): shape(r.shape.__geo_interface__)
                 for r in records('ne_50m_admin_0_countries.zip')}
    for map_id, source, lake_file in [('us-states', us_base, 'ne_10m_lakes.zip'),
                                      ('germany-states', states, 'ne_10m_lakes.zip'),
                                      ('world-countries', countries, 'ne_50m_lakes.zip')]:
        water = unary_union([shape(r.shape.__geo_interface__) for r in records(lake_file)])
        features = read(ROOT / 'maps' / map_id / 'areas.geojson')['features']
        check({f['id'] for f in features} == set(source), 'Source feature IDs changed')
        for f in features:
            geometry = shape(f['geometry'])
            expected = source[f['id']].difference(water)
            check(geometry.symmetric_difference(expected).area < 1e-10,
                  f"Land differs from source minus mapped lakes: {f['id']}")
            check(geometry.intersection(water).area < 1e-10, f"Lake remains filled as land: {f['id']}")

    water_probes = {
        'us-states': [(-87, 43.5), (-112.5, 41.1), (-81, 26.9)],
        'germany-states': [(9.4, 47.62), (12.7, 53.43), (11.46, 53.7)],
        'world-countries': [(-87, 43.5), (108, 53), (33, -1), (-112.5, 41.1)],
        'nyc-boroughs': [(-73.965, 40.743), (-74.015, 40.72)],
        'nyc-neighborhoods-focused': [(-73.965, 40.743), (-74.015, 40.72),
            (-73.99278510511897, 40.70465085326032), (-73.95473150505875, 40.73979288426392)],
    }
    for map_id, points in water_probes.items():
        for filename in ('areas.geojson', 'areas-lowres.geojson'):
            geometries = [shape(f['geometry']) for f in read(ROOT / 'maps' / map_id / filename)['features']]
            for point in points:
                check(not any(g.covers(Point(point)) for g in geometries), f'Water probe selected land: {map_id} {filename} {point}')
    print('PASS: all 309 state/country features match source land; lake and NYC river probes remain water.')


def main():
    verify_sources()
    check_land_sources()
    for identifier in LIMITS:
        folder = ROOT / 'maps' / identifier
        original = read(folder / 'areas.geojson')['features']
        reduced = read(folder / 'areas-lowres.geojson')['features']
        check([f['id'] for f in original] == [f['id'] for f in reduced], 'Simplification changed feature IDs or order')
        geometries = []
        for before, after in zip(original, reduced):
            check(before['properties'] == after['properties'], 'Simplification changed metadata')
            source, geometry = shape(before['geometry']), shape(after['geometry'])
            check(geometry.is_valid and not geometry.is_empty, f"Invalid simplified geometry: {after['id']}")
            check(source.symmetric_difference(geometry).area / source.area <= MAX_AREA_CHANGE,
                  f"Simplification exceeded its area limit: {after['id']}")
            geometries.append(geometry)
        check(coverage_is_valid(geometries), f'Simplified borders do not match: {identifier}')
        check(get_num_coordinates(geometries).sum() < get_num_coordinates([shape(f['geometry']) for f in original]).sum(),
              f'Simplification did not reduce geometry: {identifier}')
    catalog = read(ROOT / 'maps/catalog.json')
    check(catalog['schemaVersion'] == 2, 'Unsupported catalog version')
    check(unique(catalog['maps'], 'catalog') == set(EXPECTED_COUNTS), 'Unexpected map inventory')
    geometries = {}
    for entry in catalog['maps']:
        manifest_path = asset(ROOT / 'maps', entry['manifest'])
        m = read(manifest_path)
        check(m['id'] == entry['id'] and m['name'] == entry['name'], 'Catalog/manifest mismatch')
        check(m['schemaVersion'] == 2 and m['coordinateSystem'] == 'OGC:CRS84', 'Invalid map contract')
        check(m['sourceId'] in SOURCE_IDS, f"Undocumented source: {m['sourceId']}")
        check(m['areaType'] in ('state', 'borough', 'neighborhood', 'country', 'area'), 'Invalid area type')
        path = asset(manifest_path.parent, m['geometryAsset'])
        if path not in geometries:
            features, bounds = collection(path)
            check(len(features) == GEOMETRY_COUNTS[path.parent.name], 'Unexpected geometry count')
            if path.parent.name.startswith('nyc-'):
                check(-74.3 <= bounds[0] < bounds[2] <= -73.6 and
                      40.4 <= bounds[1] < bounds[3] <= 41, 'NYC coordinates outside expected region')
            if path.parent.name == 'germany-states':
                check(5 <= bounds[0] < bounds[2] <= 16 and
                      47 <= bounds[1] < bounds[3] <= 56, 'Germany coordinates outside expected region')
            geometries[path] = {f['id']: f for f in features}
        by_id = geometries[path]
        ids = unique(m['areas'], m['id'])
        check(len(ids) == entry['areaCount'] == EXPECTED_COUNTS[m['id']], 'Question count mismatch')
        eligible = {i for i, f in by_id.items() if f['properties']['quizEligible']}
        if m['id'].endswith('-countries') and m['id'] != 'world-countries':
            eligible = {i for i in eligible if by_id[i]['properties']['continent'] == m['name']}
        check(ids == eligible, f"Question filter mismatch: {m['id']}")
        for area in m['areas']:
            check(area['name'] == by_id[area['id']]['properties']['name'], 'Question name mismatch')
        if m['id'] == 'us-states':
            land = {i: shape(f['geometry']) for i, f in by_id.items()}
            for lake in [(-87, 47.5), (-87, 43.5), (-82.7, 44.5), (-81.2, 42.1), (-77.8, 43.5), (-87.55, 41.9)]:
                check(not any(g.covers(Point(lake)) for g in land.values()), 'Great Lakes must remain water')
            for state, point in [('US-IL', (-87.65, 41.9)), ('US-MI', (-83.1, 42.4)), ('US-MI', (-87.4, 46.5))]:
                check(land[state].contains(Point(point)), 'Lake shoreline removed state land')
            check(m['sourceId'] == 'natural-earth-admin1-land', 'US map must use lake-clipped boundaries')
            check(ids == {'US-' + i for i in US_STATES}, 'Incorrect US state set')
            check(set(by_id) == ids | {'US-DC'}, 'Incorrect US background')
            check(m['referenceSvgGeoreferenced'] is False, 'SVG must stay a visual reference')
            svg = ET.parse(asset(manifest_path.parent, m['referenceSvgAsset'])).getroot()
            check(svg.get('viewBox') == '0 0 959 593', 'SVG viewBox changed')
            svg_ids = [e.get('id') for e in svg.iter() if e.get('id')]
            check(len(svg_ids) == len(set(svg_ids)), 'Duplicate SVG ID')
            check({'us-' + i.lower() for i in US_STATES} <= set(svg_ids), 'Missing SVG state path')
        if m['id'] == 'germany-states':
            check(ids == {'DE-' + i for i in GERMAN_STATES}, 'Incorrect German state set')
        if m['id'] == 'nyc-boroughs':
            check(ids == {'NYC-BORO-' + str(i) for i in range(1, 6)}, 'Incorrect borough set')

    cities, bounds = collection(ROOT / 'data/us-cities.geojson', points=True)
    check(len(cities) == 769, 'Unexpected city count')
    check(-180 <= bounds[0] < bounds[2] <= -66 and 18 <= bounds[1] < bounds[3] <= 72,
          'US city bounds mismatch')
    for city in cities:
        p = city['properties']
        check(p['sourceId'] == 'natural-earth-places' and city['id'].startswith('NE-'), 'City source mismatch')
        check(isinstance(p['sourcePopulationMax'], (int, float)) and
              isinstance(p['sourceScaleRank'], (int, float)), 'Missing city metadata')
    for name, box in {'Los Angeles': (-118.5, 33.9, -118, 34.2),
                      'New York': (-74.1, 40.6, -73.8, 40.9),
                      'Anchorage': (-150, 61, -149.5, 61.5),
                      'Honolulu': (-158, 21.2, -157.7, 21.5)}.items():
        matches = [f for f in cities if f['properties']['name'] == name]
        check(len(matches) == 1, f'Missing or ambiguous city: {name}')
        lon, lat = matches[0]['geometry']['coordinates']
        check(box[0] <= lon <= box[2] and box[1] <= lat <= box[3], f'Wrong city location: {name}')

    prefix = 'http://nyc.pediacities.com/Resource/Neighborhood/'
    known_invalid = {prefix + name for name in ('Country_Club', 'Marine_Park')}
    candidates, _ = collection(ROOT / 'data/candidates/nyc-neighborhoods.geojson',
                               name_key='neighborhood', known_invalid=known_invalid)
    check(len(candidates) == 266, 'Unexpected NYC candidate count')
    for name in ('Chinatown', 'Nolita', 'Tribeca', 'Financial District'):
        matches = [f for f in candidates if f['properties']['neighborhood'] == name]
        check(len(matches) == 1 and matches[0]['properties']['borough'] == 'Manhattan',
              f'Missing requested neighborhood: {name}')
        check(shape(matches[0]['geometry']).is_valid, f'Invalid requested neighborhood: {name}')
    check_focused_neighborhoods(candidates)
    print(f'PASS: 12 catalog map packs, {sum(GEOMETRY_COUNTS.values())} valid area features, 769 legacy city points, and source hashes.')
    print('Original NYC snapshot retained; repairs applied before practice groups are merged.')


if __name__ == '__main__':
    main()
