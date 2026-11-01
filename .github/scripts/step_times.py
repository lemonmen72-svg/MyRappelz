#!/usr/bin/env python3
"""Время шагов этой задачи CI (последний шаг «Время этапов»): GitHub API — задачи текущего запуска, своя задача —
по имени раннера (RUNNER_NAME). Печатает длительность каждого завершённого шага и итог; затем строки этапов
скриптов ($RUNNER_TEMP/ci_times.txt, timing.sh). Ошибка API — только строки этапов. Нужен токен с actions: read.
Окружение: TOKEN, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT, RUNNER_NAME, RUNNER_TEMP.
"""
import datetime
import json
import os
import urllib.request


def ts(s):
	return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ") if s else None


def main():
	env = os.environ
	url = "https://api.github.com/repos/%s/actions/runs/%s/attempts/%s/jobs?per_page=100" % (
		env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_RUN_ID", ""), env.get("GITHUB_RUN_ATTEMPT", "1"))
	req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
	if env.get("TOKEN"):
		req.add_header("Authorization", "Bearer " + env["TOKEN"])
	try:
		with urllib.request.urlopen(req, timeout=20) as r:
			jobs = json.load(r).get("jobs", [])
	except Exception as e:  # noqa: BLE001
		print("время шагов: API недоступно (%s)" % e)
		jobs = []
	me = [j for j in jobs if j.get("runner_name") and j.get("runner_name") == env.get("RUNNER_NAME")]
	for j in me:
		print("Время шагов задачи «%s»:" % j.get("name", ""))
		start = ts(j.get("started_at"))
		for s in j.get("steps", []):
			a, b = ts(s.get("started_at")), ts(s.get("completed_at"))
			if a and b:
				print("%6d с  %s" % ((b - a).total_seconds(), s.get("name", "")))
		if start:
			print("%6d с  итого до этого шага" % (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) - start).total_seconds())
	path = os.path.join(env.get("RUNNER_TEMP", "/tmp"), "ci_times.txt")
	if os.path.isfile(path):
		print("Этапы скриптов:")
		print(open(path, encoding="utf-8").read().rstrip())


if __name__ == "__main__":
	main()
