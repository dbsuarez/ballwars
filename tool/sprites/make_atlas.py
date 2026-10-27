"""Measure sprite frames from a sheet's alpha channel and write an atlas manifest.

Read-only: it reads the sheet and writes only the JSON file.

Usage:
  python tool/sprites/make_atlas.py --sheet assets/sprites/X.png --grid 4x6 \
      --id-row 1=effect.explosion --id-row 3=effect.ice-impact [--shared-band] \
      [--icons gem=10,20,32,32 ...] [--output 96] [--max-shift 100] \
      --out assets/sprites/X.atlas.json

Rows and columns count from 0. Each frame starts as its grid cell; every edge
then moves to the nearest fully transparent row or column (alpha <= 24), so a
frame never cuts through art, even when art spills over a cell border. An edge
with no clean row within --max-shift px stays on the grid line, the sprite gets
"bleedOk": false and a warning goes to stderr. --shared-band only sets the
flag; frames keep their own measured rectangles. Frames end at the nearest
clean separator row/column, so they can include a few px of transparent margin
(they are not tight to the art).
"""
import argparse
import json
import sys

from PIL import Image

ALPHA_CLEAR = 24


def clean_lines(alpha, box, vertical):
    """Booleans per row (or per column when vertical) of box: no alpha above the limit."""
    x0, y0, x1, y1 = box
    out = []
    if vertical:
        for x in range(x0, x1):
            out.append(alpha.crop((x, y0, x + 1, y1)).getextrema()[1] <= ALPHA_CLEAR)
    else:
        for y in range(y0, y1):
            out.append(alpha.crop((x0, y, x1, y + 1)).getextrema()[1] <= ALPHA_CLEAR)
    return out


def nearest_edge(clean, offset, start, is_start, max_shift):
    """Nearest valid edge position to start, or None.

    clean[i] describes line offset+i. A start edge p is valid when line p-1 is
    clean (or p is the sheet border); an end edge q when line q is clean.
    """
    size = len(clean)

    def valid(p):
        if p < offset or p > offset + size:
            return False
        if is_start:
            return p == offset or clean[p - 1 - offset]
        return p == offset + size or clean[p - offset]

    for d in range(max_shift + 1):
        for p in (start - d, start + d):
            if valid(p):
                return p
    return None


def measure_frame(alpha, cell, max_shift):
    """Return ((x, y, w, h), [names of edges with no clean line])."""
    x0, y0, x1, y1 = cell
    width, height = alpha.size
    lines_y = clean_lines(alpha, (x0, 0, x1, height), False)
    missing = []
    edges = {}
    for name, start, is_start in (('top', y0, True), ('bottom', y1, False)):
        p = nearest_edge(lines_y, 0, start, is_start, max_shift)
        if p is None:
            missing.append(name)
            p = start
        edges[name] = p
    lines_x = clean_lines(alpha, (0, edges['top'], width, edges['bottom']), True)
    for name, start, is_start in (('left', x0, True), ('right', x1, False)):
        p = nearest_edge(lines_x, 0, start, is_start, max_shift)
        if p is None:
            missing.append(name)
            p = start
        edges[name] = p
    rect = [edges['left'], edges['top'],
            edges['right'] - edges['left'], edges['bottom'] - edges['top']]
    return rect, missing


def build_atlas(sheet, cols, rows, id_rows, shared_band=False, icons=None,
                output=96, max_shift=100):
    """Return (manifest dict, warning strings) for the sheet at path `sheet`."""
    with Image.open(sheet) as img:
        alpha = img.convert('RGBA').getchannel('A')
    width, height = alpha.size
    sprites, warnings = {}, []
    cw, ch = width // cols, height // rows
    if width % cols or height % rows:
        warnings.append(f'sheet {width}x{height} is not divisible by the '
                        f'{cols}x{rows} grid: {width % cols} px and '
                        f'{height % rows} px left over at the right/bottom')
    for row, sprite_id in sorted(id_rows.items()):
        frames = []
        for col in range(cols):
            cell = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
            rect, missing = measure_frame(alpha, cell, max_shift)
            frames.append(rect)
            for edge in missing:
                warnings.append(f'{sprite_id} frame {col + 1}: no clean {edge} '
                                f'edge within {max_shift} px')
        sprites[sprite_id] = {'frames': frames, 'output': output,
                              'fit': 'contain', 'sharedBand': shared_band,
                              'bleedOk': False}
    for sprite_id, rect in (icons or {}).items():
        sprites[sprite_id] = {'frames': [list(rect)], 'output': output,
                              'fit': 'contain', 'sharedBand': False,
                              'bleedOk': False}
    return {'sheet': sheet, 'sprites': sprites}, warnings


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--sheet', required=True)
    p.add_argument('--grid', required=True, help='COLSxROWS, e.g. 4x6')
    p.add_argument('--id-row', action='append', default=[], metavar='ROW=ID')
    p.add_argument('--shared-band', action='store_true')
    p.add_argument('--icons', nargs='*', default=[], metavar='ID=x,y,w,h')
    p.add_argument('--output', type=int, default=96)
    p.add_argument('--max-shift', type=int, default=100)
    p.add_argument('--out', required=True)
    return p.parse_args(argv)


def main(argv=None):
    a = parse_args(sys.argv[1:] if argv is None else argv)
    cols, rows = (int(n) for n in a.grid.lower().split('x'))
    id_rows = {}
    for item in a.id_row:
        row, sprite_id = item.split('=', 1)
        id_rows[int(row)] = sprite_id
    icons = {}
    for item in a.icons:
        sprite_id, rect = item.split('=', 1)
        icons[sprite_id] = [int(n) for n in rect.split(',')]
    atlas, warnings = build_atlas(a.sheet, cols, rows, id_rows, a.shared_band,
                                  icons, a.output, a.max_shift)
    for w in warnings:
        print('warning:', w, file=sys.stderr)
    with open(a.out, 'w', encoding='utf-8') as f:
        json.dump(atlas, f, indent=2)
        f.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
