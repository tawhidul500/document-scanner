from pathlib import Path
from copy import deepcopy
import xml.etree.ElementTree as E
root=Path(__file__).resolve().parents[2]
source=E.parse(root/'design/scanner-camera-screen.svg').getroot()
E.register_namespace('','http://www.w3.org/2000/svg')
for name,id_,box in [('close','TopBar',(18,16,24,24)),('flash','TopBar',(348,16,24,24)),
                     ('images','ImportImages',(71.5,751,26,26)),('files','ImportFiles',(292.5,751,26,26))]:
 x,y,w,h=box
 node=next(n for n in source.iter() if n.get('id')==id_)
 svg=E.Element('{http://www.w3.org/2000/svg}svg',{'width':str(w),'height':str(h),'viewBox':f'{x} {y} {w} {h}'})
 svg.append(deepcopy(node))
 E.ElementTree(svg).write(root/f'tool/scanner_artwork/{name}.svg')
