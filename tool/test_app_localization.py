"""Validate translation coverage without needing a Flutter installation."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def catalog():
    result = {}
    for line in (ROOT / 'lib/l10n/app_catalog.dart').read_text().splitlines():
        if line.startswith('  "'):
            entry = json.loads('{' + line.strip().removesuffix(',') + '}')
            for key, values in entry.items():
                if key in result:
                    raise AssertionError(f'Duplicate translation key: {key}')
                result[key] = values
    return result


class LocalizationTest(unittest.TestCase):
    def test_every_translation_preserves_placeholders(self):
        for key, values in catalog().items():
            with self.subTest(key=key):
                self.assertEqual(len(values), 8)
                placeholders = sorted(re.findall(r'\{\w+\}', key))
                for value in values:
                    self.assertTrue(value.strip())
                    self.assertEqual(sorted(re.findall(r'\{\w+\}', value)), placeholders)

    def test_literal_ui_messages_are_in_catalog(self):
        messages = catalog()
        # Names of file formats and services stay unchanged in every language.
        invariant = {'PDF', 'Google Play'}
        literal = r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")"
        pattern = re.compile(r'(?:AppText\(|\.tr\()\s*' + literal)
        for path in (ROOT / 'lib').rglob('*.dart'):
            if 'l10n' in path.parts:
                continue
            for match in pattern.finditer(path.read_text()):
                raw = match[1]
                if '$' in raw:
                    continue  # Counts and metadata are checked by widget tests.
                # Dart literals here use the same escapes as Python literals.
                import ast
                key = ast.literal_eval(raw)
                with self.subTest(file=str(path.relative_to(ROOT)), key=key):
                    self.assertTrue(key in messages or key in invariant,
                                    f'Missing UI translation: {key}')

    def test_plain_text_does_not_contain_untranslated_ui_literals(self):
        pattern = re.compile(r"(?<![\w.])Text\(\s*['\"]([A-Za-z][^'\"$]*)['\"]")
        for folder in ['features', 'widgets']:
            for path in (ROOT / 'lib' / folder).rglob('*.dart'):
                self.assertEqual(pattern.findall(path.read_text()), [], str(path))


if __name__ == '__main__':
    unittest.main()
