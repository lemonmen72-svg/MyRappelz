class_name BotHistory
extends RefCounted
## История запусков тест-бота, сравнение запусков и экспорт (фаза 6 Кардинала: «удобная админ-панель, сравнение
## запусков, отчёты, экспорт»). Каждый запуск оставляет сводку report.json (папка запуска и архив отчёта — summary):
## режим, версия, итог, проверки и неудачные проверки, разделы, замеры, автотесты, подозрения Кардинала, сбой
## прошлого запуска, ошибки лога; и строку в user://bot_reports/history.json (последние MAX_RUNS). Вкладка
## «Отчёты» админ-панели: список запусков, «Открыть», «Поделиться», «Сравнить с прошлым» (тот же режим — compare),
## «Экспорт всего» (export_all: архив истории, сводок, текстов отчётов и сравнения). Предложения по итогам —
## BotSuggest (вкладка «Предложения», только просмотр).

const SCHEMA := 1
const FILE := "history.json"
const SUMMARY := "report.json"
## Запусков в истории, не больше.
const MAX_RUNS := 40
## Неудачных проверок в сводке, не больше.
const MAX_FAILED := 60
## Разница замера, с которой строка сравнения помечается ▲ / ▼, доля.
const NOTABLE := 0.05

## Последнее сравнение (вкладка «Отчёты»): строки и запуски.
static var last_compare := PackedStringArray()
static var last_compare_ids := []


# ---------- Сводка запуска ----------

## Сводка запуска bot (report.json).
static func summary(bot: TestBot) -> Dictionary:
	var failed: Array = []
	var errors := 0
	for c in bot.checks:
		if bool(c["ok"]):
			continue
		errors += 1
		if failed.size() < MAX_FAILED:
			failed.append({"section": String(c.get("section", "")), "text": String(c.get("text", "")),
				"at": snappedf(float(c.get("at", 0.0)), 0.1)})
	var by_log := BotReport.log_by_section(bot.log_mark)
	var sections: Array = []
	for s in bot.sections:
		var lg: Dictionary = by_log.get(String(s.get("title", "")), {})
		sections.append({"id": String(s.get("id", "")), "title": String(s.get("title", "")),
			"state": String(s.get("state", "")), "sec": snappedf(float(s.get("sec", 0.0)), 0.1),
			"checks": int(s.get("checks", 0)), "errors": int(s.get("errors", 0)),
			"log_errors": int(lg.get("errors", 0)), "log_lines": Array(lg.get("lines", PackedStringArray()))})
	var measures: Array = []
	for r in bot.rows:
		var m: Dictionary = r.get("m", {})
		measures.append({"scene": String(r.get("scene", "")), "setting": String(r.get("setting", "")),
			"kind": String(r.get("kind", "")), "preset": String(r.get("preset", "")), "cap": int(r.get("cap", 0)),
			"fps": snappedf(float(m.get("fps", 0.0)), 0.1), "fps_min": snappedf(float(m.get("fps_min", 0.0)), 0.1),
			"ms": snappedf(float(m.get("ms", 0.0)), 0.01), "p95": snappedf(float(m.get("p95", 0.0)), 0.01),
			"gpu": snappedf(float(m.get("gpu", -1.0)), 0.01), "draw": roundi(float(m.get("draw", 0.0))),
			"prim": roundi(float(m.get("prim", 0.0))), "hitches": int(m.get("hitches", 0))})
	var lt := BotReport.log_tail(bot.log_mark, 0)
	var d := {
		"schema": SCHEMA, "id": bot.base_name, "mode": bot.mode,
		"mode_name": BotScenario.mode_name(bot.mode) if bot.scenario == null else bot.scenario.title(),
		"group": String(BotScenario.mode(bot.mode).get("group", "")), "version": BotReport.version(),
		"date": bot.started_text, "result": bot.result_kind,
		"result_text": String(BotReport.KIND_TEXT.get(bot.result_kind, bot.result_kind)), "reason": bot.stop_reason,
		"duration": snappedf(bot.total_time, 0.1), "active": snappedf(bot.active_time, 0.1),
		"cool": snappedf(bot.cool_time, 0.1), "away": snappedf(bot.away_time, 0.1),
		"checks": bot.checks.size(), "errors": errors, "failed": failed,
		"log": {"errors": int(lt.get("errors", 0)), "warnings": int(lt.get("warnings", 0))},
		"device": _device_line(bot.device), "renderer": BotReport.renderer_text(),
		"sections": sections, "measures": measures, "advice": [], "crash": _crash(bot),
	}
	if not bot.rows.is_empty():
		d["advice"] = Array(BotReport.recommendations(bot))
	if bot.scenario != null:
		var extra := bot.scenario.report_data(bot)
		for k in extra:
			d[k] = extra[k]
	return d


static func _device_line(dev: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ["model", "android"]:
		if String(dev.get(k, "")) != "":
			parts.append(String(dev[k]))
	return " · ".join(parts)


## Сбой прошлого запуска бота (метка RUNNING) с причиной по данным Android.
static func _crash(bot: TestBot) -> Dictionary:
	var ib := bot.interrupted_before
	if ib.is_empty():
		return {}
	var res := {"mode": String(ib.get("mode", "")), "mode_name": BotScenario.mode_name(String(ib.get("mode", ""))),
		"step": String(ib.get("step", "")), "time": String(ib.get("time", "")), "failure": false, "line": "",
		"trace": []}
	var ex: Dictionary = bot.device.get("exits", {})
	var e := BotReport.exit_after(ex.get("exits", []), String(ib.get("time", "")))
	if not e.is_empty():
		res["failure"] = BotReport.EXIT_FAILURES.has(String(e.get("reason", "")))
		res["line"] = BotReport.exit_line(e)
		var tr: Array = e.get("trace", []) if e.get("trace", []) is Array else []
		res["trace"] = tr.slice(0, 12)
	return res


## Записать сводку в папку запуска (до архива — она войдёт в него). Путь к файлу ("" — не записалось).
static func write_summary(bot: TestBot, d: Dictionary) -> String:
	if bot.run_dir == "":
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bot.run_dir))
	var path := bot.run_dir + SUMMARY
	return path if TestBot.write_atomic(path, JSON.stringify(d, "\t")) else ""


# ---------- История ----------

## Запуски (старые первыми): {id, mode, mode_name, date, version, result, result_text, checks, errors, duration,
## summary, txt, zip, public}.
static func runs(dir: String = TestBot.REPORT_DIR) -> Array:
	var path := dir + FILE
	if not FileAccess.file_exists(path):
		return []
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return []
	var list: Variant = (j.data as Dictionary).get("runs", [])
	var res: Array = []
	if list is Array:
		for r in list:
			if r is Dictionary and String((r as Dictionary).get("id", "")) != "":
				res.append(r)
	return res


## Добавить запуск в историю (по сводке d и итогу экспорта res: пути отчёта); лишние старые — вон из истории.
static func add_run(d: Dictionary, res: Dictionary, summary_path: String, dir: String = TestBot.REPORT_DIR) -> void:
	var list := runs(dir)
	var e := {"id": String(d.get("id", "")), "mode": String(d.get("mode", "")), "mode_name": String(d.get("mode_name", "")),
		"date": String(d.get("date", "")), "version": String(d.get("version", "")), "result": String(d.get("result", "")),
		"result_text": String(d.get("result_text", "")), "checks": int(d.get("checks", 0)), "errors": int(d.get("errors", 0)),
		"duration": float(d.get("duration", 0.0)), "summary": summary_path, "txt": String(res.get("txt", "")),
		"zip": String(res.get("zip", "")), "public": String(res.get("public", "")), "uri": String(res.get("uri", ""))}
	list = list.filter(func(r: Dictionary) -> bool: return String(r.get("id", "")) != String(e["id"]))
	list.append(e)
	while list.size() > MAX_RUNS:
		list.pop_front()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	TestBot.write_atomic(dir + FILE, JSON.stringify({"schema": SCHEMA, "runs": list}, "\t"))


## Сводка запуска из истории ({} — файла нет или он испорчен).
static func load_summary(run: Dictionary) -> Dictionary:
	var path := String(run.get("summary", ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data


## Прошлый запуск того же режима перед запуском i (-1 — нет).
static func previous_of(list: Array, i: int) -> int:
	if i < 0 or i >= list.size():
		return -1
	var m := String((list[i] as Dictionary).get("mode", ""))
	for k in range(i - 1, -1, -1):
		if String((list[k] as Dictionary).get("mode", "")) == m:
			return k
	return -1


## Строка запуска для списка: «07.11 12:26 · Производительность · 0.44.0 · готово · ошибок 0».
static func run_line(r: Dictionary) -> String:
	var date := String(r.get("date", ""))
	if date.length() >= 16:
		date = "%s.%s %s" % [date.substr(8, 2), date.substr(5, 2), date.substr(11, 5)]
	return "%s · %s · %s · %s · ошибок %d" % [date, String(r.get("mode_name", "?")), String(r.get("version", "?")),
		String(r.get("result_text", "?")), int(r.get("errors", 0))]


# ---------- Сравнение ----------

## Сравнение запуска b с прошлым a того же режима: итог, разделы, новые и исправленные ошибки, замеры, автотесты,
## подозрения Кардинала, лог.
static func compare(a: Dictionary, b: Dictionary) -> PackedStringArray:
	var L := PackedStringArray()
	L.append("Сравнение запусков: «%s»" % String(b.get("mode_name", b.get("mode", "?"))))
	L.append("  Было:  %s · версия %s · %s · проверок %d, ошибок %d · %s" % [String(a.get("date", "?")),
		String(a.get("version", "?")), String(a.get("result_text", "?")), int(a.get("checks", 0)), int(a.get("errors", 0)),
		TestBot.clock(float(a.get("duration", 0.0)))])
	L.append("  Стало: %s · версия %s · %s · проверок %d, ошибок %d · %s" % [String(b.get("date", "?")),
		String(b.get("version", "?")), String(b.get("result_text", "?")), int(b.get("checks", 0)), int(b.get("errors", 0)),
		TestBot.clock(float(b.get("duration", 0.0)))])
	var ea := int(a.get("errors", 0))
	var eb := int(b.get("errors", 0))
	L.append("  Итог: %s" % ("ошибок меньше (%d → %d)" % [ea, eb] if eb < ea else ("ошибок больше (%d → %d)" % [ea, eb]
		if eb > ea else "ошибок столько же (%d)" % eb)))
	_cmp_sections(a, b, L)
	_cmp_failed(a, b, L)
	_cmp_measures(a, b, L)
	_cmp_autotests(a, b, L)
	_cmp_suspicions(a, b, L)
	var la: Dictionary = a.get("log", {})
	var lb: Dictionary = b.get("log", {})
	L.append("Лог Godot: ошибок %d → %d, предупреждений %d → %d" % [int(la.get("errors", 0)), int(lb.get("errors", 0)),
		int(la.get("warnings", 0)), int(lb.get("warnings", 0))])
	return L


static func _cmp_sections(a: Dictionary, b: Dictionary, L: PackedStringArray) -> void:
	var sa := {}
	for s in a.get("sections", []):
		sa[String((s as Dictionary).get("id", ""))] = s
	var same := 0
	var lines := PackedStringArray()
	for s in b.get("sections", []):
		var sd: Dictionary = s
		var old: Dictionary = sa.get(String(sd.get("id", "")), {})
		if old.is_empty():
			lines.append("  %s: новый раздел — ошибок %d" % [String(sd.get("title", "")), int(sd.get("errors", 0))])
			continue
		var e0 := int(old.get("errors", 0))
		var e1 := int(sd.get("errors", 0))
		if e0 == e1 and int(old.get("log_errors", 0)) == int(sd.get("log_errors", 0)):
			same += 1
			continue
		lines.append("  %s: ошибок %d → %d, в логе %d → %d (%s → %s)" % [String(sd.get("title", "")), e0, e1,
			int(old.get("log_errors", 0)), int(sd.get("log_errors", 0)), TestBot.clock(float(old.get("sec", 0.0))),
			TestBot.clock(float(sd.get("sec", 0.0)))])
	if lines.is_empty() and same == 0:
		return
	L.append("Разделы:")
	L.append_array(lines)
	if same > 0:
		L.append("  без изменений: %d" % same)


## Текст проверки без чисел (числа в тексте меняются от запуска к запуску).
static func _norm(t: String) -> String:
	var re := RegEx.create_from_string("[0-9]+([.,][0-9]+)?")
	return re.sub(t, "#", true)


static func _cmp_failed(a: Dictionary, b: Dictionary, L: PackedStringArray) -> void:
	var fa := {}
	for f in a.get("failed", []):
		fa[String((f as Dictionary).get("section", "")) + "|" + _norm(String((f as Dictionary).get("text", "")))] = f
	var fb := {}
	for f in b.get("failed", []):
		fb[String((f as Dictionary).get("section", "")) + "|" + _norm(String((f as Dictionary).get("text", "")))] = f
	var new_l := PackedStringArray()
	for k in fb:
		if not fa.has(k):
			var f: Dictionary = fb[k]
			new_l.append("  + %s%s" % ["[%s] " % String(f["section"]) if String(f.get("section", "")) != "" else "",
				String(f.get("text", ""))])
	var gone := PackedStringArray()
	for k in fa:
		if not fb.has(k):
			var f: Dictionary = fa[k]
			gone.append("  − %s%s" % ["[%s] " % String(f["section"]) if String(f.get("section", "")) != "" else "",
				String(f.get("text", ""))])
	if not new_l.is_empty():
		L.append("Новые ошибки проверок (%d):" % new_l.size())
		L.append_array(new_l)
	if not gone.is_empty():
		L.append("Ошибки, которых больше нет (%d):" % gone.size())
		L.append_array(gone)


static func _cmp_measures(a: Dictionary, b: Dictionary, L: PackedStringArray) -> void:
	var ma := {}
	for m in a.get("measures", []):
		ma[String((m as Dictionary).get("scene", "")) + "|" + String((m as Dictionary).get("setting", ""))] = m
	var lines := PackedStringArray()
	var worse := 0
	var better := 0
	for m in b.get("measures", []):
		var mb: Dictionary = m
		var k := String(mb.get("scene", "")) + "|" + String(mb.get("setting", ""))
		if not ma.has(k):
			continue
		var m0: Dictionary = ma[k]
		var f0 := float(m0.get("fps", 0.0))
		var f1 := float(mb.get("fps", 0.0))
		var p0 := float(m0.get("p95", 0.0))
		var p1 := float(mb.get("p95", 0.0))
		var df := (f1 - f0) / f0 if f0 > 0.0 else 0.0
		var dp := (p1 - p0) / p0 if p0 > 0.0 else 0.0
		var mark := ""
		if df <= -NOTABLE or dp >= NOTABLE * 2.0:
			mark = "▼ "
			worse += 1
		elif df >= NOTABLE or dp <= -NOTABLE * 2.0:
			mark = "▲ "
			better += 1
		var gpu := ""
		if float(m0.get("gpu", -1.0)) > 0.0 and float(mb.get("gpu", -1.0)) > 0.0:
			gpu = ", ГП %.1f → %.1f мс" % [float(m0["gpu"]), float(mb["gpu"])]
		lines.append("  %s%s · %s: %.1f → %.1f к/с (%+.0f %%), p95 %.1f → %.1f мс%s" % [mark, String(mb.get("scene", "")),
			String(mb.get("setting", "")), f0, f1, df * 100.0, p0, p1, gpu])
	if lines.is_empty():
		return
	L.append("Замеры (▼ — хуже, ▲ — лучше на %d %% и больше; хуже %d, лучше %d):" % [roundi(NOTABLE * 100.0), worse, better])
	L.append_array(lines)


static func _cmp_autotests(a: Dictionary, b: Dictionary, L: PackedStringArray) -> void:
	var ta := {}
	for t in a.get("autotests", []):
		ta[String((t as Dictionary).get("name", ""))] = t
	var broke := PackedStringArray()
	var fixed := PackedStringArray()
	var slower := PackedStringArray()
	for t in b.get("autotests", []):
		var tb: Dictionary = t
		var n := String(tb.get("name", ""))
		if not ta.has(n):
			continue
		var t0: Dictionary = ta[n]
		var s0 := String(t0.get("status", ""))
		var s1 := String(tb.get("status", ""))
		var label := "%s «%s»" % [n, TestCatalog.title(n)]
		if s0 == "ok" and s1 != "ok" and s1 != "skip":
			broke.append("  %s: %s" % [label, String(tb.get("text", s1))])
		elif s0 != "ok" and s0 != "skip" and s1 == "ok":
			fixed.append("  " + label)
		elif s0 == "ok" and s1 == "ok" and float(t0.get("sec", 0.0)) > 3.0 \
				and float(tb.get("sec", 0.0)) > float(t0.get("sec", 0.0)) * 1.5:
			slower.append("  %s: %.1f → %.1f с" % [label, float(t0["sec"]), float(tb["sec"])])
	if not broke.is_empty():
		L.append("Автотесты, которые перестали проходить (%d):" % broke.size())
		L.append_array(broke)
	if not fixed.is_empty():
		L.append("Автотесты, которые снова проходят (%d):" % fixed.size())
		L.append_array(fixed)
	if not slower.is_empty():
		L.append("Автотесты заметно дольше (×1.5 и больше):")
		L.append_array(slower)


static func _cmp_suspicions(a: Dictionary, b: Dictionary, L: PackedStringArray) -> void:
	var sa := {}
	for s in a.get("suspicions", []):
		sa[String((s as Dictionary).get("title", ""))] = true
	var sb := {}
	for s in b.get("suspicions", []):
		sb[String((s as Dictionary).get("title", ""))] = s
	var new_l := PackedStringArray()
	for k in sb:
		if not sa.has(k):
			new_l.append("  + [%s] %s" % [String((sb[k] as Dictionary).get("severity", "")), String(k)])
	var gone := PackedStringArray()
	for k in sa:
		if not sb.has(k):
			gone.append("  − " + String(k))
	if not new_l.is_empty():
		L.append("Кардинал — новые подозрения (%d):" % new_l.size())
		L.append_array(new_l)
	if not gone.is_empty():
		L.append("Кардинал — подозрений больше нет (%d):" % gone.size())
		L.append_array(gone)


## Сравнить запуск list[i] с прошлым того же режима; строки — в last_compare (и файл в папке отчётов). "" — готово,
## иначе — почему нельзя.
static func compare_run(list: Array, i: int, dir: String = TestBot.REPORT_DIR) -> String:
	var j := previous_of(list, i)
	if j < 0:
		return "прошлого запуска этого режима в истории нет"
	var b := load_summary(list[i])
	var a := load_summary(list[j])
	if a.is_empty() or b.is_empty():
		return "сводки запуска нет (отчёт до 0.45 или файл удалён)"
	last_compare = compare(a, b)
	last_compare_ids = [String(a.get("id", "")), String(b.get("id", ""))]
	TestBot.write_atomic(compare_path(dir), "\n".join(last_compare) + "\n")
	return ""


static func compare_path(dir: String = TestBot.REPORT_DIR) -> String:
	return dir + "compare_last.txt"


# ---------- Экспорт ----------

## Архив всех отчётов: история, сводки запусков, тексты отчётов, последнее сравнение и предложения.
## Итог — как у BotReport.export ({zip, txt, public, uri, message}).
static func export_all(dir: String = TestBot.REPORT_DIR) -> Dictionary:
	var list := runs(dir)
	var now := Time.get_datetime_dict_from_system()
	var name := "DarkPact_reports_%s_%04d-%02d-%02d_%02d-%02d" % [BotReport.version(), int(now["year"]), int(now["month"]),
		int(now["day"]), int(now["hour"]), int(now["minute"])]
	var res := {"zip": "", "txt": "", "public": "", "uri": "", "message": "", "runs": list.size()}
	if list.is_empty():
		res["message"] = "Отчётов в истории ещё нет"
		return res
	var entries: Array = [["history.json", dir + FILE]]
	for r in list:
		var rd: Dictionary = r
		var id := String(rd.get("id", ""))
		if FileAccess.file_exists(String(rd.get("summary", ""))):
			entries.append([id + "/" + SUMMARY, String(rd["summary"])])
		if FileAccess.file_exists(String(rd.get("txt", ""))):
			entries.append([id + "/" + id + ".txt", String(rd["txt"])])
	if FileAccess.file_exists(compare_path(dir)):
		entries.append(["compare_last.txt", compare_path(dir)])
	var sug_path := dir + "suggestions.txt"
	if TestBot.write_atomic(sug_path, BotSuggest.text(BotSuggest.collect(list)) + "\n"):
		entries.append(["suggestions.txt", sug_path])
	var zip := dir + name + ".zip"
	if not BotReport.make_zip(zip, entries):
		res["message"] = "Архив не записался"
		return res
	res["zip"] = zip
	var pub := BotReport.publish(zip, BotReport.ZIP_MIME)
	if bool(pub.get("ok", false)):
		res["public"] = String(pub["public"])
		res["uri"] = String(pub["where"])
		res["message"] = "Экспорт: %s (запусков %d)" % [String(pub["public"]), list.size()]
	else:
		res["message"] = "Экспорт: %s (запусков %d)" % [ProjectSettings.globalize_path(zip), list.size()]
	return res
