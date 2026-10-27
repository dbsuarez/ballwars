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
            path, 2, 2, {0: 'top', 1: 'bottom'}, margin=0)
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
        self.assertIn('a frame 1: no clean bottom edge within 5 px', warnings)

    def test_uneven_grid_warns(self):
        path = self.save(Image.new('RGBA', (41, 40), (0, 0, 0, 0)))
        _, warnings = make_atlas.build_atlas(path, 2, 2, {0: 'a'})
        self.assertTrue(any('not divisible' in w and '1 px' in w
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
        with open(out) as f:
            self.assertIn('[1, 2, 3, 4]', f.read())  # one rect per line
        self.assertEqual(sorted(os.listdir(self.dir)),
                         ['sheet.png', 'x.atlas.json'])

    def test_refuses_to_overwrite_without_force(self):
        path = self.sheet_2x2()
        out = os.path.join(self.dir, 'x.atlas.json')
        with open(out, 'w') as f:
            f.write('keep')
        args = ['--sheet', path, '--grid', '2x2', '--id-row', '0=top',
                '--out', out]
        self.assertNotEqual(make_atlas.main(args), 0)
        with open(out) as f:
            self.assertEqual(f.read(), 'keep')
        self.assertEqual(make_atlas.main(args + ['--force']), 0)
        with open(out) as f:
            self.assertIn('top', f.read())

    def border_clean(self, path, rect, border=2):
        with Image.open(path) as img:
            alpha = img.getchannel('A')
        x, y, w, h = rect
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                inner = (x + border <= xx < x + w - border and
                         y + border <= yy < y + h - border)
                if not inner and alpha.getpixel((xx, yy)) > 24:
                    return False
        return True

    def test_margin_keeps_a_clear_border_when_the_gap_allows(self):
        img = Image.new('RGBA', (2 * CELL, 2 * CELL), (0, 0, 0, 0))
        paint(img, 3, 3, 17, 20)  # touches the cell's bottom line
        paint(img, 23, 5, 37, 15)
        path = self.save(img)
        tight, _ = make_atlas.build_atlas(path, 2, 2, {0: 'a'}, margin=0)
        self.assertFalse(self.border_clean(path, tight['sprites']['a']['frames'][0]))
        atlas, _ = make_atlas.build_atlas(path, 2, 2, {0: 'a'})
        frames = atlas['sprites']['a']['frames']
        self.assertEqual(frames[0][1] + frames[0][3], 22)  # clean row 20, then 2 px
        for f in frames:
            self.assertTrue(self.border_clean(path, f), f)
        self.assertLessEqual(frames[0][0] + frames[0][2], frames[1][0])

    def test_margin_never_overlaps_a_neighbour(self):
        path = self.sheet_2x2()  # one clean row (30) between the two left frames
        atlas, _ = make_atlas.build_atlas(path, 2, 2, {0: 'top', 1: 'bottom'})
        top = atlas['sprites']['top']['frames'][0]
        bottom = atlas['sprites']['bottom']['frames'][0]
        self.assertLessEqual(top[1] + top[3], bottom[1])
        self.assertEqual(top[1] + top[3], 31)
        for sprite in ('top', 'bottom'):
            fs = atlas['sprites'][sprite]['frames']
            self.assertLessEqual(fs[0][0] + fs[0][2], fs[1][0])

    def test_exact_cells_with_decimal_size_inset_padding_and_timing(self):
        path = self.save(Image.new('RGBA', (41, 20), (0, 0, 0, 0)))
        out = os.path.join(self.dir, 'x.atlas.json')
        make_atlas.main([
            '--sheet', path, '--grid', '2x1', '--cell', '20.5x20',
            '--exact', '--inset', '2', '--id-row', '0=a', '--padding', '3',
            '--steps-per-frame', '2', '--icons', 'b=20.5,0,20.5,20',
            '--out', out])
        with open(out) as f:
            a = json.load(f)['sprites']
        self.assertEqual(a['a']['frames'], [[2, 2, 16.5, 16], [22.5, 2, 16.5, 16]])
        self.assertEqual(a['a']['padding'], 3)
        self.assertEqual(a['a']['stepsPerFrame'], 2)
        self.assertEqual(a['b']['frames'], [[20.5, 0, 20.5, 20]])
        self.assertEqual(a['b']['padding'], 3)

    def test_row_range_makes_one_sprite_and_no_padding_by_default(self):
        path = self.sheet_2x2()
        out = os.path.join(self.dir, 'x.atlas.json')
        make_atlas.main(['--sheet', path, '--grid', '2x2', '--exact',
                         '--id-row', '0-1=all', '--out', out])
        with open(out) as f:
            s = json.load(f)['sprites']
        self.assertEqual(list(s), ['all'])
        self.assertEqual(s['all']['frames'], [[0, 0, 20, 20], [20, 0, 20, 20],
                                              [0, 20, 20, 20], [20, 20, 20, 20]])
        self.assertNotIn('padding', s['all'])
        self.assertNotIn('stepsPerFrame', s['all'])


if __name__ == '__main__':
    unittest.main()
