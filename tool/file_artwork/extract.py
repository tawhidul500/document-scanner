from pathlib import Path
from copy import deepcopy
import xml.etree.ElementTree as E
root=Path(__file__).resolve().parents[2]
source=E.parse(root/'design/file_thumbnail_reference.svg').getroot()
nodes=source[0]
E.register_namespace('','http://www.w3.org/2000/svg')
def asset(name,indices,box):
 x,y,w,h=box
 svg=E.Element('{http://www.w3.org/2000/svg}svg',{'fill':'none','width':str(w),'height':str(h),'viewBox':f'{x} {y} {w} {h}'})
 svg.append(deepcopy(source[1]))
 for index in indices:svg.append(deepcopy(nodes[index]))
 E.ElementTree(svg).write(root/f'tool/file_artwork/{name}.svg')
asset('pdf',[75,109],(14.5,473.835,46.085,46.085))
asset('image',[82,113],(14.5,534.82,46.085,46.085))
asset('text',[89,112],(14.5,595.807,46.085,46.085))
asset('more',[78,79,80],(346,488,4.08,17.76))
# Independent folder shapes from the same reference; no sample counts/labels.
for name,indices,box in [
 ('folder_document',[55,56],(30,321.771,48,37)),
 ('folder_idCard',[60,61],(119,321.771,48,37)),
 ('folder_qr',[65,66],(207,321.771,48,37)),
 ('folder_barcode',[70,71],(296,320.771,48,37))]:asset(name,indices,box)
