class_name BotScenarioCardinal
extends BotScenario
## Кардинал, фаза 1 — первый вертикальный срез (CARDINAL_MASTER_INSTRUCTION.md §5, CARDINAL_ARCHITECTURE.md):
## тестовый герой (Бродяга-человек 1 ур., изолированное хранилище бота) фармит зверей у деревни людей профилем
## «Обычный игрок» (CardinalRun) — сначала с картинкой (×1), потом с того же начала ускоренно (×ACCEL, без 3D).
## Сравнение: точные инварианты (опыт за каждое убийство = формула игры, оба прогона без зависаний) — проверки;
## статистика (опыт/мин игрового времени, TTK, урон по герою, смерти) — с допусками, как расхождение, не ошибка.
## Баланс, код и сохранения игрока не меняются; итог — раздел отчёта и cardinal.json в папке запуска.

## Игровое время каждого прогона, с (тест ставит меньше), ускорение второго прогона, seed.
static var game_limit := 240.0
static var accel := 4.0
static var seed_value := 20261104

## Допуск статистики «ускоренный / с картинкой» (отношение; вне — расхождение в отчёте).
const RATIO_LO := 0.6
const RATIO_HI := 1.6

var runs: Array[CardinalRun] = []
var _start_state := {}


func id() -> String:
	return "cardinal"


func title() -> String:
	return "Кардинал: первый срез"


func hero() -> Dictionary:
	return {"race": "human", "job": ClassData.WANDERER, "gender": "m", "level": 1}


func build(bot: TestBot) -> void:
	bot.do("Кардинал: исходное состояние героя", func() -> void: _save_start(bot))
	_queue_run(bot, "visual", "С картинкой", 1.0)
	bot.do("Кардинал: герой и звери — в исходное состояние", func() -> void: _restore_start(bot))
	_queue_run(bot, "fast", "Ускоренный ×%.0f" % accel, accel)
	bot.do("Кардинал: сравнение прогонов", func() -> void: _compare(bot))


func _queue_run(bot: TestBot, run_id: String, run_title: String, k: float) -> void:
	var r := CardinalRun.new()
	r.bot = bot
	r.run_name = run_id
	r.title = run_title
	r.accel = k
	r.seed_value = seed_value
	r.game_limit = game_limit
	r.wall_limit = game_limit / k * 4.0 + 60.0
	runs.append(r)
	bot.do("Кардинал: прогон «%s»" % run_title, r.begin)
	bot.wait_until("Кардинал: прогон «%s» закончен" % run_title, func() -> bool: return r.done, game_limit + 120.0)


func _save_start(bot: TestBot) -> void:
	_start_state = {"level": Game.level, "xp": Game.xp, "gold": Game.gold, "bag": Game.inventory.to_dict()}
	var p := bot.player()
	if p != null and p.current_target != null:
		p.select_target(null)


func _restore_start(bot: TestBot) -> void:
	Game.level = int(_start_state["level"])
	Game.xp = int(_start_state["xp"])
	Game.gold = int(_start_state["gold"])
	Game.inventory.from_dict(_start_state["bag"])
	var p := bot.player()
	p.recalc_stats()
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.select_target(null)
	for n in bot.get_tree().get_nodes_in_group("loot_drops"):
		(n as Node).queue_free()
	AdminPanel.respawn_all(bot.main)
	bot.note("Кардинал: герой — %d ур., %d зол., звери возрождены" % [Game.level, Game.gold])


static func _ratio(a: float, b: float) -> float:
	return b / a if a > 0.0 else (1.0 if b <= 0.0 else INF)


func _compare(bot: TestBot) -> void:
	if runs.size() < 2:
		return
	var a := runs[0].result()
	var b := runs[1].result()
	for r in [a, b]:
		var rd: Dictionary = r
		bot.check(String(rd["stop"]) == "лимит игрового времени", "Кардинал «%s»: дошёл до конца (%s)" % [rd["title"], rd["stop"]])
		bot.check(int(rd["kills"]) >= 1, "Кардинал «%s»: убийств %d" % [rd["title"], rd["kills"]])
		bot.check((rd["xp_mismatch"] as Array).is_empty(), "Кардинал «%s»: опыт за каждое убийство = формула игры%s" % [
			rd["title"], "" if (rd["xp_mismatch"] as Array).is_empty() else ": " + "; ".join(
			PackedStringArray((rd["xp_mismatch"] as Array).slice(0, 5)))])
	# Скорость сравнима только с настоящим рендером (на телефоне): headless с --fixed-fps считает кадры без отрисовки
	var speed_txt := "Кардинал: ускоренный быстрее (×%.2f против ×%.2f)" % [float(b["speedup"]), float(a["speedup"])]
	if DisplayServer.get_name() == "headless":
		bot.note(speed_txt + " — без рендера (headless) не сравнивается")
	else:
		bot.check(float(b["speedup"]) > float(a["speedup"]), speed_txt)
	var data := {"version": 1, "game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"scenario": id(), "seed": seed_value, "game_limit": game_limit, "runs": [a, b], "compare": _diff(a, b)}
	var dir := bot.run_dir if bot.run_dir != "" else bot.report_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("cardinal.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	_last = data


var _last := {}


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for key in ["xp_per_min", "ttk_avg", "kills", "damage_taken", "deaths", "gold"]:
		var va := float(a[key])
		var vb := float(b[key])
		var ratio := _ratio(va, vb)
		var ok := (va == 0.0 and vb == 0.0) or (ratio >= RATIO_LO and ratio <= RATIO_HI)
		if key == "deaths":
			ok = absf(va - vb) <= 1.0
		out.append({"metric": key, "visual": va, "fast": vb, "ratio": snappedf(ratio, 0.01) if ratio != INF else -1.0,
			"ok": ok})
	return out


const METRIC_NAMES := {"xp_per_min": "опыт / мин игрового времени", "ttk_avg": "время на зверя (TTK), с",
	"kills": "убийств", "damage_taken": "урон по герою", "deaths": "смертей", "gold": "золото"}


func summary(_bot: TestBot) -> String:
	if _last.is_empty():
		return "Кардинал: сравнения нет (прогоны не закончились)"
	var bad := 0
	for d in _last["compare"]:
		if not bool((d as Dictionary)["ok"]):
			bad += 1
	return "Кардинал: 2 прогона по %s игрового времени, расхождений вне допуска: %d" % [TestBot.clock(game_limit), bad]


func report_lines(_bot: TestBot) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Кардинал — первый срез (фаза 1)")
	out.append("  Профиль «Обычный игрок» v2 (брошенную цель минуту не выбирает), seed %d, зона «Окрестности деревни людей», герой — Бродяга 1 ур." % seed_value)
	for r in runs:
		var d := r.result()
		var ts: Dictionary = d["time_split"]
		out.append("  %s: игровое %s, настоящее %s (×%.2f), остановка — %s" % [d["title"], TestBot.clock(float(d["game_sec"])),
			TestBot.clock(float(d["wall_sec"])), float(d["speedup"]), d["stop"]])
		out.append("    уровень %d → %d, опыт +%d (%.1f/мин), убийств %d, TTK %.2f с, урон по герою %d, смертей %d, золото %+d" % [
			int((d["start"] as Dictionary)["level"]), int((d["finish"] as Dictionary).get("level", 0)), int(d["xp"]),
			float(d["xp_per_min"]), int(d["kills"]), float(d["ttk_avg"]), int(d["damage_taken"]), int(d["deaths"]), int(d["gold"])])
		out.append("    время: поиск %s, путь %s, бой %s, добыча %s, отдых %s" % [TestBot.clock(float(ts["seek"])),
			TestBot.clock(float(ts["approach"])), TestBot.clock(float(ts["fight"])), TestBot.clock(float(ts["loot"])),
			TestBot.clock(float(ts["rest"]))])
		if not (d["xp_mismatch"] as Array).is_empty():
			out.append("    ! опыт не по формуле: " + "; ".join(PackedStringArray((d["xp_mismatch"] as Array).slice(0, 5))))
	if not _last.is_empty():
		out.append("  Сравнение «ускоренный / с картинкой» (допуск %.1f–%.1f; смерти — ±1):" % [RATIO_LO, RATIO_HI])
		for e in _last["compare"]:
			var c: Dictionary = e
			out.append("    %-28s %8.1f  %8.1f  ×%-5s %s" % [METRIC_NAMES.get(c["metric"], c["metric"]), float(c["visual"]),
				float(c["fast"]), ("%.2f" % float(c["ratio"])) if float(c["ratio"]) >= 0.0 else "—",
				"в допуске" if bool(c["ok"]) else "РАСХОЖДЕНИЕ"])
		out.append("  Статистика короткого прогона шумная (мало убийств): расхождение — повод для серии seed, не ошибка.")
		out.append("  Воспроизвести: режим «Кардинал: первый срез», seed %d, %s игрового времени на прогон." % [seed_value,
			TestBot.clock(game_limit)])
	return out
