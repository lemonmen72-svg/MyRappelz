#!/usr/bin/env python3
"""Движения с манекенов Meshy (скелет Mixamo) → герои игры (родной скелет Meshy и прежняя героиня со скелетом Mixamo).

Вход — GLB-манекены, на которые Максим в Meshy накинул движения из анимационной библиотеки Meshy (кости
«mixamorig:*», один меш, клипы с именами Meshy). Выход — те же GLB героев в assets/characters/: к их клипам
(перенос UAL от tools/prepare_hero.py / tools/retarget_animations.py) дописываются клипы MQ_CLIPS с приставкой
«Mq_», в <id>.json — их длина и момент удара (clips.<имя>.hit, с). Повторный запуск заменяет только свои клипы
(помечены extras.mannequin), меш, скелет, материал и прежние клипы не трогаются.

Как переносится (тот же путь, что у клипов UAL — HeroRetarget из prepare_hero.py):
  * MixamoSource — скелет манекена под именами костей UAL (pelvis, spine_01, upperarm_l, index_01_l, …), поэтому
    HeroRetarget/BipedRetarget работают как с библиотекой Quaternius: опорная поза героя довёрнута по направлениям
    костей манекена в позе покоя (T-поза), руки, кисти (поворот вокруг оси по линии «мизинец → указательный») и пальцы
    — по манекену, бедро и голень — по направлениям манекена, стопы сохраняют поворот покоя.
  * Отрезок клипа [t0, t1] (без долгих пауз в начале и в конце), затем как у prepare_hero.make_clip: опорные стопы
    не скользят (IK бедро + голень, pc.biped_plant; у клипов, где таз уходит дальше TRAVEL_PLANT, — без закрепления),
    корень по X/Z — в позе покоя (клип на месте; высота остаётся — прыжок, присед), низ меша не под землёй,
    Dead — в конце лёжа на земле.
  * Темп: время клипа сжимается кусочно-линейно — замах до удара (hit) за pre секунд, после удара — за post секунд
    (атаки укладываются в обычный интервал атаки, умения — 1–2 с); ускорение ≥ 1 (клип не растягивается).
    Ключи — все кадры исходника (30 к/с) в новом времени, прореживание только без видимой потери: ключ убирается,
    если он восстанавливается из соседних с ошибкой < ROT_TOL / POS_TOL.
  * Момент удара: hit в спецификации (с исходника) или самая быстрая кисть внутри отрезка.

Запуск из корня репозитория (Python с -I: входные GLB — чужие данные):
  python3 -I tools/retarget_mannequin.py --m1 <m1.glb> --m2 <m2.glb> --m3 <m3.glb> [герой.glb …]
      без списка героев — все assets/characters/hero_*.glb и dark_elf_wanderer.glb;
      --preview <папка> — картинки-проверки (кадры каждого клипа, удар отмечен, оружие линиями);
      --check — без записи; --survey <папка> — исходные клипы целиком (выбор отрезков, один герой).
  После tools/prepare_hero.py (он пишет GLB героя заново, без этих клипов) — запустить снова.
Зависимости: numpy, Pillow (как у prepare_hero.py).
"""
import argparse
import glob
import importlib.util
import json
import math
import os
import re
import sys

import numpy as np

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)


def _load(name: str):
	spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


ph = _load("prepare_hero")
pc = ph.pc
ra = ph.ra

FPS = 30.0
## Прореживание ключей: поворот (рад, угол между кватернионами) и сдвиг (м) — ниже порога глаз не заметит.
ROT_TOL = 0.0015
POS_TOL = 0.0005
TAG = "mannequin"
## Переступание на месте (plant_inplace): перенос стопы почти без отрыва дальше STEP_MIN / 4 (м) идёт дугой высотой
## STEP_LIFT × сдвиг (0.03…0.14 м).
STEP_MIN = 0.06
STEP_LIFT = 0.3
## Стопа «у земли» — не выше своего минимума в клипе + STEP_LOW, м; шаг из шарканья длится STEP_TIME, с.
STEP_LOW = 0.05
STEP_TIME = 0.3
## …и не выше высоты опоры в покое + STEP_GROUND (стопа, что весь клип в воздухе, у земли не бывает), м.
STEP_GROUND = 0.08
## Опора стопы в исходнике: у земли, медленнее STANCE_SPEED (м/с) и не короче STANCE_MIN кадров.
STANCE_SPEED = 0.3
STANCE_MIN = 4
STANCE_GAP = 2
## Предел проверки ground_slide (как в tests/test_hero_models.gd), м.
GROUND_SLIDE = 0.12
GROUND_NEAR = 0.04
## Клипы, где стопы законно едут или не достают земли: кручение на колене, прыжки с ударом (проверки опор не для них).
FREE_FEET = {"Mq_Blade_Spin", "Mq_Judgment", "Mq_Leap_Slam", "Mq_Jump"}

## Клипы: имя в GLB → (манекен, клип Meshy («A+B» — подряд), t0, t1, вид, pre, post, hit).
##   t0/t1 — отрезок исходника (с); вид: act — действие, death — смерть (лёжа на земле);
##   pre/post — длительность до удара и после него в игре (с; None — без сжатия этой части);
##   hit — момент удара в исходнике (с; None — самая быстрая кисть в отрезке).
## Комбо Meshy разрезаны по ударам: части идут подряд (конец одной — начало следующей), обычные атаки чередуют их
## по кругу (CharacterModel.MQ_ATTACKS) — серия атак складывается в целое комбо. Назначение — в комментарии.
MQ_CLIPS = {
	# --- Обычные атаки ближнего боя (части комбо, ~0.7–1 с; игра подгоняет темп под интервал атаки) ---
	"Mq_Sword_A1": ("m3", "Triple_Combo_Attack", 0.0, 1.05, "act", 0.35, 0.4, 0.72),  # меч: 1-й удар тройки
	"Mq_Sword_A2": ("m3", "Triple_Combo_Attack", 1.05, 1.85, "act", 0.3, 0.3, 1.5),  # 2-й удар
	"Mq_Sword_A3": ("m3", "Triple_Combo_Attack", 1.85, 3.4, "act", 0.3, 0.6, 2.22),  # 3-й удар и возврат
	"Mq_Combo_B1": ("m3", "Weapon_Combo_2", 0.2, 1.4, "act", 0.4, 0.3, 1.1),  # топор/булава/меч со щитом
	"Mq_Combo_B2": ("m3", "Weapon_Combo_2", 1.4, 2.45, "act", 0.35, 0.35, 2.0),
	"Mq_Combo_B3": ("m3", "Weapon_Combo_2", 2.45, 4.3, "act", 0.35, 0.7, 3.0),
	"Mq_Dual_A1": ("m2", "Double_Combo_Attack", 0.0, 0.95, "act", 0.35, 0.3, 0.62),  # два клинка: удар снизу
	"Mq_Dual_A2": ("m2", "Double_Combo_Attack", 0.95, 2.6, "act", 0.4, 0.55, 1.68),  # удар сверху
	"Mq_Left_Slash": ("m3", "Left_Slash", 0.3, 2.1, "act", 0.4, 0.5, 1.3),  # косой удар справа налево
	"Mq_Thrust": ("m3", "Thrust_Slash", 0.1, 1.25, "act", 0.3, 0.35, 0.72),  # выпад (кинжал, копьё)
	"Mq_Heavy_Swing": ("m3", "Heavy_Hammer_Swing", 0.25, 1.83, "act", 0.55, None, 1.5),  # двуручное: сверху вниз
	"Mq_Axe_Spin": ("m2", "Axe_Spin_Attack", 0.0, 2.1, "act", 0.5, 0.6, 0.9),  # удар с разворота
	# --- Умения ближнего боя (1–2 с) ---
	"Mq_Axe_Chop": ("m2", "Charged_Axe_Chop", 3.0, 5.3, "act", 0.6, 0.6, 4.4),  # заряженный рубящий
	"Mq_Charged_Slash": ("m2", "Charged_Slash", 0.0, 2.0, "act", 0.7, 0.5, 1.15),  # укол и мощный взмах
	"Mq_Judgment": ("m2", "Sword_Judgment", 0.2, 2.7, "act", 0.65, 0.75, 1.2),  # прыжок с ударом сверху
	"Mq_Leap_Slam": ("m2", "Attack", 0.1, 2.4, "act", 0.65, 0.7, 1.12),  # прыжок и удар в землю
	"Mq_Blade_Spin": ("m2", "Double_Blade_Spin", 0.1, 2.0, "act", 0.6, 0.6, 1.0),  # кручение двумя клинками
	"Mq_Reap": ("m1", "Reaping_Swing", 2.0, 4.9, "act", 0.7, 0.8, 3.3),  # широкие взмахи (копьё)
	"Mq_Ground_Slam": ("m1", "Charged_Ground_Slam", 0.0, 3.0, "act", 0.75, 0.75, 1.62),  # удар по земле
	"Mq_Kick": ("m3", "Simple_Kick", 0.2, 2.1, "act", 0.45, 0.55, 1.0),  # пинок (не подключён)
	"Mq_Jump": ("m2", "Basic_Jump", 1.2, 3.4, "act", None, None, 1.9),  # прыжок на месте (не подключён)
	# --- Лук и арбалет ---
	"Mq_Bow_Shot": ("m2", "Archery_Shot_1+m3:Archery_Shot_3", 0.0, 1.67, "act", 0.6, 0.35, 1.2),  # стрела из колчана
	"Mq_Bow_Draw": ("m3", "Draw_and_Shoot_from_Back_2", 0.1, 4.9, "act", 1.1, 0.45, 4.0),  # долгое прицеливание
	"Mq_Reload": ("m1", "Standing_Reload", 0.5, 2.8, "act", 0.6, 0.6, 1.5),  # арбалет: перезарядка
	# --- Магия (посох — обычные атаки A/B/C, остальное — умения) ---
	"Mq_Cast_A": ("m1", "mage_soell_cast", 0.0, 1.8, "act", 0.35, 0.5, 0.62),  # правая рука вверх
	"Mq_Cast_B": ("m1", "mage_soell_cast_4", 0.0, 1.9, "act", 0.35, 0.55, 0.5),  # выпад двумя руками
	"Mq_Cast_C": ("m1", "mage_soell_cast_7", 0.2, 2.4, "act", 0.4, 0.55, 0.8),  # рука вперёд
	"Mq_Cast_Wide": ("m1", "mage_soell_cast_1", 0.2, 2.9, "act", 0.6, 0.6, 1.4),  # руки в стороны
	"Mq_Cast_Slam": ("m1", "mage_soell_cast_2", 0.0, 2.4, "act", 0.65, 0.55, 1.33),  # прыжок и удар в землю
	"Mq_Cast_Beam": ("m1", "mage_soell_cast_3", 0.0, 3.2, "act", 0.45, 0.9, 1.0),  # луч из ладони
	"Mq_Cast_Up": ("m1", "mage_soell_cast_6", 0.0, 2.1, "act", 0.55, 0.55, 1.05),  # подскок, рука вверх
	"Mq_Cast_Pray": ("m1", "mage_soell_cast_8", 0.0, 1.33, "act", None, None, 0.4),  # ладони у лица (лечение)
	"Mq_Charged_Cast": ("m1", "Charged_Spell_Cast", 0.0, 2.6, "act", 0.7, 0.6, 1.72),  # заряд и выброс вверх
	"Mq_Charged_Cast1": ("m1", "Charged_Spell_Cast_1", 0.3, 4.0, "act", 0.7, 0.8, 1.9),  # усиление
	# --- Прочее ---
	"Mq_Taunt": ("m1", "Chest_Pound_Taunt", 0.5, 3.2, "act", 0.7, 0.6, 2.1),  # «Вызов»: удар в грудь
	"Mq_Hit": ("m1", "Hit_Reaction_1", 0.0, 1.1, "act", None, 0.55, 0.2),  # урон
	"Mq_Death": ("m1", "Dead", 0.0, 2.7, "death", None, None, 2.1),  # смерть: падает и лежит
	"Mq_Pickup": ("m1", "Female_Bend_Over_Pick_Up_Inspect", 0.2, 2.75, "act", 0.8, 0.7, 1.5),  # подбор
}
## Шаг и бег манекена (m1 Walking / Running) — тем же путём, что UAL в prepare_hero (растяжка под WALK_NATIVE /
## RUN_NATIVE, опоры, у героинь — женская пластика). В игре не подключены: шаг и бег UAL лучше (см. CLAUDE.md).
MQ_LOCO = {"Mq_Walking": ("walk", "Walking"), "Mq_Running": ("run", "Running")}
## Не перенесены: Archery_Shot (= Draw_and_Shoot_from_Back_2), Draw_and_Shoot_from_Back и _1 (то же, 7.8 с),
## Archery_Shot_2 (неподвижное прицеливание), Archery_Aim_with_Lateral_Scan, Gun_Hold_Left_Turn, mage_soell_cast_5
## (11 с почти без движения), Quick_Walk, RunFast, run_fast_3_inplace, Run_Turn_*, Walk_Turn_* (повороты и
## разновидности бега — в игре шаг и бег одни, повороты делает код), дубли Walking/Running в m2 и m3.

## Кости UAL (как их ищут HeroRetarget/BipedRetarget) → кости Mixamo манекена.
UAL_TO_MIXAMO = {
	"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck",
	"Head": "Head",
}
for _s, _S in (("l", "Left"), ("r", "Right")):
	UAL_TO_MIXAMO.update({
		"clavicle_" + _s: _S + "Shoulder", "upperarm_" + _s: _S + "Arm", "lowerarm_" + _s: _S + "ForeArm",
		"hand_" + _s: _S + "Hand", "thigh_" + _s: _S + "UpLeg", "calf_" + _s: _S + "Leg", "foot_" + _s: _S + "Foot",
		"ball_" + _s: _S + "ToeBase",
	})
_FINGER = re.compile(r"^(thumb|index|middle|ring|pinky)_0(\d)(_leaf)?_([lr])$")


class MixamoSource(ra.Skeleton):
	"""Скелет манекена (Mixamo) под именами костей UAL: find("upperarm_l") → «mixamorig:LeftArm»."""

	def find(self, name: str) -> int:
		m = _FINGER.match(name)
		if m:
			side = "Left" if m.group(4) == "l" else "Right"
			return super().find("%sHand%s%s" % (side, m.group(1).capitalize(), m.group(2)))
		if name in UAL_TO_MIXAMO:
			return super().find(UAL_TO_MIXAMO[name])
		return super().find(name)


# ---------- Герой из готового GLB ----------

class Hero:
	"""Готовый GLB героя: скелет (кости — суставы кожи, порядок «родитель раньше детей»), меш в позе покоя, роли."""

	def __init__(self, path: str) -> None:
		self.path = path
		self.cid = os.path.splitext(os.path.basename(path))[0]
		gltf, _binc = pc.read_glb(path)
		src = pc.load_source(path)
		nodes = gltf["nodes"]
		skin = gltf["skins"][0]
		joints = list(skin["joints"])
		parent_node = {}
		for i, n in enumerate(nodes):
			for c in n.get("children", []):
				parent_node[c] = i
		# Корневой сустав кожи: его родительский узел должен быть без трансформа (клип пишет позу в его пространстве)
		for j in joints:
			p = parent_node.get(j)
			if p is not None and p not in joints:
				n = nodes[p]
				if any(k in n for k in ("matrix", "rotation", "scale")) or any(abs(x) > 1e-6 for x in n.get("translation", [0, 0, 0])):
					raise ValueError("%s: у узла над скелетом есть трансформ — не поддерживается" % path)
		order = pc.topo_order(src["parent"])
		g = pc.reorder(src, order)
		self.node = [joints[b] for b in order]  # внутренняя кость → узел glTF
		self.rig = pc.Rig(g["names"], g["parent"], g["grot"], g["gpos"])
		self.mesh = {"pos": g["pos"], "joints": g["joints"], "weights": g["weights"], "tris": g["tris"], "uv": g["uv"]}
		self.json_path = os.path.splitext(path)[0] + ".json"
		self.meta = None
		if os.path.exists(self.json_path):
			with open(self.json_path) as f:
				self.meta = json.load(f)
			self.roles, self.fingers = roles_from_meta(self.meta, self.rig)
		else:
			self.roles, self.fingers = roles_mixamo(self.rig)
		H = float(self.mesh["pos"][:, 1].max())
		self.height = H
		self.grips = self._grips()

	def _grips(self) -> dict:
		if self.meta is not None:
			return {s: {"pos": np.array(self.meta["grip_" + s.lower()]["pos"]), "dir": np.array(self.meta["grip_" + s.lower()]["dir"])}
				for s in ("R", "L")}
		# Прежняя героиня: GRIP_* из character_model.gd
		return {"R": {"pos": np.array([-0.02, 0.072, 0.017]), "dir": np.array([0.76, 0.12, 0.64])},
			"L": {"pos": np.array([0.02, 0.072, 0.017]), "dir": np.array([-0.76, 0.12, 0.64])}}


def roles_from_meta(meta: dict, rig) -> tuple:
	"""Роли костей по <id>.json (prepare_hero.py) — в том виде, что ждёт HeroRetarget (как biped_roles)."""
	bo = meta["bones"]
	ix = rig.idx

	def b(name: str) -> int:
		if name not in ix:
			raise ValueError("в скелете нет кости %s из .json" % name)
		return ix[name]

	chest, head = b(bo["chest"]), b(bo["head"])
	neck = []
	p = int(rig.parent[head])
	while p >= 0 and p != chest:
		neck.insert(0, p)
		p = int(rig.parent[p])
	if p != chest:
		raise ValueError("голова не над грудью")
	he = b(bo["head_end"])
	roles = {"kind": "biped", "root": b(bo["root"]), "hips": b(bo["hips"]), "chest": chest, "head": head,
		"neck": neck, "head_end": [he] if he != head else [], "spine": [b(n) for n in bo["spine"]],
		"arms": {s: [b(n) for n in c] for s, c in bo["arms"].items()},
		"legs": {s: [b(n) for n in c] for s, c in bo["legs"].items()}}
	fingers = {s: {f: [b(n) for n in ch] for f, ch in fs.items()} for s, fs in bo.get("fingers", {}).items()}
	for s in ("L", "R"):
		fingers.setdefault(s, {})
	return roles, fingers


def roles_mixamo(rig) -> tuple:
	"""Роли костей скелета Mixamo по именам (прежняя героиня dark_elf_wanderer)."""
	def b(name: str) -> int:
		for i, n in enumerate(rig.names):
			if n == name or n.endswith(":" + name) or n.endswith("_" + name):
				return i
		return -1

	need = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
	if any(b(n) < 0 for n in need):
		raise ValueError("нет .json с ролями и скелет не Mixamo")
	roles = {"kind": "biped", "root": b("Hips"), "hips": b("Hips"), "chest": b("Spine2"), "head": b("Head"),
		"neck": [b("Neck")], "head_end": [b("HeadTop_End")] if b("HeadTop_End") >= 0 else [],
		"spine": [b("Spine"), b("Spine1"), b("Spine2")], "arms": {}, "legs": {}}
	fingers = {}
	for s, S in (("L", "Left"), ("R", "Right")):
		roles["arms"][s] = [b(S + n) for n in ("Shoulder", "Arm", "ForeArm", "Hand")]
		roles["legs"][s] = [x for x in (b(S + n) for n in ("UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")) if x >= 0]
		fs = {}
		for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
			ch = [x for x in (b("%sHand%s%d" % (S, f, k)) for k in range(1, 5)) if x >= 0]
			if ch:
				fs[f.lower()] = ch
		fingers[s] = fs
	return roles, fingers


# ---------- Перенос клипа ----------

def hand_peak(rt, times: np.ndarray, Gp: np.ndarray, lo: float, hi: float) -> float:
	"""Момент удара: самая быстрая кисть в [lo, hi] (сглаженная скорость)."""
	best, bt = -1.0, 0.5 * (lo + hi)
	for _s, c in rt.roles["arms"].items():
		hp = Gp[:, c[3]]
		v = np.linalg.norm(np.gradient(hp, times, axis=0), axis=1)
		if len(v) > 4:
			v = np.convolve(v, np.ones(3) / 3.0, mode="same")
		for f in range(len(times)):
			if lo <= times[f] <= hi and v[f] > best:
				best, bt = float(v[f]), float(times[f])
	return bt


def warp(times: np.ndarray, hit: float, pre, post) -> tuple:
	"""Кусочно-линейное сжатие времени: [0, hit] → [0, pre], [hit, T] → [pre, pre + post] (ускорение ≥ 1)."""
	T = float(times[-1])
	a = hit if pre is None else min(float(pre), hit)
	b = (T - hit) if post is None else min(float(post), T - hit)
	k1 = a / hit if hit > 1e-6 else 1.0
	k2 = b / (T - hit) if T - hit > 1e-6 else 1.0
	out = np.where(times <= hit, times * k1, a + (times - hit) * k2)
	return out, a


def source_clip(rts: dict, src_id: str, src_clip: str) -> tuple:
	"""Клип манекена на скелете героя: «A+B» — подряд (часть может быть с другого манекена: «m3:B»)."""
	ts, qs, ps = [], [], []
	for part in src_clip.split("+"):
		sid, nm = part.split(":", 1) if ":" in part else (src_id, part)
		_t, q, p = rts[sid].clip([nm], False)
		if qs:
			q, p = q[1:], p[1:]
		qs.append(q)
		ps.append(p)
	Lq, Lt = np.concatenate(qs), np.concatenate(ps)
	return np.arange(len(Lq)) / FPS, ra.continuous(Lq), Lt


def stance_masks(rt, times: np.ndarray, Gp: np.ndarray) -> dict:
	"""Опорные интервалы стоп по клипу С перемещением (как в исходнике): стопа у земли и почти не движется."""
	H = float(rt.rig.gpos[:, 1].max())
	out = {}
	for s, b in rt.contact.items():
		y = Gp[:, b, 1]
		v = np.hypot(np.gradient(Gp[:, b, 0], times), np.gradient(Gp[:, b, 2], times)) if len(times) > 2 else np.zeros(len(times))
		st = (y < y.min() + 0.025 * H) & (v < STANCE_SPEED)
		# Опоры, разорванные на 1–2 кадра (стопа на миг ускорилась, не отрываясь), — одна опора
		idx = np.flatnonzero(st)
		for a, b2 in zip(idx[:-1], idx[1:]):
			if 1 < b2 - a <= STANCE_GAP + 1:
				st[a:b2] = True
		# Короткие «опоры» (стопа на миг притормозила, скользя) — не опоры
		f = 0
		while f < len(st):
			if not st[f]:
				f += 1
				continue
			g = f
			while g + 1 < len(st) and st[g + 1]:
				g += 1
			if g - f + 1 < STANCE_MIN:
				st[f:g + 1] = False
			f = g + 1
		out[s] = st
	return out


def plant_inplace(rt, times: np.ndarray, Lq: np.ndarray, Lt: np.ndarray, stance: dict) -> float:
	"""Клип уже на месте (корень по X/Z закреплён), по земле стопа не едет. Кадры каждой стопы делятся на опору
	(по исходнику с перемещением: у земли и почти неподвижна), «у земли» (в клипе на месте — не выше своего минимума
	+ STEP_LOW) и перенос по воздуху:
	  * опора — стопа стоит в средней точке интервала;
	  * у земли — стоит на месте (от прежней опоры), а если исходник тащит её дальше STEP_MIN / 4 — короткий шаг дугой
	    (STEP_TIME, высота STEP_LIFT × сдвиг) в момент, когда стопа исходника быстрее всего, к следующей опоре;
	  * перенос — путь исходника, сдвинутый так, чтобы начаться там, где стопа стояла, и закончиться там, где встанет.
	Шаг корпуса исходника становится переступанием на месте. IK бедро + голень, стопа сохраняет мировой поворот.
	Возвращает недостачу IK (м)."""
	F = len(times)
	_Gq, Gp = rt.fk(Lq, Lt)
	rest_y = {s: float(rt.rig.gpos[b, 1]) for s, b in rt.contact.items()}
	want = np.zeros((F, 2, 3))

	def segments(lab: list) -> list:
		out, f = [], 0
		while f < F:
			g = f
			while g + 1 < F and lab[g + 1] == lab[f]:
				g += 1
			out.append((lab[f], f, g))
			f = g + 1
		return out

	for si, (s, b) in enumerate(sorted(rt.contact.items())):
		ymin = float(Gp[:, b, 1].min())
		low_y = min(ymin + STEP_LOW, rest_y[s] + STEP_GROUND)
		lab = ["S" if stance[s][f] else ("L" if Gp[f, b, 1] < low_y else "A") for f in range(F)]
		segs = segments(lab)
		for kind, f, g in segs:
			if kind == "S":
				anchor = Gp[f:g + 1, b].mean(0)
				anchor[1] = max(rest_y[s], float(Gp[f:g + 1, b, 1].min()))
				want[f:g + 1, si] = anchor
		for i, (kind, f, g) in enumerate(segs):
			if kind != "L":
				continue
			P = Gp[f:g + 1, b]
			n = g - f + 1
			Sx = want[f - 1, si].copy() if f > 0 and lab[f - 1] != "A" else P[0].copy()
			Ex = want[g + 1, si].copy() if g + 1 < F and lab[g + 1] == "S" else P[-1].copy()
			Sx[1] = max(Sx[1], rest_y[s], float(P[:, 1].min()))
			Ex[1] = max(Ex[1], rest_y[s], float(P[:, 1].min()))
			D = float(np.hypot(*(Ex[[0, 2]] - Sx[[0, 2]])))
			if D <= STEP_MIN * 0.25:
				for k in range(n):
					u = (k + 1) / float(n + 1)
					want[f + k, si] = Sx + (Ex - Sx) * (u * u * (3.0 - 2.0 * u))
				continue
			h = float(np.clip(STEP_LIFT * D, 0.03, 0.14))
			m = min(n, max(4, int(round(STEP_TIME * FPS))))
			v = np.hypot(np.gradient(P[:, 0]), np.gradient(P[:, 2])) if n > 2 else np.ones(n)
			a = int(np.clip(int(np.argmax(v)) - m // 2, 0, n - m))
			for k in range(n):
				u = float(np.clip((k - a + 1) / float(m + 1), 0.0, 1.0))
				w = u * u * (3.0 - 2.0 * u)
				want[f + k, si] = Sx + (Ex - Sx) * w + np.array([0.0, h * math.sin(math.pi * u), 0.0])
		for kind, f, g in segs:
			if kind != "A":
				continue
			P = Gp[f:g + 1, b].copy()
			n = g - f + 1
			Sx = want[f - 1, si] if f > 0 else P[0]
			Ex = want[g + 1, si] if g + 1 < F else P[-1]
			c0, c1 = Sx - P[0], Ex - P[-1]
			for k in range(n):
				w = k / float(n - 1) if n > 1 else 0.5
				p = P[k].copy()
				p[[0, 2]] += (c0 + (c1 - c0) * w)[[0, 2]]
				p[1] = max(p[1], rest_y[s])
				want[f + k, si] = p
	short = 0.0
	for f in range(F):
		for si, (s, b) in enumerate(sorted(rt.contact.items())):
			Gq1, Gp1 = rt.fk(Lq[f:f + 1], Lt[f:f + 1])
			short = max(short, rt.two_bone(Gq1[0], Gp1[0], Lq[f], s, want[f, si]))
	return short


def make_clip(rts: dict, hero: Hero, name: str, spec: tuple, female: bool) -> dict:
	src_id, src_clip, t0, t1, kind, pre, post, hit = spec
	rt = rts[src_id]
	times, Lq, Lt = source_clip(rts, src_id, src_clip)
	keep = (times >= t0 - 1e-6) & (times <= t1 + 1e-6)
	times, Lq, Lt = times[keep] - times[keep][0], Lq[keep].copy(), Lt[keep].copy()
	r0 = rt.roles["root"]
	root = Lt[:, r0]
	travel = float(np.max(np.hypot(root[:, 0] - root[0, 0], root[:, 2] - root[0, 2])))
	_Gq, Gp = rt.fk(Lq, Lt)
	stance = stance_masks(rt, times, Gp)
	ph.pin_xz(rt, Lt)
	short = 0.0
	if kind != "death":
		short = plant_inplace(rt, times, Lq, Lt, stance)
	lift = pc.biped_ground(rt, hero.mesh, Lq, Lt, kind == "death")
	_Gq, Gp = rt.fk(Lq, Lt)
	T = float(times[-1])
	h = hand_peak(rt, times, Gp, 0.08 * T, 0.85 * T) if hit is None else float(hit) - t0
	new_t, new_hit = warp(times, h, pre, post)
	# Какая рука бьёт: средняя скорость кистей ±0.15 с вокруг удара
	win = np.abs(times - h) <= 0.15
	hv = {s: float(np.linalg.norm(np.gradient(Gp[:, c[3]], times, axis=0), axis=1)[win].mean())
		for s, c in rt.roles["arms"].items()}
	return {"hand": "R" if hv["R"] >= hv["L"] else "L", "hv": hv, "name": name, "src": "%s:%s [%.2f–%.2f]" % (src_id, src_clip, t0, t1), "kind": kind, "times": new_t,
		"src_times": times, "rot": ra.continuous(Lq), "trans": Lt, "hit": float(new_hit), "T": float(new_t[-1]),
		"travel": travel, "short": short, "lift": lift, "stance": stance}


def make_loco(rts: dict, hero: Hero, name: str, kind: str, src_clip: str, female: bool) -> dict:
	"""Шаг/бег манекена — как шаг и бег UAL в prepare_hero.make_clip (растяжка, опоры, женская пластика)."""
	ph.FEM_CLIPS[name] = kind
	cl = ph.make_clip(rts["m1"], hero.mesh, name, kind, [("m1", [src_clip])], rts, female)
	cl.update({"src": "m1:%s%s" % (src_clip, " + женская пластика" if female else ""), "kind": kind, "hit": 0.0, "stance": {},
		"src_times": cl["times"]})
	return cl


# ---------- Прореживание ключей и запись ----------

def _qangle(a: np.ndarray, b: np.ndarray) -> np.ndarray:
	d = np.abs(np.sum(a * b, axis=-1))
	return 2.0 * np.arccos(np.clip(d, -1.0, 1.0))


def reduce_keys(t: np.ndarray, v: np.ndarray, rot: bool) -> np.ndarray:
	"""Индексы ключей, из которых линейная интерполяция (slerp у поворотов) восстанавливает все кадры с ошибкой
	меньше ROT_TOL / POS_TOL (жадно: от ключа вперёд, пока отрезок держит все промежуточные кадры)."""
	n = len(t)
	if n <= 2:
		return np.arange(n)
	keep = [0]
	i = 0
	while i < n - 1:
		j = i + 1
		while j + 1 < n:
			k = j + 1
			mid = np.arange(i + 1, k)
			f = (t[mid] - t[i]) / (t[k] - t[i])
			if rot:
				est = ra.slerp(np.repeat(v[i][None], len(mid), 0), np.repeat(v[k][None], len(mid), 0), f)
				err = float(_qangle(est, v[mid]).max())
				ok = err < ROT_TOL
			else:
				est = v[i][None] + (v[k] - v[i])[None] * f[:, None]
				ok = float(np.linalg.norm(est - v[mid], axis=1).max()) < POS_TOL
			if not ok:
				break
			j = k
		keep.append(j)
		i = j
	return np.array(keep)


def write_clips(glb, hero: Hero, clips: list) -> int:
	"""Дописать клипы в GLB (ra.Glb): каналы поворотов всех костей, сдвиг — у костей, которые сдвигаются."""
	nkeys = 0
	rig = hero.rig
	for cl in clips:
		samplers, channels = [], []
		cache = {}
		times = cl["times"]

		def tin(idx: np.ndarray) -> int:
			key = tuple(int(x) for x in idx)
			if key not in cache:
				cache[key] = glb.add_float_accessor(times[idx], "SCALAR", True)
			return cache[key]

		for b in range(rig.B):
			node = hero.node[b]
			q = cl["rot"][:, b]
			idx = reduce_keys(times, q, True)
			nkeys += len(idx)
			samplers.append({"input": tin(idx), "output": glb.add_float_accessor(q[idx], "VEC4"), "interpolation": "LINEAR"})
			channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "rotation"}})
			tr = cl["trans"][:, b]
			if b == hero.roles["root"] or not np.allclose(tr, rig.lpos[b][None], atol=1e-6):
				idx = reduce_keys(times, tr, False)
				nkeys += len(idx)
				samplers.append({"input": tin(idx), "output": glb.add_float_accessor(tr[idx], "VEC3"), "interpolation": "LINEAR"})
				channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "translation"}})
		glb.json.setdefault("animations", []).append({"name": cl["name"], "channels": channels, "samplers": samplers,
			"extras": {TAG: cl["src"]}})
	return nkeys


# ---------- Проверка ----------

def verify(rt, hero: Hero, cl: dict) -> list:
	"""Замечания по клипу: низ меша под землёй, корень по X/Z уехал, опорная стопа скользит, Dead — не лёжа."""
	bad = []
	Gq, Gp = rt.fk(cl["rot"], cl["trans"])
	Gr = pc.qm_batch(Gq)
	F = len(cl["times"])
	miny = min(float(pc.skin_points(hero.rig, hero.mesh["pos"], hero.mesh["joints"], hero.mesh["weights"], Gr[f], Gp[f])[:, 1].min())
		for f in range(0, F, max(1, F // 16)))
	if miny < -0.015:
		bad.append("низ меша %.3f м" % miny)
	r0 = hero.roles["root"]
	d = np.hypot(cl["trans"][:, r0, 0] - hero.rig.lpos[r0, 0], cl["trans"][:, r0, 2] - hero.rig.lpos[r0, 2])
	if d.max() > 1e-4:
		bad.append("корень уехал на %.3f м" % d.max())
	head = hero.roles["head"]
	if cl["kind"] == "death" and Gp[-1, head, 1] > 0.6:
		bad.append("в конце смерти голова на %.2f м" % Gp[-1, head, 1])
	cl["slide"] = foot_slide(rt, cl, Gp) if cl["kind"] == "act" else 0.0
	cl["gslide"] = ground_slide(hero, cl) if cl["kind"] == "act" else 0.0
	if cl["gslide"] > GROUND_SLIDE and cl["name"] not in FREE_FEET:
		bad.append("носок едет по земле на %.3f м" % cl["gslide"])
	if cl["kind"] == "act" and cl["slide"] > 0.02:
		bad.append("стопа скользит на %.3f м" % cl["slide"])
	if cl["kind"] == "act" and cl["short"] > 0.05 and cl["name"] not in FREE_FEET:
		bad.append("нога не дотянулась до опоры на %.3f м" % cl["short"])
	return bad


def ground_slide(hero: Hero, cl: dict, n: int = 60) -> float:
	"""Та же проверка, что в tests/test_hero_models.gd: опора стопы (носок) в n + 1 точках клипа (линейно между ключами); пока
	он у земли (не выше своей высоты в покое + GROUND_NEAR), по земле он сдвигается не больше, м (поворот на носке —
	не скольжение)."""
	t = np.linspace(0.0, cl["T"], n + 1)
	ct = cl["times"]
	k = np.clip(np.searchsorted(ct, t, side="right") - 1, 0, len(ct) - 2)
	f = np.clip((t - ct[k]) / np.maximum(ct[k + 1] - ct[k], 1e-9), 0.0, 1.0)
	Lq = ra.slerp(cl["rot"][k], cl["rot"][k + 1], np.repeat(f[:, None], hero.rig.B, 1))
	Lt = cl["trans"][k] + (cl["trans"][k + 1] - cl["trans"][k]) * f[:, None, None]
	rt = ph.HeroRetarget.__new__(ph.HeroRetarget)
	rt.ra, rt.rig = ra, hero.rig
	_q, Gp = pc.BipedRetarget.fk(rt, Lq, Lt)
	worst = 0.0
	for c in hero.roles["legs"].values():
		p = Gp[:, c[min(3, len(c) - 1)]]
		low = p[:, 1] < hero.rig.gpos[c[min(3, len(c) - 1)], 1] + GROUND_NEAR
		start = -1
		for i in range(len(t)):
			if not low[i]:
				start = -1
			elif start < 0:
				start = i
			else:
				worst = max(worst, float(np.hypot(p[i, 0] - p[start, 0], p[i, 2] - p[start, 2])))
	return worst


def foot_slide(rt, cl: dict, Gp: np.ndarray) -> float:
	"""Наибольший сдвиг опорной стопы по земле за опорный интервал (интервалы — по исходнику с перемещением)."""
	worst = 0.0
	for s, b in rt.contact.items():
		st = cl["stance"][s]
		f = 0
		while f < len(st):
			if not st[f]:
				f += 1
				continue
			g = f
			while g + 1 < len(st) and st[g + 1]:
				g += 1
			seg = Gp[f:g + 1, b]
			worst = max(worst, float(np.max(np.hypot(seg[:, 0] - seg[0, 0], seg[:, 2] - seg[0, 2]))))
			f = g + 1
	return worst


# ---------- Картинки-проверки ----------

def _yaw(p: np.ndarray, deg: float) -> np.ndarray:
	a = math.radians(deg)
	c, s = math.cos(a), math.sin(a)
	return np.stack([c * p[..., 0] + s * p[..., 2], p[..., 1], -s * p[..., 0] + c * p[..., 2]], -1)


def render_frames(hero: Hero, rt, tex, frames: list, label: str, size: int = 190, yaw: float = 35.0):
	"""Ряд кадров: [(Gp, Gq, подпись, удар?)] — меш под углом 3/4, линии клинков в кистях."""
	from PIL import Image, ImageDraw
	box = (np.array([-1.1, -0.05, -1.1]), np.array([1.1, 2.15, 1.1]))
	row = Image.new("RGB", (size * len(frames), size + 14), (255, 255, 255))
	d = ImageDraw.Draw(row)
	d.text((4, size), label, fill=(0, 0, 0))
	hands = {s: rt.roles["arms"][s][3] for s in ("L", "R")}
	for fi, (gp, gq, lab, hit) in enumerate(frames):
		Gr = pc.qm_batch(gq)
		v = pc.skin_points(hero.rig, hero.mesh["pos"], hero.mesh["joints"], hero.mesh["weights"], Gr, gp)
		im = pc.render_mesh(_yaw(v, yaw), hero.mesh["tris"], hero.mesh["uv"], tex, views=("front",), size=size,
			samples=90000, box=box)
		dd = ImageDraw.Draw(im)
		for s, col in (("R", (230, 30, 30)), ("L", (230, 150, 0))):
			h = hands[s]
			base = gp[h] + Gr[h] @ hero.grips[s]["pos"]
			tip = base + Gr[h] @ hero.grips[s]["dir"] * 0.7
			a = ph._project(_yaw(base, yaw), "front", size)
			b2 = ph._project(_yaw(tip, yaw), "front", size)
			dd.line([a, b2], fill=col, width=3)
		if hit:
			dd.rectangle([0, 0, size - 1, size - 1], outline=(255, 0, 200), width=3)
		row.paste(im, (fi * size, 0))
		d.text((fi * size + 4, 2), lab, fill=(0, 0, 0))
	return row


def _sheets(out: str, prefix: str, rows: list, per: int = 8) -> list:
	from PIL import Image
	paths = []
	for k in range(0, len(rows), per):
		part = rows[k:k + per]
		W = max(r.size[0] for r in part)
		sheet = Image.new("RGB", (W, sum(r.size[1] for r in part)), (255, 255, 255))
		y = 0
		for r in part:
			sheet.paste(r, (0, y))
			y += r.size[1]
		p = os.path.join(out, "%s_%d.png" % (prefix, k // per + 1))
		sheet.save(p)
		paths.append(p)
	return paths


def hero_tex(hero: Hero):
	from PIL import Image
	p = os.path.splitext(hero.path)[0] + ".png"
	if not os.path.exists(p):
		return None
	return np.asarray(Image.open(p).convert("RGB").resize((512, 512)))


def preview(out: str, hero: Hero, rt, clips: list) -> list:
	os.makedirs(out, exist_ok=True)
	tex = hero_tex(hero)
	rows = []
	for cl in clips:
		Gq, Gp = rt.fk(cl["rot"], cl["trans"])
		t = cl["times"]
		F = len(t)
		hf = int(np.argmin(np.abs(t - cl["hit"])))
		idx = sorted(set([int(x) for x in np.linspace(0, F - 1, 6)] + [hf]))
		frames = [(Gp[f], Gq[f], "%.2f" % t[f], f == hf) for f in idx]
		rows.append(render_frames(hero, rt, tex, frames, "%s %s  %.2f с, удар %.2f" % (hero.cid, cl["name"], cl["T"], cl["hit"])))
	# Сравнение шага и бега: нынешние клипы героя (UAL) рядом с клипами манекена
	sk = ra.Skeleton(ra.Glb(hero.path))
	for name in ("Walking", "Running"):
		try:
			T = sk.length(name)
		except SystemExit:
			continue
		t = np.linspace(0.0, T, 7)[:-1]
		lt, lr = sk.sample(name, t)
		Gq, Gp = rt.fk(lr[:, hero.node], lt[:, hero.node])
		rows.append(render_frames(hero, rt, tex, [(Gp[f], Gq[f], "%.2f" % t[f], False) for f in range(len(t))],
			"%s %s (нынешний, UAL)" % (hero.cid, name)))
	return _sheets(out, "%s_mq" % hero.cid, rows)


def survey(out: str, hero: Hero, srcs: dict, names: list) -> None:
	"""Исходные клипы манекенов целиком на герое (без закрепления опор): 10 кадров с отметками времени."""
	os.makedirs(out, exist_ok=True)
	tex = hero_tex(hero)
	rows = []
	for sid, src in srcs.items():
		rt = ph.HeroRetarget(src, hero.rig, hero.roles, hero.fingers)
		for a in src.glb.json["animations"]:
			if names and a["name"] not in names:
				continue
			times, Lq, Lt = rt.clip([a["name"]], False)
			ph.pin_xz(rt, Lt)
			Gq, Gp = rt.fk(Lq, Lt)
			F = len(times)
			n = 10 if times[-1] < 6 else 14
			idx = [int(x) for x in np.linspace(0, F - 1, n)]
			frames = [(Gp[f], Gq[f], "%.2f" % times[f], False) for f in idx]
			rows.append(render_frames(hero, rt, tex, frames, "%s:%s %.2f с" % (sid, a["name"], times[-1]), size=150))
	for p in _sheets(out, "survey_%s" % hero.cid, rows, 6):
		print("картинка: %s" % p)


# ---------- Главное ----------

def process(path: str, srcs: dict, check: bool, prev: str) -> dict:
	hero = Hero(path)
	female = hero.cid.replace("_starter", "").endswith("_f")
	rts = {k: ph.HeroRetarget(s, hero.rig, hero.roles, hero.fingers) for k, s in srcs.items()}
	print("== %s: костей %d, рост %.2f м, масштаб таза %.3f, подъём %.3f м" % (hero.cid, hero.rig.B, hero.height,
		rts["m1"].k, rts["m1"].lift))
	clips = []
	ok = True
	for name, spec in MQ_CLIPS.items():
		rt = rts[spec[0]]
		cl = make_clip(rts, hero, name, spec, female)
		bad = verify(rt, hero, cl)
		ok = ok and not bad
		print("   %-18s %5.2f с (исх. %5.2f) удар %.2f, рука %s (R %.1f / L %.1f м/с); таз уходил на %.2f м; опора %.3f, "
			"скольжение %.3f (у земли %.3f), подъём %.3f%s" % (name, cl["T"], cl["src_times"][-1], cl["hit"], cl["hand"], cl["hv"]["R"],
			cl["hv"]["L"], cl["travel"], cl["short"], cl["slide"], cl["gslide"], cl["lift"], ("  ПЛОХО: " + "; ".join(bad)) if bad else ""))
		clips.append(cl)
	for name, (kind, src_clip) in MQ_LOCO.items():
		cl = make_loco(rts, hero, name, kind, src_clip, female)
		bad = verify(rts["m1"], hero, cl)
		ok = ok and not bad
		print("   %-18s %5.2f с, скорость %.2f м/с (темп ×%.2f), опора %.3f%s" % (name, cl["T"], cl["speed"],
			1.0 / cl["stretch"], cl["short"], ("  ПЛОХО: " + "; ".join(bad)) if bad else ""))
		clips.append(cl)
	size0 = os.path.getsize(path)
	if not check:
		glb = ra.Glb(path)
		names = {cl["name"] for cl in clips}
		glb.json["animations"] = [a for a in glb.json.get("animations", []) if TAG not in a.get("extras", {})]
		clash = names & {a["name"] for a in glb.json["animations"]}
		if clash:
			raise SystemExit("%s: уже есть свои клипы %s" % (path, sorted(clash)))
		nkeys = write_clips(glb, hero, clips)
		glb.save(path)
		frames = sum(len(cl["times"]) for cl in clips) * hero.rig.B
		print("   записано: %.2f → %.2f МБ (+%.2f), ключей %d из %d кадров×костей" % (size0 / 1e6, os.path.getsize(path) / 1e6,
			(os.path.getsize(path) - size0) / 1e6, nkeys, frames))
		if hero.meta is not None:
			cm = hero.meta.setdefault("clips", {})
			for k in [k for k, v in cm.items() if str(v.get("source", "")).startswith("mannequin ")]:
				del cm[k]
			for cl in clips:
				loop = cl["kind"] in ("walk", "run")
				cm[cl["name"]] = {"length": round(cl["T"], 3), "loop": loop, "source": "mannequin " + cl["src"]}
				if not loop:
					cm[cl["name"]]["hit"] = round(cl["hit"], 3)
			with open(hero.json_path, "w") as f:
				json.dump(hero.meta, f, ensure_ascii=False, indent="\t")
				f.write("\n")
	if prev:
		for p in preview(prev, hero, rts["m1"], clips):
			print("   картинка: %s" % p)
	return {"ok": ok, "before": size0, "after": os.path.getsize(path)}


def main() -> None:
	ap = argparse.ArgumentParser(description="Движения манекенов Meshy (Mixamo) → герои игры")
	ap.add_argument("heroes", nargs="*", help="GLB героев (по умолчанию все hero_*.glb и dark_elf_wanderer.glb)")
	ap.add_argument("--m1", required=True)
	ap.add_argument("--m2", required=True)
	ap.add_argument("--m3", required=True)
	ap.add_argument("--check", action="store_true", help="без записи")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок")
	ap.add_argument("--survey", default="", help="папка: исходные клипы целиком на первом герое")
	ap.add_argument("--only", default="", help="клипы через запятую (для --survey)")
	args = ap.parse_args()
	srcs = {k: MixamoSource(ra.Glb(p)) for k, p in (("m1", args.m1), ("m2", args.m2), ("m3", args.m3))}
	heroes = args.heroes or sorted(glob.glob(os.path.join(ROOT, "assets", "characters", "hero_*.glb"))) + [
		os.path.join(ROOT, "assets", "characters", "dark_elf_wanderer.glb")]
	if args.survey:
		survey(args.survey, Hero(heroes[0]), srcs, [x for x in args.only.split(",") if x])
		return
	ok = True
	tb, ta = 0, 0
	for h in heroes:
		r = process(h, srcs, args.check, args.preview)
		ok = ok and r["ok"]
		tb += r["before"]
		ta += r["after"]
	print("ИТОГ: %s; GLB героев %.1f → %.1f МБ (+%.1f)" % ("всё в порядке" if ok else "есть замечания (ПЛОХО выше)",
		tb / 1e6, ta / 1e6, (ta - tb) / 1e6))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
