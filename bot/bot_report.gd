class_name BotReport
extends RefCounted
## Отчёт тест-бота (TestBot): текст DarkPact_test_<версия>_<ГГГГ-ММ-ДД_ЧЧ-ММ>.txt (версия — application/config/version
## сборки, на ПК и в редакторе — «dev») и архив .zip с тем же именем (отчёт + папка shots/ со снимками JPG) — одним
## файлом удобнее пересылать. Пишутся в TestBot.report_dir (user://bot_reports/), снимки — в его подпапку запуска.
## Android: копии .zip и .txt — в общую папку «Загрузки/DarkPact_test» (плагин MyRappelzDownload.saveToDownloads:
## Android 10+ — MediaStore без разрешений; 9 и ниже — внешняя папка приложения, путь — в сообщении), «Открыть отчёт»
## и «Поделиться» — openFile / share плагина. ПК: файлы в user://bot_reports, кнопки открывают файл и папку.
##
## Текст: сводка по-русски (режим, итог, версия, дата, длительность, паузы на остывание, устройство — модель, Android,
## процессор, видеочип, API, рендерер, экран, память, пакет ресурсов, температура в начале и в конце), пресеты в
## среднем по сценам, таблица замеров (сцена × настройка: предел кадров, к/с среднее и худшей секунды, кадр мс
## среднее/p95/p99/макс, заминки, время видеочипа, вызовы, треугольники, объекты, скрипты, температура до→после),
## настройки по одной против базы «Среднее», рекомендации (простые правила — recommendations), раздел сценария
## (BotScenario.report_lines), журнал, проверки, хвост лога Godot (user://logs/godot.log с отметки старта бота;
## файловый лог включён и на телефоне — project.godot debug/file_logging/enable_file_logging).

const TITLE := "Dark Pact — отчёт тест-бота"
const LOG_FILE := "user://logs/godot.log"
const LOG_LINES := 150
const ZIP_MIME := "application/zip"
const TXT_MIME := "text/plain"
const KIND_TEXT := {"done": "готово", "limit": "остановлен по лимиту времени", "stopped": "остановлен вручную",
	"hot": "остановлен: телефон перегрелся", "error": "остановлен из-за ошибки"}
## Транслитерация для имён снимков (латиница в архиве читается везде).
const TRANSLIT := {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z",
	"и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
	"у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e",
	"ю": "yu", "я": "ya"}


# ---------- Имена, устройство, плагин ----------

## Версия игры для имени отчёта: сборка — application/config/version, иначе «dev».
static func version() -> String:
	var v := Assets.game_version()
	return v if v != "" else "dev"


## Имя отчёта без расширения: DarkPact_test_<версия>_<ГГГГ-ММ-ДД_ЧЧ-ММ>.
static func file_base(now: Dictionary) -> String:
	return "DarkPact_test_%s_%04d-%02d-%02d_%02d-%02d" % [version(), int(now["year"]), int(now["month"]), int(now["day"]),
		int(now["hour"]), int(now["minute"])]


## Латиница, цифры и «_» из текста (имя файла снимка), не длиннее 48 символов.
static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		var c := String(ch)
		if TRANSLIT.has(c):
			out += String(TRANSLIT[c])
		elif (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif not out.ends_with("_"):
			out += "_"
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	if out.length() > 48:
		out = out.substr(0, 48)
	return out if out != "" else "shot"


static func headroom_text(h: int) -> String:
	return "%.2f" % (float(h) / 1000.0) if h >= 0 else "—"


## Метод плагина MyRappelzDownload (Assets.download_plugin; тест — Assets.plugin_override). null — нет плагина или
## метода (у старого AAR методов отчёта нет: JNISingleton ответит null).
static func plugin_call(method: String, args: Array) -> Variant:
	var p := Assets.download_plugin()
	if p == null:
		return null
	if not p.has_method(method) and p.get_class() != "JNISingleton":
		return null
	return p.callv(method, args)


## Устройство: model, os, cpu, cores, gpu, vendor, api, driver, renderer, screen, window, memory, pack, plugin.
static func device_info() -> Dictionary:
	var d := {}
	var pinfo: Variant = plugin_call("deviceInfo", [])
	var model := OS.get_model_name()
	var os_text := "%s %s" % [OS.get_name(), OS.get_version()]
	if pinfo is Dictionary:
		var info: Dictionary = pinfo
		model = ("%s %s" % [String(info.get("manufacturer", "")), String(info.get("model", ""))]).strip_edges()
		os_text = "Android %s (API %d)" % [String(info.get("release", "?")), int(info.get("sdk", 0))]
		if String(info.get("soc", "")) != "":
			d["soc"] = String(info["soc"])
	d["model"] = model
	d["os"] = os_text
	d["cpu"] = "%s, ядер %d" % [OS.get_processor_name(), OS.get_processor_count()]
	d["gpu"] = "%s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()]
	d["api"] = RenderingServer.get_video_adapter_api_version()
	var drv := OS.get_video_adapter_driver_info()
	d["driver"] = " ".join(drv) if not drv.is_empty() else "—"
	d["renderer"] = renderer_text()
	var tree := Engine.get_main_loop() as SceneTree
	var win := Vector2i.ZERO
	var scale3d := 1.0
	if tree != null and tree.root != null:
		win = tree.root.size
		scale3d = tree.root.scaling_3d_scale
	var scr := DisplayServer.screen_get_size()
	d["screen"] = "экран %d×%d, окно %d×%d, 3D ×%.2f" % [scr.x, scr.y, win.x, win.y, scale3d]
	var mem := "статическая %.0f МБ" % (float(OS.get_static_memory_usage()) / 1048576.0)
	if OS.has_method("get_memory_info"):
		var mi: Variant = OS.call("get_memory_info")
		if mi is Dictionary:
			var m: Dictionary = mi
			mem += ", всего %.1f ГБ, доступно %.1f ГБ" % [float(m.get("physical", 0)) / 1073741824.0,
				float(m.get("available", 0)) / 1073741824.0]
	d["memory"] = mem
	if Assets.embedded():
		d["pack"] = "встроен (редактор, автотесты)"
	elif Assets.available():
		d["pack"] = "загружен полностью"
	else:
		d["pack"] = "частей %d из %d — у остальных моделей запасные" % [Assets.ready_count(), Assets.PACKS.size()]
	d["plugin"] = "есть" if Assets.download_plugin() != null else "нет (ПК или APK без плагина)"
	return d


## Рендерер: метод (gl_compatibility / mobile / forward_plus) и чем рисует (OpenGL или Vulkan).
static func renderer_text() -> String:
	var method := String(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method"))
	if RenderingServer.has_method("get_current_rendering_method"):
		method = String(RenderingServer.call("get_current_rendering_method"))
	var driver := ""
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		driver = String(RenderingServer.call("get_current_rendering_driver_name"))
	if driver == "":
		driver = "Vulkan (RenderingDevice)" if RenderingServer.get_rendering_device() != null else "OpenGL"
	return "%s, %s" % [method, driver]


# ---------- Запись и отправка ----------

## Записать отчёт бота: .txt и .zip в report_dir, на Android — копии в «Загрузки/DarkPact_test». Итог для вкладки и
## LAST_FILE: kind, text, time, txt, zip, public, uri, message, rows.
static func export(bot: TestBot) -> Dictionary:
	var txt_path := bot.report_dir + bot.base_name + ".txt"
	var zip_path := bot.report_dir + bot.base_name + ".zip"
	var text := build_text(bot)
	var res := {"kind": bot.result_kind, "text": String(KIND_TEXT.get(bot.result_kind, bot.result_kind)),
		"reason": bot.stop_reason, "time": bot.started_text, "txt": txt_path, "zip": zip_path, "public": "", "uri": "",
		"rows": bot.rows.size(), "message": ""}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bot.report_dir))
	var f := FileAccess.open(txt_path, FileAccess.WRITE)
	if f == null:
		res["message"] = "Не удалось записать отчёт (%s)" % txt_path
		return res
	f.store_string(text)
	f.close()
	var entries: Array = [[bot.base_name + ".txt", txt_path]]
	for s in bot.shots:
		entries.append(["shots/" + String(s), bot.run_dir + "shots/" + String(s)])
	if not make_zip(zip_path, entries):
		res["zip"] = ""
	# Общая папка «Загрузки» (Android, плагин)
	var pub := publish(String(res["zip"]) if String(res["zip"]) != "" else txt_path,
		ZIP_MIME if String(res["zip"]) != "" else TXT_MIME)
	if String(res["zip"]) != "":
		publish(txt_path, TXT_MIME)
	if bool(pub["ok"]):
		res["public"] = String(pub["public"])
		res["uri"] = String(pub["where"])
		res["message"] = "Отчёт сохранён: %s" % String(pub["public"])
	elif Assets.download_plugin() != null:
		var err: Variant = plugin_call("lastError", [])
		res["message"] = "В «Загрузки» сохранить не удалось (%s) — отчёт во внутренней памяти игры" % [
			String(err) if err is String else "?"]
	else:
		res["message"] = "Отчёт: %s" % ProjectSettings.globalize_path(String(res["zip"]) if String(res["zip"]) != ""
			else txt_path)
	return res


## Архив zip_path из entries [[имя в архиве, файл]]. false — не удалось.
static func make_zip(zip_path: String, entries: Array) -> bool:
	var z := ZIPPacker.new()
	if z.open(zip_path) != OK:
		return false
	for e in entries:
		var pair: Array = e
		var src := String(pair[1])
		if not FileAccess.file_exists(src):
			continue
		var bytes := FileAccess.get_file_as_bytes(src)
		if z.start_file(String(pair[0])) != OK:
			continue
		z.write_file(bytes)
		z.close_file()
	return z.close() == OK


## Копия файла path в «Загрузки/DarkPact_test» через плагин: {ok, where (content:// или путь), public (что показать)}.
static func publish(path: String, mime: String) -> Dictionary:
	var name := path.get_file()
	var v: Variant = plugin_call("saveToDownloads", [ProjectSettings.globalize_path(path), TestBot.PUBLIC_DIR, name, mime])
	if v is String and String(v) != "":
		var w := String(v)
		var shown := "Загрузки/DarkPact_test/" + name if w.begins_with("content://") else w
		return {"ok": true, "where": w, "public": shown}
	return {"ok": false, "where": "", "public": ""}


## «Открыть отчёт»: на Android — выбор приложения для .txt (плагин), на ПК — файл. Возвращает сообщение.
static func open_report(res: Dictionary) -> String:
	var txt := String(res.get("txt", ""))
	if txt == "" or not FileAccess.file_exists(txt):
		return "Отчёта ещё нет — запустите тест-бота"
	var v: Variant = plugin_call("openFile", [ProjectSettings.globalize_path(txt), TXT_MIME])
	if v is bool:
		return "Открываю отчёт" if bool(v) else "Не удалось открыть отчёт"
	if DisplayServer.get_name() != "headless":
		OS.shell_open(ProjectSettings.globalize_path(txt))
	return "Отчёт: " + ProjectSettings.globalize_path(txt)


## «Поделиться»: на Android — архив через «Поделиться» системы (плагин), на ПК — папка отчётов. Сообщение.
static func share_report(res: Dictionary) -> String:
	var file := String(res.get("zip", ""))
	if file == "" or not FileAccess.file_exists(file):
		file = String(res.get("txt", ""))
	if file == "" or not FileAccess.file_exists(file):
		return "Отчёта ещё нет — запустите тест-бота"
	var mime := ZIP_MIME if file.ends_with(".zip") else TXT_MIME
	var v: Variant = plugin_call("share", [ProjectSettings.globalize_path(file), mime, "Отчёт тест-бота Dark Pact"])
	if v is bool:
		return "Выберите, куда отправить отчёт" if bool(v) else "Не удалось поделиться отчётом"
	var dir := ProjectSettings.globalize_path(file.get_base_dir())
	if DisplayServer.get_name() != "headless":
		OS.shell_open(dir)
	return "Папка отчётов: " + dir


# ---------- Текст ----------

static func build_text(bot: TestBot) -> String:
	var L := PackedStringArray()
	L.append(TITLE)
	L.append("=".repeat(TITLE.length()))
	L.append("Режим: %s" % BotScenario.mode_name(bot.mode))
	var kind_text := String(KIND_TEXT.get(bot.result_kind, bot.result_kind))
	var reason := bot.stop_reason
	L.append("Итог: %s%s" % [kind_text, "" if reason == "" or reason.begins_with("готово") else " — " + reason])
	L.append("Замеров: %d из %d · проверок: %d, ошибок: %d" % [bot.rows.size(), bot.measures_total, bot.checks.size(),
		_errors(bot)])
	L.append("Версия игры: %s · дата: %s" % [version(), bot.started_text])
	L.append("Длительность: %s (сценарий %s, загрузка мира и паузы — остальное)" % [TestBot.clock(bot.total_time),
		TestBot.clock(bot.active_time)])
	if bot.pauses.is_empty():
		L.append("Пауз на остывание: нет")
	else:
		L.append("Пауз на остывание: %d, всего %s" % [bot.pauses.size(), TestBot.clock(bot.cool_time)])
		for p in bot.pauses:
			var pd: Dictionary = p
			L.append("  - на %s сценария, шаг «%s»: %s — %s" % [TestBot.clock(float(pd["at"])), String(pd["step"]),
				String(pd["reason"]), TestBot.clock(float(pd["sec"]))])
	L.append("Графика игрока до теста: %s (после теста — вернулась)" % bot.player_quality)
	L.append("")
	L.append("Устройство")
	var d := bot.device
	L.append("  Модель: %s · %s" % [String(d.get("model", "?")), String(d.get("os", "?"))])
	L.append("  Процессор: %s%s" % [String(d.get("cpu", "?")), " · чип " + String(d["soc"]) if d.has("soc") else ""])
	L.append("  Видеочип: %s · API %s" % [String(d.get("gpu", "?")), String(d.get("api", "?"))])
	L.append("  Драйвер: %s" % String(d.get("driver", "—")))
	L.append("  Рендерер: %s" % String(d.get("renderer", "?")))
	L.append("  Экран: %s" % String(d.get("screen", "?")))
	L.append("  Память: %s" % String(d.get("memory", "?")))
	L.append("  Пакет ресурсов: %s · плагин Android: %s" % [String(d.get("pack", "?")), String(d.get("plugin", "?"))])
	L.append("  Температура в начале: %s" % temps_text(bot.temp_start))
	L.append("  Температура в конце: %s" % temps_text(bot.temp_end))
	L.append("")
	_presets_block(bot, L)
	_rows_block(bot, L)
	_settings_block(bot, L)
	L.append("Рекомендации")
	for r in recommendations(bot):
		L.append("  - " + r)
	L.append("")
	var extra := bot.scenario.report_lines(bot) if bot.scenario != null else PackedStringArray()
	if not extra.is_empty():
		L.append_array(extra)
		L.append("")
	L.append("Журнал")
	L.append_array(bot.journal)
	L.append("")
	L.append("Проверки: %d, ошибок %d" % [bot.checks.size(), _errors(bot)])
	for c in bot.checks:
		var cd: Dictionary = c
		L.append("  [%s] %s" % ["OK" if bool(cd["ok"]) else "ОШИБКА", String(cd["text"])])
	L.append("")
	var lt := log_tail(bot.log_mark, LOG_LINES)
	L.append("Лог Godot (%s): ошибок %d, предупреждений %d" % [String(lt["from"]), int(lt["errors"]), int(lt["warnings"])])
	var tail: PackedStringArray = lt["lines"]
	L.append_array(tail)
	L.append("")
	return "\n".join(L)


static func _errors(bot: TestBot) -> int:
	var n := 0
	for c in bot.checks:
		if not bool((c as Dictionary)["ok"]):
			n += 1
	return n


## «статус 0 (нет нагрева), запас 0.41, батарея 31.2 °C».
static func temps_text(t: Dictionary) -> String:
	if t.is_empty():
		return "—"
	var st := int(t.get("status", -1))
	var b := float(t.get("battery", -1.0))
	return "статус %s (%s), запас %s, батарея %s" % [str(st) if st >= 0 else "—", TestBot.status_name(st),
		headroom_text(int(t.get("headroom", -1))), "%.1f °C" % b if b > 0.0 else "—"]


## Число треугольников: 1.28 млн / 267 тыс. / 950.
static func num(v: float) -> String:
	if v >= 1000000.0:
		return "%.2f млн" % (v / 1000000.0)
	if v >= 10000.0:
		return "%d тыс." % roundi(v / 1000.0)
	return str(roundi(v))


static func _ms(v: float) -> String:
	return "%.1f" % v if v > 0.0 else "—"


static func _temp_pair(r: Dictionary) -> String:
	var a: Dictionary = r.get("t0", {})
	var b: Dictionary = r.get("t1", {})
	var s0 := int(a.get("status", -1))
	var s1 := int(b.get("status", -1))
	var st := "%s→%s" % [str(s0) if s0 >= 0 else "—", str(s1) if s1 >= 0 else "—"]
	var hd := "%s→%s" % [headroom_text(int(a.get("headroom", -1))), headroom_text(int(b.get("headroom", -1)))]
	var b0 := float(a.get("battery", -1.0))
	var b1 := float(b.get("battery", -1.0))
	var bt := "%.1f→%.1f" % [b0, b1] if b0 > 0.0 and b1 > 0.0 else "—"
	return "%-7s %-11s %s" % [st, hd, bt]


static func _rows_of(bot: TestBot, kind: String) -> Array:
	var out: Array = []
	for r in bot.rows:
		if String((r as Dictionary).get("kind", "")) == kind:
			out.append(r)
	return out


## Пресеты в среднем по сценам.
static func _presets_block(bot: TestBot, L: PackedStringArray) -> void:
	var rows := _rows_of(bot, "preset")
	if rows.is_empty():
		return
	L.append("Пресеты (среднее по сценам)")
	L.append("  %-14s %6s %8s %8s %8s %8s %11s" % ["Пресет", "Предел", "к/с ср", "к/с мин", "кадр мс", "вызовы", "треуг."])
	for pn in Quality.NAMES:
		var acc := {"n": 0, "fps": 0.0, "min": 1.0e9, "ms": 0.0, "draw": 0.0, "prim": 0.0, "cap": 0}
		for r in rows:
			var rd: Dictionary = r
			if String(rd["setting"]) != String(pn):
				continue
			var m: Dictionary = rd["m"]
			acc["n"] = int(acc["n"]) + 1
			acc["fps"] = float(acc["fps"]) + float(m["fps"])
			acc["min"] = minf(float(acc["min"]), float(m["fps_min"]))
			acc["ms"] = float(acc["ms"]) + float(m["ms"])
			acc["draw"] = float(acc["draw"]) + float(m["draw"])
			acc["prim"] = float(acc["prim"]) + float(m["prim"])
			acc["cap"] = int(rd["cap"])
		var n := int(acc["n"])
		if n == 0:
			continue
		L.append("  %-14s %6d %8.1f %8.1f %8.1f %8d %11s" % [String(pn), int(acc["cap"]), float(acc["fps"]) / n,
			float(acc["min"]), float(acc["ms"]) / n, roundi(float(acc["draw"]) / n), num(float(acc["prim"]) / n)])
	L.append("")


## Таблица всех замеров.
static func _rows_block(bot: TestBot, L: PackedStringArray) -> void:
	L.append("Замеры (прогрев %.0f с, затем замер; кадр — настоящее время между кадрами, ГП — время видеочипа, если "
		% bot.warmup + "драйвер его отдаёт; t°: статус до→после, запас до→после, батарея °C до→после)")
	L.append(" %2s  %-15s %-24s %6s %7s %7s %7s %6s %6s %6s %5s %6s %7s %10s %7s %6s  %s" % ["#", "Сцена", "Настройка",
		"Предел", "к/с ср", "к/с мин", "кадр", "p95", "p99", "макс", "зам.", "ГП мс", "вызовы", "треуг.", "объекты",
		"скр.мс", "t°: статус  запас        батарея"])
	var i := 0
	for r in bot.rows:
		i += 1
		var rd: Dictionary = r
		var m: Dictionary = rd["m"]
		var setting := String(rd["setting"])
		if int(rd.get("retry", 0)) > 0:
			setting += " (повтор)"
		L.append(" %2d  %-15s %-24s %6d %7.1f %7.1f %7.1f %6.1f %6.1f %6.1f %5d %6s %7d %10s %7d %6.1f  %s" % [i,
			String(rd["scene"]).left(15), setting.left(24), int(rd["cap"]), float(m["fps"]), float(m["fps_min"]),
			float(m["ms"]), float(m["p95"]), float(m["p99"]), float(m["max"]), int(m["hitches"]), _ms(float(m["gpu"])),
			roundi(float(m["draw"])), num(float(m["prim"])), roundi(float(m["obj"])), float(m["proc"]), _temp_pair(rd)])
	if bot.rows.is_empty():
		L.append("  (замеров нет)")
	var vm := 0.0
	var mm := 0.0
	for r in bot.rows:
		var m: Dictionary = (r as Dictionary)["m"]
		vm = maxf(vm, float(m["vmem"]))
		mm = maxf(mm, float(m["mem"]))
	if not bot.rows.is_empty():
		L.append("  Память: наибольшая статическая %.0f МБ, видеопамять %.0f МБ" % [mm, vm])
	if not bot.shots.is_empty():
		L.append("  Снимки: shots/ в архиве (%d)" % bot.shots.size())
	L.append("")


## База «Среднее» и настройки по одной.
static func _settings_block(bot: TestBot, L: PackedStringArray) -> void:
	var rows := _rows_of(bot, "setting")
	var base := _base_row(bot)
	if rows.is_empty() or base.is_empty():
		return
	var bm: Dictionary = base["m"]
	L.append("Настройки по одной на «Среднем» (сцена «%s»; разница с базой: + — тяжелее)" % String(base["scene"]))
	L.append("  %-26s %8s %8s %8s %9s %9s %10s" % ["Настройка", "к/с", "Δ кадр", "Δ p95", "Δ ГП мс", "Δ вызовы",
		"Δ треуг."])
	for r in rows:
		var rd: Dictionary = r
		if bool(rd.get("base", false)):
			continue
		var m: Dictionary = rd["m"]
		var gpu := "—"
		if float(m["gpu"]) > 0.0 and float(bm["gpu"]) > 0.0:
			gpu = "%+.1f" % (float(m["gpu"]) - float(bm["gpu"]))
		L.append("  %-26s %8.1f %+8.1f %+8.1f %9s %+8.0f%% %+9.0f%%" % [String(rd["setting"]).left(26), float(m["fps"]),
			float(m["ms"]) - float(bm["ms"]), float(m["p95"]) - float(bm["p95"]), gpu,
			_pct(float(m["draw"]), float(bm["draw"])), _pct(float(m["prim"]), float(bm["prim"]))])
	L.append("")


static func _base_row(bot: TestBot) -> Dictionary:
	for r in bot.rows:
		var rd: Dictionary = r
		if bool(rd.get("base", false)):
			return rd
	return {}


static func _pct(v: float, b: float) -> float:
	return (v / maxf(b, 0.001) - 1.0) * 100.0


## Цена замера для сравнения: время видеочипа, если есть у обоих, иначе p95 и среднее время кадра.
static func _cost(m: Dictionary, base: Dictionary) -> float:
	if float(m["gpu"]) > 0.0 and float(base["gpu"]) > 0.0:
		return float(m["gpu"]) - float(base["gpu"])
	return (float(m["ms"]) - float(base["ms"])) * 0.5 + (float(m["p95"]) - float(base["p95"])) * 0.5


## Нагрев за замер: рост запаса до троттлинга (‰), иначе рост температуры батареи (°C × 100); нет данных — NAN.
static func _heat(r: Dictionary) -> float:
	var a: Dictionary = r.get("t0", {})
	var b: Dictionary = r.get("t1", {})
	var h0 := int(a.get("headroom", -1))
	var h1 := int(b.get("headroom", -1))
	if h0 >= 0 and h1 >= 0:
		return float(h1 - h0)
	var b0 := float(a.get("battery", -1.0))
	var b1 := float(b.get("battery", -1.0))
	if b0 > 0.0 and b1 > 0.0:
		return (b1 - b0) * 100.0
	return NAN


## Рекомендации по простым правилам.
static func recommendations(bot: TestBot) -> PackedStringArray:
	var out := PackedStringArray()
	if bot.rows.is_empty():
		out.append("Замеров нет — рекомендаций нет.")
		return out
	# 1. Пресет: самый высокий, который держит свой предел кадров во всех сценах (≥ 90 %, p95 ≤ 1.5 бюджета)
	var presets := _rows_of(bot, "preset")
	if not presets.is_empty():
		var best := -1
		var tried := 0
		for li in Quality.PRESETS.size():
			var pn := String(Quality.NAMES[li])
			var all_ok := true
			var any := false
			for r in presets:
				var rd: Dictionary = r
				if String(rd["setting"]) != pn:
					continue
				any = true
				var m: Dictionary = rd["m"]
				var cap := float(maxi(int(rd["cap"]), 1))
				if float(m["fps"]) < cap * 0.9 or float(m["p95"]) > 1500.0 / cap:
					all_ok = false
			if any:
				tried += 1
				if all_ok:
					best = li
		if best >= 0:
			out.append("Рекомендуемый пресет: «%s» — держит свой предел кадров во всех сценах." % String(Quality.NAMES[best]))
		elif tried > 0:
			out.append("Ни один пресет не держит свой предел кадров во всех сценах — начните с «Низкого» и смотрите таблицу.")
		# Самая тяжёлая сцена на «Среднем»
		var worst: Dictionary = {}
		for r in presets:
			var rd: Dictionary = r
			if String(rd["setting"]) != String(Quality.NAMES[Quality.MEDIUM]):
				continue
			if worst.is_empty() or float((rd["m"] as Dictionary)["fps"]) < float((worst["m"] as Dictionary)["fps"]):
				worst = rd
		if not worst.is_empty():
			var wm: Dictionary = worst["m"]
			out.append("Тяжелее всего на «Среднем»: «%s» — %.1f к/с (худшая секунда %.1f), %d вызовов, %s треугольников."
				% [String(worst["scene"]), float(wm["fps"]), float(wm["fps_min"]), roundi(float(wm["draw"])),
				num(float(wm["prim"]))])
	# 2. Настройки по одной: что дороже всего и что больше всего экономит
	var base := _base_row(bot)
	if not base.is_empty():
		var bm: Dictionary = base["m"]
		var costs: Array = []
		for r in _rows_of(bot, "setting"):
			var rd: Dictionary = r
			if bool(rd.get("base", false)):
				continue
			var m: Dictionary = rd["m"]
			costs.append([_cost(m, bm), String(rd["setting"]), _pct(float(m["draw"]), float(bm["draw"])), rd])
		costs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var dear := PackedStringArray()
		for c in costs:
			var ca: Array = c
			if float(ca[0]) > 0.5 and dear.size() < 3:
				dear.append("%s (+%.1f мс, вызовов %+.0f %%)" % [String(ca[1]), float(ca[0]), float(ca[2])])
		if not dear.is_empty():
			out.append("Дороже всего по кадру: " + "; ".join(dear) + ".")
		var cheap := PackedStringArray()
		for k in range(costs.size() - 1, -1, -1):
			var ca: Array = costs[k]
			if float(ca[0]) < -0.5 and cheap.size() < 2:
				cheap.append("%s (%.1f мс)" % [String(ca[1]), float(ca[0])])
		if not cheap.is_empty():
			out.append("Больше всего экономит: " + "; ".join(cheap) + ".")
		if dear.is_empty() and cheap.is_empty():
			out.append("Настройки по одной почти не меняют время кадра (кадр упирается в предел %d к/с) — сравнивайте "
				% int(base["cap"]) + "вызовы и треугольники.")
	# 3. Нагрев
	var hot: Dictionary = {}
	var hot_v := -INF
	var have_heat := false
	for r in bot.rows:
		var rd: Dictionary = r
		var h := _heat(rd)
		if is_nan(h):
			continue
		have_heat = true
		if h > hot_v:
			hot_v = h
			hot = rd
	if not have_heat:
		out.append("Температура недоступна (нет плагина или Android ниже 10) — ориентир только по времени кадра.")
	elif not hot.is_empty() and hot_v > 0.0:
		out.append("Сильнее всего грело: «%s · %s» (запас до троттлинга / батарея росли быстрее всего)." % [
			String(hot["scene"]), String(hot["setting"])])
	if not bot.pauses.is_empty():
		out.append("Телефон уходил на остывание %d раз (первый — на шаге «%s») — для долгой игры выбирайте пресет ниже, "
			% [bot.pauses.size(), String((bot.pauses[0] as Dictionary)["step"])] + "чем в той сцене, и оставьте «Беречь от перегрева».")
	# 4. Заминки
	var hitchy := 0
	for r in bot.rows:
		if int(((r as Dictionary)["m"] as Dictionary)["hitches"]) > 0:
			hitchy += 1
	if hitchy > 0:
		out.append("Заминки (кадр дольше %d мс) в %d замерах — чаще всего после смены настроек (компиляция шейдеров) "
			% [int(BotMetrics.HITCH_MS), hitchy] + "или загрузки моделей.")
	if bot.result_kind == "hot":
		out.append("Тест остановлен перегревом: повторите на остывшем телефоне, без зарядки и чехла.")
	return out


# ---------- Лог Godot ----------

## Хвост лога Godot с отметки mark (нет отметки — конец файла): {lines, errors, warnings, from}.
static func log_tail(mark: String, max_lines: int) -> Dictionary:
	var res := {"lines": PackedStringArray(["  (файла лога нет — файловое логирование выключено)"]), "errors": 0,
		"warnings": 0, "from": "нет файла"}
	var path := LOG_FILE
	var lp := String(ProjectSettings.get_setting("debug/file_logging/log_path", ""))
	if lp != "":
		path = lp
	if not FileAccess.file_exists(path):
		return res
	var all := FileAccess.get_file_as_string(path).split("\n")
	var start := 0
	res["from"] = "последние строки"
	if mark != "":
		for i in range(all.size() - 1, -1, -1):
			if all[i].contains(mark):
				start = i
				res["from"] = "с начала теста"
				break
	var errors := 0
	var warnings := 0
	for i in range(start, all.size()):
		var line := all[i]
		if line.contains("ERROR"):
			errors += 1
		elif line.contains("WARNING"):
			warnings += 1
	res["errors"] = errors
	res["warnings"] = warnings
	var from_i := maxi(start, all.size() - max_lines)
	var lines := PackedStringArray()
	for i in range(from_i, all.size()):
		lines.append("  " + all[i])
	res["lines"] = lines
	return res
