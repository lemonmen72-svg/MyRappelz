#!/usr/bin/env python3
"""Готовит данные острова из референсной картинки и конфига.

Вход:  reference/training_island.png, world/training_island.json
Выход (в world/):
  training_island_land.png     — суша (белое) / океан (чёрное), без разрезов реки
  training_island_coast.png    — расстояние до берега со знаком: 128 + метры * scale
                                 (больше 128 — суша, меньше — море), для просмотра
  training_island_coast.bin    — то же сырыми байтами W×H, его читает island_world.gd
  training_island_overlay.png  — сверка: конфиг (дороги, река, зоны, точки) поверх референса

Вода по цвету: синий канал заметно больше красного и не меньше зелёного. Океан — вода,
связанная с краем картинки. Русло реки из конфига заранее помечается сушей, поэтому река,
впадающая в море, не разрезает остров (саму реку прорезает в рельефе игра по конфигу).
Запуск из корня репозитория: python3 tools/extract_island_masks.py  (нужен Pillow)
"""
import json
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

CFG = "world/training_island.json"


def is_water(r: int, g: int, b: int) -> bool:
	return b > r + 18 and b >= g + 4


def main() -> None:
	cfg = json.load(open(CFG, encoding="utf-8"))
	ref = cfg["reference"]
	src = ref["image"].replace("res://", "")
	W, H = ref["mask_size"]
	ox, oy = ref["origin_px"]
	mpp = ref["meters_per_px"]
	iw, ih = ref["image_size"]
	k = W / iw  # пиксели маски на пиксель референса
	cell_m = mpp / k  # метров в пикселе маски
	scale = ref["coast_distance_scale"]

	def to_mask(p):
		return ((p[0] / mpp + ox) * k, (p[1] / mpp + oy) * k)

	def to_img(p):
		return (p[0] / mpp + ox, p[1] / mpp + oy)

	im = Image.open(src).convert("RGB")
	small = im.resize((W, H), Image.LANCZOS).filter(ImageFilter.MedianFilter(3))
	px = small.load()
	water = Image.new("L", (W, H), 0)
	wp = water.load()
	for y in range(H):
		for x in range(W):
			if is_water(*px[x, y]):
				wp[x, y] = 255
	water = water.filter(ImageFilter.MedianFilter(5))
	# Русло реки и пруды — суша для маски берега
	d = ImageDraw.Draw(water)
	river_w = int(cfg["river"]["width"] * 3.0 / cell_m)
	for br in cfg["river"]["branches"]:
		pts = [to_mask(p) for p in br]
		# концы у моря не трогаем: последние точки рек лежат в море
		d.line(pts[1:-1], fill=0, width=river_w, joint="curve")
	wp = water.load()

	ocean = [[False] * W for _ in range(H)]
	q = deque()
	for x in range(W):
		for y in (0, H - 1):
			if wp[x, y] > 127:
				ocean[y][x] = True
				q.append((x, y))
	for y in range(H):
		for x in (0, W - 1):
			if wp[x, y] > 127 and not ocean[y][x]:
				ocean[y][x] = True
				q.append((x, y))
	while q:
		x, y = q.popleft()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			nx, ny = x + dx, y + dy
			if 0 <= nx < W and 0 <= ny < H and not ocean[ny][nx] and wp[nx, ny] > 127:
				ocean[ny][nx] = True
				q.append((nx, ny))

	land = Image.new("L", (W, H), 0)
	lp = land.load()
	for y in range(H):
		for x in range(W):
			if not ocean[y][x]:
				lp[x, y] = 255
	land = land.filter(ImageFilter.MedianFilter(7))
	land.save("world/training_island_land.png")

	# Расстояние со знаком (фаска 3-4, два прохода), в пикселях маски
	lp = land.load()
	INF = 10 ** 9
	inside = [[lp[x, y] > 127 for x in range(W)] for y in range(H)]

	def chamfer(target: bool):
		"""Расстояние до ближайшей клетки, где inside == target."""
		dist = [[0 if inside[y][x] == target else INF for x in range(W)] for y in range(H)]
		for y in range(H):
			for x in range(W):
				v = dist[y][x]
				if v == 0:
					continue
				if x > 0: v = min(v, dist[y][x - 1] + 3)
				if y > 0:
					v = min(v, dist[y - 1][x] + 3)
					if x > 0: v = min(v, dist[y - 1][x - 1] + 4)
					if x < W - 1: v = min(v, dist[y - 1][x + 1] + 4)
				dist[y][x] = v
		for y in range(H - 1, -1, -1):
			for x in range(W - 1, -1, -1):
				v = dist[y][x]
				if v == 0:
					continue
				if x < W - 1: v = min(v, dist[y][x + 1] + 3)
				if y < H - 1:
					v = min(v, dist[y + 1][x] + 3)
					if x < W - 1: v = min(v, dist[y + 1][x + 1] + 4)
					if x > 0: v = min(v, dist[y + 1][x - 1] + 4)
				dist[y][x] = v
		return dist

	# расстояние до ближайшей клетки другого типа: для суши — до моря, для моря — до суши
	d_to_sea = chamfer(False)
	d_to_land = chamfer(True)
	coast = Image.new("L", (W, H), 0)
	cp = coast.load()
	for y in range(H):
		for x in range(W):
			if inside[y][x]:
				m = d_to_sea[y][x] / 3.0 * cell_m
			else:
				m = -d_to_land[y][x] / 3.0 * cell_m
			cp[x, y] = max(0, min(255, int(round(128 + m * scale))))
	coast.save("world/training_island_coast.png")
	# Для игры — сырые байты (PNG при импорте в Godot может сжаться с потерями)
	open(ref["coast_distance"].replace("res://", ""), "wb").write(coast.tobytes())

	# Наложение конфига на референс — для сверки глазами
	ov = im.copy()
	od = ImageDraw.Draw(ov, "RGBA")
	for zone in cfg["mob_zones"]:
		c = to_img(zone["center"]); r = zone["radius"] / mpp
		od.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=(255, 60, 60, 230), width=3)
		od.text((c[0] - 30, c[1] - 8), "%s %d-%d" % (zone["id"], zone["levels"][0], zone["levels"][1]), fill=(255, 220, 220, 255))
	for sz in cfg["safe_zones"]:
		c = to_img(sz["center"]); r = sz["radius"] / mpp
		od.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=(80, 255, 120, 230), width=3)
	for br in cfg["river"]["branches"]:
		od.line([to_img(p) for p in br], fill=(40, 120, 255, 220), width=int(cfg["river"]["width"] / mpp), joint="curve")
	for name, path in cfg["roads"]["paths"].items():
		od.line([to_img(p) for p in path], fill=(255, 200, 80, 220), width=int(cfg["roads"]["width"] / mpp), joint="curve")
	for poi in cfg["pois"]:
		c = to_img(poi["center"])
		od.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=(255, 255, 255, 255), outline=(0, 0, 0, 255))
		od.text((c[0] + 9, c[1] - 6), poi["id"], fill=(255, 255, 255, 255))
	for race, p in cfg["spawn_points"].items():
		c = to_img(p)
		od.rectangle([c[0] - 6, c[1] - 6, c[0] + 6, c[1] + 6], fill=(255, 0, 255, 255))
	# береговая линия маски
	edge = land.resize((iw, ih), Image.NEAREST).filter(ImageFilter.FIND_EDGES)
	ov.paste((255, 255, 0), mask=edge.point(lambda v: 255 if v > 0 else 0))
	ov.save("world/training_island_overlay.png")
	print("ok", W, H, "cell %.2f m" % cell_m)


if __name__ == "__main__":
	main()
