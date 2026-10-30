#!/usr/bin/env python3
"""Рисованные бесшовные текстуры окружения острова (аниме cel-стиль, свои, без внешних источников).

Выход: assets/textures/*.png, 512×512, RGB. Рядом лежат .png.import (VRAM-сжатие, мипмапы).

Текстуры — «детальные маски»: почти серые, среднее каждого канала ровно 0.5 (128), с лёгким оттенком
(тени чуть холоднее, светлое чуть теплее). Шейдеры умножают цвет вершин/зоны на tex * 2, поэтому
палитра острова и цвета построек в среднем не меняются, а текстура добавляет мазки, швы и пятна.
Стиль: крупные пятна и мазки, 2–4 тона, мягкие края, мало мелкого шума (на телефоне он рябит).

Бесшовность: шум строится через FFT (периодичен по построению), диаграммы Вороного считают
расстояния на торе, фигуры рисуются с повтором через край.
Детерминированно: у каждой текстуры своё фиксированное зерно, повторный запуск даёт те же байты.

| Файл        | Что                                   | Где                                        |
|-------------|---------------------------------------|--------------------------------------------|
| grass.png   | трава: пятна и пучки мазков-травинок | земля: луга                                |
| dirt.png    | утоптанная земля, камешки            | земля: дороги, площадки построек           |
| sand.png    | песок с мягкой рябью                 | земля: берег, отмели                       |
| rock.png    | скала: грани и трещины               | земля: обрывы; камни, глыбы пещеры        |
| stone.png   | бутовый камень / брусчатка           | земля: площадь и улицы города; цоколи     |
| wood.png    | доски                                 | стены-доски, ограды, причал, мосты, ящики  |
| tiles.png   | черепица чешуёй                      | крыши (кроме соломенных)                   |
| thatch.png  | солома ярусами                       | соломенные крыши, сено, манекены           |
| plaster.png | штукатурка / побелка                 | стены домов, башни                         |

Запуск из корня репозитория: python3 tools/gen_textures.py  (нужны numpy и Pillow)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 512
OUT = "assets/textures"
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}.png"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
detect_3d/compress_to=0
"""


# ---------- Основа ----------

def fft_noise(rng, size_px, aniso=(1.0, 1.0)):
	"""Бесшовный плавный шум 0..1 с пятнами размера ~size_px (aniso — растяжение по x, y)."""
	white = rng.standard_normal((N, N))
	fy = np.fft.fftfreq(N)[:, None] * N
	fx = np.fft.fftfreq(N)[None, :] * N
	# Частота (циклов на текстуру), соответствующая размеру пятна
	k = N / size_px
	r2 = (fx * aniso[0]) ** 2 + (fy * aniso[1]) ** 2
	spec = np.exp(-r2 / (2.0 * (k * 0.5) ** 2))
	spec[0, 0] = 0.0
	out = np.real(np.fft.ifft2(np.fft.fft2(white) * spec))
	lo, hi = np.percentile(out, 1), np.percentile(out, 99)
	return np.clip((out - lo) / (hi - lo), 0.0, 1.0)


def smoothstep(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def bands(x, levels, soft=0.12):
	"""Мягкая постеризация 0..1 → levels тонов с плавной (soft) ступенькой: рисованные пятна."""
	q = x * levels
	f = np.floor(q)
	t = smoothstep(0.5 - soft, 0.5 + soft, q - f)
	return np.clip((f + t - 0.5) / (levels - 1), 0.0, 1.0)


def grid():
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	return x, y


def wrap_d(a):
	"""Разность координат на торе: −N/2..N/2."""
	return (a + N * 0.5) % N - N * 0.5


def voronoi(pts, sy=1.0):
	"""Вороной на торе: индекс ближайшей точки, смещение до неё (dx, dy) и расстояние до границы
	ячейки (точное для пары ближайших). sy > 1 — ячейки шире, чем выше (слои породы)."""
	x, y = grid()
	f1 = np.full((N, N), np.inf)
	f2 = np.full((N, N), np.inf)
	i1 = np.zeros((N, N), np.int32)
	i2 = np.zeros((N, N), np.int32)
	for i, (px, py) in enumerate(pts):
		dx = wrap_d(x - px)
		dy = wrap_d(y - py) * sy
		d = dx * dx + dy * dy
		closer = d < f1
		second = (~closer) & (d < f2)
		f2 = np.where(closer, f1, np.where(second, d, f2))
		i2 = np.where(closer, i1, np.where(second, i, i2))
		f1 = np.where(closer, d, f1)
		i1 = np.where(closer, i, i1)
	p = np.asarray(pts)
	c1x, c1y = p[i1, 0], p[i1, 1]
	c2x, c2y = p[i2, 0], p[i2, 1]
	ddx = wrap_d(c2x - c1x)
	ddy = wrap_d(c2y - c1y) * sy
	dist12 = np.sqrt(ddx * ddx + ddy * ddy) + 1e-6
	border = (f2 - f1) / (2.0 * dist12)
	return i1, wrap_d(x - c1x), wrap_d(y - c1y), border


class Canvas:
	"""Рисование фигур с повтором через край, в 2× разрешении (сглаживание при уменьшении)."""
	S = 2

	def __init__(self, fill):
		self.img = Image.new("L", (N * self.S, N * self.S), int(round(fill * 255)))
		self.d = ImageDraw.Draw(self.img)

	def _shifts(self):
		for ox in (-N, 0, N):
			for oy in (-N, 0, N):
				yield ox, oy

	def poly(self, pts, tone):
		v = int(round(np.clip(tone, 0.0, 1.0) * 255))
		for ox, oy in self._shifts():
			self.d.polygon([((px + ox) * self.S, (py + oy) * self.S) for px, py in pts], fill=v)

	def ellipse(self, cx, cy, rx, ry, tone):
		v = int(round(np.clip(tone, 0.0, 1.0) * 255))
		for ox, oy in self._shifts():
			x0, y0 = (cx + ox - rx) * self.S, (cy + oy - ry) * self.S
			x1, y1 = (cx + ox + rx) * self.S, (cy + oy + ry) * self.S
			self.d.ellipse([x0, y0, x1, y1], fill=v)

	def line(self, pts, tone, width):
		v = int(round(np.clip(tone, 0.0, 1.0) * 255))
		for ox, oy in self._shifts():
			self.d.line([((px + ox) * self.S, (py + oy) * self.S) for px, py in pts], fill=v,
				width=max(1, int(round(width * self.S))), joint="curve")

	def array(self, blur=0.0):
		im = self.img
		if blur > 0.0:
			# Размытие с повтором краёв: рисуем 3×3, размываем, берём середину
			big = Image.new("L", (im.width * 3, im.height * 3))
			for i in range(3):
				for j in range(3):
					big.paste(im, (i * im.width, j * im.height))
			big = big.filter(ImageFilter.GaussianBlur(blur * self.S))
			im = big.crop((im.width, im.height, im.width * 2, im.height * 2))
		im = im.resize((N, N), Image.LANCZOS)
		return np.asarray(im, np.float64) / 255.0


def blur_wrap(a, px):
	"""Гауссово размытие бесшовно (через FFT)."""
	fy = np.fft.fftfreq(N)[:, None]
	fx = np.fft.fftfreq(N)[None, :]
	g = np.exp(-2.0 * (np.pi * px) ** 2 * (fx * fx + fy * fy))
	return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def finish(name, lum, shadow_tint, light_tint, lo=0.1, hi=0.9):
	"""Яркость → RGB с лёгким оттенком (тени/светлое), среднее каждого канала = 0.5, PNG + .import."""
	lum = np.clip(lum, 0.0, 1.0)
	t = smoothstep(0.3, 0.7, lum)[..., None]
	tint = np.asarray(shadow_tint)[None, None, :] * (1.0 - t) + np.asarray(light_tint)[None, None, :] * t
	rgb = lum[..., None] * tint
	# Среднее каждого канала — ровно 0.5 (палитра в среднем не меняется), затем ограничение
	for _ in range(4):
		rgb *= 0.5 / rgb.reshape(-1, 3).mean(axis=0)[None, None, :]
		rgb = np.clip(rgb, lo, hi)
	img = Image.fromarray(np.round(rgb * 255.0).astype(np.uint8), "RGB")
	path = os.path.join(OUT, name + ".png")
	img.save(path, optimize=True)
	with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
		f.write(IMPORT.format(name=name))
	m = np.asarray(img, np.float64).reshape(-1, 3).mean(axis=0) / 255.0
	print("%-12s среднее RGB %.3f %.3f %.3f, мин %.2f, макс %.2f, %d КБ" % (
		name + ".png", m[0], m[1], m[2], rgb.min(), rgb.max(), os.path.getsize(path) // 1024))


# ---------- Текстуры ----------

def grass():
	"""Трава (повтор ~4 м): крупные пятна трёх тонов и пучки широких мазков-травинок."""
	rng = np.random.default_rng(101)
	macro = bands(fft_noise(rng, 150), 3, 0.18)
	mid = fft_noise(rng, 40)
	base = 0.5 + (macro - 0.5) * 0.10 + (mid - 0.5) * 0.03
	cv = Canvas(0.5)
	# Пучки: тёмная «тень» под мазками, затем сами травинки светлее; тон пучка от 3 уровней
	clumps = []
	for _ in range(230):
		cx, cy = rng.uniform(0, N, 2)
		ang = rng.uniform(-np.pi, np.pi)
		tone = [0.6, 0.66, 0.72][rng.integers(0, 3)]
		clumps.append((cx, cy, ang, tone))
	for pass_dark in (True, False):
		for cx, cy, ang, tone in clumps:
			crng = np.random.default_rng(int(cx * 7919 + cy * 104729) % (2 ** 31))
			for _ in range(int(crng.integers(3, 6))):
				a = ang + crng.uniform(-0.7, 0.7)
				ln = crng.uniform(22, 40)
				wd = crng.uniform(5.0, 7.5)
				bx, by = cx + crng.uniform(-6, 6), cy + crng.uniform(-6, 6)
				dx, dy = np.cos(a), np.sin(a)
				nx, ny = -dy, dx
				bend = crng.uniform(-0.25, 0.25) * ln
				tip = (bx + dx * ln + nx * bend, by + dy * ln + ny * bend)
				mid_p = (bx + dx * ln * 0.5 + nx * bend * 0.35, by + dy * ln * 0.5 + ny * bend * 0.35)
				pts = [(bx - nx * wd * 0.5, by - ny * wd * 0.5), (mid_p[0] - nx * wd * 0.3, mid_p[1] - ny * wd * 0.3),
					tip, (mid_p[0] + nx * wd * 0.3, mid_p[1] + ny * wd * 0.3), (bx + nx * wd * 0.5, by + ny * wd * 0.5)]
				if pass_dark:
					cv.poly([(px + 2.5, py + 3.0) for px, py in pts], 0.3)
				else:
					cv.poly(pts, tone + crng.uniform(-0.03, 0.03))
	strokes = cv.array(blur=0.8)
	# Мазки ложатся поверх основы мягко (как кисть): смесь, а не замена
	lum = base + (strokes - 0.5) * 0.42
	finish("grass", lum, (0.93, 1.0, 1.08), (1.05, 1.03, 0.9))


def dirt():
	"""Утоптанная земля (повтор ~3.5 м): сухие и влажные пятна, редкие камешки с тенью."""
	rng = np.random.default_rng(202)
	macro = bands(fft_noise(rng, 110), 3, 0.2)
	mid = bands(fft_noise(rng, 30), 3, 0.25)
	lum = 0.5 + (macro - 0.5) * 0.16 + (mid - 0.5) * 0.05
	cv = Canvas(0.5)
	pebbles = []
	for _ in range(42):
		cx, cy = rng.uniform(0, N, 2)
		r = rng.uniform(4.0, 10.0)
		pebbles.append((cx, cy, r, r * rng.uniform(0.6, 0.9), rng.uniform(0.66, 0.74)))
	for cx, cy, rx, ry, tone in pebbles:
		cv.ellipse(cx + 1.5, cy + 2.5, rx, ry, 0.28)
	for cx, cy, rx, ry, tone in pebbles:
		cv.ellipse(cx, cy, rx, ry, tone)
		cv.ellipse(cx - rx * 0.3, cy - ry * 0.35, rx * 0.45, ry * 0.35, tone + 0.1)
	# Неглубокие колеи-полосы и трещинки: несколько изогнутых тёмных штрихов
	for _ in range(9):
		x, y = rng.uniform(0, N, 2)
		a = rng.uniform(-np.pi, np.pi)
		pts = [(x, y)]
		for _ in range(4):
			a += rng.uniform(-0.6, 0.6)
			x += np.cos(a) * 11
			y += np.sin(a) * 11
			pts.append((x, y))
		cv.line(pts, 0.38, 2.2)
	shapes = cv.array(blur=0.6)
	lum = lum + (shapes - 0.5)
	finish("dirt", lum, (0.97, 0.98, 1.04), (1.04, 1.0, 0.93))


def sand():
	"""Песок (повтор ~4 м): мягкая рябь от ветра, светлые гребни, редкие крапинки."""
	rng = np.random.default_rng(303)
	x, y = grid()
	warp = fft_noise(rng, 90)
	amp = smoothstep(0.25, 0.7, fft_noise(rng, 140))
	phase = 2.0 * np.pi * (y / N * 9.0 + x / N * 1.0 + warp * 1.4)
	s = np.sin(phase)
	ripple = smoothstep(0.55, 0.95, s) * 0.07 - smoothstep(0.1, -0.8, s) * 0.04
	macro = bands(fft_noise(rng, 120), 3, 0.22)
	lum = 0.52 + ripple * amp + (macro - 0.5) * 0.06
	cv = Canvas(0.5)
	for _ in range(55):
		cx, cy = rng.uniform(0, N, 2)
		r = rng.uniform(2.0, 3.2)
		cv.ellipse(cx, cy, r, r * 0.8, 0.4 if rng.random() < 0.6 else 0.62)
	lum = lum + (cv.array(blur=0.4) - 0.5) * 0.7
	finish("sand", lum, (0.98, 0.99, 1.03), (1.03, 1.0, 0.95))


def rock():
	"""Скала (повтор 3–5 м): плоские грани трёх тонов с наклоном, тёмные трещины по границам,
	светлая кромка над трещиной; ячейки шире, чем выше — на обрывах читаются слои породы."""
	rng = np.random.default_rng(404)
	pts = rng.uniform(0, N, (34, 2))
	i1, dx, dy, border = voronoi(pts, sy=1.7)
	tone = np.asarray([0.42, 0.52, 0.6])[rng.integers(0, 3, len(pts))]
	# Наклон грани: линейный градиент по ячейке (свет сверху-слева)
	gx = rng.uniform(-0.0012, 0.0006, len(pts))
	gy = rng.uniform(-0.0016, -0.0002, len(pts))
	lum = tone[i1] + gx[i1] * dx + gy[i1] * dy
	# Мелкие сколы: вторая сетка ячеек, видна только местами
	pts2 = rng.uniform(0, N, (110, 2))
	_, _, _, b2 = voronoi(pts2, sy=1.3)
	where = smoothstep(0.5, 0.7, fft_noise(rng, 120))
	lum -= (1.0 - smoothstep(0.6, 1.6, b2)) * 0.12 * where
	# Внутренняя тень у трещины и сама трещина
	lum -= (1.0 - smoothstep(1.5, 7.0, border)) * 0.08
	lum = lum * smoothstep(0.8, 2.2, border) + 0.2 * (1.0 - smoothstep(0.8, 2.2, border))
	# Светлая кромка: граница выше точки (край грани под светом)
	lit = (1.0 - smoothstep(2.2, 4.5, border)) * smoothstep(1.4, 2.4, border) * (dy < 0)
	lum += lit * 0.08
	lum += (fft_noise(rng, 70) - 0.5) * 0.05
	finish("rock", lum, (0.95, 0.98, 1.07), (1.03, 1.01, 0.96))


def stone():
	"""Бутовый камень / брусчатка (повтор ~3 м): скруглённые камни разного тона, тёмные швы,
	светлая фаска сверху-слева и тень снизу-справа у каждого камня."""
	rng = np.random.default_rng(505)
	n = 8
	pts = []
	for i in range(n):
		for j in range(n):
			# Ряды со сдвигом (как кладка), с разбросом
			ox = (0.5 if i % 2 else 0.0)
			pts.append(((j + ox + rng.uniform(-0.3, 0.3)) * N / n, (i + 0.5 + rng.uniform(-0.25, 0.25)) * N / n))
	pts = np.asarray(pts) % N
	i1, dx, dy, border = voronoi(pts)
	tone = rng.uniform(0.5, 0.64, len(pts))
	lum = tone[i1] + (fft_noise(rng, 26) - 0.5) * 0.05
	ln = np.sqrt(dx * dx + dy * dy) + 1e-6
	bevel = 1.0 - smoothstep(3.5, 13.0, border)
	# dx, dy — от центра камня к пикселю; свет сверху-слева
	lum += (-(dx + dy) / ln * 0.7071) * bevel * 0.09
	mortar = 1.0 - smoothstep(2.5, 4.2, border)
	mortar_tone = 0.26 + (fft_noise(rng, 50) - 0.5) * 0.06
	lum = lum * (1.0 - mortar) + mortar_tone * mortar
	finish("stone", lum, (0.96, 0.98, 1.05), (1.03, 1.01, 0.96))


def wood():
	"""Доски (повтор ~2 м): 8 горизонтальных досок, стыки со сдвигом, волокна вдоль доски,
	тёмные щели, светлая кромка сверху, редкие сучки."""
	rng = np.random.default_rng(606)
	x, y = grid()
	rows = 8
	h = N / rows
	row = np.floor(y / h).astype(np.int32)
	ly = y - row * h
	lum = np.zeros((N, N))
	seam = np.zeros((N, N))
	grain = fft_noise(rng, 30, aniso=(6.0, 0.35))
	grain = bands(grain, 4, 0.2)
	streak = fft_noise(rng, 12, aniso=(10.0, 0.25))
	for r in range(rows):
		m = row == r
		joints = np.sort(rng.uniform(0, N, int(rng.integers(1, 3))))
		# Номер доски в ряду по стыкам (с повтором через край)
		seg = np.searchsorted(joints, x[m]) % len(joints)
		tones = rng.uniform(0.47, 0.6, len(joints))
		lum[m] = tones[seg]
		dj = np.min(np.abs(wrap_d(x[m][:, None] - joints[None, :])), axis=1)
		seam[m] = 1.0 - smoothstep(0.8, 2.2, dj)
		# Сучок на части досок
		for jx in joints:
			if rng.random() < 0.7:
				kx = (jx + rng.uniform(40, 200)) % N
				ky = r * h + rng.uniform(0.3, 0.7) * h
				ddx = wrap_d(x - kx) / rng.uniform(6.0, 9.0)
				ddy = wrap_d(y - ky) / rng.uniform(3.5, 5.0)
				d = np.sqrt(ddx * ddx + ddy * ddy)
				lum -= (1.0 - smoothstep(0.7, 1.0, d)) * 0.16
				lum += (smoothstep(0.9, 1.2, d) * (1.0 - smoothstep(1.4, 2.0, d))) * 0.04
	lum += (grain - 0.5) * 0.09 + (streak - 0.5) * 0.03
	# Светлая кромка сверху доски, тень снизу, щель между рядами
	lum += (1.0 - smoothstep(1.5, 5.0, ly)) * 0.06
	lum -= smoothstep(h - 7.0, h - 2.0, ly) * 0.07
	gap = np.maximum(1.0 - smoothstep(0.6, 2.0, ly), smoothstep(h - 1.4, h - 0.2, ly))
	gap = np.maximum(gap, seam)
	lum = lum * (1.0 - gap) + 0.22 * gap
	finish("wood", lum, (0.97, 0.98, 1.03), (1.04, 1.0, 0.95))


def tiles():
	"""Черепица чешуёй (повтор ~2 м): 8 рядов по 8 черепиц, ряды со сдвигом на половину.
	Нижний ряд лежит под верхним: нижний край черепицы — дуга, под ней тень; черепица
	выпуклая (светлее посередине), каждая своего тона. Низ текстуры (v растёт) — к карнизу."""
	rng = np.random.default_rng(707)
	x, y = grid()
	rows, cols = 8, 8
	h, w = N / rows, N / cols
	depth = h * 0.42
	tone = rng.uniform(0.47, 0.6, (rows, cols))

	def tile_at(r):
		off = (r % 2) * w * 0.5
		c = np.floor(((x + off) % N) / w).astype(np.int32)
		lx = ((x + off) % N) - (c + 0.5) * w
		return c, lx

	row = np.floor(y / h).astype(np.int32)
	ly = y - row * h
	# Черепица верхнего ряда (row − 1) свисает дугой в текущий ряд
	up = (row - 1) % rows
	cu, lxu = tile_at(up)
	hang = depth * np.sqrt(np.clip(1.0 - (lxu / (w * 0.5)) ** 2, 0.0, 1.0))
	covered = ly < hang
	cr, lxr = tile_at(row)
	own_r = np.where(covered, up, row)
	own_c = np.where(covered, cu, cr)
	own_lx = np.where(covered, lxu, lxr)
	# Высота внутри своей черепицы: 0 — верх (под верхним рядом), 1 — нижняя дуга
	vy = np.where(covered, (ly + h) / (h + depth), ly / (h + depth))
	lum = tone[own_r, own_c]
	# Выпуклость: светлее посередине, темнее к бокам
	lum += (0.5 - np.abs(own_lx) / w) * 0.12 - 0.03
	# Свет к нижнему краю, тень у верха (верхний ряд отбрасывает тень)
	lum += smoothstep(0.1, 0.9, vy) * 0.08 - 0.04
	# Тень под дугой верхней черепицы и тёмная кромка дуги
	below = ly - hang
	shade = (~covered) * (1.0 - smoothstep(0.0, 9.0, below))
	lum -= shade * 0.17
	edge = 1.0 - smoothstep(0.6, 2.2, np.abs(below))
	lum = lum * (1.0 - edge * 0.85) + 0.22 * edge * 0.85
	# Швы между черепицами в ряду
	sx = np.abs(np.abs(own_lx) - w * 0.5)
	lum -= (1.0 - smoothstep(0.6, 2.0, sx)) * 0.14
	lum += (fft_noise(rng, 40) - 0.5) * 0.04
	finish("tiles", lum, (0.97, 0.97, 1.04), (1.04, 1.0, 0.95))


def thatch():
	"""Солома (повтор ~2 м): 5 ярусов, в каждом — широкие мазки-пучки вниз по скату с наклоном,
	нижний край яруса неровный, под ним тень на следующий ярус."""
	rng = np.random.default_rng(808)
	tiers = 5
	h = N / tiers
	cv = Canvas(0.36)
	for t in range(tiers):
		top = t * h
		for _ in range(105):
			x0 = rng.uniform(0, N)
			y0 = top + rng.uniform(-h * 0.08, h * 0.14)
			ln = rng.uniform(0.85, 1.15) * h
			a = np.pi * 0.5 + rng.uniform(-0.14, 0.14)
			wd = rng.uniform(7.0, 11.0)
			x1, y1 = x0 + np.cos(a) * ln, y0 + np.sin(a) * ln
			tone = [0.52, 0.6, 0.68][rng.integers(0, 3)] + rng.uniform(-0.03, 0.03)
			nx, ny = -np.sin(a), np.cos(a)
			pts = [(x0 - nx * wd * 0.5, y0 - ny * wd * 0.5), (x0 + nx * wd * 0.5, y0 + ny * wd * 0.5),
				(x1 + nx * wd * 0.2, y1 + ny * wd * 0.2), (x1 - nx * wd * 0.2, y1 - ny * wd * 0.2)]
			cv.poly([(px + 1.0, py + 2.5) for px, py in pts], 0.3)
			cv.poly(pts, tone)
	strokes = cv.array(blur=0.9)
	x, y = grid()
	ly = y % h
	# Верх яруса темнее (под нависшим верхним ярусом)
	lum = strokes - (1.0 - smoothstep(0.0, h * 0.35, ly)) * 0.1
	lum += (fft_noise(rng, 90) - 0.5) * 0.05
	finish("thatch", lum, (0.97, 0.97, 1.03), (1.04, 1.01, 0.93))


def plaster():
	"""Штукатурка / побелка (повтор ~3 м): почти ровная, крупные пятна двух тонов, широкие
	мазки кисти, редкие сколы с тёмной кладкой под ними. Контраст низкий: стены светлые."""
	rng = np.random.default_rng(909)
	macro = bands(fft_noise(rng, 170), 2, 0.25)
	lum = 0.54 + (macro - 0.5) * 0.05
	cv = Canvas(0.5)
	for _ in range(70):
		x0, y0 = rng.uniform(0, N, 2)
		a = rng.uniform(-0.35, 0.35)
		ln = rng.uniform(50, 120)
		pts = [(x0, y0), (x0 + np.cos(a) * ln * 0.5, y0 + np.sin(a) * ln * 0.5 + rng.uniform(-6, 6)),
			(x0 + np.cos(a) * ln, y0 + np.sin(a) * ln)]
		cv.line(pts, 0.5 + rng.choice([-1, 1]) * rng.uniform(0.04, 0.07), rng.uniform(14, 26))
	lum += (cv.array(blur=6.0) - 0.5) * 0.6
	# Пятна-потёки (чуть темнее)
	stain = smoothstep(0.68, 0.8, fft_noise(rng, 60))
	lum -= stain * 0.035
	# Сколы: неровное пятно кладки с тёмным краем и светлой кромкой штукатурки
	x, y = grid()
	# Кладка под сколом: кирпичи 32×16 со сдвигом рядов, тёмные швы
	brow = np.floor(y / 16.0)
	bx = (x + (brow % 2) * 16.0) % 32.0
	by = y % 16.0
	joint = np.maximum(1.0 - smoothstep(1.0, 2.5, by), 1.0 - smoothstep(1.0, 2.5, bx))
	bricks = 0.42 + (fft_noise(rng, 20) - 0.5) * 0.06
	bricks = bricks * (1.0 - joint) + 0.3 * joint
	for _ in range(3):
		cx, cy = rng.uniform(0, N, 2)
		rx, ry = rng.uniform(30, 44), rng.uniform(18, 26)
		wob = fft_noise(rng, 26)
		d = np.sqrt((wrap_d(x - cx) / rx) ** 2 + (wrap_d(y - cy) / ry) ** 2) + (wob - 0.5) * 0.7
		inside = 1.0 - smoothstep(0.9, 0.98, d)
		rim = smoothstep(0.95, 1.0, d) * (1.0 - smoothstep(1.04, 1.16, d))
		lum = lum * (1.0 - inside) + bricks * inside + rim * 0.04
	finish("plaster", lum, (0.97, 0.98, 1.04), (1.03, 1.01, 0.97), lo=0.2, hi=0.75)


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	for f in (grass, dirt, sand, rock, stone, wood, tiles, thatch, plaster):
		f()


if __name__ == "__main__":
	main()
