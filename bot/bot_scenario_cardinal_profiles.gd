class_name BotScenarioCardinalProfiles
extends BotScenario
## Режим «Кардинал: профили игроков» (фаза 4, CARDINAL_MASTER_INSTRUCTION.md §5–§7): выбранные профили
## (CardinalProfiles: Новичок, Обычный, Ветеран, Фармер, Экспериментатор) проходят выбранный отрезок острова честно
## (опыт ×1, без бессмертия) — каждый N раз с разными seed; прогон — CardinalStory с параметрами профиля, раздел отчёта
## (TestBot.section: время, ошибки лога Godot по прогону). Итог: метрики каждого прогона, распределения по профилю
## (мин / медиана / макс), сравнение профилей, подозрения (тупики, застревания, долгий гринд и уровни, смерти,
## нехватка зелий и золота, переполнение сумки, нарушения инвариантов в пробах, ошибки Godot, разброс между seed,
## доход фарма против заданий) — у каждого: важность, доказательства, диапазон, база сравнения, уверенность, как
## повторить, что посмотреть (рекомендация, НЕ применяется). Баланс, данные и сохранения игрока не меняются.
## cardinal_profiles.json — в папке запуска.
## Контрольная точка (фаза 5): после каждого прогона — TestBot.save_checkpoint (выбор запуска и результаты готовых
## прогонов); игру выгрузила система, бот остановлен перегревом или лимитом — «Продолжить» (resume): выбор того
## запуска, готовые прогоны не повторяются, в итоге и анализе — все.

## Отрезки: название, условие конца, старт, лимит игрового времени прогона и оценка (игровые с) для расчёта лимита.
## Оценки — по пробному прогону 07.11 (люди, Воин, seed 20261107, ×16): староста — Новичок 5:24, Обычный 1:41,
## Ветеран 1:32, Экспериментатор 4:31; профессия — 13:06 / 9:43 / 11:58 / 17:24, Фармер 12:09 + фарм; 10 → 15 ур. —
## Обычный 12:54.
const SEGMENTS := {
	"elder": {"name": "1 → 5 ур.: задания старосты", "stop_after": ["elder_hunt", "elder_trophies", "elder_grow",
		"elder_to_sage"], "game_limit": 2700.0, "est": 240.0},
	"job": {"name": "1 ур. → профессия (10 ур.)", "until_job": true, "game_limit": 7200.0, "est": 800.0},
	"post": {"name": "10 → 15 ур. с профессией", "start_level": 10, "until_level": 15, "game_limit": 7200.0,
		"est": 900.0},
}
const SEGMENT_IDS := ["elder", "job", "post"]
const SEED_CHOICES := [1, 3, 5]
const ACCEL_CHOICES := [8, 16, 32]
## Предел оценки времени режима, мин (дольше — «Начать» недоступна, просьба уменьшить выбор): полтора часа — один
## сеанс телефона на зарядке, дольше — нагрев и батарея.
const MAX_MINUTES := 90.0
## Сколько настоящего времени на прогон сверх оценки (загрузка, отдых, медленный телефон).
const WALL_K := 3.0

## Выбор во вкладке «Тест-бот» (до перезапуска игры).
static var chosen: Array = ["novice", "regular", "veteran", "farmer", "experimenter"]
static var segment := "job"
static var seeds := 1
static var race := "human"
static var job := ""
static var accel := 8.0
static var seed_base := 20261107

var runs: Array[CardinalStory] = []
## Готовые прогоны из контрольной точки (resume): run → результат CardinalStory.result() (после JSON числа — float).
var prior: Dictionary = {}
var _analysis := {}
var _last := {}
var _notes: PackedStringArray = PackedStringArray()


func id() -> String:
	return "cardinal_profiles"


func title() -> String:
	return "Кардинал: профили игроков"


func hero() -> Dictionary:
	return {"race": race, "job": ClassData.WANDERER, "gender": "m", "level": 1}


static func toggle_profile(pid: String) -> void:
	if chosen.has(pid):
		chosen.erase(pid)
	else:
		chosen.append(pid)
	# Порядок — как в CardinalProfiles.IDS (отчёт и сравнение)
	var ordered: Array = []
	for k in CardinalProfiles.IDS:
		if chosen.has(k):
			ordered.append(k)
	chosen = ordered


## Профессия отрезка «после профессии»: выбранная (из профессий расы) или первая профессия расы.
static func job_for_run() -> String:
	var js := ClassData.jobs_of(race)
	if job != "" and js.has(job):
		return job
	return String(js[0]) if not js.is_empty() else "warrior"


## Оценка времени режима, мин (игровое время отрезка × прогоны / ускорение, с запасом на загрузку и отдых).
static func estimate_min() -> float:
	var seg: Dictionary = SEGMENTS.get(segment, SEGMENTS["job"])
	var per_run := float(seg["est"]) / maxf(accel, 1.0) * 1.6 + 30.0
	var n := chosen.size() * seeds
	var farm := 0.0
	if chosen.has("farmer"):
		farm = float(CardinalProfiles.profile("farmer").get("farm_sec", 0.0)) / maxf(accel, 1.0) * 1.6 * seeds
	return (per_run * float(n) + farm) / 60.0 + 1.0


## Почему нельзя начать ("" — можно).
static func validate() -> String:
	if chosen.is_empty():
		return "Выберите хотя бы один профиль."
	if not SEGMENTS.has(segment):
		return "Неизвестный отрезок «%s»." % segment
	if not ClassData.jobs_of(race).size():
		return "У расы «%s» нет профессий." % race
	var est := estimate_min()
	if est > MAX_MINUTES:
		return "Слишком долго: примерно %d мин (предел %d) — меньше профилей, прогонов или отрезок короче." % [
			roundi(est), roundi(MAX_MINUTES)]
	return ""


## Лимит режима — вдвое больше оценки: на телефоне ускорение ниже заданного (упирается в процессор), оценка
## считает его до ×5 (×1.6 к игровому времени / ускорение).
func limit() -> float:
	var total := maxi(1, chosen.size() * seeds)
	var left := maxi(1, total - prior.size())
	return maxf(10.0, estimate_min() * 2.0 * float(left) / float(total)) * 60.0


func resumable() -> bool:
	return true


## Продолжение: выбор того запуска (профили, отрезок, прогоны, раса, профессия, ускорение, seed) и готовые прогоны.
func resume(data: Dictionary) -> String:
	var st: Variant = data.get("settings", null)
	var res: Variant = data.get("results", null)
	if not (st is Dictionary) or not (res is Array):
		return "в контрольной точке нет выбора или результатов прогонов"
	var sd: Dictionary = st
	var ch: Array = sd.get("profiles", [])
	if ch.is_empty():
		return "в контрольной точке нет профилей"
	for pid in ch:
		if not CardinalProfiles.IDS.has(String(pid)):
			return "неизвестный профиль «%s»" % String(pid)
	if not SEGMENTS.has(String(sd.get("segment", ""))):
		return "неизвестный отрезок «%s»" % String(sd.get("segment", ""))
	chosen = []
	for pid in ch:
		chosen.append(String(pid))
	segment = String(sd["segment"])
	seeds = clampi(int(sd.get("seeds", 1)), 1, 10)
	race = String(sd.get("race", "human"))
	job = String(sd.get("job", ""))
	accel = float(sd.get("accel", 8.0))
	seed_base = int(sd.get("seed_base", seed_base))
	prior.clear()
	for r in res:
		if r is Dictionary and String((r as Dictionary).get("run", "")) != "":
			prior[String(r["run"])] = r
	return ""


## Прогоны по порядку плана: готовые из контрольной точки и этого запуска (only_done — только законченные).
func _ordered_results(only_done: bool) -> Array:
	var by_run: Dictionary = {}
	for r in runs:
		by_run[r.run_name] = r
	var out: Array = []
	for pid in chosen:
		for s in seeds:
			var rn := "%s_%d" % [pid, s + 1]
			if prior.has(rn):
				out.append(prior[rn])
			elif by_run.has(rn):
				var cr: CardinalStory = by_run[rn]
				if cr.done or not only_done:
					out.append(cr.result())
	return out


func _settings_dict() -> Dictionary:
	return {"profiles": chosen.duplicate(), "segment": segment, "seeds": seeds, "seed_base": seed_base, "race": race,
		"job": job, "accel": accel}


## Контрольная точка после прогона: выбор и результаты готовых прогонов.
func _checkpoint(bot: TestBot) -> void:
	var done := _ordered_results(true)
	bot.save_checkpoint({"settings": _settings_dict(), "results": done}, "прогонов %d из %d" % [done.size(),
		chosen.size() * seeds])


func build(bot: TestBot) -> void:
	CardinalProfiles.reread()
	_notes = (CardinalProfiles.overrides()["notes"] as PackedStringArray).duplicate()
	for n in _notes:
		bot.note("Кардинал, профили: " + n)
	var seg: Dictionary = SEGMENTS.get(segment, SEGMENTS["job"])
	if not prior.is_empty():
		bot.note("Кардинал, профили: из контрольной точки — готовых прогонов %d из %d (%s)" % [prior.size(),
			chosen.size() * seeds, ", ".join(PackedStringArray(prior.keys()))])
	var k := 0
	for pid in chosen:
		for s in seeds:
			k += 1
			if prior.has("%s_%d" % [pid, s + 1]):
				continue
			var pr := CardinalProfiles.profile(String(pid))
			var r := CardinalStory.new()
			r.bot = bot
			r.run_name = "%s_%d" % [pid, s + 1]
			r.title = "%s #%d" % [String(pr["name"]), s + 1]
			r.race = race
			r.job = job_for_run()
			r.accel = accel
			r.seed_value = seed_base + 101 * s
			r.profile = pr
			r.stop_after = seg.get("stop_after", [])
			r.until_job = bool(seg.get("until_job", false))
			r.until_level = int(seg.get("until_level", 0))
			r.start_level = int(seg.get("start_level", 1))
			r.game_limit = float(seg["game_limit"]) + float(pr.get("farm_sec", 0.0))
			r.wall_limit = r.game_limit / maxf(accel, 1.0) * WALL_K + 120.0
			runs.append(r)
			bot.section("prof_%s_%d" % [pid, s + 1], r.title)
			bot.do("Кардинал: прогон «%s»" % r.title, r.begin)
			bot.wait_until("Кардинал: прогон «%s» закончен" % r.title, func() -> bool: return r.done, r.game_limit + 600.0)
			bot.do("Кардинал: контрольная точка", _checkpoint.bind(bot))
	bot.do("Кардинал: профили — итог и подозрения", func() -> void: _summary(bot))


## Щадящий режим TestBot: ускорение прогонов — не выше ×8.
func on_hot(_bot: TestBot) -> String:
	var was := Engine.time_scale
	for r in runs:
		r.accel = minf(r.accel, BotScenarioCardinalStory.GENTLE_ACCEL)
	var k := CardinalMove.ease_off(BotScenarioCardinalStory.GENTLE_ACCEL)
	return "ускорение Кардинала ×%.0f → ×%.0f" % [was, k] if k > 0.0 else "ускорение Кардинала не выше ×8"


func on_finish(_bot: TestBot) -> void:
	for r in runs:
		if not r.done:
			r.abort("бот остановлен")


func last_data() -> Dictionary:
	return _last


func analysis() -> Dictionary:
	return _analysis


# ==================== Итог: метрики, распределения, подозрения ====================

func _summary(bot: TestBot) -> void:
	var results := _ordered_results(false)
	var logs: Dictionary = BotReport.log_by_section(bot.log_mark) if bot.log_mark != "" else {}
	_analysis = analyze(results, logs, {"segment": segment, "accel": accel, "race": race, "job": job_for_run(),
		"seeds": seeds})
	for r in results:
		var rd: Dictionary = r
		bot.check(String(rd["stop"]) != "" and not String(rd["stop"]).begins_with("бот"),
			"Кардинал «%s»: прогон закончен (%s)" % [rd["title"], rd["stop"]])
	var hi := 0
	for s in _analysis["suspicions"]:
		if String((s as Dictionary)["severity"]) == "высокая":
			hi += 1
	bot.note("Кардинал, профили: прогонов %d, подозрений %d (высоких %d)" % [results.size(),
		(_analysis["suspicions"] as Array).size(), hi])
	var profs := {}
	for pid in chosen:
		profs[pid] = CardinalProfiles.profile(String(pid))
	_last = {"version": 1, "game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"scenario": id(), "settings": {"profiles": chosen, "segment": segment, "segment_name": SEGMENTS[segment]["name"],
		"seeds": seeds, "seed_base": seed_base, "race": race, "job": job_for_run(), "accel": accel},
		"profiles": profs, "override_notes": _notes, "runs": results, "analysis": _analysis,
		"resumed_runs": PackedStringArray(prior.keys())}
	var dir := bot.run_dir if bot.run_dir != "" else bot.report_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("cardinal_profiles.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_last, "\t"))
		f.close()


## Метрики прогона (из CardinalStory.result()): числа для таблиц и детекторов.
static func run_metrics(rd: Dictionary) -> Dictionary:
	var m: Dictionary = rd.get("metrics", {})
	var game := maxf(float(rd.get("game_sec", 0.0)), 0.1)
	var st: Dictionary = rd.get("start", {})
	var fi: Dictionary = rd.get("finish", {})
	var xp := float(fi.get("cum_xp", 0)) - float(st.get("cum_xp", 0))
	var kills := int(rd.get("kills", 0))
	var tele := int((rd.get("help", {}) as Dictionary).get("teleport", {}).get("n", 0)) if (rd.get("help", {}) as Dictionary).has("teleport") else 0
	var farm: Dictionary = m.get("farm", {})
	var res := {
		"game": game, "wall": float(rd.get("wall_sec", 0.0)), "level0": int(st.get("level", 1)), "level": int(fi.get("level", 1)),
		"quests": int(rd.get("quests_done", 0)), "deaths": int(rd.get("deaths", 0)), "kills": kills, "teleports": tele,
		"xp": xp, "xp_min": xp / (game / 60.0), "gold_end": int(fi.get("gold", 0)), "gold_in": int(m.get("gold_in", 0)),
		"gold_out": int(m.get("gold_out", 0)), "grind_share": float(m.get("grind_t", 0.0)) / game,
		"pause_share": float(m.get("pause_t", 0.0)) / game, "potions_used": int(m.get("potions_used", 0)),
		"potions_bought": int(m.get("potions_bought", 0)), "no_potion": int(m.get("no_potion", 0)),
		"no_gold": int(m.get("no_gold", 0)), "bag_full": int(m.get("bag_full", 0)), "fights": int(m.get("fights", 0)),
		"fights_dropped": int(m.get("fights_dropped", 0)), "ttk": float(m.get("fight_time", 0.0)) / maxf(float(kills), 1.0),
		"dmg": int(m.get("dmg_taken", 0)), "lost": int(m.get("lost", 0)), "noise": int(m.get("noise_picks", 0)),
		"fuzz": (m.get("fuzz", []) as Array).size(), "violations": (m.get("violations", []) as Array).size(),
		"save_kb": float(m.get("save_bytes", 0)) / 1024.0, "speedup": float(rd.get("speedup", 0.0)),
		"tame_tries": int(m.get("tame_tries", 0)), "tame_ok": int(m.get("tame_ok", 0)),
		"pet_share": float(m.get("pet_sec", 0.0)) / game, "pet_kills": int(m.get("pet_kills", 0)),
	}
	# Доли игрового времени по занятиям (путь, бой, отдых, ожидание, окна…)
	var split := {}
	var ts: Dictionary = rd.get("time_split", {})
	for k in ts:
		split[String(k)] = float(ts[k]) / game
	res["split"] = split
	# Уровни: время каждого пройденного уровня (с)
	var lv: Array = m.get("levels", [])
	var durs: Array = []
	for i in range(1, lv.size()):
		durs.append({"level": int((lv[i - 1] as Dictionary)["level"]), "sec": float((lv[i] as Dictionary)["t"]) -
			float((lv[i - 1] as Dictionary)["t"])})
	res["level_secs"] = durs
	# Фармер: доход фарма и отрезка с заданиями (в час игрового времени)
	if farm.has("t0") and farm.has("t1"):
		var ft := maxf(float(farm["t1"]) - float(farm["t0"]), 1.0)
		var qt := maxf(float(farm["t0"]), 1.0)
		res["farm"] = {"sec": ft, "xp_h": (float(farm["xp1"]) - float(farm["xp0"])) / ft * 3600.0,
			"gold_h": (float(farm["gold1"]) - float(farm["gold0"])) / ft * 3600.0,
			"kills_h": float(int(farm["kills1"]) - int(farm["kills0"])) / ft * 3600.0,
			"quest_xp_h": (float(farm["xp0"]) - float(st.get("cum_xp", 0))) / qt * 3600.0,
			"quest_gold_h": (float(farm["gold0"]) - float(st.get("gold", 0))) / qt * 3600.0, "sold": int(farm.get("sold", 0))}
	return res


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return float(s[n / 2]) if n % 2 == 1 else (float(s[n / 2 - 1]) + float(s[n / 2])) * 0.5


static func _dist(xs: Array) -> Dictionary:
	if xs.is_empty():
		return {"min": 0.0, "med": 0.0, "max": 0.0, "n": 0}
	var lo := INF
	var hi := -INF
	for x in xs:
		lo = minf(lo, float(x))
		hi = maxf(hi, float(x))
	return {"min": lo, "med": _median(xs), "max": hi, "n": xs.size()}


static func _confidence(n: int) -> String:
	return "низкая (1 прогон)" if n <= 1 else ("средняя (%d прогона)" % n if n < 5 else "высокая (%d прогонов)" % n)


## Разбор серии: results — CardinalStory.result() прогонов, logs — ошибки лога Godot по разделам
## (BotReport.log_by_section), settings — отрезок, ускорение, раса, профессия. Возвращает {"profiles": {id: {runs,
## dist}}, "suspicions": [...], "compare": [...]}.
static func analyze(results: Array, logs: Dictionary, settings: Dictionary) -> Dictionary:
	var by: Dictionary = {}
	for r in results:
		var rd: Dictionary = r
		var pid := String(rd.get("profile", "regular"))
		if not by.has(pid):
			by[pid] = []
		(by[pid] as Array).append(rd)
	var profiles: Dictionary = {}
	var sus: Array = []
	var seg_name := String((SEGMENTS.get(String(settings.get("segment", "job")), {}) as Dictionary).get("name", ""))
	var repro_base := "режим «Кардинал: профили игроков», отрезок «%s», раса %s, профессия %s, ускорение ×%.0f, версия %s" % [
		seg_name, String(ClassData.race(String(settings.get("race", "human"))).get("name", "")),
		ClassData.job_name(String(settings.get("job", ""))), float(settings.get("accel", 8.0)),
		str(ProjectSettings.get_setting("application/config/version", "dev"))]
	# Регулярный профиль — база сравнения
	var base: Dictionary = {}
	for pid in by:
		var rs: Array = by[pid]
		var mets: Array = []
		for rd in rs:
			mets.append(run_metrics(rd))
		var keys := ["game", "xp_min", "deaths", "gold_end", "kills", "teleports", "grind_share", "pause_share", "quests",
			"level", "ttk", "dmg", "potions_used"]
		var dist: Dictionary = {}
		for k in keys:
			var xs: Array = []
			for mm in mets:
				xs.append(float((mm as Dictionary)[k]))
			dist[k] = _dist(xs)
		profiles[pid] = {"runs": mets, "dist": dist, "name": CardinalProfiles.profile_name(String(pid))}
		if String(pid) == "regular":
			base = dist
	# Подозрения по каждому прогону
	for pid in by:
		var rs: Array = by[pid]
		var pname := CardinalProfiles.profile_name(String(pid))
		var conf := _confidence(rs.size())
		for i in rs.size():
			var rd: Dictionary = rs[i]
			var mm: Dictionary = (profiles[pid]["runs"] as Array)[i]
			var lim: Dictionary = (rd.get("profile_full", {}) as Dictionary).get("limits", {})
			var who := "«%s» (seed %d)" % [pname, int(rd.get("seed", 0))]
			var repro := repro_base + ", профиль «%s», seed %d" % [pname, int(rd.get("seed", 0))]
			var stop := String(rd.get("stop", ""))
			# Тупик: делать нечего, задания застряли
			var stuck_q := PackedStringArray()
			for qk in rd.get("quests", {}):
				var q: Dictionary = (rd["quests"] as Dictionary)[qk]
				if String(q.get("status", "")) == "stuck":
					stuck_q.append("%s — %s" % [String(q.get("name", qk)), String(q.get("reason", ""))])
			if stop.begins_with("делать больше нечего") or not stuck_q.is_empty():
				sus.append(_s("высокая", "Тупик: задания не пройти", pname, who, ["; ".join(stuck_q) if not stuck_q.is_empty()
					else "конец прогона: " + stop], "", "", "высокая (прямое наблюдение)", repro,
					"проверить условия и цели этих заданий (место, уровень, добыча), путь к их цели"))
			# Отрезок не пройден за лимит
			if stop.begins_with("лимит"):
				sus.append(_s("средняя", "Отрезок не пройден за лимит", pname, who, ["%s: %s, уровень %d, сдано %d заданий" % [
					stop, TestBot.clock(float(mm["game"])), int(mm["level"]), int(mm["quests"])]], "", "",
					conf, repro, "сравнить с другими профилями: долгий гринд или застревание"))
			# Застревание на пути
			if int(mm["teleports"]) > 0:
				var where: Array = ((rd.get("help", {}) as Dictionary).get("teleport", {}) as Dictionary).get("where", [])
				sus.append(_s("средняя", "Застревание на пути (перенос)", pname, who,
					PackedStringArray(where.slice(0, 5)), "%d раз" % int(mm["teleports"]), "0", "высокая (прямое наблюдение)",
					repro, "посмотреть место: коллизия, проход у моста, препятствие на пути"))
			# Смерти
			if int(mm["deaths"]) > int(lim.get("deaths", 1)):
				var dev := PackedStringArray()
				for e in rd.get("events", []):
					if String((e as Dictionary).get("kind", "")) == "death":
						dev.append("%s %s" % [TestBot.clock(float((e as Dictionary).get("t", 0.0))), String((e as Dictionary)["text"])])
				sus.append(_s("высокая" if int(mm["deaths"]) > 2 * maxi(1, int(lim.get("deaths", 1))) else "средняя",
					"Много смертей", pname, who, dev.slice(0, 5), "%d" % int(mm["deaths"]), "до %d" % int(lim.get("deaths", 1)),
					conf, repro, "сила зверей на пути заданий и их уровни против уровня героя; агрессивные рядом с целями"))
			# Долгий гринд
			if float(mm["grind_share"]) > float(lim.get("grind_share", 0.4)):
				sus.append(_s("средняя", "Долгий обязательный гринд", pname, who, ["прокачка %d %% игрового времени (%s из %s)" % [
					roundi(float(mm["grind_share"]) * 100.0), TestBot.clock(float(mm["grind_share"]) * float(mm["game"])),
					TestBot.clock(float(mm["game"]))]], "%d %%" % roundi(float(mm["grind_share"]) * 100.0),
					("у «Обычного» %d %%" % roundi(float((base.get("grind_share", {}) as Dictionary).get("med", 0.0)) * 100.0))
					if not base.is_empty() else "до %d %%" % roundi(float(lim.get("grind_share", 0.4)) * 100.0), conf, repro,
					"опыт заданий на этом отрезке против кривой опыта; задания, что ждут уровня"))
			# Долгий уровень
			var secs: Array = []
			for ls in mm["level_secs"]:
				secs.append(float((ls as Dictionary)["sec"]))
			var med := _median(secs)
			for ls in mm["level_secs"]:
				var l: Dictionary = ls
				if secs.size() >= 3 and float(l["sec"]) > float(lim.get("level_k", 3.0)) * med \
						and float(l["sec"]) > float(lim.get("min_level_sec", 120.0)):
					sus.append(_s("низкая", "Долгий уровень %d → %d" % [int(l["level"]), int(l["level"]) + 1], pname, who,
						["уровень занял %s при медиане уровней прогона %s" % [TestBot.clock(float(l["sec"])), TestBot.clock(med)]],
						TestBot.clock(float(l["sec"])), "медиана %s" % TestBot.clock(med), conf, repro,
						"чем заняты задания этого уровня и сколько опыта они дают"))
			# Простой (паузы)
			if float(mm["pause_share"]) > float(lim.get("pause_share", 0.2)):
				sus.append(_s("низкая", "Много простоя", pname, who, ["паузы %d %% игрового времени" % roundi(float(mm["pause_share"]) * 100.0)],
					"%d %%" % roundi(float(mm["pause_share"]) * 100.0), "до %d %%" % roundi(float(lim.get("pause_share", 0.2)) * 100.0),
					conf, repro, "параметры профиля (паузы) или простой из-за ожидания (возрождение зверей)"))
			# Ресурсы
			if int(mm["no_potion"]) > 0 and int(mm["deaths"]) > 0:
				sus.append(_s("средняя", "Нехватка зелий в бою", pname, who, ["зелий не было при низком HP: %d раз; смертей %d; выпито %d, куплено %d" % [
					int(mm["no_potion"]), int(mm["deaths"]), int(mm["potions_used"]), int(mm["potions_bought"])]], "%d" % int(mm["no_potion"]),
					"0", conf, repro, "сколько зелий даёт добыча и награды на отрезке, их цена против дохода"))
			if int(mm["no_gold"]) > 0:
				sus.append(_s("средняя", "Не хватило золота", pname, who, ["сообщений «Не хватает золота»: %d; золото: пришло %d, ушло %d, в конце %d" % [
					int(mm["no_gold"]), int(mm["gold_in"]), int(mm["gold_out"]), int(mm["gold_end"])]], "%d" % int(mm["no_gold"]), "0",
					conf, repro, "цены покупок по заданиям и доход отрезка"))
			if int(mm["bag_full"]) > 0:
				sus.append(_s("низкая", "Сумка переполнялась", pname, who, ["«Сумка полна»: %d раз" % int(mm["bag_full"])],
					"%d" % int(mm["bag_full"]), "0", conf, repro, "вместимость сумки на этом отрезке против добычи"))
			# Нарушения инвариантов (пробы Экспериментатора)
			var viol: Array = (rd.get("metrics", {}) as Dictionary).get("violations", [])
			if not viol.is_empty():
				sus.append(_s("высокая", "Нарушение правил игры после пробы", pname, who, PackedStringArray(viol.slice(0, 6)),
					"%d" % viol.size(), "0", "высокая (прямое наблюдение)", repro, "повторить пробу из журнала прогона по шагам"))
			# Ошибки Godot за прогон
			var lg: Dictionary = logs.get(String(rd.get("title", "")), {})
			if int(lg.get("errors", 0)) > 0:
				sus.append(_s("средняя", "Ошибки в логе Godot", pname, who, PackedStringArray((lg.get("lines", PackedStringArray()) as PackedStringArray).slice(0, 4)),
					"%d" % int(lg["errors"]), "0", "высокая (прямое наблюдение)", repro, "строки лога под разделом прогона"))
	# Разброс между seed и сравнение профилей
	var compare: Array = []
	for pid in profiles:
		var d: Dictionary = profiles[pid]["dist"]
		var g: Dictionary = d["game"]
		if int(g["n"]) >= 2 and float(g["min"]) > 0.0 and float(g["max"]) / float(g["min"]) > 2.0:
			sus.append(_s("низкая", "Большой разброс между прогонами", String(profiles[pid]["name"]), "«%s»" % String(profiles[pid]["name"]),
				["время отрезка %s … %s" % [TestBot.clock(float(g["min"])), TestBot.clock(float(g["max"]))]],
				"×%.1f" % (float(g["max"]) / float(g["min"])), "до ×2", _confidence(int(g["n"])), repro_base,
				"случайность отрезка (добыча, приручение, возрождение) — сравнить журналы прогонов"))
	if profiles.has("veteran") and profiles.has("novice"):
		var vg := float(((profiles["veteran"]["dist"] as Dictionary)["game"] as Dictionary)["med"])
		var ng := float(((profiles["novice"]["dist"] as Dictionary)["game"] as Dictionary)["med"])
		compare.append("Ветеран против Новичка: %s против %s (медианы)" % [TestBot.clock(vg), TestBot.clock(ng)])
		if vg > ng and ng > 0.0:
			sus.append(_s("средняя", "Ветеран проходит медленнее Новичка", "Ветеран", "«Ветеран»", [compare[-1]],
				TestBot.clock(vg), TestBot.clock(ng), _confidence(mini(int(((profiles["veteran"]["dist"] as Dictionary)["game"] as Dictionary)["n"]),
				int(((profiles["novice"]["dist"] as Dictionary)["game"] as Dictionary)["n"]))), repro_base,
				"оптимальное поведение не выигрывает: подготовка (броня, зелья) дороже, чем даёт, или задания ждут уровня"))
	if profiles.has("farmer"):
		for mm in profiles["farmer"]["runs"]:
			var fm: Dictionary = (mm as Dictionary).get("farm", {})
			if fm.is_empty():
				continue
			compare.append("Фармер: фарм — опыт %d/ч, золото %d/ч, убийств %d/ч; отрезок с заданиями — опыт %d/ч, золото %d/ч" % [
				roundi(float(fm["xp_h"])), roundi(float(fm["gold_h"])), roundi(float(fm["kills_h"])), roundi(float(fm["quest_xp_h"])),
				roundi(float(fm["quest_gold_h"]))])
			if float(fm["quest_xp_h"]) > 0.0 and float(fm["xp_h"]) > 2.0 * float(fm["quest_xp_h"]):
				sus.append(_s("низкая", "Фарм выгоднее заданий по опыту", "Фармер", "«Фармер»", [compare[-1]],
					"%d/ч" % roundi(float(fm["xp_h"])), "задания %d/ч" % roundi(float(fm["quest_xp_h"])), _confidence(1),
					repro_base, "опыт наград заданий против опыта зверей по силам (рейт ×5)"))
			if float(fm["quest_gold_h"]) > 0.0 and float(fm["gold_h"]) < 0.25 * float(fm["quest_gold_h"]):
				sus.append(_s("низкая", "Фарм невыгоден по золоту", "Фармер", "«Фармер»", [compare[-1]],
					"%d/ч" % roundi(float(fm["gold_h"])), "задания %d/ч" % roundi(float(fm["quest_gold_h"])), _confidence(1),
					repro_base, "золото зверей и цены продажи добычи против наград заданий"))
	var order := {"высокая": 0, "средняя": 1, "низкая": 2}
	sus.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(order.get(String(a["severity"]), 3)) < int(order.get(String(b["severity"]), 3)))
	return {"profiles": profiles, "suspicions": sus, "compare": compare}


static func _s(sev: String, title: String, profile: String, who: String, evidence: Variant, range_v: String,
		baseline: String, confidence: String, repro: String, advice: String) -> Dictionary:
	var ev := PackedStringArray()
	for e in evidence:
		ev.append(String(e))
	return {"severity": sev, "title": title, "profile": profile, "who": who, "evidence": ev, "range": range_v,
		"baseline": baseline, "confidence": confidence, "repro": repro, "advice": advice}


# ==================== Отчёт ====================

func summary(_bot: TestBot) -> String:
	if _analysis.is_empty():
		return ""
	var hi := 0
	for s in _analysis["suspicions"]:
		if String((s as Dictionary)["severity"]) == "высокая":
			hi += 1
	return "Кардинал, профили: прогонов %d%s, подозрений %d (высоких %d)" % [runs.size() + prior.size(),
		" (из них %d — из контрольной точки)" % prior.size() if not prior.is_empty() else "",
		(_analysis["suspicions"] as Array).size(), hi]


func report_lines(_bot: TestBot) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Кардинал — профили игроков (фаза 4)")
	out.append("  Отрезок «%s», раса %s, профессия %s, прогонов на профиль %d (seed %d + 101·k), ускорение ×%.0f; честно: опыт ×1, без бессмертия; помощь — только перенос, если застрял дольше 20 с" % [
		String(SEGMENTS[segment]["name"]), String(ClassData.race(race).get("name", race)), ClassData.job_name(job_for_run()),
		seeds, seed_base, accel])
	for n in _notes:
		out.append("  Правки профилей (%s): %s" % [CardinalProfiles.override_path, n])
	for pid in chosen:
		out.append("  Профиль " + CardinalProfiles.describe(CardinalProfiles.profile(String(pid))))
	if _analysis.is_empty():
		out.append("  Итога нет: режим прерван до разбора.")
		return out
	var profiles: Dictionary = _analysis["profiles"]
	out.append("  Прогоны (игровое время, уровень, сданных заданий, смертей, переносов, опыт/мин, золото в конце (пришло/ушло), прокачка, паузы, зелья выпито/куплено, боёв (брошено), TTK, урон по герою):")
	if not prior.is_empty():
		out.append("    (* — прогон до перерыва, из контрольной точки)")
	for rd0 in _ordered_results(false):
		var rd: Dictionary = rd0
		var mm := run_metrics(rd)
		out.append("    %-18s %-26s %s, ур. %d→%d, сдано %d, смертей %d, переносов %d, опыт %.0f/мин, золото %d (+%d/−%d), прокачка %d %%, паузы %d %%, зелья %d/%d, боёв %d (%d), TTK %.1f с, урон %d, ×%.1f" % [
			String(rd["title"]) + (" *" if prior.has(String(rd.get("run", ""))) else ""), String(rd["stop"]).left(26), TestBot.clock(float(mm["game"])), int(mm["level0"]), int(mm["level"]),
			int(mm["quests"]), int(mm["deaths"]), int(mm["teleports"]), float(mm["xp_min"]), int(mm["gold_end"]), int(mm["gold_in"]),
			int(mm["gold_out"]), roundi(float(mm["grind_share"]) * 100.0), roundi(float(mm["pause_share"]) * 100.0),
			int(mm["potions_used"]), int(mm["potions_bought"]), int(mm["fights"]), int(mm["fights_dropped"]), float(mm["ttk"]),
			int(mm["dmg"]), float(mm["speedup"])])
		var sp := PackedStringArray()
		var sk: Array = (mm["split"] as Dictionary).keys()
		sk.sort_custom(func(a: Variant, b: Variant) -> bool: return float(mm["split"][a]) > float(mm["split"][b]))
		for k in sk:
			if float(mm["split"][k]) >= 0.01:
				sp.append("%s %d %%" % [String(BotScenarioCardinalStory.SPLIT_NAMES.get(k, k)), roundi(float(mm["split"][k]) * 100.0)])
		out.append("      время: %s; приручений %d (с душой %d), питомец призван %d %% времени, убийств при нём %d из %d" % [
			", ".join(sp) if not sp.is_empty() else "—", int(mm["tame_tries"]), int(mm["tame_ok"]),
			roundi(float(mm["pet_share"]) * 100.0), int(mm["pet_kills"]), int(mm["kills"])])
		var ls := PackedStringArray()
		for l in mm["level_secs"]:
			ls.append("%d→%d %s" % [int((l as Dictionary)["level"]), int((l as Dictionary)["level"]) + 1, TestBot.clock(float((l as Dictionary)["sec"]))])
		if not ls.is_empty():
			out.append("      уровни: " + ", ".join(ls))
		if int(mm["lost"]) + int(mm["noise"]) + int(mm["fuzz"]) > 0:
			out.append("      сбился с пути %d, не самое выгодное дело %d, проб %d (нарушений %d)" % [int(mm["lost"]), int(mm["noise"]),
				int(mm["fuzz"]), int(mm["violations"])])
		if mm.has("farm"):
			var fm: Dictionary = mm["farm"]
			out.append("      фарм %s: опыт %d/ч, золото %d/ч, убийств %d/ч, продано %d; задания: опыт %d/ч, золото %d/ч" % [
				TestBot.clock(float(fm["sec"])), roundi(float(fm["xp_h"])), roundi(float(fm["gold_h"])), roundi(float(fm["kills_h"])),
				int(fm["sold"]), roundi(float(fm["quest_xp_h"])), roundi(float(fm["quest_gold_h"]))])
	out.append("  Распределения по профилю (мин / медиана / макс):")
	for pid in chosen:
		if not profiles.has(pid):
			continue
		var d: Dictionary = profiles[pid]["dist"]
		var g: Dictionary = d["game"]
		var x: Dictionary = d["xp_min"]
		var de: Dictionary = d["deaths"]
		var go: Dictionary = d["gold_end"]
		out.append("    %-16s время %s / %s / %s · опыт/мин %.0f / %.0f / %.0f · смертей %d / %d / %d · золото %d / %d / %d (прогонов %d)" % [
			String(profiles[pid]["name"]), TestBot.clock(float(g["min"])), TestBot.clock(float(g["med"])), TestBot.clock(float(g["max"])),
			float(x["min"]), float(x["med"]), float(x["max"]), int(de["min"]), int(de["med"]), int(de["max"]), int(go["min"]), int(go["med"]),
			int(go["max"]), int(g["n"])])
	for c in _analysis.get("compare", []):
		out.append("  Сравнение: " + String(c))
	var sus: Array = _analysis["suspicions"]
	out.append("  Подозрения (%d; рекомендации не применяются — только для решения):" % sus.size())
	out.append("    Пороги предварительные (limits профиля, правятся в %s): «долго» — ещё не «плохо», решает разработчик; уверенность растёт с числом прогонов (seed)." % CardinalProfiles.OVERRIDE_PATH)
	if sus.is_empty():
		out.append("    нет")
	for s in sus:
		var sd: Dictionary = s
		out.append("    [%s] %s — %s" % [String(sd["severity"]), String(sd["title"]), String(sd["who"])])
		for e in sd["evidence"]:
			out.append("        · " + String(e).left(240))
		if String(sd["range"]) != "" or String(sd["baseline"]) != "":
			out.append("        значение %s; база %s; уверенность %s" % [String(sd["range"]), String(sd["baseline"]), String(sd["confidence"])])
		else:
			out.append("        уверенность %s" % String(sd["confidence"]))
		out.append("        повторить: " + String(sd["repro"]))
		out.append("        посмотреть: " + String(sd["advice"]))
	out.append("  Данные целиком — cardinal_profiles.json в архиве отчёта.")
	return out
