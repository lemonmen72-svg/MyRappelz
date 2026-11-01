#!/usr/bin/env python3
"""План «Проверки кода» (задача plan в check.yml): нужны ли скриншоты и замер нагрузки и какие части запускать.

Снимки (visual) и замер (perf) идут, только если изменились файлы, влияющие на картинку: всё, кроме NO_PICTURE
(документы, tools/, автотесты test_*.gd, сборка APK и Android, скрипты только для smoke). Изменённые файлы —
GitHub API compare (push: before…sha, pull_request: base…head); не удалось узнать (новая ветка, ошибка сети,
больше 300 файлов) — снимки идут. Ручной запуск (workflow_dispatch): части — из полей запуска.

Окружение: EVENT, REPO, TOKEN, BEFORE, AFTER, BASE, HEAD, SHOTS_PARTS (число частей), PERF_PARTS (группы пресетов
через пробел, например «0,1 2,3»), INPUT_SHOTS («all» / «none» / «1,3»), INPUT_PERF («true»/«false»).
Выход (GITHUB_OUTPUT): visual, shots (JSON-список номеров частей), perf (JSON-список групп), full (все части).
Проверка правил без сети: python3 -I .github/scripts/ci_plan.py --files путь1 путь2 …
"""
import json
import os
import re
import sys
import urllib.request

# Файлы, от которых картинка не меняется: при изменении только их снимки не снимаются
NO_PICTURE = [
	r"(^|/)[^/]*\.md$",
	r"\.docx$",
	r"^tools/",
	r"^tests/test_(?!base\.gd$)[^/]*\.gd$",
	r"^tests/smoke_test\.gd$",
	r"^android/",
	r"^export_presets\.cfg$",
	r"^\.gitignore$",
	r"^\.github/workflows/android-apk\.yml$",
	r"^\.github/scripts/(smoke_test\.sh|split_tests\.py|smoke_weights\.txt)$",
]


def needs_picture(path):
	return not any(re.search(p, path) for p in NO_PICTURE)


def changed_files():
	"""Список изменённых файлов или None (не удалось узнать — считать, что изменилось всё)."""
	ev = os.environ.get("EVENT", "")
	if ev == "push":
		a, b = os.environ.get("BEFORE", ""), os.environ.get("AFTER", "")
	elif ev == "pull_request":
		a, b = os.environ.get("BASE", ""), os.environ.get("HEAD", "")
	else:
		return None
	if not a or not b or set(a) == {"0"}:
		return None
	url = "https://api.github.com/repos/%s/compare/%s...%s?per_page=300" % (os.environ.get("REPO", ""), a, b)
	req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
	tok = os.environ.get("TOKEN", "")
	if tok:
		req.add_header("Authorization", "Bearer " + tok)
	try:
		with urllib.request.urlopen(req, timeout=30) as r:
			data = json.load(r)
	except Exception as e:  # noqa: BLE001 — любая ошибка: снимаем всё
		print("compare: %s — снимки идут" % e)
		return None
	files = data.get("files")
	if not isinstance(files, list) or len(files) >= 300:
		return None
	out = []
	for f in files:
		out.append(f.get("filename", ""))
		if f.get("previous_filename"):
			out.append(f["previous_filename"])
	return out


def parse_parts(text, n):
	text = (text or "all").strip().lower()
	if text in ("all", "все", ""):
		return list(range(1, n + 1))
	if text in ("none", "нет", "0"):
		return []
	out = []
	for t in re.split(r"[ ,;]+", text):
		if t.isdigit() and 1 <= int(t) <= n and int(t) not in out:
			out.append(int(t))
	return sorted(out)


def main(argv):
	if argv and argv[0] == "--files":
		for p in argv[1:]:
			print("%s %s" % ("снимки" if needs_picture(p) else "—", p))
		return 0
	n = int(os.environ.get("SHOTS_PARTS", "1"))
	perf_groups = os.environ.get("PERF_PARTS", "").split()
	ev = os.environ.get("EVENT", "")
	if ev == "workflow_dispatch":
		shots = parse_parts(os.environ.get("INPUT_SHOTS", "all"), n)
		perf = perf_groups if os.environ.get("INPUT_PERF", "true") == "true" else []
		reason = "ручной запуск"
	else:
		files = changed_files()
		if files is None:
			pic = True
			reason = "изменённые файлы неизвестны"
		else:
			pic_files = [f for f in files if needs_picture(f)]
			pic = bool(pic_files)
			reason = "изменено файлов %d, влияют на картинку %d%s" % (len(files), len(pic_files),
				(": " + ", ".join(pic_files[:10]) + (" …" if len(pic_files) > 10 else "")) if pic_files else "")
		shots = list(range(1, n + 1)) if pic else []
		perf = perf_groups if pic else []
	visual = bool(shots or perf)
	print("План: %s → снимки %s, замер %s" % (reason, shots or "нет", perf or "нет"))
	out = os.environ.get("GITHUB_OUTPUT")
	lines = [
		"visual=%s" % ("true" if visual else "false"),
		"shots=%s" % json.dumps(shots),
		"perf=%s" % json.dumps(perf),
		"full=%s" % ("true" if len(shots) == n else "false"),
	]
	if out:
		with open(out, "a", encoding="utf-8") as f:
			f.write("\n".join(lines) + "\n")
	else:
		print("\n".join(lines))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
