extends "res://tests/test_base.gd"
## Исправления по отчёту Максима после 0.39 (в подземелье): звери обходят препятствия (IslandWorld.Route по сетке
## CardinalNav), дальность «В подземелье» (Quality.dungeon_range, объекты и монстры), карточка предмета в сумке —
## своя прокрутка до кнопок, усиления на время (благословения жрицы) переживают переход через портал (и на питомце),
## проклятия Проклятого капитана на героя (оглушение, скорость атаки и бег ниже, защита ниже, яд) раз в 30 с.

var gob: Mob = null
var goal := Vector3.ZERO
var d0 := 0.0
var first_main: Node = null
var hp_before := 0
var resume_at := Vector3.ZERO


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 30


func before_start() -> void:
	Game.location = "dungeon"
	Game.add_pet("wolf", PetData.stage_name("wolf", 0), 20)


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			_dungeon_range()
			_card_scroll()
			_curses()
			_detour_start()
			wait = 2
			step = 1
		1:
			_poison_tick()
			# Бой с обходом: до 12 с игрового времени
			wait = 720
			step = 2
		2:
			_detour_done()
			_carry_start()
			step = 3
		3:
			if main == first_main or not bool(main.get("_started")):
				return
			wait = 30
			step = 4
		4:
			_carry_done()
			_resume_start()
			step = 5
		5:
			if main == first_main or not bool(main.get("_started")):
				return
			wait = 10
			step = 6
		6:
			_resume_done()
			_gentle()
			_auto_start()
			wait = 90
			step = 7
		7:
			_auto_done()
			ok_done()


func _w() -> DungeonWorld:
	return main.get("world") as DungeonWorld


# ---------- 2. Дальность в подземелье ----------

func _dungeon_range() -> void:
	check(Quality.dungeon_range_level() == Quality.DUNGEON_RANGES.size() - 1, "в тестах — «Все» (как и звери острова)")
	var saved := Quality.mob_range_override
	Quality.mob_range_override = -1
	Quality.set_dungeon_range_level(0, false)
	check(is_equal_approx(Quality.dungeon_range(), 20.0) and is_equal_approx(Quality.mob_range(), 20.0),
		"«В подземелье» 20 м — и монстры в подземелье (%.0f)" % Quality.mob_range())
	Quality.set_dungeon_range_level(1, false)
	check(is_equal_approx(Quality.mob_range(), 30.0), "по умолчанию — 30 м")
	Game.location = "island"
	check(is_equal_approx(Quality.mob_range(), float(Quality.MOB_RANGES[Quality.mob_range_level()])), "на острове — «Звери вокруг»")
	Game.location = "dungeon"
	Quality.mob_range_override = saved
	# Настройки: строка «В подземелье»
	SettingsMenu.open(main.hud, "graphics")
	check(SettingsMenu.buttons.has("dg_view_0") and SettingsMenu.buttons.has("dg_view_1"), "в настройках — «В подземелье»")
	main.hud.close_window()


# ---------- 3. Карточка предмета прокручивается ----------

func _card_scroll() -> void:
	Game.inventory.add("weapon_sword_1h_r1", 1)
	var eco: Economy = main.get("economy")
	eco.open_bag()
	var win: InventoryWindow = eco.window
	win.select_cell(Game.inventory.find_cell("weapon_sword_1h_r1"))
	var box := win.card_box
	check(box != null and is_instance_valid(box), "карточка — в своей прокрутке")
	if box != null:
		check(box.custom_minimum_size.y > 100.0 and box.custom_minimum_size.y <= 720.0,
			"высота прокрутки карточки — с окно (%.0f)" % box.custom_minimum_size.y)
		var eq: Variant = win.buttons.get("act_equip")
		check(eq != null and box.is_ancestor_of(eq), "кнопки карточки — внутри прокрутки (до них можно долистать)")
		var panel := box.get_child(0) as Control
		check(panel != null and panel.mouse_filter == Control.MOUSE_FILTER_PASS, "панель карточки не забирает касание")
	main.hud.close_window()


# ---------- 6. Проклятия капитана ----------

func _curses() -> void:
	var p: Player = main.player
	AdminPanel.god = false
	p.max_hp = 1000000
	p.hp = p.max_hp
	var cap: Mob = main.spawn_mob("dg_captain", -1, p.global_position + Vector3(3.0, 0.0, 0.0))
	check(not MobData.curses_of("dg_captain").is_empty() and float(MobData.curses_of("dg_captain")["every"]) == 30.0,
		"у капитана проклятия раз в 30 с")
	for e in MobData.curses_of("dg_captain")["list"]:
		check(float((e as Array)[1]) <= 5.0, "проклятие %s — не дольше 5 с" % (e as Array)[0])
	# Оглушение: стоит, не бьёт, умения нельзя
	p.curse("stun", 2.0, 0.0, cap)
	check(p.stun_left > 1.9 and p.effects.has("curse:stun"), "оглушение 2 с — значок")
	p.attack_cd = 0.0
	check(not p.try_attack(), "оглушён — не бьёт")
	# Скорость атаки, бег, защита
	var asp0 := p.attack_time
	var spd0 := p.cur_speed()
	var def0 := p.defense
	p.curse("aslow", 5.0, 0.15, cap)
	p.curse("slow", 5.0, 0.15, cap)
	p.curse("armor", 5.0, 0.10, cap)
	check(p.attack_time > asp0, "скорость атаки ниже (удар раз в %.2f → %.2f с)" % [asp0, p.attack_time])
	check(p.cur_speed() < spd0 * 0.9, "бег медленнее (%.2f → %.2f)" % [spd0, p.cur_speed()])
	check(p.defense < def0, "защита ниже (%d → %d)" % [def0, p.defense])
	check(p.effects.has("buff:curse_slow") and bool(p.effects.get_entry("buff:curse_slow").get("debuff", false)),
		"ослабления — красные значки")
	# Яд
	hp_before = p.hp
	p.curse("poison", 5.0, 100.0, cap)
	check(p.poison_left > 4.9, "яд на 5 с")
	# Сам капитан в бою: проклятие раз в every
	cap.target = p
	cap.curse_now(p)
	check(cap.curse_uses == 1 and cap.last_curse.size() == 3, "капитан наложил проклятие: %s" % [cap.last_curse])
	cap.consume()


func _poison_tick() -> void:
	var p: Player = main.player
	# Прошло 2 кадра ≈ 0.03 с — за первую секунду урона ещё нет; ждём секунду на шаге 1 (wait 720)
	check(p.stun_left < 2.0, "оглушение проходит")


# ---------- 1. Звери обходят препятствия ----------

func _detour_start() -> void:
	var w := _w()
	var p: Player = main.player
	AdminPanel.god = true
	var found := false
	for sc in w._solid_circles():
		var c: Vector2 = sc[0]
		var r := float(sc[1])
		if r < 0.8:
			continue
		for ang in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
			var dv := Vector2(cos(ang), sin(ang)) * (r + 2.5)
			var a := Vector3(c.x + dv.x, 0.0, c.y + dv.y)
			var b := Vector3(c.x - dv.x, 0.0, c.y - dv.y)
			if not (w.is_walkable(a.x, a.z) and w.is_walkable(b.x, b.z) and CardinalNav.free_at(a) and CardinalNav.free_at(b)):
				continue
			if w.room_at(a.x, a.z) == "" or w.room_at(b.x, b.z) == "":
				continue
			var rt := IslandWorld.Route.new()
			if not rt._blocked(w, a, b) or CardinalNav.path(a, b).is_empty():
				continue
			goal = w.ground(b.x, b.z, 0.2)
			p.global_position = goal
			gob = main.spawn_mob("dg_goblin", -1, w.ground(a.x, a.z, 0.2))
			found = true
			break
		if found:
			break
	check(found, "нашлось препятствие с проходом вокруг")
	if gob == null:
		return
	d0 = Vector2(gob.global_position.x - goal.x, gob.global_position.z - goal.z).length()
	gob.target = p


func _detour_done() -> void:
	if gob == null or not is_instance_valid(gob):
		return
	var p: Player = main.player
	var d := Vector2(gob.global_position.x - p.global_position.x, gob.global_position.z - p.global_position.z).length()
	print("ОБХОД: зверь был в %.1f м за препятствием, через 12 с — в %.1f м, обходов пути %d" % [d0, d, gob._route.detours])
	check(gob._route.detours > 0, "зверь строил путь в обход препятствия")
	check(d < gob._reach() + 1.5, "зверь обошёл препятствие и добрался до героя (%.1f м)" % d)
	# Яд за это время прошёл: урон без защиты, по 100 в секунду (бессмертие включили — урон после 1 с был)
	check(p.poison_left <= 0.0, "яд закончился за 5 с")
	gob.consume()


# ---------- 5. Усиления переживают портал ----------

func _carry_start() -> void:
	var p: Player = main.player
	AdminPanel.god = true
	main.pets.summon(0)
	var pet: Pet = main.pets.active_pet
	check(pet != null, "волк призван")
	Game.gold += 100000
	check(Blessing.give(p, "might", pet) == "", "благословение силы куплено")
	check(p.timed_bonus.has("bless_might"), "на герое благословение")
	check(pet == null or pet.hero_buffs.has("bless_might"), "на волке благословение")
	first_main = main
	main.travel("island")


func _carry_done() -> void:
	var p: Player = main.player
	check(Game.location == "island", "перешли на остров")
	check(p.timed_bonus.has("bless_might") and float(p.timed_bonus["bless_might"]["left"]) > 3500.0,
		"благословение на герое после портала (осталось %.0f с)" % float(p.timed_bonus.get("bless_might", {}).get("left", 0.0)))
	check(p.effects.has("buff:bless_might"), "значок благословения на месте")
	var pet: Pet = main.pets.active_pet
	check(pet != null and pet.hero_buffs.has("bless_might"), "благословение на волке после портала")


# ---------- 7. Вход в игру — там, где вышел ----------

func _resume_start() -> void:
	var p: Player = main.player
	var w: IslandWorld = main.world
	var sp := w.spawn_point(Game.race_id)
	var at := Vector3.INF
	for r in [40.0, 30.0, 50.0, 25.0]:
		for k in 8:
			var a := k * PI / 4.0
			var q := Vector3(sp.x + cos(a) * r, 0.0, sp.z + sin(a) * r)
			if w.is_walkable(q.x, q.z):
				at = w.ground(q.x, q.z, 0.2)
				break
		if at != Vector3.INF:
			break
	check(at != Vector3.INF, "есть проходимая точка вдали от деревни")
	p.global_position = at
	var d: Dictionary = Game.to_dict()
	var pos: Dictionary = d.get("pos", {})
	check(String(pos.get("loc", "")) == "island" and Vector2(float(pos.get("x", 0)) - at.x, float(pos.get("z", 0)) - at.z).length() < 0.1,
		"в сохранении — место героя: %s" % [pos])
	check(main.resume_ok(pos), "точка годится для входа")
	check(not main.resume_ok({"loc": "dungeon", "x": at.x, "y": at.y, "z": at.z}), "точка другой локации — нет")
	resume_at = at
	# Перезапуск: состояние — из сохранения (как вход в игру)
	Game.from_dict(JSON.parse_string(JSON.stringify(d)))
	Game.arrive = ""
	first_main = main
	main.restart_scene()


func _resume_done() -> void:
	var p: Player = main.player
	var d := Vector2(p.global_position.x - resume_at.x, p.global_position.z - resume_at.z).length()
	check(d < 1.0, "после перезапуска герой там же, где вышел (%.2f м)" % d)
	# Погиб — в сохранение места нет (возрождение в деревне)
	p.hp = 0
	check(Game.to_dict().get("pos", {}).is_empty(), "погибший — без места выхода")


# ---------- Тест-бот: щадящий режим (отчёт 0.40.0: телефон не остывал в паузе — бот сдался на 49 из 68) ----------

var _st := 2
var _hr := 900


func _gentle() -> void:
	var bot := TestBot.new()
	bot.scenario = BotScenarioCardinalStory.new()
	bot.status_source = func() -> int: return _st
	bot.headroom_source = func() -> int: return _hr
	bot.cool_min = 0.1
	bot.cool_max = 0.3
	bot.poll = 0.05
	main.get_tree().root.add_child(bot)
	var ts := Engine.time_scale
	var ticks := Engine.physics_ticks_per_second
	Engine.time_scale = 32.0
	Engine.physics_ticks_per_second = 60 * 32
	bot.state = "running"
	bot._watch(0.1, 0.016)
	check(bot.state == "cooling", "статус 2 — пауза на остывание")
	for i in 5:
		if bot.state == "cooling":
			bot._tick_cooling(0.1)
	check(bot.state == "running" and bot.gentle, "не остыл за паузу — щадящий режим, тест продолжается")
	check(is_equal_approx(Engine.time_scale, 8.0) and Engine.physics_ticks_per_second == 60 * 8,
		"нагрузка ниже: ускорение ×32 → ×%.0f, тиков %d" % [Engine.time_scale, Engine.physics_ticks_per_second])
	check("\n".join(bot.journal).contains("Щадящий режим"), "в журнале — щадящий режим")
	bot._watch(0.1, 0.016)
	check(bot.state == "running", "статус 2 при запасе 0.90 — без новой паузы")
	_hr = 960
	bot._watch(0.1, 0.016)
	check(bot.state == "cooling", "запас дошёл до 0.96 — пауза")
	bot._end_cooling()
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = ticks
	main.get_tree().paused = false
	main.get_tree().root.disable_3d = false
	bot.queue_free()


# ---------- Автоатака: удержание «Атаки» включает и выключает ----------

var _wolf: Mob = null
var _wolf_hp := 0


func _auto_start() -> void:
	var p: Player = main.player
	AdminPanel.god = true
	_wolf = main.spawn_mob("wolf", 30, p.global_position + Vector3(0, 0, 1.6))
	_wolf.max_hp = 10000000
	_wolf.hp = _wolf.max_hp
	_wolf_hp = _wolf.hp
	p.current_target = _wolf
	check(not main.auto_attack, "автоатака по умолчанию выключена")
	# Удержание дольше AUTO_HOLD — включилась, отпустили — осталась включённой
	main.hud._buttons["attack"]["touch"] = 7
	for i in 6:
		main._auto_attack_tick(0.15)
	main.hud._buttons["attack"]["touch"] = -1
	main._auto_attack_tick(0.016)
	check(main.auto_attack, "удержание «Атаки» — автоатака включена")
	check(main.hud._msg_label.text.contains("Автоатака включена"), "сообщение: %s" % main.hud._msg_label.text)
	# Короткое нажатие не переключает
	main.hud._buttons["attack"]["touch"] = 7
	main._auto_attack_tick(0.2)
	main.hud._buttons["attack"]["touch"] = -1
	main._auto_attack_tick(0.016)
	check(main.auto_attack, "короткое нажатие автоатаку не выключает")


func _auto_done() -> void:
	check(_wolf != null and is_instance_valid(_wolf) and _wolf.hp < _wolf_hp, "кнопку не держат — герой бьёт сам (HP волка %d → %d)"
		% [_wolf_hp, _wolf.hp if _wolf != null and is_instance_valid(_wolf) else -1])
	main.hud._buttons["attack"]["touch"] = 7
	for i in 6:
		main._auto_attack_tick(0.15)
	main.hud._buttons["attack"]["touch"] = -1
	main._auto_attack_tick(0.016)
	check(not main.auto_attack, "снова удержание — автоатака выключена")
	var hp := _wolf.hp
	await main.get_tree().create_timer(1.5).timeout
	if is_instance_valid(_wolf):
		check(_wolf.hp == hp or _wolf.target == main.player, "выключена — герой не бьёт выбранную цель сам")
		_wolf.consume()
