class_name AdminPanel
extends RefCounted
## Админ-панель для тестирования (Максим на своём телефоне): кнопка «Админ-панель» в окне «Настройки».
## Окно с вкладками (вкладка запоминается, прокрутка после нажатия сохраняется); закрывается кнопкой «Закрыть»,
## игра идёт и с открытой панелью. Всё — через обычные функции Game / Player / PetManager, изменения сохраняются
## в save.json сразу (Game.save_game) — как обычная игра (уровень, золото, предметы, питомцы, множитель опыта).
##   «Герой»: раса и пол на лету (Game.admin_set_look → модель hero_<раса>_<пол>.glb); профессия сразу — любая из 9
##     или Бродяга (Game.admin_set_job: умения прежней сбрасываются с возвратом JP, оружие выдаётся и надевается);
##     уровень 1…40 (−10/−1/+1/+10 и сразу 1/10/15/20/30/40; опыт обнуляется, JP не меняются), «До след. уровня»
##     (опыт до следующего уровня через Player.gain_xp — как обычный опыт, с долей JP); JP +10/+100/обнулить,
##     золото +100/+1000/+10000/обнулить; «Полное HP/MP»; «Бессмертие» (переключатель: Player.take_damage не
##     проходит, только на эту игру — не сохраняется); «Изучить все доступные», «Забыть все умения» (возврат JP;
##     стартовые умения профессии остаются, их цену не возвращаем); «Сбросить в Бродягу» (и задание мудреца
##     «Первая профессия» — пройти заново, проверить сверх-эволюцию).
##   «Опыт»: множитель опыта за зверей ×1/×2/×5/×10/×20/×50 (Game.xp_mult — в сохранении; герою и призванному
##     питомцу, main._on_mob_gone и PetManager.on_mob_killed; награды заданий не умножаются), опыт до следующего
##     уровня герою и питомцу.
##   «Предметы»: любой предмет ItemData +1/+10 (по группам: оружие, броня, украшения, расходники, кубы чарования,
##     карты существ, трофеи; кладётся столько, сколько поместится), заточка надетого оружия и брони −1/+1/до предела
##     кубами/сброс (Enchant.admin_set, этап 3), «Очистить сумку» с подтверждением (надетое оружие, щит, броня
##     и украшения остаются).
##   «Питомцы»: питомец любого вида (PetData, кроме ушедших с острова Game.RETIRED_PETS) 1, 15 или 30 ур. (1–3 стадия,
##     сразу призывается), уровень призванного −5/−1/+1/+5 (стадия и модель меняются), полное HP/MP питомца,
##     воскресить погибших (без свитка), «Отпустить всех» с подтверждением.
##   «Мир»: «Убить цель», «Убить всех вокруг (30 м)» (с опытом и добычей, как обычное убийство), «Возродить всех
##     зверей» (пустые слоты сразу, main._spawn_slot не ставит второго зверя в занятый слот); поставить зверя
##     любого вида MobData уровня N в 5 м перед героем (свой зверь, slot −1 — не возрождается); скорость бега героя
##     ×1/×2/×3 (только на эту игру); перенос в точку — постройки и места острова и зоны зверей из
##     world/training_island.json (свободная ровная точка рядом; деревни и город — точки старта рас).
## Выключить панель — ADMIN_TOOLS = false (кнопка в «Настройках» пропадёт, множитель опыта из сохранения — ×1).
## Панель есть только у аккаунта администратора — логин Dedok_max без учёта регистра (Accounts.is_admin, enabled());
## у других логинов кнопки нет, множитель опыта из сохранения — ×1. Автотесты входят тестовым аккаунтом Dedok_max
## (tests/test_base.gd, test_login).
## Кнопки открытого окна для тестов (buttons): вкладки "tab_<hero|xp|items|pets|world>";
##   «Герой»: "race_<id>", "gender_<f|m>", "job_<id>", "lvl_minus10", "lvl_minus", "lvl_plus", "lvl_plus10",
##     "lvl_set_<N>", "xp_next", "jp_plus10", "jp_plus100", "jp_zero", "gold_plus100", "gold_plus1000",
##     "gold_plus10000", "gold_zero", "full", "god", "learn_all", "forget_all", "reset_job";
##   «Опыт»: "xp_<N>", "xp_next", "pet_xp_next";
##   «Предметы»: "item_<id>_1", "item_<id>_10", "ench_<слот>_minus", "ench_<слот>_plus", "ench_<слот>_max",
##     "ench_<слот>_zero" (слот — InventoryWindow.WORN_SLOTS), "clear_bag", "clear_bag_yes", "clear_bag_no";
##   «Питомцы»: "pet_<вид>_<ур.>", "pet_lvl_minus5", "pet_lvl_minus", "pet_lvl_plus", "pet_lvl_plus5", "pet_full",
##     "pet_revive", "pets_clear", "pets_clear_yes", "pets_clear_no";
##   «Мир»: "kill_target", "kill_around", "respawn_all", "mob_lvl_minus5", "mob_lvl_minus", "mob_lvl_plus",
##     "mob_lvl_plus5", "mob_lvl_hero", "spawn_<вид>", "speed_<1|2|3>", "tp_poi_<id>", "tp_zone_<id>" (teleports()).

const ADMIN_TOOLS := true
## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(900, 600)
const MAX_LEVEL := 40
const NOTE := Color(1.0, 0.86, 0.55)
const MUTED := Color(0.75, 0.78, 0.9)
const INFO := Color(0.85, 0.88, 0.95)
## Задание на профессию (сбрасывается вместе с профессией, как и задания после неё — QuestData.JOB_RESET).
const JOB_QUEST := QuestData.JOB_QUEST
## Вкладки: [id, подпись].
const TABS := [["hero", "Герой"], ["xp", "Опыт"], ["items", "Предметы"], ["pets", "Питомцы"], ["world", "Мир"]]
const XP_MULTS := [1, 2, 5, 10, 20, 50]
const SPEED_MULTS := [1, 2, 3]
const LEVEL_PRESETS := [1, 10, 15, 20, 30, 40]
## Уровни нового питомца — начала стадий эволюции (PetData.STAGE_LEVELS).
const PET_LEVELS := [1, 15, 30]
## Группы предметов на вкладке «Предметы»: [тип ItemData, подпись]; прочие типы — «Прочее».
const ITEM_GROUPS := [["weapon", "Оружие"], ["armor", "Броня"], ["jewelry", "Украшения"], ["consumable", "Расходники"],
	["cube", "Кубы"], ["card", "Карты существ"], ["trophy", "Трофеи"]]
const KILL_RADIUS := 30.0
const MOB_MAX_LEVEL := 50
## Зверь админ-панели ставится в SPAWN_DIST м перед героем.
const SPAWN_DIST := 5.0
## Поиск свободной точки при переносе: до TP_SEARCH м от центра места.
const TP_SEARCH := 40.0

static var buttons: Dictionary = {}
## Открытая (последняя) вкладка.
static var tab := "hero"
## Бессмертие героя (Player.take_damage) и множитель скорости бега (Player.cur_speed) — только на эту игру.
static var god := false
static var speed_mult := 1
## Уровень зверя, которого ставит «Мир».
static var spawn_level := 5
## Ждёт подтверждения: "clear_bag" | "pets_clear" | "".
static var _confirm := ""
static var _scroll: ScrollContainer = null


## Доступна ли панель: ADMIN_TOOLS и вошёл администратор (Accounts.is_admin: логин Dedok_max).
static func enabled() -> bool:
	return ADMIN_TOOLS and Accounts.is_admin()


## Сбросить то, что действует «только на эту игру» (бессмертие, скорость бега), — при смене персонажа или аккаунта.
static func reset_session() -> void:
	god = false
	speed_mult = 1
	_confirm = ""


static func open(main: Node, which: String = "") -> void:
	if not enabled():
		return
	if main == null or not is_instance_valid(main) or main.get("hud") == null or main.get("player") == null:
		return
	# Перестройка той же вкладки — прокрутка остаётся на месте
	var keep := 0
	if (which == "" or which == tab) and _scroll_alive():
		keep = _scroll.scroll_vertical
	if which != "" and which != tab:
		tab = which
		_confirm = ""
	var hud: HUD = main.hud
	buttons.clear()
	var body := hud.create_window("Админ-панель (тест)", WINDOW_SIZE)
	_scroll = body.get_parent() as ScrollContainer
	_add_tabs(main, body)
	body.add_child(_text(_summary(main), UiScale.FONT_BODY, INFO))
	match tab:
		"xp":
			_build_xp(main, body)
		"items":
			_build_items(main, body)
		"pets":
			_build_pets(main, body)
		"world":
			_build_world(main, body)
		_:
			_build_hero(main, body)
	if keep > 0 and _scroll != null:
		# Прокрутку можно вернуть, когда содержимое разложено (в начале следующего кадра)
		var sc := _scroll
		var restore := func() -> void:
			if is_instance_valid(sc):
				sc.scroll_vertical = keep
		sc.get_tree().process_frame.connect(restore, CONNECT_ONE_SHOT)


## Открыта ли сейчас админ-панель.
static func is_open(main: Node) -> bool:
	return _scroll_alive() and main != null and is_instance_valid(main) and (main.hud as HUD).is_window_open()


static func _scroll_alive() -> bool:
	if not is_instance_valid(_scroll):
		return false
	var n: Node = _scroll
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return true


## Вкладки — над прокруткой (как в окне героя).
static func _add_tabs(main: Node, body: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	var root: Node = null
	if body.get_parent() != null:
		root = body.get_parent().get_parent()
	if root is VBoxContainer:
		root.add_child(bar)
		root.move_child(bar, 1)
	else:
		body.add_child(bar)
	for t in TABS:
		var id := String(t[0])
		var b := Button.new()
		b.text = String(t[1])
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = id == tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(UiScale.px(110), UiScale.px(UiScale.TAB_H))
		b.pressed.connect(func() -> void: AdminPanel.open(main, id))
		bar.add_child(b)
		buttons["tab_" + id] = b


static func _summary(main: Node) -> String:
	var p: Player = main.player
	var t := "%s · %s, %s · ур. %d · опыт %d/%d · JP %d · %d зол. · HP %d/%d · MP %d/%d" % [
		ClassData.job_name(Game.class_id), String(ClassData.race(Game.race_id)["name"]),
		ClassData.gender_name(Game.gender).to_lower(), Game.level, Game.xp, Game.xp_to_next(Game.level),
		int(Game.hero.get("jp", 0)), Game.gold, p.hp, p.max_hp, p.mp, p.max_mp]
	var flags: PackedStringArray = []
	if god:
		flags.append("бессмертие")
	if Game.xp_mult != 1:
		flags.append("опыт ×%d" % Game.xp_mult)
	if speed_mult != 1:
		flags.append("бег ×%d" % speed_mult)
	if not flags.is_empty():
		t += " · " + ", ".join(flags)
	return t


# ---------- Вкладка «Герой» ----------

static func _build_hero(main: Node, body: VBoxContainer) -> void:
	_head(body, "Раса и пол (модель меняется сразу)")
	var rr := _row(body)
	for rid in ClassData.RACES:
		var r := String(rid)
		_choice(rr, "race_" + r, String(ClassData.race(r)["name"]), r == Game.race_id,
			func() -> void: AdminPanel.set_look(main, r, Game.gender))
	for e in ClassData.GENDERS:
		var g := String(e[0])
		_choice(rr, "gender_" + g, String(e[1]), g == Game.gender, func() -> void: AdminPanel.set_look(main, Game.race_id, g))

	_head(body, "Профессия (сразу, без задания; умения прежней — сброс с возвратом JP, оружие выдаётся и надевается)")
	var grid := _grid(body, 5)
	for jid in ClassData.CLASSES:
		var j := String(jid)
		var label := ClassData.job_name(j)
		var race := ClassData.job_race(j)
		if race != "" and race != Game.race_id:
			label += " *"
		_choice(grid, "job_" + j, label, j == Game.class_id, func() -> void: AdminPanel.set_job(main, j))
	body.add_child(_text("* — профессия другой расы (для теста можно).", UiScale.FONT_SMALL, MUTED))

	_head(body, "Уровень %d (1…%d) · опыт %d / %d (опыт обнуляется, JP не меняются)" % [Game.level, MAX_LEVEL, Game.xp,
		Game.xp_to_next(Game.level)])
	var lr := _row(body)
	_btn(lr, "lvl_minus10", "−10", func() -> void: AdminPanel.set_level(main, Game.level - 10))
	_btn(lr, "lvl_minus", "−1", func() -> void: AdminPanel.set_level(main, Game.level - 1))
	_btn(lr, "lvl_plus", "+1", func() -> void: AdminPanel.set_level(main, Game.level + 1))
	_btn(lr, "lvl_plus10", "+10", func() -> void: AdminPanel.set_level(main, Game.level + 10))
	_btn(lr, "xp_next", "До след. уровня", func() -> void: AdminPanel.xp_next(main), 170.0)
	var pr := _row(body)
	for v in LEVEL_PRESETS:
		var lvl := int(v)
		_choice(pr, "lvl_set_%d" % lvl, "Ур. %d" % lvl, lvl == Game.level, func() -> void: AdminPanel.set_level(main, lvl))

	_head(body, "Очки умений: %d JP · золото: %d" % [int(Game.hero.get("jp", 0)), Game.gold])
	var jr := _row(body)
	_btn(jr, "jp_plus10", "+10 JP", func() -> void: AdminPanel.add_jp(main, 10))
	_btn(jr, "jp_plus100", "+100 JP", func() -> void: AdminPanel.add_jp(main, 100))
	_btn(jr, "jp_zero", "JP = 0", func() -> void: AdminPanel.zero_jp(main))
	var gr := _row(body)
	_btn(gr, "gold_plus100", "+100 зол.", func() -> void: AdminPanel.add_gold(main, 100))
	_btn(gr, "gold_plus1000", "+1000 зол.", func() -> void: AdminPanel.add_gold(main, 1000))
	_btn(gr, "gold_plus10000", "+10000 зол.", func() -> void: AdminPanel.add_gold(main, 10000))
	_btn(gr, "gold_zero", "Золото = 0", func() -> void: AdminPanel.zero_gold(main))

	_head(body, "Здоровье и умения")
	var hr := _row(body)
	_btn(hr, "full", "Полное HP/MP", func() -> void: AdminPanel.full(main))
	_choice(hr, "god", "Бессмертие: вкл." if god else "Бессмертие: выкл.", god, func() -> void: AdminPanel.set_god(main, not AdminPanel.god))
	var sr := _row(body)
	_btn(sr, "learn_all", "Изучить все доступные", func() -> void: AdminPanel.learn_all(main))
	_btn(sr, "forget_all", "Забыть все умения", func() -> void: AdminPanel.forget_all(main))
	_btn(sr, "reset_job", "Сбросить в Бродягу", func() -> void: AdminPanel.reset_job(main))
	body.add_child(_text("«Бессмертие» — урон по герою не проходит (до перезапуска игры). «Сбросить в Бродягу» заодно "
		+ "забывает задание мудреца «Первая профессия».", UiScale.FONT_SMALL, MUTED))


## Раса и пол героя: модель, деревня старта и возрождения.
static func set_look(main: Node, race: String, sex: String) -> void:
	Game.admin_set_look(race, sex)
	(main.player as Player).apply_class()
	_done(main, "Герой: %s, %s" % [String(ClassData.race(Game.race_id)["name"]), ClassData.gender_name(Game.gender).to_lower()])


## Профессия сразу (Game.admin_set_job).
static func set_job(main: Node, job: String) -> void:
	var back := Game.admin_set_job(job)
	(main.player as Player).apply_class()
	var t := "Профессия: %s" % ClassData.job_name(job)
	if back > 0:
		t += " (возвращено %d JP)" % back
	_done(main, t)


## Уровень героя ровно lvl (1…MAX_LEVEL), опыт — 0, HP и MP полные.
static func set_level(main: Node, lvl: int) -> void:
	Game.level = clampi(lvl, 1, MAX_LEVEL)
	Game.xp = 0
	_full_hero(main)
	_done(main, "Уровень героя: %d" % Game.level)


## Опыт до следующего уровня (как обычный опыт: новый уровень, доля JP).
static func xp_next(main: Node) -> void:
	if Game.level >= MAX_LEVEL:
		_done(main, "Уровень %d — наибольший для панели" % MAX_LEVEL)
		return
	var need := maxi(1, Game.xp_to_next(Game.level) - Game.xp)
	(main.player as Player).gain_xp(need)
	_done(main, "+%d оп.: уровень %d" % [need, Game.level])


static func add_jp(main: Node, n: int) -> void:
	Game.hero["jp"] = int(Game.hero.get("jp", 0)) + n
	_done(main, "+%d JP" % n)


static func zero_jp(main: Node) -> void:
	Game.hero["jp"] = 0
	Game.hero["jp_part"] = 0.0
	_done(main, "JP обнулены")


static func add_gold(main: Node, n: int) -> void:
	Game.gold += n
	_done(main, "+%d зол." % n)


static func zero_gold(main: Node) -> void:
	Game.gold = 0
	_done(main, "Золото обнулено")


static func full(main: Node) -> void:
	_full_hero(main)
	_done(main, "HP и MP полные")


static func set_god(main: Node, on: bool) -> void:
	god = on
	_done(main, "Бессмертие включено: урон по герою не проходит" if on else "Бессмертие выключено")


static func learn_all(main: Node) -> void:
	var n := HeroSkills.learn_all(Game.hero, Game.class_id, Game.level)
	(main.player as Player).refresh_skills()
	_done(main, "Изучено уровней умений: %d" % n)


## Забыть все умения профессии с возвратом JP. Стартовые умения (1-й уровень бесплатный) остаются изученными.
static func forget_all(main: Node) -> void:
	var back := HeroSkills.refund_all(Game.hero, Game.class_id)
	for id in HeroSkills.list_for(Game.class_id):
		var sid := String(id)
		if bool(HeroSkills.get_skill(sid, Game.class_id).get("start", false)):
			var c := HeroSkills.jp_cost(sid, 1, Game.class_id)
			back -= c
			Game.hero["jp"] = int(Game.hero["jp"]) - c
	(main.player as Player).apply_class()
	_done(main, "Умения забыты, возвращено %d JP" % back)


## Профессия — Бродяга; задание на профессию («Доклад мудрецу») и задания после неё можно пройти заново.
static func reset_job(main: Node) -> void:
	for k in QuestData.JOB_RESET:
		var qid := String(k)
		Game.quests_done.erase(qid)
		Game.quests_active.erase(qid)
		if Game.quest_tracked == qid:
			Game.quest_tracked = ""
	set_job(main, ClassData.WANDERER)
	if main.get("quests") != null:
		(main.quests as Quests).refresh_tracker()


static func _full_hero(main: Node) -> void:
	var p: Player = main.player
	p.recalc_stats()
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.stats_changed.emit()


# ---------- Вкладка «Опыт» ----------

static func _build_xp(main: Node, body: VBoxContainer) -> void:
	_head(body, "Множитель опыта за зверей: ×%d" % Game.xp_mult)
	var row := _row(body)
	for v in XP_MULTS:
		var n := int(v)
		_choice(row, "xp_%d" % n, "×%d" % n, n == Game.xp_mult, func() -> void: AdminPanel.set_xp_mult(main, n))
	body.add_child(_text("Опыт за каждого убитого зверя умножается — и герою, и призванному питомцу. Награды заданий "
		+ "не умножаются. Множитель хранится в сохранении (остаётся после перезапуска); ×1 — обычная игра.",
		UiScale.FONT_BODY, MUTED))
	_head(body, "Опыт сразу")
	body.add_child(_text("Герой: ур. %d, опыт %d / %d" % [Game.level, Game.xp, Game.xp_to_next(Game.level)],
		UiScale.FONT_TEXT, INFO))
	var pet := _pet(main)
	if pet != null:
		body.add_child(_text("Питомец «%s»: ур. %d, опыт %d / %d" % [pet.pet_name, pet.level, pet.xp,
			PetData.xp_to_next(pet.level)], UiScale.FONT_TEXT, INFO))
	else:
		body.add_child(_text("Призванного питомца нет.", UiScale.FONT_TEXT, MUTED))
	var xr := _row(body)
	_btn(xr, "xp_next", "Герою: до след. уровня", func() -> void: AdminPanel.xp_next(main), 220.0)
	_btn(xr, "pet_xp_next", "Питомцу: до след. уровня", func() -> void: AdminPanel.pet_xp_next(main), 220.0)


static func set_xp_mult(main: Node, n: int) -> void:
	Game.xp_mult = clampi(n, 1, int(XP_MULTS[XP_MULTS.size() - 1]))
	_done(main, "Множитель опыта: ×%d" % Game.xp_mult)


static func pet_xp_next(main: Node) -> void:
	var pet := _pet(main)
	if pet == null:
		_done(main, "Сначала призовите питомца")
		return
	if pet.level >= PetData.MAX_LEVEL:
		_done(main, "Уровень питомца — наибольший")
		return
	pet.gain_xp(maxi(1, PetData.xp_to_next(pet.level) - pet.xp))
	_done(main, "Питомец «%s»: уровень %d" % [pet.pet_name, pet.level])


# ---------- Вкладка «Предметы» ----------

static func _build_items(main: Node, body: VBoxContainer) -> void:
	_head(body, "Выдать предмет (кладётся столько, сколько поместится): занято %d/%d" % [Game.inventory.used_cells(),
		Inventory.CAPACITY])
	for g in item_groups():
		var grp: Array = g
		body.add_child(_text(String(grp[1]), UiScale.FONT_TEXT, Color(0.9, 0.92, 1.0)))
		var grid := _grid(body, 6)
		for id in grp[2]:
			var iid := String(id)
			var l := _text(ItemData.item_name(iid), UiScale.FONT_BODY, ItemData.frame_color(iid))
			l.custom_minimum_size = Vector2(UiScale.px(170), 0)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(l)
			_btn(grid, "item_%s_1" % iid, "+1", func() -> void: AdminPanel.give_item(main, iid, 1), 64.0)
			_btn(grid, "item_%s_10" % iid, "+10", func() -> void: AdminPanel.give_item(main, iid, 10), 64.0)
	_build_enchant(main, body)
	_head(body, "Очистить сумку")
	if _confirm == "clear_bag":
		body.add_child(_text("Удалить из сумки всё, кроме надетого (оружие, щит, броня, украшения)?", UiScale.FONT_TEXT, Color(1.0, 0.6, 0.55)))
		var cr := _row(body)
		_btn(cr, "clear_bag_yes", "Да, очистить", func() -> void: AdminPanel.clear_bag(main))
		_btn(cr, "clear_bag_no", "Отмена", func() -> void: AdminPanel.ask(main, ""))
	else:
		var r := _row(body)
		_btn(r, "clear_bag", "Очистить сумку…", func() -> void: AdminPanel.ask(main, "clear_bag"))


## Предметы по группам: [[тип, подпись, [id…]], …] (типы ITEM_GROUPS, затем «Прочее»).
static func item_groups() -> Array:
	var res: Array = []
	var known: Dictionary = {}
	for g in ITEM_GROUPS:
		known[String(g[0])] = true
		var ids: Array = []
		for id in ItemData.ITEMS:
			if ItemData.item_type(String(id)) == String(g[0]):
				ids.append(String(id))
		if not ids.is_empty():
			res.append([String(g[0]), String(g[1]), ids])
	var other: Array = []
	for id in ItemData.ITEMS:
		if not known.has(ItemData.item_type(String(id))):
			other.append(String(id))
	if not other.is_empty():
		res.append(["other", "Прочее", other])
	return res


static func give_item(main: Node, id: String, n: int) -> void:
	var k := Game.inventory.try_add(id, n)
	if k <= 0:
		_done(main, "Сумка полна")
	else:
		_done(main, "+%d: %s" % [k, ItemData.item_name(id)])


# ---------- «Предметы»: заточка надетого (этап 3; отдельный блок — Enchant) ----------

## Заточка надетого оружия и брони: по ячейке — вещь и «+N», −1 / +1 / до предела кубами / сброс.
static func _build_enchant(main: Node, body: VBoxContainer) -> void:
	_head(body, "Заточка надетого (чарование и закалка — одна шкала «+N»; предел — как у кубов)")
	var grid := _grid(body, 5)
	for s in InventoryWindow.WORN_SLOTS:
		var slot := String(s)
		var id := Enchant.equipped_in(slot)
		var cap := Enchant.cube_cap(id) if id != "" else 0
		var what := ItemData.item_name(id) if id != "" else "—"
		var l := _text("%s: %s" % [String(InventoryWindow.EQUIP_SLOTS[InventoryWindow.equip_index(slot)][1]), what],
			UiScale.FONT_BODY, ItemData.frame_color(id) if id != "" else MUTED)
		l.custom_minimum_size = Vector2(UiScale.px(220), 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		_btn(grid, "ench_%s_minus" % slot, "−1", func() -> void: AdminPanel.enchant_step(main, slot, -1), 56.0)
		_btn(grid, "ench_%s_plus" % slot, "+1", func() -> void: AdminPanel.enchant_step(main, slot, 1), 56.0)
		_btn(grid, "ench_%s_max" % slot, "+%d" % cap if cap > 0 else "Макс.", func() -> void: AdminPanel.enchant_set(main, slot, 99), 64.0)
		_btn(grid, "ench_%s_zero" % slot, "0", func() -> void: AdminPanel.enchant_set(main, slot, 0), 56.0)


## Заточка надетой вещи в ячейке slot на d (−1 / +1).
static func enchant_step(main: Node, slot: String, d: int) -> void:
	var id := Enchant.equipped_in(slot)
	if id == "" or not ItemData.is_enchantable(id):
		_done(main, "В ячейке нет оружия или брони")
		return
	enchant_set(main, slot, ItemData.enchant_level(id) + d)


## Заточка надетой вещи в ячейке slot — n (0…предел кубами: оружие 1-го ранга и броня +10, оружие 2-го ранга +20).
static func enchant_set(main: Node, slot: String, n: int) -> void:
	var id := Enchant.equipped_in(slot)
	if id == "" or not ItemData.is_enchantable(id):
		_done(main, "В ячейке нет оружия или брони")
		return
	var res := Enchant.admin_set(slot, n, main.get("player") as Node)
	_done(main, "Заточка: %s" % ItemData.item_name(res))


## Подтверждение опасного действия ("clear_bag" | "pets_clear"; "" — отмена).
static func ask(main: Node, what: String) -> void:
	_confirm = what
	if is_open(main):
		open(main)


## Сумка пустеет; надетое оружие обеих рук (щит или второй такой же клинок), броня и украшения остаются.
static func clear_bag(main: Node) -> void:
	_confirm = ""
	var keep: Dictionary = {}
	if Game.weapon != "" and Game.inventory.has(Game.weapon):
		keep[Game.weapon] = 1
	if Game.offhand != "" and Game.inventory.has(Game.offhand, int(keep.get(Game.offhand, 0)) + 1):
		keep[Game.offhand] = int(keep.get(Game.offhand, 0)) + 1
	for k in Game.equip:
		var gid := String(Game.equip[k])
		if gid != "":
			keep[gid] = int(keep.get(gid, 0)) + 1
	Game.inventory.from_dict(keep)
	_done(main, "Сумка очищена")


# ---------- Вкладка «Питомцы» ----------

static func _build_pets(main: Node, body: VBoxContainer) -> void:
	_head(body, "Добавить питомца (коллекция %d/%d; новый сразу призывается)" % [Game.pets.size(), Game.MAX_PETS])
	var grid := _grid(body, 4)
	for s in pet_species():
		var sp := String(s)
		var l := _text("%s — %s" % [String(MobData.get_type(sp).get("name", sp)), PetData.role_name(sp).to_lower()],
			UiScale.FONT_TEXT, INFO)
		l.custom_minimum_size = Vector2(UiScale.px(170), 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		for v in PET_LEVELS:
			var lvl := int(v)
			_btn(grid, "pet_%s_%d" % [sp, lvl], "Ур. %d (%d стадия)" % [lvl, PetData.stage_for(lvl) + 1],
				func() -> void: AdminPanel.add_pet(main, sp, lvl), 150.0)
	var pet := _pet(main)
	if pet != null:
		_head(body, "Призванный питомец: «%s», ур. %d, стадия %d, HP %d/%d" % [pet.pet_name, pet.level, pet.stage + 1,
			pet.hp, pet.max_hp])
	else:
		_head(body, "Призванного питомца нет (уровень меняется у призванного)")
	var lr := _row(body)
	_btn(lr, "pet_lvl_minus5", "Ур. −5", func() -> void: AdminPanel.pet_level(main, -5))
	_btn(lr, "pet_lvl_minus", "Ур. −1", func() -> void: AdminPanel.pet_level(main, -1))
	_btn(lr, "pet_lvl_plus", "Ур. +1", func() -> void: AdminPanel.pet_level(main, 1))
	_btn(lr, "pet_lvl_plus5", "Ур. +5", func() -> void: AdminPanel.pet_level(main, 5))
	var ar := _row(body)
	_btn(ar, "pet_full", "Полное HP/MP питомца", func() -> void: AdminPanel.pet_full(main))
	_btn(ar, "pet_revive", "Воскресить погибших", func() -> void: AdminPanel.pet_revive(main))
	if _confirm == "pets_clear":
		body.add_child(_text("Отпустить всех питомцев коллекции навсегда?", UiScale.FONT_TEXT, Color(1.0, 0.6, 0.55)))
		var cr := _row(body)
		_btn(cr, "pets_clear_yes", "Да, отпустить всех", func() -> void: AdminPanel.clear_pets(main))
		_btn(cr, "pets_clear_no", "Отмена", func() -> void: AdminPanel.ask(main, ""))
	else:
		_btn(ar, "pets_clear", "Отпустить всех…", func() -> void: AdminPanel.ask(main, "pets_clear"))


## Виды питомцев для панели: все PetData, кроме ушедших с острова (Game.RETIRED_PETS).
static func pet_species() -> Array:
	var res: Array = []
	for s in PetData.SPECIES:
		if not Game.RETIRED_PETS.has(String(s)):
			res.append(String(s))
	return res


## Новый питомец вида species уровня lvl в коллекцию и сразу призвать. Индекс или -1 (коллекция полна).
static func add_pet(main: Node, species: String, lvl: int) -> int:
	var i := Game.add_pet(species, PetData.stage_name(species, lvl), clampi(lvl, 1, PetData.MAX_LEVEL))
	if i < 0:
		_done(main, "Коллекция полна (%d) — отпустите питомцев" % Game.MAX_PETS)
		return -1
	if main.get("pets") != null:
		(main.pets as PetManager).summon(i)
	_done(main, "Питомец «%s» (ур. %d) добавлен и призван" % [String(Game.pets[i]["name"]), lvl])
	return i


## Уровень призванного питомца на delta (1…PetData.MAX_LEVEL).
static func pet_level(main: Node, delta: int) -> void:
	var pet := _pet(main)
	if pet == null:
		_done(main, "Сначала призовите питомца")
		return
	set_pet_level(main, pet.level + delta)


## Уровень призванного питомца ровно lvl: характеристики, имя-стадия, модель стадии; HP и MP полные, опыт — 0.
## При повышении — JP за уровни (как при обычном росте).
static func set_pet_level(main: Node, lvl: int) -> void:
	var pet := _pet(main)
	if pet == null:
		return
	var old := pet.level
	var old_stage := pet.stage
	pet.level = clampi(lvl, 1, PetData.MAX_LEVEL)
	pet.xp = 0
	if pet.level > old:
		pet.record["jp"] = int(pet.record.get("jp", 0)) + PetSkills.JP_PER_LEVEL * (pet.level - old)
	pet._apply_stats()
	pet.hp = pet.max_hp
	pet.mp = pet.max_mp
	pet.pet_name = PetData.stage_name(pet.species, pet.level)
	if pet.stage != old_stage:
		if pet.stage > old_stage:
			pet._evolve_fx()
		else:
			pet._build_model()
	pet._write_record()
	pet._update_label()
	pet.stats_changed.emit()
	_done(main, "Питомец «%s»: уровень %d" % [pet.pet_name, pet.level])


static func pet_full(main: Node) -> void:
	var pet := _pet(main)
	if pet == null:
		_done(main, "Сначала призовите питомца")
		return
	pet.hp = pet.max_hp
	pet.mp = pet.max_mp
	pet._write_record()
	pet.stats_changed.emit()
	_done(main, "Питомец «%s»: HP и MP полные" % pet.pet_name)


## Воскресить всех погибших питомцев (без свитка, полное HP); если никто не призван — призвать первого.
static func pet_revive(main: Node) -> void:
	var first := -1
	for i in Game.pets.size():
		var rec: Dictionary = Game.pets[i]
		if bool(rec.get("dead", false)):
			rec["dead"] = false
			rec["hp"] = -1
			rec["mp"] = -1
			if first < 0:
				first = i
	if first < 0:
		_done(main, "Погибших питомцев нет")
		return
	if Game.active_pet < 0 and main.get("pets") != null:
		(main.pets as PetManager).summon(first)
	_done(main, "Питомцы воскрешены")


static func clear_pets(main: Node) -> void:
	_confirm = ""
	Game.active_pet = -1
	Game.pets.clear()
	if main.get("pets") != null:
		(main.pets as PetManager)._sync()
	_done(main, "Все питомцы отпущены")


## Призванный живой питомец или null.
static func _pet(main: Node) -> Pet:
	var pm: Variant = main.get("pets")
	if pm == null:
		return null
	var v: Variant = (pm as PetManager).active_pet
	if not is_instance_valid(v):
		return null
	var pet := v as Pet
	if pet == null or pet.is_down:
		return null
	return pet


# ---------- Вкладка «Мир» ----------

static func _build_world(main: Node, body: VBoxContainer) -> void:
	_head(body, "Звери")
	var kr := _row(body)
	_btn(kr, "kill_target", "Убить цель", func() -> void: AdminPanel.kill_target(main))
	_btn(kr, "kill_around", "Убить всех вокруг (%d м)" % int(KILL_RADIUS), func() -> void: AdminPanel.kill_around(main), 200.0)
	_btn(kr, "respawn_all", "Возродить всех зверей", func() -> void: AdminPanel.respawn_all(main), 200.0)

	_head(body, "Поставить зверя рядом (в %d м перед героем): уровень %d" % [int(SPAWN_DIST), spawn_level])
	var lr := _row(body)
	_btn(lr, "mob_lvl_minus5", "Ур. −5", func() -> void: AdminPanel.set_spawn_level(main, AdminPanel.spawn_level - 5))
	_btn(lr, "mob_lvl_minus", "Ур. −1", func() -> void: AdminPanel.set_spawn_level(main, AdminPanel.spawn_level - 1))
	_btn(lr, "mob_lvl_plus", "Ур. +1", func() -> void: AdminPanel.set_spawn_level(main, AdminPanel.spawn_level + 1))
	_btn(lr, "mob_lvl_plus5", "Ур. +5", func() -> void: AdminPanel.set_spawn_level(main, AdminPanel.spawn_level + 5))
	_btn(lr, "mob_lvl_hero", "= мой ур.", func() -> void: AdminPanel.set_spawn_level(main, Game.level))
	var mg := _grid(body, 4)
	for t in MobData.TYPES:
		var tid := String(t)
		_btn(mg, "spawn_" + tid, String(MobData.get_type(tid)["name"]),
			func() -> void: AdminPanel.spawn_mob(main, tid, AdminPanel.spawn_level), 150.0)

	_head(body, "Скорость бега героя (только для теста, до перезапуска): ×%d" % speed_mult)
	var sr := _row(body)
	for v in SPEED_MULTS:
		var m := int(v)
		_choice(sr, "speed_%d" % m, "×%d" % m, m == speed_mult, func() -> void: AdminPanel.set_speed(main, m))

	_head(body, "Перенестись")
	var tg := _grid(body, 3)
	for e in teleports():
		var d: Dictionary = e
		var c: Vector2 = d["c"]
		var label := String(d["name"])
		_btn(tg, String(d["key"]), label, func() -> void: AdminPanel.teleport(main, c, label), 200.0)


## Убить цель героя (как обычное убийство: опыт, добыча, задания).
static func kill_target(main: Node) -> bool:
	var p: Player = main.player
	var v: Variant = p.current_target
	if not is_instance_valid(v) or (v as Mob) == null or (v as Mob).is_dead:
		_done(main, "Нет цели — выберите зверя")
		return false
	var m := v as Mob
	var nm := m.mob_name
	_kill(m, p)
	_done(main, "Убит: %s" % nm)
	return true


## Убить всех живых зверей в KILL_RADIUS м от героя. Возвращает, скольких.
static func kill_around(main: Node) -> int:
	var p: Player = main.player
	var list: Array = []
	for n in p.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and _flat_dist(m.global_position, p.global_position) <= KILL_RADIUS:
			list.append(m)
	for m in list:
		_kill(m as Mob, p)
	_done(main, "Убито зверей вокруг: %d" % list.size())
	return list.size()


static func _kill(m: Mob, p: Player) -> void:
	if m.is_dead:
		return
	m.hp = 1
	m.take_damage(maxi(999999, m.max_hp * 100), p)


## Возродить зверей во всех пустых слотах мира сразу (main._spawn_slot). Возвращает, скольких.
static func respawn_all(main: Node) -> int:
	var slots: Array = []
	var sv: Variant = main.get("_slots")
	if sv is Array:
		slots = sv
	var alive: Dictionary = {}
	for n in main.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead:
			alive[m.slot] = true
	var count := 0
	for i in slots.size():
		if not alive.has(i):
			main.call("_spawn_slot", i)
			count += 1
	_done(main, "Возрождено зверей: %d" % count)
	return count


static func set_spawn_level(main: Node, lvl: int) -> void:
	spawn_level = clampi(lvl, 1, MOB_MAX_LEVEL)
	if is_open(main):
		open(main)


## Поставить зверя вида type_id уровня lvl в SPAWN_DIST м перед героем (slot −1: после смерти не возрождается).
static func spawn_mob(main: Node, type_id: String, lvl: int) -> Mob:
	if not MobData.TYPES.has(type_id):
		return null
	var p: Player = main.player
	var w := IslandWorld.current
	var base := p.global_position
	var fwd := p._forward()
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var pos := base + fwd * SPAWN_DIST
	if w != null:
		pos = w.ground(pos.x, pos.z)
		for k in 12:
			var q := base + fwd.rotated(Vector3.UP, TAU * float(k) / 12.0) * SPAWN_DIST
			if w.is_walkable(q.x, q.z):
				pos = w.ground(q.x, q.z)
				break
	# Общая функция спауна главной сцены (main.spawn_mob: звери и боссы; slot −1 — не возрождается)
	var m: Mob = null
	if main.has_method("spawn_mob"):
		m = main.call("spawn_mob", type_id, clampi(lvl, 1, MOB_MAX_LEVEL), pos, -1) as Mob
	else:
		m = Mob.new()
		m.setup(type_id, -1, pos, clampi(lvl, 1, MOB_MAX_LEVEL))
		main.add_child(m)
	_done(main, "Зверь: %s, ур. %d" % [m.mob_name, m.level])
	return m


static func set_speed(main: Node, m: int) -> void:
	speed_mult = clampi(m, 1, int(SPEED_MULTS[SPEED_MULTS.size() - 1]))
	(main.player as Player).stats_changed.emit()
	_done(main, "Скорость бега: ×%d" % speed_mult)


## Места для переноса из конфига острова: [{"key", "name", "c": Vector2}] — постройки и места (POI с радиусом;
## город и деревни рас — точки старта) и зоны зверей (с уровнями).
static func teleports() -> Array:
	var res: Array = []
	var w := IslandWorld.current
	if w == null:
		return res
	var sp: Dictionary = w.cfg.get("spawn_points", {})
	var names: Dictionary = {}
	for e in w.cfg.get("pois", []):
		var d: Dictionary = e
		if not d.has("radius") or not d.has("center"):
			continue
		var id := String(d.get("id", ""))
		var t := String(d.get("type", ""))
		var c := IslandWorld.v2(d["center"])
		if t == "town" and sp.has("default"):
			c = IslandWorld.v2(sp["default"])
		elif t.ends_with("_village") and sp.has(t.trim_suffix("_village")):
			c = IslandWorld.v2(sp[t.trim_suffix("_village")])
		var nm := String(d.get("name", id))
		names[nm] = int(names.get(nm, 0)) + 1
		res.append({"key": "tp_poi_" + id, "name": nm, "c": c})
	# Одинаковые названия (лагеря) — с координатами
	for r in res:
		var d: Dictionary = r
		if int(names.get(String(d["name"]), 0)) > 1:
			var c: Vector2 = d["c"]
			d["name"] = "%s (%d, %d)" % [String(d["name"]), roundi(c.x), roundi(c.y)]
	for e in w.cfg.get("mob_zones", []):
		var z: Dictionary = e
		var lv: Array = z.get("levels", [1, 1])
		var id := String(z.get("id", ""))
		res.append({"key": "tp_zone_" + id, "name": "%s\nзвери %d–%d ур." % [String(z.get("name", id)), int(lv[0]),
			int(lv[lv.size() - 1])], "c": IslandWorld.v2(z["center"])})
	return res


## Перенести героя (и призванного питомца) к точке c: свободное ровное место рядом. Возвращает, куда.
static func teleport(main: Node, c: Vector2, label: String = "") -> Vector3:
	var p: Player = main.player
	var w := IslandWorld.current
	var pos := Vector3(c.x, p.global_position.y, c.y)
	if w != null:
		pos = free_spot(w, c)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var pet := _pet(main)
	if pet != null and w != null:
		pet.global_position = w.ground(pos.x + 1.5, pos.z + 1.5, 0.2)
	var cam: Variant = main.get("cam")
	if cam is Camera3D and main.has_method("_cam_offset"):
		var off: Vector3 = main.call("_cam_offset")
		(cam as Camera3D).global_position = pos + off
	_done(main, "Перенос: %s" % label.replace("\n", ", ") if label != "" else "Перенос")
	return pos


## Свободная ровная точка рядом с c (не в постройке, не в воде, не на крутом склоне): по кольцам до TP_SEARCH м.
static func free_spot(w: IslandWorld, c: Vector2) -> Vector3:
	for pass_i in 2:
		var r := 0.0
		while r <= TP_SEARCH:
			var steps := 1 if r == 0.0 else 16
			for k in steps:
				var a := TAU * float(k) / float(steps)
				var q := c + Vector2(cos(a), sin(a)) * r
				var ok := Npcs.spot_ok(w, q, [], 0.0, 0.6) if pass_i == 0 else w.is_walkable(q.x, q.y)
				if ok:
					return w.ground(q.x, q.y, 0.2)
			r += 1.5
	return w.ground(c.x, c.y, 0.2)


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- Общее ----------

## После изменения: Game.changed (HUD, задания), сохранение, сообщение, окно заново (если открыто).
static func _done(main: Node, msg: String) -> void:
	Game.changed.emit()
	Game.save_game()
	if main.get("hud") != null:
		(main.hud as HUD).show_message(msg)
	if is_open(main):
		open(main)


static func _head(body: VBoxContainer, t: String) -> void:
	body.add_child(_text(t, UiScale.FONT_TEXT, NOTE))


static func _row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	body.add_child(row)
	return row


static func _grid(body: VBoxContainer, columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", int(UiScale.px(6)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(6)))
	body.add_child(grid)
	return grid


## Кнопка выбора (нажатая — текущий вариант).
static func _choice(parent: Control, key: String, text: String, on: bool, cb: Callable) -> void:
	var b := _make(parent, key, text, cb, 100.0)
	b.toggle_mode = true
	b.button_pressed = on


## Кнопка действия; min_w — наименьшая ширина для «Среднего» размера интерфейса.
static func _btn(parent: Control, key: String, text: String, cb: Callable, min_w: float = 100.0) -> void:
	_make(parent, key, text, cb, min_w)


static func _make(parent: Control, key: String, text: String, cb: Callable, min_w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UiScale.px(min_w), UiScale.button_h())
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_BODY))
	b.pressed.connect(cb)
	parent.add_child(b)
	buttons[key] = b
	return b


static func _text(t: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
