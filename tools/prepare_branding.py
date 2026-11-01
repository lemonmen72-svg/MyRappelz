#!/usr/bin/env python3
"""Арты Dark Pact: логотип, иконка приложения, главный арт, арты рас и профессий, портреты персонажей.

Исходники — картинки Максима из ChatGPT по промтам tools/Промты_Dark_Pact_арты_иконка_логотип.docx, имена файлов:
  logo_dark_pact.png                       — логотип на белом фоне (фон вырезается: прозрачный PNG);
  icon_dp.png                              — иконка приложения (монограмма DP, фон из трёх рас), квадрат;
  key_art.png                              — главный арт (экраны загрузки, входа, выбора персонажа);
  race_dark_elf.png, race_light_elf.png, race_human.png — арты рас (шаг «Раса» создания персонажа);
  job_<профессия>.png                      — арты 9 профессий (вертикальные карточки профессий);
  portraits_1..4.png                       — листы портретов 3×2 на белом фоне (порядок — SHEETS).

Куда (python3 -I tools/prepare_branding.py --src <папка> [--preview <папка>]):
  в APK (их видно до загрузки пакета ресурсов) — assets/art/:
    logo_dark_pact.png  (ширина LOGO_W, фон прозрачный),
    key_art.jpg         (родной размер 1672×941, JPEG q JPG_Q);
  иконки — assets/branding/:
    icon.png (256, иконка проекта application/config/icon — окно на ПК; экспорт кладёт её в APK как есть), icon_192.png (Android launcher_icons/main_192x192),
    icon_background_432.png / icon_foreground_432.png (адаптивная иконка Android 8+: всё на фоне, передний план
    прозрачный — см. adaptive());
  в пакете ресурсов, часть «art» (Assets.PACKS) — assets/art/pack/:
    race_<раса>.jpg (RACE_W по ширине), job_<профессия>.jpg (JOB_SIZE), portraits/<профессия>_<m|f>.png и
    portraits/wanderer_<раса>_<m|f>.png (PORTRAIT × PORTRAIT, прозрачные скруглённые углы).
Сжатие в игре — импорт Godot «Lossy» (WebP, .import рядом с файлом пишет этот скрипт): JPG/PNG-исходник всё равно
перекодируется, а режим «Lossless» дал бы файлы втрое-впятеро больше; VRAM-сжатие (ETC2 + ASTC сразу) крупнее и
мутнее на картинках с мелкими деталями. Портреты и арты профессий рисуются мельче своего размера — с мипмапами.
--preview: логотип на тёмном фоне, иконки в масках Android (круг, скруглённый квадрат), листы портретов.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
PACK = os.path.join(ART, "pack")
BRAND = os.path.join(ROOT, "assets", "branding")

LOGO_W = 1200
JPG_Q = 90
RACE_W = 1600
JOB_SIZE = (800, 1066)
PORTRAIT = 256
# Радиус скругления портрета (доля стороны) — чуть больше, чем у плиток ChatGPT (≈0.13), чтобы белые углы ушли.
PORTRAIT_RADIUS = 0.15
# Обрезка края плитки портрета внутрь (доля стороны): белая кайма и сглаженный край плитки.
PORTRAIT_INSET = 0.012
RACES = ["dark_elf", "light_elf", "human"]
JOBS = ["assassin", "neophyte", "adept", "swordsman", "wizard", "beastmaster", "warrior", "shaman", "conjurer"]
# Листы портретов: слева направо, сверху вниз (проверено глазами — пол, раса, цвет одежды профессии).
SHEETS = {
	"portraits_1.png": ["assassin_m", "assassin_f", "neophyte_m", "neophyte_f", "adept_m", "adept_f"],
	"portraits_2.png": ["swordsman_m", "swordsman_f", "wizard_m", "wizard_f", "beastmaster_m", "beastmaster_f"],
	"portraits_3.png": ["warrior_m", "warrior_f", "shaman_m", "shaman_f", "conjurer_m", "conjurer_f"],
	"portraits_4.png": ["wanderer_dark_elf_m", "wanderer_dark_elf_f", "wanderer_light_elf_m", "wanderer_light_elf_f",
		"wanderer_human_m", "wanderer_human_f"],
}
# Адаптивная иконка Android: слой 108dp = 432 px, видна середина 72dp (288 px); арт целиком — ADAPTIVE_ART px
# в центре (чуть больше видимой части — край не виден в квадратной маске, монограмма помещается и в круглую),
# за его краями — размытое продолжение того же арта (видно при сдвиге слоёв).
ADAPTIVE = 432
ADAPTIVE_ART = 292

# Импорт Godot для артов: Lossy WebP; mip — с мипмапами (картинка рисуется мельче своего размера).
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://%s"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=%s
mipmaps/generate=%s
detect_3d/compress_to=0
"""


def rel(path):
	return os.path.relpath(path, ROOT).replace(os.sep, "/")


def write_import(path, mip=False, quality=0.85):
	with open(path + ".import", "w", encoding="utf-8") as f:
		f.write(IMPORT % (rel(path), quality, "true" if mip else "false"))


def save_jpg(im, path, mip=False):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	im.convert("RGB").save(path, quality=JPG_Q, optimize=True, progressive=False, subsampling=0)
	write_import(path, mip)
	print("  %s %dx%d, %.0f КБ" % (rel(path), im.width, im.height, os.path.getsize(path) / 1024))


def save_png(im, path, mip=False, import_file=True, quality=0.85):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	im.save(path, optimize=True)
	if import_file:
		write_import(path, mip, quality)
	print("  %s %dx%d, %.0f КБ" % (rel(path), im.width, im.height, os.path.getsize(path) / 1024))


def fit_width(im, w):
	if im.width <= w:
		return im
	return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


# ---------- Логотип: белый фон → прозрачный ----------

def cut_logo(im):
	"""Белый фон логотипа → альфа. Фон — светлые пиксели, связанные с краем картинки (заливка от края; буквы
	в тёмном контуре в неё не попадают), и большие белые «дырки» внутри букв. В фоне цвет «снимается» с белого:
	пиксель C = a·F + (1 − a)·белый, a = max(1 − C) — сглаженный край и зелёное свечение остаются полупрозрачными
	без белой каймы. Остальное — непрозрачно."""
	a = np.asarray(im.convert("RGB")).astype(np.float32) / 255.0
	lo = a.min(axis=2)
	light = lo > 0.47
	lab, _n = ndimage.label(light)
	edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
	bg = np.isin(lab, edge[edge > 0])
	# Белые дырки внутри букв (A, P, D): почти чистый белый, крупные
	white = lo > 0.93
	wl, wn = ndimage.label(white & ~bg)
	if wn:
		sizes = ndimage.sum(np.ones_like(lo), wl, index=np.arange(1, wn + 1))
		big = np.where(sizes > 120)[0] + 1
		hole = np.isin(wl, big)
		# дырка + светлые пиксели вокруг неё (сглаженный край)
		grow = ndimage.binary_dilation(hole, iterations=3) & light
		bg |= grow
	alpha_u = np.clip(1.0 - lo, 0.0, 1.0)
	alpha = np.where(bg, alpha_u, 1.0)
	# Шум JPEG у белого — в ноль
	alpha = np.where(bg & (alpha < 0.04), 0.0, alpha)
	safe = np.maximum(alpha, 1e-4)[..., None]
	col = np.where(bg[..., None], (a - (1.0 - alpha)[..., None]) / safe, a)
	col = np.clip(col, 0.0, 1.0)
	rgba = np.dstack([col, alpha])
	out = Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")
	ys, xs = np.where(alpha > 0.03)
	pad = 12
	box = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad + 1),
		min(im.height, ys.max() + pad + 1))
	return out.crop(box)


# ---------- Иконка ----------

def adaptive(icon):
	"""Фон адаптивной иконки 432×432: арт ADAPTIVE_ART в центре, за краем — размытое продолжение того же арта;
	передний план — прозрачный (иначе Godot подставит обычную иконку и она обрежется маской)."""
	big = icon.resize((ADAPTIVE, ADAPTIVE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))
	dark = Image.new("RGB", big.size, (0, 0, 0))
	bg = Image.blend(big, dark, 0.25)
	art = icon.resize((ADAPTIVE_ART, ADAPTIVE_ART), Image.LANCZOS)
	o = (ADAPTIVE - ADAPTIVE_ART) // 2
	# Мягкий край арта (4 px), чтобы стык с размытым краем не был виден
	m = Image.new("L", (ADAPTIVE_ART, ADAPTIVE_ART), 0)
	ImageDraw.Draw(m).rectangle((3, 3, ADAPTIVE_ART - 4, ADAPTIVE_ART - 4), fill=255)
	m = m.filter(ImageFilter.GaussianBlur(2))
	bg.paste(art, (o, o), m)
	fg = Image.new("RGBA", (ADAPTIVE, ADAPTIVE), (0, 0, 0, 0))
	return bg, fg


def mask_preview(bg, kind):
	"""Как лаунчер покажет адаптивную иконку: середина 72dp (2/3), маска круг или скруглённый квадрат."""
	s = ADAPTIVE * 2 // 3
	o = (ADAPTIVE - s) // 2
	view = bg.crop((o, o, o + s, o + s)).convert("RGBA")
	m = Image.new("L", (s * 4, s * 4), 0)
	d = ImageDraw.Draw(m)
	if kind == "circle":
		d.ellipse((0, 0, s * 4 - 1, s * 4 - 1), fill=255)
	else:
		d.rounded_rectangle((0, 0, s * 4 - 1, s * 4 - 1), radius=s * 4 // 5, fill=255)
	view.putalpha(m.resize((s, s), Image.LANCZOS))
	return view


# ---------- Портреты ----------

def sheet_tiles(im, count):
	"""Плитки листа на белом фоне по порядку: строки по y, в строке — по x. [(x0, y0, x1, y1)]."""
	a = np.asarray(im.convert("RGB")).astype(int)
	mask = a.min(axis=2) < 230
	mask = ndimage.binary_closing(mask, iterations=3)
	mask = ndimage.binary_fill_holes(mask)
	lab, _n = ndimage.label(mask)
	boxes = []
	for sl in ndimage.find_objects(lab):
		h = sl[0].stop - sl[0].start
		w = sl[1].stop - sl[1].start
		if h > 150 and w > 150:
			boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
	boxes.sort(key=lambda b: b[1])
	rows = []
	for b in boxes:
		if rows and abs(rows[-1][0][1] - b[1]) < 80:
			rows[-1].append(b)
		else:
			rows.append([b])
	order = [b for r in rows for b in sorted(r, key=lambda b: b[0])]
	if len(order) != count:
		sys.exit("лист: найдено плиток %d, нужно %d (%s)" % (len(order), count, order))
	return order


def portrait(im, box):
	x0, y0, x1, y1 = box
	s = min(x1 - x0, y1 - y0)
	cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
	ins = s * PORTRAIT_INSET
	h = s / 2.0 - ins
	tile = im.convert("RGB").crop((round(cx - h), round(cy - h), round(cx + h), round(cy + h)))
	tile = tile.resize((PORTRAIT, PORTRAIT), Image.LANCZOS).convert("RGBA")
	k = 4
	m = Image.new("L", (PORTRAIT * k, PORTRAIT * k), 0)
	ImageDraw.Draw(m).rounded_rectangle((0, 0, PORTRAIT * k - 1, PORTRAIT * k - 1),
		radius=round(PORTRAIT * k * PORTRAIT_RADIUS), fill=255)
	tile.putalpha(m.resize((PORTRAIT, PORTRAIT), Image.LANCZOS))
	# Проверка: у скругления углов (полоса 1.5 px внутри дуги; белая одежда и волосы у края — не фон) не осталось белого фона листа
	t = np.asarray(tile).astype(int)
	c = PORTRAIT * PORTRAIT_RADIUS
	yy, xx = np.mgrid[0:PORTRAIT, 0:PORTRAIT] + 0.5
	dx = np.maximum(np.maximum(c - xx, xx - (PORTRAIT - c)), 0.0)
	dy = np.maximum(np.maximum(c - yy, yy - (PORTRAIT - c)), 0.0)
	r = np.hypot(dx, dy)
	band = (dx > 0) & (dy > 0) & (r > c - 1.5)
	white = (t[..., :3].min(axis=2) > 250) & (t[..., 3] > 128) & band
	if white.sum() > 20:
		print("  предупреждение: в углах портрета %d белых пикселей" % white.sum())
	return tile


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--src", required=True, help="папка с картинками Максима (имена — в шапке)")
	ap.add_argument("--preview", help="папка для картинок-проверок")
	a = ap.parse_args()
	src = lambda n: os.path.join(a.src, n)
	prev = a.preview
	if prev:
		os.makedirs(prev, exist_ok=True)

	print("логотип, главный арт (в APK):")
	logo = cut_logo(Image.open(src("logo_dark_pact.png")))
	logo = fit_width(logo, LOGO_W)
	save_png(logo, os.path.join(ART, "logo_dark_pact.png"), quality=0.9)
	key = Image.open(src("key_art.png")).convert("RGB")
	save_jpg(key, os.path.join(ART, "key_art.jpg"))

	print("иконка:")
	icon = Image.open(src("icon_dp.png")).convert("RGB")
	save_png(icon.resize((256, 256), Image.LANCZOS), os.path.join(BRAND, "icon.png"), import_file=False)
	save_png(icon.resize((192, 192), Image.LANCZOS), os.path.join(BRAND, "icon_192.png"), import_file=False)
	bg, fg = adaptive(icon)
	save_png(bg, os.path.join(BRAND, "icon_background_432.png"), import_file=False)
	save_png(fg, os.path.join(BRAND, "icon_foreground_432.png"), import_file=False)

	print("арты рас и профессий (пакет, часть art):")
	for r in RACES:
		im = Image.open(src("race_%s.png" % r)).convert("RGB")
		save_jpg(fit_width(im, RACE_W), os.path.join(PACK, "race_%s.jpg" % r))
	for j in JOBS:
		im = Image.open(src("job_%s.png" % j)).convert("RGB")
		save_jpg(im.resize(JOB_SIZE, Image.LANCZOS), os.path.join(PACK, "job_%s.jpg" % j), mip=True)

	print("портреты (пакет, часть art):")
	made = []
	for sheet, ids in SHEETS.items():
		im = Image.open(src(sheet))
		for box, pid in zip(sheet_tiles(im, len(ids)), ids):
			p = portrait(im, box)
			save_png(p, os.path.join(PACK, "portraits", pid + ".png"), mip=True)
			made.append((pid, p))

	if prev:
		dark = Image.new("RGBA", (logo.width + 80, logo.height + 80), (18, 20, 30, 255))
		dark.alpha_composite(logo, (40, 40))
		dark.convert("RGB").save(os.path.join(prev, "logo_on_dark.png"))
		mid = Image.new("RGBA", dark.size, (90, 60, 120, 255))
		mid.alpha_composite(logo, (40, 40))
		mid.convert("RGB").save(os.path.join(prev, "logo_on_purple.png"))
		row = Image.new("RGBA", (ADAPTIVE * 3 + 40, ADAPTIVE), (40, 40, 40, 255))
		row.paste(bg, (0, 0))
		for i, kind in enumerate(["circle", "squircle"]):
			v = mask_preview(bg, kind)
			row.alpha_composite(v, (ADAPTIVE * (i + 1) + 20 * (i + 1) + (ADAPTIVE - v.width) // 2, (ADAPTIVE - v.height) // 2))
		row.convert("RGB").save(os.path.join(prev, "icon_adaptive.png"))
		sheet = Image.new("RGBA", (PORTRAIT * 6 + 70, PORTRAIT * 4 + 50), (25, 28, 40, 255))
		for i, (_pid, p) in enumerate(made):
			sheet.alpha_composite(p, (10 + (i % 6) * (PORTRAIT + 10), 10 + (i // 6) * (PORTRAIT + 10)))
		sheet.convert("RGB").save(os.path.join(prev, "portraits.png"))
		print("проверки — %s" % prev)


if __name__ == "__main__":
	main()
