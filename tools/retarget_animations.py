#!/usr/bin/env python3
"""Переносит анимации Quaternius «Universal Animation Library» на героя со скелетом Mixamo.

Берёт GLB библиотеки анимаций (скелет в стиле UE: pelvis, spine_01, upperarm_l, …) и GLB героя
(кости «mixamorig:Hips», «mixamorig:LeftArm», …), пересчитывает выбранные клипы на скелет героя
и дописывает их в GLB героя. Меш, кожа, материалы, картинки и прежние анимации остаются как были.

Как переносится поза (ретаргетинг через глобальные повороты):
  1. Опорная поза героя: поза покоя, у которой кости позвоночника, рук и ног довёрнуты так,
     чтобы смотреть туда же, куда та же кость в позе покоя библиотеки (T-pose против A-pose,
     разная постановка ног и кистей); бёдра, голова, стопы и носки сохраняют мировой поворот
     покоя («смотрит вперёд», «стоит на земле»). Кисть дополнительно доворачивается вокруг своей
     оси по направлению «мизинец → указательный» (HAND_ACROSS; у героя оно же — GRIP_DIR в
     character_model.gd, при новой модели поправить оба места).
  2. На каждом кадре: delta = Q_src_global(t) * inverse(Q_src_global_rest),
     Q_tgt_global(t) = delta * Q_tgt_global_ref, затем обратно в локальные повороты.
  3. Бёдра: смещение таза от позы покоя масштабируется по отношению длин ног (бедро → лодыжка)
     и прибавляется к позе покоя бёдер героя. Смещение по земле (X, Z) игра всё равно убирает
     (CharacterModel._pin_root), высота (присед, падение) остаётся.
  Остальные кости героя (концы пальцев, макушка, носки) — в позе покоя относительно родителя.
  У каждого клипа есть каналы rotation и translation по всем костям героя, поэтому клип полностью
  задаёт позу и не зависит от того, какой клип играл до него.

Повторный запуск безопасен: клипы, добавленные этим скриптом раньше (помечены extras.retarget),
сначала удаляются вместе с их данными, потом записываются заново. Поэтому, когда появится новая
модель героя на том же скелете Mixamo, достаточно положить её GLB вместо старого и запустить снова.

Запуск из корня репозитория (нужен numpy):
  python3 tools/retarget_animations.py --ual1 <UAL1_Standard.glb> --ual2 <UAL2_Standard.glb> \\
      assets/characters/dark_elf_wanderer.glb
  (по умолчанию результат пишется в тот же GLB героя; --out <файл> — в другой файл,
  --check — без записи, только печать проверочных высот головы, кистей и стоп по клипам.)
  Python запускать с -I, если библиотека лежит рядом со скриптами: python3 -I tools/…

Откуда брать библиотеку (лицензия CC0, Quaternius):
  https://quaternius.itch.io/universal-animation-library    → «Universal Animation Library[Standard].zip»
  https://quaternius.itch.io/universal-animation-library-2  → «Universal Animation Library 2[Standard].zip»
  Нужны файлы Unreal-Godot/UAL1_Standard.glb и Unreal-Godot/UAL2_Standard.glb
  (версии без корневого движения, не *_RM).
"""
import argparse
import json
import struct

import numpy as np

FPS = 30.0

## Кости героя (имя Mixamo без префикса) → кости библиотеки Quaternius.
BONE_MAP = {
	"Hips": "pelvis",
	"Spine": "spine_01",
	"Spine1": "spine_02",
	"Spine2": "spine_03",
	"Neck": "neck_01",
	"Head": "Head",
	"LeftShoulder": "clavicle_l",
	"LeftArm": "upperarm_l",
	"LeftForeArm": "lowerarm_l",
	"LeftHand": "hand_l",
	"RightShoulder": "clavicle_r",
	"RightArm": "upperarm_r",
	"RightForeArm": "lowerarm_r",
	"RightHand": "hand_r",
	"LeftUpLeg": "thigh_l",
	"LeftLeg": "calf_l",
	"LeftFoot": "foot_l",
	"LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r",
	"RightLeg": "calf_r",
	"RightFoot": "foot_r",
	"RightToeBase": "ball_r",
}

## Направление кости для выравнивания поз покоя: кость героя → ([дочерние кости героя по
## приоритету], дочерняя кость библиотеки). Кости не из списка (бёдра, голова, стопы, носки)
## в опорной позе сохраняют свой мировой поворот покоя: «смотрит вперёд», «стоит на земле».
## Ключицы (LeftShoulder/RightShoulder) — тоже свой поворот покоя: у UAL ключица идёт от передней стороны груди
## назад к плечу (≈ 38° назад), довёрнутая по ней ключица героя уводила плечевой сустав на 5–7 см назад (плечи
## «за головой»); поверх покоя — повороты ключицы библиотеки (как у prepare_hero.HeroRetarget).
ALIGN = {
	"Spine": (["Spine1"], "spine_02"),
	"Spine1": (["Spine2"], "spine_03"),
	"Spine2": (["Neck"], "neck_01"),
	"Neck": (["Head"], "Head"),
	"LeftArm": (["LeftForeArm"], "lowerarm_l"),
	"LeftForeArm": (["LeftHand"], "hand_l"),
	"LeftHand": (["LeftHandMiddle1", "LeftHandMiddle4"], "middle_01_l"),
	"RightArm": (["RightForeArm"], "lowerarm_r"),
	"RightForeArm": (["RightHand"], "hand_r"),
	"RightHand": (["RightHandMiddle1", "RightHandMiddle4"], "middle_01_r"),
	"LeftUpLeg": (["LeftLeg"], "calf_l"),
	"LeftLeg": (["LeftFoot"], "foot_l"),
	"RightUpLeg": (["RightLeg"], "calf_r"),
	"RightLeg": (["RightFoot"], "foot_r"),
}

## Поворот кисти вокруг своей оси: направление «мизинец → указательный» в пространстве кости
## героя (правая кисть, как GRIP_DIR в character_model.gd; левая — зеркально по X) и пара костей
## библиотеки, задающая то же направление.
HAND_ACROSS = {
	"RightHand": ((0.76, 0.12, 0.64), "pinky_01_r", "index_01_r"),
	"LeftHand": ((-0.76, 0.12, 0.64), "pinky_01_l", "index_01_l"),
}

## Клипы: новое имя → (библиотека, [клипы библиотеки подряд], (с какой секунды, до какой) или None).
## Своих клипов героя с такими именами быть не должно (скрипт откажется их перезаписывать).
CLIPS = {
	"Idle": ("ual1", ["Idle_Loop"], None),  # покой, цикл
	"Sword_Idle": ("ual1", ["Sword_Idle"], None),  # боевая стойка с мечом, цикл
	"Sword_Slash": ("ual2", ["Sword_Regular_A", "Sword_Regular_A_Rec"], None),  # удар и возврат в покой
	"Sword_Attack": ("ual1", ["Sword_Attack"], None),  # удар с выпадом из боевой стойки
	"Sword_Combo": ("ual2", ["Sword_Regular_Combo"], None),  # три удара подряд
	"Sword_Heavy_Combo": ("ual2", ["Sword_Heavy_Combo"], None),  # тяжёлое комбо с прыжком-вращением
	"Sword_Dash": ("ual2", ["Sword_Dash"], None),  # рывок с ударом
	"Sword_Block": ("ual2", ["Sword_Block"], None),  # защитная стойка
	"Dodge": ("ual1", ["Roll"], None),  # кувырок-уклонение
	"Hit": ("ual1", ["Hit_Chest"], None),  # реакция на удар
	"Death": ("ual1", ["Death01"], None),  # смерть (падает на спину)
	"Cast": ("ual1", ["Spell_Simple_Enter", "Spell_Simple_Shoot", "Spell_Simple_Exit"], None),  # заклинание левой рукой
	"Pickup": ("ual2", ["Farm_Harvest"], None),  # присесть и поднять с земли
	# Парные клинки: удары справа и слева чередуются (Sword_Slash, Sword_Slash_B, Sword_Slash_C)
	"Sword_Slash_B": ("ual2", ["Sword_Regular_B", "Sword_Regular_B_Rec"], None),  # обратный удар и возврат
	"Sword_Slash_C": ("ual2", ["Sword_Regular_C"], None),  # колющий выпад
	# Арбалет (двуручный хват пистолета из UAL): стойка с оружием на изготовку у лица и выстрел с отдачей
	"Crossbow_Idle": ("ual1", ["Pistol_Idle_Loop"], None),  # стойка с арбалетом, цикл
	"Crossbow_Shoot": ("ual1", ["Pistol_Shoot"], None),  # выстрел
}


# ---------- Кватернионы (x, y, z, w), numpy, по последней оси ----------

def qmul(a: np.ndarray, b: np.ndarray) -> np.ndarray:
	ax, ay, az, aw = np.moveaxis(a, -1, 0)
	bx, by, bz, bw = np.moveaxis(b, -1, 0)
	return np.stack([
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	], axis=-1)


def qconj(q: np.ndarray) -> np.ndarray:
	return q * np.array([-1.0, -1.0, -1.0, 1.0])


def qrot(q: np.ndarray, v: np.ndarray) -> np.ndarray:
	u = q[..., :3]
	w = q[..., 3:4]
	t = 2.0 * np.cross(u, v)
	return v + w * t + np.cross(u, t)


def qnorm(q: np.ndarray) -> np.ndarray:
	return q / np.linalg.norm(q, axis=-1, keepdims=True)


def q_between(u: np.ndarray, v: np.ndarray) -> np.ndarray:
	"""Кратчайший поворот от направления u к направлению v."""
	u = u / np.linalg.norm(u)
	v = v / np.linalg.norm(v)
	d = float(np.dot(u, v))
	if d < -0.999999:
		axis = np.cross(u, [1.0, 0.0, 0.0])
		if np.linalg.norm(axis) < 1e-6:
			axis = np.cross(u, [0.0, 1.0, 0.0])
		axis /= np.linalg.norm(axis)
		return np.array([axis[0], axis[1], axis[2], 0.0])
	c = np.cross(u, v)
	return qnorm(np.array([c[0], c[1], c[2], 1.0 + d]))


def q_axis_angle(axis: np.ndarray, angle: float) -> np.ndarray:
	axis = axis / np.linalg.norm(axis)
	s = np.sin(angle * 0.5)
	return np.array([axis[0] * s, axis[1] * s, axis[2] * s, np.cos(angle * 0.5)])


def slerp(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
	d = np.sum(a * b, axis=-1, keepdims=True)
	b = np.where(d < 0.0, -b, b)
	d = np.abs(d)
	t = t[..., None] if t.ndim == a.ndim - 1 else t
	lin = d > 0.9995
	th = np.arccos(np.clip(d, -1.0, 1.0))
	sn = np.where(lin, 1.0, np.sin(th))
	wa = np.where(lin, 1.0 - t, np.sin((1.0 - t) * th) / sn)
	wb = np.where(lin, t, np.sin(t * th) / sn)
	return qnorm(wa * a + wb * b)


def continuous(q: np.ndarray) -> np.ndarray:
	"""Кватернионы по кадрам (ось 0) в одной полусфере — без скачков знака при интерполяции."""
	q = q.copy()
	for f in range(1, q.shape[0]):
		flip = np.sum(q[f] * q[f - 1], axis=-1) < 0.0
		q[f][flip] *= -1.0
	return q


# ---------- GLB ----------

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


class Glb:
	def __init__(self, path: str) -> None:
		d = open(path, "rb").read()
		magic, ver, _total = struct.unpack_from("<III", d, 0)
		if magic != 0x46546C67 or ver != 2:
			raise SystemExit("%s: не GLB 2.0" % path)
		self.path = path
		self.json: dict = {}
		self.bin = b""
		off = 12
		while off < len(d):
			ln, kind = struct.unpack_from("<II", d, off)
			chunk = d[off + 8: off + 8 + ln]
			if kind == 0x4E4F534A:
				self.json = json.loads(chunk.decode("utf-8"))
			elif kind == 0x004E4942:
				self.bin = chunk
			off += 8 + ln
		for ext in self.json.get("extensionsUsed", []):
			if ext in ("KHR_draco_mesh_compression", "EXT_meshopt_compression", "EXT_mesh_gpu_instancing"):
				raise SystemExit("%s: расширение %s не поддерживается" % (path, ext))
		self.nodes: list = self.json["nodes"]

	def acc(self, i: int) -> np.ndarray:
		a = self.json["accessors"][i]
		n = NCOMP[a["type"]]
		dt = np.dtype(COMP[a["componentType"]])
		out = np.zeros((a["count"], n), dtype=np.float64)
		if "bufferView" in a:
			bv = self.json["bufferViews"][a["bufferView"]]
			off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
			stride = bv.get("byteStride", dt.itemsize * n)
			raw = np.frombuffer(self.bin, dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=off)
			for k in range(n):
				out[:, k] = np.ndarray((a["count"],), dtype=dt, buffer=raw.tobytes(), offset=k * dt.itemsize, strides=(stride,))
		if "sparse" in a:
			raise SystemExit("разреженные accessor не поддерживаются")
		if a.get("normalized"):
			out /= float(np.iinfo(dt).max)
		return out

	def add_float_accessor(self, data: np.ndarray, kind: str, minmax: bool = False) -> int:
		"""Новый accessor из float-массива; данные лягут в буфер при save()."""
		data = np.ascontiguousarray(data, dtype=np.float32).reshape(len(data), -1)
		a = {"componentType": 5126, "count": int(data.shape[0]), "type": kind, "_data": data}
		if minmax:
			a["min"] = [float(x) for x in data.min(axis=0)]
			a["max"] = [float(x) for x in data.max(axis=0)]
		self.json["accessors"].append(a)
		return len(self.json["accessors"]) - 1

	def save(self, path: str) -> None:
		"""Пересобрать буфер: только используемые accessor/bufferView, новые данные в конце."""
		j = self.json
		used: list[int] = []
		seen: set[int] = set()

		def use(i) -> None:
			if i is not None and i not in seen:
				seen.add(i)
				used.append(i)

		for m in j.get("meshes", []):
			for p in m["primitives"]:
				for v in p["attributes"].values():
					use(v)
				use(p.get("indices"))
				for tg in p.get("targets", []):
					for v in tg.values():
						use(v)
		for s in j.get("skins", []):
			use(s.get("inverseBindMatrices"))
		for an in j.get("animations", []):
			for s in an["samplers"]:
				use(s["input"])
				use(s["output"])
		acc_map = {old: new for new, old in enumerate(used)}
		new_bvs: list = []
		chunks: list = []
		size = 0
		bv_map: dict = {}

		def put(raw: bytes, bv: dict) -> int:
			nonlocal size
			pad = (-size) % 4
			if pad:
				chunks.append(b"\0" * pad)
				size += pad
			bv = dict(bv)
			bv["buffer"] = 0
			bv["byteOffset"] = size
			bv["byteLength"] = len(raw)
			chunks.append(raw)
			size += len(raw)
			new_bvs.append(bv)
			return len(new_bvs) - 1

		def old_bv(i: int) -> int:
			if i not in bv_map:
				bv = j["bufferViews"][i]
				o = bv.get("byteOffset", 0)
				keep = {k: v for k, v in bv.items() if k not in ("buffer", "byteOffset", "byteLength")}
				bv_map[i] = put(self.bin[o: o + bv["byteLength"]], keep)
			return bv_map[i]

		new_acc = []
		for i in used:
			a = dict(j["accessors"][i])
			if "_data" in a:
				data = a.pop("_data")
				a["bufferView"] = put(data.tobytes(), {})
				a.pop("byteOffset", None)
			elif "bufferView" in a:
				a["bufferView"] = old_bv(a["bufferView"])
			new_acc.append(a)
		for im in j.get("images", []):
			if "bufferView" in im:
				im["bufferView"] = old_bv(im["bufferView"])
		for m in j.get("meshes", []):
			for p in m["primitives"]:
				p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
				if "indices" in p:
					p["indices"] = acc_map[p["indices"]]
				if "targets" in p:
					p["targets"] = [{k: acc_map[v] for k, v in tg.items()} for tg in p["targets"]]
		for s in j.get("skins", []):
			if "inverseBindMatrices" in s:
				s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
		for an in j.get("animations", []):
			for s in an["samplers"]:
				s["input"] = acc_map[s["input"]]
				s["output"] = acc_map[s["output"]]
		j["accessors"] = new_acc
		j["bufferViews"] = new_bvs
		pad = (-size) % 4
		chunks.append(b"\0" * pad)
		size += pad
		j["buffers"] = [{"byteLength": size}]
		js = json.dumps(j, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
		js += b" " * ((-len(js)) % 4)
		binary = b"".join(chunks)
		total = 12 + 8 + len(js) + 8 + len(binary)
		with open(path, "wb") as f:
			f.write(struct.pack("<III", 0x46546C67, 2, total))
			f.write(struct.pack("<II", len(js), 0x4E4F534A))
			f.write(js)
			f.write(struct.pack("<II", len(binary), 0x004E4942))
			f.write(binary)


# ---------- Скелет и позы ----------

class Skeleton:
	"""Узлы glTF как иерархия: локальные позы покоя и прямая кинематика."""

	def __init__(self, glb: Glb) -> None:
		self.glb = glb
		nodes = glb.nodes
		n = len(nodes)
		self.n = n
		self.parent = [-1] * n
		for i, nd in enumerate(nodes):
			for c in nd.get("children", []):
				self.parent[c] = i
		self.names = [nd.get("name", "") for nd in nodes]
		self.rest_t = np.array([nd.get("translation", [0.0, 0.0, 0.0]) for nd in nodes], dtype=np.float64)
		self.rest_r = qnorm(np.array([nd.get("rotation", [0.0, 0.0, 0.0, 1.0]) for nd in nodes], dtype=np.float64))
		self.rest_s = np.array([nd.get("scale", [1.0, 1.0, 1.0]) for nd in nodes], dtype=np.float64)
		for nd in nodes:
			if "matrix" in nd:
				raise SystemExit("узлы с matrix не поддерживаются")
		# Порядок обхода: родитель раньше детей
		self.order: list[int] = []
		roots = [i for i in range(n) if self.parent[i] < 0]
		stack = list(reversed(roots))
		while stack:
			i = stack.pop()
			self.order.append(i)
			stack.extend(reversed(nodes[i].get("children", [])))

	def find(self, name: str) -> int:
		"""Индекс узла по имени; у Mixamo допускается префикс («mixamorig:Hips», «mixamorig_Hips»)."""
		for i, nm in enumerate(self.names):
			if nm == name:
				return i
		for i, nm in enumerate(self.names):
			if nm.endswith(":" + name) or nm.endswith("_" + name) and nm.startswith("mixamorig"):
				return i
		return -1

	def fk(self, loc_t: np.ndarray, loc_r: np.ndarray) -> tuple:
		"""Мировые позиции и повороты по локальным (кадры × узлы × …). Масштаб узлов — из покоя."""
		gp = np.zeros_like(loc_t)
		gr = np.zeros_like(loc_r)
		gs = np.ones(loc_t.shape)
		for i in self.order:
			p = self.parent[i]
			if p < 0:
				gp[:, i] = loc_t[:, i]
				gr[:, i] = loc_r[:, i]
				gs[:, i] = self.rest_s[i]
			else:
				gp[:, i] = gp[:, p] + qrot(gr[:, p], gs[:, p] * loc_t[:, i])
				gr[:, i] = qmul(gr[:, p], loc_r[:, i])
				gs[:, i] = gs[:, p] * self.rest_s[i]
		return gp, gr

	def rest_pose(self, frames: int = 1) -> tuple:
		return (np.repeat(self.rest_t[None], frames, axis=0), np.repeat(self.rest_r[None], frames, axis=0))

	def anim(self, name: str) -> dict:
		for a in self.glb.json.get("animations", []):
			if a.get("name") == name:
				return a
		raise SystemExit("%s: нет клипа %s" % (self.glb.path, name))

	def sample(self, name: str, times: np.ndarray) -> tuple:
		"""Локальные позы всех узлов клипа в моменты times (линейная интерполяция, slerp)."""
		a = self.anim(name)
		loc_t, loc_r = self.rest_pose(len(times))
		for ch in a["channels"]:
			path = ch["target"]["path"]
			node = ch["target"].get("node")
			if node is None or path not in ("translation", "rotation"):
				continue
			s = a["samplers"][ch["sampler"]]
			ti = self.glb.acc(s["input"])[:, 0]
			vo = self.glb.acc(s["output"])
			if s.get("interpolation") == "CUBICSPLINE":
				vo = vo[1::3]
			k = np.clip(np.searchsorted(ti, times, side="right") - 1, 0, len(ti) - 1)
			k1 = np.minimum(k + 1, len(ti) - 1)
			span = np.where(k1 > k, ti[k1] - ti[k], 1.0)
			f = np.clip((times - ti[k]) / span, 0.0, 1.0)
			if s.get("interpolation") == "STEP":
				f = np.zeros_like(f)
			if path == "rotation":
				loc_r[:, node] = slerp(qnorm(vo[k]), qnorm(vo[k1]), f)
			else:
				loc_t[:, node] = vo[k] + (vo[k1] - vo[k]) * f[:, None]
		return loc_t, loc_r

	def length(self, name: str) -> float:
		a = self.anim(name)
		return max(self.glb.json["accessors"][s["input"]]["max"][0] for s in a["samplers"])


# ---------- Перенос ----------

class Retargeter:
	def __init__(self, src: Skeleton, tgt: Skeleton) -> None:
		self.src = src
		self.tgt = tgt
		self.pairs: list = []  # (узел героя, узел библиотеки)
		for tb, sb in BONE_MAP.items():
			ti = tgt.find(tb)
			si = src.find(sb)
			if ti < 0:
				raise SystemExit("у героя нет кости %s" % tb)
			if si < 0:
				raise SystemExit("в библиотеке нет кости %s" % sb)
			self.pairs.append((ti, si))
		self.map = {ti: si for ti, si in self.pairs}
		sp, sr = src.fk(*src.rest_pose())
		self.src_rest_p = sp[0]
		self.src_rest_r = sr[0]
		self.tgt_hips = tgt.find("Hips")
		self.src_pelvis = src.find("pelvis")
		self._build_ref()
		tp, _ = tgt.fk(*tgt.rest_pose())
		tp = tp[0]
		# Масштаб смещения бёдер: отношение длин ног (бедро → лодыжка) в покое
		lt = np.linalg.norm(tp[tgt.find("LeftUpLeg")] - tp[tgt.find("LeftFoot")])
		ls = np.linalg.norm(self.src_rest_p[src.find("thigh_l")] - self.src_rest_p[src.find("foot_l")])
		self.k = float(lt / ls)
		# Ноги в опорной позе стоят иначе, чем в покое (прямее или шире): бёдра поднимаются или
		# опускаются так, чтобы лодыжки остались на высоте покоя
		ref_t, ref_r = tgt.rest_pose()
		for i in tgt.order:
			p = tgt.parent[i]
			ref_r[0, i] = self.ref_r[i] if p < 0 else qnorm(qmul(qconj(self.ref_r[p]), self.ref_r[i]))
		rp, _ = tgt.fk(ref_t, ref_r)
		feet = [tgt.find("LeftFoot"), tgt.find("RightFoot")]
		self.lift = float(tp[feet, 1].min() - rp[0, feet, 1].min())
		self.tgt_hips_rest_world = tp[self.tgt_hips] + np.array([0.0, self.lift, 0.0])

	def _build_ref(self) -> None:
		"""Опорная поза героя: поза покоя, довёрнутая по направлениям костей позы покоя библиотеки."""
		tgt = self.tgt
		src = self.src
		gr = np.zeros((tgt.n, 4))
		rest_g = np.zeros((tgt.n, 4))
		for i in tgt.order:
			p = tgt.parent[i]
			if p < 0:
				gr[i] = tgt.rest_r[i]
				rest_g[i] = gr[i]
			else:
				gr[i] = qmul(gr[p], tgt.rest_r[i])
				rest_g[i] = qmul(rest_g[p], tgt.rest_r[i])
			base = tgt.names[i].split(":")[-1]
			if base.startswith("mixamorig_"):
				base = base[len("mixamorig_"):]
			if i in self.map and base not in ALIGN:
				gr[i] = rest_g[i]
			if base in ALIGN and i in self.map:
				kids, s_child = ALIGN[base]
				child = -1
				for kname in kids:
					c = tgt.find(kname)
					if c >= 0 and tgt.parent[c] == i:
						child = c
						break
				sc = src.find(s_child)
				if child >= 0 and sc >= 0:
					d_t = qrot(gr[i], tgt.rest_t[child])
					d_s = self.src_rest_p[sc] - self.src_rest_p[self.map[i]]
					gr[i] = qnorm(qmul(q_between(d_t, d_s), gr[i]))
					if base in HAND_ACROSS:
						gr[i] = self._twist_hand(base, gr[i], d_s)
		self.ref_r = gr

	def _twist_hand(self, base: str, g: np.ndarray, axis: np.ndarray) -> np.ndarray:
		local_dir, s_from, s_to = HAND_ACROSS[base]
		a = axis / np.linalg.norm(axis)
		cur = qrot(g, np.array(local_dir, dtype=np.float64))
		want = self.src_rest_p[self.src.find(s_to)] - self.src_rest_p[self.src.find(s_from)]
		cur = cur - a * np.dot(cur, a)
		want = want - a * np.dot(want, a)
		if np.linalg.norm(cur) < 1e-6 or np.linalg.norm(want) < 1e-6:
			return g
		cur /= np.linalg.norm(cur)
		want /= np.linalg.norm(want)
		ang = np.arctan2(np.dot(np.cross(cur, want), a), np.dot(cur, want))
		return qnorm(qmul(q_axis_angle(a, ang), g))

	def retarget(self, src_t: np.ndarray, src_r: np.ndarray) -> tuple:
		"""Локальные позы библиотеки по кадрам → локальные translation/rotation героя."""
		tgt = self.tgt
		F = src_t.shape[0]
		sp, sr = self.src.fk(src_t, src_r)
		out_t, out_r = tgt.rest_pose(F)
		gr = np.zeros((F, tgt.n, 4))
		for i in tgt.order:
			p = tgt.parent[i]
			pr = gr[:, p] if p >= 0 else np.repeat(np.array([[0.0, 0.0, 0.0, 1.0]]), F, axis=0)
			if i in self.map:
				s = self.map[i]
				delta = qmul(sr[:, s], qconj(self.src_rest_r[s])[None])
				g = qnorm(qmul(delta, self.ref_r[i][None]))
				gr[:, i] = g
				out_r[:, i] = qnorm(qmul(qconj(pr), g))
			else:
				gr[:, i] = qmul(pr, out_r[:, i])
		# Бёдра: смещение таза от покоя в масштабе героя, в пространстве родителя бёдер
		h = self.tgt_hips
		off = (sp[:, self.src_pelvis] - self.src_rest_p[self.src_pelvis]) * self.k
		world = self.tgt_hips_rest_world[None] + off
		p = tgt.parent[h]
		if p >= 0:
			pp, prr = tgt.fk(*tgt.rest_pose())
			out_t[:, h] = qrot(qconj(prr[0, p])[None], world - pp[0, p][None]) / tgt.rest_s[p]
		else:
			out_t[:, h] = world
		out_r = continuous(out_r)
		return out_t, out_r


def build_clip(src: Skeleton, rt: Retargeter, names: list, rng) -> tuple:
	"""Клипы библиотеки подряд → (времена, локальные t, локальные r) героя."""
	ts, rs = [], []
	for nm in names:
		ln = src.length(nm)
		fr = max(2, int(round(ln * FPS)) + 1)
		times = np.linspace(0.0, ln, fr)
		lt, lr = src.sample(nm, times)
		if ts:
			# Первый кадр следующего клипа совпадает с последним предыдущего
			lt, lr = lt[1:], lr[1:]
		ts.append(lt)
		rs.append(lr)
	lt = np.concatenate(ts)
	lr = np.concatenate(rs)
	times = np.arange(lt.shape[0]) / FPS
	if rng is not None:
		m = (times >= rng[0] - 1e-6) & (times <= rng[1] + 1e-6)
		lt, lr, times = lt[m], lr[m], times[m] - times[m][0]
	out_t, out_r = rt.retarget(lt, lr)
	return times, out_t, out_r


def write_clip(glb: Glb, tgt: Skeleton, joints: list, name: str, times: np.ndarray, out_t: np.ndarray,
		out_r: np.ndarray, tag: str) -> None:
	samplers, channels = [], []
	t_all = glb.add_float_accessor(times, "SCALAR", True)
	t_one = glb.add_float_accessor(np.zeros(1), "SCALAR", True)
	hips = tgt.find("Hips")
	for i in joints:
		r = out_r[:, i]
		if np.max(np.abs(r - r[0])) < 1e-5:
			samplers.append({"input": t_one, "output": glb.add_float_accessor(r[:1], "VEC4"), "interpolation": "LINEAR"})
		else:
			samplers.append({"input": t_all, "output": glb.add_float_accessor(r, "VEC4"), "interpolation": "LINEAR"})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": i, "path": "rotation"}})
		tr = out_t[:, i]
		if i == hips:
			samplers.append({"input": t_all, "output": glb.add_float_accessor(tr, "VEC3"), "interpolation": "LINEAR"})
		else:
			samplers.append({"input": t_one, "output": glb.add_float_accessor(tr[:1], "VEC3"), "interpolation": "LINEAR"})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": i, "path": "translation"}})
	glb.json.setdefault("animations", []).append(
		{"name": name, "channels": channels, "samplers": samplers, "extras": {"retarget": tag}})


# ---------- Проверка ----------

CHECK_BONES = ["Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "Hips"]


def report(tgt: Skeleton, name: str, times: np.ndarray, lt: np.ndarray, lr: np.ndarray) -> None:
	gp, _ = tgt.fk(lt, lr)
	idx = {b: tgt.find(b) for b in CHECK_BONES}
	head = gp[:, idx["Head"]]
	feet = np.stack([gp[:, idx["LeftToeBase"]], gp[:, idx["RightToeBase"]], gp[:, idx["LeftFoot"]], gp[:, idx["RightFoot"]]], 1)
	hands = np.stack([gp[:, idx["LeftHand"]], gp[:, idx["RightHand"]]], 1)
	print("%-18s %.2f с, кадров %3d | голова y %.2f…%.2f | стопы/носки мин y %.2f (кадр 0: %.2f) | кисти y %.2f…%.2f" % (
		name, times[-1], len(times), head[:, 1].min(), head[:, 1].max(), feet[:, :, 1].min(), feet[0, :, 1].min(),
		hands[:, :, 1].min(), hands[:, :, 1].max()))


def main() -> None:
	ap = argparse.ArgumentParser(description="Перенос анимаций Quaternius UAL на героя со скелетом Mixamo")
	ap.add_argument("hero", help="GLB героя (скелет Mixamo)")
	ap.add_argument("--ual1", required=True, help="UAL1_Standard.glb")
	ap.add_argument("--ual2", required=True, help="UAL2_Standard.glb")
	ap.add_argument("--out", help="куда записать (по умолчанию — в GLB героя)")
	ap.add_argument("--check", action="store_true", help="не записывать, только проверить")
	args = ap.parse_args()

	hero = Glb(args.hero)
	# Прежние клипы этого скрипта — долой (повторный запуск)
	hero.json["animations"] = [a for a in hero.json.get("animations", []) if "retarget" not in a.get("extras", {})]
	names = {a["name"] for a in hero.json["animations"]}
	tgt = Skeleton(hero)
	joints = hero.json["skins"][0]["joints"]
	libs = {"ual1": Skeleton(Glb(args.ual1)), "ual2": Skeleton(Glb(args.ual2))}
	rts = {k: Retargeter(s, tgt) for k, s in libs.items()}
	print("масштаб смещения бёдер: %.3f, подъём бёдер под опорную позу: %.3f м" % (rts["ual1"].k, rts["ual1"].lift))
	report(tgt, "(покой героя)", np.zeros(1), *tgt.rest_pose())
	for clip, (lib, src_names, rng) in CLIPS.items():
		if clip in names:
			raise SystemExit("у героя уже есть свой клип %s" % clip)
		times, out_t, out_r = build_clip(libs[lib], rts[lib], src_names, rng)
		report(tgt, clip, times, out_t, out_r)
		if not args.check:
			write_clip(hero, tgt, joints, clip, times, out_t, out_r, "%s:%s" % (lib, "+".join(src_names)))
	if args.check:
		return
	out = args.out or args.hero
	hero.save(out)
	print("записано: %s, клипов всего %d" % (out, len(hero.json["animations"])))


if __name__ == "__main__":
	main()
