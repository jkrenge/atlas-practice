"""Build reduced GeoJSON assets; install tools with npm ci --prefix scripts/geometry."""
import copy
import json
import math
import subprocess
import tempfile
from pathlib import Path

import shapely
from shapely.affinity import scale
from shapely.geometry import Point, Polygon, mapping, shape
from shapely.ops import polygonize, unary_union

ROOT = Path(__file__).resolve().parents[1]
LIMITS = {'us-states': 6000, 'germany-states': 2000, 'nyc-boroughs': 60,
          'nyc-neighborhoods-focused': 60, 'nyc-neighborhoods': 60, 'world-countries': 12000}
MAX_AREA_CHANGE = 0.01
WATER_PROBES = {
    'us-states': [(-87, 43.5), (-112.5, 41.1), (-81, 26.9)],
    'germany-states': [(9.4, 47.62), (12.7, 53.43), (11.46, 53.7)],
    'world-countries': [(-87, 43.5), (108, 53), (33, -1), (-112.5, 41.1)],
    'nyc-boroughs': [(-73.965, 40.743), (-74.015, 40.72)],
    'nyc-neighborhoods-focused': [(-73.965, 40.743), (-74.015, 40.72),
        (-73.99278510511897, 40.70465085326032), (-73.95473150505875, 40.73979288426392)],
}


def polygons(geometry):
    return list(geometry.geoms) if geometry.geom_type == 'MultiPolygon' else [geometry]


def matched_coverage(geometries):
    if shapely.coverage_is_valid(geometries):
        return geometries
    # Node shared edges. Assign tiny source overlaps to the first source area;
    # unowned faces remain water. Do not fill existing source gaps.
    parts = [[] for _ in geometries]
    for face in polygonize(unary_union([g.boundary for g in geometries])):
        point = face.representative_point()
        for index, geometry in enumerate(geometries):
            if geometry.covers(point):
                parts[index].append(face)
                break
    result = [unary_union(p) for p in parts]
    if not shapely.coverage_is_valid(result):
        raise ValueError('Source edges could not form a matched coverage')
    return result


def simplify(features, limit, water_points):
    original = [shape(f['geometry']) for f in features]
    coverage = matched_coverage(original)
    latitude = (min(g.bounds[1] for g in coverage) + max(g.bounds[3] for g in coverage)) / 2
    xscale, yscale = 111320 * math.cos(math.radians(latitude)), 111320
    rings = []
    for index, geometry in enumerate(coverage):
        for part_index, polygon in enumerate(polygons(geometry)):
            for ring_index, ring in enumerate([polygon.exterior, *polygon.interiors]):
                projected = scale(Polygon(ring), xfact=xscale, yfact=yscale, origin=(0, 0))
                rings.append({'type': 'Feature', 'properties': {
                    'key': f'{index}:{part_index}:{ring_index}', 'owner': index,
                    'threshold': min(limit, math.sqrt(projected.area) * 0.1)},
                    'geometry': mapping(projected)})
    executable = ROOT / 'scripts/geometry/node_modules/.bin/mapshaper'
    with tempfile.TemporaryDirectory() as directory:
        source, destination = Path(directory) / 'rings.json', Path(directory) / 'reduced.json'
        for _ in range(12):
            source.write_text(json.dumps({'type': 'FeatureCollection', 'features': rings}))
            subprocess.run([str(executable), str(source), '-simplify', 'variable', 'dp', 'planar',
                            'interval=threshold', 'keep-shapes', '-o', 'force', str(destination)],
                           check=True, capture_output=True, text=True)
            reduced = {f['properties']['key']: [[x / xscale, y / yscale] for x, y in
                       f['geometry']['coordinates'][0]] for f in
                       json.loads(destination.read_text())['features']}
            result = []
            for index, geometry in enumerate(coverage):
                coordinates = [[reduced[f'{index}:{j}:{k}'] for k in range(1 + len(part.interiors))]
                               for j, part in enumerate(polygons(geometry))]
                result.append(shape({'type': 'Polygon' if len(coordinates) == 1 else 'MultiPolygon',
                                     'coordinates': coordinates[0] if len(coordinates) == 1 else coordinates}))
            # Remove floating-point noise from projection round trips (about
            # 0.01 mm); this is not the simplification threshold.
            result = list(shapely.set_precision(shapely.make_valid(result), 1e-10))
            bad = {i for i, (before, after) in enumerate(zip(original, result))
                   if after.is_empty or after.geom_type not in ('Polygon', 'MultiPolygon') or
                   before.symmetric_difference(after).area / before.area > MAX_AREA_CHANGE or
                   any(after.covers(Point(point)) for point in water_points)}
            if not bad and shapely.coverage_is_valid(result):
                output = copy.deepcopy(features)
                for feature, geometry in zip(output, result):
                    feature['geometry'] = mapping(geometry)
                return output
            for ring in rings:
                if ring['properties']['owner'] in bad or not bad:
                    ring['properties']['threshold'] /= 2
    raise ValueError('Could not simplify within the area and topology limits')


def simplify_maps():
    report = {}
    for identifier, limit in LIMITS.items():
        folder = ROOT / 'maps' / identifier
        source = folder / 'areas.geojson'
        original = json.loads(source.read_text())
        reduced = {'type': 'FeatureCollection', 'features': simplify(original['features'], limit,
                   WATER_PROBES.get(identifier, []))}
        destination = folder / 'areas-lowres.geojson'
        destination.write_text(json.dumps(reduced, ensure_ascii=False, separators=(',', ':')) + '\n')
        report[identifier] = {
            'originalPoints': int(shapely.get_num_coordinates([shape(f['geometry']) for f in original['features']]).sum()),
            'reducedPoints': int(shapely.get_num_coordinates([shape(f['geometry']) for f in reduced['features']]).sum()),
            'originalBytes': source.stat().st_size, 'reducedBytes': destination.stat().st_size,
            'maxAreaChange': MAX_AREA_CHANGE, 'maxIntervalMeters': limit}
        print(identifier, report[identifier])
    for manifest in (ROOT / 'maps').glob('*/map.json'):
        data = json.loads(manifest.read_text())
        data['geometryAsset'] = data['geometryAsset'].replace('areas.geojson', 'areas-lowres.geojson')
        manifest.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    (ROOT / 'data/geometry-simplification.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    simplify_maps()
