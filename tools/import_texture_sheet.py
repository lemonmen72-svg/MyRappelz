#!/usr/bin/env python3
"""Текстуры локации из листа картинок (например, сгенерированного по промту в ChatGPT): нарезка, бесшовность,
приведение к «детальной маске» (как у tools/gen_textures.py) и запись в assets/textures/<имя>.png 512×512.

Лист: прямоугольные плитки текстур на белом фоне (или разделённые белыми линиями), порядок — слева направо,
сверху вниз. Спецификация плитки: «имя[:доля][:режим]»; «_» — пропустить плитку. Доля — взять из центра плитки
квадрат этой доли стороны (тропа без травы по краям — dirt:0.5). Режим бесшовности:
  b  — (по умолчанию) природные: копия, сдвинутая на половину (её стыки внутри), смешивается с оригиналом —
       у краёв копия, в центре оригинал;
  p  — узор с шагом (черепица, кладка, солома): по автокорреляции находится шаг узора по X и Y, плитка
       обрезается на целое число шагов, стыки сглаживаются узкой полосой; px / py — шаг только по одной оси
       (доски — py), по другой — смешивание как в b.
Маска: яркость делится на среднюю (×0.5) — почти серая «детальная маска», как у tools/gen_textures.py
(шейдеры умножают цвет зоны на tex × 2, палитра острова сохраняется); от цвета картинки остаётся четверть
(TINT) — пятна мха, цветы, сучки. Контраст слегка смягчается.

Запуск из корня репозитория (numpy, Pillow, scipy; лист — чужие данные, Python с -I):
  python3 -I tools/import_texture_sheet.py <лист.png> grass,dirt:0.5,sand,rock,stone,forest
  python3 -I tools/import_texture_sheet.py <лист.png> wood::py,tiles::p,thatch::p,plaster,masonry::p,bark::px
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SIZE = 512
# Насколько сохранить разброс относительно среднего (1 — как в картинке)
CONTRAST = 0.85
# Доля цвета картинки в маске (0 — серая)
TINT = 0.25


def tiles(im: Image.Image) -> list:
	a = np.asarray(im.convert("RGB")).astype(int)
	mask = a.min(axis=2) < 235
	mask = ndimage.binary_opening(mask, iterations=2)
	lab, _n = ndimage.label(mask)
	boxes = []
	for sl in ndimage.find_objects(lab):
		h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
		if h > 120 and w > 120:
			boxes.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop))
	boxes.sort(key=lambda b: b[0])
	rows: list = []
	for b in boxes:
		if rows and abs(rows[-1][0][0] - b[0]) < 80:
			rows[-1].append(b)
		else:
			rows.append([b])
	return [b for r in rows for b in sorted(r, key=lambda b: b[1])]


def _blend_weight(n: int, axis_w: float) -> np.ndarray:
	"""Вес оригинала по одной оси: 0 у краёв, 1 в середине (переход шириной axis_w доли стороны)."""
	x = np.arange(n) + 0.5
	d = np.minimum(x, n - x) / (n * 0.5)
	w = np.clip((d - 0.04) / axis_w, 0.0, 1.0)
	return w * w * (3 - 2 * w)


def seamless(t: np.ndarray, wide_x: bool = True, wide_y: bool = True) -> np.ndarray:
	"""Сдвинутая на половину копия у краёв, оригинал в центре; узкий переход по оси с целым числом шагов узора."""
	n = t.shape[0]
	shifted = np.roll(np.roll(t, n // 2, axis=0), n // 2, axis=1)
	wx = _blend_weight(n, 0.45 if wide_x else 0.06)
	wy = _blend_weight(n, 0.45 if wide_y else 0.06)
	w = np.minimum(wy[:, None], wx[None, :])
	return t * w[..., None] + shifted * (1.0 - w[..., None])


def period(g: np.ndarray, axis: int) -> int:
	"""Шаг узора по оси (пиксели): самый сильный пик автокорреляции яркости; 0 — шага нет."""
	prof = g - g.mean()
	n = g.shape[axis]
	f = np.fft.rfft(prof, axis=axis)
	ac = np.fft.irfft(f * np.conj(f), n=n, axis=axis)
	ac = ac.mean(axis=1 - axis)
	ac = ac / max(ac[0], 1e-9)
	# Самый сильный пик среди шагов от 1/10 до 1/2 стороны (мелкие пики — штрихи внутри узора)
	lo, hi = max(4, n // 10), n // 2
	best, best_v = 0, 0.1
	for k in range(lo, hi):
		if ac[k] > ac[k - 1] and ac[k] >= ac[k + 1] and ac[k] > best_v:
			best, best_v = k, float(ac[k])
	return best


def to_mask(t: np.ndarray) -> np.ndarray:
	lum = t @ np.array([0.299, 0.587, 0.114])
	grey = 0.5 * lum / max(lum.mean(), 1e-3)
	col = 0.5 * t / np.maximum(t.reshape(-1, 3).mean(axis=0), 1e-3)
	m = grey[..., None] * (1.0 - TINT) + col * TINT
	return np.clip(0.5 + (m - 0.5) * CONTRAST, 0.0, 1.0)


def main() -> None:
	src, names = sys.argv[1], sys.argv[2].split(",")
	im = Image.open(src).convert("RGB")
	bx = tiles(im)
	print("плиток", len(bx), "имён", len(names), [(b[3] - b[1], b[2] - b[0]) for b in bx])
	assert len(bx) == len(names), "число плиток не совпало"
	os.makedirs("assets/textures", exist_ok=True)
	for (y0, x0, y1, x1), spec in zip(bx, names):
		if spec == "_":
			continue
		name, _, frac = spec.partition(":")
		# Без краёв плитки (рамки, белые поля) — 3 % с каждой стороны
		pad = int(min(y1 - y0, x1 - x0) * 0.03)
		y0, x0, y1, x1 = y0 + pad, x0 + pad, y1 - pad, x1 - pad
		mode = "b"
		if ":" in frac:
			frac, _, mode = frac.partition(":")
		f = float(frac) if frac else 1.0
		s = int(min(y1 - y0, x1 - x0) * f)
		cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
		box = [cx - s // 2, cy - s // 2, cx - s // 2 + s, cy - s // 2 + s]
		rx = mode in ("p", "px")
		ry = mode in ("p", "py")
		if rx or ry:
			# Целое число шагов узора: берём всю плитку по оси и обрезаем до кратного шагу
			g = np.asarray(im.crop((x0, y0, x1, y1)).convert("L")).astype(np.float64)
			if rx:
				px = period(g, 1)
				if px > 0:
					wdt = (x1 - x0) // px * px
					box[0], box[2] = cx - wdt // 2, cx - wdt // 2 + wdt
			if ry:
				py = period(g, 0)
				if py > 0:
					hgt = (y1 - y0) // py * py
					box[1], box[3] = cy - hgt // 2, cy - hgt // 2 + hgt
			print("  шаг узора", name, "x", period(g, 1) if rx else "-", "y", period(g, 0) if ry else "-")
		crop = im.crop(tuple(box)).resize((SIZE, SIZE), Image.LANCZOS)
		t = np.asarray(crop).astype(np.float64) / 255.0
		t = to_mask(seamless(t, not rx, not ry))
		Image.fromarray((t * 255.0 + 0.5).astype(np.uint8)).save("assets/textures/%s.png" % name, optimize=True)
		print("записано", name)


if __name__ == "__main__":
	main()
