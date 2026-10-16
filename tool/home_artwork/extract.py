"""Extract independent reference components; excludes system UI and sample counts."""
from pathlib import Path
import xml.etree.ElementTree as E
from copy import deepcopy
root = Path(__file__).resolve().parents[2]
source=E.parse(root/'design/home_empty_reference.svg').getroot()
nodes=source[0][1]
E.register_namespace('', 'http://www.w3.org/2000/svg')
def asset(name, indices, box):
 x,y,w,h=box
 svg=E.Element('{http://www.w3.org/2000/svg}svg', {'width':str(w),'height':str(h),'viewBox':f'{x} {y} {w} {h}'})
 svg.append(deepcopy(source[1]))
 for i in indices: svg.append(deepcopy(nodes[i]))
 E.ElementTree(svg).write(root/f'tool/home_artwork/{name}.svg')
asset('navigation', [90], (0,697,375,116))
asset('empty_illustration',range(92,104),(125,466,126,123))
asset('masthead',[1,2,*range(73,90)],(0,44,375,58))
for name,indices,x in [('document',[12,*range(16,22)],14),('idCard',[13,*range(22,29)],102),('qr',[14,38,*range(39,50)],191),('barcode',[15,*range(29,38)],279)]:
 asset('scan_'+name,indices,(x,155,82,94))
for name,start,x in [('document',52,13),('idCard',57,101),('qr',62,190),('barcode',67,278)]:
 asset('tile_'+name,[start,start+1,start+3,start+4],(x,313,83,93))
# Only active-tab colors change; all paths, positioning and filters stay exact.
for state in ['settings', 'neutral']:
 variant=deepcopy(source)
 navigation=variant[0][1][90]
 for i in [3,4]: navigation[i].set('fill', '#1C59C1' if state == 'settings' else 'black')
 for i in [5,6]: navigation[i].set('fill', 'black')
 E.ElementTree(variant).write(root/f'tool/home_artwork/navigation_{state}.svg')
