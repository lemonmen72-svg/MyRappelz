#!/usr/bin/env python3
"""Пакет ресурсов MyRappelz (Assets в игре, assets.gd): что в нём, хэш содержимого, манифест, проверка .pck.

Что в пакете — include_filter пресета экспорта «Assets» в export_presets.cfg (те же шаблоны — Assets.PACK_FILTERS
в assets.gd и часть exclude_filter пресета «Android»; шаблоны как у Godot: * — любые символы, ? — один, без
учёта регистра, путь от корня проекта; папки с точкой не просматриваются).

Подкоманды (запуск из корня репозитория: python3 -I tools/asset_pack.py <команда>):
  files                 — список файлов пакета и их общий размер (исходники, не результат импорта);
  check                 — шаблоны пакета совпадают с исключёнными из APK, манифест включён в APK;
  digest --godot 4.3    — хэш содержимого (sha256 путей и содержимого файлов пакета и их .import + версия Godot):
                          версия пакета, ключ кэша в игре. Считать ДО импорта Godot (он переписывает .import);
  manifest --pck P --hash H --version V --url U --out F — манифест {version, hash, sha256, size, url, file};
  verify-pck P          — в .pck есть каждый файл пакета (его .import и импортированные данные).
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
EMBEDDED_MANIFEST = "assets_pack.json"


def read_presets(path=PRESETS):
	"""Пресеты экспорта: {имя: {ключ: значение}} (только простые строки key="value")."""
	presets = {}
	cur = None
	with open(path, encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			m = re.match(r"^\[preset\.(\d+)\]$", line)
			if m:
				cur = {}
				presets["#" + m.group(1)] = cur
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
	return {p.get("name", k): p for k, p in presets.items()}


def filters(s):
	return [x.strip() for x in s.split(",") if x.strip()]


def pack_filters():
	p = read_presets().get("Assets")
	if p is None:
		sys.exit("export_presets.cfg: нет пресета «Assets»")
	return filters(p.get("include_filter", "")), filters(p.get("exclude_filter", ""))


def godot_match(path, pat):
	return fnmatch.fnmatchcase(path.lower(), pat.lower())


def pack_files():
	"""Файлы пакета: пути от корня проекта, по алфавиту (как обход Godot: include, затем exclude)."""
	inc, exc = pack_filters()
	out = []
	for d, dirs, files in os.walk(ROOT):
		dirs[:] = sorted(x for x in dirs if not x.startswith("."))
		for fn in files:
			rel = os.path.relpath(os.path.join(d, fn), ROOT).replace(os.sep, "/")
			if any(godot_match(rel, p) for p in inc) and not any(godot_match(rel, p) for p in exc):
				out.append(rel)
	return sorted(out)


def sha256_file(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def cmd_files(_a):
	total = 0
	for rel in pack_files():
		sz = os.path.getsize(os.path.join(ROOT, rel))
		total += sz
		print("%10d  %s" % (sz, rel))
	print("итого: %d файлов, %.1f МБ" % (len(pack_files()), total / 1048576.0))


def cmd_check(_a):
	presets = read_presets()
	apk = presets.get("Android")
	if apk is None:
		sys.exit("export_presets.cfg: нет пресета «Android»")
	inc, _exc = pack_filters()
	apk_exc = filters(apk.get("exclude_filter", ""))
	apk_inc = filters(apk.get("include_filter", ""))
	bad = [p for p in inc if p not in apk_exc]
	if bad:
		sys.exit("шаблоны пакета не исключены из APK: " + ", ".join(bad))
	if EMBEDDED_MANIFEST not in apk_inc:
		sys.exit("include_filter пресета «Android» должен включать " + EMBEDDED_MANIFEST)
	files = pack_files()
	if not files:
		sys.exit("в пакет не попал ни один файл")
	print("пакет ресурсов: %d файлов, шаблоны совпадают с исключёнными из APK" % len(files))


def content_hash(godot):
	h = hashlib.sha256()
	h.update(("godot=%s\nformat=1\n" % godot).encode())
	for rel in pack_files():
		full = os.path.join(ROOT, rel)
		imp = full + ".import"
		h.update(("%s\t%s\t%s\n" % (rel, sha256_file(full), sha256_file(imp) if os.path.exists(imp) else "-")).encode())
	return h.hexdigest()


def cmd_hash(a):
	print(content_hash(a.godot))


def cmd_manifest(a):
	if not re.fullmatch(r"[0-9a-f]{16,64}", a.hash):
		sys.exit("хэш содержимого должен быть 16–64 шестнадцатеричных знака")
	m = {
		"version": a.version,
		"hash": a.hash,
		"sha256": sha256_file(a.pck),
		"size": os.path.getsize(a.pck),
		"url": a.url,
		"file": os.path.basename(a.pck),
	}
	with open(a.out, "w", encoding="utf-8") as f:
		json.dump(m, f, ensure_ascii=False, indent=1)
		f.write("\n")
	print(json.dumps(m, ensure_ascii=False))


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
	missing = []
	for rel in pack_files():
		if rel + ".import" not in have:
			missing.append(rel + ".import")
			continue
		base = os.path.basename(rel) + "-"
		if not any(os.path.basename(p).startswith(base) for p in imported):
			missing.append(rel + " (импортированные данные)")
	print("в .pck %d файлов, %.1f МБ" % (len(paths), os.path.getsize(a.pck) / 1048576.0))
	if missing:
		sys.exit("в .pck нет: " + ", ".join(missing[:20]))
	print("все %d файлов пакета на месте" % len(pack_files()))


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	sub.add_parser("files").set_defaults(fn=cmd_files)
	sub.add_parser("check").set_defaults(fn=cmd_check)
	p = sub.add_parser("digest")
	p.add_argument("--godot", required=True)
	p.set_defaults(fn=cmd_hash)
	p = sub.add_parser("manifest")
	for k in ("pck", "hash", "version", "url", "out"):
		p.add_argument("--" + k, required=True)
	p.set_defaults(fn=cmd_manifest)
	p = sub.add_parser("verify-pck")
	p.add_argument("pck")
	p.set_defaults(fn=cmd_verify)
	a = ap.parse_args()
	a.fn(a)


if __name__ == "__main__":
	main()
