import base64
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
stem = sys.argv[1] if len(sys.argv)>1 else 'snapshot'
raw = base64.b64decode((root / 'design' / (stem + '.lzw.b64')).read_text())
codes = [int.from_bytes(raw[i:i+2], 'big') for i in range(0, len(raw), 2)]
dictionary = {i: chr(i) for i in range(256)}
next_code = 256
word = chr(codes[0])
parts = [word]
for code in codes[1:]:
    entry = dictionary.get(code, word + word[0] if code == next_code else None)
    if entry is None:
        raise RuntimeError(f'Bad LZW code {code} at {next_code}')
    parts.append(entry)
    if next_code < 65535:
        dictionary[next_code] = word + entry[0]
        next_code += 1
    word = entry
data = json.loads(''.join(parts))
if stem == 'supplement':
    snapshot_path = root / 'design/figma-snapshot.json'
    existing = json.loads(snapshot_path.read_text(encoding='utf-8'))
    offset = len(existing['styles'])
    def remap(node):
        node['style'] += offset
        for child in node.get('children', []): remap(child)
    for entry in data['entries']: remap(entry)
    replacements = {n['id']: n for n in data['entries']}
    def merge(node):
        if node['id'] in replacements:
            node.update(replacements[node['id']])
        for child in node.get('children', []): merge(child)
    for node in existing['frames'] + existing['components']: merge(node)
    existing['styles'].extend(data['styles'])
    data = existing
(root / 'design' / 'figma-snapshot.json').write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'frames': len(data['frames']), 'components': len(data['components']), 'styles': len(data['styles'])}))
