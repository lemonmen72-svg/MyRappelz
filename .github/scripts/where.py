#!/usr/bin/env python3
"""Где идут автотесты и сборка APK: .github/runner.txt — «laptop» (ноутбук Максима, self-hosted исполнитель с
меткой laptop, tools/laptop/) или «github» (серверы GitHub, как раньше; ночью и когда ноутбук выключен).
Пишет в GITHUB_OUTPUT: where, smoke_on / apk_on (JSON для runs-on), smoke_parts (матрица частей), smoke_jobs."""
import json
import os
from pathlib import Path

where = "github"
f = Path(".github/runner.txt")
if f.exists():
	for line in f.read_text(encoding="utf-8").splitlines():
		line = line.split("#", 1)[0].strip().lower()
		if line:
			where = line
			break
if where not in ("laptop", "github"):
	print(f"::warning::.github/runner.txt: «{where}» — не laptop и не github, беру github")
	where = "github"

if where == "laptop":
	# Одна задача: исполнитель на ноутбуке один, тесты внутри идут потоками (i3: 4 потока, 32 ГБ памяти)
	on = ["self-hosted", "laptop"]
	parts, jobs = [1], 3
else:
	on = "ubuntu-24.04"
	parts, jobs = [1, 2, 3, 4], 1

out = {
	"where": where,
	"smoke_on": json.dumps(on),
	"apk_on": json.dumps(on),
	"smoke_parts": json.dumps(parts),
	"smoke_jobs": str(jobs),
}
print(f"выполняем: {where} — {out['smoke_on']}, части {out['smoke_parts']}, потоков {jobs}")
gh = os.environ.get("GITHUB_OUTPUT")
if gh:
	with open(gh, "a", encoding="utf-8") as fh:
		for k, v in out.items():
			fh.write(f"{k}={v}\n")
