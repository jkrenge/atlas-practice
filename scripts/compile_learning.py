"""Rebuild offline learning facts from pinned public source snapshots.

Run with .venv/bin/python scripts/compile_learning.py.
"""
import csv
import gzip
import hashlib
import html
import json
import re
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/sources'
CURATION = ROOT / 'data/learning'


def read(path):
    return json.loads(path.read_text())


def current(entity, prop):
    rows = [r for r in entity['claims'].get(prop, []) if r['rank'] != 'deprecated'
            and r['mainsnak'].get('datavalue') and 'P582' not in r.get('qualifiers', {})]
    preferred = [r for r in rows if r['rank'] == 'preferred']
    return [r['mainsnak']['datavalue']['value'] for r in preferred or rows]


def verify_sources():
    for relative, expected in read(ROOT / 'data/learning-checksums.json').items():
        if hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() != expected:
            raise ValueError(f'Learning source checksum mismatch: {relative}')


def coordinate(entity):
    point = current(entity, 'P625')[0]
    return {'longitude': point['longitude'], 'latitude': point['latitude']}


def flag_credit(metadata):
    """Plain-text author credit from a Commons Artist field, without wiki markup."""
    value = metadata.get('Artist', {}).get('value', 'Wikimedia Commons contributors')
    # Commons templates repeat the author in hidden elements for machine readers.
    value = re.sub(r'<(\w+)[^>]*display:\s*none[^>]*>.*?</\1>', '', value, flags=re.S)
    value = re.sub(r'<br\s*/?>|</li>|</p>|\u2002', '\n', value)
    text = html.unescape(re.sub('<[^>]*>', '', value))
    text = re.split(r'(?m)^\s*\w+=', text)[0]  # template fields start a line
    text = re.sub(r'\b(?:Template|User|Benutzer):', '', text)
    parts = [re.sub(r'\s+', ' ', part).strip(' ,;') for part in text.split('\n')]
    text = '; '.join(part for part in parts if part)
    return 'Unknown author' if re.fullmatch(r'(?i)(n\.?/?a\.?|unknown)?', text) else text


def challenge_places(entities):
    """Timed-challenge targets for the maps that have no city and landmark facts of their own."""
    from compile_maps import records
    countries = {f['properties']['adminCode'] for f in read(ROOT / 'maps/world-countries/areas.geojson')['features']
                 if f['properties']['quizEligible']}
    world = []
    for row in records('ne_10m_populated_places.zip'):
        p = row.record.as_dict()
        # Well-known cities only: the source's two top label ranks, capitals above
        # one million people, and any city above five million.
        if p['ADM0_A3'] in countries and (p['SCALERANK'] <= 1 or p['POP_MAX'] >= 5_000_000
                                          or (p['ADM0CAP'] == 1 and p['POP_MAX'] >= 1_000_000)):
            longitude, latitude = row.shape.points[0]
            world.append({'id': f"city-NE-{p['NE_ID']}",
                          'name': ' '.join(f"{p['NAME_EN'] or p['NAME']}, {p['ADM0NAME']}".split()),
                          'coordinate': {'longitude': longitude, 'latitude': latitude}})
    sights = [{'id': row['id'], 'name': row['name'], 'coordinate': coordinate(entities[row['qid']]),
               'sourceURL': 'https://www.wikidata.org/wiki/' + row['qid']}
              for row in read(CURATION / 'nyc-sights.json')]
    return {'world-countries': world, 'nyc': sights}


def main():
    verify_sources()
    entities = {}
    paths = sorted((SOURCE / 'place-queries').glob('*.json.gz'))
    paths += [SOURCE / 'places-remaining.json.gz', SOURCE / 'places-corrections.json.gz']
    # Complete EntityData snapshots take priority over API query snapshots.
    paths += sorted((SOURCE / 'wikidata').glob('*.json.gz'))
    for path in paths:
        data = json.loads(gzip.decompress(path.read_bytes()))
        entities.update({k: e for k, e in data.get('entities', {}).items() if 'missing' not in e})
    names = {a['id']: a['name'] for pack in ['us-states', 'germany-states']
             for a in read(ROOT / 'maps' / pack / 'map.json')['areas']}
    flags = read(CURATION / 'flag-metadata.json')
    slogans = read(CURATION / 'german-slogans.json')
    states = []
    for sid, qid in read(CURATION / 'state-entities.json').items():
        entity = entities[qid]
        capitals = current(entity, 'P36')
        assert len(capitals) <= 1, sid
        # Berlin and Hamburg are city-states and their own capitals.
        assert capitals or sid in ['DE-BE', 'DE-HH'], sid
        capital = entities[capitals[0]['id']] if capitals else entity
        slogan = slogans.get(sid, {})
        nick = next((n['text'] for n in current(entity, 'P1449') if n['language'] == 'en'), None)
        nickname = slogan.get('text', nick)
        assert nickname, sid
        flag = flags[sid]
        metadata = flag['extmetadata']
        credit = flag_credit(metadata)
        assert not re.search(r'[<>=\n]|Template:|User:', credit), (sid, credit)
        labels = capital['labels']
        states.append({
            'id': sid, 'name': names[sid],
            'capital': labels.get('de' if sid.startswith('DE') else 'en', labels['en'])['value'],
            'capitalCoordinate': coordinate(capital), 'capitalSource': 'https://www.wikidata.org/wiki/' + capital['id'],
            'sourceURL': 'https://www.wikidata.org/wiki/' + qid,
            'nickname': nickname, 'nicknameKind': slogan.get('kind', 'Nickname'),
            'nicknameSource': slogan.get('source', 'https://www.wikidata.org/wiki/' + qid),
            'flagAsset': 'flags/' + sid + '.png', 'flagCredit': credit,
            'flagSource': flag['descriptionurl'], 'flagLicense': metadata['LicenseShortName']['value'],
            'flagLicenseURL': metadata.get('LicenseUrl', {}).get('value'), 'flagRetrievedAt': '2026-09-14',
        })
    us_rows = {r[0]: r for r in openpyxl.load_workbook(SOURCE / 'census-us-cities-2025.xlsx', data_only=True).active.values
               if isinstance(r[0], int) and r[0] <= 50}
    with (SOURCE / 'destatis-cities-2024.csv').open(encoding='utf-8-sig') as handle:
        de_rows = sorted(csv.DictReader(handle), key=lambda r: int(r['2024']), reverse=True)[:10]
    sets = {}
    for kind in ['cities', 'landmarks']:
        rows = read(CURATION / (kind + '.json'))
        for row in rows:
            entity = entities[row['qid']]
            row['coordinate'] = coordinate(entity)
            row['sourceURL'] = 'https://www.wikidata.org/wiki/' + row['qid']
            if kind == 'cities':
                rank = row['rank']
                if row['country'] == 'US':
                    source = us_rows[rank]
                    assert row['populationDefinition'] == source[1], row['id']
                    row.update(population=source[8], populationDate='2025-07-01', populationSource='census-2025')
                else:
                    source = de_rows[rank - 1]
                    assert row['name'] == source['Name'], row['id']
                    row.update(population=int(source['2024']), populationDate='2024-12-31', populationSource='destatis-2024')
        sets[kind] = rows
    result = {'schemaVersion': 1, 'retrievedAt': '2026-09-14', 'states': states, **sets,
              'challenge': challenge_places(entities)}
    (ROOT / 'content/learning.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f"Compiled {len(states)} states, {len(sets['cities'])} cities, {len(sets['landmarks'])} landmarks, "
          + ', '.join(f'{len(v)} {k} challenge places' for k, v in result['challenge'].items()) + '.')


if __name__ == '__main__':
    main()
