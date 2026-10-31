extends "res://tests/test_base.gd"
## Умения «питомцевых» профессий (этап 2): Зверолов, Адепт, Колдун. Каждое своё умение их древ готово (is_ready —
## общие с Мечником, Волшебником, Неофитом, Воином и Шаманом проверяют их тесты); активные применяются (MP,
## перезарядка, эффект); ауры и пассивки меняют показатели призванного питомца (значки у панели питомца в HUD);
## опыт питомца, «Нить жизни», воскрешение умением, «Общая боль»; жертвы Адепта — HP питомца ↓ (не ниже четверти),
## урон и лечение ↑, «Кровь бездны» и «Небесный обмен» — питомец погибает; созвучия, «Гнев стаи», «Гнев духов»;
## «Слияние душ» (питомец внутри героя, статы героя ↑, возврат) и «Звериный облик» (модель питомца вместо героя);
## оценка баланса: герой + питомец своего уровня против зверя своего уровня (HP ×3) и без питомца.

const JOBS := ["beastmaster", "adept", "conjurer"]
## Профессии других помощников: их общие умения проверяют их тесты.
const OTHERS := ["swordsman", "wizard", "neophyte", "warrior", "shaman"]
## Уровни для оценки баланса.
const BAL_LEVELS := [15, 25, 35]

var mob: Mob = null
var arena := Vector3.ZERO
var t0 := 0
var pet_hp0 := 0
var mob_hp0 := 0
var hero_hp0 := 0
var mp_cost := 0


func race_class() -> Array:
	return ["light_elf", "beastmaster"]


func hero_level() -> int:
	return 40


func before_start() -> void:
	# Звери вокруг сильные и много: герой под «бессмертием» (снимается на время проверки «Общей боли»)
	AdminPanel.god = true
	game.add_pet("wolf", PetData.stage_name("wolf", 30), 30)
	game.add_pet("panther", PetData.stage_name("panther", 30), 30)
	game.active_pet = 0


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			if pet() == null:
				return
			_setup_arena()
			wait = 10
			step = 1
		1:
			_check_ready()
			_bm_passives()
			step = 2
		2:
			_bm_auras()
			# «Целебная роса»: лечение сразу и понемногу
			var pt := pet()
			pt.hp = pt.max_hp / 3
			pt.bond_hp_changed()
			pet_hp0 = pt.hp
			_cast("healing_dew")
			check(pt.hp > pet_hp0, "«Целебная роса» лечит питомца сразу: %d → %d" % [pet_hp0, pt.hp])
			check(pt.effects.has("hot:healing_dew"), "значок лечения со временем у питомца")
			pet_hp0 = pt.hp
			wait = 70
			step = 3
		3:
			var pt3 := pet()
			check(pt3.hp > pet_hp0, "«Целебная роса» лечит ещё 12 с: %d → %d" % [pet_hp0, pt3.hp])
			check(not _shown(main.hud.status_row("pet"), "hero:radiant_claws").is_empty(),
				"значок ауры «Светлые когти» — у панели питомца в HUD")
			check(not _shown(main.hud.status_row("pet"), "hot:healing_dew").is_empty(), "значок «Целебной росы» в HUD")
			_bm_life()
			step = 4
		4:
			if pet() == null:
				return
			_adept_auras()
			_adept_blood_rain()
			wait = 45
			step = 5
		5:
			check(not mob_ok(mob) or mob.hp < mob_hp0, "«Кровавый ливень»: все удары прошли, зверь %d → %d" % [mob_hp0,
				mob.hp if mob_ok(mob) else 0])
			_adept_sacrifices()
			step = 6
		6:
			if pet() == null:
				return
			_conj_chords()
			_conj_actives()
			wait = 80
			step = 7
		7:
			check(not mob_ok(mob) or mob.hp < mob_hp0, "«Гнев духов»: сила духов жжёт зверя у питомца %d → %d" % [mob_hp0,
				mob.hp if mob_ok(mob) else 0])
			var pt7 := pet()
			check(pt7.effects.has("hero_buff:spirit_wrath"), "значок «Гнева духов» у питомца")
			_merge_on()
			wait = 5
			step = 8
		8:
			_merge_check()
			wait = 5
			step = 9
		9:
			_merge_back()
			_form_on()
			wait = 5
			step = 10
		10:
			_form_check()
			step = 11
		11:
			if pet() == null:
				return
			_balance()
			player.hp = player.max_hp
			ok_done()


func pet() -> Pet:
	var pm: PetManager = main.pets
	if is_instance_valid(pm.active_pet) and not pm.active_pet.is_down:
		return pm.active_pet
	return null


## Тихое место у лугов фазанов: дикие звери вокруг убраны, тестовый зверь — по нужде (ensure_mob).
func _setup_arena() -> void:
	var player: Player = main.player
	var ph := find_mob("pheasant")
	check(ph != null, "найден луг с фазанами")
	var c := ph.global_position
	arena = AdminPanel.free_spot(IslandWorld.current, Vector2(c.x, c.z))
	player.global_position = arena
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and m.global_position.distance_to(arena) < 45.0:
			m.remove_from_group("mobs")
			m.queue_free()
	pet().set_mode("follow")


## Тестовый зверь level ур. в dist м от героя (оглушён: не бьёт и не бегает).
func ensure_mob(type_id: String = "wolf", lvl: int = 30, dist: float = 4.0) -> Mob:
	var player: Player = main.player
	if not mob_ok(mob):
		var pos := player.global_position + Vector3(dist, 0, 0)
		if IslandWorld.current != null:
			pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
		mob = main.spawn_mob(type_id, lvl, pos)
	mob.stun(60.0)
	return mob


## Применить активное умение героя sid (полный MP, перезарядка сброшена): применилось, MP списан, перезарядка, повтор
## — нет. mp_check = false — MP не сверять (умение само возвращает MP).
func _cast(sid: String, mp_check: bool = true) -> void:
	var player: Player = main.player
	var nm := String(HeroSkills.get_skill(sid).get("name", sid))
	check(HeroSkills.is_ready(sid), "«%s» готово (is_ready)" % nm)
	player.mp = player.max_mp
	player.skill_cd.erase(sid)
	var n := HeroSkills.skill_level(game.hero, sid)
	mp_cost = HeroSkills.mp_cost(sid, n)
	var mp0 := player.mp
	check(player.use_skill(sid), "«%s» ур. %d применено" % [nm, n])
	if mp_check:
		check(player.mp == mp0 - mp_cost and mp_cost > 0, "«%s» тратит MP: %d" % [nm, mp_cost])
	check(float(player.skill_cd.get(sid, 0.0)) > 0.0, "«%s» на перезарядке" % nm)
	check(not player.use_skill(sid), "«%s»: повтор — нет (перезарядка)" % nm)


## Включить / выключить переключаемое: включение тратит MP.
func _toggle(sid: String, on: bool) -> void:
	var player: Player = main.player
	var nm := String(HeroSkills.get_skill(sid).get("name", sid))
	player.mp = player.max_mp
	var mp0 := player.mp
	var err := player.set_toggle(sid, on)
	check(err == "", "«%s» %s %s" % [nm, "включено" if on else "выключено", err])
	if on:
		var cost := HeroSkills.mp_cost(sid, HeroSkills.skill_level(game.hero, sid))
		check(cost > 0 and player.mp == mp0 - cost, "«%s»: включение — %d MP" % [nm, cost])
		check(HeroSkills.toggle_on(game.hero, sid), "«%s» включено в записи героя" % nm)


func _learn_job(job: String) -> void:
	become_job(job)
	game.hero["jp"] = 5000
	HeroSkills.learn_all(game.hero, job, game.level)
	main.player.refresh_skills()
	for id in _own_ids(job):
		check(HeroSkills.skill_level(game.hero, String(id)) == HeroSkills.max_level(String(id)),
			"%s: «%s» изучено полностью" % [job, String(HeroSkills.get_skill(String(id)).get("name", id))])


## Умения профессии job, которые есть только у питомцевых профессий (не у других помощников и не у Наёмника).
func _own_ids(job: String) -> Array:
	var res: Array = []
	for id in JobSkills.ids(job):
		var sid := String(id)
		var other := HeroSkills.has_skill("assassin", sid)
		for o in OTHERS:
			if HeroSkills.has_skill(String(o), sid):
				other = true
		if not other:
			res.append(sid)
	return res


func _shown(row: StatusRow, id: String) -> Dictionary:
	for e in row.shown():
		if String(e["id"]) == id:
			return e
	return {}


# ---------- Готовность ----------

func _check_ready() -> void:
	var total := 0
	for job in JOBS:
		for id in _own_ids(String(job)):
			var sid := String(id)
			total += 1
			check(HeroSkills.is_ready(sid), "%s: «%s» готово" % [job, String(HeroSkills.get_skill(sid).get("name", sid))])
			for n in range(1, HeroSkills.max_level(sid) + 1):
				var txt := HeroSkills.effect_text(sid, n)
				check(txt != "" and not txt.contains("следующем обновлении"), "«%s» ур. %d: %s" % [sid, n, txt])
	check(total >= 40, "своих умений у трёх профессий: %d" % total)
	# Файлы механик подключены к движку (HeroSkillFx.JOB_FX_FILES)
	for job in JOBS:
		check(HeroSkillFx.JOB_FX_FILES.has("res://job_fx_%s.gd" % job), "механики «%s» подключены" % job)


# ---------- Зверолов ----------

func _bm_passives() -> void:
	var player: Player = main.player
	var pt := pet()
	var hp0 := pt.max_hp
	var mp0 := pt.max_mp
	var str0 := int(pt.stats["stats"]["str"])
	var regen0 := pt.hp_regen
	var hero_hp := player.max_hp
	_learn_job("beastmaster")
	pt = pet()
	check(pt.max_hp > hp0, "«Звериная крепость» и «Родство»: макс. HP питомца %d → %d" % [hp0, pt.max_hp])
	check(pt.max_mp > mp0, "«Звериный дух»: макс. MP питомца %d → %d" % [mp0, pt.max_mp])
	check(int(pt.stats["stats"]["str"]) > str0, "«Родство со зверем»: Сила питомца %d → %d" % [str0, int(pt.stats["stats"]["str"])])
	check(pt.hp_regen > regen0, "«Живучесть стаи»: восстановление HP питомца %.1f → %.1f" % [regen0, pt.hp_regen])
	check(player.max_hp >= hero_hp, "пассивки питомца герою не мешают")
	check(not HeroSkills.bonuses(game.hero, "beastmaster", player.weapon_kind).has("pet_stats"), "пассивки питомца — не герою")
	check(PetBond.xp_mult() > 1.25, "«Наставник зверя»: опыт питомца ×%.2f" % PetBond.xp_mult())
	# Опыт питомца за убийство — больше обычной доли
	var m := ensure_mob("pheasant", 20)
	var base := Combat.xp_for(roundi(float(m.xp_reward) * PetData.XP_SHARE), m.level, pt.level)
	var lv0 := pt.level
	var xp0 := pt.xp
	main.pets.on_mob_killed(m)
	var got := pt.xp - xp0 if pt.level == lv0 else base + 1
	check(got > base, "питомец получил больше опыта: %d (обычно %d)" % [got, base])
	check(HeroSkills.kind_name("pet_vigor").contains("питомцу"), "в карточке — «пассивное (питомцу)»")


func _bm_auras() -> void:
	var player: Player = main.player
	var pt := pet()
	var atk0 := pt.atk
	var str0 := int(pt.stats["stats"]["str"])
	_toggle("beast_might", true)
	check(pt.atk > atk0 and int(pt.stats["stats"]["str"]) > str0, "«Звериная мощь»: атака питомца %d → %d, Сила %d → %d" % [
		atk0, pt.atk, str0, int(pt.stats["stats"]["str"])])
	check(pt.effects.has("hero:beast_might"), "значок ауры героя у питомца")
	check(main.hud.status_row("pet").source == pt.effects, "ряд значков панели питомца — эффекты питомца")
	var def0 := pt.defense
	_toggle("beast_hide", true)
	check(not HeroSkills.toggle_on(game.hero, "beast_might") and not pt.effects.has("hero:beast_might"),
		"одна поддержка за раз: «Звериная мощь» выключилась")
	check(pt.defense > def0, "«Звериная шкура»: защита питомца %d → %d" % [def0, pt.defense])
	var matk0 := int(pt.stats["matk"])
	_toggle("beast_wit", true)
	check(int(pt.stats["matk"]) > matk0, "«Звериная смекалка»: маг. атака питомца %d → %d" % [matk0, int(pt.stats["matk"])])
	var mdef0 := pt.mdef
	_toggle("beast_calm", true)
	check(pt.mdef > mdef0, "«Звериное спокойствие»: маг. защита питомца %d → %d" % [mdef0, pt.mdef])
	_toggle("ward_charm", true)
	check(pt.bond_guard > 0.05 and player.skill_guard > 0.05, "«Оберег»: урон по питомцу −%d%%, по герою −%d%%" % [
		roundi(pt.bond_guard * 100.0), roundi(player.skill_guard * 100.0)])
	check(PetBond.pet_incoming(pt, 100) < 100, "урон по питомцу ниже: 100 → %d" % PetBond.pet_incoming(pt, 100))
	_toggle("radiant_claws", true)
	var m := ensure_mob()
	check(pt.bond_light > 0.2 and PetBond.pet_basic_hit(pt, m, 100) > 100, "«Светлые когти»: удар питомца 100 → %d" %
		PetBond.pet_basic_hit(pt, m, 100))
	# Аура выключается — бонус уходит
	_toggle("ward_charm", false)
	check(pt.bond_guard == 0.0 and not pt.effects.has("hero:ward_charm"), "«Оберег» выключен — защиты и значка нет")
	# «Лечение зверя» (этап 1) — по-прежнему
	pt.hp = pt.max_hp / 2
	pt.bond_hp_changed()
	var h0 := pt.hp
	_cast("mend_beast")
	check(pt.hp > h0, "«Лечение зверя»: %d → %d" % [h0, pt.hp])


func _bm_life() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	var pt := pet()
	# «Нить жизни»: смертельный удар — питомец встаёт
	_toggle("life_thread", true)
	pt.take_damage(pt.max_hp * 5, null)
	check(pet() == pt and not pt.is_down and pt.hp > 0, "«Нить жизни»: питомец встал с %d HP" % pt.hp)
	check(absf(float(pt.hp) / float(pt.max_hp) - 0.20) < 0.03, "с 20%% HP (ур. 3): %d / %d" % [pt.hp, pt.max_hp])
	check(pt.life_thread_cd > 0.0 and pt.effects.has("hero_cd:life_thread"), "«Нить жизни» перезаряжается (значок)")
	pt.take_damage(pt.max_hp * 5, null)
	check(pt.is_down and bool(game.pets[0].get("dead", false)), "второй смертельный удар — питомец погиб (перезарядка)")
	_toggle("life_thread", false)
	# «Второе дыхание»: воскрешает погибшего
	check(pet() == null, "питомца нет")
	_cast("second_wind")
	var back := pet()
	check(back != null and not bool(game.pets[0].get("dead", false)), "«Второе дыхание»: питомец воскрешён и призван")
	var frac := float(back.hp) / float(back.max_hp)
	check(frac > 0.3 and frac < 0.5, "воскрешён с %d%% HP" % roundi(frac * 100.0))
	check(back.global_position.distance_to(player.global_position) < 5.0, "питомец рядом с героем")
	player.skill_cd.erase("second_wind")
	player.mp = player.max_mp
	var mp0 := player.mp
	check(not player.use_skill("second_wind") and player.mp == mp0, "без погибших — не применяется, MP цел")
	check(main.hud._msg_label.text.contains("жив"), "сообщение: питомец жив")
	# «Небесный обмен»: питомец отдаёт силы
	player.hp = player.max_hp / 4
	player.mp = player.max_mp / 4
	var hp0 := player.hp
	player.skill_cd.erase("sky_offering")
	var mpb := player.mp
	check(player.use_skill("sky_offering"), "«Небесный обмен» применён")
	check(player.hp > hp0 + player.max_hp / 3, "герою +HP: %d → %d" % [hp0, player.hp])
	check(player.mp > mpb, "герою +MP: %d → %d" % [mpb, player.mp])
	check(bool(game.pets[0].get("dead", false)) and pet() == null, "питомец отдал силы и пал")
	check(float(player.skill_cd.get("sky_offering", 0.0)) > 0.0, "«Небесный обмен» на перезарядке")
	check(PetBond.revive(player, 1.0, 1.0) and pet() != null, "питомец снова с героем (воскрешение)")
	pet().set_mode("follow")
	# «Общая боль»: часть урона по герою — питомцу
	_toggle("shared_pain", true)
	AdminPanel.god = false
	pt = pet()
	pt.hp = pt.max_hp
	pt.bond_hp_changed()
	player.hp = player.max_hp
	var full := maxi(1, 200 - int(float(player.defense + player.aura_def) * 0.5))
	full = maxi(1, roundi(float(full) * (1.0 - player.skill_guard)))
	var ph0 := player.hp
	var pth0 := pt.hp
	player.take_damage(200, null)
	AdminPanel.god = true
	var hero_loss := ph0 - player.hp
	var pet_loss := pth0 - pt.hp
	check(pet_loss > 0 and hero_loss < full, "«Общая боль»: герою −%d вместо −%d, питомцу −%d" % [hero_loss, full, pet_loss])
	pt.hp = roundi(float(pt.max_hp) * 0.2)
	pt.bond_hp_changed()
	var weak := pt.hp
	AdminPanel.god = false
	player.take_damage(200, null)
	AdminPanel.god = true
	check(pt.hp == weak, "слабому питомцу (20 % HP) боль не передаётся")
	_toggle("shared_pain", false)
	pt.hp = pt.max_hp
	pt.bond_hp_changed()
	pm.active_pet.set_mode("follow")


# ---------- Адепт ----------

func _adept_auras() -> void:
	game.race_id = "dark_elf"
	_learn_job("adept")
	var pt := pet()
	pt.set_mode("follow")
	var atk0 := pt.atk
	var hp0 := pt.max_hp
	_toggle("fire_feed", true)
	check(pt.atk > atk0 and pt.max_hp > hp0, "«Огненная подпитка»: атака %d → %d, HP %d → %d" % [atk0, pt.atk, hp0, pt.max_hp])
	var mp0 := pt.max_mp
	_toggle("wind_feed", true)
	check(not HeroSkills.toggle_on(game.hero, "fire_feed") and pt.max_mp > mp0, "одна подпитка за раз; «Ветряная»: MP %d → %d" % [
		mp0, pt.max_mp])
	var cd0 := pt.attack_time
	_toggle("battle_fervor", true)
	check(pt.attack_time < cd0, "«Боевой задор»: удар питомца раз в %.2f → %.2f с" % [cd0, pt.attack_time])
	var th0 := pt.threat
	_toggle("beast_roar", true)
	check(pt.threat > th0 + 0.2, "«Звериный рык»: угроза питомца %.2f → %.2f" % [th0, pt.threat])
	var crit0 := pt.crit
	_cast("predator_claws")
	check(pt.crit >= crit0 + 14.0, "«Когти хищника»: крит питомца %.1f → %.1f%%" % [crit0, pt.crit])
	check(pt.effects.has("hero_buff:predator_claws"), "значок «Когтей хищника» у питомца")


func _adept_blood_rain() -> void:
	var player: Player = main.player
	var pt := pet()
	pt.hp = pt.max_hp
	pt.bond_hp_changed()
	var m := ensure_mob("wolf", 30, 6.0)
	player.select_target(m)
	mob_hp0 = m.hp
	pet_hp0 = pt.hp
	_cast("blood_rain")
	check(pt.hp < pet_hp0, "«Кровавый ливень»: питомец отдал HP %d → %d" % [pet_hp0, pt.hp])
	check(not mob_ok(m) or m.hp < mob_hp0, "первый кровавый удар — сразу: %d → %d" % [mob_hp0, m.hp if mob_ok(m) else 0])
	mob_hp0 = m.hp if mob_ok(m) else 0
	# Слабый питомец (меньше 30 % HP) крови не отдаёт: MP цел
	pt.hp = roundi(float(pt.max_hp) * 0.27)
	pt.bond_hp_changed()
	player.skill_cd.erase("blood_rain")
	player.mp = player.max_mp
	check(not player.use_skill("blood_rain") and player.mp == player.max_mp, "слабый питомец — «Кровавый ливень» не применён")
	pt.hp = pt.max_hp
	pt.bond_hp_changed()


func _adept_sacrifices() -> void:
	var player: Player = main.player
	var pt := pet()
	# «Жизнь взаймы»
	player.hp = player.max_hp / 3
	hero_hp0 = player.hp
	pt.hp = pt.max_hp
	pt.bond_hp_changed()
	pet_hp0 = pt.hp
	_cast("borrowed_life")
	check(player.hp > hero_hp0 and pt.hp < pet_hp0, "«Жизнь взаймы»: герой %d → %d, питомец %d → %d" % [hero_hp0, player.hp,
		pet_hp0, pt.hp])
	# Не ниже четверти HP питомца
	for i in 6:
		player.skill_cd.erase("borrowed_life")
		player.hp = 1
		player.mp = player.max_mp
		player.use_skill("borrowed_life")
	check(pt.hp >= ceili(float(pt.max_hp) * PetBond.PET_FLOOR) and not pt.is_down,
		"питомец не опускается ниже %d%% HP: %d / %d" % [roundi(PetBond.PET_FLOOR * 100.0), pt.hp, pt.max_hp])
	pt.hp = pt.max_hp
	pt.bond_hp_changed()
	# «Вопль бездны»: урон всем вокруг питомца
	var m := ensure_mob("wolf", 30, 2.0)
	m.global_position = pt.global_position + Vector3(1.5, 0, 0)
	mob_hp0 = m.hp
	pet_hp0 = pt.hp
	_cast("abyss_howl")
	check(pt.hp < pet_hp0, "«Вопль бездны»: питомец отдал HP %d → %d" % [pet_hp0, pt.hp])
	check(not mob_ok(m) or m.hp < mob_hp0, "«Вопль бездны»: зверь у питомца %d → %d" % [mob_hp0, m.hp if mob_ok(m) else 0])
	# «Кровь бездны»: питомец жертвует собой
	player.hp = player.max_hp / 5
	player.skill_cd.erase("abyss_blood")
	player.mp = player.max_mp
	check(player.use_skill("abyss_blood"), "«Кровь бездны» применена")
	check(player.hp == player.max_hp, "HP героя полное")
	check(player.skill_guard >= 0.8 and player.effects.has("buff:abyss_blood"), "урон по герою −%d%% (значок)" %
		roundi(player.skill_guard * 100.0))
	check(pet() == null and bool(game.pets[0].get("dead", false)), "питомец пожертвовал собой")
	player.skill_cd.erase("abyss_blood")
	check(not player.use_skill("abyss_blood"), "без питомца «Кровь бездны» не применить")
	check(PetBond.revive(player, 1.0, 1.0), "питомец воскрешён")


# ---------- Колдун ----------

func _conj_chords() -> void:
	var player: Player = main.player
	game.race_id = "human"
	_learn_job("conjurer")
	var pt := pet()
	pt.set_mode("follow")
	for e in [["chord_wisdom", "wis"], ["chord_mind", "int"], ["chord_strength", "str"], ["chord_vitality", "vit"]]:
		var sid := String(e[0])
		var st := String(e[1])
		var p0 := int(pt.stats["stats"][st])
		var h0 := int(player.hero_stats["stats"][st])
		_toggle(sid, true)
		check(int(pt.stats["stats"][st]) > p0 and int(player.hero_stats["stats"][st]) > h0,
			"«%s»: %s питомца %d → %d, героя %d → %d" % [sid, st, p0, int(pt.stats["stats"][st]), h0, int(player.hero_stats["stats"][st])])
		check(pt.effects.has("hero:" + sid), "значок созвучия у питомца")
	check(HeroSkills.toggle_on(game.hero, "chord_vitality") and not HeroSkills.toggle_on(game.hero, "chord_wisdom"),
		"одно созвучие за раз")


func _conj_actives() -> void:
	var player: Player = main.player
	var pt := pet()
	# «Очищение зверя»: снимает ослабления, лечит, защищает
	pt.hero_effect("test_debuff", 30.0, {"name": "Проверка", "src": "", "icon": {}, "debuff": true})
	pt.hp = pt.max_hp / 2
	pt.bond_hp_changed()
	var h0 := pt.hp
	_cast("cleanse_beast")
	check(not pt.effects.has("test_debuff"), "«Очищение зверя» сняло ослабление")
	check(pt.hp > h0 and pt.bond_guard > 0.1, "питомец подлечен и защищён: HP %d → %d, урон −%d%%" % [h0, pt.hp,
		roundi(pt.bond_guard * 100.0)])
	# «Колыбельная»: лечение со временем
	pt.hp = pt.max_hp / 3
	pt.bond_hp_changed()
	_cast("lullaby")
	check(pt.effects.has("hot:lullaby"), "«Колыбельная»: значок лечения у питомца")
	# «Дикий рёв»: страх
	var m := ensure_mob("wolf", 30, 4.0)
	player.select_target(m)
	_cast("wild_roar")
	check(m.fear_time >= 9.0, "«Дикий рёв»: зверь в страхе %.1f с" % m.fear_time)
	# «Гнев стаи»: атака героя и питомца
	var atk0 := player.atk
	var patk0 := pt.atk
	_cast("pack_wrath")
	check(player.atk > atk0 and pt.atk > patk0, "«Гнев стаи»: атака героя %d → %d, питомца %d → %d" % [atk0, player.atk,
		patk0, pt.atk])
	check(player.skill_guard > 0.1 and pt.bond_guard > 0.1, "«Гнев стаи»: урон по обоим ниже")
	check(player.effects.has("buff:pack_wrath") and pt.effects.has("hero_buff:pack_wrath"), "значки «Гнева стаи» у обоих")
	# «Гнев духов»: зверь рядом с питомцем
	m.global_position = pt.global_position + Vector3(2.0, 0, 0)
	m.stun(60.0)
	mob_hp0 = m.hp
	_cast("spirit_wrath")
	check(pt.hero_buffs.has("spirit_wrath"), "«Гнев духов» действует у питомца")
	pet_hp0 = pt.hp


func _merge_on() -> void:
	var player: Player = main.player
	var pt := pet()
	hero_hp0 = player.max_hp
	mob_hp0 = int(player.hero_stats["stats"]["str"])
	_toggle("soul_merge", true)
	check(pt.bond_mode == "merge" and not pt.visible, "«Слияние душ»: питомец внутри героя")
	check(int(player.hero_stats["stats"]["str"]) > mob_hp0 + 6, "Сила героя %d → %d (и доля Силы питомца)" % [mob_hp0,
		int(player.hero_stats["stats"]["str"])])
	check(player.max_hp > hero_hp0, "макс. HP героя %d → %d" % [hero_hp0, player.max_hp])
	check(player.get_node_or_null("PetBondAura") != null, "сияние вокруг героя")


func _merge_check() -> void:
	var player: Player = main.player
	var pt := pet()
	check(pt != null and pt.bond_mode == "merge", "слияние держится")
	check(pt.global_position.distance_to(player.global_position) < 0.5, "питомец «в» герое")
	var h0 := pt.hp
	pt.take_damage(500, null)
	check(pt.hp == h0, "питомец в слиянии не получает урона")
	_toggle("beast_form", true)
	check(not HeroSkills.toggle_on(game.hero, "soul_merge") and pt.bond_mode == "form", "одна связь за раз: облик вместо слияния")
	_toggle("beast_form", false)


func _merge_back() -> void:
	var player: Player = main.player
	var pt := pet()
	check(pt.bond_mode == "" and pt.visible and pt.is_in_group("pets"), "связь выключена — питомец снова рядом")
	check(player._model.visible and player.get_node_or_null("PetBondAura") == null, "модель героя на месте, сияния нет")
	check(int(player.hero_stats["stats"]["str"]) <= mob_hp0 + 1, "Сила героя вернулась: %d" % int(player.hero_stats["stats"]["str"]))


func _form_on() -> void:
	var player: Player = main.player
	var spd0 := player.cur_speed()
	_toggle("beast_form", true)
	check(pet().bond_mode == "form" and not player._model.visible, "«Звериный облик»: вместо героя — модель питомца")
	check(player.cur_speed() > spd0 and player.stealth > 0.1, "бег быстрее (%.1f → %.1f), звери замечают ближе" % [spd0,
		player.cur_speed()])


func _form_check() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	var pt := pet()
	check(pt.global_position.distance_to(player.global_position) < 0.5 and pt.visible, "питомец — облик героя")
	# Отозвали питомца — связь рвётся
	pm.recall()
	check(not HeroSkills.toggle_on(game.hero, "beast_form") and player._model.visible, "питомец отозван — облик снят")
	check(player.set_toggle("soul_merge", true) != "", "без питомца «Слияние душ» не включить")
	pm.summon(0)


# ---------- Баланс ----------

## Герой профессии + питомец своего уровня против зверя своего уровня (HP ×3): обычные атаки (Combat.expected_dps),
## без умений — их урон сверху (цель с умениями — 15–30 с, здесь только верхняя граница без них).
func _balance() -> void:
	var player: Player = main.player
	var races := {"beastmaster": "light_elf", "adept": "dark_elf", "conjurer": "human"}
	var auras := {"beastmaster": ["beast_might", "radiant_claws"], "adept": ["fire_feed", "battle_fervor"],
		"conjurer": ["chord_strength"]}
	for job in JOBS:
		for lv in BAL_LEVELS:
			var lvl := int(lv)
			game.level = lvl
			game.race_id = String(races[job])
			become_job(String(job))
			game.hero["jp"] = 5000
			HeroSkills.learn_all(game.hero, String(job), lvl)
			player.refresh_skills()
			var pt := pet()
			pt.level = lvl
			pt.refresh_skills()
			for a in auras[job]:
				if HeroSkills.skill_level(game.hero, String(a)) > 0:
					player.mp = player.max_mp
					player.set_toggle(String(a), true)
			var m := main.spawn_mob("panther", lvl, arena + Vector3(30, 0, 30)) as Mob
			var mp := Combat.profile_of(m)
			# HP зверей уже ×3 (MobStats.MOB_HP_MULT)
			var hp3 := float(m.max_hp)
			var dh := Combat.expected_dps(Combat.profile_of(player), mp)
			var dp := Combat.expected_dps(Combat.profile_of(pt), mp)
			var with_pet := hp3 / maxf(0.01, dh + dp)
			var alone := hp3 / maxf(0.01, dh)
			print("  БАЛАНС %s ур. %d: зверь HP %d, герой %.1f/с, питомец %.1f/с — вдвоём %.1f с, один %.1f с" % [
				job, lvl, roundi(hp3), dh, dp, with_pet, alone])
			check(with_pet > 2.0 and with_pet < 60.0, "%s ур. %d: вдвоём (обычные атаки) %.1f с" % [job, lvl, with_pet])
			check(alone / with_pet > 1.3, "%s ур. %d: без питомца заметно дольше (%.1f с против %.1f с)" % [job, lvl, alone, with_pet])
			m.remove_from_group("mobs")
			m.queue_free()
