#!/usr/bin/env python3
"""Герой (или житель) из Meshy → игровая модель: один конвейер «модель Meshy с авто-ригом → герой».

Вход — GLB из Meshy: персонаж в T-позе с авто-ригом (скелет «SmartRigArmature», кости Bone_NNN), без анимаций,
обычно 20–25 МБ и 150–200 тыс. треугольников. Скелет НЕ перестраивается и не переименовывается: кости,
иерархия и их повороты покоя остаются родными (меняется только масштаб под рост), клипы пишутся прямо на них.
Для каждого героя пишет в assets/characters/:
  <id>.glb         — меш ~30 тыс. треугольников (meshoptimizer, как tools/decimate_glb.py: вершины не двигаются,
                     швы UV не рвутся), рост по полу (мужчины 1.8 м, женщины 1.7 м; --height), ноги на y = 0,
                     лицом в +Z, родной скелет Meshy, клипы героя (список HERO_CLIPS), материал без картинок.
  <id>.png         — цветовая текстура 2048×2048 (+ .png.import: VRAM-сжатие, мипмапы).
  <id>.json        — роли костей (голова, кисти, таз, …), хват оружия в пространстве кисти (grip_r/grip_l: центр
                     кулака и направление клинка), поворот арбалета в правой кисти (crossbow_rot), метка лица в
                     пространстве головы, клипы и их длины. CharacterModel берёт по нему кости для оружия и эффектов.
  <id>.glb.import  — встроенные картинки отбрасываются, LOD включены.

Как устроено (общий код с двуногими зверями — блок «biped» в tools/prepare_creatures.py):
  * Роли костей гуманоида Meshy (biped_roles): ноги — две ветки у земли, таз — их общий родитель, путь к макушке —
    позвоночник, грудь — кость с двумя боковыми ветками-руками (цепочка ≥ 4 костей, уходит в сторону; короткие ветки
    груди у женских ригов — не руки), дальше шея, голова и макушка. Если Meshy повесил руки выше плеч (на макушку,
    риг hero_assassin_f), biped_regraft_arms переносит их (и грудь, висящую на шее) на кость позвоночника не выше
    плеч — поза покоя та же, меняется только родитель. Рука: ключица, плечо,
    предплечье, кисть (запястье), ладонь; пальцы — ветки ладони: большой — ближайший к запястью, остальные по
    порядку спереди назад: указательный, средний, безымянный, мизинец.
  * Клипы — Quaternius Universal Animation Library 1 и 2 (CC0), перенос через глобальные повороты (HeroRetarget —
    BipedRetarget из prepare_creatures плюс пальцы и поворот кисти вокруг своей оси по линии «мизинец →
    указательный», чтобы кулак и оружие легли как у библиотеки; корень скелета Meshy вращается вместе с тазом).
    Бедро и голень в опорной позе — по направлениям библиотеки (как у героини: T-поза Meshy ставит ноги шире), стопы
    сохраняют поворот покоя, таз поднимается так, чтобы лодыжки остались на своей высоте. Корень по X/Z стоит на месте
    (перемещает игра), высота остаётся. Опорные стопы не скользят (IK бедро + голень; у действий, где таз библиотеки
    уходит дальше TRAVEL_PLANT — рывок, кувырок, тяжёлое комбо, — опоры не закрепляются, как у героини), низ меша
    не уходит под землю, Death заканчивается лёжа на земле.
  * Шаг и бег (Walking, Running) растянуты по времени так, чтобы скорость опорной стопы была ровно WALK_NATIVE /
    RUN_NATIVE из character_model.gd (игра ускоряет клип пропорционально скорости — без проскальзывания).
  * Wave (машет рукой: жители, приветствие) — процедурный: поверх Idle правая рука поднимается и машет, ладонь вперёд.
  * Хват оружия: центр кулака — у основания пальцев со стороны ладони, клинок — по линии «мизинец → указательный»
    (как GRIP_POS/GRIP_DIR у прежней героини со скелетом Mixamo). Арбалет — поворот в правой кисти, при котором в
    первом кадре Crossbow_Idle ложе смотрит вперёд, а дуги горизонтальны (как CROSSBOW_ROT).

Новый герой: модель Meshy с авто-ригом в T-позе (персонаж, «Rig» без анимаций), затем из корня репозитория:
  python3 -I tools/prepare_hero.py --ual1 <UAL1_Standard.glb> --ual2 <UAL2_Standard.glb> \\
      hero_assassin_f=<файл.glb> [hero_warrior_f=<…> …] [--preview <папка>] [--height 1.75]
  Слева от «=» — имя выходного файла (без расширения): hero_<профессия>_<пол> (модель в экипировке воинской профессии
  своей расы), hero_<раса>_<пол>_starter (Бродяга), npc_<id> для жителей; пол m/f в конце имени задаёт рост.
  Повторный запуск перезаписывает GLB, PNG и JSON. --preview — картинки-проверки (поза покоя и кадры клипов, оружие линиями) для просмотра глазами.
UAL: https://quaternius.itch.io/universal-animation-library и …-library-2 → «…[Standard].zip»,
  файлы Unreal-Godot/UAL1_Standard.glb и UAL2_Standard.glb (без _RM).
Зависимости: numpy, Pillow, meshoptimizer (как у prepare_creatures.py). Входные GLB — чужие данные: Python с -I.
"""
import argparse
import importlib.util
import io
import json
import math
import os
import sys

import numpy as np

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)


def _load(name: str):
	spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


pc = _load("prepare_creatures")
ra = _load("retarget_animations")

## Скорости, при которых шаг и бег идут без проскальзывания (как в character_model.gd).
WALK_NATIVE = 1.4
RUN_NATIVE = 4.2
## Рост по полу (м): весь меш, с волосами и ушами.
HEIGHT = {"m": 1.8, "f": 1.7}
TRIS = 30000
TEX = 2048
FPS = 30.0
## Действия, в которых таз библиотеки уходит дальше (кувырок, тяжёлое комбо, смерть), идут без закрепления опор
## (как у прежней героини); у остальных опоры закрепляются до того, как корень ставится на место.
TRAVEL_PLANT = 0.25
## В действиях опорой считается стопа у земли, которая движется по ней медленнее (м/с); быстрое скольжение стопы
## в выпаде (Sword_Slash, Sword_Dash) остаётся как в библиотеке.
MAX_SLIDE = 0.5

## Клипы героя: имя → (вид, [варианты: (библиотека, [клипы библиотеки подряд])]).
## Вид: loop — цикл на месте, walk/run — цикл шага/бега (скорость по WALK_NATIVE/RUN_NATIVE; из вариантов
## берётся тот, чья скорость ближе), act — действие (опоры стоят), death — смерть (лёжа на земле), wave — процедурный.
## Имена — как у прежней героини (ASSET_ACTIONS / ASSET_IDLE / ASSET_WALK / ASSET_RUN в character_model.gd).
HERO_CLIPS = {
	"Idle": ("loop", [("ual1", ["Idle_Loop"])]),
	"Walking": ("walk", [("ual1", ["Walk_Loop"])]),
	"Running": ("run", [("ual1", ["Jog_Fwd_Loop"]), ("ual1", ["Sprint_Loop"])]),
	"Sword_Idle": ("loop", [("ual1", ["Sword_Idle"])]),
	"Crossbow_Idle": ("loop", [("ual1", ["Pistol_Idle_Loop"])]),
	"Wave": ("wave", [("ual1", ["Idle_Loop"])]),
}
for _name, (_lib, _src, _rng) in ra.CLIPS.items():
	if _name not in HERO_CLIPS:
		HERO_CLIPS[_name] = ("death" if _name == "Death" else "act", [(_lib, _src)])
UAL = {"ual1": "", "ual2": ""}

FINGERS = ("index", "middle", "ring", "pinky")


# ---------- Роли костей ----------

def finger_roles(rig, roles: dict) -> dict:
	"""Пальцы каждой кисти: {"L"/"R": {"thumb"/"index"/…: [кости от основания]}} (пусто, если пальцев нет)."""
	out = {}
	for s, c in roles["arms"].items():
		hand = c[3]
		palm = c[-1]
		chains = []
		for r in rig.ch[palm]:
			ch = [r]
			while len(rig.ch[ch[-1]]) == 1:
				ch.append(rig.ch[ch[-1]][0])
			chains.append(ch)
		if len(chains) < 3:
			out[s] = {}
			continue
		wrist = rig.gpos[hand]
		thumb = min(chains, key=lambda ch: np.linalg.norm(rig.gpos[ch[0]] - wrist))
		rest = sorted([ch for ch in chains if ch is not thumb], key=lambda ch: -rig.gpos[ch[0], 2])
		names = {4: FINGERS, 3: ("index", "middle", "pinky"), 2: ("index", "pinky")}.get(len(rest), FINGERS[:len(rest)])
		d = {"thumb": thumb}
		for nm, ch in zip(names, rest):
			d[nm] = ch
		out[s] = d
	return out


# ---------- Перенос клипов ----------

class HeroRetarget(pc.BipedRetarget):
	"""BipedRetarget + корень скелета Meshy вместе с тазом, пальцы и поворот кисти вокруг своей оси."""

	def __init__(self, src, rig, roles: dict, fingers: dict):
		self.fingers = fingers
		super().__init__(ra, src, rig, roles)
		# Ноги в опорной позе прямее, чем в T-позе Meshy: таз поднимается/опускается так, чтобы лодыжки остались
		# на высоте покоя (как lift в retarget_animations.Retargeter)
		_Gq, Gp = self.fk(self.lref_q[None], rig.lpos[None].copy())
		ank = [c[2] for c in roles["legs"].values()]
		self.lift = float(rig.gpos[ank, 1].min() - Gp[0, ank, 1].min())

	def clip(self, lib_names: list, loop: bool = False) -> tuple:
		times, Lq, Lt = super().clip(lib_names, loop)
		Lt[:, self.roles["root"], 1] += self.lift
		return times, Lq, Lt

	def _lib(self, name: str) -> int:
		i = self.src.find(name)
		if i < 0:
			raise ValueError("в библиотеке нет кости %s" % name)
		return i

	def _build_ref(self) -> None:
		rig, roles, src = self.rig, self.roles, self.src
		# Корень Meshy (Bone_000) несёт веса низа таза: он поворачивается вместе с тазом
		if roles["root"] != roles["hips"]:
			self.map[roles["root"]] = self._lib("pelvis")
		for s, fs in self.fingers.items():
			for f, ch in fs.items():
				for k, b in enumerate(ch[:3]):
					i = src.find("%s_%02d_%s" % (f, k + 1, s.lower()))
					if i >= 0:
						self.map[b] = i
		B = rig.B
		G = np.zeros((B, 4))
		gpos = rig.gpos
		# Выравнивание направлений: кость → (вектор к «ребёнку» в её пространстве покоя, кость библиотеки, её ребёнок).
		# Ноги — как у героини (retarget_animations.ALIGN): бедро и голень по направлениям библиотеки (T-поза Meshy
		# ставит ноги шире), стопа и пальцы сохраняют мировой поворот покоя («стоит на земле»)
		align = {}
		feet = set()
		for s, c in roles["legs"].items():
			sl = s.lower()
			align[c[0]] = (rig.lpos[c[1]], "thigh_" + sl, "calf_" + sl)
			align[c[1]] = (rig.lpos[c[2]], "calf_" + sl, "foot_" + sl)
			feet.update(c[2:4])

		def local(b: int, p_world: np.ndarray) -> np.ndarray:
			return rig.grot[b].T @ (p_world - gpos[b])

		twist = {}
		for s, c in roles["arms"].items():
			sl = s.lower()
			fs = self.fingers.get(s, {})
			for k, (sa, sb) in enumerate([("clavicle_", "upperarm_"), ("upperarm_", "lowerarm_"), ("lowerarm_", "hand_")]):
				align[c[k]] = (rig.lpos[c[k + 1]], sa + sl, sb + sl)
			hand = c[3]
			if "middle" in fs:
				align[hand] = (local(hand, gpos[fs["middle"][0]]), "hand_" + sl, "middle_01_" + sl)
			elif len(c) > 4:
				align[hand] = (rig.lpos[c[4]], "hand_" + sl, "middle_01_" + sl)
			if "index" in fs and "pinky" in fs:
				twist[hand] = (local(hand, gpos[fs["index"][0]]) - local(hand, gpos[fs["pinky"][0]]),
					"pinky_01_" + sl, "index_01_" + sl)
			for f, ch in fs.items():
				for k in range(min(2, len(ch) - 1)):
					sb = "%s_%02d_%s" % (f, k + 2, sl)
					if src.find(sb) < 0:
						sb = "%s_04_leaf_%s" % (f, sl)
					if src.find(sb) >= 0 and ch[k] in self.map:
						align[ch[k]] = (rig.lpos[ch[k + 1]], "%s_%02d_%s" % (f, k + 1, sl), sb)
		keep_world = {roles["root"], roles["hips"], roles["head"]} | set(roles["spine"]) | set(roles["neck"]) | feet
		for b in range(B):
			p = rig.parent[b]
			if p < 0 or b in keep_world:
				G[b] = self.rest_q[b]
			else:
				G[b] = ra.qnorm(ra.qmul(G[p], self.lrest_q[b]))
			if b in align:
				vec, sa, sb = align[b]
				d_t = ra.qrot(G[b], vec)
				d_s = self.sp0[self._lib(sb)] - self.sp0[self._lib(sa)]
				G[b] = ra.qnorm(ra.qmul(ra.q_between(d_t, d_s), G[b]))
			if b in twist:
				vec, sa, sb = twist[b]
				axis = ra.qrot(G[b], align[b][0])
				axis = axis / np.linalg.norm(axis)
				cur = ra.qrot(G[b], vec)
				want = self.sp0[self._lib(sb)] - self.sp0[self._lib(sa)]
				cur = cur - axis * np.dot(cur, axis)
				want = want - axis * np.dot(want, axis)
				if np.linalg.norm(cur) > 1e-6 and np.linalg.norm(want) > 1e-6:
					cur, want = cur / np.linalg.norm(cur), want / np.linalg.norm(want)
					a = math.atan2(float(np.dot(np.cross(cur, want), axis)), float(np.dot(cur, want)))
					G[b] = ra.qnorm(ra.qmul(ra.q_axis_angle(axis, a), G[b]))
		self.ref_q = G
		Lr = np.zeros((B, 4))
		for b in range(B):
			p = rig.parent[b]
			Lr[b] = G[b] if p < 0 else ra.qnorm(ra.qmul(ra.qconj(G[p]), G[b]))
		self.lref_q = Lr


def stance_speed(rt, times: np.ndarray, Lq: np.ndarray, Lt: np.ndarray) -> float:
	"""Скорость опорной стопы цикла шага (м/с): медиана скорости назад, пока стопа у земли."""
	_Gq, Gp = rt.fk(Lq, Lt)
	H = float(rt.rig.gpos[:, 1].max())
	vs = []
	for _s, b in rt.contact.items():
		y = Gp[:, b, 1]
		dz = np.gradient(Gp[:, b, 2], times)
		st = (y < y.min() + 0.025 * H) & (dz < 0.0)
		vs.extend((-dz[st]).tolist())
	return float(np.median(vs)) if vs else 0.0


def pin_xz(rt, Lt: np.ndarray) -> None:
	"""Корень по X/Z — в позе покоя (клипы на месте, перемещает игра)."""
	r0 = rt.roles["root"]
	Lt[:, r0, 0] = rt.rig.lpos[r0, 0]
	Lt[:, r0, 2] = rt.rig.lpos[r0, 2]


def wave_pose(rt, times: np.ndarray, Lq: np.ndarray, Lt: np.ndarray) -> None:
	"""Поверх покоя: правая рука поднимается в сторону-вверх, предплечье машет, ладонь смотрит вперёд."""
	rig, roles = rt.rig, rt.roles
	c = roles["arms"]["R"]
	up, fore, hand = c[1], c[2], c[3]
	# Нормаль ладони в пространстве кисти: в T-позе ладонь вниз
	n_loc = rig.grot[hand].T @ np.array([0.0, -1.0, 0.0])
	T = float(times[-1])
	ident = np.array([0.0, 0.0, 0.0, 1.0])

	def turn(f: int, b: int, q: np.ndarray, Gq: np.ndarray) -> None:
		g = ra.qnorm(ra.qmul(q, Gq[b]))
		Lq[f, b] = ra.qnorm(ra.qmul(ra.qconj(Gq[rig.parent[b]]), g))

	for f, t in enumerate(times):
		e = pc.env(float(t), 0.0, 0.45, T - 0.45, T)
		if e <= 0.0:
			continue
		Gq, Gp = rt.fk(Lq[f:f + 1], Lt[f:f + 1])
		Gq, Gp = Gq[0], Gp[0]
		want1 = np.array([-0.55, 0.62, 0.3])
		q = ra.q_between(Gp[fore] - Gp[up], want1)
		turn(f, up, ra.slerp(ident, q, np.array(e)), Gq)
		Gq, Gp = rt.fk(Lq[f:f + 1], Lt[f:f + 1])
		Gq, Gp = Gq[0], Gp[0]
		sw = math.sin(2.0 * math.pi * 1.8 * max(0.0, float(t) - 0.3))
		want2 = np.array([-0.12 - 0.42 * sw, 1.0, 0.18])
		q = ra.q_between(Gp[hand] - Gp[fore], want2)
		turn(f, fore, ra.slerp(ident, q, np.array(e)), Gq)
		# Ладонь вперёд (+Z): поворот предплечья вокруг своей оси
		Gq, Gp = rt.fk(Lq[f:f + 1], Lt[f:f + 1])
		Gq, Gp = Gq[0], Gp[0]
		axis = Gp[hand] - Gp[fore]
		axis = axis / np.linalg.norm(axis)
		cur = ra.qrot(Gq[hand], n_loc)
		want = np.array([0.0, 0.0, 1.0])
		cur = cur - axis * np.dot(cur, axis)
		want = want - axis * np.dot(want, axis)
		if np.linalg.norm(cur) > 1e-6 and np.linalg.norm(want) > 1e-6:
			cur, want = cur / np.linalg.norm(cur), want / np.linalg.norm(want)
			a = math.atan2(float(np.dot(np.cross(cur, want), axis)), float(np.dot(cur, want)))
			turn(f, fore, ra.q_axis_angle(axis, a * e), Gq)


def make_clip(rt, mesh: dict, name: str, kind: str, variants: list, libs_rt: dict) -> dict:
	best = None
	for lib, names in variants:
		r = libs_rt[lib]
		times, Lq, Lt = r.clip(names, False)
		root = Lt[:, r.roles["root"]]
		travel = float(np.max(np.hypot(root[:, 0] - root[0, 0], root[:, 2] - root[0, 2])))
		if kind in ("walk", "run"):
			pin_xz(r, Lt)
		v = stance_speed(r, times, Lq, Lt) if kind in ("walk", "run") else 0.0
		native = WALK_NATIVE if kind == "walk" else RUN_NATIVE
		score = abs(math.log(max(v, 1e-3) / native)) if kind in ("walk", "run") else 0.0
		if best is None or score < best[0]:
			best = (score, lib, names, r, times, Lq, Lt, v, travel)
	_score, lib, names, r, times, Lq, Lt, v, travel = best
	cl = {"name": name, "lib": "%s:%s" % (lib, "+".join(names)), "loop": kind in ("loop", "walk", "run")}
	speed, short = 0.0, 0.0
	if kind in ("walk", "run"):
		native = WALK_NATIVE if kind == "walk" else RUN_NATIVE
		times = times * (v / native)
		cl["stretch"] = v / native
		speed, short = pc.biped_plant(r, times, Lq, Lt, native)
	elif kind == "wave":
		keep = times <= 2.2 + 1e-6
		times, Lq, Lt = times[keep], Lq[keep], Lt[keep]
		wave_pose(r, times, Lq, Lt)
		cl["lib"] = "процедурный (поверх %s)" % cl["lib"]
		cl["loop"] = False
		_v, short = pc.biped_plant(r, times, Lq, Lt, None)
	elif kind != "death" and travel < TRAVEL_PLANT:
		_v, short = pc.biped_plant(r, times, Lq, Lt, None, MAX_SLIDE)
	# Действия закрепляют опоры там, где таз ещё ходит как в библиотеке, и только потом встают на место: закреплённая
	# стопа не тянется за уехавшим тазом, а смещается вместе с ним (как у героини)
	pin_xz(r, Lt)
	cl["travel"] = travel
	lift = pc.biped_ground(r, mesh, Lq, Lt, kind == "death")
	cl.update({"T": float(times[-1]), "times": times, "rot": Lq, "trans": Lt, "short": short, "lift": lift})
	if kind in ("walk", "run"):
		cl["speed"] = speed
	return cl


# ---------- Хват оружия ----------

def grips(rig, roles: dict, fingers: dict) -> dict:
	"""Центр кулака и направление клинка в пространстве кисти (для обеих рук)."""
	out = {}
	for s, c in roles["arms"].items():
		hand = c[3]
		w = rig.gpos[hand]
		fs = fingers.get(s, {})
		roots = [fs[f][0] for f in FINGERS if f in fs]
		if roots:
			knuck = rig.gpos[roots].mean(0)
		else:
			knuck = rig.gpos[c[-1]] if len(c) > 4 else w + (w - rig.gpos[c[2]]) * 0.35
		a = knuck - w
		L = float(np.linalg.norm(a))
		a = a / L
		if "index" in fs and "pinky" in fs:
			across = rig.gpos[fs["index"][0]] - rig.gpos[fs["pinky"][0]]
		else:
			across = np.array([0.0, 0.0, 1.0])
		across = across - a * np.dot(across, a)
		across /= np.linalg.norm(across)
		n = np.cross(a, across)
		if n[1] > 0.0:
			n = -n
		pos = w + a * (0.8 * L) + n * 0.022
		d = across + 0.15 * a
		d /= np.linalg.norm(d)
		R = rig.grot[hand]
		out[s] = {"pos": R.T @ (pos - w), "dir": R.T @ d}
	return out


# ---------- Запись ----------

PNG_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/characters/{name}.png"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
detect_3d/compress_to=0
"""

GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://assets/characters/{name}.glb"

[params]

gltf/embedded_image_handling=0
meshes/generate_lods=true
"""


def r3(v) -> list:
	return [round(float(x), 4) for x in v]


def build(cid: str, src_path: str, height: float, out_dir: str, preview: str = "") -> dict:
	from PIL import Image
	libs = {k: ra.Skeleton(ra.Glb(p)) for k, p in UAL.items()}
	print("== %s: %s" % (cid, src_path))
	src = pc.load_source(src_path)
	g = pc.to_game_space(src, height, pc.biped_yaw(src))
	g = pc.reorder(g, pc.topo_order(g["parent"]))
	# Руки, повешенные Meshy выше плеч (на макушку), — на грудь; у обычного рига ничего не меняется
	g["parent"], moved = pc.biped_regraft_arms(g["parent"], g["gpos"], height)
	if moved:
		print("   руки висели выше плеч — перенесены на грудь: %s" % ", ".join(g["names"][b] for b in moved))
		g = pc.reorder(g, pc.topo_order(g["parent"]))
	roles = pc.biped_roles(g["names"], g["parent"], g["gpos"], height)
	print("   поворот %d°, масштаб %.4f, исходный меш %d треуг., костей %d" % (
		g["yaw_deg"], g["scale"], len(g["tris"]), len(g["names"])))
	mesh = pc.simplify_mesh(g, TRIS)
	st = pc.mesh_stats(mesh["pos"], mesh["tris"])
	print("   упрощено: %d треуг., %d вершин, открытых рёбер %d (было %d), ошибка %.4f" % (
		st["tris"], st["verts"], st["open_edges"], pc.mesh_stats(g["pos"], g["tris"])["open_edges"], mesh["simplify_error"]))
	k = height / float(mesh["pos"][:, 1].max() - mesh["pos"][:, 1].min())
	shift = np.array([0.0, -float(mesh["pos"][:, 1].min()) * k, 0.0])
	mesh["pos"] = mesh["pos"] * k + shift
	g["gpos"] = g["gpos"] * k + shift
	# Имена костей — родные (Bone_NNN), роли — по иерархии и позе
	rig = pc.Rig(g["names"], g["parent"], g["grot"], g["gpos"])
	fingers = finger_roles(rig, roles)
	nm = rig.names
	for s in ("L", "R"):
		print("   %s: нога %s; рука %s; пальцы %s" % (s, " ".join(nm[b] for b in roles["legs"][s]),
			" ".join(nm[b] for b in roles["arms"][s]),
			", ".join("%s %s" % (f, "/".join(nm[b] for b in ch)) for f, ch in fingers[s].items())))
	rts = {k2: HeroRetarget(s2, rig, roles, fingers) for k2, s2 in libs.items()}
	print("   масштаб смещения таза %.3f, подъём таза под опорную позу %.3f м" % (rts["ual1"].k, rts["ual1"].lift))
	clips = []
	for name, (kind, variants) in HERO_CLIPS.items():
		cl = make_clip(rts[variants[0][0]], mesh, name, kind, variants, rts)
		extra = ""
		if "speed" in cl:
			extra = ", скорость %.2f м/с (темп ×%.2f)" % (cl["speed"], 1.0 / cl["stretch"])
		elif cl["travel"] >= TRAVEL_PLANT:
			extra = ", таз уходит на %.2f м — опоры не закреплены" % cl["travel"]
		print("   %-15s %.2f с ← %s%s; опора не достала %.3f м, подъём %.3f м" % (
			name, cl["T"], cl["lib"], extra, cl["short"], cl["lift"]))
		clips.append(cl)
	gr = grips(rig, roles, fingers)
	# Арбалет: в первом кадре Crossbow_Idle ложе (ось −Z арбалета) — вперёд модели (+Z), дуги горизонтально
	cbi = next(c for c in clips if c["name"] == "Crossbow_Idle")
	rt = rts["ual1"]
	Gq, _Gp = rt.fk(cbi["rot"][:1], cbi["trans"][:1])
	hand_r = roles["arms"]["R"][3]
	cb = ra.qnorm(ra.qmul(ra.qconj(Gq[0, hand_r]), np.array([0.0, 1.0, 0.0, 0.0])))
	head = roles["head"]
	face = rig.grot[head].T @ np.array([0.0, 0.08, 0.1])

	os.makedirs(out_dir, exist_ok=True)
	glb_path = os.path.join(out_dir, cid + ".glb")
	pc.write_glb(glb_path, cid, rig, mesh, clips)
	tex = None
	if src["image"] is not None:
		im = Image.open(io.BytesIO(src["image"])).convert("RGB")
		if im.size != (TEX, TEX):
			im = im.resize((TEX, TEX), Image.LANCZOS)
		im.save(os.path.join(out_dir, cid + ".png"), optimize=True)
		tex = np.asarray(im.resize((1024, 1024), Image.LANCZOS))
	for ext, tpl in ((".png.import", PNG_IMPORT), (".glb.import", GLB_IMPORT)):
		p = os.path.join(out_dir, cid + ext)
		if not os.path.exists(p):
			with open(p, "w") as f:
				f.write(tpl.format(name=cid))
	lo, hi = mesh["pos"].min(0), mesh["pos"].max(0)
	arms = roles["arms"]
	meta = {
		"source": os.path.basename(src_path),
		"height": round(float(hi[1] - lo[1]), 3),
		"bounds": [r3(lo), r3(hi)],
		"tris": int(len(mesh["tris"])),
		"verts": int(len(mesh["pos"])),
		"bones": {
			"root": nm[roles["root"]], "hips": nm[roles["hips"]], "chest": nm[roles["chest"]],
			"neck": nm[roles["neck"][0]] if roles["neck"] else nm[roles["chest"]], "head": nm[head],
			"head_end": nm[roles["head_end"][0]] if roles["head_end"] else nm[head],
			"hand_r": nm[arms["R"][3]], "hand_l": nm[arms["L"][3]],
			"foot_r": nm[roles["legs"]["R"][2]], "foot_l": nm[roles["legs"]["L"][2]],
			"spine": [nm[b] for b in roles["spine"]],
			"arms": {s: [nm[b] for b in c] for s, c in sorted(arms.items())},
			"legs": {s: [nm[b] for b in c] for s, c in sorted(roles["legs"].items())},
			"fingers": {s: {f: [nm[b] for b in ch] for f, ch in fs.items()} for s, fs in sorted(fingers.items())},
		},
		"grip_r": {"pos": r3(gr["R"]["pos"]), "dir": r3(gr["R"]["dir"])},
		"grip_l": {"pos": r3(gr["L"]["pos"]), "dir": r3(gr["L"]["dir"])},
		"crossbow_rot": r3(cb),
		"face": r3(face),
		"walk_speed": WALK_NATIVE,
		"run_speed": RUN_NATIVE,
		"clips": {c["name"]: {"length": round(c["T"], 3), "loop": c["loop"], "source": c["lib"]} for c in clips},
	}
	with open(os.path.join(out_dir, cid + ".json"), "w") as f:
		json.dump(meta, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	print("   записано: %s (%.1f МБ), рост %.3f м, %d треуг." % (glb_path, os.path.getsize(glb_path) / 1e6,
		meta["height"], meta["tris"]))
	ok = verify(rt, rig, roles, mesh, clips, meta)
	if preview:
		write_preview(preview, cid, rt, rig, mesh, tex, clips, gr, cb)
	return {"ok": ok, "meta": meta}


def verify(rt, rig, roles: dict, mesh: dict, clips: list, meta: dict) -> bool:
	"""Проверка по всем кадрам: низ меша не под землёй (кроме кувырка и смерти — там допускается касание),
	голова выше тазобедренных суставов (корней ног) в покое и шаге, в конце Death — лёжа (голова ниже 0.6 м).
	Корни ног, а не кость таза: у части ригов Meshy ноги висят на кости живота (hero_assassin_f — на 0.14 м выше
	суставов), и наклон бега сближал бы голову с ней."""
	ok = True
	head = roles["head"]
	thighs = [c[0] for c in roles["legs"].values()]
	for cl in clips:
		Gq, Gp = rt.fk(cl["rot"], cl["trans"])
		Gr = pc.qm_batch(Gq)
		F = len(cl["times"])
		step = max(1, F // 12)
		miny = min(float(pc.skin_points(rig, mesh["pos"], mesh["joints"], mesh["weights"], Gr[f], Gp[f])[:, 1].min())
			for f in range(0, F, step))
		bad = miny < -0.01
		if cl["name"] in ("Idle", "Walking", "Running") and not (Gp[:, head, 1] > Gp[:, thighs, 1].max(1) + 0.3).all():
			bad = True
		if cl["name"] == "Death" and Gp[-1, head, 1] > 0.6:
			bad = True
		if bad:
			ok = False
			print("   ПЛОХО: %s — низ меша %.3f м, голова %.2f…%.2f м" % (cl["name"], miny, Gp[:, head, 1].min(),
				Gp[:, head, 1].max()))
	h = meta["height"]
	print("   проверка: %s (рост %.2f м, голова в покое %.2f м)" % ("в порядке" if ok else "есть замечания", h,
		float(rig.gpos[head, 1])))
	return ok


# ---------- Картинки-проверки ----------

BOX = (np.array([-1.0, -0.05, -1.0]), np.array([1.0, 1.95, 1.0]))
PREVIEW_CLIPS = ["Idle", "Walking", "Running", "Sword_Slash", "Sword_Slash_B", "Crossbow_Idle", "Crossbow_Shoot",
	"Cast", "Dodge", "Death", "Wave", "Pickup"]


def _project(p: np.ndarray, view: str, size: int) -> tuple:
	(ax, sx), (ay, sy), _ = pc.VIEWS[view]
	lo, hi = BOX
	span = float((hi - lo).max()) * 1.08
	cx, cy = (lo[ax] + hi[ax]) * 0.5, (lo[ay] + hi[ay]) * 0.5
	return (((p[ax] - cx) * sx / span + 0.5) * (size - 1), (0.5 - (p[ay] - cy) * sy / span) * (size - 1))


def write_preview(out: str, cid: str, rt, rig, mesh: dict, tex, clips: list, gr: dict, cb: np.ndarray) -> None:
	from PIL import Image, ImageDraw
	os.makedirs(out, exist_ok=True)
	size = 230
	views = ("front", "side")
	by = {c["name"]: c for c in clips}
	rows = []
	hands = {s: rt.roles["arms"][s][3] for s in ("L", "R")}
	for name in ["rest"] + PREVIEW_CLIPS:
		if name == "rest":
			frames = [(rig.gpos, np.array([ra.qnorm(pc.m_to_q(m)) for m in rig.grot]), "rest")]
		else:
			cl = by[name]
			F = len(cl["times"])
			Gq, Gp = rt.fk(cl["rot"], cl["trans"])
			frames = [(Gp[f], Gq[f], "%.2f" % cl["times"][f]) for f in np.linspace(0, F - 1, 4).astype(int)]
		row = Image.new("RGB", (size * len(views) * len(frames), size + 14), (255, 255, 255))
		d = ImageDraw.Draw(row)
		d.text((4, size), "%s %s" % (cid, name), fill=(0, 0, 0))
		for fi, (gp, gq, lab) in enumerate(frames):
			Gr = pc.qm_batch(gq)
			v = pc.skin_points(rig, mesh["pos"], mesh["joints"], mesh["weights"], Gr, gp)
			im = pc.render_mesh(v, mesh["tris"], mesh["uv"], tex, views=views, size=size, samples=140000, box=BOX)
			dd = ImageDraw.Draw(im)
			cross = name.startswith("Crossbow")
			for s in ("R",) if cross else ("R", "L"):
				h = hands[s]
				base = gp[h] + Gr[h] @ gr[s]["pos"]
				if cross:
					tip = base + Gr[h] @ (pc.q_to_m(cb) @ np.array([0.0, 0.0, -0.45]))
					col = (40, 60, 230)
				else:
					tip = base + Gr[h] @ gr[s]["dir"] * 0.75
					col = (230, 30, 30) if s == "R" else (230, 150, 0)
				for vi, vw in enumerate(views):
					a = _project(base, vw, size)
					b = _project(tip, vw, size)
					dd.line([(a[0] + vi * size, a[1]), (b[0] + vi * size, b[1])], fill=col, width=3)
			row.paste(im, (fi * size * len(views), 0))
			d.text((fi * size * len(views) + 4, 2), lab, fill=(0, 0, 0))
		rows.append(row)
	W = max(r.size[0] for r in rows)
	sheet = Image.new("RGB", (W, sum(r.size[1] for r in rows)), (255, 255, 255))
	y = 0
	for r in rows:
		sheet.paste(r, (0, y))
		y += r.size[1]
	p = os.path.join(out, cid + "_preview.png")
	sheet.save(p)
	print("   картинка: %s" % p)


def main() -> None:
	ap = argparse.ArgumentParser(description="Герой из Meshy (авто-риг, T-поза) → игровая модель с клипами UAL")
	ap.add_argument("sources", nargs="+", help="имя=путь к GLB из Meshy; имя — выходной файл: hero_<профессия>_<m|f>, hero_<раса>_<m|f>_starter, npc_<id>")
	ap.add_argument("--ual1", required=True, help="UAL1_Standard.glb (Quaternius)")
	ap.add_argument("--ual2", required=True, help="UAL2_Standard.glb (Quaternius)")
	ap.add_argument("--out", default=os.path.join(ROOT, "assets", "characters"), help="куда писать")
	ap.add_argument("--height", type=float, default=0.0, help="рост, м (по умолчанию по полу в id: m 1.8, f 1.7)")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок")
	args = ap.parse_args()
	UAL.update({"ual1": args.ual1, "ual2": args.ual2})
	ok = True
	for s in args.sources:
		if "=" not in s:
			ap.error("ждём id=путь, получено %r" % s)
		cid, path = s.split("=", 1)
		h = args.height
		if h <= 0.0:
			sex = cid.replace("_starter", "").rsplit("_", 1)[-1]
			h = HEIGHT.get(sex, HEIGHT["m"])
		ok = build(cid, path, h, args.out, args.preview)["ok"] and ok
	print("ИТОГ: %s" % ("всё в порядке" if ok else "есть замечания (см. ПЛОХО выше)"))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
