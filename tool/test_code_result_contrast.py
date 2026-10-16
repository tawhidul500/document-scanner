"""Contrast checks for adaptive/high-contrast colors and shared dark palette.

The default 375px light layout now preserves the supplied SVG colors exactly.
Those original translucent light colors do not meet 4.5:1 everywhere; this test
does not claim they do. The high-contrast and large-text layout uses this palette.
"""
from pathlib import Path
import re
import unittest
from test_theme_contrast import contrast

SOURCE = (Path(__file__).resolve().parents[1] /
          'lib/features/scan/code_result_screen.dart').read_text()

def rgb(value):
    return value[-6:]

def composite(foreground, background, alpha=None):
    if alpha is None:
        alpha = int(foreground[:2], 16) / 255
    front, back = rgb(foreground), rgb(background)
    return ''.join(f'{round(int(front[i:i+2],16)*alpha + int(back[i:i+2],16)*(1-alpha)):02X}'
                   for i in (0,2,4))

def role(name, dark):
    declaration = re.search(rf'Color get {name} => (.*?);', SOURCE).group(1)
    values = re.findall(r'0x([0-9A-F]{8})', declaration)
    return values[0 if dark or len(values) == 1 else 1]

class ResultContrastTest(unittest.TestCase):
    def test_result_labels_and_controls(self):
        gradient = SOURCE.split('List<Color> get gradient =>', 1)[1].split(';', 1)[0]
        stops = re.findall(r'0x([0-9A-F]{8})', gradient)
        for dark in (False, True):
            for background in (stops[:3] if dark else stops[3:]):
                # Conservative bound: brightest shine and one decorative ring.
                background = composite('FFFFFFFF', background, .04 if dark else .08)
                background = composite('FFFFFFFF', background, .035 if dark else .045)
                card = composite(role('card', dark), background)
                preview = composite(role('preview', dark), card)
                for surface in (background, card, preview,
                                composite(role('badge', dark), background),
                                composite(role('badge', dark), preview)):
                    with self.subTest(dark=dark, background=surface):
                        self.assertGreaterEqual(contrast(rgb(role('text', dark)), surface), 4.5)
                muted = composite(role('muted', dark), background)
                self.assertGreaterEqual(contrast(muted, background), 4.5)
            for foreground in ('action', 'storeText', 'storeCaption'):
                self.assertGreaterEqual(contrast(rgb(role(foreground, dark)),
                                                rgb(role('button', dark))), 4.5)

if __name__ == '__main__':
    unittest.main()
