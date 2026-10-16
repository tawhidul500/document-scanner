"""Build exact-path theme icons and dark UI artwork. Requires Inkscape."""
from pathlib import Path
from copy import deepcopy
import subprocess
import xml.etree.ElementTree as E

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
NS = '{http://www.w3.org/2000/svg}'
E.register_namespace('', NS[1:-1])

def render(svg, output):
    root = E.parse(svg).getroot()
    width = float(root.get('width'))
    subprocess.run(['inkscape', str(svg), '--export-type=png',
        '--export-filename=' + str(output), '--export-width=' + str(round(width * 4))],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not output.exists() or output.stat().st_size == 0:
        raise RuntimeError(f'No PNG was produced: {output}')

def write(name, root, output):
    path = HERE / (name + '.svg')
    E.ElementTree(root).write(path)
    render(path, output)

def extract(name, source, indices, box):
    x,y,w,h = box
    svg = E.parse(ROOT / 'design/theme' / source).getroot()
    out = E.Element(NS+'svg', {'width':str(w),'height':str(h),'viewBox':f'{x} {y} {w} {h}', 'fill':svg.get('fill','none')})
    out.append(deepcopy(svg[-1]))
    for i in indices:
        # Current supplied Settings SVG includes an additional status-bar mask.
        out.append(deepcopy(svg[0][i + (1 if source == 'Setting_page.svg' else 0)]))
    return out

def background(root, color):
    x,y,w,h = root.get('viewBox').split()
    root.insert(1,E.Element(NS+'rect',{'x':x,'y':y,'width':w,'height':h,'fill':color}))

def recolor(root, colors):
    for e in root.iter():
        for key in ('fill','stroke'):
            if e.get(key) in colors: e.set(key, colors[e.get(key)])

icons = [
 ('language',range(9,13),(31,153,37.108,37.108)),
 ('theme',range(18,20),(31,201.828,37.108,37.108)),
 ('vibration',range(25,28),(31,250.652,37.108,37.108)),
 ('beep',range(33,36),(31,299.477,37.108,37.108)),
 ('share',range(52,57),(32,396.254,37.108,37.108)),
 ('rate',range(61,63),(32,445.082,37.108,37.108)),
 ('privacy',range(67,70),(32,493.906,37.108,37.108)),
 ('terms',range(74,77),(32,542.734,37.108,37.108)),
 ('apps',range(81,86),(32,591.559,37.108,37.108)),
 ('about',range(43,47),(30,685.625,36.752,36.752)),
 ('chevron',[16],(336,165,9,14)),
]
for name, ids, box in icons:
    svg=extract(name,'Setting_page.svg',ids,box)
    # Decorative glyph geometry stays exact; strengthen low-contrast strokes.
    if name in ('beep','privacy'): recolor(svg,{'#22B35E':'#167C43'})
    if name=='rate': recolor(svg,{'#F5921E':'#A95705'})
    write(name,svg,ROOT/f'assets/theme/{name}.png')
    dark=deepcopy(svg)
    recolor(dark, {'#E6F0FF':'#253C61','#F0E7FF':'#382753',
        '#E4F7EC':'#183F31','#FFF1DD':'#49321C',
        '#167C43':'#72E5A3','#A95705':'#FFC16A'})
    if name in ('share','apps'): recolor(dark,{'#1A6BE0':'#99BDFF'})
    if name in ('vibration','terms'): recolor(dark,{'#8B4BEA':'#CBABFF'})
    write(name+'_dark',dark,ROOT/f'assets/theme/{name}_dark.png')
for name, ids, box in [
 ('system',[14,15],(29.3945,194.426,93.94,71.394)),
 ('light',range(23,41),(28.9248,298.9563,94.8794,72.3334)),
 ('dark',range(46,56),(29.3945,404.637,93.94,71.394)),
 ('back',[8],(28,51,22,18)),
]:
    write(name,extract(name,'Theme_page.svg',ids,box),ROOT/f'assets/theme/{name}.png')

for path in (ROOT/'tool/home_artwork').glob('*.svg'):
    name=path.stem
    if name.startswith('navigation_'): continue
    svg=E.parse(path).getroot()
    if name=='navigation':
        for state in ('','_settings','_neutral'):
            variant=deepcopy(svg)
            nav=variant[1]
            nav[2].set('fill','#18233B')
            for i in (3,4):nav[i].set('fill','#99BDFF' if state=='_settings' else '#B8C4DB')
            for i in (5,6):nav[i].set('fill','#99BDFF' if state=='' else '#B8C4DB')
            background(variant,'#18233B')
            write(name+state+'_dark',variant,ROOT/f'assets/home/exact_{name}{state}_dark.png')
        continue
    recolor(svg,{'#0F2A5C':'#F3F6FF','#E3E9F3':'#3D4D69',
        '#EAF2FF':'#243858','#E9F8EF':'#193D32',
        '#F2EBFF':'#35264D','#FFF3E5':'#43331F',
        '#EEF3FC':'#263B61','#DCE8FB':'#3D4D69'})
    if name.startswith('tile_'): svg[1].set('fill','#18233B')
    if name=='masthead':background(svg,'#152B52')
    write(name+'_dark',svg,ROOT/f'assets/home/exact_{name}_dark.png')

for path in (ROOT/'tool/file_artwork').glob('*.svg'):
    svg=E.parse(path).getroot();name=path.stem
    recolor(svg,{'#E3E9F3':'#3D4D69','#44536B':'#B8C4DB'})
    if name in ('pdf','image','text'):
        svg[1].set('fill','#33283C' if name=='pdf' else '#263B61')
    write('file_'+name+'_dark',svg,ROOT/f'assets/files/{name}_dark.png')
print('Built reference icons and dark variants.')
