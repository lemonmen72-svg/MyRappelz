#!/usr/bin/env python3
"""Деление автотестов на части (CI: матрица smoke, параллельные потоки внутри задачи).

Задания — tests/smoke_test.gd, tests/test_*.gd (кроме test_base.gd) и «perf» (замер нагрузки без рендера,
tests/perf.gd). Вес — секунды из smoke_weights.txt рядом (строки «имя секунды», имя без tests/ и .gd);
нового теста там нет — DEFAULT_WEIGHT. Деление детерминированное: самые долгие — первыми, каждый в самую
лёгкую часть (при равенстве — с меньшим номером). Части вложенные: --of «K/N» ещё раз делит часть K из N.
Время тестов — в логе smoke («ВРЕМЯ тест …: N с»), веса обновлять по нему.

  python3 -I .github/scripts/split_tests.py PART PARTS [--of K/N]  — задания части PART из PARTS (по алфавиту);
  python3 -I .github/scripts/split_tests.py --show PARTS           — все части и их вес.
"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WEIGHTS = os.path.join(HERE, "smoke_weights.txt")
DEFAULT_WEIGHT = 5.0


def items():
	out = []
	for p in ["tests/smoke_test.gd"] + sorted(glob.glob("tests/test_*.gd")):
		name = os.path.basename(p)[:-3]
		if name == "test_base" or not os.path.isfile(p):
			continue
		out.append(name)
	if os.path.isfile("tests/perf.gd"):
		out.append("perf")
	return out


def weights():
	w = {}
	if os.path.isfile(WEIGHTS):
		for line in open(WEIGHTS, encoding="utf-8"):
			line = line.split("#", 1)[0].split()
			if len(line) == 2:
				try:
					w[line[0]] = float(line[1])
				except ValueError:
					pass
	return w


def split(names, n, w):
	parts = [[] for _ in range(n)]
	load = [0.0] * n
	for name in sorted(names, key=lambda x: (-w.get(x, DEFAULT_WEIGHT), x)):
		i = min(range(n), key=lambda j: (load[j], j))
		parts[i].append(name)
		load[i] += w.get(name, DEFAULT_WEIGHT)
	return [sorted(p, key=lambda x: (x != "smoke_test", x == "perf", x)) for p in parts], load


def main(argv):
	w = weights()
	names = items()
	if len(argv) >= 2 and argv[0] == "--show":
		n = int(argv[1])
		parts, load = split(names, n, w)
		for i in range(n):
			print("часть %d/%d: ≈%.0f с, %d заданий: %s" % (i + 1, n, load[i], len(parts[i]), " ".join(parts[i])))
		return 0
	if len(argv) < 2:
		print(__doc__)
		return 2
	k, n = int(argv[0]), int(argv[1])
	if len(argv) >= 4 and argv[2] == "--of":
		ok, on = argv[3].split("/")
		names = split(names, int(on), w)[0][int(ok) - 1]
	if n < 1 or k < 1 or k > n:
		print("нужно 1 ≤ PART ≤ PARTS", file=sys.stderr)
		return 2
	for name in split(names, n, w)[0][k - 1]:
		print(name)
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
