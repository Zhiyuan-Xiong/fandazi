"""Save the exact assets supplied by Figma design context. No page renders are used in scenes."""
import concurrent.futures
import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]

class AssetParser(HTMLParser):
    def __init__(self, variables):
        super().__init__()
        self.variables = variables
        self.stack = []
        self.assets = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'img':
            var = attrs.get('src', '').strip('{}')
            node_id = next((v for _, v in reversed(self.stack) if v), None)
            if var in self.variables and node_id:
                self.assets[node_id] = self.variables[var]
        elif tag not in ('br', 'hr', 'input'):
            self.stack.append((tag, attrs.get('data-node-id')))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                return

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag != 'img':
            self.handle_endtag(tag)

def main():
    contexts = list((ROOT / 'design' / 'contexts').glob('*.txt'))
    contexts = [p for p in contexts if not p.name.startswith('94_')]
    mapping = {}
    for path in contexts:
        content = path.read_text(encoding='utf-8')
        variables = dict(re.findall(r'const (\w+) = "(https://www\.figma\.com/api/mcp/asset/[^\"]+)"', content))
        parser = AssetParser(variables)
        parser.feed(content)
        mapping.update(parser.assets)
        if variables and not parser.assets:
            raise RuntimeError(f'Could not map assets: {path}')
    asset_dir = ROOT / 'assets' / 'figma'
    asset_dir.mkdir(parents=True, exist_ok=True)
    def download(url):
        suffix = '.' + url.rsplit('.', 1)[-1]
        name = hashlib.sha256(url.encode()).hexdigest()[:20] + suffix
        out = asset_dir / name
        if not out.exists():
            subprocess.run(['curl.exe', '-f', '-L', '--retry', '2', '--max-time', '60', '-sS', '-o', str(out), url], check=True)
            if not out.exists() or not out.stat().st_size:
                raise RuntimeError(f'Empty asset: {url}')
        return url, 'res://assets/figma/' + name
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        urls = dict(pool.map(download, set(mapping.values())))
    result = {node_id: urls[url] for node_id, url in mapping.items()}
    (ROOT / 'design' / 'asset-map.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'contexts': len(contexts), 'slots': len(mapping), 'downloads': len(urls)}))

if __name__ == '__main__':
    main()
