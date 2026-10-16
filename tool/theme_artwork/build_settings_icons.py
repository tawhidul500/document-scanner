"""Extract settings glyphs while preserving the SVG's inherited fill=none.
Run this script, then node tool/theme_artwork/render_settings_icons.cjs.
"""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as E
ROOT = Path(__file__).resolve().parents[2]
NS = '{http://www.w3.org/2000/svg}'
E.register_namespace('', NS[1:-1])
source = E.parse(ROOT / 'design/theme/Setting_page.svg').getroot()
icons = [
 ('language', range(10,14), (31,153,37.108,37.108)),
 ('theme', range(19,21), (31,201.828,37.108,37.108)),
 ('vibration', range(26,29), (31,250.652,37.108,37.108)),
 ('beep', range(34,37), (31,299.477,37.108,37.108)),
 ('share', range(53,58), (32,396.254,37.108,37.108)),
 ('rate', range(62,64), (32,445.082,37.108,37.108)),
 ('privacy', range(68,71), (32,493.906,37.108,37.108)),
 ('terms', range(75,78), (32,542.734,37.108,37.108)),
 ('apps', range(82,87), (32,591.559,37.108,37.108)),
 ('about', range(44,48), (30,685.625,36.752,36.752)),
 ('chevron', [17], (336,165,9,14)),
]
dark_colors = {
 '#E6F0FF':'#253C61', '#F0E7FF':'#382753', '#E4F7EC':'#183F31',
 '#FFF1DD':'#49321C', '#22B35E':'#72E5A3', '#F5921E':'#FFC16A',
 '#1A6BE0':'#99BDFF', '#8B4BEA':'#CBABFF', '#71819B':'#B8C4DB',
}
for name, indices, (x,y,w,h) in icons:
 svg=E.Element(NS+'svg', {'width':str(w),'height':str(h),
   'viewBox':f'{x} {y} {w} {h}', 'fill':source.get('fill','none')})
 for index in indices: svg.append(deepcopy(source[0][index]))
 for dark in [False,True]:
  variant=deepcopy(svg)
  if dark:
   for el in variant.iter():
    for prop in ['fill','stroke']:
     color=el.get(prop)
     if color in dark_colors and (name not in ['language','theme'] or color not in ['#1A6BE0','#8B4BEA']):
      el.set(prop,dark_colors[color])
  E.ElementTree(variant).write(ROOT / f'tool/theme_artwork/{name}{"_dark" if dark else ""}.svg')
