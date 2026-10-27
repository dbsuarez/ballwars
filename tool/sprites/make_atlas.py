"""Measure sprite frames from a sheet's alpha channel and write an atlas manifest.

Read-only: it reads the sheet and writes only the JSON file.

Usage:
  python tool/sprites/make_atlas.py --sheet assets/sprites/X.png --grid 4x6 \
      --id-row 1=effect.explosion --id-row 3=effect.ice-impact [--shared-band] \
      [--cell 443.5x443.5] [--exact] [--inset 12] [--padding 2] \
      [--steps-per-frame 4] [--margin 2] \
      [--icons gem=10,20,32,32 ...] [--output 96] [--max-shift 100] \
      [--force] --out assets/sprites/X.atlas.json

--force overwrites an existing --out file; without it the tool refuses.

Rows and columns count from 0. `--id-row 0-1=anim.tornado` gives one sprite
the frames of rows 0 and 1 (row by row, left to right). The cell size is the
sheet size divided by the grid unless `--cell WxH` sets it (decimals allowed,
e.g. 443.5).

Measured (the default): each frame starts as its grid cell; every edge then
moves to the nearest fully transparent row or column (alpha <= 24), so a frame
never cuts through art, even when art spills over a cell border. An edge with
no clean row within --max-shift px stays on the grid line, the sprite gets
"bleedOk": false and a warning goes to stderr. Where the transparent gap
allows, each edge then moves up to --margin px (default 2) further out over
clean lines, without overlapping a neighbouring frame, so the frame keeps the
2 px clear border the isolation test asks for.

--exact: frames are the grid cells inset by --inset px on every side, as
given, with no measuring (to reproduce existing hand cuts).

--shared-band only sets the flag; frames keep their own rectangles. --padding
and --steps-per-frame are written into every sprite when given.
"""
import argparse
import os
import json
import re
import sys

from PIL import Image

ALPHA_CLEAR = 24


def num(value):
    """An int when the value is whole, so the JSON stays tidy."""
    return int(value) if float(value).is_integer() else value


def to_json(atlas):
    """The manifest as indented JSON with one [x, y, w, h] rect per line."""
    text = json.dumps(atlas, indent=2)
    return re.sub(r'\[\s*([-\d.e]+),\s*([-\d.e]+),\s*([-\d.e]+),\s*([-\d.e]+)\s*\]',
                  r'[\1, \2, \3, \4]', text) + '\n'


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


def is_clean(alpha, box):
    x0, y0, x1, y1 = box
    if x1 <= x0 or y1 <= y0:
        return True
    return alpha.crop(box).getextrema()[1] <= ALPHA_CLEAR


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


def add_margin(alpha, frames, missing, margin):
    """Move measured edges up to `margin` px outward over clean lines.

    frames maps (row, col) -> [x, y, w, h] (edited in place); missing maps the
    same keys to edges that found no clean line (those stay put). End edges
    (right, bottom) go first and stop at the neighbour's start; start edges
    then stop at the neighbour's (already moved) end, so frames never overlap.
    """
    if margin <= 0:
        return
    width, height = alpha.size
    raw = {k: list(v) for k, v in frames.items()}
    for (row, col), f in sorted(frames.items()):
        x, y, w, h = f
        if 'bottom' not in missing[(row, col)]:
            below = raw.get((row + 1, col))
            limit = below[1] if below else height
            while h < raw[(row, col)][3] + margin and y + h < limit and \
                    is_clean(alpha, (x, y + h, x + w, y + h + 1)):
                h += 1
        if 'right' not in missing[(row, col)]:
            beside = raw.get((row, col + 1))
            limit = beside[0] if beside else width
            while w < raw[(row, col)][2] + margin and x + w < limit and \
                    is_clean(alpha, (x + w, y, x + w + 1, y + h)):
                w += 1
        f[:] = [x, y, w, h]
    for (row, col), f in sorted(frames.items()):
        x, y, w, h = f
        if 'top' not in missing[(row, col)]:
            above = frames.get((row - 1, col))
            limit = above[1] + above[3] if above else 0
            moved = 0
            while moved < margin and y > limit and \
                    is_clean(alpha, (x, y - 1, x + w, y)):
                y, h, moved = y - 1, h + 1, moved + 1
        if 'left' not in missing[(row, col)]:
            before = frames.get((row, col - 1))
            limit = before[0] + before[2] if before else 0
            moved = 0
            while moved < margin and x > limit and \
                    is_clean(alpha, (x - 1, y, x, y + h)):
                x, w, moved = x - 1, w + 1, moved + 1
        f[:] = [x, y, w, h]


def build_atlas(sheet, cols, rows, id_rows, shared_band=False, icons=None,
                output=96, max_shift=100, cell=None, exact=False, inset=0,
                padding=None, steps_per_frame=None, margin=2):
    """Return (manifest dict, warning strings) for the sheet at path `sheet`.

    id_rows maps a grid row to a sprite id; rows sharing an id become one
    sprite with their frames in row order. cell is (width, height) or None.
    """
    with Image.open(sheet) as img:
        alpha = img.convert('RGBA').getchannel('A')
    width, height = alpha.size
    sprites, warnings = {}, []
    if cell is None:
        cw, ch = width // cols, height // rows
        if width % cols or height % rows:
            warnings.append(f'sheet {width}x{height} is not divisible by the '
                            f'{cols}x{rows} grid: {width % cols} px and '
                            f'{height % rows} px left over at the right/bottom')
    else:
        cw, ch = cell
        if cols * cw > width or rows * ch > height:
            warnings.append(f'{cols}x{rows} cells of {num(cw)}x{num(ch)} do not '
                            f'fit the {width}x{height} sheet')

    def extras(entry):
        if padding is not None:
            entry['padding'] = padding
        if steps_per_frame is not None:
            entry['stepsPerFrame'] = steps_per_frame
        return entry

    frames, missing = {}, {}
    for row in sorted(id_rows):
        for col in range(cols):
            if exact:
                frames[(row, col)] = [num(col * cw + inset), num(row * ch + inset),
                                      num(cw - 2 * inset), num(ch - 2 * inset)]
                missing[(row, col)] = []
                continue
            box = (round(col * cw), round(row * ch),
                   round((col + 1) * cw), round((row + 1) * ch))
            rect, edges = measure_frame(alpha, box, max_shift)
            frames[(row, col)], missing[(row, col)] = rect, edges
            earlier = sum(1 for r in id_rows if r < row and
                          id_rows[r] == id_rows[row])
            for edge in edges:
                warnings.append(f'{id_rows[row]} frame {earlier * cols + col + 1}'
                                f': no clean {edge} edge within {max_shift} px')
    if not exact:
        add_margin(alpha, frames, missing, margin)
    for row in sorted(id_rows):
        sprite_id = id_rows[row]
        entry = sprites.setdefault(sprite_id, extras(
            {'frames': [], 'output': output, 'fit': 'contain',
             'sharedBand': shared_band, 'bleedOk': False}))
        entry['frames'].extend(frames[(row, col)] for col in range(cols))
    for sprite_id, rect in (icons or {}).items():
        sprites[sprite_id] = extras(
            {'frames': [[num(n) for n in rect]], 'output': output,
             'fit': 'contain', 'sharedBand': False, 'bleedOk': False})
    return {'sheet': sheet, 'sprites': sprites}, warnings


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--sheet', required=True)
    p.add_argument('--grid', required=True, help='COLSxROWS, e.g. 4x6')
    p.add_argument('--cell', help='cell WIDTHxHEIGHT in px, decimals allowed')
    p.add_argument('--id-row', action='append', default=[],
                   metavar='ROW[-ROW]=ID')
    p.add_argument('--exact', action='store_true',
                   help='use the grid cells (inset by --inset) without measuring')
    p.add_argument('--inset', type=float, default=0)
    p.add_argument('--shared-band', action='store_true')
    p.add_argument('--icons', nargs='*', default=[], metavar='ID=x,y,w,h')
    p.add_argument('--output', type=int, default=96)
    p.add_argument('--padding', type=int)
    p.add_argument('--steps-per-frame', type=int)
    p.add_argument('--margin', type=int, default=2)
    p.add_argument('--max-shift', type=int, default=100)
    p.add_argument('--out', required=True)
    p.add_argument('--force', action='store_true',
                   help='overwrite --out when it already exists')
    return p.parse_args(argv)


def main(argv=None):
    a = parse_args(sys.argv[1:] if argv is None else argv)
    if os.path.exists(a.out) and not a.force:
        print(f'error: {a.out} already exists; pass --force to overwrite it',
              file=sys.stderr)
        return 1
    cols, rows = (int(n) for n in a.grid.lower().split('x'))
    cell = None
    if a.cell:
        cell = tuple(num(float(n)) for n in a.cell.lower().split('x'))
    id_rows = {}
    for item in a.id_row:
        span, sprite_id = item.split('=', 1)
        first, _, last = span.partition('-')
        for row in range(int(first), int(last or first) + 1):
            id_rows[row] = sprite_id
    icons = {}
    for item in a.icons:
        sprite_id, rect = item.split('=', 1)
        icons[sprite_id] = [num(float(n)) for n in rect.split(',')]
    atlas, warnings = build_atlas(
        a.sheet, cols, rows, id_rows, a.shared_band, icons, a.output,
        a.max_shift, cell=cell, exact=a.exact, inset=num(a.inset),
        padding=a.padding, steps_per_frame=a.steps_per_frame, margin=a.margin)
    for w in warnings:
        print('warning:', w, file=sys.stderr)
    with open(a.out, 'w', encoding='utf-8') as f:
        f.write(to_json(atlas))
    return 0


if __name__ == '__main__':
    sys.exit(main())
