import importlib.util
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build', ROOT / 'tools/build.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PlaceBuildTests(unittest.TestCase):
    def test_reproducible_scene_and_current_sources(self):
        path = builder.build()
        first = path.read_bytes()
        self.assertEqual(first, builder.build().read_bytes())
        root = ET.fromstring(first)
        objects = root.findall('.//Item')
        refs = [obj.get('referent') for obj in objects]
        self.assertEqual(len(refs), len(set(refs)))
        names = [obj.findtext('Properties/string[@name="Name"]') for obj in objects]
        self.assertIn('ShoreArt', names)
        self.assertIn('WelcomeSpawn', names)
        self.assertIn('RecyclerSample', names)
        for name, expected_class in [('Domain', 'ModuleScript'),
                                     ('SceneRenderer', 'ModuleScript'),
                                     ('Balance', 'ModuleScript')]:
            obj = next(obj for obj in objects
                       if obj.findtext('Properties/string[@name="Name"]') == name)
            self.assertEqual(obj.get('class'), expected_class)
        entries = [obj.get('class') for obj in objects
                   if obj.findtext('Properties/string[@name="Name"]') == 'Bootstrap']
        self.assertCountEqual(entries, ['Script', 'LocalScript'])
        sources = [obj.findtext('Properties/ProtectedString[@name="Source"]')
                   for obj in objects if obj.get('class') in
                   ('Script', 'LocalScript', 'ModuleScript')]
        self.assertEqual(len(sources), len(list((ROOT / 'src').rglob('*.luau'))))
        for path in (ROOT / 'src').rglob('*.luau'):
            self.assertIn(path.read_text(encoding='utf-8'), sources)
        config = (ROOT / 'src/shared/BuildConfig.luau').read_text(encoding='utf-8')
        self.assertIn('environment = "Test"', config)
        self.assertIn('persistenceEnabled = false', config)
        self.assertIn('monetizationEnabled = false', config)


if __name__ == '__main__':
    unittest.main()
