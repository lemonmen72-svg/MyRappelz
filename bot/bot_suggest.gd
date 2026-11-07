class_name BotSuggest
extends RefCounted
## «Предложения по исправлениям» (фаза 6 Кардинала, вкладка «Предложения» админ-панели): что посмотреть по итогам
## последних запусков тест-бота — по сводке report.json последнего запуска каждого режима (BotHistory): сбой игры,
## ошибка бота, неудачные проверки по разделам, не прошедшие автотесты, ошибки лога Godot, остановка перегревом или
## лимитом, подозрения Кардинала, рекомендации «Производительности». У каждого — важность, где (режим, дата, версия),
## доказательства и что посмотреть. ТОЛЬКО ПРОСМОТР И ЭКСПОРТ: кнопки «применить» нет и не будет без отдельного
## решения Максима (ТЗ Кардинала, §8), игра ничего не меняет сама.

const SEVERITIES := ["critical", "error", "warn", "info"]
const SEV_NAMES := {"critical": "Критично", "error": "Ошибка", "warn": "Внимание", "info": "Заметка"}
const SEV_COLORS := {"critical": Color(1.0, 0.35, 0.35), "error": Color(1.0, 0.6, 0.4), "warn": Color(1.0, 0.85, 0.4),
	"info": Color(0.7, 0.85, 1.0)}
## Важность подозрений Кардинала → важность предложения.
const CARDINAL_SEV := {"высокая": "error", "средняя": "warn", "низкая": "info"}
## Неудачных проверок раздела в доказательствах, не больше.
const EVIDENCE := 4


## Предложения по последнему запуску каждого режима из истории runs (BotHistory.runs), важные первыми.
static func collect(runs: Array) -> Array:
	var latest := {}
	var order: Array = []
	for r in runs:
		var m := String((r as Dictionary).get("mode", ""))
		if not latest.has(m):
			order.append(m)
		latest[m] = r
	var out: Array = []
	for m in order:
		var run: Dictionary = latest[m]
		var d := BotHistory.load_summary(run)
		if d.is_empty():
			continue
		out.append_array(from_summary(d))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return SEVERITIES.find(String(a["severity"])) < SEVERITIES.find(String(b["severity"])))
	return out


## Предложения по одной сводке запуска d.
static func from_summary(d: Dictionary) -> Array:
	var out: Array = []
	var where := "%s · %s · версия %s" % [String(d.get("mode_name", d.get("mode", "?"))), String(d.get("date", "?")),
		String(d.get("version", "?"))]
	var id := String(d.get("id", ""))
	# Сбой игры в прошлом запуске бота
	var cr: Dictionary = d.get("crash", {})
	if not cr.is_empty():
		var ev := PackedStringArray()
		ev.append("Прошлый запуск «%s» (%s) не закончился%s" % [String(cr.get("mode_name", "?")), String(cr.get("time", "?")),
			", шаг: " + String(cr["step"]) if String(cr.get("step", "")) != "" else ""])
		if String(cr.get("line", "")) != "":
			ev.append("Android: " + String(cr["line"]))
		for t in (cr.get("trace", []) as Array).slice(0, 6):
			ev.append("  " + String(t))
		out.append(_item("critical" if bool(cr.get("failure", false)) else "warn",
			"Игра закрылась посреди теста%s" % (" — сбой" if bool(cr.get("failure", false)) else ""),
			where, ev, "След сбоя — раздел «Прошлые завершения игры» этого отчёта. Повторить тот же режим: если игра снова "
			+ "закроется на том же шаге — это ошибка игры на этом шаге (прислать отчёт).", id))
	# Итог запуска
	match String(d.get("result", "")):
		"error":
			out.append(_item("critical", "Тест-бот остановился с ошибкой", where,
				PackedStringArray([String(d.get("reason", ""))]),
				"Повторить режим; если ошибка та же — прислать отчёт (журнал и хвост лога — в конце отчёта).", id))
		"hot":
			out.append(_item("warn", "Остановлен перегревом телефона", where,
				PackedStringArray([String(d.get("reason", ""))]),
				"Дать телефону остыть, снять чехол, не ставить на зарядку; начать заново или «Продолжить» (долгие режимы).", id))
		"limit":
			out.append(_item("warn", "Не успел за лимит времени", where,
				PackedStringArray([String(d.get("reason", ""))]),
				"Сравнить время разделов с прошлым запуском («Отчёты» → «Сравнить с прошлым»): что стало медленнее.", id))
	# Неудачные проверки — по разделам
	var by_sec := {}
	var sec_order: Array = []
	for f in d.get("failed", []):
		var fd: Dictionary = f
		var sec := String(fd.get("section", ""))
		if not by_sec.has(sec):
			by_sec[sec] = []
			sec_order.append(sec)
		(by_sec[sec] as Array).append(String(fd.get("text", "")))
	for sec in sec_order:
		var list: Array = by_sec[sec]
		var ev := PackedStringArray()
		for t in list.slice(0, EVIDENCE):
			ev.append(String(t))
		if list.size() > EVIDENCE:
			ev.append("… ещё %d" % (list.size() - EVIDENCE))
		var title := "Раздел «%s»: ошибок проверок %d" % [sec, list.size()] if sec != "" else \
			"Ошибок проверок: %d" % list.size()
		var advice := "Повторить «По разделам» → «%s»; снимки раздела — в архиве отчёта, строки лога — в блоке «Разделы»." % sec \
			if sec != "" else "Подробности — «Проверки» в конце отчёта."
		out.append(_item("error", title, where, ev, advice, id))
	# Автотесты
	for t in d.get("autotests", []):
		var td: Dictionary = t
		var st := String(td.get("status", ""))
		if st == "ok" or st == "skip":
			continue
		var n := String(td.get("name", ""))
		var ev := PackedStringArray([String(td.get("text", st))])
		for e in (td.get("errors", []) as Array).slice(0, 3):
			ev.append("  " + String(e))
		if TestCatalog.what(n) != "":
			ev.append("Что проверяет: " + TestCatalog.what(n))
		out.append(_item("error", "Автотест «%s» (%s) не прошёл" % [TestCatalog.title(n), n], where, ev,
			"Подробности — раздел «Автотесты» отчёта; повторить: «Автотесты: по группам» → «%s»; в CI идёт тот же тест."
			% TestCatalog.group_name(TestCatalog.group_of(n)), id))
	# Лог Godot
	var lg: Dictionary = d.get("log", {})
	var log_err := int(lg.get("errors", 0))
	if log_err > 0:
		var ev := PackedStringArray()
		for s in d.get("sections", []):
			var sd: Dictionary = s
			if int(sd.get("log_errors", 0)) > 0:
				ev.append("%s: %d — %s" % [String(sd.get("title", "")), int(sd["log_errors"]),
					String((sd.get("log_lines", []) as Array).front()) if not (sd.get("log_lines", []) as Array).is_empty() else ""])
		out.append(_item("warn", "В логе Godot ошибок: %d" % log_err, where, ev,
			"Хвост лога — в конце отчёта, по разделам — в блоке «Разделы»; ошибка повторяется — прислать отчёт.", id))
	# Подозрения Кардинала
	for s in d.get("suspicions", []):
		var sd: Dictionary = s
		var ev := PackedStringArray()
		for e in sd.get("evidence", []):
			ev.append(String(e))
		if String(sd.get("who", "")) != "":
			ev.insert(0, "Кто: " + String(sd["who"]))
		var adv := String(sd.get("advice", ""))
		if String(sd.get("repro", "")) != "":
			adv += (" " if adv != "" else "") + "Повторить: " + String(sd["repro"])
		out.append(_item(String(CARDINAL_SEV.get(String(sd.get("severity", "")), "info")),
			"Кардинал: " + String(sd.get("title", "")), where, ev, adv if adv != "" else "Посмотреть раздел «Кардинал» отчёта.", id))
	# Рекомендации «Производительности»
	var adv_lines: Array = d.get("advice", [])
	if not adv_lines.is_empty():
		var ev := PackedStringArray()
		for a in adv_lines.slice(0, 8):
			ev.append(String(a).strip_edges())
		out.append(_item("info", "Производительность: рекомендации", where, ev,
			"Это советы по настройкам графики на этом телефоне; сравнить с прошлым замером — «Отчёты» → «Сравнить с прошлым».", id))
	return out


static func _item(sev: String, title: String, where: String, evidence: PackedStringArray, advice: String,
		run_id: String) -> Dictionary:
	return {"severity": sev, "title": title, "where": where, "evidence": evidence, "advice": advice, "run": run_id}


## Текст предложений (экспорт).
static func text(items: Array) -> String:
	var L := PackedStringArray()
	L.append("Dark Pact — предложения по итогам тест-бота (только просмотр: игра ничего не меняет сама)")
	L.append("")
	if items.is_empty():
		L.append("Замечаний нет.")
	for it in items:
		var d: Dictionary = it
		L.append("[%s] %s" % [String(SEV_NAMES.get(String(d["severity"]), d["severity"])), String(d["title"])])
		L.append("  где: " + String(d["where"]))
		for e in d["evidence"]:
			L.append("  · " + String(e))
		if String(d["advice"]) != "":
			L.append("  что посмотреть: " + String(d["advice"]))
		L.append("")
	return "\n".join(L)


## Сколько предложений каждой важности.
static func counts(items: Array) -> Dictionary:
	var c := {}
	for s in SEVERITIES:
		c[s] = 0
	for it in items:
		var s := String((it as Dictionary)["severity"])
		c[s] = int(c.get(s, 0)) + 1
	return c
