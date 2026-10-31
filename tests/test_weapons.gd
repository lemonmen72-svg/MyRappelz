extends "res://tests/test_base.gd"
## Оружие профессий (решения Максима): какие виды разрешены каждой профессии (ровно по списку, Бродяге — любые),
## вторая рука (щит — только у профессий со щитом и к одноручному, пара — два одинаковых одноручных, двуручное
## освобождает вторую руку), бонусы вида (физ. / маг. атака, скорость атаки −40…+25 %, скорость каста посохов,
## щит — защита и шанс блока, блок срабатывает), стартовые наборы, перевод старых парных предметов Наёмника,
## умения Наёмника с одним и двумя кинжалами / мечами и арбалетом, умения щита, лука и двух топоров.

## Виды оружия профессий — дословно по списку Максима (пары — «один или два»).
const EXPECT := {
	"assassin": ["dagger", "daggers", "sword_1h", "dual_swords", "crossbow"],
	"adept": ["dagger", "staff_1h", "staff_2h", "shield"],
	"neophyte": ["staff_1h", "staff_2h"],
	"swordsman": ["sword_2h", "sword_1h", "dual_swords", "shield", "mace_2h", "mace_1h"],
	"wizard": ["staff_1h", "staff_2h"],
	"beastmaster": ["mace_2h", "staff_1h", "staff_2h"],
	"warrior": ["bow", "axe_2h", "axe_1h", "dual_axes"],
	"conjurer": ["axe_2h", "axe_1h", "dual_axes"],
	"shaman": ["staff_2h", "axe_2h"],
}
## Оружие 1-го ранга всех видов (у торговца).
const R1 := ["weapon_sword_1h_r1", "weapon_sword_2h_r1", "weapon_dagger_r1", "weapon_mace_1h_r1", "weapon_mace_2h_r1",
	"weapon_axe_1h_r1", "weapon_axe_2h_r1", "weapon_staff_1h_r1", "weapon_staff_2h_r1", "weapon_shield_r1",
	"crossbow_starter", "weapon_bow_r1"]
## Скорость атаки вида, % (Максим; булавы — как топоры).
const ASPD := {"sword_2h": -15, "sword_1h": -5, "dagger": 25, "axe_1h": -10, "axe_2h": -25, "crossbow": -20, "bow": -40,
	"mace_1h": -10, "mace_2h": -20, "staff_1h": 0, "staff_2h": 0}
## Скорость каста, %.
const CAST := {"staff_1h": 20, "staff_2h": 10}
## Какие атаки даёт вид.
const STATS := {"sword_2h": ["atk"], "sword_1h": ["atk"], "dagger": ["atk", "matk"], "axe_1h": ["atk", "matk"],
	"axe_2h": ["atk", "matk"], "crossbow": ["atk"], "bow": ["atk"], "staff_1h": ["matk"], "staff_2h": ["matk"],
	"mace_1h": ["atk", "matk"], "mace_2h": ["atk", "matk"]}
## Стартовое оружие профессии: [в руке, во второй руке].
const STARTER := {
	"swordsman": ["weapon_sword_1h_r1", "weapon_shield_r1"], "warrior": ["weapon_axe_2h_r1", ""],
	"conjurer": ["weapon_axe_1h_r1", ""], "shaman": ["weapon_staff_2h_r1", ""], "wizard": ["weapon_staff_2h_r1", ""],
	"neophyte": ["weapon_staff_2h_r1", ""], "beastmaster": ["weapon_mace_2h_r1", ""],
	"adept": ["weapon_dagger_r1", "weapon_shield_r1"], "assassin": ["weapon_dagger_r1", "weapon_dagger_r1"],
	"wanderer": ["weapon_sword_1h_r1", ""],
}

var mob: Mob = null


func race_class() -> Array:
	return ["human", "wanderer"]


func hero_level() -> int:
	return 25


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			_check_kinds()
			_check_items()
			_check_offhand_rules()
			_check_skill_groups()
			_check_migration_data()
			step = 1
		1:
			_check_bonuses(player)
			_check_pairs(player)
			_check_shield(player)
			step = 2
		2:
			_check_jobs(player)
			step = 3
		3:
			_check_assassin(player)
			_check_job_skills(player)
			step = 4
		4:
			_check_old_saves(player)
			ok_done()


# ---------- Данные ----------

func _check_kinds() -> void:
	for j in EXPECT:
		var job := String(j)
		var have: Array = ClassData.weapons(job).duplicate()
		var want: Array = (EXPECT[job] as Array).duplicate()
		have.sort()
		want.sort()
		check(have == want, "%s: виды оружия %s" % [ClassData.job_name(job), have])
		for k in have:
			check(ItemData.WEAPON_KINDS.has(String(k)), "%s: вид %s известен" % [job, k])
	var all: Array = ItemData.WEAPON_KINDS.keys()
	for k in all:
		check(ClassData.weapons(ClassData.WANDERER).has(String(k)), "Бродяге доступно: %s" % ItemData.weapon_kind_name(String(k)))
	for id in R1:
		check(ItemData.weapon_fits(String(id), ClassData.WANDERER), "Бродяга носит %s" % ItemData.item_name(String(id)))
	check(ClassData.CLASSES.size() == EXPECT.size() + 1, "все профессии проверены")


func _check_items() -> void:
	var kinds: Dictionary = {}
	for id in R1:
		var sid := String(id)
		var k := ItemData.weapon_kind(sid)
		kinds[k] = true
		check(ItemData.is_weapon(sid) and ItemData.rank(sid) == 1, "%s: оружие 1-го ранга" % sid)
		check(NpcData.shop("merchant").has(sid) and int(ItemData.get_item(sid)["buy"]) > 0, "%s: продаёт торговец" % sid)
		check(InventoryWindow.goods(ClassData.WANDERER).has(sid), "%s: Бродяге в товарах" % sid)
		var b := ItemData.weapon_bonus(sid)
		if k == "shield":
			check(int(b["def"]) > 0 and float(b["block"]) > 0.0 and int(b["atk"]) == 0 and int(b["aspd"]) == 0,
				"щит: защита +%d, блок %d%%" % [int(b["def"]), roundi(float(b["block"]) * 100.0)])
			continue
		check(int(b["aspd"]) == int(ASPD[k]), "%s: скорость атаки %+d%%" % [ItemData.weapon_kind_name(k), int(b["aspd"])])
		check(int(b["cast"]) == int(CAST.get(k, 0)), "%s: скорость каста %+d%%" % [ItemData.weapon_kind_name(k), int(b["cast"])])
		var st: Array = STATS[k]
		check((int(b["atk"]) > 0) == st.has("atk") and (int(b["matk"]) > 0) == st.has("matk"),
			"%s: физ. атака +%d, маг. атака +%d" % [ItemData.weapon_kind_name(k), int(b["atk"]), int(b["matk"])])
		check(ItemData.weapon_stats_text(sid) != "", "%s: строка бонусов «%s»" % [sid, ItemData.weapon_stats_text(sid)])
	# Есть предмет каждого одиночного вида (пары — два одиночных)
	for k in ItemData.WEAPON_KINDS:
		var kind := String(k)
		if ItemData.hands(kind) is String and String(ItemData.hands(kind)) == "dual":
			check(kinds.has(ItemData.single_kind(kind)), "пара %s — из двух «%s»" % [kind, ItemData.single_kind(kind)])
		else:
			check(kinds.has(kind), "есть оружие 1-го ранга: %s" % ItemData.weapon_kind_name(kind))
	check(ItemData.icon_shape("weapon_bow_r1") == "bow", "лук: процедурный значок «bow»")
	check(InventoryWindow.goods("warrior").has("weapon_bow_r1") and not InventoryWindow.goods("warrior").has("weapon_staff_2h_r1"),
		"Воину торговец предлагает лук, но не посох")


func _check_offhand_rules() -> void:
	# [профессия, в руке, во второй руке, можно]
	var cases := [
		["assassin", "weapon_dagger_r1", "weapon_dagger_r1", true], ["assassin", "weapon_sword_1h_r1", "sword_steel", true],
		["assassin", "weapon_dagger_r1", "weapon_sword_1h_r1", false], ["assassin", "crossbow_starter", "weapon_dagger_r1", false],
		["assassin", "weapon_dagger_r1", "weapon_shield_r1", false],
		["swordsman", "weapon_sword_1h_r1", "weapon_shield_r1", true], ["swordsman", "weapon_mace_1h_r1", "weapon_shield_r1", true],
		["swordsman", "weapon_sword_2h_r1", "weapon_shield_r1", false], ["swordsman", "weapon_mace_2h_r1", "weapon_shield_r1", false],
		["swordsman", "weapon_sword_1h_r1", "weapon_sword_1h_r1", true], ["swordsman", "weapon_mace_1h_r1", "weapon_mace_1h_r1", false],
		["adept", "weapon_dagger_r1", "weapon_shield_r1", true], ["adept", "weapon_staff_1h_r1", "weapon_shield_r1", true],
		["adept", "weapon_staff_2h_r1", "weapon_shield_r1", false], ["adept", "weapon_dagger_r1", "weapon_dagger_r1", false],
		["warrior", "weapon_axe_1h_r1", "weapon_axe_1h_r1", true], ["warrior", "weapon_axe_2h_r1", "weapon_axe_1h_r1", false],
		["warrior", "weapon_bow_r1", "weapon_axe_1h_r1", false], ["warrior", "weapon_axe_1h_r1", "weapon_shield_r1", false],
		["conjurer", "weapon_axe_1h_r1", "weapon_axe_1h_r1", true], ["shaman", "weapon_axe_2h_r1", "weapon_axe_2h_r1", false],
		["wizard", "weapon_staff_1h_r1", "weapon_shield_r1", false], ["wizard", "weapon_staff_1h_r1", "weapon_staff_1h_r1", false],
		["wanderer", "weapon_dagger_r1", "weapon_shield_r1", true], ["wanderer", "weapon_dagger_r1", "weapon_dagger_r1", true],
		["wanderer", "weapon_mace_1h_r1", "weapon_shield_r1", true], ["wanderer", "weapon_staff_2h_r1", "weapon_shield_r1", false],
	]
	for c in cases:
		var e: Array = c
		var err := ItemData.offhand_block(String(e[2]), String(e[1]), String(e[0]))
		check((err == "") == bool(e[3]), "%s: %s + %s во второй руке — %s%s" % [ClassData.job_name(String(e[0])),
			ItemData.item_name(String(e[1])), ItemData.item_name(String(e[2])), "можно" if bool(e[3]) else "нельзя",
			"" if err == "" else " («%s»)" % err])
	check(ItemData.grip_kind("weapon_dagger_r1", "dagger_steel") == "daggers"
		and ItemData.grip_kind("weapon_sword_1h_r1", "weapon_shield_r1") == "sword_1h"
		and ItemData.grip_kind("weapon_axe_1h_r1", "weapon_axe_1h_r1") == "dual_axes"
		and ItemData.grip_kind("weapon_dagger_r1", "") == "dagger", "вид хвата: пара — два одинаковых одноручных")


## У каждого умения с оружием есть хотя бы одна группа, оружие которой профессия может держать.
func _check_skill_groups() -> void:
	for j in EXPECT:
		var job := String(j)
		var kinds := ClassData.weapons(job)
		var bad := ""
		for id in HeroSkills.list_for(job):
			var sid := String(id)
			var need := HeroSkills.weapon_need(sid, job)
			if need.is_empty():
				continue
			var ok := false
			for g in need:
				var gd: Dictionary = HeroSkills.WEAPON_GROUPS[String(g)]
				if bool(gd.get("shield", false)):
					ok = ok or kinds.has("shield")
				for k in gd.get("kinds", []):
					ok = ok or kinds.has(String(k))
			if not ok:
				bad += " %s %s" % [sid, need]
		check(bad == "", "%s: умения подходят оружию профессии%s" % [ClassData.job_name(job), bad])
	check(HeroSkills.weapon_need("faith_staff", "wizard") == ["staff"] and HeroSkills.weapon_need("dark_rod", "neophyte") == ["staff"]
		and HeroSkills.weapon_need("spin_strike", "warrior") == ["axe"], "у Волшебника, Неофита и Воина — свои виды")


func _check_migration_data() -> void:
	var m: Dictionary = Game.migrate_items({"daggers_starter": 1, "dual_swords_steel": 1, "crossbow_starter": 1, "dual_swords_starter": 2})
	check(int(m.get("weapon_dagger_r1", 0)) == 2 and int(m.get("sword_steel", 0)) == 2 and int(m.get("crossbow_starter", 0)) == 1
		and int(m.get("weapon_sword_1h_r1", 0)) == 4, "прежние пары → по два одиночных клинка: %s" % [m])
	for old in ["daggers_starter", "dual_swords_starter", "daggers_steel", "dual_swords_steel"]:
		check(ItemData.get_item(String(old)).is_empty() and ItemData.is_weapon(ItemData.migrate_id(String(old))),
			"%s → %s" % [old, ItemData.migrate_id(String(old))])


# ---------- Бонусы оружия в производных героя ----------

func _base_aspd(player: Player) -> float:
	return float(player.hero_stats["aspd"]) / 100.0


func _check_bonuses(player: Player) -> void:
	for id in R1:
		var sid := String(id)
		if ItemData.is_shield(sid):
			continue
		if not game.inventory.has(sid):
			game.inventory.add(sid)
		check(player.equip(sid) == "" and game.weapon == sid, "Бродяга надел %s" % ItemData.item_name(sid))
		var k := ItemData.weapon_kind(sid)
		var it := ItemData.get_item(sid)
		var hs := player.hero_stats
		var want := _base_aspd(player) + float(ASPD[k]) / 100.0
		check(is_equal_approx(player.aspd, want) and is_equal_approx(player.weapon_aspd, float(ASPD[k]) / 100.0),
			"%s: скорость атаки %d%% (%+d%%)" % [ItemData.weapon_kind_name(k), roundi(player.aspd * 100.0), int(ASPD[k])])
		check(is_equal_approx(player.cast_speed, float(CAST.get(k, 0)) / 100.0), "%s: скорость каста %+d%%"
			% [ItemData.weapon_kind_name(k), roundi(player.cast_speed * 100.0)])
		var t := ItemData.base_cd(k) / player.aspd / (1.0 + player.cast_speed if player.attack_kind == "magic" else 1.0)
		check(is_equal_approx(player.attack_time, t), "%s: удар раз в %.2f с" % [ItemData.weapon_kind_name(k), player.attack_time])
		var matk_want := int(hs["matk"]) + int(it.get("matk", 0))
		match player.attack_kind:
			"magic":
				check(player.matk == matk_want and player.atk == player.matk, "%s: маг. атака %d = %d + %d, удар — магией"
					% [ItemData.weapon_kind_name(k), player.matk, int(hs["matk"]), int(it.get("matk", 0))])
			"ranged":
				check(player.atk == int(hs["ratk"]) + int(it["atk"]) and player.matk == int(hs["matk"]),
					"%s: атака %d = стрельба %d + %d" % [ItemData.weapon_kind_name(k), player.atk, int(hs["ratk"]), int(it["atk"])])
			_:
				var mk_add := int(it.get("matk", 0)) if (STATS[k] as Array).has("matk") else 0
				check(player.atk == int(hs["patk"]) + int(it["atk"]) and player.matk == int(hs["matk"]) + mk_add,
					"%s: физ. атака %d (+%d), маг. атака %d (+%d)" % [ItemData.weapon_kind_name(k), player.atk, int(it["atk"]),
					player.matk, mk_add])
	# Кинжал: и физ., и маг. атака; маг. атака оружия усиливает заклинания (cur_matk)
	check(player.equip("weapon_dagger_r1") == "", "кинжал")
	check(player.atk > int(player.hero_stats["patk"]) and player.matk > int(player.hero_stats["matk"])
		and player.cur_matk() == player.matk, "кинжал: физ. %d и маг. %d атака выше статов" % [player.atk, player.matk])
	# Посохи: каст быстрее — пауза после заклинания короче
	check(player.equip("weapon_staff_1h_r1") == "", "одноручный посох")
	check(is_equal_approx(player.cast_time(), Player.CAST_TIME / 1.2), "одноручный посох: каст %.2f с (+20%%)" % player.cast_time())
	check(player.equip("weapon_staff_2h_r1") == "", "двуручный посох")
	check(is_equal_approx(player.cast_time(), Player.CAST_TIME / 1.1), "двуручный посох: каст %.2f с (+10%%)" % player.cast_time())
	check(Player.is_spell(HeroSkills.get_skill("fire_spark", "neophyte")) and not Player.is_spell(HeroSkills.get_skill("backstab", "assassin")),
		"заклинание — магическое умение, удар — нет")
	# Окно героя: скорость каста в показателях, кнопки оружия
	main.hero_window.open("hero")
	var wt := _window_text()
	check(wt.contains("Скорость каста") and wt.contains("Скорость атаки"), "в окне героя — скорость атаки и каста")
	check(main.hero_window.buttons.has("weapon_weapon_bow_r1"), "в окне героя можно выбрать лук")
	main.hud.close_window()


## Пары: второй такой же одноручный во второй руке; атаки обеих рук складываются, скорость — по основному.
func _check_pairs(player: Player) -> void:
	for pair in [["weapon_dagger_r1", "daggers", ["DaggerR", "DaggerL"]], ["weapon_sword_1h_r1", "dual_swords", ["Sword", "SwordL"]],
			["weapon_axe_1h_r1", "dual_axes", ["Axe", "AxeL"]]]:
		var e: Array = pair
		var id := String(e[0])
		var have: int = game.inventory.count(id)
		if have < 2:
			game.inventory.add(id, 2 - have)
		check(player.equip(id) == "", "%s в руке" % ItemData.item_name(id))
		var one_atk := player.atk
		var one_aspd := player.aspd
		check(player.equip(id, true) == "" and game.offhand == id and player.weapon_kind == String(e[1]),
			"второй %s во второй руке — %s" % [ItemData.item_name(id), ItemData.weapon_kind_name(String(e[1]))])
		check(player.atk == one_atk + int(ItemData.get_item(id)["atk"]) and is_equal_approx(player.aspd, one_aspd),
			"%s: атака %d → %d, скорость атаки та же" % [String(e[1]), one_atk, player.atk])
		check(game.inventory.find_cell(id) == -1, "%s: обе штуки в руках, в ячейках нет" % String(e[1]))
		if player._model._asset != null:
			for part in e[2]:
				check(player._model.find_child(String(part), true, false) != null, "%s: в модели %s" % [String(e[1]), String(part)])
		game.inventory.remove(id, game.inventory.count(id) - 2)
	# Одноручные булавы парой не носят
	game.inventory.remove("weapon_mace_1h_r1", game.inventory.count("weapon_mace_1h_r1"))
	game.inventory.add("weapon_mace_1h_r1", 2)
	check(player.equip("weapon_mace_1h_r1") == "" and player.equip("weapon_mace_1h_r1", true) != "", "две булавы — нельзя")
	# Двуручное освобождает вторую руку
	check(player.equip("weapon_dagger_r1") == "" and player.equip("weapon_dagger_r1", true) == "", "снова два кинжала")
	check(player.equip("weapon_axe_2h_r1") == "" and game.offhand == "" and player.weapon_kind == "axe_2h",
		"двуручный топор — вторая рука пуста")
	check(game.inventory.count("weapon_dagger_r1") == 2 and game.inventory.find_cell("weapon_dagger_r1") >= 0,
		"кинжалы вернулись в сумку")
	check(player.equip("weapon_dagger_r1", true) != "", "к двуручному кинжал во вторую руку не взять")
	# Лук: двуручный, стреляет стрелами, модель — лук в левой руке
	check(player.equip("weapon_bow_r1") == "" and player.attack_kind == "ranged" and player.weapon_kind == "bow", "лук")
	if player._model._asset != null:
		check(player._model.find_child("Bow", true, false) != null, "в модели лук")
	mob = find_mob("pheasant")
	check(mob != null, "фазан для выстрела из лука")
	stand_near(mob, 6.0)
	player.select_target(mob)
	player.attack_cd = 0.0
	check(player.try_attack(), "выстрел из лука")
	var arrows := 0
	for n in get_tree().get_nodes_in_group("projectiles"):
		if (n as Projectile).kind == "arrow":
			arrows += 1
	check(arrows > 0, "летит стрела (%d)" % arrows)


func _check_shield(player: Player) -> void:
	if not game.inventory.has("weapon_shield_r1"):
		game.inventory.add("weapon_shield_r1")
	check(player.equip("weapon_sword_1h_r1") == "", "меч")
	var def0 := player.defense
	var block0 := player.block
	check(player.equip("weapon_shield_r1") == "" and player.has_shield and game.shield == "weapon_shield_r1", "щит во второй руке")
	var sh := ItemData.weapon_bonus("weapon_shield_r1")
	check(player.defense == def0 + int(sh["def"]), "щит: защита %d → %d" % [def0, player.defense])
	check(is_equal_approx(player.block, block0 + float(sh["block"])), "щит: шанс блока %d%%" % roundi(player.block * 100.0))
	if player._model._asset != null:
		check(player._model.find_child("Shield", true, false) != null, "щит в модели")
	# Блок срабатывает: удары зверя иногда приходятся в щит (уклонение выключено)
	mob = find_mob("pheasant")
	var blocked := 0
	player.eva = 0.0
	player.shade_eva = 0.0
	for i in 200:
		player.hp = player.max_hp
		player.take_damage(10, mob)
		if player.hp == player.max_hp:
			blocked += 1
	player.hp = player.max_hp
	player.recalc_stats()
	check(blocked >= 5 and blocked <= 50, "блок щитом: %d ударов из 200 (шанс %d%%)" % [blocked, roundi(player.block * 100.0)])
	check(player.equip("weapon_sword_2h_r1") == "" and not player.has_shield and is_equal_approx(player.block, block0),
		"двуручный меч снял щит, блока нет")
	# Окно сумки: карточка щита — защита и блок
	check(ItemData.weapon_stats_text("weapon_shield_r1").contains("блок"), "строка щита: %s" % ItemData.weapon_stats_text("weapon_shield_r1"))


# ---------- Профессии ----------

func _check_jobs(player: Player) -> void:
	for j in STARTER:
		var job := String(j)
		become_job(job)
		var st: Array = STARTER[job]
		check(game.weapon == String(st[0]) and game.offhand == String(st[1]), "%s: в руках %s, во второй руке «%s»"
			% [ClassData.job_name(job), ItemData.item_name(game.weapon), ItemData.item_name(game.offhand) if game.offhand != "" else "—"])
		for id in ItemData.starter_weapons(job):
			check(game.inventory.has(String(id)), "%s: в сумке %s" % [job, ItemData.item_name(String(id))])
		if job == ClassData.WANDERER:
			continue
		for id in R1:
			var sid := String(id)
			if not game.inventory.has(sid):
				game.inventory.add(sid)
			var allowed: bool = (EXPECT[job] as Array).has(ItemData.weapon_kind(sid))
			if ItemData.is_shield(sid):
				# Щит — к одноручному оружию профессии
				var one := ""
				for k in ["weapon_sword_1h_r1", "weapon_dagger_r1", "weapon_staff_1h_r1", "weapon_mace_1h_r1"]:
					if one == "" and ItemData.weapon_fits(String(k), job):
						one = String(k)
				if one != "":
					player.equip(one)
				check((player.equip(sid) == "") == allowed, "%s: щит %s" % [ClassData.job_name(job), "можно" if allowed else "нельзя"])
				continue
			var err := player.equip(sid)
			check((err == "") == allowed, "%s: %s — %s%s" % [ClassData.job_name(job), ItemData.weapon_kind_name(ItemData.weapon_kind(sid)),
				"можно" if allowed else "нельзя", "" if err == "" else " («%s»)" % err])


func _check_assassin(player: Player) -> void:
	become_job("assassin")
	var rec: Dictionary = game.hero
	learn_skills(["blade_mastery", "charge_stab", "crossbow_mastery", "dual_shot"])
	check(player.assign_slot("charge_stab", 2) and player.assign_slot("dual_shot", 3), "умения на кнопках 3 и 4")
	game.inventory.add("weapon_sword_1h_r1", 2)
	var grips := [["weapon_dagger_r1", false, "dagger"], ["weapon_dagger_r1", true, "daggers"],
		["weapon_sword_1h_r1", false, "sword_1h"], ["weapon_sword_1h_r1", true, "dual_swords"]]
	for g in grips:
		var e: Array = g
		var id := String(e[0])
		check(player.equip(id) == "", "Наёмник: %s" % ItemData.item_name(id))
		if bool(e[1]):
			check(player.equip(id, true) == "", "второй во вторую руку")
		else:
			game.unequip_offhand()
			player.refresh_skills()
		check(player.weapon_kind == String(e[2]), "хват: %s" % ItemData.weapon_kind_name(String(e[2])))
		check(player.slot_block("skill3") == "" and player.slot_block("skill4") == "Нужен арбалет",
			"%s: клинковое умение доступно, арбалетное — нет" % String(e[2]))
		check(HeroSkills.bonuses(rec, "assassin", player.weapon_kind).has("atk_pct"), "%s: «Школа клинка» действует" % String(e[2]))
		mob = find_mob("pheasant")
		stand_near(mob)
		player.select_target(mob)
		player.mp = player.max_mp
		player.skill_cd.clear()
		var hp0 := mob.hp
		check(player.use_skill("skill3"), "%s: «Пронзающий выпад» применён" % String(e[2]))
		check(not mob_ok(mob) or mob.hp < hp0, "%s: урон нанесён" % String(e[2]))
	check(player.equip("crossbow_starter") == "" and game.offhand == "", "арбалет: вторая рука свободна")
	check(player.slot_block("skill3") == "Нужны клинки" and player.slot_block("skill4") == "", "с арбалетом — наоборот")
	mob = find_mob("pheasant")
	stand_near(mob, 6.0)
	player.select_target(mob)
	player.mp = player.max_mp
	player.skill_cd.clear()
	check(player.use_skill("skill4"), "«Сдвоенный болт» с арбалетом")


## Умения щита (Мечник), лука и двух топоров (Воин), посоха (Волшебник).
func _check_job_skills(player: Player) -> void:
	become_job("swordsman")
	check(HeroSkills.weapon_ok("shield_wall", game.weapon_kind(), game.has_shield()), "Мечник: «Стена щита» со щитом")
	check(not HeroSkills.weapon_ok("shield_wall", "sword_1h", false), "без щита — нет")
	check(HeroSkills.weapon_ok("ringing_blow", "mace_2h") and not HeroSkills.weapon_ok("ringing_blow", "sword_1h"),
		"«Гулкий удар» — булавой (и двуручной)")
	check(HeroSkills.weapon_ok("twin_blades_drill", "dual_swords") and not HeroSkills.weapon_ok("twin_blades_drill", "sword_1h"),
		"«Два светлых клинка» — с двумя мечами")
	become_job("warrior")
	check(player.equip("weapon_bow_r1") == "" and HeroSkills.weapon_ok("bow_mastery", player.weapon_kind), "Воин: лук и «Школа лука»")
	check(HeroSkills.weapon_block("bow_mastery", "axe_2h") == "Нужен лук", "без лука — «Нужен лук»")
	check(HeroSkills.weapon_ok("dual_axes", "dual_axes") and HeroSkills.weapon_block("dual_axes", "axe_1h") == "Нужны два топора",
		"«Два топора» — только с двумя")
	become_job("wizard")
	check(HeroSkills.weapon_ok("faith_staff", "staff_1h") and HeroSkills.weapon_ok("ringing_blow", "staff_2h"),
		"Волшебник: умения посоха")


# ---------- Сохранения ----------

func _check_old_saves(player: Player) -> void:
	# Сохранение версии 2 с прежними парами: надетые парные мечи → два учебных меча в обеих руках
	game.from_dict({"version": 2, "name": "Пара", "race": "dark_elf", "class": "assassin", "level": 12, "job_changed": true,
		"inventory": {"dual_swords_starter": 1, "daggers_steel": 1, "crossbow_starter": 1, "hp_potion": 2},
		"weapon": "dual_swords_starter", "shield": ""})
	player.apply_class()
	check(game.weapon == "weapon_sword_1h_r1" and game.offhand == "weapon_sword_1h_r1" and player.weapon_kind == "dual_swords",
		"старые парные мечи — два меча в руках")
	check(game.inventory.count("weapon_sword_1h_r1") == 2 and game.inventory.count("dagger_steel") == 2
		and game.inventory.count("crossbow_starter") == 1, "прежние пары в сумке — по два клинка")
	check(not game.inventory.has("dual_swords_starter") and not game.inventory.has("daggers_steel"), "прежних предметов нет")
	# Надетые стальные кинжалы
	game.from_dict({"version": 2, "name": "Пара", "race": "dark_elf", "class": "assassin", "level": 12, "job_changed": true,
		"inventory": {"daggers_steel": 1}, "weapon": "daggers_steel"})
	player.apply_class()
	check(game.weapon == "dagger_steel" and game.offhand == "dagger_steel" and player.weapon_kind == "daggers",
		"старые стальные кинжалы — по кинжалу в каждой руке")
	# Мечник со щитом прежней версии: поле "shield" читается
	game.from_dict({"version": 2, "name": "Щит", "race": "light_elf", "class": "swordsman", "level": 12, "job_changed": true,
		"inventory": {"weapon_sword_1h_r1": 1, "weapon_shield_r1": 1}, "weapon": "weapon_sword_1h_r1", "shield": "weapon_shield_r1"})
	player.apply_class()
	check(game.shield == "weapon_shield_r1" and player.has_shield, "старое поле «shield» — щит во второй руке")
	# Волшебник прежней версии с булавой и щитом: теперь только посохи
	game.from_dict({"version": 2, "name": "Маг", "race": "light_elf", "class": "wizard", "level": 12, "job_changed": true,
		"inventory": {"weapon_mace_1h_r1": 1, "weapon_shield_r1": 1}, "weapon": "weapon_mace_1h_r1", "shield": "weapon_shield_r1"})
	player.apply_class()
	check(ItemData.weapon_kind(game.weapon).begins_with("staff") and game.offhand == "", "Волшебник: булава и щит сняты, в руках посох")
	# Сохранение и загрузка второй руки
	game.from_dict({"version": 2, "name": "Пара", "race": "human", "class": "warrior", "level": 12, "job_changed": true,
		"inventory": {"weapon_axe_1h_r1": 2}, "weapon": "weapon_axe_1h_r1", "offhand": "weapon_axe_1h_r1"})
	player.apply_class()
	check(player.weapon_kind == "dual_axes", "Воин: два топора из сохранения")
	check(game.save_game() and game.load_game(), "сохранено и загружено")
	player.apply_class()
	check(game.offhand == "weapon_axe_1h_r1" and player.weapon_kind == "dual_axes", "вторая рука сохраняется")


## Весь текст открытого окна.
func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w == null:
		return t
	for n in w.find_children("*", "Label", true, false):
		t += (n as Label).text + "\n"
	for n in w.find_children("*", "Button", true, false):
		t += (n as Button).text + "\n"
	return t
