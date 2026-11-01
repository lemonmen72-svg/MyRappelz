#!/usr/bin/env python3
"""Пакет ресурсов MyRappelz (Assets в игре, assets.gd): части пакета, хэши содержимого, манифест, проверка .pck.

Пакет разбит на части (герои по расам, жители, стадии зверей, мир, звери 1-й стадии, оружие в руках, значки), у
каждой свой хэш и свой файл .pck: изменилась одна модель — сборка экспортирует, а игрок скачивает только её часть.
В APK остаются запасные герои (IN_APK), все .json (роли костей, creatures.json, props.json, handheld.json),
шейдеры, сцены, данные; всё тяжёлое из MUST_PACK должно быть в какой-то части. Список частей и их шаблоны — в трёх местах,
которые должны совпадать (следит команда check и тест tests/test_asset_pack.gd):
  - Assets.PACKS в assets.gd (имя части → шаблоны файлов);
  - пресеты экспорта «Assets <часть>» в export_presets.cfg (include_filter части);
  - exclude_filter пресета «Android» — объединение шаблонов всех частей (их файлы не попадают в APK).
Шаблоны как у Godot: * — любые символы, ? — один, без учёта регистра, путь от корня проекта; папки с точкой
не просматриваются.

Подкоманды (запуск из корня репозитория: python3 -I tools/asset_pack.py <команда>):
  files [--part P] [--summary] — файлы частей, размеры исходников и оценка после импорта (картинки с VRAM-сжатием —
                          по размеру и сжатию: ASTC 4×4 высокого качества 1 байт на пиксель, ETC2 0.5, мипмапы ×4/3);
  check                 — три места совпадают, файл не попал в две части, все модели и картинки MUST_PACK
                          (герои, жители, звери, постройки, текстуры, оружие, значки; кроме запасных героев APK) —
                          в какой-то части, .json — не в частях и включены в APK, манифест включён в APK;
  digest --godot 4.3 [--part P] — хэш содержимого части (sha256 имени части, путей и содержимого её файлов и их
                          .import + версия Godot): версия части, ключ кэша в игре. Без --part — строки «часть хэш»
                          по всем частям. Считать ДО импорта Godot (он переписывает .import);
  manifest --version V --base-url U --out F --part ИМЯ PCK ХЭШ [--part …] — манифест
                          {format: 2, version, parts: [{name, hash, sha256, size, url, file}]}, url = U/<имя файла>;
  verify-pck --part P PCK — в .pck есть каждый файл части (его .import и импортированные данные);
  apk-check LIST        — список файлов APK (вывод unzip -l): файлов частей в нём нет, запасные герои, .json
                          моделей и манифест пакета — есть.
Сборка пакета — в .github/workflows/android-apk.yml (только при сборке APK).
"""
import argparse
import fnmatch
import hashlib
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESETS = os.path.join(ROOT, "export_presets.cfg")
ASSETS_GD = os.path.join(ROOT, "assets.gd")
EMBEDDED_MANIFEST = "assets_pack.json"
PART_PRESET = "Assets "
PART_NAME = re.compile(r"[a-z0-9_]{1,32}")
# Имя части старого манифеста (один пакет на всё) — не годится для новой части.
LEGACY_PART = "all"
# Должны быть в какой-то части (модели и картинки), кроме запасных героев, которые лежат в APK.
MUST_PACK = [
	"assets/characters/*.glb",
	"assets/characters/*.png",
	"assets/creatures/*.glb",
	"assets/creatures/*.png",
	"assets/props/*.glb",
	"assets/props/*.png",
	"assets/textures/*.png",
	"assets/handheld/*.glb",
	"assets/handheld/*.png",
	"assets/icons/*.png",
]
# Данные моделей (роли костей, размеры, точки) — всегда в APK: код читает их до подключения частей.
NEVER_PACK = [
	"assets/*.json",
]
IN_APK = [
	"assets/characters/hero_human_?_starter.glb",
	"assets/characters/hero_human_?_starter.png",
]
# Часть больше этого (исходники или оценка после импорта — imported_mb) — пора делить.
PART_WARN_MB = 120.0


def read_presets(path=PRESETS):
	"""Пресеты экспорта по порядку: [(имя, {ключ: значение})] (только простые строки key="value")."""
	presets = []
	cur = None
	with open(path, encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			m = re.match(r"^\[preset\.(\d+)\]$", line)
			if m:
				cur = {}
				presets.append(cur)
				continue
			if line.startswith("["):
				cur = None
				continue
			if cur is None or "=" not in line:
				continue
			k, v = line.split("=", 1)
			if v.startswith('"') and v.endswith('"'):
				v = v[1:-1]
			cur[k] = v
	return [(p.get("name", "#%d" % i), p) for i, p in enumerate(presets)]


def preset(name):
	for n, p in read_presets():
		if n == name:
			return p
	return None


def filters(s):
	return [x.strip() for x in s.split(",") if x.strip()]


def parts():
	"""Части пакета по порядку пресетов: [(имя, include_filter)]."""
	out = []
	for n, p in read_presets():
		if n.startswith(PART_PRESET):
			out.append((n[len(PART_PRESET):], filters(p.get("include_filter", ""))))
	if not out:
		sys.exit("export_presets.cfg: нет пресетов «%s<часть>»" % PART_PRESET)
	return out


def part_filters(name):
	for n, inc in parts():
		if n == name:
			return inc
	sys.exit("нет части «%s» (есть: %s)" % (name, ", ".join(n for n, _ in parts())))


def gd_packs(path=ASSETS_GD):
	"""Assets.PACKS из assets.gd: [(имя, [шаблоны])]."""
	with open(path, encoding="utf-8") as f:
		text = f.read()
	m = re.search(r"^const PACKS := \{\n(.*?)^\}", text, re.M | re.S)
	if not m:
		sys.exit("assets.gd: не найден const PACKS := { … }")
	out = []
	for name, body in re.findall(r'"([^"]+)"\s*:\s*\[(.*?)\]', m.group(1), re.S):
		out.append((name, re.findall(r'"([^"]+)"', body)))
	return out


def godot_match(path, pat):
	return fnmatch.fnmatchcase(path.lower(), pat.lower())


def all_files():
	"""Все файлы проекта (пути от корня), без папок с точкой."""
	out = []
	for d, dirs, files in os.walk(ROOT):
		dirs[:] = sorted(x for x in dirs if not x.startswith("."))
		for fn in files:
			out.append(os.path.relpath(os.path.join(d, fn), ROOT).replace(os.sep, "/"))
	return sorted(out)


def match_any(rel, pats):
	return any(godot_match(rel, p) for p in pats)


def part_files(name, files=None):
	"""Файлы части: пути от корня проекта, по алфавиту."""
	inc = part_filters(name)
	return [rel for rel in (files if files is not None else all_files()) if match_any(rel, inc)]


def sha256_file(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def size_mb(files):
	return sum(os.path.getsize(os.path.join(ROOT, rel)) for rel in files) / 1048576.0


def png_size(path):
	"""Ширина и высота PNG по заголовку (IHDR); не PNG — None."""
	with open(path, "rb") as f:
		head = f.read(24)
	if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
		return None
	return struct.unpack(">II", head[16:24])


def import_params(path):
	"""[params] файла .import: ключ → строка значения (пусто, если файла нет)."""
	out = {}
	imp = path + ".import"
	if not os.path.exists(imp):
		return out
	sec = ""
	with open(imp, encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			if line.startswith("["):
				sec = line
			elif sec == "[params]" and "=" in line:
				k, v = line.split("=", 1)
				out[k] = v
	return out


def imported_mb(files):
	"""Оценка размера части после импорта для телефона (то, что ляжет в .pck): у картинок с VRAM-сжатием
	(compress/mode=2) — ASTC 4×4 при compress/high_quality (1 байт на пиксель) или ETC2 (0.5), с мипмапами ×4/3;
	(текстуры — и видеопамять, пока модель на экране); остальное — по размеру исходника. Возвращает
	(всего МБ, из них текстуры VRAM МБ)."""
	total = vram = 0.0
	for rel in files:
		path = os.path.join(ROOT, rel)
		prm = import_params(path) if rel.lower().endswith(".png") else {}
		wh = png_size(path) if prm.get("compress/mode") == "2" else None
		if wh is None:
			total += os.path.getsize(path)
			continue
		bpp = 1.0 if prm.get("compress/high_quality") == "true" else 0.5
		b = wh[0] * wh[1] * bpp * (4.0 / 3.0 if prm.get("mipmaps/generate") == "true" else 1.0)
		total += b
		vram += b
	return total / 1048576.0, vram / 1048576.0


def cmd_files(a):
	files = all_files()
	names = [a.part] if a.part else [n for n, _ in parts()]
	total_n = 0
	total = total_imp = total_vram = 0.0
	for name in names:
		fl = part_files(name, files)
		if not a.summary:
			for rel in fl:
				print("%10d  %s" % (os.path.getsize(os.path.join(ROOT, rel)), rel))
		mb = size_mb(fl)
		imp, vram = imported_mb(fl)
		print("часть %-14s %3d файлов, %6.1f МБ исходников, ≈ %6.1f МБ после импорта (текстуры VRAM %5.1f МБ)" % (
			name, len(fl), mb, imp, vram))
		total_n += len(fl)
		total += mb
		total_imp += imp
		total_vram += vram
	if not a.part:
		print("итого: %d частей, %d файлов, %.1f МБ исходников, ≈ %.1f МБ после импорта (текстуры VRAM %.1f МБ)" % (
			len(names), total_n, total, total_imp, total_vram))


def cmd_check(_a):
	errors = []
	apk = preset("Android")
	if apk is None:
		sys.exit("export_presets.cfg: нет пресета «Android»")
	cfg = parts()
	gd = gd_packs()
	names = [n for n, _ in cfg]
	if len(set(names)) != len(names):
		errors.append("пресеты частей повторяются: " + ", ".join(names))
	for n in names:
		if not PART_NAME.fullmatch(n) or n == LEGACY_PART:
			errors.append("неверное имя части «%s» (a–z, 0–9, _; не «%s»)" % (n, LEGACY_PART))
	if [n for n, _ in gd] != names:
		errors.append("части Assets.PACKS (%s) ≠ пресеты экспорта (%s)" % (
			", ".join(n for n, _ in gd), ", ".join(names)))
	gdd = dict(gd)
	for n, inc in cfg:
		if n in gdd and sorted(gdd[n]) != sorted(inc):
			errors.append("часть «%s»: шаблоны Assets.PACKS ≠ include_filter «%s%s»" % (n, PART_PRESET, n))
		if not filters(preset(PART_PRESET + n).get("exclude_filter", "")) == []:
			errors.append("пресет «%s%s»: exclude_filter должен быть пустым" % (PART_PRESET, n))
	apk_exc = filters(apk.get("exclude_filter", ""))
	apk_inc = filters(apk.get("include_filter", ""))
	union = [p for _, inc in cfg for p in inc]
	bad = [p for p in union if p not in apk_exc]
	if bad:
		errors.append("шаблоны частей не исключены из APK: " + ", ".join(bad))
	if EMBEDDED_MANIFEST not in apk_inc:
		errors.append("include_filter пресета «Android» должен включать " + EMBEDDED_MANIFEST)
	files = all_files()
	owner = {}
	for n, _ in cfg:
		fl = part_files(n, files)
		if not fl:
			errors.append("в часть «%s» не попал ни один файл" % n)
		for rel in fl:
			if rel in owner:
				errors.append("%s — в двух частях: %s и %s" % (rel, owner[rel], n))
			owner[rel] = n
		mb = size_mb(fl)
		imp = imported_mb(fl)[0]
		if max(mb, imp) > PART_WARN_MB:
			print("предупреждение: часть «%s» — %.1f МБ исходников, ≈ %.1f МБ после импорта, пора разделить" % (
				n, mb, imp))
	loose = [rel for rel in files if match_any(rel, MUST_PACK) and not match_any(rel, IN_APK) and rel not in owner]
	if loose:
		errors.append("модели и картинки не попали ни в одну часть (попадут в APK): " + ", ".join(loose[:20]))
	for rel in files:
		if match_any(rel, NEVER_PACK):
			if rel in owner:
				errors.append("%s — данные моделей должны остаться в APK (в части «%s»)" % (rel, owner[rel]))
			elif not match_any(rel, apk_inc):
				errors.append("%s не попадёт в APK: добавьте шаблон в include_filter пресета «Android»" % rel)
	for rel in files:
		if match_any(rel, IN_APK) and rel in owner:
			errors.append("запасная модель %s должна остаться в APK" % rel)
	if errors:
		sys.exit("\n".join(errors))
	print("пакет ресурсов: %d частей (%s), %d файлов; Assets.PACKS, пресеты частей и исключения APK совпадают" % (
		len(cfg), ", ".join(names), len(owner)))


def content_hash(godot, name):
	h = hashlib.sha256()
	h.update(("godot=%s\nformat=2\npart=%s\n" % (godot, name)).encode())
	for rel in part_files(name):
		full = os.path.join(ROOT, rel)
		imp = full + ".import"
		h.update(("%s\t%s\t%s\n" % (rel, sha256_file(full), sha256_file(imp) if os.path.exists(imp) else "-")).encode())
	return h.hexdigest()


def cmd_hash(a):
	if a.part:
		print(content_hash(a.godot, a.part))
		return
	for n, _ in parts():
		print("%s %s" % (n, content_hash(a.godot, n)))


def cmd_manifest(a):
	known = [n for n, _ in parts()]
	got = [p[0] for p in a.part]
	if sorted(got) != sorted(known):
		sys.exit("в манифесте должны быть все части ровно по разу: %s (дано: %s)" % (", ".join(known), ", ".join(got)))
	out = []
	for name, pck, h in sorted(a.part, key=lambda p: known.index(p[0])):
		if not re.fullmatch(r"[0-9a-f]{16,64}", h):
			sys.exit("часть %s: хэш содержимого должен быть 16–64 шестнадцатеричных знака" % name)
		out.append({
			"name": name,
			"hash": h,
			"sha256": sha256_file(pck),
			"size": os.path.getsize(pck),
			"url": a.base_url.rstrip("/") + "/" + os.path.basename(pck),
			"file": os.path.basename(pck),
		})
	m = {"format": 2, "version": a.version, "parts": out}
	with open(a.out, "w", encoding="utf-8") as f:
		json.dump(m, f, ensure_ascii=False, indent=1)
		f.write("\n")
	print(json.dumps(m, ensure_ascii=False))
	print("всего: %.1f МБ" % (sum(p["size"] for p in out) / 1048576.0))


def read_pck(path):
	"""Список путей .pck (формат Godot 4.0–4.3, версия 2). None — другой формат."""
	with open(path, "rb") as f:
		magic, ver, _maj, _min, _pat, flags = struct.unpack("<6I", f.read(24))
		if magic != 0x43504447:
			sys.exit("не .pck Godot: " + path)
		if ver != 2:
			print("предупреждение: формат .pck %d — список файлов не проверяется" % ver)
			return None
		if flags & 1:
			sys.exit("каталог .pck зашифрован")
		f.read(8 + 16 * 4)
		(count,) = struct.unpack("<I", f.read(4))
		out = []
		for _ in range(count):
			(n,) = struct.unpack("<I", f.read(4))
			p = f.read(n).rstrip(b"\0").decode("utf-8")
			f.read(8 + 8 + 16 + 4)
			if p.startswith("res://"):
				p = p[len("res://"):]
			out.append(p)
		return out


def cmd_verify(a):
	paths = read_pck(a.pck)
	if paths is None:
		return
	have = set(paths)
	imported = [p for p in paths if p.startswith(".godot/imported/")]
	want = part_files(a.part)
	missing = []
	for rel in want:
		if rel + ".import" not in have:
			missing.append(rel + ".import")
			continue
		base = os.path.basename(rel) + "-"
		if not any(os.path.basename(p).startswith(base) for p in imported):
			missing.append(rel + " (импортированные данные)")
	# Файлы других частей в этом .pck — лишний вес (и шаблоны разошлись с пресетом).
	others = set()
	for n, _ in parts():
		if n != a.part:
			others.update(part_files(n))
	extra = [p for p in paths if p.endswith(".import") and p[:-len(".import")] in others]
	print("часть %s: в .pck %d файлов, %.1f МБ" % (a.part, len(paths), os.path.getsize(a.pck) / 1048576.0))
	if missing:
		sys.exit("в .pck нет: " + ", ".join(missing[:20]))
	if extra:
		sys.exit("в .pck файлы других частей: " + ", ".join(extra[:20]))
	print("все %d файлов части на месте" % len(want))


def apk_names(path):
	"""Имена файлов из вывода unzip -l (последний столбец строк с датой)."""
	out = []
	with open(path, encoding="utf-8", errors="replace") as f:
		for line in f:
			cols = line.split()
			if len(cols) >= 4 and cols[0].isdigit() and re.match(r"\d", cols[1]):
				out.append(cols[-1])
	return out


def in_apk(names, rel):
	"""Файл проекта rel есть в APK (Godot кладёт проект в assets/ внутри APK; ресурс — его .import)."""
	for want in (rel, rel + ".import"):
		for n in names:
			if n == want or n.endswith("/" + want):
				return True
	return False


def cmd_apk_check(a):
	names = apk_names(a.listing)
	if not names:
		sys.exit("список файлов APK пуст: " + a.listing)
	files = all_files()
	errors = []
	packed = []
	for n, _ in parts():
		for rel in part_files(n, files):
			if in_apk(names, rel + ".import"):
				packed.append(rel)
	if packed:
		errors.append("в APK попали файлы пакета ресурсов (%d): %s" % (len(packed), ", ".join(packed[:20])))
	need = [rel for rel in files if match_any(rel, IN_APK + NEVER_PACK)] + [EMBEDDED_MANIFEST]
	missing = [rel for rel in need if not in_apk(names, rel)]
	if missing:
		errors.append("в APK нет: " + ", ".join(missing[:20]))
	if errors:
		sys.exit("\n".join(errors))
	print("APK: файлов пакета нет; запасные герои, данные моделей (.json, %d) и манифест на месте" % len(need))


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("files")
	p.add_argument("--part")
	p.add_argument("--summary", action="store_true")
	p.set_defaults(fn=cmd_files)
	sub.add_parser("check").set_defaults(fn=cmd_check)
	p = sub.add_parser("digest")
	p.add_argument("--godot", required=True)
	p.add_argument("--part")
	p.set_defaults(fn=cmd_hash)
	p = sub.add_parser("manifest")
	for k in ("version", "base-url", "out"):
		p.add_argument("--" + k, required=True)
	p.add_argument("--part", nargs=3, action="append", required=True, metavar=("ИМЯ", "PCK", "ХЭШ"))
	p.set_defaults(fn=cmd_manifest)
	p = sub.add_parser("apk-check")
	p.add_argument("listing")
	p.set_defaults(fn=cmd_apk_check)
	p = sub.add_parser("verify-pck")
	p.add_argument("--part", required=True)
	p.add_argument("pck")
	p.set_defaults(fn=cmd_verify)
	a = ap.parse_args()
	if getattr(a, "part", None) and isinstance(a.part, str):
		part_filters(a.part)
	a.fn(a)


if __name__ == "__main__":
	main()
