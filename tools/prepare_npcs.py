#!/usr/bin/env python3
"""Жители-NPC из Meshy (авто-риг, родной скелет Bone_NNN) → игровые модели assets/characters/npc_<id>.glb.

Обёртка над tools/prepare_hero.py (тот же конвейер, что у героев: меш ~30 тыс. треуг., клипы UAL Idle, Wave,
Walking, Running …, <id>.json с ролями костей и хватом). Добавляет только то, чего нет в имени файла жителя:
рост и пол каждого жителя (NPCS). Пол в prepare_hero задаётся окончанием id (_f — женская пластика шага и покоя),
а файл жителя называется npc_<id> без пола — поэтому женщины собираются как npc_<id>_f во временную папку
и переименовываются (GLB, PNG, JSON, .import; имена внутри GLB ни на что не влияют).

Запуск из корня репозитория (входные GLB — чужие данные: Python с -I):
  python3 -I tools/prepare_npcs.py --ual1 <UAL1_Standard.glb> --ual2 <UAL2_Standard.glb> \\
      npc_smith=<Кузнец.glb> npc_hunter=<файл.glb> … [--preview <папка>]
Какой файл Максима каким жителем стал — assets/LICENSES.md («Жители»).
"""
import argparse
import importlib.util
import os
import shutil
import sys
import tempfile

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)

## Житель → (пол m/f, рост всего меша, м — с волосами, шляпой и ушами). Мужчины ~1.8, женщины ~1.7; старики чуть
## ниже, кузнец могучий; у Вейрис высокий хвост над головой, у торговца шляпа.
NPCS = {
	"npc_merchant": ("m", 1.80),
	"npc_kirk": ("m", 1.74),
	"npc_sage": ("m", 1.72),
	"npc_smith": ("m", 1.86),
	"npc_storekeeper": ("m", 1.72),
	"npc_elder_human": ("m", 1.76),
	"npc_elder_light": ("f", 1.74),
	"npc_elder_dark": ("f", 1.80),
	"npc_hunter": ("f", 1.68),
	"npc_merc_chief": ("m", 1.82),
	# Три лавки города (этап 2; бесплатные модели Meshy, скачанные Максимом — assets/LICENSES.md): оружейник —
	# крепкий мужчина в капюшоне, бронница — в наплечниках с секирой за спиной (высокий хвост), ювелир — рыжие
	# кудри, красный плащ
	"npc_weaponsmith": ("m", 1.84),
	"npc_armorer": ("f", 1.74),
	"npc_jeweler": ("f", 1.70),
}


def _load(name: str):
	spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


def main() -> None:
	ap = argparse.ArgumentParser(description="Жители из Meshy → npc_<id>.glb (через prepare_hero.py)")
	ap.add_argument("sources", nargs="+", help="npc_<id>=путь к GLB из Meshy (id — из NPCS)")
	ap.add_argument("--ual1", required=True, help="UAL1_Standard.glb (Quaternius)")
	ap.add_argument("--ual2", required=True, help="UAL2_Standard.glb (Quaternius)")
	ap.add_argument("--out", default=os.path.join(ROOT, "assets", "characters"), help="куда писать")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок")
	args = ap.parse_args()
	ph = _load("prepare_hero")
	ph.UAL.update({"ual1": args.ual1, "ual2": args.ual2})
	ok = True
	for s in args.sources:
		if "=" not in s:
			ap.error("ждём npc_<id>=путь, получено %r" % s)
		cid, path = s.split("=", 1)
		if cid not in NPCS:
			ap.error("неизвестный житель %r (есть: %s)" % (cid, ", ".join(NPCS)))
		sex, h = NPCS[cid]
		if sex == "m":
			ok = ph.build(cid, path, h, args.out, args.preview)["ok"] and ok
			continue
		# Женщина: id с «_f» (женская пластика), затем переименование в npc_<id>
		tmp = tempfile.mkdtemp(prefix=".tmp_npc_", dir=args.out)
		try:
			tid = cid + "_f"
			ok = ph.build(tid, path, h, tmp, args.preview)["ok"] and ok
			for ext in (".glb", ".png", ".json"):
				src = os.path.join(tmp, tid + ext)
				if os.path.exists(src):
					shutil.move(src, os.path.join(args.out, cid + ext))
			for ext, tpl in ((".png.import", ph.PNG_IMPORT), (".glb.import", ph.GLB_IMPORT)):
				p = os.path.join(args.out, cid + ext)
				if not os.path.exists(p):
					with open(p, "w") as f:
						f.write(tpl.format(name=cid))
		finally:
			shutil.rmtree(tmp, ignore_errors=True)
	print("ИТОГ (жители): %s" % ("всё в порядке" if ok else "есть замечания (см. ПЛОХО выше)"))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
