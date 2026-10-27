"""Tests for make_atlas.py. Run: python -m unittest tool/sprites/test_make_atlas.py"""
import json
import os
import shutil
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_atlas  # noqa: E402

CELL = 20


def paint(img, x0, y0, x1, y1):
    for y in range(y0, y1):
        for x in range(x0, x1):
            img.putpixel((x, y), (255, 0, 0, 255))


class MakeAtlasTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir, True)

    def save(self, img, name='sheet.png'):
        path = os.path.join(self.dir, name)
        img.save(path)
        return path

    def sheet_2x2(self):
        img = Image.new('RGBA', (2 * CELL, 2 * CELL), (0, 0, 0, 0))
        paint(img, 2, 2, 18, 30)  # top-left leaks 10 px into the cell below
        paint(img, 2, 33, 18, 38)  # bottom-left starts after a clean row
        paint(img, 22, 2, 38, 18)
        paint(img, 22, 22, 38, 38)
        return self.save(img)

    def test_edges_move_to_clean_rows(self):
        path = self.sheet_2x2()
        atlas, warnings = make_atlas.build_atlas(
            path, 2, 2, {0: 'top', 1: 'bottom'})
        top = atlas['sprites']['top']['frames'][0]
        bottom = atlas['sprites']['bottom']['frames'][0]
        self.assertEqual(top[1] + top[3], 30)  # ends at the clean row
        self.assertEqual(bottom[1], 31)  # starts after it
        self.assertGreaterEqual(bottom[1], top[1] + top[3])
        self.assertEqual(warnings, [])
        self.assertTrue(all(isinstance(n, int) for f in
                            atlas['sprites']['top']['frames'] for n in f))
        self.assertEqual(atlas['sprites']['top']['output'], 96)

    def test_no_clean_edge_warns(self):
        img = Image.new('RGBA', (2 * CELL, 2 * CELL), (0, 0, 0, 0))
        paint(img, 0, 0, 20, 40)  # solid column of art, no clean row
        path = self.save(img)
        atlas, warnings = make_atlas.build_atlas(path, 2, 2, {0: 'a'}, max_shift=5)
        self.assertFalse(atlas['sprites']['a']['bleedOk'])
        self.assertTrue(any('a' in w and 'frame 1' in w and 'bottom' in w
                            for w in warnings), warnings)

    def test_shared_band_and_output(self):
        path = self.sheet_2x2()
        atlas, _ = make_atlas.build_atlas(
            path, 2, 2, {0: 'top'}, shared_band=True, output=64)
        self.assertTrue(atlas['sprites']['top']['sharedBand'])
        self.assertEqual(atlas['sprites']['top']['output'], 64)

    def test_icons_and_cli_writes_only_json(self):
        path = self.sheet_2x2()
        out = os.path.join(self.dir, 'x.atlas.json')
        code = make_atlas.main([
            '--sheet', path, '--grid', '2x2', '--id-row', '0=top',
            '--icons', 'gem=1,2,3,4', '--out', out])
        self.assertEqual(code, 0)
        with open(out) as f:
            data = json.load(f)
        self.assertEqual(data['sheet'], path)
        self.assertEqual(data['sprites']['gem']['frames'], [[1, 2, 3, 4]])
        self.assertEqual(sorted(os.listdir(self.dir)),
                         ['sheet.png', 'x.atlas.json'])


if __name__ == '__main__':
    unittest.main()
