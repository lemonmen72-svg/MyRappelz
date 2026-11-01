#!/usr/bin/env python3
"""Части сценария скриншотов tests/shots.gd (CI: матрица visual в .github/workflows/check.yml).

Сценарий — одна цепочка шагов `match step` (шаг ставит `wait = N` и `step = M`). Его делят на части по таблице
PART_ENTRIES в tests/shots.gd: [шаг точки входа, кадров в блоке до следующей точки входа]. Часть K из N снимает
свои блоки (Godot делит таблицу по весам — func part_bounds в shots.gd; здесь то же деление для печати).

Скрипт разбирает цепочку по тексту (кадров на шаг — wait + 1; цикл `if _frames >= N` — N), проверяет таблицу
и печатает её заново с весами — после правок сценария:
  python3 -I tools/shots_parts.py               — таблица PART_ENTRIES с пересчитанными весами (вставить в shots.gd);
  python3 -I tools/shots_parts.py --parts 6     — какие кадры в какой части и сколько кадров у части;
  python3 -I tools/shots_parts.py --check       — точки входа есть в цепочке и идут по её порядку (код 1 — нет).
Точка входа — шаг, с которого начинается блок (обычно шаг без снимка в начале, где блок ставит свою сцену), или шаг
со снимком, перед которым wait ≥ 3 (часть рисует кадры перед снимком). Вес — только для деления на части поровну.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "tests", "shots.gd")


def parse(path):
	"""Шаги run_step: {шаг: {"wait", "next", "shots", "loop"}} и таблица PART_ENTRIES [[шаг, вес], …]."""
	lines = open(path, encoding="utf-8").read().split("\n")
	steps = {}
	cur = None
	in_run = False
	for line in lines:
		if line.startswith("func "):
			in_run = line.startswith("func run_step(")
			cur = None
			continue
		if not in_run:
			continue
		m = re.match(r"^\t\t(\d+):\s*(#.*)?$", line)
		if m:
			cur = int(m.group(1))
			steps[cur] = {"wait": 0, "next": None, "shots": [], "loop": 0, "done": False}
			continue
		if cur is None:
			continue
		s = steps[cur]
		for n in re.findall(r"\bwait = (\d+)", line):
			s["wait"] = int(n)
		for n in re.findall(r"\bstep = (\d+)", line):
			s["next"] = int(n)
		for n in re.findall(r"if _frames >= (\d+)", line):
			s["loop"] = int(n)
		s["shots"] += re.findall(r"\bshot\(\"([^\"]+)\"", line)
		if "ok_done()" in line:
			s["done"] = True
	text = "\n".join(lines)
	m = re.search(r"const PART_ENTRIES := \[(.*?)\n\]", text, re.S)
	entries = []
	if m:
		for a, b in re.findall(r"\[(\d+),\s*(\d+)\]", m.group(1)):
			entries.append([int(a), int(b)])
	return steps, entries


def chain(steps):
	"""Цепочка от шага 0: [(шаг, первый кадр шага, кадров шага)]."""
	out = []
	s = 0
	frame = 0
	seen = set()
	while s is not None and s in steps and s not in seen:
		seen.add(s)
		st = steps[s]
		n = st["loop"] if st["loop"] else st["wait"] + 1
		out.append((s, frame, n))
		frame += n
		s = None if st["done"] else st["next"]
	return out


def part_bounds(weights, k, n):
	"""Как part_bounds в shots.gd: [индекс первой точки входа части k (с 1), индекс после последней]."""
	cnt = len(weights)
	cum = []
	total = 0
	for w in weights:
		cum.append(total)
		total += w
	cuts = [0]
	for j in range(1, n):
		target = float(total) * float(j) / float(n)
		best = cnt
		best_d = float("inf")
		for i in range(cuts[j - 1] + 1, cnt):
			d = abs(float(cum[i]) - target)
			if d < best_d:
				best_d = d
				best = i
		cuts.append(best)
	cuts.append(cnt)
	return cuts[k - 1], cuts[k]


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--parts", type=int, default=0, help="показать деление на N частей")
	ap.add_argument("--check", action="store_true", help="только проверить таблицу точек входа")
	ap.add_argument("--file", default=SHOTS)
	a = ap.parse_args()
	steps, entries = parse(a.file)
	ch = chain(steps)
	order = {s: i for i, (s, _f, _n) in enumerate(ch)}
	start = {s: f for s, f, _n in ch}
	total = ch[-1][1] + ch[-1][2] if ch else 0
	errors = []
	if not entries:
		errors.append("в %s нет таблицы PART_ENTRIES" % a.file)
	if entries and entries[0][0] != 0:
		errors.append("первая точка входа должна быть шагом 0")
	prev = -1
	for e in entries:
		if e[0] not in order:
			errors.append("точки входа %d нет в цепочке шагов" % e[0])
		elif order[e[0]] <= prev:
			errors.append("точка входа %d стоит не по порядку цепочки" % e[0])
		else:
			prev = order[e[0]]
	if ch and not steps[ch[-1][0]]["done"]:
		errors.append("цепочка обрывается на шаге %d (нет ok_done или следующего шага)" % ch[-1][0])
	for e in errors:
		print("ОШИБКА: " + e, file=sys.stderr)
	if errors:
		return 1
	if a.check:
		print("PART_ENTRIES: %d точек входа, цепочка %d шагов, ≈%d кадров — в порядке" % (len(entries), len(ch), total))
		return 0
	# Веса заново: кадры от точки входа до следующей
	fresh = []
	for i, e in enumerate(entries):
		end = start[entries[i + 1][0]] if i + 1 < len(entries) else total
		fresh.append([e[0], end - start[e[0]]])
	if a.parts <= 0:
		print("const PART_ENTRIES := [")
		row = []
		for e in fresh:
			row.append("[%d, %d]" % (e[0], e[1]))
		for i in range(0, len(row), 8):
			print("\t" + ", ".join(row[i:i + 8]) + ",")
		print("]")
		stale = [(e[0], e[1], f[1]) for e, f in zip(entries, fresh) if e[1] != f[1]]
		if stale:
			print("# устарели веса (шаг: в таблице → по цепочке): " +
				", ".join("%d: %d → %d" % s for s in stale), file=sys.stderr)
		print("# всего ≈%d кадров" % total, file=sys.stderr)
		return 0
	weights = [e[1] for e in entries]
	shots_of = {}
	for i, e in enumerate(entries):
		lo = order[e[0]]
		hi = order[entries[i + 1][0]] if i + 1 < len(entries) else len(ch)
		shots_of[i] = [sh for s, _f, _n in ch[lo:hi] for sh in steps[s]["shots"]]
	for k in range(1, a.parts + 1):
		b0, b1 = part_bounds(weights, k, a.parts)
		if b0 >= b1:
			print("часть %d/%d: пусто" % (k, a.parts))
			continue
		frames = sum(fresh[i][1] for i in range(b0, b1))
		skip = start[entries[b0][0]]
		shots = [sh for i in range(b0, b1) for sh in shots_of[i]]
		print("часть %d/%d: шаги %d…%s, ≈%d кадров с отрисовкой, перемотка %d кадров, снимков %d: %s … %s" % (
			k, a.parts, entries[b0][0], str(entries[b1][0]) + " (не входит)" if b1 < len(entries) else "конец",
			frames, skip, len(shots), shots[0] if shots else "-", shots[-1] if shots else "-"))
	return 0


if __name__ == "__main__":
	sys.exit(main())
