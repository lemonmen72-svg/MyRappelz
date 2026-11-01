extends "res://tests/test_base.gd"
## Команды питомца (круглые кнопки HUD у панели питомца) и ячейки умений питомца (окно существа).
## Кнопки «Авто», «Атака», «Защита», «За мной»: видны при призванном питомце, со значками, текущий режим — с кольцом;
## «За мной» — не дерётся (и в ответ); «Защита» — нападает на ударившего хозяина и на цель хозяина, сам на зверей
## не бросается; «Авто» — сам нападает на ближайшего зверя в Pet.AUTO_RANGE м от хозяина, дальше — нет, цель
## дальше поводка бросает; «Атака» — разовая: без цели — сообщение, с целью — бьёт её (даже вне радиуса «Авто»),
## после её смерти — снова прежний режим. Режим запоминается в записи (cmd): после отзыва и призыва, после
## сохранения и загрузки. Ячейки: 3 «Авто» + 2 «Ауры», новое активное умение само встаёт в свободную ячейку,
## назначение и перенос, неизученное и пассивное не ставятся, ИИ применяет только умения из ячеек (по порядку),
## переключаемое без ячейки выключено, окно существа (ячейки, «В ячейку», «Убрать», касание ячейки), окно
## «Питомцы» (ячейки коротко), перенос старой записи без ячеек.

## Зверь для боёв: слабый фазан (волк питомца сильнее — бой короткий).
const MOB := "pheasant"
const MOB_LVL := 3

var arena := Vector3.ZERO
var timer := 0
var a: Mob = null
var b: Mob = null
var c: Mob = null
var d: Mob = null
var uses_before := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 10


func before_start() -> void:
	AdminPanel.god = true
	game.add_pet("wolf", "Серохвост", 12)
	var i: int = game.add_pet("panther", PetData.stage_name("panther", 20), 20)
	var rec: Dictionary = game.pets[i]
	rec["jp"] = 200
	for id in ["shadow_rend", "dusk_rupture", "shadow_fang", "daze", "shadow_bond", "provoke"]:
		check(PetSkills.learn(rec, String(id)), "пантера выучила «%s»" % String(PetSkills.get_skill(String(id))["name"]))
	game.active_pet = 0


func run_step() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	var hud: HUD = main.hud
	match step:
		0:
			_check_migration()
			# Арена: звери острова убраны (без возрождения), герой — на ровном месте вне безопасных зон
			for n in get_tree().get_nodes_in_group("mobs"):
				var m := n as Mob
				m.remove_from_group("mobs")
				m.queue_free()
			arena = _find_arena()
			check(arena != Vector3.ZERO, "арена для питомца найдена: %s" % arena)
			player.global_position = arena
			wait = 5
			step = 1
		1:
			var pet: Pet = pm.active_pet
			check(pet != null and pet.species == "wolf", "призван волк")
			if pet == null:
				return
			pet._teleport_to_owner()
			check(pet.mode == "defend" and PetSkills.command(game.pets[0]) == "defend", "режим по умолчанию — «Защита»")
			# Кнопки HUD
			var ids := hud.pet_button_ids()
			check(", ".join(PackedStringArray(ids)) == "pet_auto, pet_attack, pet_defend, pet_follow", "кнопки питомца: %s" % [ids])
			for id in ids:
				check(hud.is_button_visible(id), "кнопка %s видна" % id)
				var ic := hud.button_icon(id)
				check(ic != null and String(ic.spec.get("shape", "")) == id, "у кнопки %s значок-рисунок" % id)
				check(hud.button_text(id) != "", "у кнопки %s есть подпись: %s" % [id, hud.button_text(id)])
			_check_lit("pet_defend")
			for k in [KEY_Z, KEY_F, KEY_X, KEY_G]:
				check(HUD.KEYS.has(k), "клавиша для команды питомца: %s" % OS.get_keycode_string(k))
			# «За мной»: касание кнопки
			touch(true, 4, button_center("pet_follow"))
			touch(false, 4, button_center("pet_follow"))
			check(pet.mode == "follow" and String(game.pets[0]["cmd"]) == "follow", "касание «За мной» — режим follow в записи")
			_check_lit("pet_follow")
			# Зверь бьёт хозяина
			a = _spawn(Vector3(5.0, 0, 0))
			a.target = player
			player.take_damage(1, a)
			check(is_same(player.last_attacker, a), "герой запомнил, кто его ударил")
			pet.take_damage(1, a)
			timer = 0
			step = 2
		2:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.target != null:
				fail("«За мной»: питомец взял цель %s" % pet.target.mob_name)
				return
			if timer < 60:
				return
			check(a.hp == a.max_hp, "«За мной»: питомец не дерётся, даже когда бьют хозяина и его самого")
			# «Защита»
			main._on_action("pet_defend")
			check(pet.mode == "defend" and String(game.pets[0]["cmd"]) == "defend", "«Защита» — режим defend в записи")
			_check_lit("pet_defend")
			timer = 0
			step = 3
		3:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.target == a:
				check(true, "«Защита»: питомец напал на зверя, ударившего хозяина (%d кадров)" % timer)
				a.consume()
				# Зверь рядом, никого не трогает — в «Защите» питомец сам не нападает
				b = _spawn(Vector3(0, 0, 5.0))
				player.last_target = null
				timer = 0
				step = 4
				return
			if timer > 60:
				fail("«Защита»: питомец не нападает на ударившего хозяина")
		4:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.target != null:
				fail("«Защита»: питомец сам напал на зверя %s" % pet.target.mob_name)
				return
			if timer < 40:
				return
			check(b.hp == b.max_hp, "«Защита»: на мирного зверя рядом питомец не нападает")
			# Хозяин атакует зверя — питомец помогает
			player.last_target = b
			timer = 0
			step = 5
		5:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.target == b:
				check(true, "«Защита»: питомец бьёт цель хозяина")
				player.last_target = null
				b.consume()
				# «Авто»: зверь в 8 м — нападает, зверь в 20 м — нет
				c = _spawn(Vector3(8.0, 0, 0))
				d = _spawn(Vector3(-20.0, 0, 0))
				main._on_action("pet_auto")
				check(pet.mode == "auto" and String(game.pets[0]["cmd"]) == "auto", "«Авто» — режим auto в записи")
				_check_lit("pet_auto")
				timer = 0
				step = 6
				return
			if timer > 60:
				fail("«Защита»: питомец не помогает бить цель хозяина")
		6:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.target == d:
				fail("«Авто»: питомец напал на зверя в 20 м от хозяина")
				return
			if pet.target == c:
				check(true, "«Авто»: питомец сам напал на ближайшего зверя в %d м (%d кадров)" % [roundi(Pet.AUTO_RANGE), timer])
				# Поводок: цель дальше Pet.LEASH от хозяина — питомец бросает её и не ищет дальше AUTO_RANGE
				c.global_position = _ground(Vector3(0, 0, Pet.LEASH + 2.0))
				pet.global_position = player.global_position + Vector3(1.0, 0.2, 0)
				wait = 2
				timer = 0
				step = 7
				return
			if timer > 60:
				fail("«Авто»: питомец не нападает на зверя рядом")
		7:
			var pet: Pet = pm.active_pet
			check(pet.target == null, "«Авто»: цель дальше поводка (%d м) брошена" % roundi(Pet.LEASH))
			check(pet.find_target() == null, "«Авто»: дальше %d м от хозяина целей нет" % roundi(Pet.AUTO_RANGE))
			c.consume()
			# «Атака» без цели — сообщение, режим прежний
			player._set_target(null)
			main._on_action("pet_attack")
			check(main.hud._msg_label.text.contains("Выберите цель"), "«Атака» без цели: " + main.hud._msg_label.text)
			check(pet.mode == "auto", "без цели режим не меняется")
			# «Атака» по выделенному зверю в 20 м (вне радиуса «Авто»)
			player._set_target(d)
			main._on_action("pet_attack")
			check(pet.mode == "attack" and pet.target == d, "«Атака»: питомец атакует выделенного зверя")
			check(String(game.pets[0]["cmd"]) == "auto", "разовая «Атака» не меняет режим в записи")
			_check_lit("pet_attack")
			timer = 0
			step = 8
		8:
			var pet: Pet = pm.active_pet
			timer += 1
			if not mob_ok(d) or d.hp < d.max_hp:
				check(true, "«Атака»: питомец добежал и ранил цель (%d кадров)" % timer)
				if mob_ok(d):
					d.take_damage(d.hp + 5, player)
				wait = 3
				step = 9
				return
			if timer > 60 * 15:
				fail("«Атака»: питомец не бьёт выделенного зверя")
		9:
			var pet: Pet = pm.active_pet
			check(pet.mode == "auto", "цель «Атаки» погибла — снова «Авто»: %s" % pet.mode)
			_check_lit("pet_auto")
			# Режим запоминается: отзыв и призыв
			pm.recall()
			for id in hud.pet_button_ids():
				check(not hud.is_button_visible(id), "без питомца кнопка %s скрыта" % id)
			check(pm.summon(0), "волк призван снова")
			wait = 3
			step = 10
		10:
			var pet: Pet = pm.active_pet
			check(pet != null and pet.mode == "auto", "после призыва режим тот же — «Авто»")
			_check_lit("pet_auto")
			main._on_action("pet_follow")
			check(game.save_game(), "игра сохранена")
			game.pets[0]["cmd"] = "auto"
			check(game.load_game(), "игра загружена")
			check(String(game.pets[0]["cmd"]) == "follow", "режим «За мной» сохранён в save.json")
			wait = 3
			step = 11
		11:
			var pet: Pet = pm.active_pet
			check(pet != null and is_same(pet.record, game.pets[0]) and pet.mode == "follow", "после загрузки — «За мной»")
			# Ячейки умений: пантера
			check(pm.summon(1), "пантера призвана")
			wait = 3
			step = 12
		12:
			_check_slots(player, pm)
			_check_window(pm)
			# Бой: ИИ применяет только умение из ячейки
			var pet: Pet = pm.active_pet
			var rec: Dictionary = game.pets[1]
			for i in PetSkills.AUTO_SLOTS:
				pet.clear_slot("auto", i)
			check(pet.assign_slot("shadow_fang", 2) == "", "«Клык полуночи» — в ячейку 3")
			pet.skill_cds.clear()
			pet.mp = pet.max_mp
			uses_before = pet.learned_uses
			a = _spawn(Vector3(3.0, 0, 3.0))
			pet._teleport_to_owner()
			player._set_target(a)
			main._on_action("pet_attack")
			check(rec["slots"] == ["", "", "shadow_fang"], "в ячейках только «Клык полуночи»: %s" % [rec["slots"]])
			timer = 0
			step = 13
		13:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.learned_uses > uses_before:
				var used: Array = []
				for k in pet.skill_cds:
					if float(pet.skill_cds[k]) > 0.0:
						used.append(String(k))
				check(used == ["shadow_fang"], "ИИ применил только умение из ячейки: %s" % [used])
				ok_done()
				return
			if not mob_ok(a):
				# Фазан пал от обычных атак раньше, чем умение — новый
				a = _spawn(Vector3(3.0, 0, 3.0))
				player._set_target(a)
				main._on_action("pet_attack")
			if timer > 60 * 30:
				fail("питомец не применяет умение из ячейки")


# ---------- Ячейки ----------

func _check_slots(player: Player, pm: PetManager) -> void:
	var pet: Pet = pm.active_pet
	check(pet != null and pet.species == "panther", "призвана пантера")
	if pet == null:
		return
	var rec: Dictionary = game.pets[1]
	check(rec["slots"] == ["shadow_rend", "dusk_rupture", "shadow_fang"], "новые активные — сами в ячейки «Авто»: %s"
		% [rec["slots"]])
	check(rec["aura_slots"] == ["", ""] and (rec["toggles"] as Dictionary).is_empty(), "ауры не включены сами")
	check(", ".join(PackedStringArray(pet._actives)) == "shadow_rend, dusk_rupture, shadow_fang",
		"ИИ берёт умения из ячеек: %s" % [pet._actives])
	# Назначение, перенос, обмен, лимит
	check(pet.assign_slot("daze", 0) == "" and rec["slots"] == ["daze", "dusk_rupture", "shadow_fang"],
		"«Морок» — в ячейку 1 вместо «Двойного росчерка»: %s" % [rec["slots"]])
	check(pet.assign_slot("shadow_fang", 0) == "" and rec["slots"] == ["shadow_fang", "dusk_rupture", "daze"],
		"перенос из ячейки 3 в 1 — умения меняются местами: %s" % [rec["slots"]])
	check(pet.assign_slot("shadow_rend", 3) != "", "ячеек «Авто» только 3")
	check(pet.assign_slot("inner_fire", 0) != "", "пассивное в ячейку не ставится: " + PetSkills.slot_block(rec, "inner_fire"))
	check(pet.assign_slot("hunter_call", 1) != "", "неизученное в ячейку не ставится: " + PetSkills.slot_block(rec, "hunter_call"))
	check(pet.assign_slot("shadow_bond", 2) != "", "аура — только в ячейку ауры (их 2)")
	# ИИ: только ячейки, по порядку
	var m := _spawn(Vector3(4.0, 0, -4.0))
	m.target = player
	pet.skill_cds.clear()
	pet.mp = pet.max_mp
	pet.clear_slot("auto", 0)
	pet.clear_slot("auto", 2)
	check(pet.assign_slot("dusk_rupture", 0) == "" and pet.assign_slot("shadow_fang", 1) == "", "в ячейках «Разрыв», «Клык»")
	check(pet._pick_active(m) == "dusk_rupture", "ИИ берёт первое готовое по порядку ячеек (не по силе): %s"
		% pet._pick_active(m))
	pet.skill_cds["dusk_rupture"] = 5.0
	pet.skill_cds["shadow_fang"] = 5.0
	check(pet._pick_active(m) == "", "ячейки на перезарядке — «Двойной росчерк» вне ячеек ИИ не применяет")
	pet.skill_cds.clear()
	m.consume()
	# Ауры: включены только в ячейках
	var mp0 := pet.mp
	check(pet.assign_slot("shadow_bond", 0) == "" and PetSkills.toggle_on(rec, "shadow_bond") and pet.mp < mp0,
		"«Узы тени» в ячейке ауры 1 — включены (MP %d → %d)" % [mp0, pet.mp])
	check(player.aura_atk > 0.0, "«Узы тени» дают бонус хозяину")
	pet.mp = pet.max_mp
	check(pet.set_toggle("provoke", true) == "" and PetSkills.slot_of(rec, "provoke") == 1 and pet.threat > 0.0,
		"включение «Дерзкого вызова» заняло ячейку ауры 2")
	check(pet.clear_slot("aura", 1) == "provoke" and not PetSkills.toggle_on(rec, "provoke") and is_zero_approx(pet.threat),
		"убрали из ячейки — «Дерзкий вызов» выключен")
	check(pet.set_toggle("shadow_bond", false) == "" and PetSkills.slot_of(rec, "shadow_bond") < 0
		and is_zero_approx(player.aura_atk), "выключение «Уз тени» освободило ячейку, бонус снят")
	# Переключаемое без ячейки включиться не может: запись чинится (свободная ячейка или выключение)
	(rec["toggles"] as Dictionary)["provoke"] = true
	rec["aura_slots"] = ["shadow_bond", "shadow_bond"]
	PetSkills.ensure_record(rec)
	check(rec["aura_slots"] == ["shadow_bond", "provoke"], "повторы убраны, включённое без ячейки заняло свободную: %s"
		% [rec["aura_slots"]])
	check(not PetSkills.toggle_on(rec, "shadow_bond") or PetSkills.slot_of(rec, "shadow_bond") >= 0,
		"включено только то, что в ячейке")
	pet.clear_slot("aura", 0)
	pet.clear_slot("aura", 1)
	check((rec["toggles"] as Dictionary).is_empty(), "ячейки аур пусты — переключаемые выключены")
	# Без MP аура остаётся в ячейке выключенной и включается при полном MP
	pet.mp = 0
	var warn := pet.assign_slot("shadow_bond", 0)
	check(warn != "" and PetSkills.slot_of(rec, "shadow_bond") == 0 and not PetSkills.toggle_on(rec, "shadow_bond"),
		"без MP: «Узы тени» в ячейке, но выключены (%s)" % warn)
	pet.mp = pet.max_mp
	pet._restore_auras()
	check(PetSkills.toggle_on(rec, "shadow_bond"), "MP полное — аура из ячейки включилась сама")
	pet.assign_slot("shadow_rend", 2)


## Окно существа: 5 ячеек, «В ячейку», «Убрать», касание ячейки; окно «Питомцы» — ячейки коротко.
func _check_window(pm: PetManager) -> void:
	var cw: CreatureWindow = pm.creature
	var rec: Dictionary = game.pets[1]
	check(pm.open_creature(1, "skills") and cw.is_open(), "окно существа пантеры, «Умения»")
	for key in ["slot_auto_0", "slot_auto_1", "slot_auto_2", "slot_aura_0", "slot_aura_1"]:
		check(cw.buttons.has(key), "ячейка %s в окне" % key)
	check(not cw.buttons.has("slot_auto_3") and not cw.buttons.has("slot_aura_2"), "ячеек ровно 3 + 2")
	check(_window_text().contains("Авто:") and _window_text().contains("Ауры:"), "подписи ячеек «Авто» и «Ауры»")
	# Касание занятой ячейки — убрать
	var first := String((rec["slots"] as Array)[0])
	_press(cw, "slot_auto_0")
	check(String((rec["slots"] as Array)[0]) == "" and first != "", "касание ячейки убрало «%s»" % first)
	# Карточка: «В ячейку 1»
	_press(cw, "skill_daze")
	check(cw.buttons.has("toslot_daze_0") and cw.buttons.has("toslot_daze_2") and not cw.buttons.has("toslot_daze_3"),
		"в карточке активного — «В ячейку 1–3»")
	_press(cw, "toslot_daze_0")
	check(String((rec["slots"] as Array)[0]) == "daze", "«В ячейку 1» поставил «Морок»")
	check(cw.buttons.has("unslot_daze"), "у умения в ячейке — «Убрать»")
	_press(cw, "unslot_daze")
	check(PetSkills.slot_of(rec, "daze") < 0, "«Убрать» освободил ячейку")
	# Касание пустой ячейки — поставить выбранное умение
	_press(cw, "skill_daze")
	_press(cw, "slot_auto_0")
	check(String((rec["slots"] as Array)[0]) == "daze", "касание пустой ячейки поставило выбранный «Морок»")
	# Ауры в карточке: «В ячейку ауры 1–2»
	_press(cw, "skill_provoke")
	check(cw.buttons.has("toslot_provoke_1") and not cw.buttons.has("toslot_provoke_2"), "в карточке ауры — «В ячейку ауры 1–2»")
	pm.active_pet.mp = pm.active_pet.max_mp
	_press(cw, "toslot_provoke_1")
	check(PetSkills.slot_of(rec, "provoke") == 1 and PetSkills.toggle_on(rec, "provoke"), "«Дерзкий вызов» — в ячейке ауры 2, включён")
	_press(cw, "slot_aura_1")
	check(not PetSkills.toggle_on(rec, "provoke"), "касание ячейки ауры — выключено")
	# Неизученное и пассивное — без кнопок ячеек
	_press(cw, "skill_hunter_call")
	check(not cw.buttons.has("toslot_hunter_call_0"), "неизученное умение в ячейку не поставить (кнопок нет)")
	_press(cw, "skill_inner_fire")
	check(not cw.buttons.has("toslot_inner_fire_0"), "пассивное — без ячейки")
	# Окно «Питомцы»
	main._on_action("pets_window")
	var t := _window_text()
	check(t.contains("Авто:") and t.contains("Ауры:") and t.contains("Защита"), "в окне «Питомцы» — режим и ячейки")
	main.hud.close_window()


## Старая запись без ячеек: изученные активные — в ячейки по силе, включённые переключаемые — в ячейки ауры.
func _check_migration() -> void:
	var old := {"species": "panther", "name": "Тень", "level": 20,
		"skills": {"shadow_rend": 3, "dusk_rupture": 2, "shadow_fang": 1, "daze": 1, "shadow_bond": 1, "provoke": 1,
			"inner_fire": 2},
		"toggles": {"shadow_bond": true, "provoke": true}}
	PetSkills.ensure_record(old)
	check(old["slots"] == ["shadow_fang", "dusk_rupture", "daze"], "перенос: активные по силе в 3 ячейки: %s" % [old["slots"]])
	check(old["aura_slots"] == ["provoke", "shadow_bond"] and PetSkills.toggle_on(old, "shadow_bond")
		and PetSkills.toggle_on(old, "provoke"), "перенос: включённые переключаемые — в ячейки ауры: %s" % [old["aura_slots"]])
	check(String(old["cmd"]) == "defend", "перенос: режим «Защита»")
	# Старое сохранение целиком (Game.from_dict): то же; потом — сохранение теста (ячейки и режим в save.json)
	check(game.save_game(), "игра сохранена")
	var d: Dictionary = game.to_dict()
	d["pets"] = [{"species": "panther", "name": "Тень", "level": 20, "skills": {"shadow_rend": 1, "daze": 1},
		"toggles": {"provoke": true, "shadow_bond": true}}]
	d["active_pet"] = -1
	game.from_dict(d)
	var r: Dictionary = game.pets[0]
	check(r["slots"] == ["daze", "shadow_rend", ""], "старое сохранение: ячейки «Авто» %s" % [r["slots"]])
	check(r["aura_slots"] == ["", ""] and (r["toggles"] as Dictionary).is_empty(),
		"старое сохранение: неизученные переключаемые выключены: %s" % [r["toggles"]])
	check(game.load_game(), "игра загружена")
	check(game.pets.size() == 2 and game.pets[1]["slots"] == ["shadow_rend", "dusk_rupture", "shadow_fang"],
		"ячейки пантеры сохранены в save.json: %s" % [game.pets[1].get("slots")])


# ---------- Помощники ----------

## Кольцо (цвет HUD.PET_MODE_ON) только у кнопки id.
func _check_lit(id: String) -> void:
	var hud: HUD = main.hud
	for bid in hud.pet_button_ids():
		var sb := (hud._buttons[bid]["panel"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		var lit := sb != null and sb.bg_color == HUD.PET_MODE_ON
		check(lit == (bid == id), "кнопка %s %s" % [bid, "подсвечена" if bid == id else "не подсвечена"])


## Ровное место вне безопасных зон, далеко от воды: вокруг на 22 м проходимо.
func _find_arena() -> Vector3:
	var w := IslandWorld.current
	if w == null:
		return Vector3.ZERO
	var r := 20.0
	while r < 260.0:
		for k in 32:
			var ang := TAU * float(k) / 32.0
			var q := Vector2(cos(ang), sin(ang)) * r
			if _arena_ok(w, q):
				return w.ground(q.x, q.y)
		r += 5.0
	return Vector3.ZERO


func _arena_ok(w: IslandWorld, q: Vector2) -> bool:
	if not w.is_walkable(q.x, q.y) or w.in_safe_zone(Vector3(q.x, 0, q.y)) or w.water_distance(q.x, q.y) < 12.0:
		return false
	var h0 := w.height_at(q.x, q.y)
	for k in 8:
		var ang := TAU * float(k) / 8.0
		for rr in [5.0, 10.0, 15.0]:
			var p := q + Vector2(cos(ang), sin(ang)) * float(rr)
			if not w.is_walkable(p.x, p.y) or w.in_safe_zone(Vector3(p.x, 0, p.y)) or absf(w.height_at(p.x, p.y) - h0) > 4.0:
				return false
	return true


func _ground(off: Vector3) -> Vector3:
	var p := arena + off
	if IslandWorld.current != null:
		return IslandWorld.current.ground(p.x, p.z)
	return p


## Фазан у арены со смещением off (слот −1 — не возрождается), оглушён надолго: стоит на месте и не нападает сам.
func _spawn(off: Vector3) -> Mob:
	var m: Mob = main.spawn_mob(MOB, MOB_LVL, _ground(off))
	m.stun(600.0)
	return m


func _press(cw: CreatureWindow, key: String) -> void:
	var bt: Button = cw.buttons.get(key)
	check(bt != null and is_instance_valid(bt), "кнопка «%s» в окне существа" % key)
	if bt != null:
		bt.pressed.emit()


func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w != null and is_instance_valid(w):
		for n in w.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
	return t
