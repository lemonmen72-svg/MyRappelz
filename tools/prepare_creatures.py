#!/usr/bin/env python3
"""Звери из Meshy AI → игровые модели: упрощённый меш, реальный размер, понятные кости, свои анимации.

Вход — GLB из Meshy (один меш со скином, скелет «SmartRigArmature» с безликими костями Bone_NNN, без анимаций,
высота 1.7 м). Для каждого зверя пишет в assets/creatures/:
  <id>.glb            — меш ~7 тыс. треугольников (meshoptimizer: вершины не двигаются, у оставшихся — исходные
                        UV, нормали и веса; швы UV не рвутся), один материал без картинок, масштаб под высоту
                        из CREATURES, ноги на y = 0, морда в +Z; узел «Armature» → кости с понятными именами
                        (Root, Spine*, Hips, Chest, Neck*, Head, Ear*, Tail*, LegFL1…/LegL1…, Toe*, Wing*);
                        клипы Idle, Walk, Run (циклы), Attack, Hit, Death, Cast — процедурные.
  <id>.png            — цветовая текстура из GLB, 1024×1024 (+ .png.import: VRAM-сжатие, мипмапы).
  <id>.glb.import     — встроенные картинки отбрасываются, LOD включены (пишется, только если файла нет).
  creatures.json      — размеры, скорости шага/бега без проскальзывания, длины клипов, момент удара и умения,
                        роли костей → имена (для игры: куда цеплять эффекты, какая кость — голова и т. п.).

Как устроено:
  * Роли костей определяются сами по иерархии и позам покоя: ноги — ветки, у которых все концы у земли
    (4 — четвероногий, 2 — птица), голова — последнее ветвление на пути к самой передне-верхней кости,
    хвост — путь к самой задней кости. Куда смотрит морда — по длинной оси меша: голова выше хвоста.
  * Анимации: позы задаются в осях модели (наклон тела, изгиб спины, шея, голова, волна хвоста, уши, крылья),
    ноги — аналитический IK на две кости с твёрдой кистью/стопой: в опорной фазе стопа стоит в мире
    (в пространстве модели едет назад со скоростью хода), в переносной — дуга вперёд; если нога не достаёт,
    сначала поднимается пятка. Корень по X/Z не двигается (перемещает игра), только высота и наклоны.
  * Death: тело ложится на бок, корень подгоняется так, чтобы низ меша был ровно на земле; последний кадр — лёжа.
  * У фазана в скелете Meshy нет крыльев: добавляются кости WingL/WingR, веса — по области сложенного крыла
    (CREATURES["pheasant"]["wings"]).
  * Проверка (после сборки и по --check): файл читается заново, прямая кинематика и скиннинг по каждому кадру
    каждого клипа: низ меша не ниже земли, опоры ног не уходят в землю, в Walk/Run опорная стопа при указанной
    скорости не проскальзывает (> 2 см — ошибка), где голова, морда в +Z. --preview <папка> — PNG
    («палочки» сбоку/сверху/спереди и меш по кадрам) для просмотра глазами.

Новый зверь или стадия эволюции: добавить запись в CREATURES (высота, стиль клипов «cat»/«turtle»/«bird»,
параметры шага; стадия — stage_cfg(вид, высота, …)) и запустить скрипт с его GLB. Скелеты Meshy разные: лишняя
нога-копия убирается (merge_twin_legs), у головы уши — самая высокая боковая ветка, прочие ветки — HeadX*, если хвост
лежит на земле ниже лап — ноги ищутся как парные боковые концы (side_leg_roots). Если роли всё же не найдутся,
скрипт скажет, какие кости без роли.

Зависимости: numpy, Pillow, meshoptimizer (pip install numpy pillow meshoptimizer; обёртка Python 0.2.x,
библиотека meshoptimizer 0.24+). Запуск из корня репозитория (входные файлы — чужие данные, Python с -I):
  python3 -I tools/prepare_creatures.py panther=<пантера.glb> turtle=<черепаха.glb> pheasant=<фазан.glb>
  python3 -I tools/prepare_creatures.py --check                   # только проверка готовых assets/creatures
  python3 -I tools/prepare_creatures.py --preview /tmp/prev panther=<…>   # плюс картинки-проверки
Повторный запуск перезаписывает GLB, PNG и запись зверя в creatures.json (остальные записи остаются).
"""
import argparse
import io
import json
import math
import os
import struct
import sys

import numpy as np

# ---------- Звери ----------
# height — итоговая высота модели (м); tris — треугольников после упрощения; style — набор клипов;
# ik_upper — номер кости в цепочке ноги, с которой начинается пара IK (по умолчанию — две самые длинные подряд);
# prox_swing — насколько лопатка/бедро до пары IK качается вслед за лапой;
# walk/run — шаг: T — длина цикла (с), duty — доля опорной фазы, stride — путь стопы за опору (м),
# lift — подъём стопы (м), flex — сгиб кисти в переносе (рад), curl — поджатие пальцев, crouch — присед корпуса (м),
# td — когда нога встаёт на землю (доля цикла). Скорость без проскальзывания = stride / (duty · T).
# Поправки под неудобные скелеты Meshy (по умолчанию выключены): ground_fit — если кончики лап или низ тела в кадре
# ушли в землю, тело приподнимается на недостачу; foot_rigid — подошва (вершины ниже лодыжки) целиком на кости стопы;
# toe_tip — кость-опора на кончике пальцев у лап без костей пальцев; ground: "feet" — земля по лапам (хвост ниже лап
# приподнимается в позе покоя).
CREATURES = {
	"panther": {
		"height": 1.15, "tris": 7000, "style": "cat", "prox_swing": 0.5, "idle_T": 2.4,
		# шаг: диагональные пары (левая передняя + правая задняя, потом наоборот)
		"walk": {"T": 1.0, "duty": 0.62, "stride": 0.40, "lift": 0.08, "flex": 0.8, "crouch": 0.04,
			"td": {"FL": 0.0, "BR": 0.04, "FR": 0.5, "BL": 0.54}},
		# галоп: задние почти вместе, потом передние; два безопорных полёта
		"run": {"T": 0.46, "duty": 0.30, "stride": 0.60, "lift": 0.14, "flex": 0.8, "crouch": 0.05,
			"td": {"BL": 0.0, "BR": 0.07, "FL": 0.47, "FR": 0.54}},
	},
	"turtle": {
		"height": 0.85, "tris": 7000, "style": "turtle", "prox_swing": 0.0, "idle_T": 3.0,
		"walk": {"T": 1.1, "duty": 0.66, "stride": 0.17, "lift": 0.045, "flex": 0.4, "crouch": 0.025,
			"td": {"FL": 0.0, "BR": 0.05, "FR": 0.5, "BL": 0.55}},
		"run": {"T": 0.7, "duty": 0.58, "stride": 0.21, "lift": 0.06, "flex": 0.5, "crouch": 0.03,
			"td": {"FL": 0.0, "BR": 0.05, "FR": 0.5, "BL": 0.55}},
	},
	"pheasant": {
		"height": 0.85, "tris": 7000, "style": "bird", "prox_swing": 0.0,
		# бедро (LegX1) держим: на нём у Meshy висят бока тела; IK — голень и цевка
		"ik_upper": {"L": 1, "R": 1},
		"walk": {"T": 0.72, "duty": 0.6, "stride": 0.17, "lift": 0.07, "flex": 0.5, "curl": 0.7, "crouch": 0.012,
			"td": {"L": 0.0, "R": 0.5}},
		"run": {"T": 0.40, "duty": 0.4, "stride": 0.26, "lift": 0.10, "flex": 0.6, "curl": 0.8, "crouch": 0.025,
			"td": {"L": 0.0, "R": 0.5}},
		# в скелете Meshy нет костей крыльев — добавляем: плечо (для левого, правое зеркально по X) и область
		# сложенного крыла на боку: lat — отступ от середины (м), y и z — плавные полосы (м)
		"wings": {"shoulder": [0.12, 0.52, 0.16], "lat": [0.105, 0.15], "y": [0.27, 0.32, 0.58, 0.64],
			"z": [-0.32, -0.24, 0.18, 0.24]},
	},
	"wolf": {
		"height": 0.95, "tris": 7000, "style": "cat", "prox_swing": 0.5, "idle_T": 2.2, "ground_fit": True,
		# шаг: диагональные пары; бег — галоп, как у пантеры, чуть короче и чаще. Лапы у волка в покое почти прямые —
		# присед поглубже, чтобы им хватало длины
		"walk": {"T": 0.9, "duty": 0.62, "stride": 0.36, "lift": 0.07, "flex": 0.8, "crouch": 0.045,
			"td": {"FL": 0.0, "BR": 0.04, "FR": 0.5, "BL": 0.54}},
		"run": {"T": 0.44, "duty": 0.30, "stride": 0.56, "lift": 0.13, "flex": 0.8, "crouch": 0.07,
			"td": {"BL": 0.0, "BR": 0.07, "FL": 0.47, "FR": 0.54}},
	},
}


def stage_cfg(base: str, height: float, **over) -> dict:
	"""Стадия эволюции вида: стиль и шаг вида 1-й стадии; длины шага (stride, lift, crouch) — в пропорции высоты.
	Высота стадии — «база» (как у 1-й стадии при масштабе 1): крупнее на старших стадиях модель делает игра
	(PetData.STAGES scale), поэтому здесь она лишь выравнивает пропорции новой модели под вид."""
	import copy
	cfg = copy.deepcopy(CREATURES[base])
	k = height / cfg["height"]
	cfg["height"] = height
	for g in ("walk", "run"):
		for key in ("stride", "lift", "crouch"):
			cfg[g][key] = round(cfg[g][key] * k, 3)
	for key, v in over.items():
		if key in ("walk", "run"):
			cfg[key].update(v)  # частичная правка шага: {"crouch": …}
		else:
			cfg[key] = v
	return cfg


# Модели 2-й и 3-й стадий (Meshy, Максим). Высоты подобраны так, чтобы при масштабе 1 зверь был по объёму как
# 1-я стадия (у льва-пантеры корпус выше и короче, поэтому база выше); рост стадии даёт игра.
# У новых фазанов в скелете есть свои короткие кости плеч, но веса крыла на них не доходят до кончика —
# крылья, как у 1-й стадии, добавляются (область — по меркам модели). У фазана 3-й стадии хвост лежит на
# земле ниже лап: земля — по лапам, хвост в покое приподнимается (ground: "feet").
CREATURES.update({
	"panther_2": stage_cfg("panther", 1.3, ground_fit=True),
	"panther_3": stage_cfg("panther", 1.3, ground_fit=True),
	"turtle_2": stage_cfg("turtle", 0.85, foot_rigid=True, walk={"crouch": 0.05}, run={"crouch": 0.05}),
	"turtle_3": stage_cfg("turtle", 0.85, foot_rigid=True, walk={"crouch": 0.05}, run={"crouch": 0.05}),
	"pheasant_2": stage_cfg("pheasant", 0.9, wings={"shoulder": [0.13, 0.52, 0.22], "lat": [0.07, 0.12],
		"y": [0.30, 0.36, 0.66, 0.72], "z": [-0.42, -0.32, 0.24, 0.30]}),
	"pheasant_3": stage_cfg("pheasant", 0.9, ground="feet", toe_tip=True, run={"crouch": 0.0},
		wings={"shoulder": [0.11, 0.50, 0.18], "lat": [0.06, 0.10], "y": [0.26, 0.32, 0.60, 0.66],
		"z": [-0.30, -0.22, 0.20, 0.26]}),
	"wolf_2": stage_cfg("wolf", 0.95),
	"wolf_3": stage_cfg("wolf", 0.95),
})


# ---------- GLB: чтение ----------

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


def read_glb(path: str) -> tuple:
	data = open(path, "rb").read()
	magic, _ver, length = struct.unpack_from("<III", data, 0)
	if magic != 0x46546C67:
		raise ValueError("%s: не GLB" % path)
	pos = 12
	gltf = None
	binc = b""
	while pos + 8 <= min(length, len(data)):
		clen, ctype = struct.unpack_from("<II", data, pos)
		chunk = data[pos + 8:pos + 8 + clen]
		if ctype == 0x4E4F534A:
			gltf = json.loads(chunk.decode("utf-8"))
		elif ctype == 0x004E4942:
			binc = chunk
		pos += 8 + clen
	if gltf is None:
		raise ValueError("%s: нет JSON" % path)
	return gltf, binc


def accessor(gltf: dict, binc: bytes, i: int) -> np.ndarray:
	a = gltf["accessors"][i]
	bv = gltf["bufferViews"][a["bufferView"]]
	dt = np.dtype(COMP[a["componentType"]])
	n = NCOMP[a["type"]]
	count = a["count"]
	off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
	stride = bv.get("byteStride", 0) or dt.itemsize * n
	if stride == dt.itemsize * n:
		arr = np.frombuffer(binc, dtype=dt, count=count * n, offset=off).reshape(count, n).copy()
	else:
		rows = [np.frombuffer(binc, dtype=dt, count=n, offset=off + k * stride) for k in range(count)]
		arr = np.stack(rows)
	if a.get("normalized") and dt != np.float32:
		arr = arr.astype(np.float64) / float(np.iinfo(dt).max)
	return arr if n > 1 else arr[:, 0]


def image_bytes(gltf: dict, binc: bytes, img: int) -> bytes:
	bv = gltf["bufferViews"][gltf["images"][img]["bufferView"]]
	o = bv.get("byteOffset", 0)
	return binc[o:o + bv["byteLength"]]


# ---------- Повороты (матрицы 3×3) ----------

def q_to_m(q) -> np.ndarray:
	x, y, z, w = [float(v) for v in q]
	n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
	x, y, z, w = x / n, y / n, z / n, w / n
	return np.array([
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def m_to_q(m: np.ndarray) -> np.ndarray:
	"""Матрица поворота → кватернион (x, y, z, w)."""
	t = m[0, 0] + m[1, 1] + m[2, 2]
	if t > 0.0:
		s = math.sqrt(t + 1.0) * 2.0
		q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
	elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
		s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2.0
		q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
	elif m[1, 1] > m[2, 2]:
		s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2.0
		q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
	else:
		s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2.0
		q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
	q = np.array(q)
	return q / np.linalg.norm(q)


def rot_axis(axis, ang: float) -> np.ndarray:
	a = np.asarray(axis, dtype=np.float64)
	a = a / np.linalg.norm(a)
	x, y, z = a
	c, s = math.cos(ang), math.sin(ang)
	C = 1.0 - c
	return np.array([
		[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
		[y * x * C + z * s, c + y * y * C, y * z * C - x * s],
		[z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def rx(a: float) -> np.ndarray:
	return rot_axis((1, 0, 0), a)


def ry(a: float) -> np.ndarray:
	return rot_axis((0, 1, 0), a)


def rz(a: float) -> np.ndarray:
	return rot_axis((0, 0, 1), a)


def body_rot(pitch_up: float = 0.0, yaw_left: float = 0.0, roll_right: float = 0.0) -> np.ndarray:
	"""Поворот в осях модели (X — влево от зверя, Y — вверх, Z — вперёд):
	pitch_up > 0 — морда вверх, yaw_left > 0 — поворот влево (+X), roll_right > 0 — крен на правый бок (-X)."""
	return ry(yaw_left) @ rx(-pitch_up) @ rz(roll_right)


def frame_from(u: np.ndarray, w: np.ndarray) -> np.ndarray:
	"""Ортонормированный базис: первая ось вдоль u, вторая — составляющая w поперёк u."""
	u = u / np.linalg.norm(u)
	w = w - u * float(np.dot(w, u))
	w = w / np.linalg.norm(w)
	return np.stack([u, w, np.cross(u, w)], axis=1)


def smooth(x: float) -> float:
	x = min(max(x, 0.0), 1.0)
	return x * x * (3.0 - 2.0 * x)


def env(t: float, a: float, b: float, c: float, d: float) -> float:
	"""Огибающая: 0 до a, плавно 1 к b, держит до c, плавно 0 к d."""
	if t <= a or t >= d:
		return 0.0
	if t < b:
		return smooth((t - a) / max(b - a, 1e-6))
	if t <= c:
		return 1.0
	return 1.0 - smooth((t - c) / max(d - c, 1e-6))


def keys(t: float, pts: list) -> float:
	"""Плавная (smoothstep) интерполяция по ключам [(время, значение), ...]."""
	if t <= pts[0][0]:
		return pts[0][1]
	for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
		if t <= t1:
			return v0 + (v1 - v0) * smooth((t - t0) / max(t1 - t0, 1e-6))
	return pts[-1][1]


# ---------- Исходная модель Meshy ----------

def node_matrix(n: dict) -> np.ndarray:
	if "matrix" in n:
		return np.array(n["matrix"], dtype=np.float64).reshape(4, 4).T
	m = np.eye(4)
	m[:3, :3] = q_to_m(n.get("rotation", [0, 0, 0, 1])) * np.array(n.get("scale", [1, 1, 1]), dtype=np.float64)
	m[:3, 3] = n.get("translation", [0, 0, 0])
	return m


def load_source(path: str) -> dict:
	"""Меш, кожа и скелет в позе покоя (вершины уже «надеты» на скелет в позе покоя)."""
	gltf, binc = read_glb(path)
	nodes = gltf["nodes"]
	parent = {}
	for i, n in enumerate(nodes):
		for c in n.get("children", []):
			parent[c] = i
	glob = {}

	def g(i):
		if i not in glob:
			glob[i] = (g(parent[i]) if i in parent else np.eye(4)) @ node_matrix(nodes[i])
		return glob[i]

	mesh_nodes = [i for i, n in enumerate(nodes) if "mesh" in n and "skin" in n]
	if len(mesh_nodes) != 1:
		raise ValueError("ждём один меш со скином, найдено %d" % len(mesh_nodes))
	mn = mesh_nodes[0]
	prims = gltf["meshes"][nodes[mn]["mesh"]]["primitives"]
	if len(prims) != 1:
		raise ValueError("ждём один примитив в меше, найдено %d" % len(prims))
	pr = prims[0]
	at = pr["attributes"]
	pos = accessor(gltf, binc, at["POSITION"]).astype(np.float64)
	nrm = accessor(gltf, binc, at["NORMAL"]).astype(np.float64)
	uv = accessor(gltf, binc, at["TEXCOORD_0"]).astype(np.float64)
	jnt = accessor(gltf, binc, at["JOINTS_0"]).astype(np.int64)
	wgt = accessor(gltf, binc, at["WEIGHTS_0"]).astype(np.float64)
	tris = accessor(gltf, binc, pr["indices"]).astype(np.int64).reshape(-1, 3)
	skin = gltf["skins"][nodes[mn]["skin"]]
	joints = skin["joints"]
	ibm = accessor(gltf, binc, skin["inverseBindMatrices"]).astype(np.float64).reshape(-1, 4, 4).transpose(0, 2, 1)
	# По glTF трансформ узла меша со скином не учитывается: вершина = Σ w · G(кость) · IBM · v
	skin_m = np.stack([g(j) @ ibm[k] for k, j in enumerate(joints)])
	wgt = wgt / np.maximum(wgt.sum(1, keepdims=True), 1e-9)
	mv = np.einsum("vk,vkij->vij", wgt, skin_m[jnt])
	pos = np.einsum("vij,vj->vi", mv[:, :3, :3], pos) + mv[:, :3, 3]
	nrm = np.einsum("vij,vj->vi", mv[:, :3, :3], nrm)
	nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
	jset = {j: k for k, j in enumerate(joints)}
	bparent = np.array([jset.get(parent.get(j, -1), -1) for j in joints])
	gm = np.stack([g(j) for j in joints])
	gr = gm[:, :3, :3].copy()
	gr /= np.linalg.norm(gr, axis=1)[:, None, :]  # без масштаба
	mat = gltf["materials"][pr.get("material", 0)] if gltf.get("materials") else {}
	tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
	img = image_bytes(gltf, binc, gltf["textures"][tex["index"]]["source"]) if tex else None
	return {
		"names": [nodes[j].get("name", "Bone_%d" % k) for k, j in enumerate(joints)],
		"parent": bparent, "grot": gr, "gpos": gm[:, :3, 3].copy(),
		"pos": pos, "nrm": nrm, "uv": uv, "joints": jnt, "weights": wgt, "tris": tris,
		"image": img,
	}


def children_of(parent: np.ndarray) -> list:
	ch = [[] for _ in range(len(parent))]
	for b, p in enumerate(parent):
		if p >= 0:
			ch[p].append(int(b))
	return ch


def subtree(ch: list, b: int) -> list:
	out = [b]
	for c in ch[b]:
		out += subtree(ch, c)
	return out


def path_to(parent: np.ndarray, b: int) -> list:
	p = [int(b)]
	while parent[p[-1]] >= 0:
		p.append(int(parent[p[-1]]))
	return p[::-1]


def facing_yaw(src: dict) -> float:
	"""Куда смотрит морда: длинная ось меша (X или Z), со стороны, где кости тела выше (голова выше хвоста).
	Возвращает поворот вокруг Y (кратный 90°), после которого морда смотрит в +Z."""
	pos = src["pos"]
	lo, hi = pos.min(0), pos.max(0)
	ctr = (lo + hi) * 0.5
	ax = 2 if (hi[2] - lo[2]) >= (hi[0] - lo[0]) else 0
	half = (hi[ax] - lo[ax]) * 0.5
	gp = src["gpos"]
	height = hi[1] - lo[1]
	legs = set()
	for r in leg_roots(src["parent"], gp, lo[1] + 0.1 * height):
		legs.update(subtree(children_of(src["parent"]), r))
	body = [b for b in range(len(gp)) if b not in legs]
	best = None
	for sgn in (1.0, -1.0):
		sel = [b for b in body if (gp[b, ax] - ctr[ax]) * sgn > 0.25 * half]
		score = max([gp[b, 1] for b in sel], default=-1e9)
		if best is None or score > best[0]:
			best = (score, sgn)
	sgn = best[1]
	if ax == 2:
		return 0.0 if sgn > 0 else math.pi
	return -math.pi * 0.5 if sgn > 0 else math.pi * 0.5  # морда в +X → поворот на -90°


def leg_roots(parent: np.ndarray, gpos: np.ndarray, ground_y: float) -> list:
	"""Начала ног: поднимаемся от листьев у земли, пока все листья поддерева у земли."""
	ch = children_of(parent)
	leaves = {}

	def lv(b):
		if b not in leaves:
			leaves[b] = [b] if not ch[b] else sum((lv(c) for c in ch[b]), [])
		return leaves[b]

	def low(b):
		return all(gpos[x, 1] < ground_y for x in lv(b))

	roots = []
	for b in range(len(parent)):
		if ch[b] or gpos[b, 1] >= ground_y:
			continue
		r = b
		while parent[r] >= 0 and low(int(parent[r])):
			r = int(parent[r])
		if r not in roots:
			roots.append(r)
	return roots


def side_leg_roots(parent: np.ndarray, gpos: np.ndarray, height: float) -> list:
	"""Запасной поиск ног (когда у земли не 2 и не 4 ветки — например, хвост лежит на земле ниже лап):
	концы в нижней трети высоты, сбоку от середины и с зеркальной парой; поднимаемся, пока все концы поддерева такие."""
	ch = children_of(parent)
	cand = {b for b in range(len(parent)) if not ch[b] and gpos[b, 1] < 0.3 * height and abs(gpos[b, 0]) > 0.02 * height}
	mir = np.array([-1.0, 1.0, 1.0])
	cand = {b for b in cand if any(np.linalg.norm(gpos[o] * mir - gpos[b]) < 0.05 * height for o in cand if o != b)}
	leaves = {}

	def lv(b):
		if b not in leaves:
			leaves[b] = [b] if not ch[b] else sum((lv(c) for c in ch[b]), [])
		return leaves[b]

	roots = []
	for b in sorted(cand):
		r = b
		while parent[r] >= 0 and all(x in cand for x in lv(int(parent[r]))):
			r = int(parent[r])
		if r not in roots:
			roots.append(r)
	return roots


def merge_twin_legs(g: dict, height: float) -> dict:
	"""У скелета Meshy бывает лишняя «нога» — копия настоящей (те же суставы), прицепленная к другой кости
	(у волка 3-й стадии — к основанию хвоста), а веса вершин поделены между ними. Копия убирается, её веса
	переходят к соответствующим костям настоящей ноги. Настоящая — та, чей родитель общий с другими ногами."""
	parent = g["parent"]
	lr = leg_roots(parent, g["gpos"], 0.1 * height)
	if len(lr) <= 4:
		return g
	ch = children_of(parent)
	gp = g["gpos"]
	drop, to = [], {}
	for i, a in enumerate(lr):
		for b in lr[i + 1:]:
			sa, sb = subtree(ch, a), subtree(ch, b)
			if a in drop or b in drop or len(sa) != len(sb):
				continue
			if float(np.mean(np.linalg.norm(gp[sa] - gp[sb], axis=1))) > 0.03 * height:
				continue
			share_a = sum(1 for r in lr if r != a and parent[r] == parent[a])
			share_b = sum(1 for r in lr if r != b and parent[r] == parent[b])
			keep, dup = (sa, sb) if share_a >= share_b else (sb, sa)
			drop += dup
			to.update({d: k for d, k in zip(dup, keep)})
	if not drop:
		return g
	print("   лишняя нога-копия: %s → %s" % ([g["names"][b] for b in drop], [g["names"][to[b]] for b in drop]))
	jn = g["joints"].copy()
	wt = g["weights"].copy()
	for d, k in to.items():
		jn[jn == d] = k
	for a in range(jn.shape[1]):  # одна кость дважды у вершины — веса складываются
		for b in range(a + 1, jn.shape[1]):
			same = (jn[:, a] == jn[:, b]) & (wt[:, b] > 0.0)
			wt[same, a] += wt[same, b]
			wt[same, b] = 0.0
	keep = [b for b in range(len(parent)) if b not in drop]
	inv = np.full(len(parent), -1, dtype=np.int64)
	inv[keep] = np.arange(len(keep))
	out = dict(g)
	out["names"] = [g["names"][b] for b in keep]
	out["parent"] = np.array([inv[parent[b]] if parent[b] >= 0 else -1 for b in keep])
	out["grot"] = g["grot"][keep]
	out["gpos"] = g["gpos"][keep]
	out["joints"] = inv[jn]
	out["weights"] = wt
	return out


def lift_tail_to_feet(g: dict, roles: dict, height: float) -> None:
	"""ground: "feet" — земля по лапам, а не по низу меша: хвост, лежащий ниже лап, в позе покоя приподнимается
	(как c.tail(lift), сильнее у основания), пока низ меша не окажется на уровне лап; меш и скелет — в новой позе покоя."""
	legs = set()
	for lg in roles["legs"].values():
		legs.update(lg["chain"])
		for t in lg["toes"]:
			legs.update(t)
	dom = g["joints"][np.arange(len(g["pos"])), np.argmax(g["weights"], 1)]
	foot_y = float(g["pos"][np.isin(dom, list(legs)), 1].min())
	if float(g["pos"][:, 1].min()) >= foot_y - 0.002:
		return
	rig = Rig(roles["names"], g["parent"], g["grot"], g["gpos"])
	tail = roles["tail"]
	n = len(tail)
	best = None
	for step in range(1, 91):
		a = 0.02 * step
		P = {"root_off": np.zeros(3), "trans": {}, "ik": {},
			"rot": {b: body_rot(-a * 2.0 * (n - k) / (n * (n + 1))) for k, b in enumerate(tail)}}
		_L, _T, Gr, Gp, _i = evaluate(rig, P)
		v = skin_points(rig, g["pos"], g["joints"], g["weights"], Gr, Gp)
		best = (a, Gr, Gp, v)
		if float(v[:, 1].min()) >= foot_y - 0.002:
			break
	a, Gr, Gp, v = best
	R = Gr @ rig.grot.transpose(0, 2, 1)
	nrm = np.zeros_like(g["nrm"])
	for k in range(g["joints"].shape[1]):
		nrm += g["weights"][:, k:k + 1] * np.einsum("vij,vj->vi", R[g["joints"][:, k]], g["nrm"])
	nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
	off = np.array([0.0, -foot_y, 0.0])
	g["pos"], g["nrm"], g["grot"], g["gpos"] = v + off, nrm, Gr, Gp + off
	print("   земля по лапам (было %.3f м ниже лап): хвост приподнят на %.0f°, низ меша %.3f" % (
		foot_y, math.degrees(a), float(v[:, 1].min()) - foot_y))


def to_game_space(src: dict, height: float) -> dict:
	"""Поворот мордой в +Z, масштаб до нужной высоты, ноги на y = 0. Кости — без масштаба."""
	yaw = facing_yaw(src)
	R = ry(yaw)
	pos = src["pos"] @ R.T
	s = height / float(pos[:, 1].max() - pos[:, 1].min())
	pos = pos * s
	off = np.array([0.0, -pos[:, 1].min(), 0.0])
	out = dict(src)
	out["pos"] = pos + off
	out["nrm"] = src["nrm"] @ R.T
	out["gpos"] = src["gpos"] @ R.T * s + off
	out["grot"] = np.einsum("ij,bjk->bik", R, src["grot"])
	out["yaw_deg"] = round(math.degrees(yaw))
	out["scale"] = s
	return out


def detect_roles(names: list, parent: np.ndarray, gpos: np.ndarray, height: float, cfg: dict) -> dict:
	"""Роли костей по иерархии и позам покоя (модель уже мордой в +Z, X — влево от зверя)."""
	B = len(parent)
	ch = children_of(parent)
	roots = [b for b in range(B) if parent[b] < 0]
	if len(roots) != 1:
		raise ValueError("ждём один корень скелета, найдено %d" % len(roots))
	root = roots[0]
	lr = leg_roots(parent, gpos, 0.1 * height)
	if len(lr) not in (2, 4):
		lr = side_leg_roots(parent, gpos, height)
	leg_set = set()
	for r in lr:
		leg_set.update(subtree(ch, r))
	body = [b for b in range(B) if b not in leg_set]

	def chain(r):
		c = [r]
		while len(ch[c[-1]]) == 1:
			c.append(ch[c[-1]][0])
		return c

	legs = {}
	if len(lr) == 4:
		kind = "quadruped"
		srt = sorted(lr, key=lambda b: -gpos[b, 2])
		for r in srt[:2]:
			legs["F" + ("L" if gpos[r, 0] > 0 else "R")] = r
		for r in srt[2:]:
			legs["B" + ("L" if gpos[r, 0] > 0 else "R")] = r
		front_attach = int(parent[legs["FL"]])
		back_attach = int(parent[legs["BL"]])
	elif len(lr) == 2:
		kind = "biped"
		for r in lr:
			legs["L" if gpos[r, 0] > 0 else "R"] = r
		front_attach = back_attach = int(parent[legs["L"]])
	else:
		raise ValueError("не понял ноги: найдено %d начал ног у земли" % len(lr))
	if len(legs) != len(lr):
		raise ValueError("ноги не разошлись по сторонам: %s" % legs)

	roles = {"kind": kind, "root": root, "legs": {}}
	for key, r in legs.items():
		c = chain(r)
		toes = [chain(t) for t in sorted(ch[c[-1]], key=lambda t: gpos[t, 0])] if len(ch[c[-1]]) > 1 else []
		roles["legs"][key] = {"chain": c, "toes": toes}

	# Голова: путь от корня к самой «передне-верхней» кости тела; голова — последний узел с ветвлением после груди
	tip = max(body, key=lambda b: gpos[b, 1] + gpos[b, 2])
	hp = path_to(parent, tip)
	if front_attach not in hp:
		raise ValueError("передние ноги не на пути к голове")
	ia = hp.index(front_attach)

	def bch(b):
		return [c for c in ch[b] if c not in leg_set]

	head = None
	for k in range(len(hp) - 1, ia, -1):
		if len(bch(hp[k])) >= 2:
			head = hp[k]
			break
	if head is None:
		head = hp[-2] if (not ch[hp[-1]] and len(hp) - 2 > ia) else hp[-1]
	ih = hp.index(head)
	roles["head"] = head
	roles["neck"] = hp[ia + 1:ih]
	roles["spine"] = hp[1:ia + 1]
	roles["chest"] = front_attach
	roles["hips"] = back_attach
	# Хвост: путь к самой задней кости тела
	rear = min(body, key=lambda b: (gpos[b, 2], len(ch[b])))
	tp = path_to(parent, rear)
	while len(ch[tp[-1]]) == 1:  # хвост, загнутый вперёд (кончик не самый задний), — до конца цепочки
		tp.append(ch[tp[-1]][0])
	div = next((k for k, b in enumerate(tp) if b not in hp), len(tp))
	tail_part = tp[div:]
	if back_attach in tail_part:
		j = tail_part.index(back_attach)
		roles["back"] = tail_part[:j + 1]
		roles["tail"] = tail_part[j + 1:]
	else:
		roles["back"] = []
		roles["tail"] = tail_part
	if len(roles["tail"]) < 1:
		raise ValueError("не нашёл хвост")

	# Имена
	nm = {root: "Root"}
	k = 0
	for b in roles["spine"]:
		if b == front_attach and kind == "quadruped":
			nm[b] = "Chest"
		elif b == back_attach:
			nm[b] = "Hips"
		else:
			k += 1
			nm[b] = "Spine%d" % k
	for i, b in enumerate(roles["back"]):
		nm[b] = "Hips" if b == back_attach else "Back%d" % (i + 1)
	for i, b in enumerate(roles["neck"]):
		nm[b] = "Neck%d" % (i + 1) if len(roles["neck"]) > 1 else "Neck"
	nm[head] = "Head"
	for i, b in enumerate(roles["tail"]):
		nm[b] = "Tail%d" % (i + 1)
	for key, lg in roles["legs"].items():
		for i, b in enumerate(lg["chain"]):
			nm[b] = "Leg%s%d" % (key, i + 1)
		for ti, toe in enumerate(lg["toes"]):
			for i, b in enumerate(toe):
				nm[b] = "Toe%s%d_%d" % (key, ti + 1, i + 1)
	# Отростки головы: уши (две ветки по сторонам) или кончик морды
	hx = bch(head)
	roles["ears"] = {"L": [], "R": []}
	roles["head_extra"] = []
	lat = [c for c in hx if abs(gpos[c, 0] - gpos[head, 0]) > 0.01 * height]
	if len(hx) >= 2 and lat:
		# Уши — самая высокая боковая ветка с каждой стороны; прочие ветки (глаза, челюсть, нос, грива) — HeadX
		ears = {}
		for c in lat:
			side = "L" if gpos[c, 0] > gpos[head, 0] else "R"
			top = max(gpos[b, 1] for b in subtree(ch, c))
			if side not in ears or top > ears[side][0]:
				ears[side] = (top, c)
		n_hx = 0
		for c in hx:
			side = "L" if gpos[c, 0] > gpos[head, 0] else "R"
			if side in ears and ears[side][1] == c:
				for i, b in enumerate(subtree(ch, c)):
					nm[b] = "Ear%s%d" % (side, i + 1)
					roles["ears"][side].append(b)
			else:
				n_hx += 1
				for i, b in enumerate(subtree(ch, c)):
					nm[b] = "HeadX%d_%d" % (n_hx, i + 1)
					roles["head_extra"].append(b)
	else:
		for i, b in enumerate(sum((subtree(ch, c) for c in hx), [])):
			nm[b] = "HeadEnd" if i == 0 else "HeadEnd%d" % (i + 1)
			roles["head_extra"].append(b)
	# Прочие ветки (горловой мешок, гребень и т. п.)
	roles["extra"] = []
	n_extra = 0
	for b in range(B):
		if b in nm:
			continue
		p = int(parent[b])
		if p in nm and not nm[p].startswith("Extra"):
			n_extra += 1
			base = "Throat" if (roles["neck"] and p in roles["neck"] and gpos[b, 1] <= gpos[p, 1]) else "Extra%d_" % n_extra
			for i, x in enumerate(subtree(ch, b)):
				nm[x] = "%s%d" % (base, i + 1)
				roles["extra"].append(x)
	missing = [names[b] for b in range(B) if b not in nm]
	if missing:
		raise ValueError("кости без роли: %s" % missing)
	roles["names"] = [nm[b] for b in range(B)]
	if len(set(roles["names"])) != B:
		raise ValueError("повтор имён костей: %s" % roles["names"])
	return roles


# ---------- Упрощение меша ----------

def weld_same(m: dict) -> dict:
	"""Сварка вершин с одинаковыми позицией и UV (различаются только нормалью): нормали усредняются."""
	key = np.hstack([np.round(m["pos"] / 1e-6), np.round(m["uv"] / 1e-6)]).astype(np.int64)
	_, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
	inv = inv.ravel()
	out = dict(m)
	for k in ("pos", "uv", "joints", "weights"):
		out[k] = m[k][first]
	n = np.zeros((len(first), 3))
	np.add.at(n, inv, m["nrm"])
	out["nrm"] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
	out["tris"] = inv[m["tris"]]
	return out


def simplify_mesh(m: dict, target_tris: int) -> dict:
	"""Упрощение meshoptimizer: вершины не сдвигаются, остаются исходные (с их UV, нормалями и весами).
	Сначала свариваются вершины, различающиеся только нормалью (иначе такие «швы» запирают упрощение).
	Швы UV (вершины с одной позицией и разными UV) meshoptimizer сам держит согласованными;
	разница UV и нормалей входит в метрику ошибки, чтобы не плыли границы участков текстуры."""
	import ctypes
	import meshoptimizer as mo
	from meshoptimizer._loader import lib
	m = weld_same(m)
	idx = np.ascontiguousarray(m["tris"].astype(np.uint32).ravel())
	vp = np.ascontiguousarray(m["pos"].astype(np.float32))
	attrs = np.ascontiguousarray(np.hstack([m["uv"], m["nrm"]]).astype(np.float32))
	aw = np.array([1.0, 1.0, 0.25, 0.25, 0.25], dtype=np.float32)
	dest = np.zeros(len(idx), dtype=np.uint32)
	err = ctypes.c_float(0.0)
	# У обёртки Python нет сигнатуры этой функции — задаём сами (size_t, float), иначе аргументы портятся
	P = ctypes.POINTER
	fn = lib.meshopt_simplifyWithAttributes
	fn.argtypes = [P(ctypes.c_uint), P(ctypes.c_uint), ctypes.c_size_t, P(ctypes.c_float), ctypes.c_size_t,
		ctypes.c_size_t, P(ctypes.c_float), ctypes.c_size_t, P(ctypes.c_float), ctypes.c_size_t,
		P(ctypes.c_ubyte), ctypes.c_size_t, ctypes.c_float, ctypes.c_uint, P(ctypes.c_float)]
	fn.restype = ctypes.c_size_t
	n = fn(dest.ctypes.data_as(P(ctypes.c_uint)), idx.ctypes.data_as(P(ctypes.c_uint)), len(idx),
		vp.ctypes.data_as(P(ctypes.c_float)), len(vp), 12, attrs.ctypes.data_as(P(ctypes.c_float)),
		attrs.shape[1] * 4, aw.ctypes.data_as(P(ctypes.c_float)), len(aw),
		None, target_tris * 3, 1.0, 0, ctypes.byref(err))
	t = dest[:n].astype(np.int64).reshape(-1, 3)
	# Вырожденные треугольники (две вершины в одной точке) — прочь
	p = m["pos"]
	cr = np.linalg.norm(np.cross(p[t[:, 1]] - p[t[:, 0]], p[t[:, 2]] - p[t[:, 0]]), axis=1)
	t = t[cr > 1e-12]
	# Порядок треугольников под кэш вершин, потом вершины по порядку первого использования
	flat = np.ascontiguousarray(t.astype(np.uint32).ravel())
	opt = np.zeros_like(flat)
	mo.optimize_vertex_cache(opt, flat, len(flat), len(p))
	t = opt.astype(np.int64).reshape(-1, 3)
	_, first = np.unique(t.ravel(), return_index=True)
	used = t.ravel()[np.sort(first)]
	remap = np.full(len(p), -1, dtype=np.int64)
	remap[used] = np.arange(len(used))
	out = dict(m)
	for k in ("pos", "nrm", "uv", "joints", "weights"):
		out[k] = m[k][used]
	out["tris"] = remap[t]
	out["simplify_error"] = float(err.value)
	return out


def mesh_stats(pos: np.ndarray, tris: np.ndarray) -> dict:
	"""Открытые рёбра по позициям (после сварки швов) — для сравнения до/после упрощения."""
	q = np.round(pos / 1e-5).astype(np.int64)
	_, weld = np.unique(q, axis=0, return_inverse=True)
	weld = weld.ravel()
	e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
	e = np.sort(weld[e], axis=1)
	e = e[e[:, 0] != e[:, 1]]
	_, cnt = np.unique(e, axis=0, return_counts=True)
	return {"tris": int(len(tris)), "verts": int(len(pos)), "open_edges": int((cnt == 1).sum())}


# ---------- Просмотр: точечный растеризатор меша и «палочки» скелета ----------

VIEWS = {
	# имя: (ось экрана X, знак), (ось экрана Y, знак), (ось глубины, знак «ближе к камере»)
	"side": ((2, 1.0), (1, 1.0), (0, -1.0)),  # справа от зверя, морда вправо
	"top": ((0, -1.0), (2, 1.0), (1, 1.0)),  # сверху, морда вверх
	"front": ((0, 1.0), (1, 1.0), (2, 1.0)),  # спереди
}


def render_mesh(pos: np.ndarray, tris: np.ndarray, uv: np.ndarray, tex, views=("side", "top", "front"),
		size: int = 360, samples: int = 500000, box=None):
	"""Картинка PIL: меш точками по поверхности (z-буфер), цвет из текстуры, простой свет."""
	from PIL import Image
	rng = np.random.default_rng(1)
	a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
	cr = np.cross(b - a, c - a)
	area = 0.5 * np.linalg.norm(cr, axis=1)
	fn = cr / np.maximum(2.0 * area[:, None], 1e-12)
	sel = rng.choice(len(tris), samples, p=area / area.sum())
	r1, r2 = rng.random(samples), rng.random(samples)
	flip = r1 + r2 > 1.0
	r1[flip], r2[flip] = 1.0 - r1[flip], 1.0 - r2[flip]
	p = a[sel] + r1[:, None] * (b - a)[sel] + r2[:, None] * (c - a)[sel]
	if tex is not None:
		ta, tb, tc = uv[tris[sel, 0]], uv[tris[sel, 1]], uv[tris[sel, 2]]
		t = ta + r1[:, None] * (tb - ta) + r2[:, None] * (tc - ta)
		h, w = tex.shape[:2]
		col = tex[np.clip((t[:, 1] % 1.0) * h, 0, h - 1).astype(int), np.clip((t[:, 0] % 1.0) * w, 0, w - 1).astype(int)] / 255.0
	else:
		col = np.full((samples, 3), 0.8)
	light = np.array([0.4, 0.8, 0.45])
	col = col * (0.45 + 0.55 * np.abs(fn[sel] @ (light / np.linalg.norm(light))))[:, None]
	lo, hi = (pos.min(0), pos.max(0)) if box is None else box
	span = float((hi - lo).max()) * 1.08
	panels = []
	for v in views:
		(ax, sx), (ay, sy), (az, sz) = VIEWS[v]
		cx, cy = (lo[ax] + hi[ax]) * 0.5, (lo[ay] + hi[ay]) * 0.5
		px = ((p[:, ax] - cx) * sx / span + 0.5) * (size - 1)
		py = (0.5 - (p[:, ay] - cy) * sy / span) * (size - 1)
		ix, iy = px.astype(int), py.astype(int)
		ok = (ix >= 0) & (ix < size) & (iy >= 0) & (iy < size)
		pix = iy[ok] * size + ix[ok]
		dep = -p[ok, az] * sz
		order = np.lexsort((dep, pix))
		pix_s = pix[order]
		first = np.ones(len(pix_s), dtype=bool)
		first[1:] = pix_s[1:] != pix_s[:-1]
		buf = np.full((size * size, 3), 0.93)
		buf[pix_s[first]] = col[ok][order][first]
		img = (buf.reshape(size, size, 3) * 255).astype(np.uint8)
		if v != "top":
			gy = int((0.5 - (0.0 - cy) * sy / span) * (size - 1))
			if 0 <= gy < size:
				img[gy, :, :] = (60, 140, 60)
		panels.append(Image.fromarray(img))
	out = Image.new("RGB", (size * len(panels), size), (255, 255, 255))
	for i, im in enumerate(panels):
		out.paste(im, (i * size, 0))
	return out


def draw_sticks(frames: list, parent: np.ndarray, view: str = "side", size: int = 220, span: float = 2.0,
		center=(0.0, 0.5, 0.0), marks=None, title: str = ""):
	"""Ряд кадров «палочками»: frames — список (B, 3) мировых позиций суставов. marks — {кость: цвет}."""
	from PIL import Image, ImageDraw
	(ax, sx), (ay, sy), (az, sz) = VIEWS[view]
	img = Image.new("RGB", (size * len(frames), size + 14), (250, 250, 250))
	d = ImageDraw.Draw(img)
	d.text((4, size), title, fill=(0, 0, 0))
	for fi, gp in enumerate(frames):
		ox = fi * size

		def P(v):
			return (ox + ((v[ax] - center[ax]) * sx / span + 0.5) * size, ((0.5 - (v[ay] - center[ay]) * sy / span)) * size)

		if view != "top":
			gy = P(np.zeros(3))[1]
			d.line([(ox, gy), (ox + size, gy)], fill=(80, 160, 80))
		d.line([(ox + size - 1, 0), (ox + size - 1, size)], fill=(200, 200, 200))
		order = np.argsort(gp[:, az] * sz)  # дальние раньше
		for b in order:
			p = int(parent[b])
			if p < 0:
				continue
			far = gp[b, az] * sz < np.median(gp[:, az] * sz) - 0.02
			colr = (150, 150, 190) if far else (20, 20, 60)
			if marks and b in marks:
				colr = tuple(int(c + (255 - c) * 0.55) for c in marks[b]) if far else marks[b]
			d.line([P(gp[p]), P(gp[b])], fill=colr, width=2)
		d.text((ox + 3, 2), str(fi), fill=(120, 0, 0))
	return img


# ---------- Скелет, ноги (IK) и решение позы ----------

I3 = np.eye(3)


def topo_order(parent: np.ndarray) -> list:
	ch = children_of(parent)
	root = [b for b in range(len(parent)) if parent[b] < 0][0]
	order, stack = [], [root]
	while stack:
		b = stack.pop()
		order.append(b)
		stack.extend(reversed(ch[b]))
	return order


def reorder(src: dict, order: list) -> dict:
	"""Кости по порядку «родитель раньше детей»; индексы костей у вершин — по новому порядку."""
	inv = np.empty(len(order), dtype=np.int64)
	inv[order] = np.arange(len(order))
	out = dict(src)
	out["names"] = [src["names"][b] for b in order]
	out["parent"] = np.array([inv[src["parent"][b]] if src["parent"][b] >= 0 else -1 for b in order])
	out["grot"] = src["grot"][order]
	out["gpos"] = src["gpos"][order]
	out["joints"] = inv[src["joints"]]
	return out


def slerp_m(a: np.ndarray, b: np.ndarray, w: float) -> np.ndarray:
	qa, qb = m_to_q(a), m_to_q(b)
	d = float(np.dot(qa, qb))
	if d < 0.0:
		qb, d = -qb, -d
	if d > 0.9995:
		q = qa + (qb - qa) * w
	else:
		th = math.acos(min(d, 1.0))
		q = (math.sin((1 - w) * th) * qa + math.sin(w * th) * qb) / math.sin(th)
	return q_to_m(q)


class Rig:
	"""Скелет в позе покоя (мировые = пространство модели) и локальные трансформы костей."""

	def __init__(self, names: list, parent: np.ndarray, grot: np.ndarray, gpos: np.ndarray):
		self.names = list(names)
		self.parent = np.asarray(parent).copy()
		self.grot = np.asarray(grot, dtype=np.float64).copy()
		self.gpos = np.asarray(gpos, dtype=np.float64).copy()
		self.legs = {}
		self.ik_upper = {}
		self._locals()

	def _locals(self):
		B = len(self.names)
		self.B = B
		self.lrot = np.zeros((B, 3, 3))
		self.lpos = np.zeros((B, 3))
		for b in range(B):
			p = self.parent[b]
			if p < 0:
				self.lrot[b] = self.grot[b]
				self.lpos[b] = self.gpos[b]
			else:
				self.lrot[b] = self.grot[p].T @ self.grot[b]
				self.lpos[b] = self.grot[p].T @ (self.gpos[b] - self.gpos[p])
		self.ch = children_of(self.parent)
		self.idx = {n: i for i, n in enumerate(self.names)}

	def add_bone(self, name: str, parent: int, gpos, grot=None) -> int:
		self.names.append(name)
		self.parent = np.append(self.parent, parent)
		self.gpos = np.vstack([self.gpos, np.asarray(gpos, dtype=np.float64)[None]])
		self.grot = np.concatenate([self.grot, (I3 if grot is None else grot)[None]])
		self._locals()
		return len(self.names) - 1


class Leg:
	"""Нога: проксимальные кости (лопатка), пара IK (плечо+предплечье / бедро+голень), дистальные (кисть, пальцы).
	Дистальная часть твёрдая: её поворот задаётся «сгибом» вокруг оси X у точки опоры."""

	def __init__(self, rig: Rig, key: str, chain: list, toes: list, upper_i: int, prox_swing: float):
		self.key = key
		self.chain = chain
		self.toes = toes
		self.prox = chain[:upper_i]
		self.u, self.l, self.a = chain[upper_i], chain[upper_i + 1], chain[upper_i + 2]
		self.distal = subtree(rig.ch, self.a)
		gp = rig.gpos
		# Точка опоры (ось подъёма пятки): самый передний из суставов кисти/стопы у земли,
		# чтобы при подъёме пятки пальцы не уходили в землю
		low = min(gp[b, 1] for b in self.distal)
		self.c = max((b for b in self.distal if gp[b, 1] < low + 0.04), key=lambda b: gp[b, 2])
		S, K, A, C = gp[self.u], gp[self.l], gp[self.a], gp[self.c]
		self.l1 = float(np.linalg.norm(K - S))
		self.l2 = float(np.linalg.norm(A - K))
		self.o = C - A
		# Ось сустава (колено/локоть) в покое: перпендикуляр к плоскости сгиба. Если нога почти прямая —
		# ось X (сгиб вперёд-назад). Знак: куда выгнут сустав относительно линии «таз — лодыжка».
		hinge = np.cross(K - S, A - K)
		if np.linalg.norm(hinge) < 1e-3 * self.l1 * self.l2:
			hinge = np.array([1.0, 0.0, 0.0])
		self.hinge = hinge / np.linalg.norm(hinge)
		dn = (A - S) / np.linalg.norm(A - S)
		self.bend = 1.0 if np.dot(np.cross(self.hinge, dn), K - S) >= 0.0 else -1.0
		self.u0 = (K - S) / self.l1
		self.d0 = (A - K) / self.l2
		self.neutral = C.copy()
		self.side = 1.0 if gp[chain[0], 0] > 0 else -1.0
		self.height = float(gp[chain[0], 1] - C[1])
		self.reach = float(np.linalg.norm(A - S) / (self.l1 + self.l2))
		self.prox_swing = prox_swing


def pick_upper(rig: Rig, chain: list) -> int:
	"""Пара IK по умолчанию: две соседние кости с наибольшей суммарной длиной (за ними должна быть ещё кость)."""
	gp = rig.gpos
	seg = [float(np.linalg.norm(gp[chain[k + 1]] - gp[chain[k]])) for k in range(len(chain) - 1)]
	best = max(range(len(chain) - 2), key=lambda k: seg[k] + seg[k + 1])
	return best


FLEX_STEPS = sorted(np.arange(-1.3, 1.3001, 0.02), key=abs)


def solve_leg(rig: Rig, leg: Leg, S: np.ndarray, Rd: np.ndarray, spec: dict) -> tuple:
	"""Аналитический IK на две кости. spec: target (куда поставить точку опоры), flex (сгиб дистальной части),
	curl (поджать пальцы). Если не достаёт — сначала дополнительный сгиб дистальной части (подъём пятки),
	потом нога вытягивается к цели (опора отрывается)."""
	target = np.asarray(spec["target"], dtype=np.float64)
	flex = float(spec.get("flex", 0.0))
	hinge = Rd @ leg.hinge
	rmax = 0.995 * (leg.l1 + leg.l2)
	rmin = abs(leg.l1 - leg.l2) + 0.05 * (leg.l1 + leg.l2)
	used = flex
	A = target - rx(flex) @ leg.o
	if np.linalg.norm(A - S) > rmax:
		for df in FLEX_STEPS:
			A2 = target - rx(flex + df) @ leg.o
			if np.linalg.norm(A2 - S) <= rmax:
				used, A = flex + df, A2
				break
	dv = A - S
	d = float(np.linalg.norm(dv))
	short = 0.0
	if d > rmax:
		short = d - rmax
		A = S + dv * (rmax / d)
		d = rmax
	elif d < rmin:
		A = S + dv * (rmin / d)
		d = rmin
	dn = (A - S) / d
	a = (leg.l1 ** 2 - leg.l2 ** 2 + d * d) / (2.0 * d)
	h = math.sqrt(max(leg.l1 ** 2 - a * a, 0.0))
	pp = np.cross(hinge, dn)
	pp = leg.bend * pp / max(np.linalg.norm(pp), 1e-9)
	K = S + dn * a + pp * h
	Ru = frame_from(K - S, hinge) @ frame_from(leg.u0, leg.hinge).T
	Rl = frame_from(A - K, hinge) @ frame_from(leg.d0, leg.hinge).T
	F = rx(used)
	out = {leg.u: Ru @ rig.grot[leg.u], leg.l: Rl @ rig.grot[leg.l]}
	for b in leg.distal:
		out[b] = F @ rig.grot[b]
	curl = float(spec.get("curl", 0.0))
	if curl and leg.toes:
		for toe in leg.toes:
			n = len(toe)
			for k, b in enumerate(toe):
				ch = rig.ch[b]
				nxt = rig.gpos[ch[0]] if ch else rig.gpos[b] + (rig.gpos[b] - rig.gpos[toe[k - 1]] if k else np.array([0, 0, 0.01]))
				dirv = nxt - rig.gpos[b]
				ax = np.cross(dirv, [0.0, 1.0, 0.0])
				if np.linalg.norm(ax) < 1e-6:
					continue
				out[b] = F @ rot_axis(ax, -curl * (k + 1) / n) @ rig.grot[b]
	return out, short, used


def evaluate(rig: Rig, P: dict) -> tuple:
	"""Поза → локальные повороты (B,3,3), мировые повороты и позиции суставов, сведения об IK.
	P: root_off — сдвиг корня; rot — {кость: поворот в осях модели}; trans — {кость: сдвиг в осях модели};
	ik — {нога: spec для solve_leg, w — вес IK (0 — нога свободна, повороты из rot)}."""
	B = rig.B
	Gr = np.zeros((B, 3, 3))
	Gp = np.zeros((B, 3))
	L = np.zeros((B, 3, 3))
	T = np.zeros((B, 3))
	rot = P.get("rot", {})
	trans = P.get("trans", {})
	ik = P.get("ik", {})
	desired, wmap, info = {}, {}, {}
	for b in range(B):
		p = rig.parent[b]
		d = rot.get(b)
		if p < 0:
			Gr[b] = (I3 if d is None else d) @ rig.grot[b]
			Gp[b] = rig.gpos[b] + P.get("root_off", np.zeros(3))
			L[b] = Gr[b]
			T[b] = Gp[b]
			continue
		loc = rig.lrot[b] if d is None else rig.lrot[b] @ rig.grot[b].T @ d @ rig.grot[b]
		lp = rig.lpos[b] if b not in trans else rig.lpos[b] + Gr[p].T @ np.asarray(trans[b])
		key = rig.ik_upper.get(b)
		if key is not None and key in ik and ik[key].get("w", 1.0) > 0.0:
			leg = rig.legs[key]
			S = Gp[p] + Gr[p] @ lp
			des, short, used = solve_leg(rig, leg, S, Gr[p] @ rig.grot[p].T, ik[key])
			for x, g in des.items():
				desired[x] = g
				wmap[x] = float(ik[key].get("w", 1.0))
			info[key] = {"short": short, "flex": used}
		if b in desired:
			loc_ik = Gr[p].T @ desired[b]
			w = wmap[b]
			loc = loc_ik if w >= 0.999 else slerp_m(loc, loc_ik, w)
		L[b] = loc
		T[b] = lp
		Gr[b] = Gr[p] @ loc
		Gp[b] = Gp[p] + Gr[p] @ lp
	return L, T, Gr, Gp, info


def skin_points(rig: Rig, pos: np.ndarray, joints: np.ndarray, weights: np.ndarray, Gr: np.ndarray, Gp: np.ndarray) -> np.ndarray:
	R = Gr @ rig.grot.transpose(0, 2, 1)
	t = Gp - np.einsum("bij,bj->bi", R, rig.gpos)
	out = np.zeros_like(pos)
	for k in range(joints.shape[1]):
		j = joints[:, k]
		out += weights[:, k:k + 1] * (np.einsum("vij,vj->vi", R[j], pos) + t[j])
	return out


# ---------- Хореография: помощники ----------

class Ctx:
	"""Скелет с ролями костей и помощники для поз: всё в осях модели (X — влево от зверя, Y — вверх, Z — вперёд)."""

	def __init__(self, rig: Rig, roles: dict, cfg: dict):
		self.rig = rig
		self.roles = roles
		self.cfg = cfg
		self.H = cfg["height"]
		self.root = roles["root"]
		self.head_b = roles["head"]
		self.neck_b = list(roles["neck"])
		self.tail_b = list(roles["tail"])
		sp = list(roles["spine"])
		if roles["hips"] in sp:
			sp = sp[sp.index(roles["hips"]) + 1:]
		self.flex_b = [b for b in sp if b != roles["chest"]]
		self.ears_b = roles["ears"]
		self.wing_b = roles.get("wings", {})
		self.bob_k = None

	@staticmethod
	def pose() -> dict:
		return {"root_off": np.zeros(3), "rot": {}, "trans": {}, "ik": {}, "pitch": 0.0}

	def rot(self, P: dict, b: int, M: np.ndarray) -> None:
		P["rot"][b] = M @ P["rot"].get(b, I3)

	def chain(self, P: dict, bones: list, pitch_up: float = 0.0, yaw: float = 0.0, roll: float = 0.0) -> None:
		if not bones:
			return
		n = len(bones)
		M = body_rot(pitch_up / n, yaw / n, roll / n)
		for b in bones:
			self.rot(P, b, M)

	def body(self, P: dict, pitch_up: float = 0.0, yaw: float = 0.0, roll: float = 0.0, dy: float = 0.0) -> None:
		"""Поворот всего тела вокруг корня (у этих скелетов корень — у тазобедренных суставов) и подъём/опускание."""
		self.rot(P, self.root, body_rot(pitch_up, yaw, roll))
		P["root_off"] = P["root_off"] + np.array([0.0, dy, 0.0])
		P["pitch"] += pitch_up

	def spine(self, P: dict, pitch_up: float = 0.0, yaw: float = 0.0, roll: float = 0.0) -> None:
		"""Изгиб спины между тазом и грудью: pitch_up > 0 — прогиб (перед выше), < 0 — спина дугой."""
		self.chain(P, self.flex_b, pitch_up, yaw, roll)

	def neck(self, P: dict, pitch_up: float = 0.0, yaw: float = 0.0, roll: float = 0.0) -> None:
		self.chain(P, self.neck_b, pitch_up, yaw, roll)

	def head(self, P: dict, pitch_up: float = 0.0, yaw: float = 0.0, roll: float = 0.0) -> None:
		self.rot(P, self.head_b, body_rot(pitch_up, yaw, roll))

	def tail(self, P: dict, lift: float = 0.0, yaw: float = 0.0, wave: float = 0.0, phase: float = 0.0,
			lag: float = 0.6, wave_pitch: float = 0.0) -> None:
		"""Хвост: lift > 0 — вверх, yaw — в сторону, wave — волна от основания к кончику."""
		n = len(self.tail_b)
		for k, b in enumerate(self.tail_b):
			g = (0.6 + 0.8 * k / max(n - 1, 1)) / n  # волна сильнее к кончику
			gl = 2.0 * (n - k) / (n * (n + 1))  # подъём сильнее у основания
			w = math.sin(phase - k * lag)
			self.rot(P, b, body_rot(-(lift * gl + wave_pitch * g * math.cos(phase - k * lag)), yaw * gl + wave * g * w, 0.0))

	def ears(self, P: dict, back: float = 0.0, twitch_l: float = 0.0, twitch_r: float = 0.0) -> None:
		for side, tw in (("L", twitch_l), ("R", twitch_r)):
			bones = self.ears_b.get(side, [])
			if bones:
				s = 1.0 if side == "L" else -1.0
				self.rot(P, bones[0], body_rot(-back, s * tw, 0.0))

	def wings(self, P: dict, lift: float = 0.0, spread: float = 0.0) -> None:
		"""Крылья (если есть кости WingL/WingR): lift — поднять наружу-вверх, spread — развести концы в стороны."""
		if "L" in self.wing_b:
			self.rot(P, self.wing_b["L"], rz(lift) @ ry(-spread))
		if "R" in self.wing_b:
			self.rot(P, self.wing_b["R"], rz(-lift) @ ry(spread))

	def foot(self, P: dict, key: str, dz: float = 0.0, dy: float = 0.0, dx: float = 0.0, flex: float = 0.0,
			w: float = 1.0, curl: float = 0.0) -> None:
		"""Точка опоры ноги: сдвиг от положения покоя (dx — наружу), flex — сгиб кисти/стопы, w — вес IK."""
		leg = self.rig.legs[key]
		tgt = leg.neutral + np.array([dx * leg.side, dy, dz])
		P["ik"][key] = {"target": tgt, "flex": flex, "w": w, "curl": curl}
		if leg.prox_swing and leg.prox and w > 0.0:
			ang = -leg.prox_swing * dz / max(leg.height, 1e-3) * w
			for b in leg.prox:
				self.rot(P, b, rx(ang / len(leg.prox)))

	def stand(self, P: dict, w: float = 1.0) -> None:
		for key in self.rig.legs:
			if key not in P["ik"]:
				self.foot(P, key, w=w)

	def gait(self, P: dict, t: float, g: dict) -> None:
		"""Цикл шага: опорная фаза — стопа неподвижна в мире (едет назад со скоростью хода),
		переносная — дуга вперёд. td — доля цикла, когда нога встаёт на землю."""
		x = t / g["T"]
		for key, td in g["td"].items():
			p = (x - td) % 1.0
			if p < g["duty"]:
				s = p / g["duty"]
				dz, dy, fl, cu = g["stride"] * (0.5 - s), 0.0, 0.0, 0.0
			else:
				s = (p - g["duty"]) / (1.0 - g["duty"])
				dz = g["stride"] * (-0.5 + s - math.sin(2 * math.pi * s) / (2 * math.pi))
				e = math.sin(math.pi * s)
				dy = g["lift"] * e
				fl = g.get("flex", 0.0) * e
				cu = g.get("curl", 0.0) * e
			self.foot(P, key, dz=dz + g.get("dz0", 0.0), dy=dy, flex=fl, curl=cu)

	def neck_bob(self, P: dict, dz: float) -> None:
		"""Голова вперёд/назад на dz (м) почти без наклона: низ шеи вперёд, верх — назад."""
		if self.bob_k is None:
			self.bob_k = 1.0
			P0 = self.pose()
			self.neck_bob(P0, 0.0)
			P1 = self.pose()
			self.bob_k = 1.0
			self._bob_raw(P1, 0.05)
			h0 = evaluate(self.rig, P0)[3][self.head_b]
			h1 = evaluate(self.rig, P1)[3][self.head_b]
			self.bob_k = max((h1[2] - h0[2]) / 0.05, 1e-3)
		self._bob_raw(P, dz / self.bob_k)

	def _bob_raw(self, P: dict, a: float) -> None:
		n = len(self.neck_b)
		lo, hi = self.neck_b[:n // 2], self.neck_b[n // 2:]
		self.chain(P, lo, -a, 0.0, 0.0)
		self.chain(P, hi, a, 0.0, 0.0)


def gait_speed(g: dict) -> float:
	return g["stride"] / (g["duty"] * g["T"])


TAU = 2.0 * math.pi


def fold_legs(c: Ctx, P: dict, a: float) -> None:
	"""Расслабленные ноги (для падения): передние — лапы вперёд, задние — назад, суставы чуть согнуты."""
	for key, leg in c.rig.legs.items():
		front = key.startswith("F")
		c.rot(P, leg.u, rx((-0.45 if front else 0.35) * a))
		c.rot(P, leg.l, rx((0.7 if front else -0.6) * a))


def quad_clips(c: Ctx) -> list:
	"""Клипы четвероногих: «cat» (пантера) и «turtle» (черепаха)."""
	cfg = c.cfg
	cat = cfg["style"] == "cat"
	H = c.H
	W, R = cfg["walk"], cfg["run"]
	neck0 = c.neck_b[0] if c.neck_b else c.head_b
	out = []

	Ti = cfg.get("idle_T", 2.4)

	def idle(t):
		P = c.pose()
		ph = TAU * t / Ti
		br = 0.5 - 0.5 * math.cos(ph)
		c.body(P, pitch_up=0.01 * br, dy=-0.004 * H * br)
		if cat:
			c.spine(P, pitch_up=0.02 * br)
			c.tail(P, lift=0.2, wave=0.35, phase=ph, lag=0.5, wave_pitch=0.12)
			c.ears(P, twitch_l=0.35 * env(t, 1.30, 1.38, 1.45, 1.6), twitch_r=0.3 * env(t, 0.4, 0.48, 0.55, 0.7))
		else:
			c.tail(P, wave=0.15, phase=ph)
		c.neck(P, pitch_up=0.03 * math.sin(2 * ph), yaw=0.12 * math.sin(ph))
		c.head(P, pitch_up=0.04 * math.sin(ph + 1.0), yaw=0.08 * math.sin(ph - 0.6), roll=0.04 * math.sin(ph))
		c.stand(P)
		return P

	out.append({"name": "Idle", "T": Ti, "loop": True, "fn": idle})

	def walk(t):
		P = c.pose()
		ph = TAU * t / W["T"]
		c.body(P, pitch_up=0.01 * math.sin(2 * ph), roll=(0.025 if cat else 0.05) * math.sin(ph),
			yaw=0.02 * math.sin(ph), dy=-W["crouch"] - 0.006 * H * math.cos(2 * ph))
		if cat:
			c.spine(P, yaw=0.06 * math.sin(ph))
			c.tail(P, lift=0.35, wave=0.3, phase=ph, lag=0.6, wave_pitch=0.08)
		else:
			c.tail(P, wave=0.2, phase=ph)
		c.neck(P, pitch_up=-0.06 + 0.03 * math.sin(2 * ph + 0.5), yaw=-0.05 * math.sin(ph))
		c.head(P, pitch_up=0.05 - 0.02 * math.sin(2 * ph + 0.5))
		c.gait(P, t, W)
		return P

	out.append({"name": "Walk", "T": W["T"], "loop": True, "fn": walk, "speed": gait_speed(W), "gait": W})

	def run(t):
		P = c.pose()
		x = t / R["T"]
		ph = TAU * x
		if cat:
			# Галоп: спина разгибается в фазе «вытянутого» полёта и сгибается дугой в «собранном»
			sp = 0.32 * math.cos(TAU * (x - 0.42))
			bp = 0.07 * math.cos(TAU * (x - 0.95))
			c.body(P, pitch_up=bp, dy=-R["crouch"] + 0.03 * math.cos(2 * TAU * (x - 0.43)))
			c.spine(P, pitch_up=sp)
			c.neck(P, pitch_up=-0.12 - 0.5 * (sp + bp))
			c.head(P, pitch_up=0.05 - 0.2 * (sp + bp))
			c.tail(P, lift=0.9, wave=0.15, phase=ph, wave_pitch=0.3)
			c.ears(P, back=0.35)
		else:
			c.body(P, roll=0.07 * math.sin(ph), yaw=0.03 * math.sin(ph), dy=-R["crouch"] - 0.008 * H * math.cos(2 * ph))
			c.neck(P, pitch_up=-0.12, yaw=-0.06 * math.sin(ph))
			c.head(P, pitch_up=0.12)
			c.tail(P, wave=0.3, phase=ph)
		c.gait(P, t, R)
		return P

	out.append({"name": "Run", "T": R["T"], "loop": True, "fn": run, "speed": gait_speed(R), "gait": R})

	if cat:
		Ta, hit = 0.75, 0.36

		def attack(t):
			# Встаёт на задние, удар правой передней лапой сверху вниз с броском головы (укус)
			P = c.pose()
			c.body(P, pitch_up=keys(t, [(0, 0), (0.2, 0.16), (0.36, -0.06), (0.5, -0.04), (0.75, 0)]),
				dy=keys(t, [(0, 0), (0.2, -0.05), (0.36, -0.02), (0.75, 0)]))
			c.spine(P, pitch_up=keys(t, [(0, 0), (0.2, -0.10), (0.36, 0.12), (0.5, 0.06), (0.75, 0)]))
			c.neck(P, pitch_up=keys(t, [(0, 0), (0.2, 0.15), (0.36, -0.25), (0.5, -0.2), (0.75, 0)]),
				yaw=keys(t, [(0, 0), (0.36, -0.1), (0.75, 0)]))
			c.head(P, pitch_up=keys(t, [(0, 0), (0.2, 0.12), (0.36, -0.12), (0.75, 0)]))
			c.tail(P, lift=keys(t, [(0, 0), (0.2, 0.3), (0.5, 0.2), (0.75, 0)]), wave=0.3 * env(t, 0.1, 0.3, 0.45, 0.75),
				phase=TAU * t / 0.4)
			c.ears(P, back=0.45 * env(t, 0.0, 0.15, 0.5, 0.75))
			c.foot(P, "FR", dz=keys(t, [(0, 0), (0.2, 0.12), (0.37, 0.30), (0.45, 0.30), (0.7, 0)]),
				dy=keys(t, [(0, 0), (0.2, 0.30), (0.30, 0.24), (0.37, 0.02), (0.45, 0.02), (0.56, 0.08), (0.7, 0)]),
				flex=0.6 * env(t, 0.0, 0.15, 0.3, 0.38))
			c.stand(P)
			return P

		def cast(t):
			# Рык: голова вверх, грудь приподнята, хвост вверх
			P = c.pose()
			e = keys(t, [(0, 0), (0.28, 1), (0.58, 1), (0.8, 0)])
			c.body(P, pitch_up=0.12 * e, dy=-0.03 * H * e)
			c.spine(P, pitch_up=0.08 * e)
			c.neck(P, pitch_up=0.45 * e)
			c.head(P, pitch_up=0.25 * e, yaw=0.07 * math.sin(TAU * 9 * t) * env(t, 0.3, 0.36, 0.55, 0.62))
			c.tail(P, lift=0.4 * e, wave=0.2 * e, phase=TAU * t / 0.4)
			c.ears(P, back=0.5 * e)
			c.stand(P)
			return P
	else:
		Ta, hit = 0.7, 0.36

		def attack(t):
			# Выпад головой с укусом: шея назад-вверх, затем бросок вперёд-вниз, перед панциря наклоняется
			P = c.pose()
			c.body(P, pitch_up=keys(t, [(0, 0), (0.22, 0.06), (0.36, -0.10), (0.5, -0.08), (0.7, 0)]),
				dy=keys(t, [(0, 0), (0.22, -0.015), (0.36, -0.02), (0.7, 0)]))
			c.neck(P, pitch_up=keys(t, [(0, 0), (0.22, 0.30), (0.36, -0.35), (0.5, -0.3), (0.7, 0)]))
			c.head(P, pitch_up=keys(t, [(0, 0), (0.22, -0.15), (0.36, 0.20), (0.5, 0.15), (0.7, 0)]))
			P["trans"][neck0] = np.array([0.0, 0.0, keys(t, [(0, 0), (0.22, -0.03), (0.36, 0.06), (0.5, 0.05), (0.7, 0)])])
			c.tail(P, wave=0.2 * env(t, 0.1, 0.3, 0.45, 0.7), phase=TAU * t / 0.35)
			c.stand(P)
			return P

		def cast(t):
			# Втягивает голову в панцирь и упирается лапами: ниже и шире
			P = c.pose()
			e = keys(t, [(0, 0), (0.25, 1), (0.6, 1), (0.8, 0)])
			c.body(P, dy=-0.03 * e)
			P["trans"][neck0] = np.array([0.0, 0.0, -0.09 * e])
			c.neck(P, pitch_up=0.1 * e)
			c.head(P, pitch_up=-0.1 * e)
			c.tail(P, yaw=0.0, lift=-0.1 * e)
			for key in c.rig.legs:
				c.foot(P, key, dx=0.03 * e)
			return P

	out.append({"name": "Attack", "T": Ta, "loop": False, "fn": attack, "hit": hit})

	def hit_fn(t):
		P = c.pose()
		e = keys(t, [(0, 0), (0.07, 1), (0.35, 0)])
		c.body(P, pitch_up=(0.08 if cat else 0.03) * e, roll=0.05 * e, dy=-0.02 * H * e)
		if cat:
			c.spine(P, pitch_up=-0.08 * e)
			c.ears(P, back=0.5 * e)
			c.tail(P, lift=0.25 * e)
		else:
			P["trans"][neck0] = np.array([0.0, 0.0, -0.05 * e])
			c.tail(P, lift=0.2 * e)
		c.neck(P, pitch_up=0.2 * e, yaw=0.1 * e)
		c.head(P, pitch_up=0.1 * e)
		c.stand(P)
		return P

	out.append({"name": "Hit", "T": 0.35, "loop": False, "fn": hit_fn})

	Td = 1.1 if cat else 1.2
	roll_end = 1.45 if cat else 1.25
	h0 = float(c.rig.gpos[c.root, 1])

	def death(t):
		P = c.pose()
		x = t / Td
		roll = keys(x, [(0, 0), (0.25, 0.12), (0.72, roll_end + 0.07), (0.86, roll_end - 0.03), (1.0, roll_end)])
		c.body(P, pitch_up=keys(x, [(0, 0), (0.25, -0.06), (0.7, -0.02)]), roll=roll,
			dy=keys(x, [(0, 0), (0.25, -0.07 * h0), (0.72, -0.6 * h0)]))
		c.neck(P, pitch_up=keys(x, [(0, 0), (0.25, -0.25), (0.75, -0.15)]), roll=keys(x, [(0, 0), (0.75, 0.4)]))
		c.head(P, pitch_up=keys(x, [(0, 0), (0.3, -0.1), (0.75, 0.1)]))
		if cat:
			c.tail(P, lift=keys(x, [(0, 0), (0.6, -0.15)]), yaw=keys(x, [(0, 0), (0.7, 0.3)]))
			c.ears(P, back=keys(x, [(0, 0), (0.3, 0.5)]))
		else:
			P["trans"][neck0] = np.array([0.0, 0.0, keys(x, [(0, 0), (0.3, -0.04), (0.8, -0.02)])])
		w = 1.0 - smooth((x - 0.22) / 0.33)
		c.stand(P, w=w)
		fold_legs(c, P, 1.0 - w)
		return P

	out.append({"name": "Death", "T": Td, "loop": False, "fn": death, "fit_after": 0.72})
	out.append({"name": "Cast", "T": 0.8, "loop": False, "fn": cast, "cast": 0.42})
	return out


def bird_clips(c: Ctx) -> list:
	"""Клипы птицы (фазан): шаг с покачиванием головой, бег с приподнятыми крыльями, клевок, взмахи."""
	cfg = c.cfg
	H = c.H
	W, R = cfg["walk"], cfg["run"]
	out = []

	def tail_guard(P, extra=0.0, wave=0.0, phase=0.0):
		# Хвост у фазана касается земли: при наклоне тела назад он приподнимается, чтобы не уйти в землю
		c.tail(P, lift=max(0.0, P["pitch"]) * 1.3 + extra, wave=wave, phase=phase)

	Ti = 2.6

	def idle(t):
		P = c.pose()
		ph = TAU * t / Ti
		br = 0.5 - 0.5 * math.cos(ph)
		c.body(P, pitch_up=0.012 * br, dy=-0.003 * H * br)
		c.neck(P, pitch_up=0.03 * math.sin(ph))
		c.head(P, yaw=keys(t, [(0, 0), (0.35, 0), (0.45, 0.4), (1.1, 0.4), (1.2, -0.25), (1.9, -0.25), (2.0, 0), (2.6, 0)]),
			roll=0.15 * env(t, 0.45, 0.55, 1.0, 1.1) - 0.1 * env(t, 1.2, 1.3, 1.8, 1.9))
		c.wings(P, lift=0.12 * env(t, 2.0, 2.08, 2.16, 2.32))
		tail_guard(P, extra=0.03, wave=0.05, phase=ph)
		c.stand(P)
		return P

	out.append({"name": "Idle", "T": Ti, "loop": True, "fn": idle})

	def walk(t):
		P = c.pose()
		x = t / W["T"]
		ph = TAU * x
		c.body(P, pitch_up=0.02 * math.sin(2 * ph), roll=-0.05 * math.cos(TAU * (x - 0.3)),
			dy=-W["crouch"] + 0.005 * math.cos(2 * ph))
		# Голова «стоит» в мире, пока тело идёт вперёд, потом рывком догоняет (как у курообразных)
		v = gait_speed(W)
		h = 0.7
		a = v * h * W["T"] / 4.0
		s = (2.0 * x) % 1.0
		dz = a - 2.0 * a * s / h if s < h else -a + 2.0 * a * smooth((s - h) / (1.0 - h))
		c.neck_bob(P, dz)
		c.wings(P, lift=0.03)
		tail_guard(P, extra=0.03 + 0.03 * math.sin(2 * ph), wave=0.06, phase=ph)
		c.gait(P, t, W)
		return P

	out.append({"name": "Walk", "T": W["T"], "loop": True, "fn": walk, "speed": gait_speed(W), "gait": W})

	def run(t):
		P = c.pose()
		x = t / R["T"]
		ph = TAU * x
		c.body(P, pitch_up=-0.22 + 0.02 * math.sin(2 * ph), roll=-0.04 * math.cos(TAU * (x - 0.2)),
			dy=-R["crouch"] + 0.008 * math.cos(2 * ph))
		c.neck(P, pitch_up=-0.30)
		c.head(P, pitch_up=0.35)
		c.wings(P, lift=0.35 + 0.12 * math.sin(2 * ph), spread=0.15)
		tail_guard(P, extra=0.12, wave=0.05, phase=ph)
		c.gait(P, t, R)
		return P

	out.append({"name": "Run", "T": R["T"], "loop": True, "fn": run, "speed": gait_speed(R), "gait": R})

	def attack(t):
		# Клевок: замах назад с поднятыми крыльями, бросок вниз-вперёд, ещё один взмах
		P = c.pose()
		c.body(P, pitch_up=keys(t, [(0, 0), (0.22, 0.14), (0.38, -0.32), (0.5, -0.25), (0.7, 0)]))
		c.neck(P, pitch_up=keys(t, [(0, 0), (0.22, 0.25), (0.38, -0.5), (0.5, -0.42), (0.7, 0)]))
		c.head(P, pitch_up=keys(t, [(0, 0), (0.22, 0.1), (0.38, -0.2), (0.7, 0)]))
		c.neck_bob(P, keys(t, [(0, 0), (0.22, -0.05), (0.38, 0.07), (0.5, 0.05), (0.7, 0)]))
		c.wings(P, lift=keys(t, [(0, 0), (0.15, 0.75), (0.3, 0.15), (0.42, 0.6), (0.55, 0.2), (0.7, 0)]),
			spread=0.3 * env(t, 0.05, 0.15, 0.5, 0.7))
		tail_guard(P, extra=0.1 * env(t, 0.0, 0.2, 0.5, 0.7))
		c.stand(P)
		return P

	out.append({"name": "Attack", "T": 0.7, "loop": False, "fn": attack, "hit": 0.38})

	def hit_fn(t):
		P = c.pose()
		e = keys(t, [(0, 0), (0.07, 1), (0.35, 0)])
		c.body(P, pitch_up=0.12 * e, dy=-0.01 * e)
		c.neck(P, pitch_up=0.25 * e)
		c.neck_bob(P, -0.03 * e)
		c.head(P, pitch_up=0.1 * e)
		c.wings(P, lift=0.4 * e, spread=0.15 * e)
		tail_guard(P, extra=0.15 * e)
		c.stand(P)
		return P

	out.append({"name": "Hit", "T": 0.35, "loop": False, "fn": hit_fn})

	Td = 1.1
	h0 = float(c.rig.gpos[c.root, 1])

	def death(t):
		P = c.pose()
		x = t / Td
		roll = keys(x, [(0, 0), (0.3, 0.15), (0.72, 1.42), (0.86, 1.3), (1.0, 1.35)])
		c.body(P, pitch_up=keys(x, [(0, 0), (0.3, 0.1), (0.72, -0.05)]), roll=roll,
			dy=keys(x, [(0, 0), (0.3, -0.03), (0.72, -0.6 * h0)]))
		c.neck(P, pitch_up=keys(x, [(0, 0), (0.3, 0.2), (0.75, -0.6)]), roll=keys(x, [(0, 0), (0.75, 0.4)]))
		c.head(P, pitch_up=keys(x, [(0, 0), (0.75, -0.2)]))
		flap = 0.6 * abs(math.sin(TAU * t / 0.3)) * env(x, 0.0, 0.05, 0.3, 0.45)
		c.wings(P, lift=flap + keys(x, [(0, 0), (0.4, 0), (0.8, 0.3)]), spread=keys(x, [(0, 0), (0.3, 0.3), (0.8, 0.4)]))
		tail_guard(P, extra=keys(x, [(0, 0), (0.3, 0.15), (0.8, 0.05)]))
		w = 1.0 - smooth((x - 0.25) / 0.3)
		c.stand(P, w=w)
		for key, leg in c.rig.legs.items():
			c.rot(P, leg.u, rx(0.5 * (1.0 - w)))
			c.rot(P, leg.l, rx(-0.6 * (1.0 - w)))
			P["ik"][key]["curl"] = 0.9 * (1.0 - w)
		return P

	out.append({"name": "Death", "T": Td, "loop": False, "fn": death, "fit_after": 0.72})

	def cast(t):
		# Взмахи крыльями на месте: тело выпрямлено, голова вверх
		P = c.pose()
		e = keys(t, [(0, 0), (0.15, 1), (0.62, 1), (0.8, 0)])
		c.body(P, pitch_up=0.12 * e)
		c.neck(P, pitch_up=0.15 * e)
		c.head(P, pitch_up=0.2 * e)
		beat = abs(math.sin(TAU * (t - 0.12) / 0.5))
		c.wings(P, lift=(0.25 + 0.65 * beat) * env(t, 0.06, 0.16, 0.62, 0.78), spread=0.35 * env(t, 0.06, 0.16, 0.62, 0.78))
		tail_guard(P, extra=0.1 * e)
		c.stand(P)
		return P

	out.append({"name": "Cast", "T": 0.8, "loop": False, "fn": cast, "cast": 0.42})
	return out


# ---------- Сборка зверя ----------

FPS = 30.0


def band(v: np.ndarray, e) -> np.ndarray:
	"""Плавная «полоса»: 0 до e[0], 1 между e[1] и e[2], 0 после e[3]."""
	a = np.clip((v - e[0]) / max(e[1] - e[0], 1e-6), 0.0, 1.0)
	b = np.clip((v - e[2]) / max(e[3] - e[2], 1e-6), 0.0, 1.0)
	return a * a * (3 - 2 * a) * (1.0 - b * b * (3 - 2 * b))


def add_wings(rig: Rig, roles: dict, mesh: dict, wc: dict) -> None:
	"""Кости крыльев, которых нет в скелете Meshy: WingL/WingR от плеча, веса — у сложенного крыла на боку
	(область задана в конфиге, плавные края), прежние веса этих вершин ослабляются."""
	pos = mesh["pos"]
	jn = mesh["joints"].copy()
	wt = mesh["weights"].copy()
	roles["wings"] = {}
	for side, s in (("L", 1.0), ("R", -1.0)):
		b = rig.add_bone("Wing" + side, roles["hips"], np.array(wc["shoulder"]) * np.array([s, 1.0, 1.0]))
		roles["wings"][side] = b
		lat = pos[:, 0] * s
		lo, hi = wc["lat"]
		a = np.clip((lat - lo) / (hi - lo), 0.0, 1.0)
		w = a * a * (3 - 2 * a) * band(pos[:, 1], wc["y"]) * band(pos[:, 2], wc["z"])
		sel = np.nonzero(w > 1e-3)[0]
		for v in sel:
			old = wt[v] * (1.0 - w[v])
			k = int(np.argmin(old))
			old[k] = 0.0
			sm = old.sum()
			if sm > 1e-9:
				old *= (1.0 - w[v]) / sm
			old[k] = w[v]
			jn[v, k] = b
			wt[v] = old
	mesh["joints"], mesh["weights"] = jn, wt


def rigid_feet(rig: Rig, mesh: dict) -> None:
	"""foot_rigid: подошва целиком на стопе. У Meshy низ толстой лапы (черепаха) бывает привязан к голени — при шаге
	голень поворачивается и подошва уходит в землю. Вершины ниже лодыжки: доля костей ноги выше стопы → кость стопы."""
	jn = mesh["joints"].copy()
	wt = mesh["weights"].copy()
	pos = mesh["pos"]
	moved = 0
	for leg in rig.legs.values():
		upper = [b for b in leg.chain if b not in leg.distal]
		low = pos[:, 1] < rig.gpos[leg.a, 1]
		hit = np.zeros(len(pos), dtype=bool)
		for k in range(jn.shape[1]):
			m = low & np.isin(jn[:, k], upper) & (wt[:, k] > 0.0)
			jn[m, k] = leg.a
			hit |= m
		moved += int(hit.sum())
	for a in range(jn.shape[1]):
		for b in range(a + 1, jn.shape[1]):
			same = (jn[:, a] == jn[:, b]) & (wt[:, b] > 0.0)
			wt[same, a] += wt[same, b]
			wt[same, b] = 0.0
	mesh["joints"], mesh["weights"] = jn, wt
	print("   подошвы на стопах: %d вершин" % moved)


def add_toe_tips(rig: Rig, roles: dict, mesh: dict) -> None:
	"""toe_tip: у лапы без костей пальцев (фазан 3-й стадии) пальцы торчат вперёд за последней костью — при подъёме
	пятки они уходили бы в землю. Добавляется кость без весов на кончике пальцев (ToeTip<нога>): она самая передняя
	у земли и становится точкой опоры ноги."""
	dom = mesh["joints"][np.arange(len(mesh["pos"])), np.argmax(mesh["weights"], 1)]
	for key, lg in sorted(roles["legs"].items()):
		if lg["toes"]:
			continue
		end = lg["chain"][-1]
		sel = mesh["pos"][np.isin(dom, lg["chain"][-2:])]
		low = sel[sel[:, 1] < sel[:, 1].min() + 0.012]
		tip = low[np.argmax(low[:, 2])]
		rig.add_bone("ToeTip" + key, end, np.array([tip[0], max(float(rig.gpos[end, 1]) - 0.004, 0.0), tip[2]]))


def bake(c: Ctx, clip: dict) -> dict:
	"""Клип по кадрам 30 к/с: локальные повороты (кватернионы) и сдвиги всех костей."""
	rig = c.rig
	T = clip["T"]
	n = max(2, int(round(T * FPS)))
	times = np.linspace(0.0, T, n + 1)
	Q = np.zeros((len(times), rig.B, 4))
	TR = np.zeros((len(times), rig.B, 3))
	short = 0.0
	m = c.mesh
	for f, t in enumerate(times):
		P = clip["fn"](float(t))
		L, Tr, Gr, Gp, info = evaluate(rig, P)
		if "fit_after" in clip:
			# Падение: тело ложится на землю — корень опускается/поднимается так, чтобы низ меша был на y = 0
			v = skin_points(rig, m["pos"], m["joints"], m["weights"], Gr, Gp)
			miny = float(v[:, 1].min())
			dy = -miny if t >= clip["fit_after"] * T - 1e-6 else max(0.0, -miny)
			Tr[c.root, 1] += dy
		elif c.cfg.get("ground_fit"):
			# Кончики лап или низ панциря чуть ушли в землю (сгиб кисти, присед) — тело приподнимается на недостачу
			v = skin_points(rig, m["pos"], m["joints"], m["weights"], Gr, Gp)
			Tr[c.root, 1] += max(0.0, -float(v[:, 1].min()))
		short = max([short] + [i["short"] for i in info.values()])
		for b in range(rig.B):
			Q[f, b] = m_to_q(L[b])
		TR[f] = Tr
	for f in range(1, len(times)):
		flip = np.sum(Q[f] * Q[f - 1], axis=1) < 0.0
		Q[f][flip] *= -1.0
	out = {k: v for k, v in clip.items() if k != "fn"}
	out.update({"times": times, "rot": Q, "trans": TR, "short": short})
	return out


def write_glb(path: str, cid: str, rig: Rig, mesh: dict, clips: list) -> None:
	binb = bytearray()
	views, accs = [], []

	def add(arr, ctype, typ, target=None, minmax=False):
		arr = np.ascontiguousarray(arr)
		while len(binb) % 4:
			binb.append(0)
		off = len(binb)
		data = arr.tobytes()
		binb.extend(data)
		v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
		if target:
			v["target"] = target
		views.append(v)
		a = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
		if minmax:
			r = arr.reshape(arr.shape[0], -1)
			a["min"] = [float(x) for x in r.min(0)]
			a["max"] = [float(x) for x in r.max(0)]
		accs.append(a)
		return len(accs) - 1

	B = rig.B
	w = mesh["weights"].astype(np.float64)
	w = w / w.sum(1, keepdims=True)
	attrs = {
		"POSITION": add(mesh["pos"].astype(np.float32), 5126, "VEC3", 34962, True),
		"NORMAL": add(mesh["nrm"].astype(np.float32), 5126, "VEC3", 34962),
		"TEXCOORD_0": add(mesh["uv"].astype(np.float32), 5126, "VEC2", 34962),
		"JOINTS_0": add(mesh["joints"].astype(np.uint8 if B < 256 else np.uint16), 5121 if B < 256 else 5123, "VEC4", 34962),
		"WEIGHTS_0": add(w.astype(np.float32), 5126, "VEC4", 34962),
	}
	big = len(mesh["pos"]) > 65535
	ind = add(mesh["tris"].ravel().astype(np.uint32 if big else np.uint16), 5125 if big else 5123, "SCALAR", 34963)
	ibm = np.zeros((B, 4, 4))
	for b in range(B):
		M = np.eye(4)
		M[:3, :3] = rig.grot[b]
		M[:3, 3] = rig.gpos[b]
		ibm[b] = np.linalg.inv(M).T  # по столбцам
	ibm_acc = add(ibm.astype(np.float32).reshape(B, 16), 5126, "MAT4")

	nodes = [{"name": "Armature", "children": [1, 2]}, {"name": cid, "mesh": 0, "skin": 0}]
	for b in range(B):
		n = {"name": rig.names[b], "translation": [float(x) for x in rig.lpos[b]],
			"rotation": [float(x) for x in m_to_q(rig.lrot[b])]}
		if rig.ch[b]:
			n["children"] = [2 + c for c in rig.ch[b]]
		nodes.append(n)

	anims = []
	for cl in clips:
		times = cl["times"].astype(np.float32)
		tin = add(times, 5126, "SCALAR", None, True)
		tin2 = add(np.array([times[0], times[-1]], dtype=np.float32), 5126, "SCALAR", None, True)
		samplers, channels = [], []

		def chan(node, pathname, vals, typ):
			const = np.allclose(vals, vals[0:1], atol=1e-6)
			data = np.stack([vals[0], vals[0]]) if const else vals
			samplers.append({"input": tin2 if const else tin, "output": add(data.astype(np.float32), 5126, typ),
				"interpolation": "LINEAR"})
			channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": pathname}})

		for b in range(B):
			chan(2 + b, "rotation", cl["rot"][:, b], "VEC4")
			tr = cl["trans"][:, b]
			if b == 0 or not np.allclose(tr, rig.lpos[b][None], atol=1e-6):
				chan(2 + b, "translation", tr, "VEC3")
		anims.append({"name": cl["name"], "samplers": samplers, "channels": channels})

	gltf = {
		"asset": {"version": "2.0", "generator": "MyRappelz tools/prepare_creatures.py"},
		"scene": 0,
		"scenes": [{"name": "Scene", "nodes": [0]}],
		"nodes": nodes,
		"meshes": [{"name": cid, "primitives": [{"attributes": attrs, "indices": ind, "material": 0, "mode": 4}]}],
		"materials": [{"name": cid, "doubleSided": True,
			"pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
		"skins": [{"name": "Armature", "joints": [2 + b for b in range(B)], "inverseBindMatrices": ibm_acc, "skeleton": 2}],
		"animations": anims,
		"accessors": accs,
		"bufferViews": views,
		"buffers": [{"byteLength": len(binb)}],
	}
	js = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
	js += b" " * ((4 - len(js) % 4) % 4)
	while len(binb) % 4:
		binb.append(0)
	total = 12 + 8 + len(js) + 8 + len(binb)
	with open(path, "wb") as f:
		f.write(struct.pack("<III", 0x46546C67, 2, total))
		f.write(struct.pack("<II", len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack("<II", len(binb), 0x004E4942))
		f.write(bytes(binb))


PNG_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/creatures/{name}.png"

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

source_file="res://assets/creatures/{name}.glb"

[params]

gltf/embedded_image_handling=0
meshes/generate_lods=true
"""


def build(cid: str, src_path: str, cfg: dict, out_dir: str) -> dict:
	from PIL import Image
	print("== %s: %s" % (cid, src_path))
	src = load_source(src_path)
	g = to_game_space(src, cfg["height"])
	g = reorder(g, topo_order(g["parent"]))
	g = merge_twin_legs(g, cfg["height"])
	roles = detect_roles(g["names"], g["parent"], g["gpos"], cfg["height"], cfg)
	if cfg.get("ground") == "feet":
		lift_tail_to_feet(g, roles, cfg["height"])
	print("   поворот %d°, масштаб %.4f, исходный меш %d треуг." % (g["yaw_deg"], g["scale"], len(g["tris"])))
	mesh = simplify_mesh(g, cfg["tris"])
	st = mesh_stats(mesh["pos"], mesh["tris"])
	print("   упрощено: %d треуг., %d вершин, открытых рёбер %d (было %d), ошибка %.4f" % (
		st["tris"], st["verts"], st["open_edges"], mesh_stats(g["pos"], g["tris"])["open_edges"], mesh["simplify_error"]))
	# После упрощения могли пропасть самые верхние/нижние вершины: подгоняем высоту и землю ещё раз
	k = cfg["height"] / float(mesh["pos"][:, 1].max() - mesh["pos"][:, 1].min())
	shift = np.array([0.0, -float(mesh["pos"][:, 1].min()) * k, 0.0])
	mesh["pos"] = mesh["pos"] * k + shift
	g["gpos"] = g["gpos"] * k + shift
	rig = Rig(roles["names"], g["parent"], g["grot"], g["gpos"])
	if cfg.get("wings"):
		add_wings(rig, roles, mesh, cfg["wings"])
	if cfg.get("toe_tip"):
		add_toe_tips(rig, roles, mesh)
	for key, lg in sorted(roles["legs"].items()):
		up = cfg.get("ik_upper", {}).get(key, pick_upper(rig, lg["chain"]))
		leg = Leg(rig, key, lg["chain"], lg["toes"], up, cfg.get("prox_swing", 0.0))
		rig.legs[key] = leg
		rig.ik_upper[leg.u] = key
		print("   нога %s: %s; IK %s+%s, опора %s, длины %.3f+%.3f, вытянута в покое на %d%%" % (
			key, " ".join(rig.names[b] for b in lg["chain"]), rig.names[leg.u], rig.names[leg.l], rig.names[leg.c],
			leg.l1, leg.l2, round(leg.reach * 100)))
	if cfg.get("foot_rigid"):
		rigid_feet(rig, mesh)
	c = Ctx(rig, roles, cfg)
	c.mesh = mesh
	clips = [bake(c, cl) for cl in (bird_clips(c) if cfg["style"] == "bird" else quad_clips(c))]
	for cl in clips:
		if cl["short"] > 0.005:
			print("   %s: нога не достаёт до цели на %.3f м (опора приподнимается)" % (cl["name"], cl["short"]))
	os.makedirs(out_dir, exist_ok=True)
	glb = os.path.join(out_dir, cid + ".glb")
	write_glb(glb, cid, rig, mesh, clips)
	if src["image"] is not None:
		im = Image.open(io.BytesIO(src["image"])).convert("RGB")
		if im.size != (1024, 1024):
			im = im.resize((1024, 1024), Image.LANCZOS)
		im.save(os.path.join(out_dir, cid + ".png"), optimize=True)
	for ext, tpl in ((".png.import", PNG_IMPORT), (".glb.import", GLB_IMPORT)):
		p = os.path.join(out_dir, cid + ext)
		if not os.path.exists(p):
			with open(p, "w") as f:
				f.write(tpl.format(name=cid))
	nm = rig.names
	lo, hi = mesh["pos"].min(0), mesh["pos"].max(0)
	meta = {
		"height": round(float(hi[1] - lo[1]), 3),
		"length": round(float(hi[2] - lo[2]), 3),
		"width": round(float(hi[0] - lo[0]), 3),
		"bounds": [[round(float(x), 3) for x in lo], [round(float(x), 3) for x in hi]],
		"walk_speed": round(next(cl["speed"] for cl in clips if cl["name"] == "Walk"), 3),
		"run_speed": round(next(cl["speed"] for cl in clips if cl["name"] == "Run"), 3),
		"attack_hit_time": next(cl["hit"] for cl in clips if cl["name"] == "Attack"),
		"cast_time": next(cl["cast"] for cl in clips if cl["name"] == "Cast"),
		"clips": {cl["name"]: {"length": round(float(cl["T"]), 3), "loop": cl["loop"]} for cl in clips},
		"head_rest": [round(float(x), 3) for x in rig.gpos[roles["head"]]],
		"tris": int(len(mesh["tris"])),
		"verts": int(len(mesh["pos"])),
		"bones": {
			"root": nm[roles["root"]], "hips": nm[roles["hips"]], "chest": nm[roles["chest"]], "head": nm[roles["head"]],
			"spine": [nm[b] for b in roles["spine"]], "back": [nm[b] for b in roles["back"]],
			"neck": [nm[b] for b in roles["neck"]], "tail": [nm[b] for b in roles["tail"]],
			"legs": {k: [nm[b] for b in lg.chain] for k, lg in sorted(rig.legs.items())},
			"feet": {k: nm[lg.c] for k, lg in sorted(rig.legs.items())},
			"toes": {k: [[nm[b] for b in t] for t in lg.toes] for k, lg in sorted(rig.legs.items()) if lg.toes},
			"ears": {s: [nm[b] for b in v] for s, v in roles["ears"].items() if v},
			"wings": {s: nm[b] for s, b in roles.get("wings", {}).items()},
			"other": [nm[b] for b in roles["head_extra"] + roles["extra"]],
		},
		"source": os.path.basename(src_path),
	}
	for cl in clips:
		if cl["name"] in ("Walk", "Run"):
			g2 = cl["gait"]
			meta["clips"][cl["name"]].update({"speed": round(cl["speed"], 3), "stride": g2["stride"], "duty": g2["duty"]})
	return meta


# ---------- Проверка готового GLB (независимое чтение файла, прямая кинематика, скиннинг) ----------

def load_built(path: str) -> dict:
	gltf, binc = read_glb(path)
	nodes = gltf["nodes"]
	parent = {}
	for i, n in enumerate(nodes):
		for c in n.get("children", []):
			parent[c] = i
	skin = gltf["skins"][0]
	pr = gltf["meshes"][0]["primitives"][0]
	at = pr["attributes"]
	anims = {}
	for a in gltf.get("animations", []):
		chs = []
		for ch in a["channels"]:
			s = a["samplers"][ch["sampler"]]
			chs.append((ch["target"]["node"], ch["target"]["path"], accessor(gltf, binc, s["input"]).astype(np.float64),
				accessor(gltf, binc, s["output"]).astype(np.float64)))
		anims[a["name"]] = chs
	return {
		"nodes": nodes, "parent": parent, "joints": skin["joints"],
		"ibm": accessor(gltf, binc, skin["inverseBindMatrices"]).astype(np.float64).reshape(-1, 4, 4).transpose(0, 2, 1),
		"pos": accessor(gltf, binc, at["POSITION"]).astype(np.float64),
		"jn": accessor(gltf, binc, at["JOINTS_0"]).astype(np.int64),
		"wt": accessor(gltf, binc, at["WEIGHTS_0"]).astype(np.float64),
		"uv": accessor(gltf, binc, at["TEXCOORD_0"]).astype(np.float64),
		"tris": accessor(gltf, binc, pr["indices"]).astype(np.int64).reshape(-1, 3),
		"anims": anims, "idx": {n.get("name", ""): i for i, n in enumerate(nodes)},
		"images": len(gltf.get("images", [])), "materials": len(gltf.get("materials", [])),
	}


def sample_channel(ti: np.ndarray, vo: np.ndarray, t: float, path: str) -> np.ndarray:
	if len(ti) == 1 or t <= ti[0]:
		return vo[0]
	if t >= ti[-1]:
		return vo[-1]
	k = int(np.searchsorted(ti, t, side="right") - 1)
	f = (t - ti[k]) / (ti[k + 1] - ti[k])
	a, b = vo[k], vo[k + 1]
	if path == "rotation":
		if np.dot(a, b) < 0:
			b = -b
		q = a + (b - a) * f
		return q / np.linalg.norm(q)
	return a + (b - a) * f


def built_pose(m: dict, clip, t: float) -> dict:
	"""Мировые матрицы узлов в момент t клипа (None — поза покоя)."""
	over = {}
	if clip is not None:
		for node, path, ti, vo in m["anims"][clip]:
			over[(node, path)] = sample_channel(ti, vo, t, path)
	G = {}

	def g(i):
		if i in G:
			return G[i]
		n = m["nodes"][i]
		M = np.eye(4)
		M[:3, :3] = q_to_m(over.get((i, "rotation"), n.get("rotation", [0, 0, 0, 1]))) * np.array(n.get("scale", [1, 1, 1]))
		M[:3, 3] = over.get((i, "translation"), n.get("translation", [0, 0, 0]))
		G[i] = (g(m["parent"][i]) if i in m["parent"] else np.eye(4)) @ M
		return G[i]

	for j in m["joints"]:
		g(j)
	return G


def built_skin(m: dict, G: dict) -> np.ndarray:
	S = np.stack([G[j] @ m["ibm"][k] for k, j in enumerate(m["joints"])])
	out = np.zeros_like(m["pos"])
	for k in range(4):
		j = m["jn"][:, k]
		out += m["wt"][:, k:k + 1] * (np.einsum("vij,vj->vi", S[j][:, :3, :3], m["pos"]) + S[j][:, :3, 3])
	return out


def check(out_dir: str, ids: list, meta_all: dict, preview: str = "") -> bool:
	ok = True
	for cid in ids:
		meta = meta_all[cid]
		path = os.path.join(out_dir, cid + ".glb")
		m = load_built(path)
		png = os.path.join(out_dir, cid + ".png")
		if preview and os.path.exists(png):
			from PIL import Image
			m["tex"] = np.array(Image.open(png).convert("RGB").resize((512, 512)))
		bn = meta["bones"]
		idx = m["idx"]
		head = idx[bn["head"]]
		feet = {k: idx[v] for k, v in bn["feet"].items()}
		G0 = built_pose(m, None, 0.0)
		rest_v = built_skin(m, G0)
		lo, hi = rest_v.min(0), rest_v.max(0)
		hz = G0[head][2, 3]
		print("== %s: %d костей, %d треуг., %d вершин, картинок в GLB %d; высота %.3f (y %.3f…%.3f), длина %.3f, ширина %.3f" % (
			cid, len(m["joints"]), len(m["tris"]), len(m["pos"]), m["images"], hi[1] - lo[1], lo[1], hi[1],
			hi[2] - lo[2], hi[0] - lo[0]))
		face_ok = hz > 0.0 and G0[head][1, 3] > 0.3 * (hi[1] - lo[1])
		print("   голова в покое: %s → морда в %s" % (np.round(G0[head][:3, 3], 3), "+Z" if face_ok else "НЕ +Z (!)"))
		ok &= bool(face_ok) and abs(lo[1]) < 0.003 and abs((hi[1] - lo[1]) - meta["height"]) < 0.01
		rest_foot = {k: G0[b][:3, 3].copy() for k, b in feet.items()}
		for name, info in meta["clips"].items():
			L = info["length"]
			times = np.arange(0.0, L + 1e-6, 1.0 / FPS)
			miny, miny_t = 1e9, 0.0
			foot_min = 1e9
			fp = {k: [] for k in feet}
			hp = []
			sticks = []
			verts_at = {}
			pick = set(np.linspace(0, len(times) - 1, 5).round().astype(int).tolist())
			for fi, t in enumerate(times):
				G = built_pose(m, name, float(t))
				v = built_skin(m, G)
				if v[:, 1].min() < miny:
					miny, miny_t = float(v[:, 1].min()), float(t)
				for k, b in feet.items():
					p = G[b][:3, 3].copy()
					fp[k].append(p)
					foot_min = min(foot_min, p[1] - rest_foot[k][1])
				hp.append(G[head][:3, 3].copy())
				if preview:
					sticks.append(np.stack([G[j][:3, 3] for j in m["joints"]]))
					if fi in pick:
						verts_at[fi] = v
			hp = np.array(hp)
			line = "   %-6s %.2f с: низ меша %+.3f (t=%.2f), опоры ниже покоя на %.3f, голова y %.2f…%.2f z %.2f…%.2f" % (
				name, L, miny, miny_t, max(0.0, -foot_min), hp[:, 1].min(), hp[:, 1].max(), hp[:, 2].min(), hp[:, 2].max())
			bad = miny < -0.01
			if name in ("Walk", "Run"):
				v = info["speed"]
				slide = 0.0
				n = len(times) - 1  # последний кадр = первый
				for k in feet:
					P_ = np.array(fp[k][:n])
					st = P_[:, 1] <= rest_foot[k][1] + 0.004
					if st.all() or not st.any():
						continue
					s0 = int(np.argmin(st))  # начинаем с кадра переноса
					run_pts = []
					for i in range(n + 1):
						f = (s0 + i) % n
						tt = times[f] + (L if s0 + i >= n else 0.0)
						if i < n and st[f]:
							run_pts.append(P_[f] + np.array([0.0, 0.0, v * tt]))
						elif run_pts:
							r = np.array(run_pts)
							slide = max(slide, float(np.linalg.norm((r.max(0) - r.min(0))[[0, 2]])))
							run_pts = []
				line += ", проскальзывание опоры %.3f м при %.2f м/с" % (slide, v)
				bad |= slide > 0.02
			if name == "Death":
				line += ", в конце голова y %.2f, верх тела %.2f" % (hp[-1, 1], float(built_skin(m, built_pose(m, name, L))[:, 1].max()))
			print(line + ("  ← ПЛОХО" if bad else ""))
			ok &= not bad
			if preview:
				write_preview(preview, cid, name, m, sticks, verts_at, meta)
	return ok


def write_preview(out: str, cid: str, clip: str, m: dict, sticks: list, verts_at: dict, meta: dict) -> None:
	"""Картинка для глаз: «палочки» по кадрам (левые ноги синие, правые красные) и меш в нескольких кадрах."""
	from PIL import Image
	os.makedirs(out, exist_ok=True)
	joints = m["joints"]
	parent = np.array([joints.index(m["parent"][j]) if m["parent"].get(j) in joints else -1 for j in joints])
	names = [m["nodes"][j].get("name", "") for j in joints]
	marks = {}
	for k, n in enumerate(names):
		if n.startswith(("LegFL", "LegBL", "LegL", "ToeL", "WingL")):
			marks[k] = (40, 90, 220)
		elif n.startswith(("LegFR", "LegBR", "LegR", "ToeR", "WingR")):
			marks[k] = (220, 50, 40)
	H = meta["height"]
	span = max(meta["length"], H) * 1.2
	sel = np.linspace(0, len(sticks) - 1, min(8, len(sticks))).round().astype(int)
	ctr = (0.0, span * 0.42, 0.0)
	second = "front" if clip == "Death" else "top"
	rows = [draw_sticks([sticks[i] for i in sel], parent, "side", 240, span, ctr, marks, clip + " side"),
		draw_sticks([sticks[i] for i in sel], parent, second, 240, span, (0.0, span * 0.42, 0.0), marks, clip + " " + second)]
	box = (np.array([-span / 2, 0.0, -span / 2]), np.array([span / 2, span * 0.84, span / 2]))
	views = ("side", "front") if clip == "Death" else ("side",)
	shots = [render_mesh(verts_at[fi], m["tris"], m["uv"], m.get("tex"), views=views, size=300, samples=150000, box=box)
		for fi in sorted(verts_at)]
	row = Image.new("RGB", (sum(r.size[0] for r in shots), 300), (255, 255, 255))
	x = 0
	for r in shots:
		row.paste(r, (x, 0))
		x += r.size[0]
	rows.append(row)
	w = max(r.size[0] for r in rows)
	img = Image.new("RGB", (w, sum(r.size[1] for r in rows)), (255, 255, 255))
	y = 0
	for r in rows:
		img.paste(r, (0, y))
		y += r.size[1]
	img.save(os.path.join(out, "%s_%s.png" % (cid, clip)))


# ---------- Запуск ----------

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> None:
	ap = argparse.ArgumentParser(description="Звери из Meshy: упрощение, масштаб, понятные кости, процедурные анимации.")
	ap.add_argument("sources", nargs="*", help="id=путь к GLB из Meshy (id: %s)" % ", ".join(CREATURES))
	ap.add_argument("--out", default=os.path.join(ROOT, "assets", "creatures"), help="куда писать (по умолчанию assets/creatures)")
	ap.add_argument("--check", action="store_true", help="только проверить готовые GLB из creatures.json, ничего не писать")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок (палочки и меш по кадрам)")
	args = ap.parse_args()
	meta_path = os.path.join(args.out, "creatures.json")
	meta_all = {}
	if os.path.exists(meta_path):
		with open(meta_path) as f:
			meta_all = json.load(f)
	built = []
	if not args.check:
		for s in args.sources:
			if "=" not in s:
				ap.error("ждём id=путь, получено %r" % s)
			cid, path = s.split("=", 1)
			if cid not in CREATURES:
				ap.error("неизвестный зверь %r (есть: %s)" % (cid, ", ".join(CREATURES)))
			meta_all[cid] = build(cid, path, CREATURES[cid], args.out)
			built.append(cid)
		if built:
			order = [k for k in CREATURES if k in meta_all] + [k for k in meta_all if k not in CREATURES]
			with open(meta_path, "w") as f:
				json.dump({k: meta_all[k] for k in order}, f, ensure_ascii=False, indent="\t")
				f.write("\n")
	ids = built or list(meta_all)
	if not ids:
		ap.error("нет ни исходников, ни готовых зверей в %s" % meta_path)
	ok = check(args.out, ids, meta_all, args.preview)
	print("ИТОГ: %s" % ("всё в порядке" if ok else "есть замечания (см. ПЛОХО выше)"))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
