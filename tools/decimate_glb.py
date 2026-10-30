#!/usr/bin/env python3
"""Упрощение меша модели со скелетом в GLB (например, героя из Meshy: 180+ тыс. треугольников — слишком много
для телефона: модель рисуется трижды — сама, контур и тень).

Меняется только меш (первый примитив каждого меша): треугольников становится не больше --tris, вершины не
сдвигаются (у оставшихся — исходные UV, нормали, кости и веса; упрощение — tools/prepare_creatures.simplify_mesh,
meshoptimizer). Скелет, кожа и все анимации остаются как были. Встроенные картинки выбрасываются (Godot их всё
равно отбрасывает при импорте — gltf/embedded_image_handling=0, текстура лежит рядом PNG). Буфер пересобирается
без неиспользуемых данных.

Запуск из корня репозитория (нужны numpy и meshoptimizer — см. шапку prepare_creatures.py):
  python3 -I tools/decimate_glb.py assets/characters/dark_elf_wanderer.glb --tris 30000
"""
import argparse
import importlib.util
import json
import os
import struct

import numpy as np

_spec = importlib.util.spec_from_file_location("prepare_creatures",
	os.path.join(os.path.dirname(os.path.abspath(__file__)), "prepare_creatures.py"))
pc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pc)

CT = {np.dtype(np.uint8): 5121, np.dtype(np.uint16): 5123, np.dtype(np.uint32): 5125, np.dtype(np.float32): 5126}
TYPE = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4", 16: "MAT4"}


def raw_accessor(gltf: dict, binc: bytes, i: int) -> bytes:
	"""Байты данных accessor без чередования (как они лежат, без перевода в float)."""
	a = gltf["accessors"][i]
	bv = gltf["bufferViews"][a["bufferView"]]
	size = np.dtype(pc.COMP[a["componentType"]]).itemsize * pc.NCOMP[a["type"]]
	off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
	stride = bv.get("byteStride", 0) or size
	if stride == size:
		return binc[off:off + size * a["count"]]
	return b"".join(binc[off + k * stride:off + k * stride + size] for k in range(a["count"]))


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("glb")
	ap.add_argument("--tris", type=int, default=30000)
	ap.add_argument("--out", default="")
	args = ap.parse_args()
	gltf, binc = pc.read_glb(args.glb)

	out = bytearray()
	views: list = []
	accs: list = []

	def put(data: bytes, target: int = 0) -> int:
		while len(out) % 4:
			out.append(0)
		views.append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data)})
		if target:
			views[-1]["target"] = target
		out.extend(data)
		return len(views) - 1

	def new_acc(arr: np.ndarray, target: int = 0, minmax: bool = False, normalized: bool = False) -> int:
		arr = np.ascontiguousarray(arr)
		n = 1 if arr.ndim == 1 else arr.shape[1]
		a = {"bufferView": put(arr.tobytes(), target), "componentType": CT[arr.dtype], "count": int(arr.shape[0]),
			"type": TYPE[n]}
		if normalized:
			a["normalized"] = True
		if minmax:
			a["min"] = [float(x) for x in arr.min(axis=0)]
			a["max"] = [float(x) for x in arr.max(axis=0)]
		accs.append(a)
		return len(accs) - 1

	copied: dict = {}

	def copy_acc(i: int) -> int:
		if i in copied:
			return copied[i]
		a = dict(gltf["accessors"][i])
		a.pop("byteOffset", None)
		a["bufferView"] = put(raw_accessor(gltf, binc, i))
		accs.append(a)
		copied[i] = len(accs) - 1
		return copied[i]

	before = after = 0
	for mesh in gltf["meshes"]:
		for k, prim in enumerate(mesh["primitives"]):
			at = prim["attributes"]
			if k > 0 or "JOINTS_0" not in at:
				prim["attributes"] = {n: copy_acc(v) for n, v in at.items()}
				if "indices" in prim:
					prim["indices"] = copy_acc(prim["indices"])
				continue
			jdt = np.dtype(pc.COMP[gltf["accessors"][at["JOINTS_0"]]["componentType"]])
			m = {"pos": pc.accessor(gltf, binc, at["POSITION"]).astype(np.float64),
				"nrm": pc.accessor(gltf, binc, at["NORMAL"]).astype(np.float64),
				"uv": pc.accessor(gltf, binc, at["TEXCOORD_0"]).astype(np.float64),
				"joints": pc.accessor(gltf, binc, at["JOINTS_0"]),
				"weights": pc.accessor(gltf, binc, at["WEIGHTS_0"]).astype(np.float64),
				"tris": pc.accessor(gltf, binc, prim["indices"]).astype(np.int64).reshape(-1, 3)}
			before += len(m["tris"])
			s = pc.simplify_mesh(m, args.tris)
			after += len(s["tris"])
			w = s["weights"] / np.maximum(s["weights"].sum(axis=1, keepdims=True), 1e-9)
			prim["attributes"] = {
				"POSITION": new_acc(s["pos"].astype(np.float32), 34962, True),
				"NORMAL": new_acc(s["nrm"].astype(np.float32), 34962),
				"TEXCOORD_0": new_acc(s["uv"].astype(np.float32), 34962),
				"JOINTS_0": new_acc(s["joints"].astype(jdt), 34962),
				"WEIGHTS_0": new_acc(w.astype(np.float32), 34962),
			}
			idt = np.uint16 if len(s["pos"]) < 65536 else np.uint32
			prim["indices"] = new_acc(s["tris"].astype(idt).ravel(), 34963)
	for skin in gltf.get("skins", []):
		if "inverseBindMatrices" in skin:
			skin["inverseBindMatrices"] = copy_acc(skin["inverseBindMatrices"])
	for anim in gltf.get("animations", []):
		for smp in anim["samplers"]:
			smp["input"] = copy_acc(smp["input"])
			smp["output"] = copy_acc(smp["output"])
	# Встроенные картинки — прочь (в игре текстура из соседнего PNG)
	for key in ("images", "textures", "samplers"):
		gltf.pop(key, None)
	for mat in gltf.get("materials", []):
		pbr = mat.get("pbrMetallicRoughness", {})
		for t in ("baseColorTexture", "metallicRoughnessTexture"):
			pbr.pop(t, None)
		for t in ("normalTexture", "occlusionTexture", "emissiveTexture"):
			mat.pop(t, None)
	gltf["accessors"] = accs
	gltf["bufferViews"] = views
	while len(out) % 4:
		out.append(0)
	gltf["buffers"] = [{"byteLength": len(out)}]
	js = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
	js += b" " * ((4 - len(js) % 4) % 4)
	total = 12 + 8 + len(js) + 8 + len(out)
	data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js \
		+ struct.pack("<II", len(out), 0x004E4942) + bytes(out)
	path = args.out or args.glb
	open(path, "wb").write(data)
	print("треугольников %d → %d, файл %.1f МБ" % (before, after, len(data) / 1e6))


if __name__ == "__main__":
	main()
