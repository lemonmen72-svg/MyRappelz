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
## Экран до мира для кадров 102–109 (вход, выбор, создание персонажа) и 260–269 (арты Dark Pact).
var _menu: CanvasLayer = null
## Подставной sha256 частей манифеста для кадра 260 (экран загрузки без сети).
const SHOT_SHA := "0000000000000000000000000000000000000000000000000000000000000000"
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
## Движения манекенов Meshy (кадры 140–141): [модель, вид оружия ItemData, щит, клип] — поза в момент удара.
const MQ_ATTACK_ROW := [
	["res://assets/characters/hero_swordsman_m.glb", "sword_1h", true, "mq_combo_b1"],
	["res://assets/characters/hero_assassin_f.glb", "daggers", false, "mq_dual_a1"],
	["res://assets/characters/hero_warrior_m.glb", "axe_2h", false, "mq_heavy_swing"],
	["res://assets/characters/hero_warrior_f.glb", "bow", false, "mq_bow_shot"],
	["res://assets/characters/hero_wizard_f.glb", "staff_2h", false, "mq_cast_a"],
	["res://assets/characters/hero_swordsman_f.glb", "spear", false, "mq_leap_slam"],
]
const MQ_SKILL_ROW := [
	["res://assets/characters/hero_swordsman_m.glb", "sword_1h", true, "mq_taunt"],
	["res://assets/characters/hero_shaman_m.glb", "staff_2h", false, "mq_charged_cast"],
	["res://assets/characters/hero_assassin_m.glb", "dual_swords", false, "mq_blade_spin"],
	["res://assets/characters/hero_conjurer_f.glb", "axe_1h", false, "mq_axe_chop"],
	["res://assets/characters/hero_neophyte_m.glb", "staff_2h", false, "mq_cast_beam"],
	["res://assets/characters/hero_adept_f.glb", "dagger", false, "mq_judgment"],
]
## Шаг и бег из манекенов (кадры 250–256): Воин и Волшебница — [модель, вид оружия, щит, клип, доля цикла (−1 —
## момент удара из .json)]; раскадровка цикла бега — по 6 фаз.
const LOCO_HERO := "res://assets/characters/hero_warrior_m.glb"
const LOCO_HEROINE := "res://assets/characters/hero_wizard_f.glb"
const MQ_LOCO_ROW := [
	[LOCO_HERO, "axe_1h", false, "mq_walking", 0.25], [LOCO_HERO, "axe_1h", false, "mq_running_b", 0.25],
	[LOCO_HERO, "axe_1h", false, "mq_sprint", 0.25], [LOCO_HEROINE, "staff_1h", false, "mq_walking", 0.25],
	[LOCO_HEROINE, "staff_1h", false, "mq_running_b", 0.25], [LOCO_HEROINE, "staff_1h", false, "mq_sprint", 0.25],
]
## Новые удары и умения (кадр 254): вторая часть выпада, кручение с колена, пинок, прыжок, стойка, подъём.
const MQ_NEW_ROW := [
	[LOCO_HEROINE, "daggers", false, "mq_thrust_b", -1.0], [LOCO_HERO, "dual_swords", false, "mq_blade_spin_b", -1.0],
	[LOCO_HEROINE, "dagger", false, "mq_kick", -1.0], [LOCO_HERO, "daggers", false, "mq_jump", 0.45],
	[LOCO_HEROINE, "sword_1h", false, "mq_guard", -1.0], [LOCO_HERO, "axe_1h", false, "mq_rise", 0.3],
]
## Лук и петли (кадр 255): прицеливания манекенов, прицел с обзором, заряд в приседе.
const MQ_BOW_ROW := [
	[LOCO_HEROINE, "bow", false, "mq_bow_draw_b", -1.0], [LOCO_HERO, "bow", false, "mq_bow_draw_c", -1.0],
	[LOCO_HEROINE, "bow", false, "mq_bow_draw_d", 0.3], [LOCO_HERO, "bow", false, "mq_bow_scan_hold", 0.1],
	[LOCO_HEROINE, "axe_1h", false, "mq_crouch_charge_hold", 0.5], [LOCO_HERO, "sword_1h", true, "mq_pickup_b", 0.75],
]
## Повороты на месте и эмоции (кадр 256): середина поворота, усиление нового уровня, удар в грудь после босса.
const MQ_TURN_ROW := [
	[LOCO_HERO, "axe_1h", false, "mq_turn_l90", 0.5], [LOCO_HEROINE, "staff_1h", false, "mq_turn_r90", 0.5],
	[LOCO_HERO, "crossbow", false, "mq_turn_l180", 0.5], [LOCO_HEROINE, "staff_1h", false, "mq_turn_l180", 0.7],
	[LOCO_HERO, "axe_1h", false, "mq_charged_cast1", -1.0], [LOCO_HEROINE, "staff_1h", false, "mq_taunt", -1.0],
]
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
## Камера кадров настроек графики (120–129) и место героя в городе (у ратуши, видно с камеры кадров 12–14).
var _gcam: Camera3D = null
## Кадры 290–292: пресет до блока бережения телефона.
var _thermal_level := -1
const GFX_HERO := Vector2(4.5, -6.5)
var _top: Camera3D = null
var _row: Node3D = null
var _frames := 0
## Рыба для кадра 54 (убитая падает на землю).
var _fish: Variant = null
## Летающие рыбы в ряд рядом с героем — кадр 52.
const FISH_ROW := ["flyfish", "flyfish_sail", "flyfish_drake"]
## Жители-лавки города (кадры 280–286): оружейник, бронница, ювелир.
const SHOP_NPCS := ["weaponsmith", "armorer", "jeweler"]
## Анатемы в ряд рядом с героем — кадр 56. Кентавр: стадии рядом с героем — кадр 55, в мире — кадр 58.
const ANATHEMA_ROW := ["anathema", "anathema_blade", "anathema_chief"]
## Умения Наёмника для кадров окна героя [id, уровень].
const HERO_SKILLS := [["blade_mastery", 2], ["charge_stab", 2], ["dark_strike", 1], ["evasion_expert", 2],
	["concentration", 1], ["crossbow_mastery", 1], ["dual_shot", 1]]
## Зелья рангов и оружие 2-го ранга для кадра 190 (сумка): [id, количество].
const POTION_BAG := [
	["potion_hp_r2", 6], ["potion_hp_r6", 2], ["potion_hp_r11", 1], ["potion_mp_r1", 5], ["potion_mp_r7", 2],
	["potion_aspd_r2", 3], ["potion_cast_r12", 1], ["potion_speed_r1", 4], ["weapon_staff_2h_r2", 1], ["weapon_sword_1h_r2", 1],
]
## Кадры 270–274 (экипировка): надето кроме доспеха (доспех — по профессии героя) и лежит в сумке.
const GEAR_SHOT_WORN := ["armor_helmet_r1", "armor_gloves_r1", "armor_boots_r1", "ring_hp_r1", "ring_cast_r1",
	"earring_crit_r1", "pendant_mdef_r1", "belt_speed_r1"]
const GEAR_SHOT_BAG := ["pendant_hp_r1", "ring_critdmg_r2", "armor_body_warrior_r1", "armor_helmet_r2", "earring_aspd_r1"]
## Предметы для кадров сумки и торговца (27–30): [id, количество]. Карты существ: пустые, с душой, зеркальная.
const BAG_ITEMS := [
	["dagger_steel", 1], ["sword_steel", 2], ["crossbow_heavy", 1], ["card_panther", 4], ["card_wolf", 1], ["card_turtle", 1],
	["card_panther_soul", 1], ["card_wolf_soul", 1], ["mirror_card", 2], ["lizard_scale", 7],
	["wolf_pelt", 3], ["panther_fang", 2], ["pheasant_feather", 4], ["shell_plate", 2], ["chief_spike", 1],
	["potion_hp_r1", 12],
]

## ---------- Части сценария (CI: матрица visual в .github/workflows/check.yml, задачи идут параллельно) ----------
## Запуск части K из N (K с 1): … res://tests/runner.tscn -- res://tests/shots.gd --shots-part=K --shots-parts=N.
## Без аргументов — вся цепочка, как раньше. Цепочку делят точки входа PART_ENTRIES: [шаг, с которого начинается
## блок кадров; кадров в блоке до следующей точки входа; секунд блока в CI], по порядку цепочки. Часть K получает
## подряд идущие блоки так, чтобы самая долгая часть была как можно короче (part_bounds: время части — секунды её
## блоков + перемотка до её начала, PART_FF_MS мс на кадр). Шаги до своей точки входа часть проходит «перемоткой»:
## логика игры идёт кадр за кадром как в полной цепочке (герой, питомцы, окна, качество — то же состояние), но без
## отрисовки (RenderingServer.render_loop_enabled = false) и без снимков; за PART_WARMUP кадров до точки входа
## отрисовка включается. На точке входа следующей части — ok_done().
## Новый блок кадров: дописать в цепочку как раньше и добавить его первый шаг в PART_ENTRIES по порядку цепочки
## (точка входа — шаг без снимка в начале, где блок ставит свою сцену, или шаг со снимком, перед которым wait ≥ 3);
## таблицу пересчитывает python3 -I tools/shots_parts.py: кадры — по цепочке, секунды — --from-logs <shots.log
## частей> (строки «[OK] скриншот …, N с от запуска»), у нового блока без замера — по кадрам; --parts N — деление.
const PART_ENTRIES := [
	[0, 373, 208], [9, 189, 112], [18, 256, 102], [29, 181, 80], [41, 185, 55], [46, 74, 24],
	[52, 83, 51], [520, 225, 80], [540, 103, 38], [560, 143, 28], [600, 195, 40], [605, 205, 36],
	[610, 117, 25], [700, 246, 45], [800, 336, 78], [806, 61, 58], [807, 82, 69], [808, 176, 52],
	[814, 152, 72], [816, 59, 23], [818, 120, 29], [960, 45, 12], [963, 64, 14], [925, 141, 33],
	[940, 33, 9], [943, 63, 47], [946, 95, 46], [980, 40, 46], [1000, 42, 18], [1002, 95, 83],
	[1025, 102, 102], [1021, 126, 144], [1040, 141, 181], [1060, 66, 67], [1160, 124, 148], [1120, 98, 101],
	[1080, 60, 58], [1200, 181, 224], [1260, 224, 112], [1220, 103, 52], [1240, 76, 40], [1300, 55, 29],
]
## Сколько кадров до точки входа часть уже рисует (компиляция шейдеров, тени, окна интерфейса).
const PART_WARMUP := 10
## Перемотка без отрисовки, мс на кадр до точки входа (по логам CI ≈7–11 мс) — для деления на части.
const PART_FF_MS := 10
## Первый шаг части (−1 — вся цепочка), шаг начала следующей части (−1 — до конца), часть пуста.
var _part_start := -1
var _part_end := -1
var _part_empty := false
## Идёт перемотка к точке входа (без отрисовки и снимков).
var _skipping := false
var _skip_t0 := 0
var _t0 := 0


## Части k (1…n): [индекс первой точки входа PART_ENTRIES, индекс после последней]. Подряд идущие блоки, самая
## долгая часть — как можно короче (динамика по числу частей и концу части; при равенстве — раньше начало).
## То же деление — part_bounds в tools/shots_parts.py.
static func part_bounds(k: int, n: int) -> Array:
	var cnt := PART_ENTRIES.size()
	var parts := mini(n, cnt)
	if k > parts:
		return [cnt, cnt]
	var start_f: Array[int] = []
	var cum_ms: Array[int] = [0]
	var f := 0
	for e in PART_ENTRIES:
		start_f.append(f)
		f += int(e[1])
		cum_ms.append(cum_ms[cum_ms.size() - 1] + int(e[2]) * 1000)
	var big := 1 << 60
	# best[j][i] — наименьшее время самой долгой части, если первые i блоков разделить на j частей;
	# src[j][i] — первый блок последней из этих частей
	var best: Array = []
	var src: Array = []
	for _r in range(parts + 1):
		var row: Array[int] = []
		row.resize(cnt + 1)
		row.fill(big)
		var srow: Array[int] = []
		srow.resize(cnt + 1)
		srow.fill(0)
		best.append(row)
		src.append(srow)
	best[0][0] = 0
	for j in range(1, parts + 1):
		for i in range(j, cnt + 1):
			for p in range(j - 1, i):
				var prev: int = best[j - 1][p]
				if prev == big:
					continue
				var c: int = cum_ms[i] - cum_ms[p] + start_f[p] * PART_FF_MS
				var v := maxi(prev, c)
				var cur: int = best[j][i]
				if v < cur:
					best[j][i] = v
					src[j][i] = p
	var cuts: Array[int] = []
	cuts.resize(parts + 1)
	cuts[parts] = cnt
	var at := cnt
	for jb in range(parts, 0, -1):
		var s: int = src[jb][at]
		cuts[jb - 1] = s
		at = s
	return [cuts[k - 1], cuts[k]]


## Аргументы --shots-part=K --shots-parts=N: границы части и перемотка без отрисовки до её начала.
func _setup_part() -> void:
	_t0 = Time.get_ticks_msec()
	var k := 0
	var n := 0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--shots-part="):
			k = s.get_slice("=", 1).to_int()
		elif s.begins_with("--shots-parts="):
			n = s.get_slice("=", 1).to_int()
	if n <= 1:
		return
	if k < 1 or k > n:
		fail("часть %d из %d: нужно 1 ≤ K ≤ N" % [k, n])
		return
	var b := part_bounds(k, n)
	var i0 := int(b[0])
	var i1 := int(b[1])
	if i0 >= i1:
		_part_empty = true
		print("Часть %d/%d: блоков нет (частей больше, чем точек входа)" % [k, n])
		return
	_part_start = int(PART_ENTRIES[i0][0])
	_part_end = int(PART_ENTRIES[i1][0]) if i1 < PART_ENTRIES.size() else -1
	print("Часть %d/%d: шаги с %d до %s" % [k, n, _part_start, str(_part_end) if _part_end >= 0 else "конца"])
	if _part_start != 0:
		_skipping = true
		_skip_t0 = Time.get_ticks_msec()
		RenderingServer.render_loop_enabled = false


func _process(delta: float) -> void:
	if not done and main != null and main.is_inside_tree():
		_part_tick()
	super(delta)


func _part_tick() -> void:
	if _part_empty:
		ok_done()
		return
	if _part_end >= 0 and step == _part_end:
		print("Часть: дошли до шага %d — дальше следующая часть (%.0f с)" % [_part_end,
			float(Time.get_ticks_msec() - _t0) / 1000.0])
		ok_done()
		return
	if not _skipping:
		return
	# Без отрисовки кадры короткие — без предела кадров/с (Quality.apply_fps ставит его заново)
	Engine.max_fps = 0
	if step == _part_start and wait <= PART_WARMUP:
		_skipping = false
		RenderingServer.render_loop_enabled = true
		Quality.apply_fps()
		# Снимок читает уже нарисованный кадр: хотя бы 3 кадра с отрисовкой до шага входа
		wait = maxi(wait, 3)
		print("Часть: перемотка до шага %d — %d кадров за %.1f с, дальше с отрисовкой" % [_part_start, frame,
			float(Time.get_ticks_msec() - _skip_t0) / 1000.0])


func ok_done() -> void:
	if _skipping and not done:
		fail("точка входа части (шаг %d) не встретилась в цепочке — PART_ENTRIES в tests/shots.gd" % _part_start)
		return
	super()


func race_class() -> Array:
	return ["light_elf", "wizard"]


func before_start() -> void:
	_setup_part()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS_DIR))
	Quality.set_level(Quality.HIGH, false)
	# MSAA на программном рендере CI в разы медленнее — сценарий не укладывался в предел; сглаживание — FXAA
	# (MSAA снимается отдельно в кадрах 128–129)
	Quality.set_option("aa", 1, false)
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
			use_now(player, "skill1")
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
			Quality.set_option("aa", 1, false)
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
			# Окно торговца: товары, сумка, карточка зелья 2-го ранга (оружие — у оружейника, кадры 280–289)
			main.economy.open_shop()
			main.economy.window._on_cell("good", InventoryWindow.goods(game.class_id).find("potion_hp_r2"))
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
			use_now(main.player, "skill1")
			wait = 10
			step = 818
		818:
			shot("98_skills_warrior_shaman")
			# Умения Шамана (кадр 99): огненное лезвие и «Священный огонь» включены, «Обвал» по зверю, сгусток посоха
			_job_showcase("shaman", ["rockslide", "fire_frenzy", "pure_spring", "earth_grip"], ["fire_edge", "sacred_fire"], 6.0)
			use_now(main.player, "skill2")
			use_now(main.player, "skill1")
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
			use_now(main.player, "skill1")
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
			use_now(main.player, "skill1")
			wait = 14
			step = 831
		831:
			shot("101_skills_pet_merge")
			main.player.set_toggle("soul_merge", false)
			# Умения Неофита (кадр 96): «Пылающая земля» и «Грозовой круг» на земле у зверя, «Сгусток пламени» летит,
			# «Теневая печать» включена; значки зоны и горения у панели цели
			game.admin_set_look("dark_elf", "f")
			_job_showcase("neophyte", ["burning_ground", "storm_circle", "flame_orb", "wildfire"], ["shadow_seal"], 6.0)
			use_now(main.player, "skill1")
			use_now(main.player, "skill2")
			wait = 50
			step = 832
		832:
			main.player.skill_cd.clear()
			main.player.attack_cd = 0.0
			use_now(main.player, "skill3")
			wait = 8
			step = 833
		833:
			shot("96_skills_casters")
			for z in get_tree().get_nodes_in_group("skill_zones"):
				z.queue_free()
			# Мечник и Волшебник (кадр 97): «Гром щита» (провокация), «Колючий щит» и «Благодать»; затем светлая магия
			game.admin_set_look("light_elf", "m")
			_job_showcase("swordsman", ["shield_thunder", "thorn_shield", "dawn_cross", "armor_breach"], ["grace", "blessed_blade"], 1.8)
			use_now(main.player, "skill2")
			use_now(main.player, "skill1")
			use_now(main.player, "skill3")
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
			wait = 2
			step = 963
		963:
			# Цепочка заданий острова (кадры 110–114): Бродяга-человек у Старосты Ольвина
			for z in get_tree().get_nodes_in_group("skill_zones"):
				z.queue_free()
			main.player._set_target(null)
			game.admin_set_job(ClassData.WANDERER)
			game.admin_set_look("human", "m")
			game.level = 3
			main.player.apply_class()
			game.quests_active = {}
			game.quests_done = {}
			game.quest_tracked = ""
			main.quests._changed()
			_talk_view("elder_human")
			main.npcs.talk_to("elder_human")
			main.npcs.open_dialog("elder_human", "quest", "elder_hunt")
			wait = 12
			step = 920
		920:
			shot("110_elder_quest")
			main.npcs.close_dialog()
			# Склад у Кладовщика Тобина: стопки на складе, выбрана вещь из сумки
			_talk_view("storekeeper")
			for e in [["wolf_pelt", 6], ["pheasant_feather", 9], ["mirror_card", 2], ["potion_hp_r1", 20], ["shell_plate", 3]]:
				game.storage.add(String(e[0]), int(e[1]))
			game.inventory.add("panther_fang", 4)
			main.economy.open_storage()
			main.economy.window.select_cell(game.inventory.find_cell("panther_fang"))
			wait = 12
			step = 921
		921:
			shot("111_storage")
			main.hud.close_window()
			# Журнал: четыре задания мудреца, у лавки куплено 2 из 3
			for id in QuestData.ELDER_CHAIN:
				game.quests_done[String(id)] = 1
			game.level = 7
			main.player.apply_class()
			for id in ["sage_path", "sage_storage", "sage_shop", "sage_teacher"]:
				main.quests.accept(String(id))
			game.quests_active["sage_shop"]["progress"] = [2, 1]
			game.quests_active["sage_teacher"]["progress"] = [1]
			game.quest_tracked = "sage_shop"
			main.quests.refresh_tracker()
			main.quests.window.open("sage_shop")
			wait = 10
			step = 922
		922:
			shot("112_sage_journal")
			main.hud.close_window()
			# Охотница Ярра: семь вожаков и доклад мудрецу
			for id in ["sage_storage", "sage_shop", "sage_teacher", "sage_to_hunter", "hunter_hunt"]:
				game.quests_active.erase(String(id))
				game.quests_done[String(id)] = 1
			game.quest_tracked = "sage_path"
			main.quests._changed()
			_talk_view("hunter")
			main.npcs.talk_to("hunter")
			main.npcs.open_dialog("hunter", "quests")
			wait = 12
			step = 923
		923:
			shot("113_hunter_bosses")
			var all_b: Button = main.npcs.buttons.get("accept_all")
			if all_b != null:
				all_b.pressed.emit()
			main.npcs.close_dialog()
			game.quest_tracked = "hunter_boss_wolf"
			main.quests.refresh_tracker()
			main.quests.window.open("hunter_boss_wolf")
			wait = 10
			step = 924
		924:
			shot("114_hunter_journal")
			main.hud.close_window()
			wait = 2
			step = 925
		925:
			# Экраны до мира (кадры 102–109): вход, выбор персонажа, шаги создания, настройки со сменой персонажа
			main.hud.close_window()
			_menu = LoginScreen.new()
			get_tree().root.add_child(_menu)
			wait = 10
			step = 900
		900:
			shot("102_login")
			_menu.queue_free()
			# Выбор персонажа: тестовый герой в слоте 1 и ещё два персонажа (только сводка), слот 4 пуст
			Accounts.save_slot(1, {"name": "Лиара", "race": "light_elf", "class": "wizard", "level": 24, "gender": "f"})
			Accounts.save_slot(2, {"name": "Гром_топор", "race": "human", "class": "warrior", "level": 31, "gender": "m"})
			_menu = CharacterSelect.new()
			get_tree().root.add_child(_menu)
			(_menu as CharacterSelect).select(1)
			wait = 10
			step = 901
		901:
			shot("103_char_select")
			(_menu as CharacterSelect)._on_delete()
			wait = 6
			step = 902
		902:
			shot("104_char_delete")
			_menu.queue_free()
			Accounts.delete_slot(1)
			Accounts.delete_slot(2)
			_menu = CharacterCreate.new()
			get_tree().root.add_child(_menu)
			(_menu as CharacterCreate)._select_race("light_elf")
			wait = 10
			step = 903
		903:
			shot("105_create_race")
			(_menu as CharacterCreate).go_next()
			wait = 10
			step = 904
		904:
			shot("106_create_jobs")
			(_menu as CharacterCreate).go_next()
			wait = 40
			step = 905
		905:
			shot("107_create_gender")
			(_menu as CharacterCreate).go_next()
			(_menu as CharacterCreate)._name_edit.text = "Светлана"
			wait = 40
			step = 906
		906:
			shot("108_create_name")
			_menu.queue_free()
			_menu = null
			SettingsMenu.open(main.hud, "other")
			wait = 6
			step = 907
		907:
			shot("109_settings_account")
			main.hud.close_window()
			step = 940
		940:
			# Настройки графики (кадры 120–121): вкладка «Графика» — пресет и все настройки
			main.hud.visible = true
			main.cam.current = true
			for z in get_tree().get_nodes_in_group("skill_zones"):
				z.queue_free()
			Quality.set_level(Quality.HIGH, false)
			Quality.apply(get_tree())
			SettingsMenu.open(main.hud, "graphics")
			wait = 6
			step = 941
		941:
			shot("120_settings_graphics")
			if is_instance_valid(SettingsMenu._scroll):
				SettingsMenu._scroll.scroll_vertical = 100000
			wait = 4
			step = 942
		942:
			shot("121_settings_graphics_more")
			main.hud.close_window()
			# Тени в городе (кадры 122–124): герой у ратуши, дома и их тени — выкл / низкие / высокие
			var hp := IslandWorld.current.ground(GFX_HERO.x, GFX_HERO.y, 0.2) if IslandWorld.current != null \
				else Vector3(GFX_HERO.x, 0.2, GFX_HERO.y)
			main.player.global_position = hp
			main.player.select_target(null)
			main.hud.visible = false
			_gcam = Camera3D.new()
			main.add_child(_gcam)
			_gcam.global_position = Vector3(7.0, 4.5, -2.0)
			_gcam.look_at(Vector3(-1.0, 2.2, -14.0))
			_gcam.current = true
			Quality.set_option("shadows", 0, false)
			Quality.apply(get_tree())
			wait = 20
			step = 943
		943:
			shot("122_shadows_off")
			Quality.set_option("shadows", 1, false)
			Quality.apply(get_tree())
			wait = 20
			step = 944
		944:
			shot("123_shadows_low")
			Quality.set_option("shadows", 3, false)
			Quality.apply(get_tree())
			wait = 20
			step = 945
		945:
			shot("124_shadows_high")
			# Герой крупно (кадры 125–129): тени на модели и сглаживание краёв и контуров
			var pl: Player = main.player
			var front := pl._model.global_transform.basis * Vector3(0, 0, -1)
			front.y = 0.0
			_gcam.global_position = pl.global_position + front.normalized() * 2.6 + Vector3(0.6, 1.4, 0)
			_gcam.look_at(pl.global_position + Vector3(0, 1.0, 0))
			wait = 20
			step = 946
		946:
			shot("125_hero_model_shadows_off")
			# Как было раньше: карта теней на самой модели (самозатенение)
			Quality.set_option("model_shadows", 1, false)
			Quality.apply(get_tree())
			wait = 15
			step = 947
		947:
			shot("126_hero_model_shadows_on")
			Quality.set_option("model_shadows", 0, false)
			Quality.set_option("aa", 0, false)
			Quality.apply(get_tree())
			wait = 15
			step = 948
		948:
			shot("127_aa_off")
			Quality.set_option("aa", 1, false)
			Quality.apply(get_tree())
			wait = 15
			step = 949
		949:
			shot("128_aa_fxaa")
			Quality.set_option("aa", 3, false)
			Quality.apply(get_tree())
			wait = 15
			step = 950
		950:
			shot("129_aa_msaa4")
			Quality.set_level(Quality.HIGH, false)
			Quality.apply(get_tree())
			_gcam.queue_free()
			main.cam.current = true
			main.hud.visible = true
			# Движения манекенов Meshy (tools/retarget_mannequin.py): обычные атаки разным оружием — кадр 140
			_mq_row(MQ_ATTACK_ROW)
			wait = 30
			step = 980
		980:
			shot("140_mq_attacks")
			_heroes.queue_free()
			_top.queue_free()
			# Умения: «Вызов», заряд, кручение клинками, рубящий топором, луч, прыжок с ударом — кадр 141
			_mq_row(MQ_SKILL_ROW)
			wait = 30
			step = 981
		981:
			shot("141_mq_skills")
			_heroes.queue_free()
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			wait = 2
			step = 982
		982:
			wait = 5
			step = 1000
		1000:
			# Оружие и предметы в руках из файлов (Handheld, tools/prepare_handheld.py): ряды крупно
			_handheld_row(HANDHELD_WEAPONS)
			wait = 20
			step = 1001
		1001:
			shot("150_handheld_weapons")
			_handheld_row(HANDHELD_NPC)
			wait = 20
			step = 1002
		1002:
			shot("151_handheld_npc_items")
			_weapon_heroes(HANDHELD_HEROES_A)
			wait = 45
			step = 1003
		1003:
			shot("152_heroes_weapons_a")
			_weapon_heroes(HANDHELD_HEROES_B)
			wait = 45
			step = 1004
		1004:
			shot("153_heroes_weapons_b")
			_handheld_clear()
			wait = 2
			step = 1025
		1025:
			# Жители из Meshy (кадры 160–164): все десять в ряд с предметами, крупно в городе, у лагеря, в деревне
			# эльфов, охотница со спины (колчан)
			_heroes_row([], 1.0, 6.2)
			_npc_row()
			wait = 60
			step = 1020
		1020:
			shot("160_npc_row")
			_heroes.queue_free()
			_top.queue_free()
			_top = Camera3D.new()
			main.add_child(_top)
			_top.current = true
			_npc_view("storekeeper")
			wait = 40
			step = 1021
		1021:
			shot("161_npc_storekeeper")
			_npc_view("smith")
			wait = 40
			step = 1022
		1022:
			shot("162_npc_smith")
			_npc_view("elder_light")
			wait = 40
			step = 1023
		1023:
			shot("163_npc_elder_light")
			_npc_back_view("hunter")
			wait = 40
			step = 1024
		1024:
			shot("164_npc_hunter_back")
			_top.queue_free()
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			wait = 2
			step = 1040
		1040:
			# Хват второй рукой (TwoHandIK, кадры 170–172): двуручное наперевес, лук и арбалет в покое
			_two_hand_row(TWO_HAND_IDLE, 1.05, 3.5, 1.2)
			wait = 45
			step = 1041
		1041:
			_two_hand_log()
			shot("170_two_hand_idle")
			# Удары обеими руками (двуручные клипы манекенов), натяжение лука, выстрел из арбалета
			_two_hand_row(TWO_HAND_ATTACK, 1.1, 3.6, 1.25)
			wait = 45
			step = 1042
		1042:
			_two_hand_log()
			shot("171_two_hand_attack")
			# Крупно: лук натянут, арбалет на изготовку, копьё наперевес
			_two_hand_row(TWO_HAND_CLOSE, 1.2, 2.3, 0.95)
			wait = 45
			step = 1043
		1043:
			_two_hand_log()
			shot("172_two_hand_close")
			_handheld_clear()
			wait = 2
			step = 1060
		1060:
			# Время каста (кадры 180–182): Неофитка в петле накопления силы («Огненный смерч», 1.8 с) — полоса каста
			# с названием под героиней; лучник и арбалетчица в петле прицеливания
			AdminPanel.god = true
			game.admin_set_look("dark_elf", "f")
			_job_showcase("neophyte", ["fire_tornado", "flame_orb", "zap", "thunderclap"], [], 7.0)
			main.player.skill_cd.clear()
			check(main.player.use_skill("skill1") and main.player.casting == "fire_tornado", "кадр 180: каст «Огненного смерча»")
			wait = 30
			step = 1061
		1061:
			check(main.hud.is_cast_visible(), "кадр 180: полоса каста видна")
			shot("180_cast_magic_loop")
			main.player.cancel_cast("")
			game.admin_set_look("human", "m")
			_job_showcase("warrior", ["sticky_arrow", "pin_down", "burning_arrow", "kindle_spark"], [], 8.0)
			if game.inventory.count("weapon_bow_r1") < 1:
				game.inventory.add("weapon_bow_r1", 1)
			main.player.equip("weapon_bow_r1")
			wait = 3
			step = 1062
		1062:
			main.player.skill_cd.clear()
			main.player.mp = main.player.max_mp
			check(main.player.use_skill("skill1") and main.player.casting == "sticky_arrow", "кадр 181: прицеливание из лука")
			wait = 11
			step = 1063
		1063:
			shot("181_cast_bow_aim")
			main.player.cancel_cast("")
			game.admin_set_look("dark_elf", "f")
			_job_showcase("assassin", ["dual_shot", "thrust_arrow", "piercing_arrow", "critical_shot"], [], 8.0)
			if game.inventory.count("crossbow_starter") < 1:
				game.inventory.add("crossbow_starter", 1)
			main.player.equip("crossbow_starter")
			wait = 3
			step = 1064
		1064:
			main.player.skill_cd.clear()
			main.player.mp = main.player.max_mp
			check(main.player.use_skill("skill1") and main.player.casting == "dual_shot", "кадр 182: прицеливание из арбалета")
			wait = 11
			step = 1065
		1065:
			shot("182_cast_crossbow_aim")
			main.player.cancel_cast("")
			wait = 2
			step = 1160
		1160:
			# Оружие 2-го ранга из файлов (кадры 230–232): ряд крупно, герои профессий с оружием 2-го ранга в руках
			_handheld_row(HANDHELD_WEAPONS_R2)
			wait = 20
			step = 1161
		1161:
			shot("230_handheld_weapons_r2")
			_weapon_heroes_r2(HANDHELD_HEROES_R2_A)
			wait = 45
			step = 1162
		1162:
			shot("231_heroes_weapons_r2_a")
			_weapon_heroes_r2(HANDHELD_HEROES_R2_B)
			wait = 45
			step = 1163
		1163:
			shot("232_heroes_weapons_r2_b")
			_handheld_clear()
			# Компактный HUD и значки (кадры 210–217): панели с числами в полосках, значки меню, значки заданий
			# над жителями («!», «?», «=») и красный значок над зверем — целью задания; вкладки окон значками
			game.admin_set_look("human", "m")
			game.level = 12
			main.player.apply_class()
			main.player.hp = int(main.player.max_hp * 0.7)
			main.player.mp = int(main.player.max_mp * 0.45)
			game.xp = int(game.xp_to_next(game.level) * 0.37)
			game.quests_active = {}
			game.quests_done = {}
			game.quest_tracked = ""
			main.quests._changed()
			if main.pets.active_pet == null and game.pets.size() > 0:
				game.pets[0]["dead"] = false
				main.pets.summon(0)
			check(main.quests.accept("elder_hunt"), "кадры 210–213: задание старосты взято")
			wait = 10
			step = 1120
		1120:
			main.hud.update_player(main.player)
			_mark_view(4.5)
			wait = 20
			step = 1121
		1121:
			check(main.hud.player_summary().contains("Ур. 12"), "кадр 210: панель игрока — %s" % main.hud.player_summary())
			shot("210_hud_panels")
			_mark_view(2.6)
			main.cam_dist = 4.5
			main.cam_pitch = 0.22
			wait = 10
			step = 1122
		1122:
			var mk := find_mob("pheasant")
			check(mk != null and mk.quest_mark_visible(), "кадр 211: над фазаном красный значок задания")
			shot("211_mob_quest_mark")
			main.player.select_target(null)
			_talk_view("elder_human")
			wait = 12
			step = 1123
		1123:
			check(main.npcs.npc("elder_human").mark_text() == "?", "кадр 212: над старостой «?»")
			shot("212_npc_mark_active")
			var ph := find_mob("pheasant")
			if ph != null:
				for i in 3:
					main.quests.on_mob_killed(ph)
			main.npcs.refresh_marks()
			wait = 6
			step = 1124
		1124:
			check(main.npcs.npc("elder_human").mark_text() == "=", "кадр 213: над старостой «=»")
			shot("213_npc_mark_complete")
			_talk_view("kirk")
			wait = 12
			step = 1125
		1125:
			check(main.npcs.kirk.mark_text() == "!", "кадр 214: над Кирком «!»")
			shot("214_npc_mark_available")
			SettingsMenu.open(main.hud, "ui")
			wait = 6
			step = 1126
		1126:
			shot("215_settings_tabs_icons")
			main.hud.close_window()
			main.hero_window.open("hero")
			wait = 8
			step = 1127
		1127:
			shot("216_hero_tabs_icons")
			main.hud.close_window()
			UiScale.set_level(UiScale.LARGE, false)
			main.hud.apply_ui_scale()
			_mark_view(4.5)
			wait = 12
			step = 1128
		1128:
			shot("217_hud_large")
			UiScale.set_level(UiScale.MEDIUM, false)
			main.hud.apply_ui_scale()
			wait = 3
			step = 1080
		# ---------- Кадры 190–192: зелья рангов в сумке, золото на складе, мешочки добычи ----------
		1080:
			game.level = 12
			main.player.apply_class()
			for e in POTION_BAG:
				game.inventory.add(String(e[0]), int(e[1]))
			main.economy.open_bag()
			main.economy.window.select_cell(game.inventory.find_cell("potion_hp_r2"))
			wait = 12
			step = 1081
		1081:
			shot("190_bag_potion_ranks")
			main.hud.close_window()
			# Склад: золото на складе, вещи
			_talk_view("storekeeper")
			game.storage_gold = 12500
			game.gold = 3400
			for e in [["potion_mp_r2", 8], ["weapon_staff_2h_r2", 1], ["potion_speed_r1", 4]]:
				game.storage.add(String(e[0]), int(e[1]))
			main.economy.open_storage()
			main.economy.window.select_store(game.storage.find_cell("potion_mp_r2"))
			wait = 12
			step = 1082
		1082:
			shot("191_storage_gold")
			main.hud.close_window()
			# Мешочки добычи у торговца: обычный зверь (2 предмета) и босс (4 — мешочек крупнее); ускорения со значками
			var p: Player = main.player
			var pos := Vector3(0.0, 0.0, 3.2)
			if IslandWorld.current != null:
				pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
			p.global_position = pos
			p.hp = p.max_hp
			main.cam_yaw = 0.25
			main.cam_pitch = 0.3
			main.cam_dist = 6.5
			main.economy.spawn_drop(Vector3(-0.6, 0.0, -0.2), LootTable.roll("wolf", 12), 9)
			main.economy.spawn_drop(Vector3(1.0, 0.0, -1.0), LootTable.roll("boss_panther", 24), 120)
			for id in ["potion_aspd_r2", "potion_speed_r1"]:
				check(main.economy.drink(String(id)), "кадр 192: выпито %s" % id)
			wait = 30
			step = 1083
		1083:
			shot("192_loot_drops")
			wait = 2
			step = 1200
		1200:
			# Бег из манекенов: раскадровка цикла Mq_Running — Воин (6 фаз сбоку) — кадр 250
			_clip_row(_phases(LOCO_HERO, "axe_1h", "mq_running", 6), PI * 0.5)
			wait = 20
			step = 1201
		1201:
			shot("250_run_cycle_hero")
			_clip_row_clear()
			_clip_row(_phases(LOCO_HEROINE, "staff_1h", "mq_running", 6), PI * 0.5)
			wait = 20
			step = 1202
		1202:
			shot("251_run_cycle_heroine")
			_clip_row_clear()
			# Герой и героиня бегут вживую со скоростью героя (7 м/с, темп — по своей скорости клипа) — кадр 252
			_heroes_row([LOCO_HERO, LOCO_HEROINE], 1.4, 4.2)
			for c in _heroes.get_children():
				var m := c as CharacterModel
				m.rotation.y = PI * 0.5
				m.set_move_speed(7.0)
			wait = 50
			step = 1203
		1203:
			for c in _heroes.get_children():
				var m := c as CharacterModel
				check(m.loco_clip().to_lower() == "mq_running", "кадр 252: бег — клип манекена (%s; оружие %s, клип %s, loco %s, скорость %.1f/%.1f, действие %.2f, таблица %d)"
					% [m.loco_clip(), m.weapon_kind, m._anim.current_animation if m._anim != null else "-", m._loco, m._speed,
					m._asset_speed, m._act_end, m._mq_loco_table().size()])
			shot("252_run_live")
			_clip_row_clear()
			# Шаг, трусца и быстрый бег (кадр 253)
			_clip_row(MQ_LOCO_ROW, PI * 0.5)
			wait = 20
			step = 1204
		1204:
			shot("253_walk_jog_sprint")
			_clip_row_clear()
			_clip_row(MQ_NEW_ROW, PI + 0.6)
			wait = 20
			step = 1205
		1205:
			shot("254_mq_new_moves")
			_clip_row_clear()
			_clip_row(MQ_BOW_ROW, PI + 0.6)
			wait = 20
			step = 1206
		1206:
			shot("255_mq_bow_loops")
			_clip_row_clear()
			_clip_row(MQ_TURN_ROW, PI + 0.6)
			wait = 20
			step = 1207
		1207:
			shot("256_mq_turns_emotes")
			_clip_row_clear()
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			wait = 2
			step = 1260
		# ---------- Кадры 280–286: три лавки города (оружейник, бронница, ювелир) ----------
		1260:
			# Три торговца в ряд крупно — кадр 280
			_heroes_row([], 1.3, 3.6)
			_npc_row(SHOP_NPCS, 1.3)
			wait = 60
			step = 1261
		1261:
			shot("280_shop_npcs_row")
			_clip_row_clear()
			_top = Camera3D.new()
			main.add_child(_top)
			_top.current = true
			_npc_view("weaponsmith")
			wait = 40
			step = 1262
		1262:
			shot("281_weaponsmith_place")
			_npc_view("armorer")
			wait = 40
			step = 1263
		1263:
			shot("282_armorer_place")
			_npc_view("jeweler")
			wait = 40
			step = 1264
		1264:
			shot("283_jeweler_place")
			_top.queue_free()
			_top = null
			main.cam.current = true
			main.hud.visible = true
			main.player.visible = true
			_shop_view("armorer")
			wait = 12
			step = 1265
		1265:
			shot("284_armorer_trade")
			main.hud.close_window()
			_shop_view("jeweler")
			wait = 12
			step = 1266
		1266:
			shot("285_jeweler_trade")
			main.hud.close_window()
			_shop_view("weaponsmith")
			wait = 12
			step = 1267
		1267:
			shot("286_weaponsmith_trade")
			main.hud.close_window()
			wait = 2
			step = 1220
		1220:
			# Арты Dark Pact (кадры 260–269): экран загрузки ресурсов (как без пакета: части «не загружены»,
			# предупреждение о размере) — главный арт и логотип
			main.hud.close_window()
			Assets.simulate_missing(true)
			var ld := AssetLoader.new()
			ld.offline = true
			ld.preset_manifest = Assets.manifest_from({"format": 2, "version": "0.25.0", "parts": [
				{"name": "heroes_dark", "hash": "1234567890abcdef", "sha256": SHOT_SHA, "size": 84000000,
					"url": "https://example.invalid/a.pck"},
				{"name": "art", "hash": "abcdef1234567890", "sha256": SHOT_SHA, "size": 4200000,
					"url": "https://example.invalid/b.pck"}]})
			get_tree().root.add_child(ld)
			_menu = ld
			wait = 10
			step = 1221
		1221:
			shot("260_loader_art")
			_menu.queue_free()
			Assets.simulate_missing(false)
			_menu = LoginScreen.new()
			get_tree().root.add_child(_menu)
			wait = 10
			step = 1222
		1222:
			shot("261_login_art")
			_menu.queue_free()
			# Выбор персонажа с портретами: профессия и пол, Бродяга — раса и пол; слот 4 пуст (без портрета)
			Accounts.save_slot(1, {"name": "Лиара", "race": "light_elf", "class": "wizard", "level": 24, "gender": "f"})
			Accounts.save_slot(2, {"name": "Гром_топор", "race": "human", "class": "warrior", "level": 31, "gender": "m"})
			_menu = CharacterSelect.new()
			get_tree().root.add_child(_menu)
			(_menu as CharacterSelect).select(1)
			wait = 10
			step = 1223
		1223:
			for i in 3:
				check((_menu as CharacterSelect).portrait_of(i) != null, "кадр 262: портрет у слота %d" % (i + 1))
			shot("262_select_portraits")
			_menu.queue_free()
			Accounts.delete_slot(1)
			Accounts.delete_slot(2)
			# Шаг «Раса»: арт расы на фоне, описание слева
			_menu = CharacterCreate.new()
			get_tree().root.add_child(_menu)
			(_menu as CharacterCreate)._select_race("dark_elf")
			wait = 10
			step = 1224
		1224:
			check((_menu as CharacterCreate).backdrop() != null, "кадр 263: арт расы на фоне")
			shot("263_create_race_dark")
			(_menu as CharacterCreate)._select_race("light_elf")
			wait = 6
			step = 1225
		1225:
			shot("264_create_race_light")
			(_menu as CharacterCreate)._select_race("human")
			wait = 6
			step = 1226
		1226:
			shot("265_create_race_human")
			(_menu as CharacterCreate).go_next()
			wait = 10
			step = 1227
		1227:
			shot("266_create_jobs_human")
			(_menu as CharacterCreate).go_back()
			(_menu as CharacterCreate)._select_race("dark_elf")
			(_menu as CharacterCreate).go_next()
			wait = 10
			step = 1228
		1228:
			shot("267_create_jobs_dark")
			_menu.queue_free()
			_menu = null
			# Окно выбора профессии у мудреца — карточки с артами профессий
			main.job_window.open("")
			wait = 10
			step = 1229
		1229:
			shot("268_sage_job_window")
			main.hud.close_window()
			# Без пакета ресурсов (часть «art» не загружена): шаг «Раса» без арта — прежний тёмный фон
			Assets.simulate_missing(true)
			_menu = CharacterCreate.new()
			get_tree().root.add_child(_menu)
			wait = 10
			step = 1230
		1230:
			check((_menu as CharacterCreate).backdrop() == null, "кадр 269: без пакета — без арта")
			shot("269_create_race_no_pack")
			_menu.queue_free()
			_menu = null
			Assets.simulate_missing(false)
			wait = 3
			step = 1240
		# ---------- Кадры 270–274: экипировка — броня и украшения в сумке, карточки со сравнением, окно героя, добыча ----------
		1240:
			main.hud.close_window()
			game.level = 15
			main.player.apply_class()
			# Сумка заново: надетое оружие, немного зелий, броня и украшения (герой кадров — Волшебник: доспех мага)
			var keep: Dictionary = {}
			if game.weapon != "":
				keep[game.weapon] = 1
			if game.offhand != "":
				keep[game.offhand] = int(keep.get(game.offhand, 0)) + 1
			game.inventory.from_dict(keep)
			game.inventory.add("potion_hp_r2", 6)
			game.inventory.add("potion_mp_r2", 5)
			var v := ItemData.body_armor_for(game.class_id)
			if v == "":
				v = "mage"
			var worn: Array = ["armor_body_%s_r1" % v] + GEAR_SHOT_WORN
			for id in worn + GEAR_SHOT_BAG + ["armor_body_%s_r2" % v]:
				game.inventory.add(String(id))
			for id in worn:
				check(main.player.equip_gear(String(id)) == "", "кадр 270: надето %s" % id)
			main.player.hp = main.player.max_hp
			main.economy.open_bag()
			main.economy.window.select_equip("body")
			wait = 12
			step = 1241
		1241:
			shot("270_bag_equipment")
			var v2 := ItemData.body_armor_for(game.class_id)
			main.economy.window.select_cell(game.inventory.find_cell("armor_body_%s_r2" % (v2 if v2 != "" else "mage")))
			wait = 8
			step = 1242
		1242:
			shot("271_armor_card_compare")
			main.economy.window.select_cell(game.inventory.find_cell("pendant_hp_r1"))
			wait = 8
			step = 1243
		1243:
			shot("272_jewelry_card_compare")
			main.hud.close_window()
			main.hero_window.open("hero")
			wait = 12
			step = 1244
		1244:
			shot("273_hero_window_equipment")
			main.hud.close_window()
			# Мешочки с бронёй и украшениями: дальний лежит, ближний подобран — сообщение «Подобрано: …»
			var p: Player = main.player
			var pos := Vector3(0.0, 0.0, 3.2)
			if IslandWorld.current != null:
				pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
			p.global_position = pos
			main.cam_yaw = 0.25
			main.cam_pitch = 0.3
			main.cam_dist = 6.5
			main.economy.spawn_drop(Vector3(-1.4, 0.0, -0.6), {"armor_helmet_r1": 1, "armor_boots_r2": 1, "belt_eva_r1": 1}, 14)
			main.economy.spawn_drop(Vector3(0.3, 0.0, 2.6), {"armor_gloves_r1": 1, "ring_aspd_r1": 1}, 9)
			wait = 30
			step = 1245
		1245:
			shot("274_loot_armor_pickup")
			wait = 2
			step = 1300
		1300:
			# Бережение телефона (кадры 290–292): вкладка «Графика» — «Беречь от перегрева», авто-снижение по
			# подставному статусу температуры и восстановление
			_thermal_level = Quality.level()
			Quality.set_level(Quality.ULTRA, false)
			Quality.apply(get_tree())
			SettingsMenu.open(main.hud, "graphics")
			wait = 6
			step = 1301
		1301:
			if is_instance_valid(SettingsMenu._scroll):
				SettingsMenu._scroll.scroll_vertical = 100000
			wait = 4
			step = 1302
		1302:
			shot("290_settings_guard")
			main.hud.close_window()
			# Сильный нагрев (статус 3): три шага вниз — 30 кадров/с, 720p, тени «Низкие»
			_thermal_run(3, 5, 5.0)
			check(Quality.throttle_level() == 3, "кадр 291: авто-снижение — шаг %d" % Quality.throttle_level())
			wait = 20
			step = 1303
		1303:
			shot("291_thermal_throttled")
			# Остыл: шаг вверх раз в минуту прохлады — до графики как выбрана
			_thermal_run(0, 50, 5.0)
			check(Quality.throttle_level() == 0, "кадр 292: графика восстановлена (шаг %d)" % Quality.throttle_level())
			wait = 20
			step = 1304
		1304:
			shot("292_thermal_restored")
			if _thermal_level >= Quality.LOW and _thermal_level <= Quality.ULTRA:
				Quality.set_level(_thermal_level, false)
			Quality.apply(get_tree())
			ok_done()


## Кадры 291–292: ThermalGuard с подставным статусом температуры status, n шагов логики по dt с (кадры в бюджете).
func _thermal_run(status: int, n: int, dt: float) -> void:
	var g := ThermalGuard.current
	if g == null:
		fail("нет ThermalGuard в главной сцене")
		return
	var st := status
	g.force = true
	g.status_source = func() -> int: return st
	g.headroom_source = func() -> int: return -1
	g._settle = 0.0
	for i in n:
		g.tick(dt, 1.0 / float(maxi(Quality.current_fps_cap(), 1)))
	g.force = false
	g.status_source = Callable()
	g.headroom_source = Callable()


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


## Кадры 210–217: игрок в dist м от фазана (цель выделена, над ним красный значок задания), камера за игроком.
func _mark_view(dist: float) -> void:
	var p: Player = main.player
	p.visible = true
	var m := find_mob("pheasant")
	if m == null:
		return
	stand_near(m, dist)
	p.select_target(m)
	main.npcs.refresh_marks()
	main.cam_yaw = atan2(p.global_position.x - m.global_position.x, p.global_position.z - m.global_position.z) + 0.3
	main.cam_pitch = 0.3
	main.cam_dist = 7.0


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


## Кадр 160: все жители (модели из файлов, CharacterModel.npc_spec) с предметами NpcProps в ряд в узле _heroes —
## после _heroes_row([]) (камера и площадь те же). only — только эти жители (кадр 280: три лавки), иначе все,
## кроме лавок (кадр 160 — прежние десять); gap — шаг ряда, м.
func _npc_row(only: Array = [], gap: float = 0.95) -> void:
	var ids: Array = []
	for k in NpcData.NPCS:
		if (only.is_empty() and not SHOP_NPCS.has(k)) or only.has(k):
			ids.append(String(k))
	var base := Vector3(0.0, 0.0, 3.0)
	for i in ids.size():
		var id := String(ids[i])
		var m := CharacterModel.new()
		m.setup(CharacterModel.npc_spec(id))
		_heroes.add_child(m)
		NpcProps.attach(m, id)
		var gp := base + Vector3((float(i) - float(ids.size() - 1) * 0.5) * gap, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		m.global_position = gp
		# Чётные — вполоборота вправо, нечётные — влево: видно предметы в обеих руках и за спиной
		m.rotation.y = PI + (0.35 if i % 2 == 0 else -0.35)


## Кадры 284–286: игрок перед жителем-лавкой (_talk_view), открыта его лавка, выбран первый товар.
func _shop_view(id: String) -> void:
	_talk_view(id)
	main.economy.open_shop(id)
	var goods := InventoryWindow.goods(game.class_id, id)
	check(main.economy.is_shop_open() and main.economy.window.seller == id, "кадр лавки %s: окно открыто" % id)
	if not goods.is_empty():
		main.economy.window._on_cell("good", 0)


## Камера _top в 3 м за спиной жителя (игрок далеко впереди — житель не поворачивается).
func _npc_back_view(id: String) -> void:
	var n: Npc = main.npcs.npc(id)
	if n == null:
		return
	var player: Player = main.player
	var c := n.global_position
	var fwd := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw))
	player.visible = false
	player.global_position = c + fwd * 14.0 + Vector3(0, 0.5, 0)
	n._model.rotation.y = n.face_yaw
	var from := c - fwd.rotated(Vector3.UP, 0.4) * 3.0
	from.y = c.y + 1.6
	_top.global_position = from
	_top.look_at(c + Vector3(0, 1.1, 0))


## Кадры 110–114: игрок в 2.6 м перед жителем id (кнопка «Говорить» видна, диалог не закрывается), камера
## за игроком чуть сбоку — житель в кадре.
func _talk_view(id: String) -> void:
	var n: Npc = main.npcs.npc(id)
	if n == null:
		return
	var p: Player = main.player
	var fwd := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw))
	var pos := n.global_position + fwd * 2.6
	var w := IslandWorld.current
	if w != null:
		pos.y = w.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	p.visible = true
	p.hp = p.max_hp
	main.cam_yaw = atan2(fwd.x, fwd.z) + 0.35
	main.cam_pitch = 0.33
	main.cam_dist = 6.5


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


## Герои в ряд (кадры 140–141), каждый замер в своём клипе манекена Meshy в момент удара (clips.<имя>.hit в
## <модель>.json): клип с начала без смешивания, перемотка к удару, темп 0 — действие держит позу.
func _mq_row(rows: Array) -> void:
	var paths: Array = []
	var weapons: Array = []
	for r in rows:
		var row: Array = r
		paths.append(row[0])
		weapons.append([row[0], row[1], row[2]])
	_heroes_row(paths, 1.45, 7.4, weapons)
	_top.global_position += Vector3(0, 0.3, 0)
	for i in rows.size():
		var row: Array = rows[i]
		var m := _heroes.get_child(i) as CharacterModel
		if m == null or m._anim == null:
			continue
		m.rotation.y = PI + 0.6
		var c := String(m._clips.get(String(row[3]), ""))
		check(c != "", "%s: есть клип %s" % [String(row[0]), String(row[3])])
		if c == "":
			continue
		var clips: Dictionary = CharacterModel.asset_rig(String(row[0])).get("clips", {})
		var info: Dictionary = clips.get(c, {})
		m._anim.play(c, 0.0)
		m._anim.seek(float(info.get("hit", 0.3)), true)
		m._anim.speed_scale = 0.0
		m._act_end = 99.0
		m._act_hit = 99.0


## Строки для _clip_row: одна модель в n фазах клипа (раскадровка цикла).
func _phases(path: String, weapon: String, clip: String, n: int) -> Array:
	var rows: Array = []
	for k in n:
		rows.append([path, weapon, false, clip, float(k) / float(n)])
	return rows


## Герои в ряд (кадры 250–256), каждый замер в своём клипе: [модель, вид оружия, щит, клип, доля клипа (−1 — момент
## удара из .json)]; rot — поворот моделей (PI/2 — боком к камере).
func _clip_row(rows: Array, rot: float) -> void:
	var paths: Array = []
	var weapons: Array = []
	for r in rows:
		var row: Array = r
		paths.append(row[0])
		weapons.append([row[0], row[1], row[2]])
	_heroes_row(paths, 1.25, 7.0, weapons)
	_top.global_position += Vector3(0, 0.2, 0)
	for i in rows.size():
		var row: Array = rows[i]
		var m := _heroes.get_child(i) as CharacterModel
		if m == null or m._anim == null:
			continue
		m.rotation.y = rot
		var c := String(m._clips.get(String(row[3]), ""))
		check(c != "", "%s: есть клип %s" % [String(row[0]), String(row[3])])
		if c == "":
			continue
		var info: Dictionary = CharacterModel.asset_rig(String(row[0])).get("clips", {}).get(c, {})
		var a := m._anim.get_animation(c)
		var at := float(row[4]) * a.length
		if float(row[4]) < 0.0:
			at = float(info.get("hit", 0.3))
		m._anim.play(c, 0.0)
		m._anim.seek(at, true)
		m._anim.speed_scale = 0.0
		m._act_end = 99.0
		m._act_hit = 99.0


func _clip_row_clear() -> void:
	if _heroes != null and is_instance_valid(_heroes):
		_heroes.queue_free()
	if _top != null and is_instance_valid(_top):
		_top.queue_free()
	_heroes = null
	_top = null


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


## Кадры 150–151: оружие 1-го ранга и предметы жителей из файлов (Handheld) в ряд, стоймя, камера спереди.
const HANDHELD_WEAPONS := ["weapon_dagger_r1", "weapon_sword_1h_r1", "weapon_sword_2h_r1", "weapon_axe_1h_r1",
	"weapon_axe_2h_r1", "weapon_mace_1h_r1", "weapon_mace_2h_r1", "weapon_staff_1h_r1", "weapon_staff_2h_r1",
	"weapon_spear_r1", "npc_longbow", "weapon_shield_r1", "weapon_crossbow_r1"]
const HANDHELD_NPC := ["npc_cane", "npc_wand", "npc_hammer", "npc_antlerstaff", "npc_grimoire", "npc_tome",
	"npc_scroll", "npc_keys", "npc_quiver", "npc_longbow"]
## Кадры 152–153: герои профессий с оружием из файлов [модель, вид, предмет, вторая рука].
const HANDHELD_HEROES_A := [
	["hero_swordsman_m", "sword_1h", "weapon_sword_1h_r1", "weapon_shield_r1"],
	["hero_warrior_f", "axe_2h", "weapon_axe_2h_r1", ""],
	["hero_wizard_f", "staff_2h", "weapon_staff_2h_r1", ""],
	["hero_assassin_m", "daggers", "weapon_dagger_r1", "weapon_dagger_r1"],
	["hero_beastmaster_m", "mace_2h", "weapon_mace_2h_r1", ""],
	["hero_conjurer_m", "dual_axes", "weapon_axe_1h_r1", "weapon_axe_1h_r1"],
]
const HANDHELD_HEROES_B := [
	["hero_swordsman_f", "sword_2h", "weapon_sword_2h_r1", ""],
	["hero_warrior_m", "bow", "weapon_bow_r1", ""],
	["hero_assassin_f", "crossbow", "crossbow_starter", ""],
	["hero_neophyte_m", "staff_1h", "weapon_staff_1h_r1", ""],
	["hero_adept_f", "dagger", "weapon_dagger_r1", "weapon_shield_r1"],
	["hero_swordsman_m", "spear", "weapon_spear_r1", ""],
]
## Кадры 230–232: оружие 2-го ранга (модели weapon_*_r2) в ряд и в руках героев [модель героя, вид, модель
## основной руки, модель второй руки].
const HANDHELD_WEAPONS_R2 := ["weapon_dagger_r2", "weapon_sword_1h_r2", "weapon_sword_2h_r2", "weapon_axe_1h_r2",
	"weapon_axe_2h_r2", "weapon_mace_1h_r2", "weapon_mace_2h_r2", "weapon_staff_1h_r2", "weapon_staff_2h_r2",
	"weapon_spear_r2", "weapon_bow_r2", "weapon_shield_r2", "weapon_crossbow_r2"]
const HANDHELD_HEROES_R2_A := [
	["hero_swordsman_m", "sword_1h", "weapon_sword_1h_r2", "weapon_shield_r2"],
	["hero_warrior_f", "axe_2h", "weapon_axe_2h_r2", ""],
	["hero_wizard_f", "staff_2h", "weapon_staff_2h_r2", ""],
	["hero_assassin_m", "daggers", "weapon_dagger_r2", "weapon_dagger_r2"],
	["hero_beastmaster_m", "mace_2h", "weapon_mace_2h_r2", ""],
	["hero_conjurer_m", "dual_axes", "weapon_axe_1h_r2", "weapon_axe_1h_r2"],
]
const HANDHELD_HEROES_R2_B := [
	["hero_swordsman_f", "sword_2h", "weapon_sword_2h_r2", ""],
	["hero_warrior_m", "bow", "weapon_bow_r2", ""],
	["hero_assassin_f", "crossbow", "weapon_crossbow_r2", ""],
	["hero_neophyte_m", "staff_1h", "weapon_staff_1h_r2", ""],
	["hero_human_m_starter", "mace_1h", "weapon_mace_1h_r2", "weapon_shield_r2"],
	["hero_swordsman_m", "spear", "weapon_spear_r2", ""],
]
## Узлы оружия второй руки у CharacterModel (остальные узлы с меткой "handheld" — основная рука).
const OFFHAND_NODES := ["Shield", "DaggerL", "AxeL", "SwordL"]
var _hh_row: Node3D = null
var _hh_cam: Camera3D = null
## Хват второй рукой (кадры 170–172): [модель героя, вид ItemData, предмет, клип ("" — покой), момент клипа, с,
## поворот к камере, рад].
const TWO_HAND_IDLE := [
	["hero_warrior_m", "sword_2h", "weapon_sword_2h_r1", "", 0.0, 0.35],
	["hero_swordsman_f", "spear", "weapon_spear_r1", "", 0.0, 0.35],
	["hero_warrior_f", "axe_2h", "weapon_axe_2h_r1", "", 0.0, 0.35],
	["hero_wizard_f", "staff_2h", "weapon_staff_2h_r1", "", 0.0, 0.35],
	["hero_light_elf_m_starter", "bow", "weapon_bow_r1", "", 0.0, 0.6],
	["hero_assassin_f", "crossbow", "crossbow_starter", "", 0.0, 0.6],
]
const TWO_HAND_ATTACK := [
	["hero_warrior_m", "sword_2h", "weapon_sword_2h_r1", "mq_heavy_swing", 0.3, 0.5],
	["hero_swordsman_f", "spear", "weapon_spear_r1", "mq_leap_slam", 0.65, 0.5],
	["hero_beastmaster_m", "mace_2h", "weapon_mace_2h_r1", "mq_heavy_swing", 0.55, 0.5],
	["hero_warrior_f", "bow", "weapon_bow_r1", "mq_bow_draw", 0.9, 1.2],
	["hero_light_elf_m_starter", "bow", "weapon_bow_r1", "mq_bow_shot", 0.5, 1.2],
	["hero_assassin_m", "crossbow", "crossbow_starter", "crossbow_shoot", 0.2, 0.9],
]
const TWO_HAND_CLOSE := [
	["hero_warrior_f", "bow", "weapon_bow_r1", "mq_bow_draw", 0.9, 1.3],
	["hero_assassin_f", "crossbow", "crossbow_starter", "", 0.0, 0.8],
	["hero_human_m_starter", "spear", "weapon_spear_r1", "", 0.0, 0.4],
]


## Площадь города перед ратушей: ряд узлов, камера спереди (HUD и игрок скрыты).
func _handheld_stage(look_h: float, dist: float) -> Vector3:
	_handheld_clear()
	var player: Player = main.player
	player.visible = false
	main.pets.recall()
	var base := Vector3(0.0, 0.0, 3.0)
	if IslandWorld.current != null:
		base.y = IslandWorld.current.height_at(base.x, base.z)
	player.global_position = base + Vector3(0, 0.1, -6.0)
	_hh_row = Node3D.new()
	_hh_row.name = "HandheldRow"
	main.add_child(_hh_row)
	_hh_cam = Camera3D.new()
	main.add_child(_hh_cam)
	_hh_cam.global_position = base + Vector3(0, look_h + 0.1, dist)
	_hh_cam.look_at(base + Vector3(0, look_h, 0))
	_hh_cam.current = true
	main.hud.visible = false
	return base


## Предметы ids стоймя в ряд (нижний конец на земле; арбалет — ложем вбок на высоте пояса, лук — профилем).
func _handheld_row(ids: Array) -> void:
	var gap := 0.42
	var base := _handheld_stage(0.9, 2.6)
	for i in ids.size():
		var id := String(ids[i])
		var w := Handheld.make(id)
		check(w != null, "кадр предметов: модель %s из файла" % id)
		if w == null:
			continue
		_hh_row.add_child(w)
		var x := (float(i) - float(ids.size() - 1) * 0.5) * gap
		match Handheld.frame(id):
			"crossbow":
				w.rotation.y = PI * 0.5
				w.global_position = base + Vector3(x, 0.9, 0)
			"bow":
				w.rotation.y = -PI * 0.5
				w.global_position = base + Vector3(x, 0.75, 0)
			_:
				var butt := Handheld.point(id, "butt")
				w.global_position = base + Vector3(x, 0.03 - butt.y, 0)
		print("  %s: %s, длина %.2f м" % [id, Handheld.frame(id), float(Handheld.info(id).get("length", 0.0))])


## Герои профессий с оружием из файлов в ряд (Idle), камера спереди.
func _weapon_heroes(list: Array) -> void:
	var gap := 1.25
	var base := _handheld_stage(1.0, 3.6)
	for i in list.size():
		var e: Array = list[i]
		var path := CharacterModel.HERO_ASSET_DIR + String(e[0]) + ".glb"
		var spec := CharacterModel.spec_for("dark_elf", "assassin", String(e[1]), "f", ItemData.is_shield(String(e[3])),
			String(e[2]), String(e[3]))
		spec["asset"] = path
		var m := CharacterModel.new()
		m.setup(spec)
		_hh_row.add_child(m)
		var gp := base + Vector3((float(i) - float(list.size() - 1) * 0.5) * gap, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		m.global_position = gp
		m.rotation.y = PI + 0.3
		var held: PackedStringArray = []
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			if (mi as Node).has_meta("handheld"):
				held.append("%s=%s" % [mi.name, String((mi as Node).get_meta("handheld"))])
		print("  %s (%s): %s" % [String(e[0]), String(e[1]), ", ".join(held)])


## Предмет ItemData, у которого модель в руках — model_id (поле "model"); "" — такого предмета нет.
func _item_with_model(model_id: String) -> String:
	if model_id == "":
		return ""
	for k in ItemData.ITEMS:
		if String(ItemData.get_item(String(k)).get("model", "")) == model_id:
			return String(k)
	return ""


## Герои с оружием 2-го ранга (кадры 231–232): предмет с полем "model" — через CharacterModel.spec_for (как в игре);
## нет такого предмета — герой с моделью вида, затем меш в руке заменяется моделью 2-го ранга (рамка осей та же).
func _weapon_heroes_r2(list: Array) -> void:
	var gap := 1.25
	var base := _handheld_stage(1.0, 3.6)
	for i in list.size():
		var e: Array = list[i]
		var main_id := String(e[2])
		var off_id := String(e[3])
		var main_item := _item_with_model(main_id)
		var off_item := _item_with_model(off_id)
		var shield := off_id != "" and Handheld.frame(off_id) == "shield"
		var spec := CharacterModel.spec_for("dark_elf", "assassin", String(e[1]), "f", shield, main_item, off_item)
		spec["asset"] = CharacterModel.HERO_ASSET_DIR + String(e[0]) + ".glb"
		var m := CharacterModel.new()
		m.setup(spec)
		_hh_row.add_child(m)
		var gp := base + Vector3((float(i) - float(list.size() - 1) * 0.5) * gap, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		m.global_position = gp
		m.rotation.y = PI + 0.3
		var held: PackedStringArray = []
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var w := n as MeshInstance3D
			if not w.has_meta("handheld"):
				continue
			var want := off_id if OFFHAND_NODES.has(String(w.name)) else main_id
			if want != "" and String(w.get_meta("handheld")) != want and Handheld.exists(want):
				w.mesh = Handheld.mesh(want)
				w.material_override = Handheld.material(want)
				w.set_meta("handheld", want)
			check(String(w.get_meta("handheld")) == want, "кадр оружия 2-го ранга: %s, %s — модель %s (%s)" % [
				String(e[0]), String(w.name), want, String(w.get_meta("handheld"))])
			held.append("%s=%s" % [w.name, String(w.get_meta("handheld"))])
		check(not held.is_empty(), "кадр оружия 2-го ранга: у %s оружие в руках" % String(e[0]))
		print("  %s (%s, предмет «%s»): %s" % [String(e[0]), String(e[1]), main_item, ", ".join(held)])


## Герои с двуручным, луком и арбалетом в ряд (кадры 170–172): покой или клип, замерший в момент (темп 0); камера
## спереди на высоте look_h в dist м, шаг ряда gap м. В лог — вес и промах кулака второй руки (TwoHandIK).
func _two_hand_row(list: Array, look_h: float, dist: float, gap: float) -> void:
	var base := _handheld_stage(look_h, dist)
	for i in list.size():
		var e: Array = list[i]
		var spec := CharacterModel.spec_for("dark_elf", "assassin", String(e[1]), "f", false, String(e[2]))
		spec["asset"] = CharacterModel.HERO_ASSET_DIR + String(e[0]) + ".glb"
		var m := CharacterModel.new()
		m.setup(spec)
		_hh_row.add_child(m)
		var gp := base + Vector3((float(i) - float(list.size() - 1) * 0.5) * gap, 0, 0)
		if IslandWorld.current != null:
			gp.y = IslandWorld.current.height_at(gp.x, gp.z)
		m.global_position = gp
		m.rotation.y = PI + float(e[5])
		check(m._ik != null, "кадр хвата: %s с «%s» — вторая рука на оружии (TwoHandIK)" % [String(e[0]), String(e[1])])
		var key := String(e[3])
		if key == "" or m._anim == null:
			continue
		var c := String(m._clips.get(key, ""))
		check(c != "", "кадр хвата: %s — есть клип %s" % [String(e[0]), key])
		if c == "":
			continue
		m._anim.play(c, 0.0)
		m._anim.seek(float(e[4]), true)
		m._anim.speed_scale = 0.0
		m._act_end = 99.0
		m._act_hit = 99.0


## В лог: у каждого героя ряда — клип, вес хвата второй руки и промах кулака до цели (по позе костей).
func _two_hand_log() -> void:
	if _hh_row == null:
		return
	for n in _hh_row.get_children():
		var m := n as CharacterModel
		if m == null or m._ik == null:
			continue
		var ik := m._ik
		print("  хват %s: %s, клип %s, вес %.2f, точка %s" % [String(m.spec.get("asset", "")).get_file(), ik.hold,
			ik.clip, ik.last_weight, ik.last_point])


func _handheld_clear() -> void:
	if _hh_row != null:
		_hh_row.queue_free()
		_hh_row = null
	if _hh_cam != null:
		_hh_cam.queue_free()
		_hh_cam = null
	main.cam.current = true
	main.hud.visible = true
	(main.player as Player).visible = true


func shot(shot_name: String) -> void:
	# Перемотка к точке входа части: кадр снимает другая часть
	if _skipping:
		return
	var img := get_viewport().get_texture().get_image()
	var path := SHOTS_DIR + shot_name + ".png"
	var err := img.save_png(path)
	check(err == OK, "скриншот %s (%dx%d), %.0f с от запуска" % [shot_name, img.get_width(), img.get_height(),
		float(Time.get_ticks_msec() - _t0) / 1000.0])


## Туман на высоте 250 м заливает весь кадр — для вида сверху выключаем.
func _set_fog(on: bool) -> void:
	for n in main.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if we != null and we.environment != null:
			we.environment.fog_enabled = on
