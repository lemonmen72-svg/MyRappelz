extends "res://tests/test_base.gd"
## Зелья по рангам (ItemData.POTION_KINDS): 5 видов × 15 рангов, названия, цены, значки по размеру колбы, требование
## уровня (ранг выше уровня героя не выпить), здоровье и мана (доля + число по рангу, перезарядка), ускорения
## атаки, каста и бега (усиление на время со значком у полоски HP, повтор заменяет и продлевает, по времени
## снимается), кнопка «Зелье» — старший ранг по уровню. Ранги снаряжения: оружие 2-го ранга — с 21 ур.
## Перевод старых сохранений (hp_potion → potion_hp_r1).


func race_class() -> Array:
	return ["dark_elf", "wanderer"]


func run_step() -> void:
	var p: Player = main.player
	var eco: Economy = main.economy
	match step:
		0:
			_unit_data()
			_unit_ranks()
			# Требование уровня: 1 ур. — ранг 2 не выпить, ранг 1 — можно
			game.inventory.add("potion_hp_r2", 2)
			p.hp = 10
			check(not eco.drink("potion_hp_r2") and game.inventory.count("potion_hp_r2") == 2 and p.hp == 10,
				"зелье 2-го ранга на 1 ур. не выпить")
			check(main.hud._msg_label.text.contains("Нужен 11 уровень"), "сообщение: " + main.hud._msg_label.text)
			check(Economy.best_potion("hp") == "potion_hp_r1" and Economy.potion_count("hp") == 3,
				"«Зелье» берёт 1-й ранг (3 шт.), 2-й не по уровню")
			var hp0 := p.hp
			check(eco.drink("potion_hp_r1"), "зелье 1-го ранга выпито")
			check(p.hp == mini(p.max_hp, hp0 + ItemData.potion_restore("potion_hp_r1", p.max_hp)),
				"здоровье +%d (25%% от %d + %d)" % [ItemData.potion_restore("potion_hp_r1", p.max_hp), p.max_hp,
				ItemData.potion_flat("hp", 1)])
			p.hp = 10
			check(not eco.drink("potion_hp_r1") and p.hp == 10, "перезарядка зелья здоровья")
			# Мана — своя перезарядка, не общая со здоровьем
			game.inventory.add("potion_mp_r1", 3)
			check(p.max_mp > 0, "у героя есть MP: %d" % p.max_mp)
			p.mp = 0
			check(eco.drink("potion_mp_r1") and p.mp == mini(p.max_mp, ItemData.potion_restore("potion_mp_r1", p.max_mp)),
				"мана +%d" % ItemData.potion_restore("potion_mp_r1", p.max_mp))
			check(not eco.drink("potion_mp_r1") and eco.mana_cooldown_frac() > 0.5, "перезарядка зелья маны")
			p.mp = p.max_mp
			# Ускорения
			_check_buffs_lvl1()
			step = 1
		1:
			# 12 ур.: 2-й ранг можно; кнопка «Зелье» — старший ранг
			game.level = 12
			p.recalc_stats()
			check(Economy.best_potion("hp") == "potion_hp_r2" and Economy.potion_count("hp") == 4, "12 ур.: «Зелье» — 2-й ранг, всего 4")
			eco._update_potion_button()
			var ic: IconView = main.hud.button_icon("potion")
			check(ic != null and String(ic.spec.get("item", "")) == "potion_hp_r2" and ic.count() == 4, "значок «Зелья» — 2-й ранг, число 4")
			eco._potion_cd = 0.0
			p.hp = 10
			var n2: int = game.inventory.count("potion_hp_r2")
			main._on_action("potion")
			check(game.inventory.count("potion_hp_r2") == n2 - 1 and p.hp == mini(p.max_hp, 10 + ItemData.potion_restore("potion_hp_r2", p.max_hp)),
				"кнопка «Зелье» выпила 2-й ранг")
			# Ускорение 2-го ранга заменяет 1-й: прибавка больше, отсчёт заново, значок — новое зелье
			game.inventory.add("potion_aspd_r2", 1)
			var before := p.aspd
			var had := float(p.timed_bonus["potion_aspd"]["bonus"]["aspd"]) if p.timed_bonus.has("potion_aspd") else 0.0
			check(eco.drink("potion_aspd_r2"), "выпито зелье скорости атаки II")
			var tb: Dictionary = p.timed_bonus["potion_aspd"]
			check(is_equal_approx(float(tb["bonus"]["aspd"]), 0.11) and is_equal_approx(float(tb["left"]), ItemData.POTION_BUFF_TIME),
				"повтор заменил прибавку (+11%%) и продлил до %d с" % int(ItemData.POTION_BUFF_TIME))
			check(is_equal_approx(p.aspd, before - had + 0.11), "скорость атаки: %.2f → %.2f" % [before, p.aspd])
			var e := p.effects.get_entry("buff:potion_aspd")
			check(not e.is_empty() and String((e["icon"] as Dictionary).get("item", "")) == "potion_aspd_r2"
				and is_equal_approx(float(e["dur"]), ItemData.POTION_BUFF_TIME), "значок — зелье II, отсчёт заново")
			# По времени усиление снимается
			for id in ["potion_aspd", "potion_cast", "potion_speed"]:
				if p.timed_bonus.has(id):
					p.timed_bonus[id]["left"] = 0.05
			wait = 10
			step = 2
		2:
			for id in ["potion_aspd", "potion_cast", "potion_speed"]:
				check(not p.timed_bonus.has(id) and not p.effects.has("buff:" + id), "усиление %s снято по времени" % id)
			p.recalc_stats()
			check(is_equal_approx(p.cast_speed, _base_cast()), "скорость каста вернулась: %.2f" % p.cast_speed)
			_check_weapon_rank()
			_check_migration()
			ok_done()


# ---------- Данные ----------

func _unit_data() -> void:
	check(ItemData.POTION_KINDS.size() == 5, "5 видов зелий: здоровье, мана, скорость атаки, каста, бега")
	for k in ItemData.POTION_KINDS:
		var kind := String(k)
		var prev_buy := 0
		var prev_flat := -1
		for r in range(1, ItemData.POTION_RANKS + 1):
			var id := ItemData.potion_id(kind, r)
			var it := ItemData.get_item(id)
			check(not it.is_empty() and ItemData.is_potion(id) and ItemData.potion_kind(id) == kind and ItemData.rank(id) == r,
				"%s: зелье есть, ранг %d" % [id, r])
			check(ItemData.item_name(id).ends_with(" " + ItemData.roman(r)), "название с рангом: %s" % ItemData.item_name(id))
			check(ItemData.item_type(id) == "consumable" and ItemData.stack_size(id) == ItemData.STACK, "%s: расходник стопкой" % id)
			check(ItemData.required_level(id) == (r - 1) * 10 + 1, "%s: пить с %d ур." % [id, ItemData.required_level(id)])
			check(int(it["buy"]) > prev_buy and int(it["sell"]) > 0 and int(it["sell"]) < int(it["buy"]), "%s: цена растёт с рангом" % id)
			prev_buy = int(it["buy"])
			var tier := 1 if r <= 5 else (2 if r <= 10 else 3)
			check(ItemData.icon_path(id) == "res://assets/icons/items/potion_%s_t%d.png" % [kind, tier], "%s: значок %s" % [id, ItemData.icon_path(id)])
			if kind == "hp" or kind == "mp":
				check(ItemData.potion_flat(kind, r) > prev_flat, "%s: восстанавливает больше с рангом" % id)
				prev_flat = ItemData.potion_flat(kind, r)
			else:
				check(is_equal_approx(ItemData.potion_buff(r), 0.10 + 0.01 * float(r - 1)), "%s: +%d%%" % [id, roundi(ItemData.potion_buff(r) * 100.0)])
			var icon := ItemIcon.make(id, 64.0)
			check(icon.item_id == id, "значок %s создаётся" % id)
			icon.free()
		check(ItemData.item_name("potion_" + kind) == String(ItemData.POTION_KINDS[kind]["name"]), "семья зелий %s — название вида" % kind)
	# Числа: на нижнем уровне ранга ≈ половина HP героя, на 1-м ранге — 24 HP и 8 MP сверх 25 %
	check(ItemData.potion_flat("hp", 1) == 24 and ItemData.potion_flat("mp", 1) == 8, "1-й ранг: +24 HP / +8 MP")
	check(ItemData.potion_flat("hp", 2) == 72 and ItemData.potion_flat("hp", 15) == 689, "2-й ранг +72 HP, 15-й +689 HP")
	check(ItemData.migrate_id("hp_potion") == "potion_hp_r1", "старое зелье здоровья — 1-го ранга")
	check(ItemData.get_item("hp_potion").is_empty(), "предмета hp_potion больше нет")
	# Сортировка: здоровье раньше маны, старший ранг раньше
	check(ItemData.sort_before("potion_hp_r2", "potion_hp_r1") and ItemData.sort_before("potion_hp_r1", "potion_mp_r9"),
		"сортировка зелий: по виду, старшие ранги раньше")


func _unit_ranks() -> void:
	for e in [[1, 1], [10, 1], [11, 2], [20, 2], [21, 3], [99, 10], [141, 15], [150, 15], [200, 15]]:
		check(ItemData.potion_rank_for_level(int(e[0])) == int(e[1]), "зелье %d ур. — %d-го ранга" % [int(e[0]), int(e[1])])
	for e in [[1, 1], [20, 1], [21, 2], [50, 2], [51, 3], [80, 3], [81, 4], [110, 4], [111, 5], [140, 5], [141, 6], [150, 6]]:
		check(ItemData.equip_rank_for_level(int(e[0])) == int(e[1]), "снаряжение %d ур. — %d-го ранга" % [int(e[0]), int(e[1])])
	check(ItemData.rank_level_range(3, true) == [21, 30] and ItemData.rank_level_range(15, true) == [141, 150], "ранги зелий по 10 ур.")
	check(ItemData.rank_level_range(2) == [21, 50], "2-й ранг снаряжения — 21–50 ур.")
	# Торговец: зелья 1-го и 2-го рангов всех видов; оружие (только 1-го ранга) — у оружейника
	var goods := InventoryWindow.goods("wanderer", "merchant")
	for k in ItemData.POTION_KINDS:
		for r in range(1, ItemData.POTION_RANKS + 1):
			var id := ItemData.potion_id(String(k), r)
			check(goods.has(id) == (r <= 2), "у торговца %s: %s" % [id, "есть" if r <= 2 else "нет"])
	for g in goods:
		check(not ItemData.is_weapon(String(g)), "оружия у торговца нет (оно у оружейника): %s" % g)
	for g in InventoryWindow.goods("wanderer", "weaponsmith"):
		check(ItemData.rank(String(g)) == 1, "оружие у оружейника — 1-го ранга: %s" % g)


# ---------- Ускорения ----------

func _check_buffs_lvl1() -> void:
	var p: Player = main.player
	var eco: Economy = main.economy
	for k in ["aspd", "cast", "speed"]:
		game.inventory.add(ItemData.potion_id(String(k), 1), 2)
	var aspd0 := p.aspd
	var cast0 := p.cast_speed
	var speed0 := p.cur_speed()
	check(eco.drink("potion_aspd_r1"), "выпито зелье скорости атаки I")
	check(is_equal_approx(p.aspd, aspd0 + 0.10), "скорость атаки +10%%: %.2f → %.2f" % [aspd0, p.aspd])
	check(eco.drink("potion_cast_r1"), "выпито зелье скорости каста I")
	check(is_equal_approx(p.cast_speed, cast0 + 0.10), "скорость каста +10%%: %.2f → %.2f" % [cast0, p.cast_speed])
	check(eco.drink("potion_speed_r1"), "выпито зелье скорости бега I")
	check(absf(p.cur_speed() - speed0 * 1.10) < 0.01, "скорость бега +10%%: %.2f → %.2f" % [speed0, p.cur_speed()])
	for k in ["aspd", "cast", "speed"]:
		var sid := "potion_" + String(k)
		var e := p.effects.get_entry("buff:" + sid)
		check(p.timed_bonus.has(sid) and not e.is_empty(), "усиление %s и значок у полоски HP" % sid)
		if e.is_empty():
			continue
		check(not bool(e["debuff"]) and is_equal_approx(float(e["dur"]), ItemData.POTION_BUFF_TIME), "%s: баф на %d с" % [sid, int(ItemData.POTION_BUFF_TIME)])
		check(String((e["icon"] as Dictionary).get("item", "")) == ItemData.potion_id(String(k), 1), "%s: значок — само зелье" % sid)
		check(String(e["src"]) == ItemData.item_name(ItemData.potion_id(String(k), 1)), "%s: подпись — название зелья" % sid)
	# Значки видны в ряду эффектов героя (HUD)
	var row: StatusRow = main.hud.status_row("player")
	check(row != null, "ряд эффектов героя")
	# Ускорения не ломают кнопку «Зелье»: она по-прежнему про здоровье
	check(Economy.best_potion("hp") == "potion_hp_r1", "«Зелье» — здоровье")


## Скорость каста героя без зелий (оружие и умения).
func _base_cast() -> float:
	return float(ItemData.grip_bonus(game.weapon, game.offhand)["cast"]) / 100.0 + Player._bv(main.player.skill_bonus, "cast")


# ---------- Оружие по рангу ----------

func _check_weapon_rank() -> void:
	var p: Player = main.player
	game.inventory.add("weapon_sword_1h_r2", 1)
	game.level = 20
	var err := p.equip("weapon_sword_1h_r2")
	check(err.contains("Нужен 21 уровень") and game.weapon != "weapon_sword_1h_r2", "оружие 2-го ранга на 20 ур. не надеть: " + err)
	var it := ItemData.get_item("weapon_sword_1h_r2")
	var r1 := ItemData.get_item("weapon_sword_1h_r1")
	check(int(it["atk"]) > int(r1["atk"]) * 3, "меч 2-го ранга сильнее 1-го: %d против %d" % [int(it["atk"]), int(r1["atk"])])
	check(Handheld.model_for("weapon_sword_1h_r2") != "", "модель меча 2-го ранга (или откат на модель вида)")
	game.level = 21
	check(p.equip("weapon_sword_1h_r2") == "" and game.weapon == "weapon_sword_1h_r2", "на 21 ур. надет")
	var ic := ItemIcon.make("weapon_sword_1h_r2", 64.0)
	check(ic.item_id == "weapon_sword_1h_r2", "значок оружия 2-го ранга создаётся")
	ic.free()
	# Все виды оружия 1-го ранга получили пару 2-го ранга
	for k in ItemData.WEAPON_KINDS:
		var kind := String(k)
		if ItemData.single_kind(kind) != kind:
			continue
		var found := false
		for id in ItemData.ITEMS:
			if ItemData.weapon_kind(String(id)) == kind and ItemData.rank(String(id)) == 2:
				found = true
		check(found, "вид «%s»: есть оружие 2-го ранга" % ItemData.weapon_kind_name(kind))


# ---------- Старые сохранения ----------

func _check_migration() -> void:
	game.from_dict({"version": 2, "name": "Старая", "race": "dark_elf", "class": "wanderer", "level": 4,
		"inventory": {"hp_potion": 5}, "bag": [{"id": "hp_potion", "n": 5}],
		"storage": {"items": {"hp_potion": 2}, "cells": [{"id": "hp_potion", "n": 2}]}})
	check(game.inventory.count("potion_hp_r1") == 5 and not game.inventory.has("hp_potion"), "сумка: hp_potion → potion_hp_r1")
	check(game.inventory.find_cell("potion_hp_r1") >= 0 and game.inventory.find_cell("hp_potion") < 0, "раскладка сумки переведена")
	check(game.storage.count("potion_hp_r1") == 2, "склад: hp_potion → potion_hp_r1")
