"""Compile the inspected Figma tree to editable native Godot scenes."""
import copy
import json
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = json.loads((ROOT / 'design/figma-snapshot.json').read_text(encoding='utf-8'))
ASSETS = json.loads((ROOT / 'design/asset-map.json').read_text(encoding='utf-8'))
STYLES = SOURCE['styles']
AUDIT = {'asset_slots': [], 'missing_images': [], 'unexported_vectors': [], 'scene_counts': {}, 'animated_otters': []}

def walk(n):
    yield n
    for child in n.get('children', []):
        yield from walk(child)

ALL_NODES = {n['id']: n for f in SOURCE['frames'] + SOURCE['components'] for n in walk(f)}
# Preserve the source's wrapping Auto Layout, including initially hidden categories.
for layout in json.loads((ROOT / 'design/catalog-layout.json').read_text(encoding='utf-8')):
    ALL_NODES[layout['id']].update({k: v for k, v in layout.items() if k != 'children'})
BUTTON_ALIGNMENT = {row[0]: row[1:] for row in json.loads((ROOT / 'design/button-alignment.json').read_text(encoding='utf-8'))['rows']}
IMAGE_HASHES = {}
SUFFIX_ASSETS = {}
for node_id, asset in ASSETS.items():
    node = ALL_NODES.get(node_id)
    if node:
        for paint in STYLES[node['style']].get('fills', []):
            if paint['type'] == 'IMAGE':
                IMAGE_HASHES[paint['imageHash']] = asset
    SUFFIX_ASSETS.setdefault(node_id.rsplit(';', 1)[-1], asset)

def asset_for(node):
    if node['id'] in ASSETS:
        return ASSETS[node['id']]
    for paint in STYLES[node['style']].get('fills', []):
        if paint['type'] == 'IMAGE':
            if paint['imageHash'] in IMAGE_HASHES:
                return IMAGE_HASHES[paint['imageHash']]
            AUDIT['missing_images'].append({'id': node['id'], 'name': node['name'], 'hash': paint['imageHash']})
    return SUFFIX_ASSETS.get(node['id'].rsplit(';', 1)[-1])

def gd(value):
    if value is None:
        return 'null'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (float, int)):
        return str(round(value, 6))
    if isinstance(value, list):
        return '[' + ', '.join(gd(v) for v in value) + ']'
    if isinstance(value, dict):
        return '{' + ', '.join(gd(k) + ': ' + gd(v) for k, v in value.items()) + '}'
    raise TypeError(type(value))

def color(value, opacity=1):
    return 'Color(%s)' % ', '.join(gd(v) for v in [value.get('r', 0), value.get('g', 0), value.get('b', 0), value.get('a', 1) * opacity])

def clean_name(value):
    return re.sub(r'[^\w\u4e00-\u9fff-]+', '_', value).strip('_')[:52] or 'Layer'

def slug(node_id):
    return re.sub(r'[^a-zA-Z0-9]', '_', node_id)

NAV_PAGES = ['165:958', '165:1308', '165:1510', '165:1669']
NAVS = [next(n for n in walk(ALL_NODES[p]) if n['name'] == 'Bottom Navigation') for p in NAV_PAGES]
# User-requested home bubble proportions; preserve its original 248 x 82 frame.
HOME_BUBBLE_LAYOUT = {
    'I165:976;165:2229': dict(x=10, y=7, width=68, height=68),
    'I165:976;165:2229;98:1958': dict(x=2, y=2, width=64, height=64),
    'I165:976;165:2242': dict(x=88, y=13, width=148, height=56),
}

class Scene:
    def __init__(self):
        self.ext = {}
        self.subs = []
        self.nodes = []
        self.count = 0
        self.root_id = ''

    def external(self, path, kind):
        if path not in self.ext:
            self.ext[path] = (kind, str(len(self.ext) + 1))
        return 'ExtResource(%s)' % gd(self.ext[path][1])

    def sub(self, kind, props):
        name = 'R%d' % (len(self.subs) + 1)
        self.subs.append('[sub_resource type=%s id=%s]\n%s\n' % (gd(kind), gd(name), '\n'.join(k + ' = ' + v for k, v in props.items())))
        return 'SubResource(%s)' % gd(name)

    def emit(self, name, kind, parent, props, instance=None):
        header = '[node name=%s' % gd(name)
        if kind:
            header += ' type=%s' % gd(kind)
        if parent is not None:
            header += ' parent=%s' % gd(parent)
        if instance:
            header += ' instance=' + instance
        self.nodes.append(header + ']\n' + '\n'.join(k + ' = ' + v for k, v in props.items()) + '\n')
        self.count += 1
        return '.' if parent is None else (name if parent == '.' else parent + '/' + name)

    def font(self, style):
        info = style.get('fontName', {})
        weight = info.get('variationSettings', {}).get('wght', 700 if 'Bold' in info.get('style', '') else 500 if 'Medium' in info.get('style', '') else 400)
        font = self.external('res://assets/fonts/NotoSansSC-VF.ttf', 'FontFile')
        return self.sub('FontVariation', {'base_font': font, 'variation_opentype': gd({int.from_bytes(b'wght', 'big'): float(weight)})})

    def add(self, n, parent=None, root=False, nav_enabled=True, override_name=None, in_container=False):
        if not root and n.get('visible') is False and 'visible' not in n.get('boundVariables', {}):
            return None
        if root:
            self.root_id = n['id']
        name = override_name or clean_name(n['name']) + '_' + slug(n['id'])
        # The hidden saved card retained a pre-redesign y=155. Replace the empty
        # lunch in its existing slot so recording does not overlap the drink card.
        if n['id'] == '165:1338':
            n = {**n, 'x':ALL_NODES['165:1337']['x'], 'y':ALL_NODES['165:1337']['y'], 'rotation':ALL_NODES['165:1337'].get('rotation',0)}
        if n['id'] in HOME_BUBBLE_LAYOUT:
            n = {**n, **HOME_BUBBLE_LAYOUT[n['id']]}
        props = {'layout_mode': '0', 'mouse_filter': '2'}
        x, y = (0, 0) if root else (n['x'], n['y'])
        w, h = n['width'], n['height']
        props.update({'offset_left': gd(x), 'offset_top': gd(y), 'offset_right': gd(x+w), 'offset_bottom': gd(y+h)})
        if in_container:
            props['layout_mode'] = '2'
            props['custom_minimum_size'] = 'Vector2(%s, %s)'%(gd(w),gd(h))
        if n.get('visible') is False:
            props['visible'] = 'false'
        if n.get('opacity', 1) != 1:
            props['modulate'] = 'Color(1, 1, 1, %s)' % gd(n['opacity'])
        if n.get('rotation'):
            props['rotation'] = gd(-math.radians(n['rotation']))
        props['metadata/figma_id'] = gd(n['id'])
        props['metadata/figma_name'] = gd(n['name'])
        props['metadata/figma_type'] = gd(n['type'])
        if n.get('boundVariables'):
            props['metadata/bindings'] = gd(n['boundVariables'])
        if n.get('reactions'):
            props['metadata/reactions'] = gd(n['reactions'])
        if n['name'] == 'Bottom Navigation' and nav_enabled:
            active = max(range(len(n['children'])), key=lambda i: n['children'][i]['width'])
            props['active_tab'] = str(active)
            return self.emit(name, None, parent, props, self.external('res://scenes/components/bottom_navigation.tscn', 'PackedScene'))
        style = copy.deepcopy(STYLES[n['style']])
        if n['id'] == 'I165:976;165:2242':
            style.update(fontSize=14, textAlignVertical='CENTER')
        texture = asset_for(n)
        direction = n.get('overflowDirection','NONE')
        scrolling = direction != 'NONE'
        kind = 'TextureRect' if texture else 'Label' if n['type'] == 'TEXT' else 'ScrollContainer' if scrolling else 'Panel'
        furniture_categories = n['name'] in ('Furniture lists', 'Catalog category lists')
        furniture_row = n['name'].startswith('Horizontal furniture / ')
        wrapped_grid = n.get('layoutWrap') == 'WRAP' and n.get('layoutMode') == 'HORIZONTAL'
        if furniture_categories:
            kind = 'VBoxContainer'
            props['theme_override_constants/separation'] = gd(n.get('itemSpacing', 0))
            props['clip_contents'] = 'true'
        if wrapped_grid:
            kind = 'GridContainer'
            cell_width = n['children'][0]['width']
            gap = n.get('itemSpacing', 0)
            props['columns'] = str(max(1, int((w + gap) / (cell_width + gap))))
            props['theme_override_constants/h_separation'] = gd(gap)
            props['theme_override_constants/v_separation'] = gd(n.get('counterAxisSpacing', gap))
        if texture:
            props['texture_filter'] = '4'
            props['texture'] = self.external(texture, 'Texture2D')
            props['expand_mode'] = '1'
            if n['name'].startswith('OTTER_') and n['name'].endswith('/PNG'):
                pose = n['name'].removeprefix('OTTER_').removesuffix('/PNG')
                motion = 'home_mood' if n['id'] == 'I165:976;165:2229;98:1958' else 'otter_motion'
                props['script'] = self.external(f'res://scripts/{motion}.gd', 'Script')
                props['pose_name'] = gd(pose)
                AUDIT['animated_otters'].append({'id': n['id'], 'scene': self.root_id, 'pose': pose})
            image_fills = [f for f in style.get('fills', []) if f['type']=='IMAGE']
            props['stretch_mode'] = '5' if image_fills and image_fills[0].get('scaleMode') == 'FIT' else '6' if image_fills else '0'
            if image_fills and style.get('cornerRadius',0) > 0:
                shader = self.external('res://scripts/rounded_gradient.gdshader','Shader')
                radii = [style.get(k,0) for k in ('topLeftRadius','topRightRadius','bottomRightRadius','bottomLeftRadius')]
                props['material'] = self.sub('ShaderMaterial', {'shader':shader,'shader_parameter/rect_size':'Vector2(%s, %s)'%(gd(w),gd(h)),'shader_parameter/radii':'Vector4(%s)'%', '.join(gd(r) for r in radii)})
            AUDIT['asset_slots'].append({'id': n['id'], 'name': n['name'], 'file': texture, 'width': w, 'height': h, 'scene': self.root_id})
        elif kind == 'Label':
            props['text'] = gd(n.get('characters', ''))
            props['theme_override_fonts/font'] = self.font(style)
            props['theme_override_font_sizes/font_size'] = str(round(style.get('fontSize', 14)))
            paints = [p for p in style.get('fills', []) if p['type']=='SOLID']
            props['theme_override_colors/font_color'] = color(paints[0]['color'], paints[0].get('opacity',1)) if paints else 'Color(0.16,0.24,0.2,1)'
            props['horizontal_alignment'] = str({'LEFT':0,'CENTER':1,'RIGHT':2,'JUSTIFIED':3}.get(style.get('textAlignHorizontal'),0))
            props['vertical_alignment'] = str({'TOP':0,'CENTER':1,'BOTTOM':2}.get(style.get('textAlignVertical'),0))
            props['autowrap_mode'] = '3'
            props['clip_text'] = 'true'
            props['mouse_filter'] = '2'
        elif kind == 'Panel':
            if n['type'] == 'ELLIPSE':
                for k in ('topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius'):
                    style[k] = min(w,h)/2
            if n['type'] == 'LINE':
                props['offset_bottom'] = gd(y + max(h, style.get('strokeWeight',1)))
                style['fills'] = style.get('strokes', [])
                style['strokes'] = []
            if n['type'] in ('VECTOR', 'BOOLEAN_OPERATION', 'POLYGON', 'STAR'):
                AUDIT['unexported_vectors'].append({'id':n['id'],'name':n['name'],'scene':self.root_id})
            props['script'] = self.external('res://scripts/surface.gd', 'Script')
            props['surface_data'] = gd(style)
            props['clip_contents'] = gd(n.get('clipsContent', False))
        elif kind == 'ScrollContainer':
            props['horizontal_scroll_mode'] = '3' if direction in ('HORIZONTAL','HORIZONTAL_AND_VERTICAL') else '0'
            props['vertical_scroll_mode'] = '3' if direction in ('VERTICAL','HORIZONTAL_AND_VERTICAL') else '0'
            props['mouse_filter'] = '1'
            if style.get('fills') or style.get('strokes'):
                backdrop = {k:v for k,v in props.items() if k not in ('horizontal_scroll_mode','vertical_scroll_mode','metadata/reactions')}
                backdrop['mouse_filter'] = '2'
                backdrop['script'] = self.external('res://scripts/surface.gd','Script')
                backdrop['surface_data'] = gd(style)
                self.emit(name+'_Backdrop', 'Panel', parent, backdrop)
        path = self.emit(name, kind, parent, props)
        content_path = path
        if scrolling and not texture:
            children = n.get('children', [])
            bottom = max([h] + [c['y']+c['height']+n.get('paddingBottom',0) for c in children if c.get('visible',True)])
            right = max([w] + [c['x']+c['width']+n.get('paddingRight',0) for c in children if c.get('visible',True)])
            if direction == 'VERTICAL': right = w
            if direction == 'HORIZONTAL': bottom = h
            content_props = {'custom_minimum_size': 'Vector2(%s, %s)'%(gd(right),gd(bottom)), 'layout_mode':'2','mouse_filter':'2'}
            if furniture_row:
                content_props['theme_override_constants/separation'] = gd(n.get('itemSpacing', 0))
            content_path = self.emit('ScrollContent', 'HBoxContainer' if furniture_row else 'Control', path, content_props)
        clicks = [r for r in n.get('reactions', []) if r['trigger']['type']=='ON_CLICK']
        if clicks:
            empty = self.sub('StyleBoxEmpty', {})
            self.emit('HitTarget','Button',content_path,{'layout_mode':'0','offset_right':gd(w),'offset_bottom':gd(h),'mouse_filter':'0','mouse_default_cursor_shape':'2','focus_mode':'2','flat':'true','theme_override_styles/normal':empty,'theme_override_styles/hover':empty,'theme_override_styles/pressed':empty,'theme_override_styles/focus':empty,'metadata/source_id':gd(n['id']),'metadata/click_actions':gd(clicks[0]['actions'])})
        # A raw IMAGE fill is only the frame's background; keep its editable overlays.
        # An exported SVG already includes its vector subtree.
        if not texture or any(p['type']=='IMAGE' for p in style.get('fills', [])):
            for c in n.get('children', []):
                # Hidden Figma instances retain padding-based coordinates until
                # revealed. Apply their authored center alignment in every state.
                if n['id'] in BUTTON_ALIGNMENT and c['type'] == 'TEXT':
                    primary, counter = BUTTON_ALIGNMENT[n['id']]
                    c = {**c, 'x': (w-c['width'])/2 if primary == 'CENTER' else c['x'],
                         'y': (h-c['height'])/2 if counter == 'CENTER' else c['y']}
                self.add(c, content_path, nav_enabled=nav_enabled, in_container=furniture_categories or furniture_row or wrapped_grid)
        return path

    def save(self, path):
        header = '[gd_scene load_steps=%d format=3]\n\n' % (len(self.ext) + len(self.subs) + 1)
        ext = '\n'.join('[ext_resource type=%s path=%s id=%s]' % (gd(k),gd(p),gd(i)) for p,(k,i) in self.ext.items())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(header + ext + '\n\n' + '\n'.join(self.subs) + '\n'.join(self.nodes), encoding='utf-8')

def main():
    nav = Scene()
    base = copy.deepcopy(NAVS[0])
    base['children'] = []
    base['x'] = base['y'] = 0
    nav.add(base, root=True, nav_enabled=False, override_name='BottomNavigation')
    nav.nodes[0] = nav.nodes[0].replace(nav.external('res://scripts/surface.gd', 'Script'), nav.external('res://scripts/bottom_navigation.gd', 'Script'))
    for i, state in enumerate(NAVS):
        path = nav.emit('State%d'%i, 'HBoxContainer', '.', {'layout_mode':'0','offset_left':'16.0','offset_top':'8.0','offset_right':'343.0','offset_bottom':'60.0','mouse_filter':'2','theme_override_constants/separation':'4','visible':gd(i==0)})
        for child in state['children']:
            nav.add(child, path, nav_enabled=False, in_container=True)
    nav.save(ROOT / 'scenes/components/bottom_navigation.tscn')
    routes = {}
    requested = set(sys.argv[1:])
    for n in SOURCE['frames'] + [c for c in SOURCE['components'] if c['id'] in ('165:2044','165:2054','165:2377')]:
        path = 'scenes/pages/' + slug(n['id']) + '.tscn'
        routes[n['id']] = {'path':'res://'+path,'name':n['name'],'width':n['width'],'height':n['height'],'component':n['type']=='COMPONENT'}
        if requested and n['id'] not in requested:
            continue
        scene = Scene()
        scene.add(n, root=True)
        scene.save(ROOT / path)
        AUDIT['scene_counts'][n['id']] = scene.count
    (ROOT / 'design/routes.json').write_text(json.dumps(routes, ensure_ascii=False, indent=2), encoding='utf-8')
    (ROOT / 'design/variables.json').write_text(json.dumps(SOURCE['variables'], ensure_ascii=False), encoding='utf-8')
    (ROOT / 'design/build-audit.json').write_text(json.dumps(AUDIT, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'scenes':len(AUDIT['scene_counts']),'nodes':sum(AUDIT['scene_counts'].values()),'asset_slots':len(AUDIT['asset_slots']),'missing_images':len(AUDIT['missing_images']),'unexported_vectors':len(AUDIT['unexported_vectors'])}))

if __name__ == '__main__':
    main()
