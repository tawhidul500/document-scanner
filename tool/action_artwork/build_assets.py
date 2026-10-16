"""Reproduce shared action alpha masks from the user's original SVGs."""
from copy import deepcopy
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
NS = '{http://www.w3.org/2000/svg}'
ET.register_namespace('', NS[1:-1])
OUT = ROOT / 'assets/actions'
OUT.mkdir(exist_ok=True)


def export(name, source, indices, box):
    original = ET.parse(ROOT / source).getroot()
    elements = list(original.iter())
    x, y, width, height = box
    svg = ET.Element(NS + 'svg', width=str(width), height=str(height),
                     viewBox=f'{x} {y} {width} {height}', fill='none')
    for index in indices:
        svg.append(deepcopy(elements[index]))
    path = Path(__file__).parent / f'{name}.svg'
    ET.ElementTree(svg).write(path, encoding='unicode')
    png = OUT / f'{name}.png'
    subprocess.run(['inkscape', str(path), f'--export-filename={png}',
                    f'--export-width={round(width * 4)}'], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Knock out the white paper fill in the overlapping-page artwork. Tinting
    # must preserve clear interiors on both light and dark toolbar surfaces.
    if name == 'merge':
        image = Image.open(png).convert('RGBA')
        image.putdata([(0, 0, 0, round(a * (255 - max(r, g, b)) / (255 - 107)))
                       for r, g, b, a in image.getdata()])
        image.save(png)


menu = 'design/document_folder/Document_page-4.svg'
review = 'design/document_review_reference.svg'
folder = 'design/document_folder/Document_page.svg'
export('close', menu, [110], (346.5, 679.5, 10.5, 10.5))
export('rename', menu, [105, 106], (31, 733, 24, 24))
export('download', menu, [112], (31, 773, 24, 24))
export('edit', review, [18, 19, 20], (127, 756, 26, 26))
export('ocr', review, [22], (222.5, 757.5, 19, 19))
export('sign', review, [35, 36], (313, 758, 19, 19))
export('share', folder, [104, 105, 106, 107], (133.5, 749.5, 24, 24))
export('move', folder, [102], (50, 749, 24, 24))
export('merge', folder, [109, 110], (219.5, 749, 24, 24))
export('delete', folder, [112], (306, 749, 24, 24))
