#!/usr/bin/env python3
# Нарезка листа значков: тайлы на белом фоне -> PNG 128x128 с прозрачными скруглёнными углами.
# python3 -I tools/cut_icon_sheet.py (нужны numpy, Pillow, scipy) <лист.png> <папка> id1,id2,...   (порядок: слева направо, сверху вниз;
# «_» — пропустить тайл: ChatGPT иногда рисует дубли или лишние)
import sys, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
src, out, ids = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
im = Image.open(src).convert('RGB'); a = np.asarray(im).astype(int)
mask = (a.min(axis=2) < 225)  # не белое
mask = ndimage.binary_closing(mask, iterations=3)
mask = ndimage.binary_fill_holes(mask)
lab, n = ndimage.label(mask)
boxes = []
for sl in ndimage.find_objects(lab):
    h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
    if h > 80 and w > 80:
        boxes.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop))
# строки по y, внутри — по x
boxes.sort(key=lambda b: b[0])
rows = []
for b in boxes:
    if rows and abs(rows[-1][0][0] - b[0]) < 60: rows[-1].append(b)
    else: rows.append([b])
order = [b for r in rows for b in sorted(r, key=lambda b: b[1])]
print('найдено тайлов', len(order), 'нужно', len(ids), 'размеры', sorted({(b[2]-b[0], b[3]-b[1]) for b in order})[:4])
assert len(order) == len(ids), 'число тайлов не совпало'
import os; os.makedirs(out, exist_ok=True)
for (y0, x0, y1, x1), i in zip(order, ids):
    if i == '_':
        continue
    s = max(y1 - y0, x1 - x0); cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    tile = im.crop((cx - s // 2, cy - s // 2, cx - s // 2 + s, cy - s // 2 + s)).resize((128, 128), Image.LANCZOS).convert('RGBA')
    m = Image.new('L', (128 * 4, 128 * 4), 0); ImageDraw.Draw(m).rounded_rectangle((2, 2, 128 * 4 - 3, 128 * 4 - 3), radius=56, fill=255)
    tile.putalpha(m.resize((128, 128), Image.LANCZOS)); tile.save(os.path.join(out, i + '.png'), optimize=True)
print('ok')
