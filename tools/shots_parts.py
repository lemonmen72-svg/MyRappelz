#!/usr/bin/env python3
"""Части сценария скриншотов tests/shots.gd (CI: матрица visual в .github/workflows/check.yml).

Сценарий — одна цепочка шагов `match step` (шаг ставит `wait = N` и `step = M`). Его делят на части по таблице
PART_ENTRIES в tests/shots.gd: [шаг точки входа, кадров в блоке до следующей точки входа, секунд блока в CI].
Часть K из N получает подряд идущие блоки так, чтобы самая долгая часть была как можно короче: время части —
секунды её блоков + перемотка до её начала (PART_FF_MS мс на кадр до точки входа). Делит Godot (func part_bounds
в shots.gd); здесь — то же деление для печати и проверки.

  python3 -I tools/shots_parts.py                       — таблица PART_ENTRIES заново: кадры по цепочке, секунды —
                                                          прежние (у нового блока — кадры × SEC_PER_FRAME);
  python3 -I tools/shots_parts.py --from-logs F …       — секунды блоков из логов частей (shots.log из артефактов
                                                          shots-part-K или ветки ci-screenshots: строки «[OK]
                                                          скриншот X (…), N с от запуска» и «перемотка … за N с»);
  python3 -I tools/shots_parts.py --parts 6 [--from-logs …] — деление: что в какой части и оценка её времени;
  python3 -I tools/shots_parts.py --check               — точки входа есть в цепочке и идут по её порядку.
Кадров на шаг — wait + 1, цикл `if _frames >= N` — N. Точка входа — шаг, с которого начинается блок (обычно шаг
без снимка в начале, где блок ставит свою сцену), или шаг со снимком, перед которым wait ≥ 3.
Время блока по логу — от последнего снимка предыдущего блока (у первого блока части — от конца перемотки) до
последнего снимка блока: в него входит и подготовка блока (загрузка моделей) в последнем шаге предыдущего.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "tests", "shots.gd")
# Секунд на кадр с отрисовкой у блока без замера (CI, llvmpipe; в среднем по логам ≈0.4–0.5)
SEC_PER_FRAME = 0.5
# Перемотка без отрисовки, мс на кадр до точки входа — как PART_FF_MS в shots.gd
PART_FF_MS = 10


def parse(path):
	"""Шаги run_step: {шаг: {"wait", "next", "shots", "loop", "done"}} и таблица PART_ENTRIES [[шаг, кадры, сек], …]."""
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
		for row in re.findall(r"\[([\d,\s]+)\]", m.group(1)):
			nums = [int(x) for x in row.replace(" ", "").split(",") if x]
			entries.append((nums + [0, 0])[:3])
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


def part_bounds(entries, k, n):
	"""Как part_bounds в shots.gd: [индекс первой точки входа части k (с 1), индекс после последней]."""
	cnt = len(entries)
	parts = min(n, cnt)
	if k > parts:
		return cnt, cnt
	start_f = []
	cum_ms = [0]
	f = 0
	for e in entries:
		start_f.append(f)
		f += e[1]
		cum_ms.append(cum_ms[-1] + e[2] * 1000)
	inf = 1 << 60
	best = [[inf] * (cnt + 1) for _ in range(parts + 1)]
	src = [[0] * (cnt + 1) for _ in range(parts + 1)]
	best[0][0] = 0
	for j in range(1, parts + 1):
		for i in range(j, cnt + 1):
			for p in range(j - 1, i):
				prev = best[j - 1][p]
				if prev == inf:
					continue
				c = cum_ms[i] - cum_ms[p] + start_f[p] * PART_FF_MS
				v = max(prev, c)
				if v < best[j][i]:
					best[j][i] = v
					src[j][i] = p
	cuts = [0] * (parts + 1)
	cuts[parts] = cnt
	at = cnt
	for j in range(parts, 0, -1):
		cuts[j - 1] = src[j][at]
		at = cuts[j - 1]
	return cuts[k - 1], cuts[k]


def read_logs(paths):
	"""Логи частей: [(перемотка, с или 0; [(снимок, секунды от запуска), …])]."""
	out = []
	for p in paths:
		ff = 0.0
		shots = []
		for line in open(p, encoding="utf-8", errors="replace"):
			m = re.search(r"перемотка до шага \d+ — \d+ кадров за ([\d.]+) с", line)
			if m:
				ff = float(m.group(1))
			m = re.search(r"\[OK\] скриншот (\S+) \(.*?\), (\d+) с от запуска", line)
			if m:
				shots.append((m.group(1), float(m.group(2))))
		out.append((ff, shots))
	return out


def block_seconds(logs, shots_of):
	"""Секунды блоков (индекс → список замеров) по логам частей."""
	block_of = {}
	for i, names in shots_of.items():
		for s in names:
			block_of[s] = i
	got = {}
	for ff, shots in logs:
		t = dict(shots)
		order = sorted({block_of[s] for s, _ in shots if s in block_of})
		for i in order:
			names = shots_of[i]
			if not names or any(s not in t for s in names):
				continue
			prev = shots_of.get(i - 1, [])
			if prev and all(s in t for s in prev):
				start = t[prev[-1]]
			elif i - 1 in order:
				continue
			else:
				start = ff
			got.setdefault(i, []).append(max(1.0, t[names[-1]] - start))
	return got


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--parts", type=int, default=0, help="показать деление на N частей")
	ap.add_argument("--check", action="store_true", help="только проверить таблицу точек входа")
	ap.add_argument("--from-logs", nargs="+", default=[], metavar="LOG", help="секунды блоков из логов частей")
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
	shots_of = {}
	for i, e in enumerate(entries):
		lo = order[e[0]]
		hi = order[entries[i + 1][0]] if i + 1 < len(entries) else len(ch)
		shots_of[i] = [sh for s, _f, _n in ch[lo:hi] for sh in steps[s]["shots"]]
	measured = block_seconds(read_logs(a.from_logs), shots_of) if a.from_logs else {}
	fresh = []
	for i, e in enumerate(entries):
		end = start[entries[i + 1][0]] if i + 1 < len(entries) else total
		frames = end - start[e[0]]
		if i in measured:
			secs = round(sum(measured[i]) / len(measured[i]))
		elif e[2] > 0:
			secs = e[2]
		else:
			secs = round(frames * SEC_PER_FRAME)
		fresh.append([e[0], frames, secs])
	if a.from_logs:
		miss = [entries[i][0] for i in range(len(entries)) if i not in measured]
		print("# по логам измерено блоков: %d из %d%s" % (len(measured), len(entries),
			("; без замера (прежние секунды или кадры × %.1f): %s" % (SEC_PER_FRAME, miss)) if miss else ""), file=sys.stderr)
	if a.parts <= 0:
		print("const PART_ENTRIES := [")
		row = ["[%d, %d, %d]" % tuple(e) for e in fresh]
		for i in range(0, len(row), 6):
			print("\t" + ", ".join(row[i:i + 6]) + ",")
		print("]")
		print("# всего ≈%d кадров, ≈%d с снимков" % (total, sum(e[2] for e in fresh)), file=sys.stderr)
		return 0
	for k in range(1, a.parts + 1):
		b0, b1 = part_bounds(fresh, k, a.parts)
		if b0 >= b1:
			print("часть %d/%d: пусто" % (k, a.parts))
			continue
		secs = sum(fresh[i][2] for i in range(b0, b1))
		skip = start[entries[b0][0]]
		shots = [sh for i in range(b0, b1) for sh in shots_of[i]]
		print("часть %d/%d: шаги %d…%s, снимки ≈%d с + перемотка %d кадров ≈%d с = ≈%.1f мин; снимков %d: %s … %s" % (
			k, a.parts, entries[b0][0], str(entries[b1][0]) + " (не входит)" if b1 < len(entries) else "конец",
			secs, skip, skip * PART_FF_MS // 1000, (secs + skip * PART_FF_MS / 1000.0) / 60.0, len(shots),
			shots[0] if shots else "-", shots[-1] if shots else "-"))
	return 0


if __name__ == "__main__":
	sys.exit(main())
