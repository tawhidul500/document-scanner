"""Extract reference artwork at 4x. Requires Inkscape; no UI text is rasterized."""
from copy import deepcopy
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = '{http://www.w3.org/2000/svg}'
ET.register_namespace('', NS[1:-1])
SOURCE = ET.parse(ROOT / 'design/scan_results/QR-Code_page_redesign.svg').getroot()
BARCODE = ET.parse(ROOT / 'design/scan_results/Barcode_page_redesign.svg').getroot()
OUT = ROOT / 'assets/scan_results'
OUT.mkdir(exist_ok=True)

def by_id(root, name):
    return next(el for el in root.iter() if el.get('id') == name)

def export(name, box, elements, shadow=False):
    x, y, w, h = box
    root = ET.Element(NS + 'svg', width=str(w), height=str(h),
                      viewBox=f'{x} {y} {w} {h}', fill='none')
    defs = deepcopy(SOURCE.find(NS + 'defs'))
    # Inkscape does not implement SVG2 feDropShadow. Use equivalent SVG1 primitives.
    for f in defs.findall(NS + 'filter'):
        drop = f.find(NS + 'feDropShadow')
        if drop is None:
            continue
        f.remove(drop)
        ET.SubElement(f, NS + 'feGaussianBlur', {'in': 'SourceAlpha',
            'stdDeviation': drop.get('stdDeviation'), 'result': 'blur'})
        ET.SubElement(f, NS + 'feOffset', {'in': 'blur', 'dx': drop.get('dx'),
            'dy': drop.get('dy'), 'result': 'offset'})
        ET.SubElement(f, NS + 'feFlood', {'flood-color': drop.get('flood-color'),
            'flood-opacity': drop.get('flood-opacity'), 'result': 'color'})
        ET.SubElement(f, NS + 'feComposite', {'in': 'color', 'in2': 'offset',
            'operator': 'in', 'result': 'shadow'})
        merge = ET.SubElement(f, NS + 'feMerge')
        ET.SubElement(merge, NS + 'feMergeNode', {'in': 'shadow'})
        ET.SubElement(merge, NS + 'feMergeNode', {'in': 'SourceGraphic'})
    root.append(defs)
    for element in elements:
        copy = deepcopy(element)
        if not shadow:
            for el in copy.iter():
                el.attrib.pop('filter', None)
        root.append(copy)
    path = Path(__file__).parent / f'{name}.svg'
    ET.ElementTree(root).write(path, encoding='unicode')
    subprocess.run(['inkscape', str(path), f'--export-filename={OUT / (name + ".png")}',
                    f'--export-width={round(w * 4)}'], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

export('back', (19, 31, 20, 18), [by_id(SOURCE, 'Back_Button')])
export('close', (326, 107, 14, 14), [list(by_id(SOURCE, 'Close_Button'))[1]])
export('open', (45, 269, 18, 18), [list(by_id(SOURCE, 'Open_Button'))[1]])
export('search', (44, 268, 19, 19), [list(by_id(BARCODE, 'Search_Button'))[1]])
export('copy', (152, 267, 16, 16), list(by_id(SOURCE, 'Copy_Button'))[1:3])
export('save', (267, 269, 16, 20), [list(by_id(SOURCE, 'Save_Button'))[1]])
export('mini_barcode', (262, 156, 64, 30), [by_id(BARCODE, 'Mini_Barcode')])
export('illustration', (40, 406, 295, 150), [by_id(SOURCE, 'Illustration')], shadow=True)
export('play', (92, 690, 22, 24), [by_id(SOURCE, 'Play_Icon')])
export('next', (299, 695, 16, 14), [list(by_id(SOURCE, 'CTA_Get_On_Google_Play'))[-1]])
