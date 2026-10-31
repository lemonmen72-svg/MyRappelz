extends "res://tests/test_base.gd"
## Скриншоты ключевых сцен для проверки графики (CI с настоящим рендером, не headless).
## Сохраняет PNG в user://shots/. Запуск без --headless, например под xvfb:
## godot --rendering-driver opengl3 --fixed-fps 30 --path . res://tests/runner.tscn -- res://tests/shots.gd

const SHOTS_DIR := "user://shots/"

## Новые звери (пантера, черепаха, фазан) крупно в ряд — кадры 15 и 16. Стадии эволюции питомцев — кадры 49–51.
const ROW := ["panther", "turtle", "pheasant"]
## Окно существа (кадры 17 и 18): пантера 20 ур. (2-я стадия) с изученными умениями [id, уровень].
const SHOWCASE_SKILLS := [
	["inner_fire", 6], ["hardening", 3], ["shadow_rend", 6], ["dusk_rupture", 3], ["vitality", 3],
	["daze", 2], ["shadow_fang", 3], ["provoke", 1], ["calm_mind", 2], ["shadow_bond", 2],
]

var _create: Node = null
## Герои в ряд (кадр 86): прежняя героиня и герои из Meshy (tools/prepare_hero.py).
const HERO_ROW := ["res://assets/characters/dark_elf_wanderer.glb", "res://assets/characters/hero_assassin_m.glb",
	"res://assets/characters/hero_swordsman_f.glb", "res://assets/characters/hero_warrior_m.glb",
	"res://assets/characters/hero_swordsman_m.glb"]
## Второй ряд (кадр 89): героиня-Наёмник, Воин-женщина и Бродяги всех рас и полов.
const HERO_ROW2 := ["res://assets/characters/hero_assassin_f.glb", "res://assets/characters/hero_warrior_f.glb",
	"res://assets/characters/hero_dark_elf_f_starter.glb", "res://assets/characters/hero_dark_elf_m_starter.glb",
	"res://assets/characters/hero_light_elf_f_starter.glb", "res://assets/characters/hero_light_elf_m_starter.glb",
	"res://assets/characters/hero_human_f_starter.glb", "res://assets/characters/hero_human_m_starter.glb"]
## Новые герои (кадр 94): Неофит, Адепт (тёмные эльфы), Волшебник, Зверолов (светлые эльфы), Шаман, Колдун (люди).
const HERO_CASTERS := ["res://assets/characters/hero_neophyte_f.glb", "res://assets/characters/hero_neophyte_m.glb",
	"res://assets/characters/hero_adept_f.glb", "res://assets/characters/hero_adept_m.glb",
	"res://assets/characters/hero_wizard_f.glb", "res://assets/characters/hero_wizard_m.glb",
	"res://assets/characters/hero_beastmaster_f.glb", "res://assets/characters/hero_beastmaster_m.glb",
	"res://assets/characters/hero_shaman_f.glb", "res://assets/characters/hero_shaman_m.glb",
	"res://assets/characters/hero_conjurer_f.glb", "res://assets/characters/hero_conjurer_m.glb"]
## Оружие героев (кадр 91): [модель, вид оружия ItemData, щит во второй руке] — одноручное со щитом, лук, пары,
## посох, двуручное.
const WEAPON_ROW := [
	["res://assets/characters/hero_swordsman_m.glb", "sword_1h", true],
	["res://assets/characters/hero_warrior_m.glb", "bow", false],
	["res://assets/characters/hero_warrior_f.glb", "dual_axes", false],
	["res://assets/characters/hero_assassin_f.glb", "daggers", false],
	["res://assets/characters/hero_swordsman_f.glb", "dual_swords", false],
	["res://assets/characters/hero_dark_elf_m_starter.glb", "staff_2h", false],
	["res://assets/characters/hero_dark_elf_f_starter.glb", "dagger", true],
	["res://assets/characters/hero_human_m_starter.glb", "axe_2h", false],
]
var _heroes: Node3D = null
var _top: Camera3D = null
var _row: Node3D = null
var _frames := 0
## Рыба для кадра 54 (убитая падает на землю).
var _fish: Variant = null
## Летающие рыбы в ряд рядом с героем — кадр 52.
const FISH_ROW := ["flyfish", "flyfish_sail", "flyfish_drake"]
## Анатемы в ряд рядом с героем — кадр 56. Кентавр: стадии рядом с героем — кадр 55, в мире — кадр 58.
const ANATHEMA_ROW := ["anathema", "anathema_blade", "anathema_chief"]
## Умения Наёмника для кадров окна героя [id, уровень].
const HERO_SKILLS := [["blade_mastery", 2], ["charge_stab", 2], ["dark_strike", 1], ["evasion_expert", 2],
	["concentration", 1], ["crossbow_mastery", 1], ["dual_shot", 1]]
## Предметы для кадров сумки и торговца (27–30): [id, количество]. Карты существ: пустые, с душой, зеркальная.
const BAG_ITEMS := [
	["dagger_steel", 1], ["sword_steel", 2], ["crossbow_heavy", 1], ["card_panther", 4], ["card_wolf", 1], ["card_turtle", 1],
	["card_panther_soul", 1], ["card_wolf_soul", 1], ["mirror_card", 2], ["lizard_scale", 7],
	["wolf_pelt", 3], ["panther_fang", 2], ["pheasant_feather", 4], ["shell_plate", 2], ["chief_spike", 1],
	["hp_potion", 12],
]


func race_class() -> Array:
	return ["light_elf", "wizard"]


func before_start() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS_DIR))
	Quality.set_level(Quality.HIGH, false)
	# Звери острова до 30 ур. сильнее героя-новичка: на кадрах рядом со зверями герой не должен погибать
	AdminPanel.god = true
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
			var m := find_mob("pheasant")
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
			# Главный враг пещеры — вожак анатем (каменного стража на острове больше нет)
			var g := find_mob("anathema_chief")
			if g != null:
				stand_near(g, 7.0)
			wait = 60
			step = 4
		4:
			shot("04_anathema_chief")
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
			game.level = 25
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
			game.inventory.add("sword_steel", 2)
			player.equip("sword_steel")
			player.equip("sword_steel", true)
			wait = 40
			step = 26
		26:
			shot("24_hero_dual_swords")
			player._model.play_attack()
			wait = 10
			step = 27
		27:
			shot("25_hero_dual_attack")
			player.equip("weapon_dagger_r1")
			player.equip("weapon_dagger_r1", true)
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
			# Окно сумки: карточка стального кинжала (сравнение с надетым)
			main.economy.open_bag()
			main.economy.window.select_cell(game.inventory.find_cell("dagger_steel"))
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
			# Анатему приручить нельзя — фиолетовый значок
			var m := find_mob("anathema")
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
			# Стадии эволюции питомцев (модели из файлов <вид>, <вид>_2, <вид>_3) — в ряд, размер как у питомца
			_build_stage_row([["panther", 0], ["panther", 1], ["panther", 2]])
			wait = 40
			step = 52
		52:
			_tick_stage_row()
			shot("49_stages_panther")
			_build_stage_row([["pheasant", 0], ["pheasant", 1], ["pheasant", 2], ["turtle", 0], ["turtle", 1], ["turtle", 2]])
			wait = 40
			step = 53
		53:
			_tick_stage_row()
			shot("50_stages_pheasant_turtle")
			_build_stage_row([["wolf", 0], ["wolf", 1], ["wolf", 2]])
			wait = 40
			step = 54
		54:
			_tick_stage_row()
			shot("51_stages_wolf")
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
			step = 540
		540:
			# Кентавр: три стадии рядом с героем (питомец 1-й стадии ростом с героя, к 3-й — выше)
			_build_stage_row([["centaur", 0], ["centaur", 1], ["centaur", 2]])
			var first := _row.get_child(0) as Node3D
			main.player.visible = true
			main.player.global_position = first.global_position + Vector3(-1.3, 0.1, 0.3)
			wait = 40
			step = 541
		541:
			_tick_stage_row()
			shot("55_stages_centaur")
			_row.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			# Дикий кентавр в мире (Восточные равнины), цель героя
			_fish_view("centaur", 6.0)
			wait = 60
			step = 542
		542:
			shot("58_centaur_world")
			step = 560
		560:
			# Анатемы (ящеры с костяными клинками) рядом с героем
			_anathema_row()
			wait = 40
			step = 561
		561:
			shot("56_anathema_row")
			_row.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			_fish_view("anathema_blade", 5.0)
			wait = 60
			step = 562
		562:
			shot("57_anathema_world")
			# Объекты локации из файлов (модели Meshy, PropAsset) — кадры 59–67, «Высокое», HUD скрыт
			main.hud.visible = false
			_top = Camera3D.new()
			main.add_child(_top)
			_top.current = true
			# Город крупно: ратуша (север площади), дома, фонари, колодец
			_look_from(Vector2(0.0, 6.0), 3.0, Vector2(0.0, -16.0), 4.0)
			wait = 40
			step = 600
		600:
			shot("59_town_close")
			_look_from(Vector2(16.0, 18.0), 11.0, Vector2(0.0, 0.0), 1.0)
			wait = 30
			step = 601
		601:
			shot("60_town_wide")
			# Деревня людей и мельница
			var vc := _poi_c("human_village")
			var wm := _poi_c("windmill")
			var mid := vc.lerp(wm, 0.5)
			var side := Vector2(-(wm - vc).y, (wm - vc).x).normalized()
			_look_from(mid + side * 22.0, 9.0, mid, 3.0)
			wait = 40
			step = 602
		602:
			shot("61_human_village_mill")
			_look_from(_poi_c("light_elf_village") + Vector2(4.0, 19.0), 7.0, _poi_c("light_elf_village"), 3.0)
			wait = 40
			step = 603
		603:
			shot("62_light_elf_village")
			_look_from(_poi_c("dark_elf_village") + Vector2(-4.0, 21.0), 8.0, _poi_c("dark_elf_village"), 4.0)
			wait = 40
			step = 604
		604:
			shot("63_dark_elf_village")
			# Порт: маяк, причал, склад, груз
			var lc := _poi_c("lighthouse")
			var pc := _poi_c("pier")
			_look_from(lc.lerp(pc, 0.5) + Vector2(-6.0, -16.0), 8.0, lc.lerp(pc, 0.5), 4.0)
			wait = 40
			step = 605
		605:
			shot("64_port_lighthouse")
			# Корабль на воде (качается)
			var ship := IslandWorld.current.get_node("Pois").find_child("Ship", true, false) as Node3D
			if ship != null:
				var sp := ship.global_position
				_top.global_position = sp + Vector3(9.0, 5.0, 10.0)
				_top.look_at(sp + Vector3(0, 3.0, 0))
			wait = 40
			step = 606
		606:
			shot("65_ship")
			# Пещера: вход в скале (смотрит вниз по склону)
			var cave := IslandWorld.current.get_node("Pois").find_child("Cave", true, false) as Node3D
			if cave != null:
				var fwd := cave.global_transform.basis.z
				_top.global_position = cave.global_position + fwd * 13.0 + Vector3(3.0, 5.0, 0)
				_top.look_at(cave.global_position + Vector3(0, 2.5, 0))
			wait = 40
			step = 607
		607:
			shot("66_cave")
			# Лагерь: шатры и костёр
			var tc := _poi_c("tent_w1")
			_look_from(tc + Vector2(7.0, 7.0), 4.5, tc, 0.8)
			wait = 40
			step = 608
		608:
			shot("67_camp")
			# Лес: деревья, кусты и камни из файлов (центр острова и роща светлых эльфов)
			var fp := _forest_spot(Vector2(-30.0, -30.0), 30.0)
			_look_from(fp + Vector2(10.0, 12.0), 4.0, fp, 2.0)
			wait = 40
			step = 609
		609:
			shot("68_forest")
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			# Значки эффектов и кнопок (кадр 69): призвана пантера с включёнными «Узами тени» (только следует),
			# у героя «Щит света» и «Быстрый шаг», от пантеры — «Зов охотницы»; цель — фазан с замедлением,
			# уязвимостью и уроном со временем
			main.pets.summon(1)
			var pet: Pet = main.pets.active_pet
			if pet != null:
				pet.set_mode("follow")
			var ph := find_mob("pheasant")
			if ph != null:
				stand_near(ph, 4.0)
				player._set_target(ph)
			wait = 40
			step = 610
		610:
			player.hp = player.max_hp
			player.add_timed_bonus("focus_moment", 25.0, {"crit": 0.15})
			player.speed_buff = 0.3
			player.speed_buff_time = 5.0
			player.add_effect("speed", 5.0, StatusEffects.source_hero_skill("quick_pace"))
			var pet: Pet = main.pets.active_pet
			if pet != null:
				pet._apply_buff(PetSkills.get_skill("hunter_call"), 1, "hunter_call")
			var ph: Mob = player.current_target
			if ph != null and not ph.is_dead:
				ph.slow(0.2, 10.0, StatusEffects.source_pet_skill("panther", "dusk_rupture"))
				ph.expose(0.1, 6.0, StatusEffects.source_pet_skill("panther", "shadow_fang"))
				ph.add_dot("piercing_arrow", 0.5, 12.0, player, true, StatusEffects.source_hero_skill("piercing_arrow"))
			wait = 75
			step = 611
		611:
			player.hp = player.max_hp
			shot("69_status_icons")
			# Жители (кадры 70–75): площадь города с мудрецом, кузнецом, кладовщиком, Кирком и торговцем,
			# крупно — старосты, охотница, глава наёмников (HUD скрыт)
			player._set_target(null)
			main.pets.recall()
			main.hud.visible = false
			_top = Camera3D.new()
			main.add_child(_top)
			_top.current = true
			player.global_position = Vector3(0, 0.1, 3.0)
			_look_from(Vector2(1.0, 21.0), 8.5, Vector2(0.0, -2.0), 1.0)
			wait = 40
			step = 700
		700:
			shot("70_npcs_town")
			_npc_view("elder_human")
			wait = 40
			step = 701
		701:
			shot("71_npc_elders")
			_npc_view("elder_light")
			wait = 40
			step = 702
		702:
			shot("72_npc_elder_light")
			_npc_view("elder_dark")
			wait = 40
			step = 703
		703:
			shot("73_npc_elder_dark")
			_npc_view("hunter")
			wait = 40
			step = 704
		704:
			shot("74_npc_hunter")
			_npc_view("merc_chief")
			wait = 40
			step = 705
		705:
			shot("75_npc_merc_chief")
			# Постройки вблизи (кадры 76–81): стены без дыр, дома эльфов без пересвета; HUD и герой скрыты
			player.visible = false
			player.global_position = Vector3(0, 0.1, 3.0)
			_building_view("town_house_b", 0.0)
			wait = 40
			step = 800
		800:
			shot("76_town_house_front")
			_building_view("town_house_b", 90.0)
			wait = 30
			step = 801
		801:
			shot("77_town_house_side")
			_building_view("town_house_b", 180.0)
			wait = 30
			step = 802
		802:
			shot("78_town_house_back")
			_building_view("Windmill", 35.0, 11.0, 3.0)
			wait = 40
			step = 803
		803:
			shot("79_mill_close")
			_building_view("light_elf_house", 25.0)
			wait = 40
			step = 804
		804:
			shot("80_light_elf_house_close")
			_building_view("dark_elf_house", -25.0)
			wait = 40
			step = 805
		805:
			shot("81_dark_elf_house_close")
			# Мост с питомцем (кадр 82): герой на середине настила, волк идёт к нему с берега через мост
			var w := IslandWorld.current
			if w != null and not w.bridges.is_empty():
				var b: Dictionary = w.bridges[0]
				var a: Vector3 = b["a"]
				var e: Vector3 = b["b"]
				var axis := Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()
				var side := Vector3(-axis.z, 0.0, axis.x)
				player.visible = true
				player.global_position = IslandWorld.bridge_point(b, 0.6) + Vector3(0, 0.2, 0)
				main.pets.summon(0)
				var pet: Pet = main.pets.active_pet
				if pet != null:
					pet.set_mode("follow")
					var ps := a - axis * 3.0 + side * 3.0
					pet.global_position = w.ground(ps.x, ps.z, 0.2)
				var mid := IslandWorld.bridge_point(b, 0.4)
				var cam := mid + side * 9.0 - axis * 3.0
				_top.global_position = Vector3(cam.x, maxf(w.height_at(cam.x, cam.z), mid.y) + 4.0, cam.z)
				_top.look_at(mid + Vector3(0, 0.5, 0))
			wait = 150
			step = 806
		806:
			shot("82_bridge_pet")
			main.pets.recall()
			_top.queue_free()
			# Герои из Meshy (tools/prepare_hero.py) и прежняя героиня в ряд, стойка покоя — кадр 86
			_heroes_row(HERO_ROW, 1.25, 4.6)
			wait = 60
			step = 807
		807:
			shot("86_heroes_row")
			_heroes.queue_free()
			_top.queue_free()
			# Второй ряд: героиня-Наёмник, Воин-женщина, Бродяги — кадр 89
			_heroes_row(HERO_ROW2, 1.0, 5.6)
			wait = 60
			step = 820
		820:
			shot("89_heroes_row2")
			_heroes.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			player.visible = true
			# Профессии: экран создания (раса и пол, все — Бродяги)
			var cc := CharacterCreate.new()
			_create = cc
			get_tree().root.add_child(cc)
			cc._select_race("human")
			cc._select_gender("m")
			wait = 20
			step = 808
		808:
			shot("83_create_race")
			_create.queue_free()
			# Бродяга 12 ур.: выбор профессии у мудреца (окно с тремя карточками, сверх-эволюция +10)
			game.race_id = "light_elf"
			game.level = 12
			game.admin_set_job("wanderer")
			player.apply_class()
			main.job_window.open("")
			main.job_window._on_pick("swordsman")
			wait = 20
			step = 809
		809:
			shot("84_job_choice")
			main.hud.close_window()
			# HUD Бродяги: кнопок умений нет
			var ph := find_mob("pheasant")
			if ph != null:
				stand_near(ph, 4.0)
				player._set_target(ph)
			wait = 30
			step = 810
		810:
			shot("85_wanderer_hud")
			# Древо новой профессии: Мечник, вкладка «Щит и булава»
			game.change_job("swordsman")
			player.apply_class()
			main.hero_window.open("shield")
			wait = 20
			step = 811
		811:
			shot("88_job_tree")
			# Админ-панель (Настройки → Админ-панель): вкладка «Герой»
			AdminPanel.open(main, "hero")
			wait = 20
			step = 812
		812:
			shot("92_admin_hero")
			# Вкладка «Мир»: звери, скорость бега, перенос
			AdminPanel.open(main, "world")
			wait = 20
			step = 813
		813:
			shot("93_admin_world")
			main.hud.close_window()
			# Оружие профессий: одноручное со щитом, лук, два топора, два кинжала, два меча, посох, кинжал и щит
			var paths: Array = []
			for e in WEAPON_ROW:
				paths.append(String((e as Array)[0]))
			_heroes_row(paths, 1.0, 5.6, WEAPON_ROW)
			wait = 60
			step = 814
		814:
			shot("91_weapons")
			_heroes.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			# Босс у своего логова (модель 3-й эволюции, крупнее, подпись «Босс»); герой под «бессмертием»
			AdminPanel.god = true
			var boss := find_mob("boss_panther")
			if boss != null:
				stand_near(boss, 9.0)
				main.player.select_target(boss)
				main.cam_yaw = atan2(main.player.global_position.x - boss.global_position.x,
					main.player.global_position.z - boss.global_position.z)
			wait = 90
			step = 815
		815:
			shot("90_boss")
			# Маги и звероловы: 12 новых героев (Неофит, Адепт, Волшебник, Зверолов, Шаман, Колдун × 2 пола) — кадр 94
			_heroes_row(HERO_CASTERS, 0.85, 8.6)
			wait = 60
			step = 816
		816:
			shot("94_heroes_casters")
			_heroes.queue_free()
			_top.queue_free()
			# Женская пластика: Волшебница и Волшебник идут рядом (шаг на месте, вполоборота к камере) — кадр 95
			_heroes_row(["res://assets/characters/hero_wizard_f.glb", "res://assets/characters/hero_wizard_m.glb"],
				1.1, 3.4)
			for c in _heroes.get_children():
				var m := c as CharacterModel
				m.rotation.y = PI + 0.7
				m.set_move_speed(1.4)
			wait = 47
			step = 817
		817:
			shot("95_female_walk")
			_heroes.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			# Умения Воина (кадр 98): две искры духа (значок с числом у полоски HP), «Ярость дикаря», «Камнелом» по волку
			AdminPanel.god = true
			game.admin_set_look("human", "m")
			_job_showcase("warrior", ["stonebreaker", "kindle_spark", "power_breath", "spin_strike"], ["savage_fury"], 1.8)
			JobFxWarrior.add_sparks(main.player._fx, 2)
			main.player.use_skill("skill1")
			wait = 10
			step = 818
		818:
			shot("98_skills_warrior_shaman")
			# Умения Шамана (кадр 99): огненное лезвие и «Священный огонь» включены, «Обвал» по зверю, сгусток посоха
			_job_showcase("shaman", ["rockslide", "fire_frenzy", "pure_spring", "earth_grip"], ["fire_edge", "sacred_fire"], 6.0)
			main.player.use_skill("skill2")
			main.player.use_skill("skill1")
			main.player.try_attack()
			wait = 14
			step = 819
		819:
			shot("99_skills_shaman")
			# Умения Зверолова (кадр 100): ауры питомцу — значки у панели питомца, «Целебная роса» на волка
			game.admin_set_look("light_elf", "f")
			_job_showcase("beastmaster", ["healing_dew", "mend_beast", "second_wind", "sky_offering"],
				["beast_might", "ward_charm", "radiant_claws"], 5.0)
			if main.pets.active_pet == null and not game.pets.is_empty():
				game.pets[0]["dead"] = false
				main.pets.summon(0)
			var bp: Pet = main.pets.active_pet
			if bp != null:
				bp._teleport_to_owner()
				bp.hp = bp.max_hp / 2
				bp.bond_hp_changed()
			main.player.use_skill("skill1")
			wait = 14
			step = 830
		830:
			shot("100_skills_pet_jobs")
			# Колдун (кадр 101): «Слияние душ» — питомец внутри героя, сияние цвета питомца; «Гнев стаи»
			game.admin_set_look("human", "m")
			_job_showcase("conjurer", ["pack_wrath", "lullaby", "wild_roar", "spirit_wrath"], ["chord_strength"], 5.0)
			var cp: Pet = main.pets.active_pet
			if cp != null:
				cp._teleport_to_owner()
			main.player.set_toggle("soul_merge", true)
			main.player.use_skill("skill1")
			wait = 14
			step = 831
		831:
			shot("101_skills_pet_merge")
			main.player.set_toggle("soul_merge", false)
			# Умения Неофита (кадр 96): «Пылающая земля» и «Грозовой круг» на земле у зверя, «Сгусток пламени» летит,
			# «Теневая печать» включена; значки зоны и горения у панели цели
			game.admin_set_look("dark_elf", "f")
			_job_showcase("neophyte", ["burning_ground", "storm_circle", "flame_orb", "wildfire"], ["shadow_seal"], 6.0)
			main.player.use_skill("skill1")
			main.player.use_skill("skill2")
			wait = 50
			step = 832
		832:
			main.player.skill_cd.clear()
			main.player.attack_cd = 0.0
			main.player.use_skill("skill3")
			wait = 8
			step = 833
		833:
			shot("96_skills_casters")
			for z in get_tree().get_nodes_in_group("skill_zones"):
				z.queue_free()
			# Мечник и Волшебник (кадр 97): «Гром щита» (провокация), «Колючий щит» и «Благодать»; затем светлая магия
			game.admin_set_look("light_elf", "m")
			_job_showcase("swordsman", ["shield_thunder", "thorn_shield", "dawn_cross", "armor_breach"], ["grace", "blessed_blade"], 1.8)
			main.player.use_skill("skill2")
			main.player.use_skill("skill1")
			main.player.use_skill("skill3")
			wait = 8
			step = 834
		834:
			shot("97_skills_guard")
			# Команды питомца (кадр 130): круглые кнопки «Авто», «Атака», «Защита», «За мной» под панелью питомца,
			# у пантеры — режим «Авто» (кнопка с кольцом); окно существа с 5 ячейками умений (кадр 131)
			if game.pets.size() > 1:
				game.pets[1]["dead"] = false
				main.pets.summon(1)
			wait = 5
			step = 960
		960:
			var pp: Pet = main.pets.active_pet
			if pp != null:
				pp._teleport_to_owner()
				pp.set_mode("auto")
			wait = 30
			step = 961
		961:
			shot("130_pet_buttons")
			if game.pets.size() > 1:
				main.pets.open_creature(1, "skills")
			wait = 10
			step = 962
		962:
			shot("131_creature_slots")
			main.hud.close_window()
			ok_done()


## Кадры 96–101: герой профессии job 40 ур. с изученным древом, умения slots на кнопках 1–4, включённые toggles,
## у волка (или фазана) на расстоянии dist м, MP полное.
func _job_showcase(job: String, slots: Array, toggles: Array, dist: float) -> void:
	var p: Player = main.player
	become_job(job)
	game.level = 40
	game.hero["jp"] = 5000
	HeroSkills.learn_all(game.hero, job, game.level)
	p.refresh_skills()
	p.mp = p.max_mp
	p.hp = p.max_hp
	for i in slots.size():
		p.assign_slot(String(slots[i]), i)
	for t in toggles:
		p.set_toggle(String(t), true)
	p.mp = p.max_mp
	var m := find_mob("wolf")
	if m == null:
		m = find_mob("pheasant")
	if m != null:
		stand_near(m, dist)
		p.select_target(m)
		main.cam_yaw = atan2(p.global_position.x - m.global_position.x, p.global_position.z - m.global_position.z) + 0.5


## Камера _top в 3.4 м перед жителем, чуть сбоку; игрок (скрыт) у камеры — житель повернётся к ней.
func _npc_view(id: String) -> void:
	var n: Npc = main.npcs.npc(id)
	if n == null:
		return
	var player: Player = main.player
	var c := n.global_position
	var dir := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw)).rotated(Vector3.UP, 0.35)
	var from := c + dir * 3.4
	var w := IslandWorld.current
	if w != null:
		from.y = maxf(w.height_at(from.x, from.z), c.y) + 1.5
	player.visible = false
	player.global_position = Vector3(from.x, from.y - 1.4, from.z)
	_top.global_position = from
	_top.look_at(c + Vector3(0, 1.15, 0))
	print("  %s: (%.1f, %.1f)" % [id, c.x, c.z])


## Игрок в 3 м от Учителя Кирка (со стороны площади), камера за игроком чуть сбоку — Кирк в кадре.
func _kirk_view() -> void:
	var player: Player = main.player
	var kp: Vector3 = main.npcs.kirk.global_position
	var to_c := Vector3(-kp.x, 0, -kp.z).normalized()
	player.global_position = kp + to_c * 3.0 + Vector3(0, 0.1, 0)
	main.cam_yaw = atan2(to_c.x, to_c.z) + 0.35
	main.cam_pitch = 0.33
	main.cam_dist = 6.5


## Центр POI из конфига острова (x, z).
func _poi_c(id: String) -> Vector2:
	var w := IslandWorld.current
	if w == null or w.poi(id).is_empty():
		return Vector2.ZERO
	return IslandWorld.v2(w.poi(id)["center"])


## Камера _top у постройки (тело poi_buildings с именем bname — первое найденное): с направления angle°
## от её фасада (0 — спереди, 90 — справа, 180 — сзади) на расстоянии dist, на высоте h; смотрит на середину стены.
func _building_view(bname: String, angle: float, dist: float = 8.5, h: float = 2.2) -> void:
	var body: Node3D = null
	for b in get_tree().get_nodes_in_group("poi_buildings"):
		var n := b as Node3D
		if n != null and String(n.name).begins_with(bname):
			body = n
			break
	if body == null:
		print("  постройка %s не найдена" % bname)
		return
	var fwd := body.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, deg_to_rad(angle))
	var c := body.global_position
	var from := c + fwd * dist
	var w := IslandWorld.current
	var gy := w.height_at(from.x, from.z) if w != null else c.y
	_top.global_position = Vector3(from.x, maxf(gy, c.y) + h, from.z)
	_top.look_at(c + Vector3(0, 1.8, 0))


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


## Герой слева, три анатемы в ряд справа (клип Idle — боевая стойка), камера сбоку чуть сверху, HUD скрыт.
func _anathema_row() -> void:
	var player: Player = main.player
	main.pets.recall()
	player.visible = true
	var base := player.global_position
	_row = Node3D.new()
	_row.name = "AnathemaRow"
	main.add_child(_row)
	for i in ANATHEMA_ROW.size():
		var id := String(ANATHEMA_ROW[i])
		var holder := Node3D.new()
		holder.set_meta("species", id)
		_row.add_child(holder)
		var d := MobData.get_type(id)
		CreatureModels.build(holder, id, d["color"], float(d["scale"]))
		var gp := base + Vector3(1.6 + 2.0 * float(i), 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		holder.global_position = gp
		holder.rotation.y = PI + 0.7
	_top = Camera3D.new()
	main.add_child(_top)
	_top.global_position = base + Vector3(3.0, 2.0, 7.5)
	_top.look_at(base + Vector3(3.0, 1.2, 0))
	_top.current = true
	main.hud.visible = false


## Героиня (скелет Mixamo) и герои из Meshy с родным скелетом в ряд на площади города перед камерой (Idle, парные
## мечи; у последнего — арбалет), игрок скрыт, HUD скрыт. gap — шаг ряда, м; dist — камера от ряда, м.
func _heroes_row(paths: Array, gap: float, dist: float, weapons: Array = []) -> void:
	var player: Player = main.player
	player.visible = false
	# Площадь города (ровно, без воды); игрок скрыт там же
	var base := Vector3(0.0, 0.0, 3.0)
	if IslandWorld.current != null:
		base.y = IslandWorld.current.height_at(base.x, base.z)
	player.global_position = base + Vector3(0, 0.1, 0)
	_heroes = Node3D.new()
	_heroes.name = "HeroRow"
	main.add_child(_heroes)
	for i in paths.size():
		var spec := CharacterModel.spec_for("dark_elf", "assassin", "crossbow" if i == paths.size() - 1 else "dual_swords")
		if i < weapons.size():
			var we: Array = weapons[i]
			spec = CharacterModel.spec_for("dark_elf", "assassin", String(we[1]), "f", bool(we[2]))
		spec["asset"] = String(paths[i])
		var m := CharacterModel.new()
		m.setup(spec)
		_heroes.add_child(m)
		var gp := base + Vector3((float(i) - float(paths.size() - 1) * 0.5) * gap, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		m.global_position = gp
		# Модель смотрит в −Z, камера — с +Z; чуть вполоборота
		m.rotation.y = PI + 0.25
	_top = Camera3D.new()
	main.add_child(_top)
	_top.global_position = base + Vector3(0, 1.2, dist)
	_top.look_at(base + Vector3(0, 0.95, 0))
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
## Ряд питомцев по стадиям эволюции [[вид, стадия 0..2], …] перед своей камерой, игрок и питомец скрыты, HUD скрыт.
## Модели — как у питомца: масштаб PetData.stage_scale, своя модель стадии (CreatureAsset.model_for) и украшения.
func _build_stage_row(list: Array) -> void:
	var player: Player = main.player
	main.pets.recall()
	player.visible = false
	main.hud.visible = false
	if is_instance_valid(_row):
		_row.queue_free()
	if not is_instance_valid(_top):
		_top = Camera3D.new()
		main.add_child(_top)
	_top.current = true
	var base := player.global_position
	_row = Node3D.new()
	_row.name = "StageRow"
	main.add_child(_row)
	var xs: Array[float] = []
	var x := 0.0
	for i in list.size():
		var e: Array = list[i]
		var id := String(e[0])
		var st := int(e[1])
		var lvl := int(PetData.STAGE_LEVELS[st])
		var sc := PetData.stage_scale(id, lvl)
		var mid := CreatureAsset.model_for(id, st)
		var w := maxf(float(CreatureAsset.info_for(mid)["width"]), float(CreatureAsset.info_for(mid)["length"]) * 0.55) * sc
		if i > 0:
			x += w * 0.5 + 0.35
		xs.append(x)
		x += w * 0.5
		var holder := Node3D.new()
		holder.set_meta("species", id)
		_row.add_child(holder)
		CreatureModels.build(holder, id, PetData.stage_color(id, lvl), sc, PetData.asset_tint(id, lvl), st)
		CreatureModels.decorate_pet(holder, id, sc, st, PetData.role(id))
		print("  стадия %d %s: модель %s, высота %.2f м" % [st + 1, id, mid, CreatureModels.height(mid, sc)])
	var half := x * 0.5
	var top_h := 0.0
	for i in _row.get_child_count():
		var holder := _row.get_child(i) as Node3D
		var gp := base + Vector3(xs[i] - half, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		holder.global_position = gp
		holder.rotation.y = PI + 0.6
		var e: Array = list[i]
		var id := String(e[0])
		var mid := CreatureAsset.model_for(id, int(e[1]))
		top_h = maxf(top_h, CreatureModels.height(mid, PetData.stage_scale(id, int(PetData.STAGE_LEVELS[int(e[1])]))))
	var dist := maxf(x * 0.95, top_h * 2.2) + 1.2
	_top.global_position = base + Vector3(0, top_h * 0.75 + 0.4, dist)
	_top.look_at(base + Vector3(0, top_h * 0.45, 0))


## Украшения над головой (самоцвет роли) — к голове модели.
func _tick_stage_row() -> void:
	for n in _row.get_children():
		var ca := CreatureModels.asset_of(n as Node3D)
		if ca != null:
			ca.update(1.0 / 30.0, 0.0)


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
