import collections
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
d = json.loads((root / 'design/figma-snapshot.json').read_text(encoding='utf-8'))
def walk(n):
    yield n
    for c in n.get('children', []):
        yield from walk(c)
nodes = [n for f in d['frames'] + d['components'] for n in walk(f)]
actions = [a for n in nodes for r in n.get('reactions', []) for a in r['actions']]
print('Nodes:', len(nodes), 'Action types:', collections.Counter(a['type'] for a in actions))
print('Navigation:', collections.Counter(a.get('navigation') for a in actions))
print('Variables in actions:', json.dumps([a for a in actions if a['type'] in ('SET_VARIABLE','CONDITIONAL')][:12], ensure_ascii=False))
print('Main frames:')
for f in d['frames']:
    print(f['id'], f['name'], len(list(walk(f))))
print('Home key nodes:')
for n in walk(next(f for f in d['frames'] if f['id']=='165:958')):
    if n['name'] in ('Bottom Navigation','Tab / 食宠','Tab / 日记','Content','Floating Feed Button'):
        print(json.dumps({**{k:v for k,v in n.items() if k!='children'},'style':d['styles'][n['style']]}, ensure_ascii=False))
print('Component destinations:')
print(sorted({a.get('destinationId') for a in actions if a.get('navigation')=='CHANGE_TO'}))
