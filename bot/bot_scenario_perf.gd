extends BotScenario
## Режим «Производительность» тест-бота (заменяет отдельный тест производительности третьей сборки).
## Тестовый герой — Неофит 40 ур. (тёмная эльфийка: зоны на земле, залпы, горение — самые «тяжёлые» эффекты), все
## доступные умения, питомец-волк 30 ур., бессмертие (AdminPanel.god).
## Сцены (SCENES): город у жителей и лавок, поле с травой и зверями, толпа зверей (CROWD зверей кольцом), бой
## с умениями (BATTLE зверей перед героем, умения по кругу, обычная атака, MP и HP полные), даль (камера низко
## и далеко — весь остров). В каждой сцене — каждый пресет «Низкое…Максимальное» по MEASURE с (до замера прогрев
## TestBot.warmup), затем в городе — база «Среднее» и тяжёлые настройки по одной (SETTINGS) поверх «Среднего».
## На каждую комбинацию — строка отчёта (метрики, температура до/после) и снимок. Итого ≈ 31 замер × 18 с ≈ 9.5 мин
## (лимит режима — 12 мин активного времени, BotScenario.MODES).

const MEASURE := 15.0
const CROWD := 14
const CROWD_TYPES := ["wolf", "panther", "turtle", "pheasant", "anathema", "flyfish", "flyfish_sail"]
const CROWD_LEVEL := 5
const BATTLE := 3
const BATTLE_TYPE := "turtle"
const BATTLE_LEVEL := 40
## Сцены: id, название, точка острова, камера (поворот, наклон, расстояние; нет — по умолчанию), что ещё.
const SCENES := [
	{"id": "town", "name": "Город", "pos": Vector2(0, 5)},
	{"id": "field", "name": "Поле", "pos": Vector2(30, 30), "cam": [0.8, 0.62, 14.0]},
	{"id": "crowd", "name": "Толпа зверей", "pos": Vector2(30, 30), "cam": [0.8, 0.7, 16.0], "crowd": true},
	{"id": "battle", "name": "Бой с умениями", "pos": Vector2(34, 24), "cam": [0.4, 0.6, 11.0], "battle": true},
	{"id": "far", "name": "Даль", "pos": Vector2(0, 5), "cam": [0.6, 0.32, 22.0]},
]
## Настройки по одной поверх «Среднего» (город): [ключ Quality, значение].
const SETTINGS := [
	["shadows", 0], ["shadows", 3], ["aa", 0], ["aa", 1], ["aa", 3], ["render", 0], ["render", 3], ["outlines", 0],
	["postfx", 2], ["view", 3], ["model_shadows", 1],
]

var bot: TestBot
var _cast_cd := 0.0
var _skill_i := 0
var _refill := 0.0


func id() -> String:
	return "perf"


func title() -> String:
	return "Производительность"


func hero() -> Dictionary:
	return {"race": "dark_elf", "job": "neophyte", "gender": "f", "level": 40}


func build(b: TestBot) -> void:
	bot = b
	b.do("Герой: умения и питомец", _prepare)
	for e in SCENES:
		var sc: Dictionary = e
		b.do("Сцена «%s»" % String(sc["name"]), _enter.bind(sc))
		var tick := _battle_tick if bool(sc.get("battle", false)) else Callable()
		for l in range(Quality.LOW, Quality.ULTRA + 1):
			b.measure(String(sc["name"]), Quality.level_name(l), MEASURE, {"preset": l, "kind": "preset", "tick": tick})
		b.do("Конец сцены «%s»" % String(sc["name"]), _leave)
	var town: Dictionary = SCENES[0]
	b.do("Город: настройки по одной", _enter.bind(town))
	b.measure(String(town["name"]), "Среднее (база)", MEASURE, {"preset": Quality.MEDIUM, "kind": "setting",
		"base": true})
	for e in SETTINGS:
		var op: Array = e
		var key := String(op[0])
		var v := int(op[1])
		b.measure(String(town["name"]), "%s: %s" % [Quality.option_title(key), Quality.option_label(key, v)], MEASURE,
			{"preset": Quality.MEDIUM, "option": [key, v], "kind": "setting"})
	b.do("Конец: графика «Среднее»", func() -> void: b.set_preset(Quality.MEDIUM))


## Все доступные умения Неофита 40 ур., четыре атакующих — на кнопки, питомец-волк.
func _prepare() -> void:
	bot.learn_all()
	var p := bot.player()
	if not bot.check(p != null, "герой в мире"):
		return
	var picked: Array = []
	var list: Array = HeroSkills.list_for(Game.class_id)
	for k in range(list.size() - 1, -1, -1):
		var sid := String(list[k])
		if HeroSkills.kind(sid) != "active" or HeroSkills.skill_level(Game.hero, sid) <= 0 or not HeroSkills.is_ready(sid):
			continue
		if HeroSkills.weapon_block(sid, p.weapon_kind, p.has_shield) != "":
			continue
		var use := String(HeroSkills.get_skill(sid).get("use", ""))
		if use == "self" or use == "pet":
			continue
		picked.append(sid)
		if picked.size() >= HeroSkills.SLOTS:
			break
	for i in picked.size():
		p.assign_slot(String(picked[i]), i)
	p.refresh_skills()
	bot.check(picked.size() >= 2, "атакующих умений на кнопках: %d" % picked.size())
	bot.add_pet("wolf", 30)


func _enter(sc: Dictionary) -> void:
	bot.reset_camera()
	var at: Vector2 = sc["pos"]
	bot.teleport(at, String(sc["name"]))
	if sc.has("cam"):
		var c: Array = sc["cam"]
		bot.set_camera(float(c[0]), float(c[1]), float(c[2]))
	var p := bot.player()
	if p != null and bool(sc.get("crowd", false)):
		var w := IslandWorld.current
		var made := 0
		for i in CROWD:
			var a := TAU * float(i) / float(CROWD)
			var r := 7.0 + 4.0 * float(i % 2)
			var q := p.global_position + Vector3(cos(a), 0.0, sin(a)) * r
			if w != null and not w.is_walkable(q.x, q.z):
				continue
			var pos := w.ground(q.x, q.z) if w != null else q
			if bot.spawn(String(CROWD_TYPES[i % CROWD_TYPES.size()]), CROWD_LEVEL, pos) != null:
				made += 1
		bot.check(made * 2 >= CROWD, "толпа зверей: %d из %d" % [made, CROWD])
	if bool(sc.get("battle", false)):
		_cast_cd = 0.0
		_skill_i = 0
		_battle_mobs()


func _leave() -> void:
	bot.clear_spawned()
	bot.reset_camera()
	var p := bot.player()
	if p != null:
		p.select_target(null)


## Звери боя: держать BATTLE живых перед героем.
func _battle_mobs() -> void:
	var alive := bot.spawned_alive().size()
	var k := 0
	while alive < BATTLE and k < BATTLE * 2:
		var side := (float(alive) - float(BATTLE - 1) / 2.0) * 2.2
		bot.spawn(BATTLE_TYPE, BATTLE_LEVEL, bot.ahead(5.0, side))
		alive += 1
		k += 1


## Каждый кадр боя: HP и MP полные, звери на месте, цель — ближайший зверь боя, умения по кругу, иначе обычная атака.
func _battle_tick(dt: float) -> void:
	var p := bot.player()
	if p == null:
		return
	_refill -= dt
	if _refill <= 0.0:
		_refill = 0.5
		p.hp = p.max_hp
		p.mp = p.max_mp
		_battle_mobs()
	var target: Mob = null
	for v in bot.spawned_alive():
		var m := v as Mob
		if target == null or m.global_position.distance_to(p.global_position) < target.global_position.distance_to(
				p.global_position):
			target = m
	if target == null:
		return
	if p.current_target != target:
		p.select_target(target)
	_cast_cd -= dt
	if p.casting != "":
		return
	if _cast_cd <= 0.0:
		for n in HeroSkills.SLOTS:
			var slot := "skill%d" % ((_skill_i + n) % HeroSkills.SLOTS + 1)
			if p.skill_id(slot) == "" or p.cooldown_frac(slot) > 0.0:
				continue
			_skill_i = (_skill_i + n + 1) % HeroSkills.SLOTS
			_cast_cd = 0.4
			p.use_skill(slot)
			return
	p.try_attack()
