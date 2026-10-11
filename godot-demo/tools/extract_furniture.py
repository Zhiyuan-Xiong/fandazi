"""Reuse the 32 original Figma artworks, names and unlock thresholds."""
import json
import build_scenes as source

items = []
for group in source.ALL_NODES['202:2391']['children']:
    for card in group['children']:
        values = {a['variableId']: a['variableValue']['value']
                  for node in source.walk(card) for r in node.get('reactions', [])
                  for a in r.get('actions', []) if a['type'] == 'SET_VARIABLE'
                  and a.get('variableValue', {}).get('type') in ('STRING', 'FLOAT')}
        art = [n for n in source.walk(card) if n['name'].startswith('Artwork /')][-1]
        slug = values['VariableID:201:10']
        pose = 'LieDown' if slug in ['paw-rug', 'pet-bed', 'blanket-basket'] else (
            'Default' if slug in ['sage-armchair', 'sage-sofa', 'beanbag', 'dining-chair', 'peach-cushion', 'cream-cushion'] else '')
        items.append(dict(id=slug, name=values['VariableID:201:8'], day=int(values['VariableID:201:9']),
                          category=group['name'].split(' / ')[-1], asset=source.asset_for(art), pose=pose))
assert len(items) == 32 and len({i['id'] for i in items}) == 32
(source.ROOT / 'design/furniture.json').write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding='utf-8')
print('FURNITURE_EXTRACTED', len(items))
