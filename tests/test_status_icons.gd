extends "res://tests/test_base.gd"
## Значки на кнопках HUD и значки эффектов у полосок HP (реестр StatusEffects, ряды StatusRow, IconView):
## кнопки умений — значок назначенного умения, обновляется при переназначении; «Зелье» — значок зелья с числом;
## «Атака» — надетое оружие; «Приручить» — карта существа; «Говорить» — рисунок; перезарядка — сектор.
## Баф героя («Танец теней») и баф от питомца («Зов охотницы») — значки у панели игрока, доля оставшегося
## времени убывает; «Узы тени» питомца — значок без таймера у питомца и у хозяина; дебаф на звере
## (замедление, урон со временем) — значок у панели цели, кончился — пропал; переключаемое героя — значок
## без таймера, выключили — пропал; касание значка — подпись; много эффектов — «+N».

var mob: Mob = null
var shade_frac := 0.0
var slow_frac := 0.0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	var i: int = game.add_pet("panther", PetData.stage_name("panther", 20), 20)
	var rec: Dictionary = game.pets[i]
	PetSkills.ensure_record(rec)
	(rec["skills"] as Dictionary)["shadow_bond"] = 1
	(rec["toggles"] as Dictionary)["shadow_bond"] = true
	game.active_pet = i


func run_step() -> void:
	var player: Player = main.player
	var hud: HUD = main.hud
	match step:
		0:
			wait = 5
			step = 10
		10:
			# Питомец только следует за героем (не бьёт фазана); фазан рядом и цель — чтобы успел «проснуться»
			# (вдали звери не обновляются)
			main.pets.handle_action("pet_follow")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			if mob == null:
				return
			stand_near(mob, 2.0)
			player._set_target(mob)
			wait = 45
			step = 1
		1:
			_check_buttons(player, hud)
			var pet: Pet = main.pets.active_pet
			check(pet != null, "пантера призвана")
			if pet == null:
				return
			check(pet.mode == "follow", "питомец — «За мной»")
			# Баф героя: «Танец теней» (20 с)
			var rec: Dictionary = game.hero
			(rec["skills"] as Dictionary)["deep_evasion"] = 1
			check(player.assign_slot("deep_evasion", 0), "«Танец теней» — на кнопку 1")
			player.mp = player.max_mp
			check(use_now(player, "skill1"), "«Танец теней» применён")
			check(player.effects.has("shade"), "в реестре героя — «shade»")
			# Баф от питомца: «Зов охотницы» — атака хозяина выше на 15 с
			pet._apply_buff(PetSkills.get_skill("hunter_call"), 1, "hunter_call")
			var atk_e := player.effects.get_entry("atk")
			check(not atk_e.is_empty() and String(atk_e["src"]) == "Зов охотницы" and not bool(atk_e["debuff"]),
				"баф от питомца в реестре героя: %s" % StatusEffects.describe(atk_e))
			# Переключаемое героя
			(rec["skills"] as Dictionary)["concentration"] = 1
			check(player.set_toggle("concentration", true) == "", "«Холодный расчёт» включён")
			# Дебаф на звере
			check(mob_ok(mob), "фазан жив")
			if not mob_ok(mob):
				return
			stand_near(mob, 2.0)
			player._set_target(mob)
			mob.slow(0.3, 3.0, StatusEffects.source_pet_skill("panther", "dusk_rupture"))
			mob.add_dot("piercing_arrow", 1.0, 30.0, player, false, StatusEffects.source_hero_skill("piercing_arrow"))
			wait = 3
			step = 2
		2:
			var row := hud.status_row("player")
			var shade := _shown(row, "shade")
			check(not shade.is_empty() and not bool(shade["toggle"]), "значок «Танца теней» у панели игрока")
			shade_frac = StatusEffects.left_frac(shade)
			check(shade_frac > 0.9 and shade_frac < 1.0, "доля оставшегося времени %.3f" % shade_frac)
			var ic := row.icon(_index(row, "shade"))
			check(ic != null and ic.visible and String(ic.spec.get("path", "")) == HeroSkills.icon_path("deep_evasion"),
				"значок эффекта — значок умения «Танец теней»")
			check(ic != null and ic.sector().y < 0.05, "только что наложен — сектора почти нет")
			check(not _shown(row, "atk").is_empty(), "значок «Зова охотницы» у панели игрока")
			var conc := _shown(row, "toggle:concentration")
			check(not conc.is_empty() and bool(conc["toggle"]), "переключаемое героя — значок без таймера")
			var ci := row.icon(_index(row, "toggle:concentration"))
			check(ci != null and ci.sector() == Vector2.ZERO, "у переключаемого нет сектора")
			check(not _shown(row, "pet:shadow_bond").is_empty(), "«Узы тени» питомца — значок и у хозяина")
			var prow := hud.status_row("pet")
			check(prow.is_visible_in_tree() and not _shown(prow, "toggle:shadow_bond").is_empty(),
				"«Узы тени» — значок у панели питомца")
			var trow := hud.status_row("target")
			var sl := _shown(trow, "slow")
			check(trow.is_visible_in_tree() and not sl.is_empty() and bool(sl["debuff"]), "замедление — дебаф у панели цели")
			var si := trow.icon(_index(trow, "slow"))
			check(si != null and String(si.spec.get("path", "")) == CreatureWindow.icon_path("panther", "dusk_rupture"),
				"значок замедления — умение пантеры")
			check(not _shown(trow, "dot:piercing_arrow").is_empty(), "урон со временем — значок у цели")
			slow_frac = StatusEffects.left_frac(sl)
			# Касание значка — подпись
			touch(true, 3, si.get_global_rect().get_center())
			touch(false, 3, si.get_global_rect().get_center())
			check(hud._fx_tip.visible and hud._fx_tip.text.contains("Замедление") and hud._fx_tip.text.contains("Сумрачный разрыв"),
				"подпись по касанию: %s" % hud._fx_tip.text)
			# Перезарядка «Танца теней» на кнопке — сектор
			var b1 := hud.button_icon("skill1")
			check(b1 != null and b1.sector().y == 1.0 and b1.sector().x < 0.05, "перезарядка — сектор на кнопке: %s"
				% (b1.sector() if b1 != null else Vector2.ZERO))
			wait = 60
			step = 3
		3:
			player.hp = player.max_hp
			var row := hud.status_row("player")
			var shade := _shown(row, "shade")
			check(not shade.is_empty() and StatusEffects.left_frac(shade) < shade_frac - 0.03,
				"доля «Танца теней» убывает: %.3f → %.3f" % [shade_frac, StatusEffects.left_frac(shade) if not shade.is_empty() else 0.0])
			var ic := row.icon(_index(row, "shade"))
			check(ic != null and ic.sector().x == 0.0 and ic.sector().y > 0.04,
				"истёкшая доля — тёмный сектор от 12 часов: %s" % (ic.sector() if ic != null else Vector2.ZERO))
			var trow := hud.status_row("target")
			var sl := _shown(trow, "slow")
			check(not sl.is_empty() and StatusEffects.left_frac(sl) < slow_frac - 0.2, "доля замедления убывает")
			var si := trow.icon(_index(trow, "slow"))
			check(si != null and si.sector().y > 0.25, "сектор замедления растёт: %.2f" % (si.sector().y if si != null else 0.0))
			check(player.set_toggle("concentration", false) == "", "«Холодный расчёт» выключен")
			wait = 130
			step = 4
		4:
			player.hp = player.max_hp
			var row := hud.status_row("player")
			check(_shown(row, "toggle:concentration").is_empty() and not player.effects.has("toggle:concentration"),
				"выключенное переключаемое — значка нет")
			var trow := hud.status_row("target")
			check(mob_ok(mob), "фазан жив")
			check(mob.slow_time == 0.0 and not mob.effects.has("slow") and _shown(trow, "slow").is_empty(),
				"замедление кончилось — значок пропал")
			check(not _shown(trow, "dot:piercing_arrow").is_empty(), "урон со временем ещё идёт")
			# Много эффектов — «+N»
			mob.stun(20.0)
			mob.blind(20.0)
			mob.weaken_aim(0.3, 20.0)
			mob.expose(0.1, 20.0)
			mob.weaken(0.1, 20.0)
			mob.effects.add("x1", 20.0, StatusEffects.effect_info("weak"))
			mob.effects.add("x2", 20.0, StatusEffects.effect_info("weak"))
			mob.effects.add("x3", 20.0, StatusEffects.effect_info("weak"))
			wait = 2
			step = 5
		5:
			var trow := hud.status_row("target")
			check(trow.shown().size() <= trow.capacity() and trow.hidden_count() > 0 and trow._more != null and trow._more.visible,
				"не помещаются — «+%d» (видно %d из %d)" % [trow.hidden_count(), trow.shown().size(), mob.effects.entries().size()])
			# Снятие ауры питомца — «Уз» у хозяина нет; смерть зверя — значков цели нет
			player.clear_pet_aura(main.pets.active_pet)
			check(not player.effects.has("pet:shadow_bond"), "аура питомца снята — значка «Уз» у хозяина нет")
			mob.take_damage(mob.hp + 5, player)
			check(mob.effects.is_empty(), "погибший зверь — реестр пуст")
			player.clear_buffs()
			check(not player.effects.has("shade") and not player.effects.has("atk"), "сброс усилений убирает значки")
			ok_done()


func _check_buttons(player: Player, hud: HUD) -> void:
	for bid in ["skill1", "skill2"]:
		var sid := player.skill_id(String(bid))
		var ic := hud.button_icon(String(bid))
		check(sid != "" and ic != null and String(ic.spec.get("path", "")) == HeroSkills.icon_path(sid),
			"кнопка %s — значок умения %s" % [bid, sid])
		check(not (hud._buttons[bid]["label"] as Label).visible, "у кнопки %s нет текста, только значок" % bid)
	# Переназначение: «Шаг тени» на кнопку 1 — значок меняется
	var s2 := player.skill_id("skill2")
	check(player.assign_slot(s2, 0), "умение кнопки 2 — на кнопку 1")
	var ic1 := hud.button_icon("skill1")
	check(ic1 != null and String(ic1.spec.get("path", "")) == HeroSkills.icon_path(s2), "значок кнопки 1 обновился")
	check(not hud.is_button_visible("skill2"), "кнопка 2 опустела и скрыта")
	var pot := hud.button_icon("potion")
	check(pot != null and String(pot.spec.get("item", "")) == "potion_hp_r1" and Economy.best_potion("hp") == "potion_hp_r1" and pot.count() == Economy.potion_count("hp"),
		"«Зелье» — значок зелья и число %d" % (pot.count() if pot != null else -1))
	var atk := hud.button_icon("attack")
	check(atk != null and String(atk.spec.get("item", "")) == game.weapon and game.weapon != "",
		"«Атака» — значок надетого оружия %s" % game.weapon)
	check(player.equip("crossbow_starter") == "", "надет арбалет")
	check(String(hud.button_icon("attack").spec.get("item", "")) == "crossbow_starter", "значок «Атаки» — арбалет")
	check(player.equip("weapon_dagger_r1") == "" and player.equip("weapon_dagger_r1", true) == "", "снова два кинжала")
	var tame := hud.button_icon("tame")
	check(tame != null and (String(tame.spec.get("item", "")).begins_with("card_")
		or String(tame.spec.get("path", "")) == UiIcons.path("btn_tame")), "«Приручить» — карта существа")
	var talk := hud.button_icon("talk")
	check(talk != null and String(talk.spec.get("shape", "")) == "talk" and hud.button_text("talk") == "Говорить",
		"«Говорить» — рисунок, подпись в button_text")


## Запись эффекта id среди видимых значков ряда (пусто — нет).
func _shown(row: StatusRow, id: String) -> Dictionary:
	for e in row.shown():
		if String(e["id"]) == id:
			return e
	return {}


func _index(row: StatusRow, id: String) -> int:
	var list := row.shown()
	for i in list.size():
		if String(list[i]["id"]) == id:
			return i
	return -1
