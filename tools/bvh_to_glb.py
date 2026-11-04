#!/usr/bin/env python3
"""Мокап CMU (BVH, конверсия cgspeed 2010) → GLB-«манекен» со скелетом под имена Mixamo для tools/retarget_mannequin.py.

Зачем: шаг и бег героев раньше брались с манекенов Meshy (m1 Walking / Running) и подгонялись под скорость героя
(длина шага ×1.1–1.3, подъём стопы ×0.62 IK) — выходил «шпагат» и прямые ноги, не похоже на человека (жалоба Максима
на 0.30.0). Теперь — запись живого человека из базы CMU Graphics Lab (mocap.cs.cmu.edu: «free for use in research and
commercial projects worldwide»; BVH — конверсия Bruce Hahne, без дополнительных ограничений; assets/LICENSES.md).

Что делает:
  * читает BVH (иерархия, OFFSET, каналы ZYX, кадры), единицы CMU → метры (UNIT: 1/0.45 дюйма = 0.05644 м);
  * переименовывает кости в Mixamo (mixamorig:Hips, Spine, Spine1, Spine2, Neck, Head, LeftShoulder, LeftArm, …,
    LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase), лишние звенья CMU (LHipJoint, Neck1) остаются под своими именами;
    пальцы CMU (LeftFingerBase, LeftHandIndex1, LThumb) не берутся — вместо них неподвижные дочерние точки кисти
    HandMiddle1 / HandIndex1 / HandPinky1 (для направления и поворота кисти в переносе: ладонь вниз, указательный —
    вперёд); пальцы героя потом берутся из бега манекена (retarget_mannequin, MQ_CMU);
  * поза покоя — первый кадр файла (T-поза конверсии, лицом к +Z), клип — выбранный отрезок;
  * выбирает ровный цикл шага: по максимумам выноса левой стопы вперёд (относительно таза, вдоль движения) — целые
    циклы в середине записи с самой ровной скоростью; разворачивает запись так, чтобы движение шло к +Z;
  * печатает скорость (м/с, по тазу), длину шага, частоту шагов, долю полёта (обе стопы над землёй).

Запуск:  python3 -I tools/bvh_to_glb.py out.glb имя_клипа=файл.bvh[:циклов] …   (--info — только числа)
Зависимости: numpy.
"""
import argparse
import json
import math
import os
import re
import struct
import sys

import numpy as np

UNIT = 0.0254 / 0.45
## Кости CMU → Mixamo (без приставки). Остальные (кроме пальцев) — под своими именами.
RENAME = {
	"Hips": "Hips", "LowerBack": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
	"RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
}
DROP = re.compile(r"^(Left|Right)(FingerBase|HandIndex1)$|^[LR]Thumb$")


# ---------- кватернионы (x, y, z, w) ----------

def qmul(a, b):
	ax, ay, az, aw = np.moveaxis(a, -1, 0)
	bx, by, bz, bw = np.moveaxis(b, -1, 0)
	return np.stack([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz], -1)


def qaxis(axis, ang):
	ang = np.asarray(ang, dtype=np.float64)
	s = np.sin(ang * 0.5)[..., None]
	return np.concatenate([np.asarray(axis, dtype=np.float64) * s, np.cos(ang * 0.5)[..., None]], -1)


def qrot(q, v):
	u = q[..., :3]
	w = q[..., 3:4]
	t = 2.0 * np.cross(u, v)
	return v + w * t + np.cross(u, t)


AX = {"X": np.array([1.0, 0, 0]), "Y": np.array([0, 1.0, 0]), "Z": np.array([0, 0, 1.0])}


# ---------- BVH ----------

class Bvh:
	def __init__(self, path: str) -> None:
		toks = open(path).read().split()
		self.names, self.parent, self.offset, self.chans = [], [], [], []
		i = 0
		stack = []
		end_count = 0
		while toks[i] != "MOTION":
			t = toks[i]
			if t in ("ROOT", "JOINT"):
				self.names.append(toks[i + 1])
				self.parent.append(stack[-1] if stack else -1)
				self.offset.append(None)
				self.chans.append([])
				cur = len(self.names) - 1
				i += 2
			elif t == "End":
				end_count += 1
				self.names.append("_end%d" % end_count)
				self.parent.append(stack[-1])
				self.offset.append(None)
				self.chans.append([])
				cur = len(self.names) - 1
				i += 2
			elif t == "{":
				stack.append(cur)
				i += 1
			elif t == "}":
				stack.pop()
				i += 1
			elif t == "OFFSET":
				self.offset[stack[-1]] = [float(x) for x in toks[i + 1:i + 4]]
				i += 4
			elif t == "CHANNELS":
				n = int(toks[i + 1])
				self.chans[stack[-1]] = toks[i + 2:i + 2 + n]
				i += 2 + n
			else:
				i += 1
		nf = int(toks[i + 2])
		self.dt = float(toks[i + 5])
		vals = np.array([float(x) for x in toks[i + 6:]], dtype=np.float64)
		ncol = sum(len(c) for c in self.chans)
		self.data = vals[:nf * ncol].reshape(nf, ncol)
		self.offset = np.array(self.offset, dtype=np.float64) * UNIT
		# Локальные повороты и смещения по кадрам
		J = len(self.names)
		self.lq = np.zeros((nf, J, 4))
		self.lq[..., 3] = 1.0
		self.lt = np.repeat(self.offset[None], nf, axis=0)
		col = 0
		for j, ch in enumerate(self.chans):
			q = np.zeros((nf, 4))
			q[:, 3] = 1.0
			for c in ch:
				v = self.data[:, col]
				col += 1
				if c.endswith("position"):
					self.lt[:, j, "XYZ".index(c[0])] = v * UNIT
				else:
					q = qmul(q, qaxis(AX[c[0]], np.radians(v)))
			self.lq[:, j] = q

	def fk(self, lq=None, lt=None):
		lq = self.lq if lq is None else lq
		lt = self.lt if lt is None else lt
		gq = np.zeros_like(lq)
		gp = np.zeros_like(lt)
		for j, p in enumerate(self.parent):
			if p < 0:
				gq[:, j], gp[:, j] = lq[:, j], lt[:, j]
			else:
				gq[:, j] = qmul(gq[:, p], lq[:, j])
				gp[:, j] = gp[:, p] + qrot(gq[:, p], lt[:, j])
		return gq, gp


def gait(b: Bvh, frames: slice = slice(1, None)) -> dict:
	"""Направление движения, скорость, циклы по выносу левой стопы."""
	gq, gp = b.fk()
	ix = {n: i for i, n in enumerate(b.names)}
	hip = gp[frames, ix["Hips"]]
	lf = gp[frames, ix["LeftFoot"]]
	rf = gp[frames, ix["RightFoot"]]
	lt_ = gp[frames, ix["LeftToeBase"]]
	rt_ = gp[frames, ix["RightToeBase"]]
	d = hip[-1, [0, 2]] - hip[0, [0, 2]]
	fwd = d / max(np.linalg.norm(d), 1e-6)
	ahead = (lf[:, [0, 2]] - hip[:, [0, 2]]) @ fwd
	n = len(ahead)
	# Сглаживание (±4 кадра) и максимумы
	k = 4
	sm = np.convolve(np.pad(ahead, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
	peaks = [i for i in range(1, n - 1) if sm[i] >= sm[i - 1] and sm[i] > sm[i + 1] and sm[i] > np.percentile(sm, 70)]
	clean = []
	for p in peaks:
		if clean and p - clean[-1] < 0.25 / b.dt:
			if sm[p] > sm[clean[-1]]:
				clean[-1] = p
			continue
		clean.append(p)
	ground = min(lt_[:, 1].min(), rt_[:, 1].min())
	return {"fwd": fwd, "peaks": clean, "hip": hip, "ground": ground, "lt": lt_, "rt": rt_, "lf": lf, "rf": rf}


def pick_cycles(b: Bvh, cycles: int) -> tuple:
	g = gait(b)
	pk = g["peaks"]
	if len(pk) < cycles + 1:
		raise SystemExit("мало циклов: %d" % (len(pk) - 1))
	best = None
	for a in range(len(pk) - cycles):
		s, e = pk[a], pk[a + cycles]
		hip = g["hip"]
		v = np.linalg.norm(np.diff(hip[s:e + 1][:, [0, 2]], axis=0), axis=1) / b.dt
		score = float(np.std(v) / max(np.mean(v), 1e-6))
		# Ровность циклов — длины соседних циклов близки, середина записи лучше края
		mid = abs((s + e) * 0.5 - len(hip) * 0.5) / len(hip)
		score += 0.3 * mid
		if best is None or score < best[0]:
			best = (score, s, e)
	_, s, e = best
	return s + 1, e + 1, g


def stats(b: Bvh, s: int, e: int, g: dict) -> dict:
	hip = b.fk()[1][:, b.names.index("Hips")]
	dist = float(np.linalg.norm(hip[e, [0, 2]] - hip[s, [0, 2]]))
	T = (e - s) * b.dt
	ground = g["ground"]
	lt = g["lt"][s - 1:e - 1, 1] - ground
	rt = g["rt"][s - 1:e - 1, 1] - ground
	air = float(np.mean((lt > 0.05) & (rt > 0.05)))
	return {"speed": dist / T, "T": T, "step": dist / 2.0, "cadence": 2.0 / T, "flight": air,
		"hip_h": float(hip[s:e, 1].mean()), "bob": float(np.ptp(hip[s:e, 1]))}


# ---------- GLB ----------

def write_glb(path: str, clips: list) -> None:
	"""clips — [(имя, Bvh, s, e)]; скелет — из первого (у всех клипов одного актёра он один)."""
	b0 = clips[0][1]
	keep = [j for j, n in enumerate(b0.names) if not n.startswith("_end") and not DROP.match(n)]
	newi = {j: k for k, j in enumerate(keep)}
	nodes = []
	rest_q = b0.lq[0]
	for j in keep:
		n = b0.names[j]
		tr = b0.offset[j] if b0.parent[j] >= 0 else np.array([0.0, b0.lt[0, j, 1], 0.0])
		nodes.append({"name": "mixamorig:" + RENAME.get(n, n), "translation": [float(x) for x in tr],
			"rotation": [float(x) for x in rest_q[j]], "children": []})
	for j in keep:
		p = b0.parent[j]
		if p >= 0:
			nodes[newi[p]]["children"].append(newi[j])
	# Дочерние точки кисти: в T-позе кисть смотрит вдоль руки, ладонь вниз; «средний» — вдоль кисти, «указательный» и
	# «мизинец» — вперёд и назад от него (как у Mixamo). Направление — в пространстве покоя кисти.
	_gq0, gp0 = b0.fk(b0.lq[:1], b0.lt[:1])
	gq0 = _gq0[0]
	for side, sx in (("Left", 1.0), ("Right", -1.0)):
		h = b0.names.index(side + "Hand")
		fa = b0.names.index(side + "ForeArm")
		along = gp0[0, h] - gp0[0, fa]
		along = along / max(np.linalg.norm(along), 1e-6) * 0.08
		inv = gq0[h].copy()
		inv[:3] *= -1
		for nm, off in (("HandMiddle1", np.zeros(3)), ("HandIndex1", np.array([0, 0, 0.025])),
				("HandPinky1", np.array([0, 0, -0.025]))):
			w = along + off
			loc = qrot(inv, w)
			nodes.append({"name": "mixamorig:" + side + nm, "translation": [float(x) for x in loc],
				"rotation": [0.0, 0.0, 0.0, 1.0], "children": []})
			nodes[newi[h]]["children"].append(len(nodes) - 1)
	for nd in nodes:
		if not nd["children"]:
			del nd["children"]
	buf = bytearray()
	accessors, views, anims = [], [], []

	def add(arr: np.ndarray, typ: str, minmax: bool = False) -> int:
		a = np.ascontiguousarray(arr, dtype=np.float32)
		while len(buf) % 4:
			buf.append(0)
		views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": a.nbytes})
		buf.extend(a.tobytes())
		acc = {"bufferView": len(views) - 1, "componentType": 5126, "count": int(a.shape[0]), "type": typ}
		if minmax:
			acc["min"] = [float(a.min())]
			acc["max"] = [float(a.max())]
		accessors.append(acc)
		return len(accessors) - 1

	for name, b, s, e, fwd in clips:
		lq = b.lq[s:e + 1].copy()
		lt = b.lt[s:e + 1].copy()
		# Разворот: движение — к +Z (поворот вокруг Y всей записи), начало — над нулём по X/Z
		yaw = math.atan2(fwd[0], fwd[1])
		r = qaxis(np.array([0, 1.0, 0]), -yaw)
		root = 0
		lq[:, root] = qmul(np.broadcast_to(r, lq[:, root].shape), lq[:, root])
		lt[:, root] = qrot(np.broadcast_to(r, lq[:, root].shape), lt[:, root])
		lt[:, root, 0] -= lt[0, root, 0]
		lt[:, root, 2] -= lt[0, root, 2]
		times = np.arange(e - s + 1) * b.dt
		ti = add(times[:, None], "SCALAR", True)
		samplers, chans = [], []
		for j in keep:
			k = newi[j]
			samplers.append({"input": ti, "output": add(lq[:, j], "VEC4"), "interpolation": "LINEAR"})
			chans.append({"sampler": len(samplers) - 1, "target": {"node": k, "path": "rotation"}})
			if j == root:
				samplers.append({"input": ti, "output": add(lt[:, j], "VEC3"), "interpolation": "LINEAR"})
				chans.append({"sampler": len(samplers) - 1, "target": {"node": k, "path": "translation"}})
		anims.append({"name": name, "samplers": samplers, "channels": chans})
	gltf = {"asset": {"version": "2.0", "generator": "bvh_to_glb.py (CMU mocap)"}, "scene": 0,
		"scenes": [{"nodes": [0]}], "nodes": nodes, "animations": anims, "accessors": accessors,
		"bufferViews": views, "buffers": [{"byteLength": len(buf)}]}
	js = json.dumps(gltf, separators=(",", ":")).encode()
	while len(js) % 4:
		js += b" "
	while len(buf) % 4:
		buf.append(0)
	out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf))
	out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + bytes(buf)
	with open(path, "wb") as f:
		f.write(out)


def main() -> None:
	ap = argparse.ArgumentParser(description="CMU BVH → GLB-манекен (имена Mixamo)")
	ap.add_argument("out")
	ap.add_argument("clips", nargs="+", help="имя=файл.bvh[:циклов]")
	ap.add_argument("--info", action="store_true", help="только числа, без записи")
	args = ap.parse_args()
	todo = []
	for c in args.clips:
		name, rest = c.split("=", 1)
		cyc = 1
		if re.search(r":\d+$", rest):
			rest, cyc = rest.rsplit(":", 1)
			cyc = int(cyc)
		b = Bvh(rest)
		s, e, g = pick_cycles(b, cyc)
		st = stats(b, s, e, g)
		print("%-14s %s: кадры %d–%d из %d (%.0f к/с), циклов %d: %.2f с, скорость %.2f м/с, шаг %.2f м, %.2f шаг/с, "
			"полёт %.0f %%, таз %.2f м (ход %.3f)" % (name, os.path.basename(rest), s, e, len(b.lq), 1 / b.dt, cyc, st["T"],
			st["speed"], st["step"] / cyc, st["cadence"] * cyc, 100 * st["flight"], st["hip_h"], st["bob"]))
		todo.append((name, b, s, e, g["fwd"]))
	if not args.info:
		write_glb(args.out, todo)
		print("записано: %s (%.2f МБ)" % (args.out, os.path.getsize(args.out) / 1e6))


if __name__ == "__main__":
	main()
