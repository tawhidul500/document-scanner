"""Check semantic color contrast directly against the Dart palette."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT/'lib/theme/app_theme.dart').read_text()

def luminance(hex_color):
    values = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
    values = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    return sum(v*w for v,w in zip(values,(.2126,.7152,.0722)))

def contrast(a,b):
    x,y=sorted((luminance(a),luminance(b)))
    return (y+.05)/(x+.05)

def palette():
    result={}
    for role,dark,light in re.findall(r'Color get (\w+) => dark \? (.*?) : (.*?);', SOURCE):
        values=[]
        for value in (light,dark):
            values.append('FFFFFF' if value=='Colors.white' else
                re.search(r'0xFF([0-9A-Fa-f]{6})',value).group(1))
        result[role]=values
    return result

class ThemeContrastTest(unittest.TestCase):
    def test_text_on_app_surfaces(self):
        colors=palette()
        for mode in (0,1):
            for foreground in ('text','secondary','primary','danger'):
                for background in ('surface','background','workspace','selected'):
                    with self.subTest(mode=mode,foreground=foreground,background=background):
                        self.assertGreaterEqual(contrast(colors[foreground][mode],colors[background][mode]),4.5)
            self.assertGreaterEqual(contrast(colors['onPrimary'][mode],colors['primary'][mode]),4.5)
            self.assertGreaterEqual(contrast('FFFFFF',colors['header'][mode]),4.5)
            self.assertGreaterEqual(contrast(colors['controlOutline'][mode],colors['surface'][mode]),3)
            self.assertGreaterEqual(contrast(colors['text'][mode],colors['closeSurface'][mode]),4.5)
    def test_camera_menu_white_labels(self):
        source=(ROOT/'lib/features/home/camera_action_menu.dart').read_text()
        gradients=source.split('static const colors = [',1)[1].split('];',1)[0]
        for fill in re.findall(r'Color\(0xFF([0-9A-F]{6})\)',gradients):
            self.assertGreaterEqual(contrast('FFFFFF',fill),4.5,fill)

if __name__ == '__main__':
    unittest.main()
