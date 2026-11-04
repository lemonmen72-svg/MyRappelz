#!/usr/bin/env python3
# Эталон анимаций (система анимаций 1.0, docs/animation/REFERENCE.md): позы исходных клипов манекенов Meshy против
# перенесённых клипов Mq_* героев. Считает Blender (без рендера, только скелеты — быстро), рисует Pillow.
#
#   blender -b --factory-startup --python tools/anim_reference.py -- --m1 m1.glb --m2 m2.glb --m3 m3.glb \
#       [--heroes hero_warrior_m,hero_warrior_f,…|all] [--out docs/animation] [--sheets N]
#   python3 -I tools/anim_reference.py [--out docs/animation]   — листы по reference/worst.json (Pillow; в Blender его нет)
#
# Эталон — направления 10 сегментов тела (плечо, предплечье, бедро, голень слева и справа; корпус таз → шея; голова
# шея → макушка) в системе таза (ось X — от левого бедра к правому по горизонтали, Z — вверх, поворот всего тела
# снят: повороты на месте и разворот модели не мешают). Пишется в <out>/reference/mannequin_poses.json (клип → кадры
# 30 к/с → 10 единичных векторов) — дальше сравнение возможно и без манекенов. Клип героя сжат по времени вокруг
# удара (retarget_mannequin.py MQ_CLIPS), поэтому кадры совмещаются динамической подгонкой времени (DTW, наклон до 3).
# Отчёт: <out>/REFERENCE_REPORT.md (по клипу и герою — средний и худший угол по группам), <out>/reference/report.json,
# листы <out>/reference/sheets/<клип>.png (линии: эталон серым, герой цветом; худшие клипы).
import ast
import json
import math
import os
import sys
import time

try:
	import bpy  # Blender
except ImportError:
	bpy = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FPS = 30
SEGS = ["arm_up_l", "arm_lo_l", "arm_up_r", "arm_lo_r", "leg_up_l", "leg_lo_l", "leg_up_r", "leg_lo_r", "spine", "head"]
GROUPS = {"руки": [0, 1, 2, 3], "ноги": [4, 5, 6, 7], "корпус": [8, 9]}
# Суставы манекена (Mixamo): сегмент = от первого сустава ко второму
MIX = {"arm_up_l": ("LeftArm", "LeftForeArm"), "arm_lo_l": ("LeftForeArm", "LeftHand"),
	"arm_up_r": ("RightArm", "RightForeArm"), "arm_lo_r": ("RightForeArm", "RightHand"),
	"leg_up_l": ("LeftUpLeg", "LeftLeg"), "leg_lo_l": ("LeftLeg", "LeftFoot"),
	"leg_up_r": ("RightUpLeg", "RightLeg"), "leg_lo_r": ("RightLeg", "RightFoot"),
	"spine": ("Hips", "Neck"), "head": ("Head", "HeadTop_End")}
HIPS_LR = ("LeftUpLeg", "RightUpLeg")
# Пороги (градусы, средний угол после DTW): выше — «смотреть глазами». Ноги у шага и бега (loco) и стоп у клипов
# на месте (plant_inplace) нарочно отличаются от исходника — для них порог ног шире.
LIMIT = {"руки": 25.0, "ноги": 25.0, "корпус": 15.0}
LIMIT_LOCO_LEGS = 40.0


def args():
	a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else (sys.argv[1:] if bpy is None else [])
	o = {"heroes": "all", "out": os.path.join(ROOT, "docs", "animation"), "sheets": 8}
	i = 0
	while i < len(a):
		o[a[i].lstrip("-")] = a[i + 1]
		i += 2
	return o


def mq_clips():
	"""MQ_CLIPS и MQ_LOCO из tools/retarget_mannequin.py (разбор текста — модуль не импортируется в Blender)."""
	src = open(os.path.join(ROOT, "tools", "retarget_mannequin.py"), encoding="utf-8").read()
	tree = ast.parse(src)
	out = {}
	for node in tree.body:
		if isinstance(node, ast.Assign) and len(node.targets) == 1 and getattr(node.targets[0], "id", "") in ("MQ_CLIPS", "MQ_LOCO"):
			try:
				val = ast.literal_eval(node.value)
			except ValueError:
				continue
			name = node.targets[0].id
			if isinstance(val, dict):
				for k, v in val.items():
					out[k] = (name, v)
	return out


def clear():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.render.fps = FPS


def load(path):
	"""GLB → арматура (меши удалены: позы считаются без скиннинга) и словарь действий."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	arm = None
	for o in set(bpy.data.objects) - before:
		if o.type == "ARMATURE" and arm is None:
			arm = o
	for o in list(set(bpy.data.objects) - before):
		if o.type == "MESH":
			bpy.data.objects.remove(o, do_unlink=True)
	acts = {a.name: a for a in bpy.data.actions}
	return arm, acts


def find_action(acts, name):
	"""Действие по имени клипа: импорт glTF дописывает «_<имя арматуры>» (Charged_Spell_Cast_SmartRigArmature) — только
	точное совпадение после снятия суффикса (иначе Charged_Spell_Cast нашёл бы Charged_Spell_Cast_1, Mq_Thrust —
	Mq_Thrust_B)."""
	if name in acts:
		return acts[name]
	for k, a in acts.items():
		for o in bpy.data.objects:
			if o.type == "ARMATURE":
				for suf in ("_" + o.name, "_" + o.data.name):
					if k.endswith(suf) and k[:-len(suf)] == name:
						return a
	return None


def bone_lookup(arm, names):
	"""Имя → кость (у Mixamo с префиксом mixamorig:)."""
	pb = arm.pose.bones
	out = {}
	for n in names:
		hit = pb.get(n) or pb.get("mixamorig:" + n)
		if hit is None:
			for b in pb:
				if b.name.endswith(":" + n) or b.name.endswith(n):
					hit = b
					break
		out[n] = hit
	return out


def hero_joints(rig):
	"""Суставы героя по ролям <id>.json — те же ключи, что у Mixamo."""
	b = rig["bones"]
	al, ar = b["arms"]["L"], b["arms"]["R"]
	ll, lr = b["legs"]["L"], b["legs"]["R"]
	return {"LeftArm": al[1], "LeftForeArm": al[2], "LeftHand": al[3], "RightArm": ar[1], "RightForeArm": ar[2],
		"RightHand": ar[3], "LeftUpLeg": ll[0], "LeftLeg": ll[1], "LeftFoot": ll[2], "RightUpLeg": lr[0],
		"RightLeg": lr[1], "RightFoot": lr[2], "Hips": b["hips"], "Neck": b["neck"], "Head": b["head"],
		"HeadTop_End": b["head_end"]}


def norm(v):
	l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
	return (v[0] / l, v[1] / l, v[2] / l) if l > 1e-9 else (0.0, 0.0, 1.0)


def pose(arm, bones):
	"""10 единичных векторов в системе таза (поворот тела вокруг вертикали снят)."""
	mw = arm.matrix_world
	p = {k: mw @ b.head for k, b in bones.items() if b is not None}
	lr = p[HIPS_LR[1]] - p[HIPS_LR[0]]
	x = norm((lr.x, lr.y, 0.0))
	y = (-x[1], x[0], 0.0)  # Z вверх, Y — вперёд/назад по горизонтали
	out = []
	for s in SEGS:
		a, c = MIX[s]
		d = p[c] - p[a]
		out.append(norm((d.x * x[0] + d.y * x[1], d.x * y[0] + d.y * y[1], d.z)))
	return out


def sample(arm, bones, action, t0, t1):
	arm.animation_data_create()
	arm.animation_data.action = action
	sc = bpy.context.scene
	frames = []
	n = max(2, int(round((t1 - t0) * FPS)) + 1)
	for i in range(n):
		f = (t0 + (t1 - t0) * i / (n - 1)) * FPS
		sc.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
		frames.append(pose(arm, bones))
	return frames


def ang(a, b):
	d = max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]))
	return math.degrees(math.acos(d))


def frame_cost(fa, fb):
	return sum(ang(fa[i], fb[i]) for i in range(len(SEGS))) / len(SEGS)


def dtw(ref, got):
	"""Путь совмещения кадров эталона и героя (концы совпадают)."""
	n, m = len(ref), len(got)
	INF = 1e18
	D = [[INF] * (m + 1) for _ in range(n + 1)]
	D[0][0] = 0.0
	C = [[frame_cost(ref[i], got[j]) for j in range(m)] for i in range(n)]
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			D[i][j] = C[i - 1][j - 1] + min(D[i - 1][j - 1], D[i - 1][j], D[i][j - 1])
	path = []
	i, j = n, m
	while i > 0 and j > 0:
		path.append((i - 1, j - 1))
		k = min((D[i - 1][j - 1], 0), (D[i - 1][j], 1), (D[i][j - 1], 2))[1]
		i, j = (i - 1, j - 1) if k == 0 else ((i - 1, j) if k == 1 else (i, j - 1))
	return path[::-1]


def calibrate(ref, raw):
	"""Поворот на сегмент: эталон ≈ R · герой (Кабш, numpy есть в Blender); сдвиг рига — угол поворота, градусы."""
	import numpy as np
	rots, bias = [], {}
	for k in range(len(SEGS)):
		A, B = [], []
		for name, (got, path) in raw.items():
			for i, j in path:
				A.append(got[j][k])
				B.append(ref[name]["frames"][i][k])
		if not A:
			rots.append(np.eye(3))
			continue
		H = np.array(A).T @ np.array(B)
		U, _, Vt = np.linalg.svd(H)
		d = np.sign(np.linalg.det(Vt.T @ U.T))
		R = Vt.T @ np.diag([1.0, 1.0, d]) @ U.T
		rots.append(R)
		bias[SEGS[k]] = round(math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(R) - 1.0) / 2.0)))), 1)
	return rots, bias


def rotate(R, v):
	return norm(tuple(float(R[r][0] * v[0] + R[r][1] * v[1] + R[r][2] * v[2]) for r in range(3)))


def stats(ref, got, path):
	res = {}
	for g, idx in GROUPS.items():
		vals = [sum(ang(ref[i][k], got[j][k]) for k in idx) / len(idx) for i, j in path]
		res[g] = {"mean": round(sum(vals) / len(vals), 1), "max": round(max(vals), 1)}
	return res


def compare(ref, got):
	path = dtw(ref, got)
	res = {}
	for g, idx in GROUPS.items():
		vals = [sum(ang(ref[i][k], got[j][k]) for k in idx) / len(idx) for i, j in path]
		res[g] = {"mean": round(sum(vals) / len(vals), 1), "max": round(max(vals), 1)}
	return res, path


def sheet(path_png, title, ref, got, path):
	"""Лист: 6 кадров по пути DTW — эталон (серым) и герой (цветом), вид спереди и сбоку, линии суставов."""
	from PIL import Image, ImageDraw
	W, H, cols = 1200, 420, 6
	from PIL import ImageFont
	im = Image.new("RGB", (W, H), (250, 250, 248))
	dr = ImageDraw.Draw(im)
	try:
		font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
	except OSError:
		font = ImageFont.load_default()
	dr.text((10, 6), title, fill=(20, 20, 20), font=font)
	picks = [path[int(k * (len(path) - 1) / (cols - 1))] for k in range(cols)]

	def draw(frame, ox, oy, view, col, w):
		# суставы из сегментов: таз в начале координат, длины условные
		L = {"arm_up": 0.28, "arm_lo": 0.26, "leg_up": 0.42, "leg_lo": 0.42, "spine": 0.5, "head": 0.2}
		hip_l, hip_r = (-0.1, 0, 0), (0.1, 0, 0)
		neck = tuple(frame[8][k] * L["spine"] for k in range(3))
		pts = {"neck": neck, "headtop": tuple(neck[k] + frame[9][k] * L["head"] for k in range(3))}
		for side, sh, hp, ia, il in (("l", -0.16, hip_l, 0, 4), ("r", 0.16, hip_r, 2, 6)):
			s0 = (neck[0] + sh, neck[1], neck[2] - 0.03)
			el = tuple(s0[k] + frame[ia][k] * L["arm_up"] for k in range(3))
			wr = tuple(el[k] + frame[ia + 1][k] * L["arm_lo"] for k in range(3))
			kn = tuple(hp[k] + frame[il][k] * L["leg_up"] for k in range(3))
			an = tuple(kn[k] + frame[il + 1][k] * L["leg_lo"] for k in range(3))
			pts.update({"s" + side: s0, "e" + side: el, "w" + side: wr, "h" + side: hp, "k" + side: kn, "a" + side: an})
		lines = [("hl", "hr"), ("hl", "neck"), ("hr", "neck"), ("neck", "headtop"), ("sl", "sr"), ("sl", "el"),
			("el", "wl"), ("sr", "er"), ("er", "wr"), ("hl", "kl"), ("kl", "al"), ("hr", "kr"), ("kr", "ar")]
		sc = 120

		def pr(p):
			return (ox + (p[0] if view == "front" else p[1]) * sc, oy - p[2] * sc)
		for a, b in lines:
			dr.line([pr(pts[a]), pr(pts[b])], fill=col, width=w)
	cw = W / cols
	for c, (i, j) in enumerate(picks):
		x0 = cw * c + cw * 0.3
		draw(ref[i], x0, 250, "front", (160, 160, 160), 5)
		draw(got[j], x0, 250, "front", (220, 60, 40), 2)
		draw(ref[i], x0 + cw * 0.45, 250, "side", (160, 160, 160), 5)
		draw(got[j], x0 + cw * 0.45, 250, "side", (40, 90, 220), 2)
		dr.text((cw * c + 8, 380), "кадр %d / %d" % (i, j), fill=(60, 60, 60), font=font)
	im.save(path_png)


def main():
	o = args()
	t_start = time.time()
	clips = mq_clips()
	out_ref = os.path.join(o["out"], "reference")
	os.makedirs(os.path.join(out_ref, "sheets"), exist_ok=True)
	# --- Эталон: манекены ---
	ref = {}
	for m in ("m1", "m2", "m3"):
		clear()
		arm, acts = load(o[m])
		bones = bone_lookup(arm, set(sum(([a, b] for a, b in MIX.values()), [])) | set(HIPS_LR))
		missing = [k for k, v in bones.items() if v is None]
		if missing:
			print("ОШИБКА: у манекена %s нет костей %s" % (m, missing))
			return 2
		for name, (table, spec) in clips.items():
			if table == "MQ_CLIPS":
				src, act_name, t0, t1 = spec[0], spec[1], float(spec[2]), float(spec[3])
			else:
				# MQ_LOCO: (вид, "манекен:клип", …) — весь клип
				src, act_name = spec[1].split(":", 1)
				t0, t1 = 0.0, -1.0
			if src != m:
				continue
			if "+" in act_name:
				# Склейка двух клипов (Mq_Bow_Shot) — эталона нет, сравнивается глазами
				print("без эталона (склейка): %s" % name)
				continue
			a = find_action(acts, act_name)
			if a is None:
				print("нет клипа %s у %s (%s)" % (act_name, m, name))
				continue
			if t1 < 0:
				t1 = (a.frame_range[1] - a.frame_range[0]) / FPS
				t0 = a.frame_range[0] / FPS
			ref[name] = {"src": "%s:%s" % (m, act_name), "t0": t0, "t1": t1, "kind": table,
				"frames": [[[round(c, 3) for c in v] for v in f] for f in sample(arm, bones, a, t0, t1)]}
	with open(os.path.join(out_ref, "mannequin_poses.json"), "w", encoding="utf-8") as fh:
		json.dump({"fps": FPS, "segments": SEGS, "clips": ref}, fh, separators=(",", ":"))
	print("эталон: клипов %d, %.0f с" % (len(ref), time.time() - t_start))
	# --- Герои ---
	cdir = os.path.join(ROOT, "assets", "characters")
	if o["heroes"] == "all":
		heroes = sorted(f[:-4] for f in os.listdir(cdir) if f.startswith("hero_") and f.endswith(".glb"))
	else:
		heroes = [h for h in o["heroes"].split(",") if h]
	report = {}
	calib = {}
	for h in heroes:
		t_h = time.time()
		rig = json.load(open(os.path.join(cdir, h + ".json"), encoding="utf-8"))
		clear()
		arm, acts = load(os.path.join(cdir, h + ".glb"))
		names = hero_joints(rig)
		pb = arm.pose.bones
		bones = {k: pb.get(v) for k, v in names.items()}
		if any(b is None for b in bones.values()):
			print("пропуск %s: нет костей по ролям" % h)
			continue
		report[h] = {}
		raw = {}
		for name, r in ref.items():
			a = find_action(acts, name)
			if a is None:
				continue
			length = float(rig.get("clips", {}).get(name, {}).get("length", (a.frame_range[1] - a.frame_range[0]) / FPS))
			got = sample(arm, bones, a, a.frame_range[0] / FPS, a.frame_range[0] / FPS + length)
			raw[name] = (got, dtw(r["frames"], got))
		# Калибровка рига: постоянный поворот каждого сегмента (Кабш по всем совмещённым кадрам всех клипов) — другая
		# форма скелета (кость «макушки» — шапка или причёска, наклон шеи) не считается ошибкой движения
		rots, bias = calibrate(ref, raw)
		calib[h] = bias
		for name, (got, path) in raw.items():
			got_c = [[rotate(rots[k], f[k]) for k in range(len(SEGS))] for f in got]
			res = stats(ref[name]["frames"], got_c, path)
			report[h][name] = res
			report[h][name]["_path"] = path
			report[h][name]["_got"] = got_c
		print("%s: клипов %d, %.0f с" % (h, len(report[h]), time.time() - t_h))
	# --- Отчёт ---
	rows = []
	for h, cl in report.items():
		for name, res in cl.items():
			loco = ref[name]["kind"] == "MQ_LOCO"
			bad = [g for g in GROUPS if res[g]["mean"] > (LIMIT_LOCO_LEGS if (g == "ноги" and loco) else LIMIT[g])]
			rows.append((h, name, res, bad))
	rows.sort(key=lambda r: -max(r[2][g]["mean"] for g in GROUPS))
	md = ["# Эталон анимаций — сравнение с манекенами", "",
		"Считано `tools/anim_reference.py` (Blender %s, без рендера) за %.0f с: клипов-эталонов %d, героев %d. Угол — среднее по "
		"сегментам группы после совмещения кадров (DTW) и калибровки рига (ниже), в градусах; пороги: руки %.0f°, ноги %.0f° (шаг/бег %.0f°), корпус %.0f°."
		% (bpy.app.version_string, time.time() - t_start, len(ref), len(report), LIMIT["руки"], LIMIT["ноги"],
			LIMIT_LOCO_LEGS, LIMIT["корпус"]), "",
		"Выше порога — не обязательно ошибка (женская пластика, ноги на месте у выпадов, сжатие удара), но такие клипы "
		"смотреть глазами: листы в `reference/sheets/`.", ""]
	flagged = [r for r in rows if r[3]]
	md.append("## Выше порога: %d из %d" % (len(flagged), len(rows)))
	md.append("")
	md.append("| Герой | Клип | Руки ср./макс. | Ноги ср./макс. | Корпус ср./макс. | Где |")
	md.append("|---|---|---|---|---|---|")
	for h, name, res, bad in flagged[:80]:
		md.append("| %s | %s | %.0f / %.0f | %.0f / %.0f | %.0f / %.0f | %s |" % (h, name, res["руки"]["mean"],
			res["руки"]["max"], res["ноги"]["mean"], res["ноги"]["max"], res["корпус"]["mean"], res["корпус"]["max"],
			", ".join(bad)))
	md.append("")
	md.append("## Сдвиг рига (калибровка, градусы; вычтен из сравнения)")
	md.append("")
	md.append("Постоянный поворот сегмента героя относительно манекена во всех клипах — форма скелета, а не движение. "
		"Большой сдвиг корпуса или головы — роль кости «шея» / «макушка» в `<id>.json` стоит на другой кости.")
	md.append("")
	md.append("| Герой | " + " | ".join(SEGS) + " |")
	md.append("|---|" + "---|" * len(SEGS))
	for h in sorted(calib):
		md.append("| %s | %s |" % (h, " | ".join("%.0f" % calib[h].get(sg, 0) for sg in SEGS)))
	md.append("")
	md.append("## По клипам (среднее по всем героям)")
	md.append("")
	md.append("| Клип | Эталон | Руки | Ноги | Корпус |")
	md.append("|---|---|---|---|---|")
	for name in sorted(ref):
		vals = [report[h][name] for h in report if name in report[h]]
		if not vals:
			continue
		avg = {g: sum(v[g]["mean"] for v in vals) / len(vals) for g in GROUPS}
		md.append("| %s | %s | %.0f | %.0f | %.0f |" % (name, ref[name]["src"], avg["руки"], avg["ноги"], avg["корпус"]))
	with open(os.path.join(o["out"], "REFERENCE_REPORT.md"), "w", encoding="utf-8") as fh:
		fh.write("\n".join(md) + "\n")
	slim = {h: {n: {g: r[g] for g in GROUPS} for n, r in cl.items()} for h, cl in report.items()}
	with open(os.path.join(out_ref, "report.json"), "w", encoding="utf-8") as fh:
		json.dump(slim, fh, ensure_ascii=False, indent=0)
	worst = []
	for h, name, res, bad in rows[:int(o["sheets"])]:
		r = report[h][name]
		worst.append({"file": "%s__%s.png" % (h, name), "title": "%s · %s · эталон %s (серый) · руки %.0f°, ноги %.0f°, корпус %.0f°"
			% (h, name, ref[name]["src"], res["руки"]["mean"], res["ноги"]["mean"], res["корпус"]["mean"]),
			"ref": ref[name]["frames"], "got": r["_got"], "path": r["_path"]})
	with open(os.path.join(out_ref, "worst.json"), "w", encoding="utf-8") as fh:
		json.dump(worst, fh, ensure_ascii=False)
	print("ГОТОВО: строк %d, выше порога %d, всего %.0f с" % (len(rows), len(flagged), time.time() - t_start))
	return 0


def draw_sheets():
	o = args()
	out_ref = os.path.join(o["out"], "reference")
	os.makedirs(os.path.join(out_ref, "sheets"), exist_ok=True)
	worst = json.load(open(os.path.join(out_ref, "worst.json"), encoding="utf-8"))
	for w in worst:
		sheet(os.path.join(out_ref, "sheets", w["file"]), w["title"], w["ref"], w["got"], [tuple(p) for p in w["path"]])
	print("листов: %d" % len(worst))
	return 0


if __name__ == "__main__":
	sys.exit(main() if bpy is not None else draw_sheets())
