class_name BotScenarioCardinalStory
extends BotScenario
## Режим «Кардинал: прохождение острова» (CardinalStory): свежий Бродяга проходит все задания острова и жителей как
## игрок, крафтит, закаляет, приручает, снаряжает питомца, вставляет его в пояс. Сначала (det) — короткий отрезок
## (первые задания старосты) дважды с одного начала и seed: ×accel и ×accel·2 — совпадают ли решения и итог; потом
## полный прогон первой расы из races и, если задано, прогоны других рас до выбора профессии. Итог — раздел отчёта
## (по каждому заданию: взято / сдано / застряло и почему, время, уровень, сверка наград; фичи; помощь; находки) и
## cardinal_story.json в папке запуска. Ускорение — accel (вкладка «Тест-бот»: ×8 / ×16 / ×32).

## Ускорение прогонов (вкладка «Тест-бот», кнопки bot_accel_<N>), seed, лимит игрового времени полного прогона.
static var accel := 8.0
static var seed_value := 20261105
static var game_limit := 6.0 * 3600.0
## Расы: [раса, только до профессии]. Первая — полный прогон.
static var races: Array = [["human", false]]
## Отрезок детерминизма: прогон ×accel и ×accel·2 до сдачи этих заданий ([] — без проверки).
static var det_quests: Array = ["elder_hunt", "elder_trophies"]
## Лимит настоящего времени одного прогона, с.
static var wall_limit := 1800.0
## Поправки профиля CardinalStory.PROFILE_STORY (тест — быстрый прогон: больше опыта, бег ×2; каждая — помощь в отчёте).
static var profile_over: Dictionary = {}
const ACCEL_CHOICES := [8, 16, 32]

var runs: Array[CardinalStory] = []
var det_runs: Array[CardinalStory] = []
var _det := {}
var _last := {}


func id() -> String:
	return "cardinal_story"


func title() -> String:
	return "Кардинал: прохождение острова"


func hero() -> Dictionary:
	return {"race": String((races[0] as Array)[0]) if not races.is_empty() else "human", "job": ClassData.WANDERER,
		"gender": "m", "level": 1}


func build(bot: TestBot) -> void:
	if not det_quests.is_empty():
		_queue(bot, "det_a", "Отрезок ×%.0f" % accel, "human", false, accel, det_quests, det_runs)
		_queue(bot, "det_b", "Отрезок ×%.0f" % (accel * 2.0), "human", false, accel * 2.0, det_quests, det_runs)
		bot.do("Кардинал: детерминизм ×%.0f / ×%.0f" % [accel, accel * 2.0], func() -> void: _compare_det(bot))
	for i in races.size():
		var r: Array = races[i]
		var race := String(r[0])
		var short := bool(r[1])
		var t := "%s%s" % [String(ClassData.race(race).get("name", race)), " — до профессии" if short else ""]
		_queue(bot, "story_" + race, t, race, short, accel, [], runs)
	bot.do("Кардинал: итог прохождения", func() -> void: _summary(bot))


func _queue(bot: TestBot, run_id: String, run_title: String, race: String, short: bool, k: float, stop: Array,
		into: Array[CardinalStory]) -> void:
	var r := CardinalStory.new()
	r.bot = bot
	r.run_name = run_id
	r.title = run_title
	r.race = race
	r.until_job = short
	r.accel = k
	r.seed_value = seed_value
	r.stop_after = stop
	r.game_limit = game_limit if stop.is_empty() else 1200.0
	r.wall_limit = wall_limit
	var pr: Dictionary = CardinalStory.PROFILE_STORY.duplicate()
	pr.merge(profile_over, true)
	r.profile = pr
	into.append(r)
	bot.do("Кардинал: прогон «%s»" % run_title, r.begin)
	bot.wait_until("Кардинал: прогон «%s» закончен" % run_title, func() -> bool: return r.done, r.game_limit + 600.0)


## Щадящий режим TestBot: ускорение прогонов — не выше GENTLE_ACCEL (идущий и следующие).
const GENTLE_ACCEL := 8.0


func on_hot(_bot: TestBot) -> String:
	var was := Engine.time_scale
	for r in runs + det_runs:
		r.accel = minf(r.accel, GENTLE_ACCEL)
	var k := CardinalMove.ease_off(GENTLE_ACCEL)
	return "ускорение Кардинала ×%.0f → ×%.0f" % [was, k] if k > 0.0 else "ускорение Кардинала не выше ×%.0f" % GENTLE_ACCEL


func on_finish(_bot: TestBot) -> void:
	for r in det_runs + runs:
		if not r.done:
			r.abort("бот остановлен")


## Детерминизм ×N / ×2N: одинаковые события (взял, сдал, профессия), уровень и опыт, золото, убийства.
func _compare_det(bot: TestBot) -> void:
	if det_runs.size() < 2:
		return
	var a := det_runs[0].result()
	var b := det_runs[1].result()
	var ea := _key_events(a)
	var eb := _key_events(b)
	var same := ea == eb
	var fa: Dictionary = a["finish"]
	var fb: Dictionary = b["finish"]
	# Итог: те же сданные задания и уровень. Опыт, золото и убийства — для сведения: побитово два прогона в одной игре
	# не совпадут (физика героя расходится в 9-м знаке уже на первых шагах — в пространстве другие тела зверей и
	# питомцев после возрождения; дальше это растёт), см. отчёт
	var final_same := int(fa.get("level", 0)) == int(fb.get("level", 0)) and int(fa.get("done", 0)) == int(fb.get("done", 0))
	var first := ""
	for i in mini(ea.size(), eb.size()):
		if ea[i] != eb[i]:
			first = "%s против %s" % [ea[i], eb[i]]
			break
	if first == "" and ea.size() != eb.size():
		first = "событий %d против %d" % [ea.size(), eb.size()]
	_det = {"accel_a": det_runs[0].accel, "accel_b": det_runs[1].accel, "events_same": same, "final_same": final_same,
		"first_diff": first, "a": {"game": a["game_sec"], "wall": a["wall_sec"], "speedup": a["speedup"], "kills": a["kills"],
		"finish": fa, "stop": a["stop"]}, "b": {"game": b["game_sec"], "wall": b["wall_sec"], "speedup": b["speedup"],
		"kills": b["kills"], "finish": fb, "stop": b["stop"]}}
	var txt := "Кардинал: ×%.0f и ×%.0f — решения %s, итог %s (опыт %d / %d, золото %d / %d, убийств %d / %d)%s" % [
		det_runs[0].accel, det_runs[1].accel, "совпали" if same else "разошлись", "тот же" if final_same else "разный",
		int(fa.get("cum_xp", 0)), int(fb.get("cum_xp", 0)), int(fa.get("gold", 0)), int(fb.get("gold", 0)), int(a["kills"]),
		int(b["kills"]), "" if first == "" else "; первое расхождение — " + first]
	bot.check(String(a["stop"]) == "отрезок пройден" and String(b["stop"]) == "отрезок пройден",
		"Кардинал: отрезок детерминизма пройден обоими прогонами (%s / %s)" % [a["stop"], b["stop"]])
	if DisplayServer.get_name() == "headless":
		bot.check(same and final_same, txt)
	else:
		bot.note(txt)


## События, по которым сравниваются прогоны: взял, сдал, профессия (по порядку).
static func _key_events(r: Dictionary) -> Array:
	var res: Array = []
	for e in r.get("events", []):
		var ed: Dictionary = e
		if ["take", "done", "job"].has(String(ed["kind"])):
			res.append("%s:%s" % [ed["kind"], ed["text"]])
	return res


func _summary(bot: TestBot) -> void:
	var out: Array = []
	for r in runs:
		var d := r.result()
		out.append(d)
		var short := r.until_job
		if short:
			bot.check(not ClassData.is_wanderer(String((d["finish"] as Dictionary).get("job", ClassData.WANDERER))),
				"Кардинал «%s»: профессия выбрана (%s; сдано %d)" % [d["title"], d["stop"], int(d["quests_done"])])
		else:
			bot.check(int(d["quests_done"]) == int(d["quests_total"]), "Кардинал «%s»: пройдено %d из %d заданий (%s)" % [
				d["title"], int(d["quests_done"]), int(d["quests_total"]), d["stop"]])
		var bad_rewards := PackedStringArray()
		for k in d["quests"]:
			var q: Dictionary = d["quests"][k]
			if q.get("reward_ok") == false:
				bad_rewards.append(String(q["name"]))
		bot.check(bad_rewards.is_empty(), "Кардинал «%s»: награды сходятся%s" % [d["title"],
			"" if bad_rewards.is_empty() else ": не сходятся — " + ", ".join(bad_rewards)])
		for fk in d["features"]:
			var f: Dictionary = d["features"][fk]
			if f["ok"] == false:
				bot.check(false, "Кардинал «%s»: %s — %s" % [d["title"], fk, f["text"]])
	_last = {"version": 1, "game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"scenario": id(), "seed": seed_value, "accel": accel, "profile": CardinalStory.PROFILE_STORY, "profile_over": profile_over,
		"determinism": _det, "runs": out}
	var dir := bot.run_dir if bot.run_dir != "" else bot.report_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var f2 := FileAccess.open(dir.path_join("cardinal_story.json"), FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(_last, "\t"))
		f2.close()


func last_data() -> Dictionary:
	return _last


func summary(_bot: TestBot) -> String:
	if runs.is_empty():
		return ""
	var parts := PackedStringArray()
	for r in runs:
		var d := r.result()
		parts.append("%s — пройдено %d из %d (%s)" % [d["title"], int(d["quests_done"]), int(d["quests_total"]), d["stop"]])
	return "Кардинал: " + "; ".join(parts)


const STATUS_NAMES := {"done": "сдано", "active": "взято, не сдано", "not_taken": "не взято", "stuck": "застряло"}
const SPLIT_NAMES := {"walk": "путь", "fight": "бой", "loot": "добыча", "rest": "отдых", "npc": "жители", "ui": "окна",
	"wait": "ожидание", "pause": "паузы"}
const FEATURE_NAMES := {"job": "Выбор профессии", "dungeon": "Подземелье", "bag": "Торба", "storage": "Склад", "temper": "Закалка",
	"craft": "Крафт кубом", "craft_powder": "Крафт с порошком", "tame": "Приручение", "form": "Формирование",
	"pet_gear": "Снаряжение питомцу (оружие)", "pet_armor": "Снаряжение питомцу (доспех)", "evolve": "Эволюция у Кирка",
	"belt": "Пояс: карта питомца", "belt_expand": "Расширитель пояса",
	"chapter1": "Глава I «Шёпот из глубин» (подземелье)"}


func report_lines(_bot: TestBot) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Кардинал — прохождение острова")
	var pr: Dictionary = CardinalStory.PROFILE_STORY.duplicate()
	pr.merge(profile_over, true)
	out.append("  Профиль «%s» v%d: опыт ×%d, бессмертие на боссах — %s, перенос, если застрял дольше %.0f с; звери спят дальше %.0f м (упрощение симуляции); ускорение ×%.0f + перемотка отдыха ×%.0f; seed %d" % [
		String(pr["name"]), int(pr["version"]), int(pr["xp_mult"]), "да" if bool(pr["god_bosses"]) else "нет",
		float(pr["stuck_teleport"]), float(pr["sim_radius"]), accel, CardinalStory.REST_BOOST, seed_value])
	if not profile_over.is_empty():
		out.append("  Поправки профиля (быстрый прогон): %s" % str(profile_over))
	if not _det.is_empty():
		var a: Dictionary = _det["a"]
		var b: Dictionary = _det["b"]
		var fa: Dictionary = a["finish"]
		var fb: Dictionary = b["finish"]
		out.append("  Детерминизм (первые задания старосты): ×%.0f и ×%.0f — решения (взял / сдал по порядку) %s, итог (сданные задания, уровень) %s%s" % [float(_det["accel_a"]),
			float(_det["accel_b"]), "совпали" if bool(_det["events_same"]) else "разошлись", "тот же" if bool(_det["final_same"]) else "разный",
			"" if String(_det["first_diff"]) == "" else "; первое расхождение — " + String(_det["first_diff"])])
		var exact := int(fa.get("cum_xp", 0)) == int(fb.get("cum_xp", 0)) and int(fa.get("gold", 0)) == int(fb.get("gold", 0))
		out.append("    опыт %d / %d, золото %d / %d, убийств %d / %d, игровое время %s / %s%s" % [
			int(fa.get("cum_xp", 0)), int(fb.get("cum_xp", 0)), int(fa.get("gold", 0)), int(fb.get("gold", 0)), int(a["kills"]), int(b["kills"]),
			TestBot.clock(float(a["game"])), TestBot.clock(float(b["game"])), " — совпали до единицы" if exact else
			" — разошлись: физика героя у двух прогонов в одной игре расходится в 9-м знаке (в пространстве другие тела возрождённых зверей), дальше растёт"])
		out.append("    ×%.0f: игровое %s, настоящее %s — скорость ×%.2f; ×%.0f: игровое %s, настоящее %s — ×%.2f" % [
			float(_det["accel_a"]), TestBot.clock(float(a["game"])), TestBot.clock(float(a["wall"])), float(a["speedup"]),
			float(_det["accel_b"]), TestBot.clock(float(b["game"])), TestBot.clock(float(b["wall"])), float(b["speedup"])])
	for r in runs:
		var d := r.result()
		out.append("  %s (%s → %s): %s" % [d["title"], ClassData.job_name(ClassData.WANDERER), ClassData.job_name(String(d["job"])),
			"не закончен" if not r.done else String(d["stop"])])
		var f: Dictionary = d["finish"]
		out.append("    Пройдено заданий: %d из %d · игровое %s, настоящее %s (×%.2f) · уровень %d → %d, золото %d → %d, питомцев %d (старший — %d ур., %d форма), ячеек сумки %d" % [
			int(d["quests_done"]), int(d["quests_total"]), TestBot.clock(float(d["game_sec"])), TestBot.clock(float(d["wall_sec"])),
			float(d["speedup"]), int((d["start"] as Dictionary).get("level", 1)), int(f.get("level", 0)),
			int((d["start"] as Dictionary).get("gold", 0)), int(f.get("gold", 0)), int(f.get("pets", 0)), int(f.get("pet_level", 0)),
			int(f.get("pet_form", 0)), int(f.get("bag", 0))])
		var ts: Dictionary = d["time_split"]
		var tparts := PackedStringArray()
		for k in ts:
			tparts.append("%s %s" % [String(SPLIT_NAMES.get(k, k)), TestBot.clock(float(ts[k]))])
		out.append("    Время: " + ", ".join(tparts) + " (перемотка отдыха — %s)" % TestBot.clock(float(d["rest_boost_game"])))
		out.append("    Убийств %d, смертей %d" % [int(d["kills"]), int(d["deaths"])])
		var cost: Dictionary = d.get("cost", {})
		var nav: Dictionary = d.get("nav", {})
		out.append("    Нагрузка: тиков физики %d, %.2f мс на тик (из них код Кардинала %.3f мс); сетка пути — %d мс, клеток под оградами, стенами и деревьями %d" % [
			int(cost.get("ticks", 0)), float(cost.get("ms_per_tick", 0.0)), float(cost.get("cardinal_ms_per_tick", 0.0)),
			int(nav.get("build_ms", 0)), int(nav.get("blocked_cells", 0))])
		# Помощь
		var hp := PackedStringArray()
		for k in d["help"]:
			hp.append("%s ×%d" % [String({"god": "бессмертие", "teleport": "перенос", "xp_pet": "опыт ×N после заданий (питомец)", "speed": "бег ×N", "dungeon": "подземелье: HP монстра ×N и бессмертие"}.get(k, k)), int((d["help"][k] as Dictionary)["n"])])
		out.append("    Помощь (послабления): " + (", ".join(hp) if not hp.is_empty() else "нет") + "; опыт ×%d всё время" % int(d["xp_mult"]))
		for k in d["help"]:
			for w in (d["help"][k] as Dictionary)["where"]:
				out.append("      · " + String(w))
		# Фичи
		out.append("    Как игрок:")
		for fk in d["features"]:
			var fe: Dictionary = d["features"][fk]
			var st := "ок" if fe["ok"] == true else ("ОШИБКА" if fe["ok"] == false else "—")
			out.append("      %s [%s] ×%d: %s" % [String(FEATURE_NAMES.get(fk, fk)), st, int(fe["n"]), String(fe["text"])])
		for fk in FEATURE_NAMES:
			if not (d["features"] as Dictionary).has(fk) and not r.until_job:
				var why := "условия не сложились"
				match String(fk):
					"evolve":
						why = "питомец не дорос до %d ур. (старший — %d ур.)" % [int(PetData.EVOLVE_LEVELS[0]), int(f.get("pet_level", 0))]
					"belt", "belt_expand":
						why = "«Способность карты» — с 40 ур. питомца (старший — %d ур.)" % int(f.get("pet_level", 0))
				out.append("      %s: не проверено — %s" % [String(FEATURE_NAMES[fk]), why])
		# Задания
		out.append("    Задания (взято → сдано, уровень на сдаче, награда):")
		for k in d["quests"]:
			var q: Dictionary = d["quests"][k]
			var line := "      %-28s %s" % [String(q["name"]).left(28), String(STATUS_NAMES.get(String(q["status"]), q["status"]))]
			if String(q["status"]) == "done":
				line += " %s → %s, %d ур.: %s" % [TestBot.clock(float(q["taken"])) if float(q["taken"]) >= 0.0 else "—",
					TestBot.clock(float(q["done"])), int(q["level_done"]), String(q["reward"])]
			elif String(q["reason"]) != "":
				line += " — " + String(q["reason"])
			out.append(line)
		if not (d["findings"] as PackedStringArray).is_empty():
			out.append("    Находки (что мешает пройти или не сходится):")
			for fnd in d["findings"]:
				out.append("      ! " + String(fnd))
	out.append("  Воспроизвести: режим «Кардинал: прохождение острова», seed %d, ускорение ×%.0f." % [seed_value, accel])
	return out
