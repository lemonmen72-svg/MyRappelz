#!/usr/bin/env python3
# Инвентарь клипов героев и жителей для системы анимаций: docs/animation/ANIMATION_INVENTORY.csv.
# По <id>.json рядом с моделями (assets/characters): клип, длина, петля, момент удара, своя скорость, кто его
# выбирает (константы CharacterModel, где клип упомянут). Запуск из корня: python3 -I tools/anim_inventory.py
import csv, glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(ROOT, "character_model.gd"), encoding="utf-8").read()
OUT = os.path.join(ROOT, "docs", "animation", "ANIMATION_INVENTORY.csv")

# Константы CharacterModel → какие ключи клипов (нижний регистр) в них упомянуты
consts = {}
for m in re.finditer(r'^const (MQ_\w+|ASSET_\w+) := (.*?)(?=^\S)', SRC, re.M | re.S):
	consts[m.group(1)] = set(re.findall(r'"([a-z0-9_]+)"', m.group(2)))


def users(clip):
	k = clip.lower()
	return ";".join(sorted(n for n, keys in consts.items() if k in keys or any(x and x in k for x in keys if len(x) > 3 and n == "ASSET_ACTIONS")))


rows = []
for f in sorted(glob.glob(os.path.join(ROOT, "assets", "characters", "*.json"))):
	d = json.load(open(f, encoding="utf-8"))
	mid = os.path.basename(f)[:-5]
	for name, info in sorted(d.get("clips", {}).items()):
		info = info if isinstance(info, dict) else {}
		rows.append({"model": mid, "clip": name, "length": info.get("length", ""), "loop": info.get("loop", False),
			"hit": info.get("hit", ""), "speed": info.get("speed", ""), "turn": info.get("turn", ""),
			"source": "mannequin" if name.startswith("Mq_") else "ual/meshy", "used_by": users(name) or "—"})
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", newline="", encoding="utf-8") as fh:
	w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
	w.writeheader()
	w.writerows(rows)
unused = sorted({r["clip"] for r in rows if r["used_by"] == "—"})
print("клипов", len(rows), "моделей", len({r["model"] for r in rows}), "не выбирается кодом:", ", ".join(unused))
