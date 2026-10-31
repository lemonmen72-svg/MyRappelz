extends "res://tests/test_base.gd"
## Скриншоты ключевых сцен для проверки графики (CI с настоящим рендером, не headless).
## Сохраняет PNG в user://shots/. Запуск без --headless, например под xvfb:
## godot --rendering-driver opengl3 --fixed-fps 30 --path . res://tests/runner.tscn -- res://tests/shots.gd

const SHOTS_DIR := "user://shots/"

## Новые звери (пантера, черепаха, фазан) крупно в ряд — кадры 15 и 16.
const ROW := ["panther", "turtle", "pheasant"]
## Окно существа (кадры 17 и 18): пантера 20 ур. (2-я стадия) с изученными умениями [id, уровень].
const SHOWCASE_SKILLS := [
	["inner_fire", 6], ["hardening", 3], ["shadow_rend", 6], ["dusk_rupture", 3], ["vitality", 3],
	["daze", 2], ["shadow_fang", 3], ["provoke", 1], ["calm_mind", 2], ["shadow_bond", 2],
]

var _create: Node = null
var _top: Camera3D = null
var _row: Node3D = null
var _frames := 0
## Рыба для кадра 54 (убитая падает на землю).
var _fish: Variant = null
## Летающие рыбы в ряд рядом с героем — кадр 52.
const FISH_ROW := ["flyfish", "flyfish_sail", "flyfish_drake"]
## Умения Наёмника для кадров окна героя [id, уровень].
const HERO_SKILLS := [["blade_mastery", 2], ["charge_stab", 2], ["dark_strike", 1], ["evasion_expert", 2],
	["concentration", 1], ["crossbow_mastery", 1], ["dual_shot", 1]]
## Предметы для кадров сумки и торговца (27–30): [id, количество]. Карты существ: пустые, с душой, зеркальная.
const BAG_ITEMS := [
	["daggers_steel", 1], ["crossbow_heavy", 1], ["card_panther", 4], ["card_wolf", 1], ["card_turtle", 1],
	["card_panther_soul", 1], ["card_wolf_soul", 1], ["mirror_card", 2], ["boar_tusk", 7],
	["wolf_pelt", 3], ["panther_fang", 2], ["pheasant_feather", 4], ["shell_plate", 2], ["golem_shard", 1],
	["hp_potion", 12],
]


func race_class() -> Array:
	return ["light_elf", "cleric"]


func before_start() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS_DIR))
	Quality.set_level(Quality.HIGH, false)
	game.add_pet("wolf", "Серохвост", 5)
	game.active_pet = 0
	var i: int = game.add_pet("panther", PetData.stage_name("panther", 20), 20)
	var rec: Dictionary = game.pets[i]
	for e in SHOWCASE_SKILLS:
		for k in int(e[1]):
			PetSkills.learn(rec, String(e[0]))
	(rec["toggles"] as Dictionary)["shadow_bond"] = true


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			# Вид острова сверху (север сверху) — для сверки с reference/training_island.png
			_top = Camera3D.new()
			_top.projection = Camera3D.PROJECTION_ORTHOGONAL
			_top.size = 205.0
			_top.far = 600.0
			_top.rotation_degrees = Vector3(-90, 0, 0)
			_top.position = Vector3(1.0, 250.0, -3.0)
			main.add_child(_top)
			_top.current = true
			IslandVegetation.set_far_view(get_tree(), true)
			main.hud.visible = false
			_set_fog(false)
			wait = 90
			step = 100
		100:
			shot("00_island_top")
			IslandVegetation.set_far_view(get_tree(), false)
			main.hud.visible = true
			_set_fog(true)
			_top.current = false
			main.cam.current = true
			_top.queue_free()
			wait = 20
			step = 1
		1:
			shot("01_start")
			var m := find_mob("boar")
			if m != null:
				stand_near(m, 4.0)
			wait = 45
			step = 2
		2:
			shot("02_mobs")
			player.try_attack()
			player.use_skill("skill1")
			wait = 8
			step = 3
		3:
			shot("03_combat")
			var g := find_mob("golem")
			if g != null:
				stand_near(g, 7.0)
			wait = 60
			step = 4
		4:
			shot("04_golem")
			var f := find_mob("pheasant")
			if f != null:
				stand_near(f, 4.0)
			wait = 60
			step = 5
		5:
			shot("05_pheasant")
			# Рядом с торговцем (дальше SHOP_RANGE окно торговца закрывается само)
			player.global_position = Vector3(0, 0.1, -1.5)
			wait = 60
			step = 6
		6:
			main.economy.open_shop()
			wait = 5
			step = 7
		7:
			shot("06_shop")
			main.hud.close_window()
			main.pets.handle_action("pets_window")
			wait = 5
			step = 8
		8:
			shot("07_pets")
			main.hud.close_window()
			_create = CharacterCreate.new()
			get_tree().root.add_child(_create)
			wait = 10
			step = 9
		9:
			shot("08_create")
			_create.queue_free()
			# Главный герой крупно спереди: стойка покоя, затем удар
			_top = Camera3D.new()
			main.add_child(_top)
			var front := player._model.global_transform.basis * Vector3(0, 0, -1)
			front.y = 0.0
			_top.global_position = player.global_position + front.normalized() * 2.8 + Vector3(0, 1.3, 0)
			_top.look_at(player.global_position + Vector3(0, 0.95, 0))
			_top.current = true
			main.hud.visible = false
			wait = 30
			step = 10
		10:
			shot("09_hero")
			player._model.play_attack()
			wait = 12
			step = 11
		11:
			shot("10_hero_attack")
			player._model.play_buff()
			wait = 25
			step = 12
		12:
			shot("11_hero_skill")
			# Город с рисованными текстурами (площадь, улицы, дома) на трёх уровнях качества
			_top.global_position = Vector3(7.0, 4.5, -2.0)
			_top.look_at(Vector3(-1.0, 2.2, -14.0))
			Quality.set_level(Quality.HIGH, false)
			Quality.apply(get_tree())
			wait = 20
			step = 13
		13:
			shot("12_town_high")
			Quality.set_level(Quality.MEDIUM, false)
			Quality.apply(get_tree())
			wait = 20
			step = 14
		14:
			shot("13_town_medium")
			Quality.set_level(Quality.LOW, false)
			Quality.apply(get_tree())
			wait = 20
			step = 15
		15:
			shot("14_town_low")
			Quality.set_level(Quality.HIGH, false)
			Quality.apply(get_tree())
			_build_row()
			wait = 30
			step = 16
		16:
			shot("15_creatures")
			_frames = 0
			step = 17
		17:
			# Те же звери на ходу: шаг (модель из файла — клип Walk, запасная — перестановка лап)
			_frames += 1
			_animate_row(_frames)
			if _frames >= 24:
				shot("16_creatures_walk")
				_row.queue_free()
				main.player.visible = true
				_top.queue_free()
				main.cam.current = true
				main.hud.visible = true
				# Окно существа: пантера с изученными умениями, обе вкладки
				main.pets.summon(1)
				wait = 5
				step = 18
		18:
			main.pets.open_creature(1, "stats")
			wait = 30
			step = 19
		19:
			shot("17_creature_stats")
			main.pets.open_creature(1, "skills")
			wait = 10
			step = 20
		20:
			shot("18_creature_skills")
			main.hud.close_window()
			# Наёмник: окно героя (вкладка «Герой» с 7 характеристиками и боевыми показателями, древо «Мечи и кинжалы»)
			main.pets.recall()
			game.race_id = "dark_elf"
			game.class_id = "assassin"
			game.level = 7
			player.apply_class()
			game.hero["jp"] = 40
			for e in HERO_SKILLS:
				for k in int(e[1]):
					HeroSkills.learn(game.hero, "assassin", game.level, String(e[0]))
			player.refresh_skills()
			player.set_toggle("concentration", true)
			# Вкладка «Герой»: 7 характеристик, боевые показатели, неполные HP и MP
			player.hp = roundi(player.max_hp * 0.8)
			player.mp = roundi(player.max_mp * 0.65)
			main.hero_window.open("hero")
			wait = 40
			step = 21
		21:
			shot("19_hero_window")
			main.hero_window.selected = "dark_strike"
			main.hero_window.open("blades")
			wait = 10
			step = 22
		22:
			shot("20_hero_tree")
			main.hero_window.open("crossbow")
			wait = 10
			step = 23
		23:
			shot("21_hero_tree_crossbow")
			main.hud.close_window()
			# Герой крупно: арбалет на изготовку, выстрел, парные мечи, парные кинжалы
			player.equip("crossbow_starter")
			_front_camera()
			wait = 40
			step = 24
		24:
			shot("22_hero_crossbow")
			player._model.play_attack()
			wait = 5
			step = 25
		25:
			shot("23_hero_crossbow_shot")
			player.equip("dual_swords_starter")
			wait = 40
			step = 26
		26:
			shot("24_hero_dual_swords")
			player._model.play_attack()
			wait = 10
			step = 27
		27:
			shot("25_hero_dual_attack")
			player.equip("daggers_starter")
			wait = 40
			step = 28
		28:
			shot("26_hero_daggers")
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			# Сумка с добычей и покупками, у торговца
			for e in BAG_ITEMS:
				game.inventory.add(String(e[0]), int(e[1]))
			player.global_position = Vector3(0, 0.1, -1.5)
			wait = 10
			step = 29
		29:
			# Окно сумки: карточка стальных кинжалов (сравнение с надетыми)
			main.economy.open_bag()
			main.economy.window.select_cell(game.inventory.find_cell("daggers_steel"))
			wait = 8
			step = 30
		30:
			shot("27_inventory")
			# Окно торговца: товары, сумка, карточка тяжёлого арбалета
			main.economy.open_shop()
			main.economy.window._on_cell("good", InventoryWindow.goods(game.class_id).find("crossbow_heavy"))
			wait = 8
			step = 31
		31:
			shot("28_shop")
			main.hud.close_window()
			# Сумка с картами существ: карточка карты с душой (кнопка «Сформировать»)
			main.economy.open_bag()
			main.economy.window.select_cell(game.inventory.find_cell("card_panther_soul"))
			wait = 8
			step = 32
		32:
			shot("29_bag_soul_card")
			# Карточка пустой карты: где водится вид, уровни, тир, где взять, что делать
			main.economy.window.select_cell(game.inventory.find_cell("card_panther"))
			wait = 8
			step = 33
		33:
			shot("30_bag_card")
			main.hud.close_window()
			# Панель цели со значком приручения: волк, карта волка в сумке — зелёный значок
			var m := find_mob("wolf")
			if m != null:
				stand_near(m, 4.0)
				player._set_target(m)
			wait = 20
			step = 34
		34:
			shot("31_target_tame")
			# Кабана приручить нельзя — фиолетовый значок
			var m := find_mob("boar")
			if m != null:
				stand_near(m, 4.0)
				player._set_target(m)
			wait = 20
			step = 35
		35:
			shot("32_target_no_tame")
			player._set_target(null)
			# Учитель Кирк в центре города со значком «!» (задание можно взять), кнопка «Говорить»
			_kirk_view()
			wait = 45
			step = 36
		36:
			shot("33_kirk_town")
			main.npcs.talk_to("kirk")
			wait = 8
			step = 37
		37:
			shot("34_kirk_dialog")
			main.npcs.open_dialog("kirk", "quest", "kirk_first_card")
			wait = 8
			step = 38
		38:
			shot("35_kirk_quest_offer")
			# Лавка Кирка: карты существ и зеркальная карта, карточка карты фазана
			main.economy.open_shop("kirk")
			main.economy.window._on_cell("good", InventoryWindow.goods(game.class_id, "kirk").find("card_pheasant"))
			wait = 8
			step = 39
		39:
			shot("36_kirk_shop")
			main.hud.close_window()
			# Журнал: три задания цепочки сданы, «Испытание связи» — 2/5
			for id in ["kirk_first_card", "kirk_soul", "kirk_new_friend"]:
				game.quests_done[id] = 1
			main.quests.accept("kirk_bond_trial")
			game.quests_active["kirk_bond_trial"]["progress"] = [2]
			main.quests.refresh_tracker()
			main.quests.window.open("kirk_bond_trial")
			wait = 8
			step = 40
		40:
			shot("37_quest_journal")
			main.hud.close_window()
			wait = 20
			step = 41
		41:
			# Трекер справа вверху под меню; над Кирком серый «?»
			shot("38_quest_tracker")
			# Текстуры локации крупно («Высокое»): деревня людей — колодец (кладка, ворот-бревно),
			# цоколи домов (кладка), доски, черепица и солома
			main.hud.visible = false
			_top = Camera3D.new()
			main.add_child(_top)
			_top.current = true
			_look_from(Vector2(82.5, 27.5), 2.0, Vector2(94.0, 17.3), 1.6)
			wait = 40
			step = 42
		42:
			shot("39_village_close")
			# Загон: ограда из брёвен (столбики — кора, жерди — лежачее бревно)
			_look_from(Vector2(95.5, 43.5), 1.5, Vector2(90.0, 37.0), 0.6)
			wait = 30
			step = 43
		43:
			shot("40_fence_close")
			# Мост: настил из досок, столбики перил — кора, поручни — бревно
			var w := IslandWorld.current
			if w != null and not w.bridges.is_empty():
				var a: Vector3 = w.bridges[0]["a"]
				var e: Vector3 = w.bridges[0]["b"]
				var mid := (a + e) * 0.5
				var side := Vector2(-(e.z - a.z), e.x - a.x).normalized()
				var from := Vector2(mid.x, mid.z) + side * 5.0 + Vector2(e.x - a.x, e.z - a.z).normalized() * 2.0
				_top.global_position = Vector3(from.x, maxf(w.height_at(from.x, from.y), mid.y) + 1.8, from.y)
				_top.look_at(mid + Vector3(0, 0.4, 0))
			wait = 30
			step = 44
		44:
			shot("41_bridge_close")
			# Лес светлых эльфов: лесная подстилка под деревьями (листья, мох), граница с травой
			var p := _forest_spot(Vector2(-50.0, -54.0), 26.0)
			_look_from(p + Vector2(0.0, 7.0), 3.4, p, 0.0)
			wait = 40
			step = 45
		45:
			shot("42_forest_floor")
			# Лес тёмных эльфов (мёртвая роща): та же подстилка с холодным оттенком зоны
			var p := _forest_spot(Vector2(38.0, -56.0), 26.0)
			_look_from(p + Vector2(0.0, 7.0), 3.4, p, 0.0)
			wait = 40
			step = 46
		46:
			shot("43_dead_grove_floor")
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			SettingsMenu.open(main.hud)
			wait = 5
			step = 47
		47:
			shot("44_settings")
			main.hud.close_window()
			# HUD при «Мелком» и «Крупном» размере интерфейса (UiScale; без сохранения в настройки)
			UiScale.set_level(UiScale.SMALL, false)
			main.hud.apply_ui_scale()
			wait = 5
			step = 48
		48:
			shot("45_hud_small")
			UiScale.set_level(UiScale.LARGE, false)
			main.hud.apply_ui_scale()
			wait = 5
			step = 49
		49:
			shot("46_hud_large")
			main.hero_window.open("blades")
			wait = 8
			step = 50
		50:
			shot("47_hero_skills_large")
			main.hud.close_window()
			main.economy.open_bag()
			wait = 5
			step = 51
		51:
			shot("48_bag_large")
			main.hud.close_window()
			UiScale.set_level(UiScale.MEDIUM, false)
			main.hud.apply_ui_scale()
			step = 520
		520:
			# Летающие рыбы рядом с героем: парят на уровне его головы
			_fish_row()
			wait = 40
			step = 521
		521:
			shot("52_flyfish_row")
			_row.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			_fish_view("flyfish_sail", 5.0)
			wait = 60
			step = 522
		522:
			shot("53_flyfish_world")
			_fish = _fish_view("flyfish", 4.0)
			wait = 30
			step = 523
		523:
			# Убитая рыба падает на землю (клип Death)
			if mob_ok(_fish):
				(_fish as Mob).take_damage((_fish as Mob).hp + 5, main.player)
			wait = 90
			step = 524
		524:
			shot("54_flyfish_dead")
			ok_done()


## Игрок в 3 м от Учителя Кирка (со стороны площади), камера за игроком чуть сбоку — Кирк в кадре.
func _kirk_view() -> void:
	var player: Player = main.player
	var kp: Vector3 = main.npcs.kirk.global_position
	var to_c := Vector3(-kp.x, 0, -kp.z).normalized()
	player.global_position = kp + to_c * 3.0 + Vector3(0, 0.1, 0)
	main.cam_yaw = atan2(to_c.x, to_c.z) + 0.35
	main.cam_pitch = 0.33
	main.cam_dist = 6.5


## Камера _top из точки from (x, z) на высоте h над землёй смотрит на точку to на высоте th над землёй.
func _look_from(from: Vector2, h: float, to: Vector2, th: float) -> void:
	var w := IslandWorld.current
	var fy := w.height_at(from.x, from.y) if w != null else 0.0
	var ty := w.height_at(to.x, to.y) if w != null else 0.0
	_top.global_position = Vector3(from.x, fy + h, from.y)
	_top.look_at(Vector3(to.x, ty + th, to.y))


## Точка с самым густым лесом (вес леса IslandWorld.forest_at) в круге r вокруг c, подальше от стволов.
func _forest_spot(c: Vector2, r: float) -> Vector2:
	var w := IslandWorld.current
	var best := c
	var best_v := -1.0
	if w == null:
		return best
	var y := -r
	while y <= r:
		var x := -r
		while x <= r:
			var q := c + Vector2(x, y)
			if Vector2(x, y).length() <= r and w.is_walkable(q.x, q.y) and w.road_distance(q.x, q.y) > 3.0:
				var v := w.forest_at(q.x, q.y)
				if v > best_v:
					best_v = v
					best = q
			x += 2.0
		y += 2.0
	print("  лес у %s: вес %.2f в %s" % [c, best_v, best])
	return best


## Камера спереди на героя (как кадры 09–11), HUD скрыт.
func _front_camera() -> void:
	var player: Player = main.player
	_top = Camera3D.new()
	main.add_child(_top)
	var front := player._model.global_transform.basis * Vector3(0, 0, -1)
	front.y = 0.0
	# Чуть сбоку: видно обе руки и оружие
	var side := front.normalized().rotated(Vector3.UP, 0.45)
	_top.global_position = player.global_position + side * 2.6 + Vector3(0, 1.35, 0)
	_top.look_at(player.global_position + Vector3(0, 1.0, 0))
	_top.current = true
	main.hud.visible = false


## Пантера, черепаха и фазан в ряд перед камерой (вид три четверти), игрок и питомец скрыты.
func _build_row() -> void:
	var player: Player = main.player
	main.pets.recall()
	player.visible = false
	var base := player.global_position
	_row = Node3D.new()
	_row.name = "CreatureRow"
	main.add_child(_row)
	for i in ROW.size():
		var id := String(ROW[i])
		var holder := Node3D.new()
		holder.set_meta("species", id)
		_row.add_child(holder)
		var d := MobData.get_type(id)
		CreatureModels.build(holder, id, d["color"], float(d["scale"]))
		var gp := base + Vector3((float(i) - 1.0) * 2.2, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		holder.global_position = gp
		# Перед модели (−Z) — к камере (+Z), с поворотом на три четверти
		holder.rotation.y = PI + 0.7
		var ca := CreatureModels.asset_of(holder)
		print("  %s: %s, высота %.2f м" % [id, "модель из файла" if ca != null else "запасная из примитивов",
			CreatureModels.height(id, float(d["scale"]))])
	_top.global_position = base + Vector3(0, 1.15, 3.9)
	_top.look_at(base + Vector3(0, 0.5, 0))


## Герой слева, три летающие рыбы в ряд справа (клип Idle), камера сбоку чуть сверху, HUD скрыт.
func _fish_row() -> void:
	var player: Player = main.player
	main.pets.recall()
	player.visible = true
	var base := player.global_position
	_row = Node3D.new()
	_row.name = "FishRow"
	main.add_child(_row)
	for i in FISH_ROW.size():
		var id := String(FISH_ROW[i])
		var holder := Node3D.new()
		holder.set_meta("species", id)
		_row.add_child(holder)
		var d := MobData.get_type(id)
		CreatureModels.build(holder, id, d["color"], float(d["scale"]))
		var gp := base + Vector3(1.4 + 2.4 * float(i), 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		holder.global_position = gp
		holder.rotation.y = PI + 0.9
	_top = Camera3D.new()
	main.add_child(_top)
	_top.global_position = base + Vector3(3.0, 1.9, 7.0)
	_top.look_at(base + Vector3(3.0, 1.2, 0))
	_top.current = true
	main.hud.visible = false


## Игрок в dist м от ближайшей рыбы вида id, рыба — цель, камера за игроком смотрит на рыбу. Возвращает рыбу.
func _fish_view(id: String, dist: float) -> Mob:
	var f := find_mob(id)
	if f == null:
		return null
	stand_near(f, dist)
	main.player._set_target(f)
	var d: Vector3 = main.player.global_position - f.global_position
	main.cam_yaw = atan2(d.x, d.z) + 0.3
	main.cam_pitch = 0.22
	main.cam_dist = 6.0
	return f


func _animate_row(frame_i: int) -> void:
	for n in _row.get_children():
		var holder := n as Node3D
		var id := String(holder.get_meta("species"))
		var ca := CreatureModels.asset_of(holder)
		if ca != null:
			ca.update(1.0 / 30.0, float(ca.info["walk_speed"]) * float(MobData.get_type(id)["scale"]))
		else:
			CreatureModels.animate(holder, id, float(frame_i) / 30.0, 0.5)


func shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := SHOTS_DIR + shot_name + ".png"
	var err := img.save_png(path)
	check(err == OK, "скриншот %s (%dx%d)" % [shot_name, img.get_width(), img.get_height()])


## Туман на высоте 250 м заливает весь кадр — для вида сверху выключаем.
func _set_fog(on: bool) -> void:
	for n in main.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if we != null and we.environment != null:
			we.environment.fog_enabled = on
