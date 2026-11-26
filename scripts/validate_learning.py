"""Validate the offline fact database and its source links and map positions.

Run with .venv/bin/python scripts/validate_learning.py.
"""
import json
import math
import struct
from collections import Counter
from urllib.parse import urlparse

from shapely.geometry import shape, Point
from compile_learning import ROOT, verify_sources


def check(value, message):
    if not value:
        raise ValueError(message)


def main():
    verify_sources()
    data = json.loads((ROOT / 'content/learning.json').read_text())
    check(data['schemaVersion'] == 1, 'Unsupported fact schema')
    states = {s['id']: s for s in data['states']}
    check(len(states) == len(data['states']) == 66, 'State inventory')
    maps = {}
    for country, pack, count in [('US', 'us-states', 50), ('DE', 'germany-states', 16)]:
        manifest = json.loads((ROOT / 'maps' / pack / 'map.json').read_text())
        check({s for s in states if s.startswith(country)} == {a['id'] for a in manifest['areas']}, 'State IDs do not match map')
        maps.update({f['id']: shape(f['geometry']) for f in json.loads((ROOT / 'maps' / pack / manifest['geometryAsset']).read_text())['features']})
    for state in states.values():
        for field in ['capital', 'nickname', 'nicknameKind', 'flagCredit', 'flagLicense']:
            check(bool(state[field]), f"Missing {field}: {state['id']}")
        asset = (ROOT / 'content' / state['flagAsset']).resolve()
        check(asset.is_relative_to(ROOT / 'content/flags'), 'Flag outside assets folder')
        blob = asset.read_bytes()
        check(blob[:8] == b'\x89PNG\r\n\x1a\n', 'Invalid flag image')
        width, height = struct.unpack('>II', blob[16:24])
        check(width >= 300 and height >= 100, 'Flag image too small')
        check(urlparse(state['flagSource']).netloc == 'commons.wikimedia.org', 'Missing flag provenance')
    for kind, counts in [('cities', {'US': 50, 'DE': 10}), ('landmarks', {'US': 50, 'DE': 20})]:
        rows = data[kind]
        check(Counter(r['country'] for r in rows) == counts, f'{kind}: wrong country counts')
        check(len({r['id'] for r in rows}) == len(rows), f'{kind}: duplicate IDs')
        check(len({r['qid'] for r in rows}) == len(rows), f'{kind}: duplicate entities')
        for row in rows:
            check(row['stateID'].startswith(row['country']), 'Country/state mismatch')
            check(urlparse(row['sourceURL']).netloc == 'www.wikidata.org', 'Missing coordinate source')
        if kind == 'cities':
            for country, count in counts.items():
                cities = [r for r in rows if r['country'] == country]
                check([r['rank'] for r in cities] == list(range(1, count + 1)), 'City ranking gap')
                check(all(a['population'] > b['population'] for a, b in zip(cities, cities[1:])), 'Population order')
                check(len({r['populationDate'] for r in cities}) == 1, 'Mixed population dates')
    points = [(s['id'], s['id'], s['capitalCoordinate']) for s in states.values()]
    points += [(p['id'], p['stateID'], p['coordinate']) for p in data['cities'] + data['landmarks']]
    for identifier, state, coordinate in points:
        lon, lat = coordinate['longitude'], coordinate['latitude']
        check(math.isfinite(lon) and math.isfinite(lat) and -180 <= lon <= 180 and -90 <= lat <= 90, identifier)
        # Natural Earth shorelines are generalized; allow 0.15 degrees for coast/border points.
        check(maps[state].distance(Point(lon, lat)) < 0.15, f'Point outside expected state: {identifier}')
    names = {p['name']: p for p in data['landmarks']}
    for name, (lon, lat) in {'Statue of Liberty': (-74.04443, 40.68921), 'Liberty Bell': (-75.1503, 39.9495), 'Mount Rushmore': (-103.45917, 43.87889)}.items():
        point = names[name]['coordinate']
        check(abs(point['longitude'] - lon) < 0.002 and abs(point['latitude'] - lat) < 0.002, 'Requested sight coordinate changed')
    check(states['US-MN']['flagAsset'] != states['US-UT']['flagAsset'], 'Flags reused incorrectly')
    # Timed-challenge places: (west, south, east, north) limits and one known point per list.
    for key, count, box, known in [('world-countries', 148, (-180, -60, 180, 75), ('Paris, France', 2.35, 48.86)),
                                   ('nyc', 56, (-74.3, 40.45, -73.7, 40.95), ('Times Square', -73.9858, 40.7575))]:
        rows = data['challenge'][key]
        check(len(rows) == len({r['id'] for r in rows}) == len({r['name'] for r in rows}) == count, f'{key}: challenge inventory')
        for row in rows:
            lon, lat = row['coordinate']['longitude'], row['coordinate']['latitude']
            check(box[0] <= lon <= box[2] and box[1] <= lat <= box[3], f"Challenge point outside its map: {row['id']}")
        point = next(r for r in rows if r['name'] == known[0])['coordinate']
        check(abs(point['longitude'] - known[1]) < 0.05 and abs(point['latitude'] - known[2]) < 0.05, f'{key}: known point moved')
    print('PASS: 66 state capitals/names/flags, 60 ranked city populations, 70 landmarks, 196 geographic points, '
          '148 world and 56 New York challenge places, image headers and source hashes.')


if __name__ == '__main__':
    main()
