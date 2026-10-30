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
## Умения Бродяги для кадров окна героя [id, уровень].
const HERO_SKILLS := [["blade_mastery", 2], ["charge_stab", 2], ["dark_strike", 1], ["evasion_expert", 2],
	["concentration", 1], ["crossbow_mastery", 1], ["dual_shot", 1]]


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
			player.global_position = Vector3(0, 0.1, 1.0)
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
			# Бродяга: окно героя (вкладка «Герой» с 7 характеристиками и боевыми показателями, древо «Мечи и кинжалы»)
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
			ok_done()


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
