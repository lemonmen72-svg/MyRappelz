class_name CardinalProfiles
extends RefCounted
## Кардинал, фаза 4 (CARDINAL_MASTER_INSTRUCTION.md §5, §6): пять профилей поведения игрока — Новичок, Обычный,
## Ветеран, Фармер, Экспериментатор. Профиль — параметры поведения CardinalStory поверх PROFILE_STORY: как отдыхает и
## рискует, как готовится (зелья, экипировка), учит ли умения сразу, зовёт ли питомца, делает ли необязательное,
## паузы, ошибки маршрута, неоптимальный выбор, «пробы» (fuzzing) у Экспериментатора, фарм у Фармера; стартовые
## ресурсы; что знает и насколько рискует (для отчёта); пороги подозрений (limits). Режим честный: опыт ×1, без
## бессмертия, без помощи подземелью; единственная помощь — перенос, если застрял (в отчёте — как находка).
##
## Без перекомпиляции: user://cardinal_profiles.json — {"<профиль>": {ключ: значение, "limits": {…}}} поверх
## встроенных. Каждое значение проверяется по SCHEMA (тип и пределы): неизвестный профиль или ключ, не тот тип — не
## берётся, вне пределов — ставится на край; каждая правка и отказ — строка в отчёте (notes).

const IDS := ["novice", "regular", "veteran", "farmer", "experimenter"]
const OVERRIDE_PATH := "user://cardinal_profiles.json"

## Честный режим (у всех профилей фазы 4): поверх CardinalStory.PROFILE_STORY.
const HONEST := {
	"xp_mult": 1, "god_bosses": false, "pet_phase_xp": 1, "pet_phase_sec": 0.0, "run_speed": 1, "dungeon_hp": 1.0,
	"stuck_teleport": 20.0,
}

## Профили. Поведение: pause_chance (доля шагов плана с паузой), pause_min/max (с), noise (доля выборов не самого
## дешёвого дела), lost_chance (доля дальних путей, где сначала уходит не туда), skill_use (доля попыток нажать умение),
## learn_lazy (умения — раз в 3 уровня), potions_keep (держать зелий здоровья, докупать у торговца), use_pet (звать
## питомца в бой), features (необязательное: торба, склад, крафт, закалка, снаряжение питомцу, эволюция, пояс),
## gear_buy (покупать броню 1-го ранга в пустые ячейки), fuzz (доля шагов с пробой: окна, страницы умений, автоатака,
## зелье при полном HP, отказ от задания, сортировка — с проверкой инвариантов), farm_sec (фарм после отрезка, с),
## start_gold / start_potions (+ к стартовым), level_gap / rest_* / potion_below — риск, boss_gap (босс — когда герой
## не младше босса − gap: −2 — с запасом в 2 уровня), avoid_aggro (обходить агрессивных зверей не по силам и не бить
## зверей рядом с ними; Новичок их не замечает). limits — пороги подозрений:
## deaths (смертей больше — подозрение), grind_share (доля прокачки в игровом времени), level_k (уровень дольше
## медианы уровней прогона в N раз), pause_share (доля пауз), min_level_sec (короче — уровень не проверяется).
const DEFAULTS := {
	"novice": {
		"name": "Новичок", "version": 1,
		"desc": "неидеальный маршрут, паузы, неполная подготовка, ошибается с заданной вероятностью",
		"knowledge": "подсказки заданий и трекер; умения учит редко, зелий не покупает, питомца в бой не зовёт",
		"risk": "высокий",
		"rest_below": 0.3, "rest_until": 0.75, "potion_below": 0.2, "level_gap": 3, "boss_gap": 1, "avoid_aggro": false,
		"pause_chance": 0.12, "pause_min": 2.0, "pause_max": 8.0, "noise": 0.35, "lost_chance": 0.15,
		"skill_use": 0.35, "learn_lazy": true, "potions_keep": 0, "use_pet": false, "features": false,
		"gear_buy": false, "fuzz": 0.0, "farm_sec": 0.0, "start_gold": 0, "start_potions": 0,
		"limits": {"deaths": 3, "grind_share": 0.55, "level_k": 3.0, "pause_share": 0.35, "min_level_sec": 120.0},
	},
	"regular": {
		"name": "Обычный", "version": 1,
		"desc": "разумно проходит задания, немного отвлекается, умеренно тратит",
		"knowledge": "подсказки заданий, карта жителей; учит умения, держит пару зелий, зовёт питомца",
		"risk": "средний",
		"rest_below": 0.45, "rest_until": 0.9, "potion_below": 0.35, "level_gap": 2, "boss_gap": -2, "avoid_aggro": true,
		"pause_chance": 0.03, "pause_min": 1.0, "pause_max": 4.0, "noise": 0.1, "lost_chance": 0.03,
		"skill_use": 0.85, "learn_lazy": false, "potions_keep": 3, "use_pet": true, "features": true,
		"gear_buy": false, "fuzz": 0.0, "farm_sec": 0.0, "start_gold": 0, "start_potions": 0,
		"limits": {"deaths": 1, "grind_share": 0.4, "level_k": 3.0, "pause_share": 0.15, "min_level_sec": 120.0},
	},
	"veteran": {
		"name": "Ветеран", "version": 1,
		"desc": "оптимальный порядок и маршрут, все умения, питомец, броня и запас зелий; без читов и скрытого знания",
		"knowledge": "механики игры, цены лавок, где звери; не видит скрытого (шансов, будущей добычи)",
		"risk": "низкий",
		"rest_below": 0.5, "rest_until": 0.95, "potion_below": 0.4, "level_gap": 1, "boss_gap": -1, "avoid_aggro": true,
		"pause_chance": 0.0, "pause_min": 0.0, "pause_max": 0.0, "noise": 0.0, "lost_chance": 0.0,
		"skill_use": 1.0, "learn_lazy": false, "potions_keep": 8, "use_pet": true, "features": true,
		"gear_buy": true, "fuzz": 0.0, "farm_sec": 0.0, "start_gold": 0, "start_potions": 0,
		"limits": {"deaths": 0, "grind_share": 0.35, "level_k": 3.0, "pause_share": 0.05, "min_level_sec": 120.0},
	},
	"farmer": {
		"name": "Фармер", "version": 1,
		"desc": "сравнивает доход: задания против прокачки на зверях и продажи добычи",
		"knowledge": "как Обычный; после отрезка фармит зверей по силам и продаёт добычу",
		"risk": "средний",
		"rest_below": 0.45, "rest_until": 0.9, "potion_below": 0.35, "level_gap": 1, "boss_gap": -3, "avoid_aggro": true,
		"pause_chance": 0.02, "pause_min": 1.0, "pause_max": 3.0, "noise": 0.05, "lost_chance": 0.0,
		"skill_use": 0.9, "learn_lazy": false, "potions_keep": 4, "use_pet": true, "features": false,
		"gear_buy": false, "fuzz": 0.0, "farm_sec": 600.0, "start_gold": 0, "start_potions": 0,
		"limits": {"deaths": 1, "grind_share": 1.0, "level_k": 3.0, "pause_share": 0.1, "min_level_sec": 120.0},
	},
	"experimenter": {
		"name": "Экспериментатор", "version": 1,
		"desc": "необычный порядок, крайние сочетания, прерывания; пробует всё (fuzzing с ограничениями)",
		"knowledge": "как Обычный, но выбирает дела вразнобой и проверяет окна, кнопки, отказ от заданий",
		"risk": "средний",
		"rest_below": 0.4, "rest_until": 0.85, "potion_below": 0.3, "level_gap": 2, "boss_gap": 0, "avoid_aggro": true,
		"pause_chance": 0.05, "pause_min": 1.0, "pause_max": 5.0, "noise": 0.6, "lost_chance": 0.1,
		"skill_use": 0.6, "learn_lazy": false, "potions_keep": 2, "use_pet": true, "features": true,
		"gear_buy": false, "fuzz": 0.25, "farm_sec": 0.0, "start_gold": 0, "start_potions": 0,
		"limits": {"deaths": 3, "grind_share": 0.6, "level_k": 4.0, "pause_share": 0.25, "min_level_sec": 120.0},
	},
}

## Ключ → [тип, мин, макс] (тип: "float", "int", "bool", "text").
const SCHEMA := {
	"name": ["text"], "desc": ["text"], "knowledge": ["text"], "risk": ["text"], "version": ["int", 1, 1000],
	"rest_below": ["float", 0.05, 0.95], "rest_until": ["float", 0.1, 1.0], "potion_below": ["float", 0.0, 0.9],
	"level_gap": ["int", -2, 6], "boss_gap": ["int", -10, 10], "avoid_aggro": ["bool"],
	"pause_chance": ["float", 0.0, 0.5], "pause_min": ["float", 0.0, 30.0],
	"pause_max": ["float", 0.0, 60.0], "noise": ["float", 0.0, 1.0], "lost_chance": ["float", 0.0, 0.5],
	"skill_use": ["float", 0.0, 1.0], "learn_lazy": ["bool"], "potions_keep": ["int", 0, 30], "use_pet": ["bool"],
	"features": ["bool"], "gear_buy": ["bool"], "fuzz": ["float", 0.0, 0.5], "farm_sec": ["float", 0.0, 3600.0],
	"start_gold": ["int", 0, 1000000], "start_potions": ["int", 0, 50], "stuck_teleport": ["float", 5.0, 120.0],
}
const LIMITS_SCHEMA := {
	"deaths": ["int", 0, 1000], "grind_share": ["float", 0.0, 1.0], "level_k": ["float", 1.0, 20.0],
	"pause_share": ["float", 0.0, 1.0], "min_level_sec": ["float", 0.0, 3600.0],
}

## Правки из файла (кэш на запуск): {"data": {профиль: {ключ: значение}}, "notes": [строки]}.
static var _over: Dictionary = {}
## Путь файла правок (тест подставляет свой).
static var override_path := OVERRIDE_PATH


static func ids() -> Array:
	return IDS


static func profile_name(id: String) -> String:
	return String((DEFAULTS.get(id, {}) as Dictionary).get("name", id))


## Профиль для CardinalStory: PROFILE_STORY + честный режим + встроенный профиль + проверенные правки из файла.
static func profile(id: String) -> Dictionary:
	var p: Dictionary = CardinalStory.PROFILE_STORY.duplicate(true)
	p.merge(HONEST, true)
	var d: Dictionary = (DEFAULTS.get(id, DEFAULTS["regular"]) as Dictionary).duplicate(true)
	var ov: Dictionary = (overrides()["data"] as Dictionary).get(id, {})
	for k in ov:
		if k == "limits":
			var lim: Dictionary = d["limits"]
			for lk in ov["limits"]:
				lim[lk] = ov["limits"][lk]
		else:
			d[k] = ov[k]
	p.merge(d, true)
	p["id"] = id if DEFAULTS.has(id) else "regular"
	p["overridden"] = not ov.is_empty()
	return p


## Правки из user://cardinal_profiles.json (один раз за запуск; reread — перечитать).
static func overrides() -> Dictionary:
	if _over.is_empty():
		_over = load_overrides(override_path)
	return _over


## Файл правок (тест подставляет свой).
static func use_file(path: String) -> void:
	override_path = path
	_over = {}


static func cur_path() -> String:
	return override_path


## Перечитать файл при следующем запросе. Не «reload»: CardinalProfiles.reload() — встроенный GDScript.reload()
## (перекомпиляция скрипта, все статические поля — к начальным: путь файла правок сбрасывался на user://…, правки
## теста и игрока не доходили до прогона; в APK перекомпиляция может и не пройти).
static func reread() -> void:
	_over = {}


## Прочитать и проверить файл правок: {"data": {id: {ключ: значение}}, "notes": PackedStringArray}.
static func load_overrides(path: String) -> Dictionary:
	var notes := PackedStringArray()
	var out := {"data": {}, "notes": notes, "path": path}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		notes.append("файл правок %s не открылся" % path)
		out["notes"] = notes
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		notes.append("файл правок %s — не JSON-объект, правки не взяты" % path)
		out["notes"] = notes
		return out
	var data: Dictionary = {}
	for pid in (parsed as Dictionary):
		var id := String(pid)
		if not DEFAULTS.has(id):
			notes.append("профиль «%s» неизвестен (есть: %s) — пропущен" % [id, ", ".join(PackedStringArray(IDS))])
			continue
		var src: Variant = (parsed as Dictionary)[pid]
		if not (src is Dictionary):
			notes.append("профиль «%s»: не объект — пропущен" % id)
			continue
		var clean: Dictionary = {}
		for k in (src as Dictionary):
			var key := String(k)
			if key == "limits":
				var lsrc: Variant = (src as Dictionary)[k]
				if not (lsrc is Dictionary):
					notes.append("%s.limits: не объект — пропущено" % id)
					continue
				var lclean: Dictionary = {}
				for lk in (lsrc as Dictionary):
					var r1: Array = _checked(id + ".limits." + String(lk), LIMITS_SCHEMA.get(String(lk)), (lsrc as Dictionary)[lk])
					if String(r1[1]) != "":
						notes.append(String(r1[1]))
					if r1[0] != null:
						lclean[String(lk)] = r1[0]
				if not lclean.is_empty():
					clean["limits"] = lclean
				continue
			var r2: Array = _checked(id + "." + key, SCHEMA.get(key), (src as Dictionary)[k])
			if String(r2[1]) != "":
				notes.append(String(r2[1]))
			if r2[0] != null:
				clean[key] = r2[0]
		if not clean.is_empty():
			data[id] = clean
			notes.append("профиль «%s»: взяты правки %s" % [id, ", ".join(PackedStringArray(clean.keys()))])
	out["data"] = data
	out["notes"] = notes
	return out


## Значение v ключа name по правилу rule ([тип, мин, макс]): [проверенное значение или null (не взято), замечание].
static func _checked(name: String, rule: Variant, v: Variant) -> Array:
	if rule == null:
		return [null, "%s: неизвестный ключ — пропущен" % name]
	var r: Array = rule
	match String(r[0]):
		"text":
			if v is String:
				return [String(v).left(200), ""]
		"bool":
			if v is bool:
				return [v, ""]
		"int", "float":
			if v is int or v is float:
				var x := float(v)
				var lo := float(r[1])
				var hi := float(r[2])
				var note := ""
				if x < lo or x > hi:
					note = "%s: %s вне пределов %s…%s — взято %s" % [name, str(v), str(r[1]), str(r[2]), str(clampf(x, lo, hi))]
					x = clampf(x, lo, hi)
				return [roundi(x) if String(r[0]) == "int" else x, note]
	return [null, "%s: значение %s не того типа (нужно %s) — пропущено" % [name, str(v), String(r[0])]]


## Строки отчёта о профиле: имя, версия, что знает, риск, главное из поведения.
static func describe(p: Dictionary) -> String:
	return "«%s» v%d (%s; риск %s; знает: %s): отдых с %d %% до %d %% HP, зелье ниже %d %%, звери до +%d ур., паузы %d %% шагов, не самое выгодное дело %d %%, сбивается с пути %d %%, умения %d %%%s%s%s%s%s%s%s%s%s" % [
		String(p.get("name", "")), int(p.get("version", 1)), String(p.get("desc", "")), String(p.get("risk", "")),
		String(p.get("knowledge", "")), roundi(float(p["rest_below"]) * 100.0), roundi(float(p["rest_until"]) * 100.0),
		roundi(float(p["potion_below"]) * 100.0), int(p["level_gap"]), roundi(float(p.get("pause_chance", 0.0)) * 100.0),
		roundi(float(p.get("noise", 0.0)) * 100.0), roundi(float(p.get("lost_chance", 0.0)) * 100.0),
		roundi(float(p.get("skill_use", 1.0)) * 100.0),
		", учит умения раз в 3 уровня" if bool(p.get("learn_lazy", false)) else "",
		", держит зелий %d" % int(p.get("potions_keep", 0)) if int(p.get("potions_keep", 0)) > 0 else ", зелий не покупает",
		"" if bool(p.get("use_pet", true)) else ", питомца в бой не зовёт",
		"" if bool(p.get("features", true)) else ", необязательное не делает",
		", покупает броню" if bool(p.get("gear_buy", false)) else "",
		", пробы %d %% шагов" % roundi(float(p.get("fuzz", 0.0)) * 100.0) if float(p.get("fuzz", 0.0)) > 0.0 else "",
		", фарм %s после отрезка" % TestBot.clock(float(p.get("farm_sec", 0.0))) if float(p.get("farm_sec", 0.0)) > 0.0 else "",
		", боссы — с %s" % _boss_text(int(p.get("boss_gap", 3))),
		"" if bool(p.get("avoid_aggro", true)) else ", агрессивных зверей не замечает"]


static func _boss_text(gap: int) -> String:
	if gap == 0:
		return "уровня босса"
	return "ур. босса %s%d" % ["+" if gap < 0 else "−", absi(gap)]
