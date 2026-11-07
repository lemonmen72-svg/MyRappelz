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
##   «Питомцы»: питомец любого вида (PetData, кроме ушедших с острова Game.RETIRED_PETS) 1 / 30 ур., 2-я форма на
##     60 ур., 3-я на 115 (сразу призывается), уровень призванного −10/−5/−1/+1/+5/+10 и сразу 1/30/50/60/100/115
##     (форма не меняется), «Эволюция» по правилам Кирка, «Вернуть 1-ю форму», опыт до следующего уровня, полное
##     HP/MP питомца, воскресить погибших (без свитка), «Отпустить всех» с подтверждением.
##   «Мир»: «Убить цель», «Убить всех вокруг (30 м)» (с опытом и добычей, как обычное убийство), «Возродить всех
##     зверей» (пустые слоты сразу, main._spawn_slot не ставит второго зверя в занятый слот); поставить зверя
##     любого вида MobData уровня N в 5 м перед героем (свой зверь, slot −1 — не возрождается); скорость бега героя
##     ×1/×2/×3 (только на эту игру); перенос в точку — постройки и места острова и зоны зверей из
##     world/training_island.json (свободная ровная точка рядом; деревни и город — точки старта рас).
##     «Редактор объектов подземелья» (DungeonEditor, только в подземелье), «Отправить файл» раскладки, «Сбросить».
##   «Тест-бот» (TestBot, папка bot/): режим («Производительность», «Быстрый», «Полный», «По разделам» — с выбором
##     разделов переключателями, выбор запоминается),
##     «Начать» (бот играет отдельным тестовым героем в своём хранилище — сохранения игрока не трогает; по окончании
##     игрок возвращается в свой аккаунт и слот), «Стоп», состояние, «Открыть отчёт», «Поделиться».
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
##   «Питомцы»: "pet_<вид>_<ур.>", "pet_lvl_minus10", "pet_lvl_minus5", "pet_lvl_minus", "pet_lvl_plus", "pet_lvl_plus5",
##     "pet_lvl_plus10", "pet_lvl_<1|30|50|60|100|115>", "pet_evolve", "pet_devolve", "pet_xp_up", "pet_full",
##     "pet_revive", "pets_clear", "pets_clear_yes", "pets_clear_no";
##   «Мир»: "time_<0|5|6|9|12|17|18|21>", "time_speed_<1|10|60>", "time_freeze", "time_reset", "weather_auto",
##     "weather_<clear|cloudy|rain|storm|mist>" (время и погода — WorldClock, Weather; на эту игру),
##     "kill_target", "kill_around", "respawn_all", "mob_lvl_minus5", "mob_lvl_minus", "mob_lvl_plus",
##     "mob_lvl_plus5", "mob_lvl_hero", "spawn_<вид>", "speed_<1|2|3>", "loc_island", "loc_dungeon" (go_location),
##     "editor_start", "editor_share", "editor_reset", "editor_reset_yes", "editor_reset_no" (DungeonEditor), "tp_poi_<id>", "tp_zone_<id>" (teleports());
##   «Тест-бот»: "bot_mode_<id>" (BotScenario.MODES; «скоро» — недоступны), "bot_sec_<раздел>" (режим «По разделам»:
##     переключатели разделов BotSection.SECTIONS), "bot_start", "bot_stop", "bot_open", "bot_share",
##     "bot_resume" / "bot_forget" (прерванный запуск долгого режима — контрольная точка TestBot.read_checkpoint),
##     «Кардинал: профили игроков»: "bot_prof_<профиль>", "bot_seg_<elder|job|post>", "bot_seeds_<1|3|5>",
##     "bot_race_<раса>", "bot_job_<профессия>", "bot_paccel_<8|16|32>" (BotScenarioCardinalProfiles),
##     "anim_system", "anim_combat_idle" (система анимаций 1.0 и боевая стойка — выключатели отката),
##     "vfx_new" (эффекты умений генератора VFX — SkillVfx.enabled).

const ADMIN_TOOLS := true
## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(900, 600)
const MAX_LEVEL := 40
const NOTE := Color(1.0, 0.86, 0.55)
const MUTED := Color(0.75, 0.78, 0.9)
const INFO := Color(0.85, 0.88, 0.95)
const BAD := Color(1.0, 0.5, 0.45)
## Задание на профессию (сбрасывается вместе с профессией, как и задания после неё — QuestData.JOB_RESET).
const JOB_QUEST := QuestData.JOB_QUEST
## Вкладки: [id, подпись].
const TABS := [["hero", "Герой"], ["xp", "Опыт"], ["items", "Предметы"], ["pets", "Питомцы"], ["world", "Мир"],
	["bot", "Тест-бот"], ["reports", "Отчёты"], ["suggest", "Предложения"]]
const XP_MULTS := [1, 2, 5, 10, 20, 50]
const SPEED_MULTS := [1, 2, 3]
const LEVEL_PRESETS := [1, 10, 15, 20, 30, 40]
## Новый питомец: [уровень, стадия] — 1 ур., 30 ур., 2-я форма на 60 ур. и 3-я на 115 (со сверх-эволюцией).
const PET_LEVELS := [[1, 0], [30, 0], [60, 1], [115, 2]]
## Уровень призванного питомца сразу: пороги эволюции и сверх-эволюции.
const PET_LEVEL_PRESETS := [1, 30, 50, 60, 100, 115]
## Группы предметов на вкладке «Предметы»: [тип ItemData, подпись]; прочие типы — «Прочее».
const ITEM_GROUPS := [["weapon", "Оружие"], ["armor", "Броня"], ["jewelry", "Украшения"], ["bag", "Торбы"], ["consumable", "Расходники"],
	["cube", "Кубы"], ["upgrade", "Прокачка"], ["card", "Карты существ"], ["trophy", "Трофеи"],
	["document", "Документы"]]
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
## Режим тест-бота на вкладке «Тест-бот» (BotScenario.MODES).
static var bot_mode := "perf"
## Ждёт подтверждения: "clear_bag" | "pets_clear" | "editor_reset" | "".
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
		"bot":
			_build_bot(main, body)
		"reports":
			_build_reports(main, body)
		"suggest":
			_build_suggest(main, body)
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
		b.custom_minimum_size = Vector2(UiScale.px(96), UiScale.px(UiScale.TAB_H))
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


## Система анимаций и боевая стойка (AnimResolver.enabled, combat_idle): выкл. — прежний выбор клипов (откат).
static func set_anim(main: Node, on: bool, combat: bool) -> void:
	AnimResolver.enabled = on
	AnimResolver.combat_idle = combat
	_done(main, "Система анимаций %s, боевая стойка %s" % ["включена" if on else "выключена (прежний выбор клипов)",
		"включена" if combat else "выключена"])


static func set_vfx(main: Node, on: bool) -> void:
	SkillVfx.enabled = on
	_done(main, "Новые эффекты умений %s" % ("включены" if on else "выключены (прежние вспышки)"))


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
		Game.inventory.capacity])
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
			var lvl := int(v[0])
			var stg := int(v[1])
			_btn(grid, "pet_%s_%d" % [sp, lvl], "Ур. %d (%d форма)" % [lvl, stg + 1],
				func() -> void: AdminPanel.add_pet(main, sp, lvl, stg), 150.0)
	var pet := _pet(main)
	if pet != null:
		_head(body, "Призванный питомец: «%s», ур. %d, стадия %d, HP %d/%d" % [pet.pet_name, pet.level, pet.stage + 1,
			pet.hp, pet.max_hp])
	else:
		_head(body, "Призванного питомца нет (уровень меняется у призванного)")
	var lr := _row(body)
	_btn(lr, "pet_lvl_minus10", "Ур. −10", func() -> void: AdminPanel.pet_level(main, -10))
	_btn(lr, "pet_lvl_minus5", "Ур. −5", func() -> void: AdminPanel.pet_level(main, -5))
	_btn(lr, "pet_lvl_minus", "Ур. −1", func() -> void: AdminPanel.pet_level(main, -1))
	_btn(lr, "pet_lvl_plus", "Ур. +1", func() -> void: AdminPanel.pet_level(main, 1))
	_btn(lr, "pet_lvl_plus5", "Ур. +5", func() -> void: AdminPanel.pet_level(main, 5))
	_btn(lr, "pet_lvl_plus10", "Ур. +10", func() -> void: AdminPanel.pet_level(main, 10))
	var pr := _row(body)
	for v in PET_LEVEL_PRESETS:
		var pl := int(v)
		_btn(pr, "pet_lvl_%d" % pl, "Ур. %d" % pl, func() -> void: AdminPanel.set_pet_level(main, pl))
	var er := _row(body)
	_btn(er, "pet_evolve", "Эволюция (как у Кирка)", func() -> void: AdminPanel.pet_evolve(main))
	_btn(er, "pet_devolve", "Вернуть 1-ю форму", func() -> void: AdminPanel.pet_devolve(main))
	_btn(er, "pet_xp_up", "Опыт до след. уровня", func() -> void: AdminPanel.pet_xp_next(main))
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
static func add_pet(main: Node, species: String, lvl: int, stage: int = 0) -> int:
	var st := clampi(stage, 0, PetData.STAGES.size() - 1)
	var i := Game.add_pet(species, PetData.stage_name(species, st), clampi(lvl, 1, PetData.MAX_LEVEL))
	if i < 0:
		_done(main, "Коллекция полна (%d) — отпустите питомцев" % Game.MAX_PETS)
		return -1
	# Форма сразу: эволюции на уровнях сверх-эволюции (не выше уровня питомца)
	var evo: Array = []
	for k in st:
		evo.append(mini(int(PetData.SUPER_LEVELS[k]), int(Game.pets[i]["level"])))
	Game.pets[i]["stage"] = st
	Game.pets[i]["evo"] = evo
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
	pet.level = clampi(lvl, 1, PetData.MAX_LEVEL)
	pet.xp = 0
	if pet.level > old:
		pet.record["jp"] = int(pet.record.get("jp", 0)) + PetSkills.JP_PER_LEVEL * (pet.level - old)
	pet._apply_stats()
	pet.hp = pet.max_hp
	pet.mp = pet.max_mp
	pet._write_record()
	pet._update_label()
	pet.stats_changed.emit()
	_done(main, "Питомец «%s»: уровень %d" % [pet.pet_name, pet.level])


## Эволюция призванного питомца по правилам Учителя Кирка (Pet.evolve).
static func pet_evolve(main: Node) -> void:
	var pet := _pet(main)
	if pet == null:
		_done(main, "Сначала призовите питомца")
		return
	var why := pet.evolve()
	_done(main, why if why != "" else "Питомец «%s»: %d форма" % [pet.pet_name, pet.stage + 1])


## Вернуть призванного питомца в 1-ю форму (проверить эволюцию заново).
static func pet_devolve(main: Node) -> void:
	var pet := _pet(main)
	if pet == null:
		_done(main, "Сначала призовите питомца")
		return
	pet.record["stage"] = 0
	pet.record["evo"] = []
	pet._apply_stats()
	pet.hp = pet.max_hp
	pet.mp = pet.max_mp
	pet.pet_name = PetData.stage_name(pet.species, 0)
	pet._build_model()
	pet._write_record()
	pet._update_label()
	pet.stats_changed.emit()
	_done(main, "Питомец «%s»: 1-я форма" % pet.pet_name)


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
	# Время и погода (0.46, атмосфера): час, скорость времени, своя погода — только на эту игру
	_head(body, "Время и погода: " + Atmosphere.status_text())
	body.add_child(_text("Сутки — 24 минуты (минута — час), время и погода у всех игроков одни и те же. Здесь — "
		+ "своё только на эту игру: поставить час, ускорить время, выбрать погоду.", UiScale.FONT_SMALL, MUTED))
	var tr := _row(body)
	for hh in [0, 5, 6, 9, 12, 17, 18, 21]:
		var h := int(hh)
		_btn(tr, "time_%d" % h, "%02d:00" % h, func() -> void: AdminPanel.set_time(main, float(h)), 70.0)
	var sr2 := _row(body)
	for v in [1, 10, 60]:
		var sp := int(v)
		_choice(sr2, "time_speed_%d" % sp, "Время ×%d" % sp, not WorldClock.frozen and roundi(WorldClock.speed) == sp,
			func() -> void: AdminPanel.set_time_speed(main, float(sp)))
	_choice(sr2, "time_freeze", "Остановить", WorldClock.frozen, func() -> void: AdminPanel.toggle_time_freeze(main))
	_btn(sr2, "time_reset", "Как у всех", func() -> void: AdminPanel.reset_time(main), 120.0)
	var wg := _grid(body, 3)
	_choice(wg, "weather_auto", "Погода по расписанию", Weather.force == "", func() -> void: AdminPanel.set_weather(main, ""))
	for wid in Weather.ORDER:
		var ww := String(wid)
		_choice(wg, "weather_" + ww, Weather.state_name(ww), Weather.force == ww, func() -> void: AdminPanel.set_weather(main, ww))
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

	_head(body, "Локация (подземелье — без проверки уровня и задания)")
	var lc := _row(body)
	var here := IslandWorld.current.location() if IslandWorld.current != null else "island"
	_choice(lc, "loc_island", "Остров", here == "island", func() -> void: AdminPanel.go_location(main, "island"))
	_choice(lc, "loc_dungeon", "Подземелье", here == "dungeon", func() -> void: AdminPanel.go_location(main, "dungeon"))

	_head(body, "Редактор объектов подземелья (сами ставите, двигаете, крутите; файл — «Отправить»)")
	var er := _row(body)
	_btn(er, "editor_start", "Открыть редактор", func() -> void: AdminPanel.editor_start(main), 180.0)
	_btn(er, "editor_share", "Отправить файл", func() -> void: AdminPanel._done(main, DungeonEditor.share_file()), 160.0)
	if _confirm == "editor_reset":
		_btn(er, "editor_reset_yes", "Да, сбросить", func() -> void: AdminPanel.editor_reset(main), 140.0)
		_btn(er, "editor_reset_no", "Отмена", func() -> void: AdminPanel.ask(main, ""), 110.0)
	else:
		_btn(er, "editor_reset", "Сбросить мою раскладку…", func() -> void: AdminPanel.ask(main, "editor_reset"), 200.0)
	(buttons["editor_start"] as Button).disabled = here != "dungeon"
	(buttons["editor_share"] as Button).disabled = not DungeonEditor.has_file()
	var ef := DungeonEditor.read_file()
	var ftxt := "Своей раскладки нет — встроенная."
	if not ef.is_empty():
		var stale := here == "dungeon" and int(ef.get("layout_version", -1)) != DungeonEditor.layout_version(IslandWorld.current)
		ftxt = "Ваша раскладка: %d объектов, сохранена %s%s." % [int(ef.get("count", 0)), String(ef.get("saved", "?")),
			" — от прежней раскладки, не действует" if stale else ""]
	body.add_child(_text(ftxt + (" Редактор — только в подземелье." if here != "dungeon" else ""), UiScale.FONT_SMALL, MUTED))

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
		if m != null and not m.is_dead and m.get_parent() == main:
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


## Перейти в локацию to ("island" / "dungeon") без проверок портала: герой встаёт у портала локации.
static func go_location(main: Node, to: String) -> void:
	if IslandWorld.current != null and IslandWorld.current.location() == to:
		return
	main.hud.close_window()
	main.travel(to)


## Редактор объектов подземелья (DungeonEditor): окно закрывается, справа — панель редактора.
static func editor_start(main: Node) -> DungeonEditor:
	main.hud.close_window()
	return DungeonEditor.start(main)


## Своя раскладка удаляется — при следующем входе в подземелье встроенная (сцена заново, если вы в подземелье).
static func editor_reset(main: Node) -> void:
	_confirm = ""
	DungeonEditor.reset_file()
	_done(main, "Раскладка сброшена на встроенную")
	if IslandWorld.current is DungeonWorld:
		main.hud.close_window()
		var p: Node3D = main.get("player")
		DungeonEditor.return_pos = p.global_position if p != null else Vector3.ZERO
		DungeonEditor.return_yaw = float(main.get("cam_yaw"))
		Game.arrive = "editor"
		main.call("restart_scene")


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


# ---------- Вкладка «Тест-бот» ----------

static func _build_bot(main: Node, body: VBoxContainer) -> void:
	body.add_child(_text("Бот играет отдельным тестовым героем в своём хранилище — ваш герой и сохранения не меняются, "
		+ "по окончании вы вернётесь к своему герою. Отчёт — в Загрузки/DarkPact_test (.zip и .txt), история и сравнение "
		+ "запусков — вкладка «Отчёты», что посмотреть по итогам — «Предложения». При нагреве бот сам уходит на паузу "
		+ "«остывание», при сильном — останавливается. Что какой режим и тест проверяет — ниже и в docs/TESTS.md.",
		UiScale.FONT_SMALL, MUTED))
	for g in BotScenario.MODE_GROUPS:
		var gid := String(g[0])
		_head(body, String(g[1]))
		body.add_child(_text(String(g[2]), UiScale.FONT_SMALL, MUTED))
		var gg := _grid(body, 3)
		for e in BotScenario.modes_in(gid):
			var md: Dictionary = e
			var mid := String(md["id"])
			var avail := bool(md.get("ready", false))
			var label := String(md["name"])
			if not avail:
				label += " — скоро"
			_choice(gg, "bot_mode_" + mid, label, mid == bot_mode, func() -> void: AdminPanel.set_bot_mode(main, mid))
			(buttons["bot_mode_" + mid] as Button).disabled = not avail
	_build_bot_mode_info(main, body)
	if bot_mode == "sections":
		_build_bot_sections(main, body)
	elif bot_mode == "cardinal_story":
		_build_bot_accel(main, body)
	elif bot_mode == "cardinal_profiles":
		_build_bot_profiles(main, body)
	elif bot_mode.begins_with("autotests"):
		_build_bot_tests(main, body)
	var running := TestBot.is_running()
	_head(body, "Состояние: " + TestBot.status_text())
	var r := _row(body)
	_btn(r, "bot_start", "Начать", func() -> void: AdminPanel.bot_start(main), 140.0)
	_btn(r, "bot_stop", "Стоп", func() -> void: AdminPanel.bot_stop(main), 140.0)
	var block := start_block()
	(buttons["bot_start"] as Button).disabled = running or block != ""
	(buttons["bot_stop"] as Button).disabled = not running
	if block != "" and not running:
		body.add_child(_text("Начать нельзя: " + block, UiScale.FONT_SMALL, BAD))
	# Прерванный запуск долгого режима (контрольная точка): «Продолжить» — с того же места, «Забыть»
	var cp := TestBot.read_checkpoint()
	if bool(cp.get("exists", false)) and not running:
		_head(body, "Прерванный запуск")
		var cp_ok := bool(cp.get("ok", false))
		if cp_ok:
			body.add_child(_text("«%s»: %s, записана %s. «Продолжить» — с того же места, готовое не повторяется." % [
				String(cp.get("title", "")), String(cp.get("progress", "")), String(cp.get("saved", ""))], UiScale.FONT_SMALL,
				INFO))
		else:
			body.add_child(_text("Контрольная точка «%s» не подходит: %s." % [String(cp.get("title", "?")),
				String(cp.get("error", ""))], UiScale.FONT_SMALL, BAD))
		var r5 := _row(body)
		_btn(r5, "bot_resume", "Продолжить", func() -> void: AdminPanel.bot_resume(main), 160.0)
		_btn(r5, "bot_forget", "Забыть", func() -> void: AdminPanel.bot_forget(main), 160.0)
		(buttons["bot_resume"] as Button).disabled = not cp_ok
	var last := TestBot.last_result()
	_head(body, "Последний отчёт")
	var where := String(last.get("public", ""))
	if where == "" and not last.is_empty():
		var f := String(last.get("zip", ""))
		if f == "":
			f = String(last.get("txt", ""))
		where = ProjectSettings.globalize_path(f) if f != "" else ""
	body.add_child(_text(where if where != "" else "Отчётов ещё нет.", UiScale.FONT_SMALL, INFO))
	var r2 := _row(body)
	_btn(r2, "bot_open", "Открыть отчёт", func() -> void: AdminPanel.bot_report(main, false), 160.0)
	_btn(r2, "bot_share", "Поделиться", func() -> void: AdminPanel.bot_report(main, true), 160.0)
	(buttons["bot_open"] as Button).disabled = last.is_empty()
	(buttons["bot_share"] as Button).disabled = last.is_empty()
	# Откат новых систем на прежние — только до перезапуска игры
	_head(body, "Откат систем (до перезапуска)")
	body.add_child(_text("Решения выбора клипов: " + AnimResolver.summary_line(), UiScale.FONT_SMALL, INFO))
	var r3 := _row(body)
	_choice(r3, "anim_system", "Система анимаций: вкл." if AnimResolver.enabled else "Система анимаций: выкл.",
		AnimResolver.enabled, func() -> void: AdminPanel.set_anim(main, not AnimResolver.enabled, AnimResolver.combat_idle))
	_choice(r3, "anim_combat_idle", "Боевая стойка: вкл." if AnimResolver.combat_idle else "Боевая стойка: выкл.",
		AnimResolver.combat_idle, func() -> void: AdminPanel.set_anim(main, AnimResolver.enabled, not AnimResolver.combat_idle))
	var r4 := _row(body)
	_choice(r4, "vfx_new", "Новые эффекты умений: вкл." if SkillVfx.enabled else "Новые эффекты умений: выкл.",
		SkillVfx.enabled, func() -> void: AdminPanel.set_vfx(main, not SkillVfx.enabled))


## Почему выбранный режим не начать ("" — можно).
static func start_block() -> String:
	match bot_mode:
		"sections":
			return "выберите хотя бы один раздел" if BotScenarioGame.chosen().is_empty() else ""
		"autotests_groups":
			return BotScenarioAutotests.groups_block()
		"cardinal_profiles":
			return BotScenarioCardinalProfiles.validate()
	return ""


## Выбранный режим: что проверяет, когда запускать, сколько идёт.
static func _build_bot_mode_info(_main: Node, body: VBoxContainer) -> void:
	var m := BotScenario.mode(bot_mode)
	if m.is_empty():
		return
	_head(body, "Выбрано: " + String(m["name"]))
	body.add_child(_text("Что проверяет: " + String(m.get("about", "")), UiScale.FONT_SMALL, INFO))
	body.add_child(_text("Когда запускать: " + String(m.get("when", "")), UiScale.FONT_SMALL, INFO))
	var t := "до %d мин" % int(m.get("minutes", 12))
	if bot_mode == "sections":
		t = "примерно %s (по выбранным разделам)" % TestBot.clock(BotScenarioGame.estimate(BotScenarioGame.chosen()))
	elif bot_mode == "autotests_groups":
		t = "примерно %s (по выбранным группам)" % TestBot.clock(BotScenarioAutotests.estimate(
			BotScenarioAutotests.group_tests(BotScenarioAutotests.groups())))
	body.add_child(_text("Сколько идёт: " + t, UiScale.FONT_SMALL, INFO))


## Автотесты: какие тесты пойдут (по группам каталога, с названиями); «по группам» — переключатели групп и что
## проверяет каждый тест выбранных групп.
static func _build_bot_tests(main: Node, body: VBoxContainer) -> void:
	if bot_mode == "autotests_groups":
		var cur := BotScenarioAutotests.groups()
		_head(body, "Группы тестов (выбрано %d)" % cur.size())
		var g := _grid(body, 3)
		for gid in TestCatalog.group_ids():
			var n := BotScenarioAutotests.group_tests(PackedStringArray([gid])).size()
			var gg := String(gid)
			_choice(g, "bot_tgrp_" + gg, "%s · %d" % [TestCatalog.group_name(gg), n], cur.has(gg),
				func() -> void: AdminPanel.toggle_test_group(main, gg))
		for gid in cur:
			_head(body, TestCatalog.group_name(String(gid)))
			for n in TestCatalog.in_group(String(gid)):
				var why := TestCatalog.ci_only(String(n))
				body.add_child(_text("• %s — %s%s" % [TestCatalog.title(String(n)), TestCatalog.what(String(n)),
					" (только CI — на телефоне пропуск)" if why != "" else ""], UiScale.FONT_SMALL, MUTED if why != "" else INFO))
		return
	var names := (BotScenario.create(bot_mode) as BotScenarioAutotests).test_names()
	_head(body, "Тесты (%d) по группам" % names.size())
	for gid in TestCatalog.group_ids():
		var titles := PackedStringArray()
		for n in names:
			if TestCatalog.group_of(String(n)) == String(gid):
				titles.append(TestCatalog.title(String(n)))
		if not titles.is_empty():
			body.add_child(_text("%s: %s" % [TestCatalog.group_name(String(gid)), ", ".join(titles)], UiScale.FONT_SMALL,
				INFO))
	body.add_child(_text("Что проверяет каждый тест — режим «Автотесты: по группам» или docs/TESTS.md.", UiScale.FONT_SMALL,
		MUTED))


static func toggle_test_group(main: Node, g: String) -> void:
	BotScenarioAutotests.toggle_group(g)
	if is_open(main):
		open(main)


# ---------- Вкладка «Отчёты»: история запусков, сравнение, экспорт ----------

## Выбранный запуск в истории (-1 — последний).
static var report_sel := -1
## Папка отчётов вкладок «Отчёты» и «Предложения» (тест — своя).
static var reports_dir := TestBot.REPORT_DIR


static func _build_reports(main: Node, body: VBoxContainer) -> void:
	var list := BotHistory.runs(reports_dir)
	body.add_child(_text("Запуски тест-бота на этом телефоне (последние %d, новые сверху). Выберите запуск: открыть, "
		% BotHistory.MAX_RUNS + "поделиться, сравнить с прошлым запуском того же режима. «Экспорт всего» — архив сводок, "
		+ "текстов отчётов, сравнения и предложений.", UiScale.FONT_SMALL, MUTED))
	if list.is_empty():
		_head(body, "Отчётов в истории ещё нет (история ведётся с версии 0.45)")
		return
	var sel := report_sel if report_sel >= 0 and report_sel < list.size() else list.size() - 1
	_head(body, "Запуски")
	for i in range(list.size() - 1, -1, -1):
		var ii := i
		_choice(body, "bot_hist_%d" % i, BotHistory.run_line(list[i]), i == sel,
			func() -> void: AdminPanel.select_report(main, ii))
	var run: Dictionary = list[sel]
	_head(body, "Выбран: " + BotHistory.run_line(run))
	var d := BotHistory.load_summary(run)
	if not d.is_empty():
		body.add_child(_text("Итог: %s%s · проверок %d, ошибок %d · длительность %s · лог: ошибок %d" % [
			String(d.get("result_text", "")), " (%s)" % String(d["reason"]) if String(d.get("reason", "")) != "" else "",
			int(d.get("checks", 0)), int(d.get("errors", 0)), TestBot.clock(float(d.get("duration", 0.0))),
			int((d.get("log", {}) as Dictionary).get("errors", 0))], UiScale.FONT_SMALL, INFO))
	var r := _row(body)
	_btn(r, "bot_hist_open", "Открыть", func() -> void: AdminPanel.report_open(main, false), 120.0)
	_btn(r, "bot_hist_share", "Поделиться", func() -> void: AdminPanel.report_open(main, true), 120.0)
	_btn(r, "bot_hist_compare", "Сравнить с прошлым", func() -> void: AdminPanel.report_compare(main), 180.0)
	var prev := BotHistory.previous_of(list, sel)
	(buttons["bot_hist_compare"] as Button).disabled = prev < 0
	if prev < 0:
		body.add_child(_text("Сравнить не с чем: прошлого запуска режима «%s» в истории нет." % String(run.get("mode_name", "")),
			UiScale.FONT_SMALL, MUTED))
	var ids := BotHistory.last_compare_ids
	if not BotHistory.last_compare.is_empty() and ids.size() == 2 and String(ids[1]) == String(run.get("id", "")):
		_head(body, "Сравнение")
		for line in BotHistory.last_compare:
			var col := INFO
			if line.contains("▼") or line.begins_with("  +") or line.contains("перестали"):
				col = BAD
			body.add_child(_text(line, UiScale.FONT_SMALL, col))
		var rc := _row(body)
		_btn(rc, "bot_cmp_share", "Поделиться сравнением", func() -> void: AdminPanel.compare_share(main), 200.0)
	_head(body, "Экспорт")
	var re := _row(body)
	_btn(re, "bot_export_all", "Экспорт всего", func() -> void: AdminPanel.reports_export(main), 160.0)


static func select_report(main: Node, i: int) -> void:
	report_sel = i
	if is_open(main):
		open(main)


static func _selected_run() -> Dictionary:
	var list := BotHistory.runs(reports_dir)
	if list.is_empty():
		return {}
	var sel := report_sel if report_sel >= 0 and report_sel < list.size() else list.size() - 1
	return list[sel]


## «Открыть» / «Поделиться» выбранным отчётом.
static func report_open(main: Node, share: bool) -> String:
	var run := _selected_run()
	var msg := "Отчётов в истории нет"
	if not run.is_empty():
		msg = BotReport.share_report(run) if share else BotReport.open_report(run)
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.show_message(msg, 6.0)
	return msg


## «Сравнить с прошлым»: выбранный запуск с прошлым того же режима (строки — в окне, файл — compare_last.txt).
static func report_compare(main: Node) -> String:
	var list := BotHistory.runs(reports_dir)
	var sel := report_sel if report_sel >= 0 and report_sel < list.size() else list.size() - 1
	var err := BotHistory.compare_run(list, sel, reports_dir) if not list.is_empty() else "отчётов в истории нет"
	var hud := main.get("hud") as HUD
	if err != "" and hud != null:
		hud.show_message("Сравнить нельзя: " + err, 6.0)
	if is_open(main):
		open(main)
	return err


static func compare_share(main: Node) -> String:
	var msg := BotReport.share_report({"txt": BotHistory.compare_path(reports_dir)})
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.show_message(msg, 6.0)
	return msg


## «Экспорт всего»: архив в «Загрузки» и «Поделиться».
static func reports_export(main: Node) -> Dictionary:
	var res := BotHistory.export_all(reports_dir)
	var msg := String(res.get("message", ""))
	if String(res.get("zip", "")) != "":
		msg += " · " + BotReport.share_report(res)
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.show_message(msg, 8.0)
	return res


# ---------- Вкладка «Предложения»: только просмотр ----------

static func _build_suggest(main: Node, body: VBoxContainer) -> void:
	var items := BotSuggest.collect(BotHistory.runs(reports_dir))
	body.add_child(_text("Что стоит посмотреть по последнему запуску каждого режима тест-бота. Только просмотр и экспорт: "
		+ "игра ничего не исправляет и не меняет сама — решение за вами.", UiScale.FONT_SMALL, MUTED))
	var c := BotSuggest.counts(items)
	_head(body, "Предложений: %d (критично %d, ошибок %d, внимание %d, заметок %d)" % [items.size(), int(c["critical"]),
		int(c["error"]), int(c["warn"]), int(c["info"])])
	if items.is_empty():
		body.add_child(_text("Замечаний нет — или запусков с версии 0.45 ещё не было.", UiScale.FONT_SMALL, INFO))
	for it in items:
		var d: Dictionary = it
		var sev := String(d["severity"])
		body.add_child(_text("● %s · %s" % [String(BotSuggest.SEV_NAMES.get(sev, sev)), String(d["title"])],
			UiScale.FONT_BODY, BotSuggest.SEV_COLORS.get(sev, INFO)))
		body.add_child(_text("где: " + String(d["where"]), UiScale.FONT_SMALL, MUTED))
		for e in d["evidence"]:
			body.add_child(_text("· " + String(e), UiScale.FONT_SMALL, INFO))
		if String(d["advice"]) != "":
			body.add_child(_text("Что посмотреть: " + String(d["advice"]), UiScale.FONT_SMALL, NOTE))
	var r := _row(body)
	_btn(r, "bot_sug_export", "Экспорт предложений", func() -> void: AdminPanel.suggest_export(main), 200.0)
	(buttons["bot_sug_export"] as Button).disabled = items.is_empty()


## «Экспорт предложений»: текст в папку отчётов, «Загрузки» и «Поделиться».
static func suggest_export(main: Node) -> String:
	var path := reports_dir + "suggestions.txt"
	var ok := TestBot.write_atomic(path, BotSuggest.text(BotSuggest.collect(BotHistory.runs(reports_dir))) + "\n")
	var msg := "Не удалось записать предложения"
	if ok:
		BotReport.publish(path, BotReport.TXT_MIME)
		msg = BotReport.share_report({"txt": path})
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.show_message(msg, 6.0)
	return msg


## «По разделам»: разделы переключателями (выбор хранится — BotScenarioGame.chosen), оценка времени.
static func _build_bot_sections(main: Node, body: VBoxContainer) -> void:
	var cur := BotScenarioGame.chosen()
	_head(body, "Разделы (выбрано %d, примерно %s)" % [cur.size(), TestBot.clock(BotScenarioGame.estimate(cur))])
	var g := _grid(body, 3)
	for e in BotSection.SECTIONS:
		var sd: Dictionary = e
		var sid := String(sd["id"])
		_choice(g, "bot_sec_" + sid, "%s · %s" % [String(sd["name"]), TestBot.clock(float(sd.get("full", 30)))], cur.has(sid),
			func() -> void: AdminPanel.toggle_bot_section(main, sid))


## «Кардинал: прохождение острова»: ускорение прогона ×8 / ×16 / ×32 (BotScenarioCardinalStory.accel).
static func _build_bot_accel(main: Node, body: VBoxContainer) -> void:
	_head(body, "Ускорение прохождения (шаг физики тот же 1/60 с, без 3D)")
	var r := _row(body)
	for k in BotScenarioCardinalStory.ACCEL_CHOICES:
		var kk := int(k)
		_choice(r, "bot_accel_%d" % kk, "×%d" % kk, roundi(BotScenarioCardinalStory.accel) == kk,
			func() -> void: AdminPanel.set_bot_accel(main, kk))


## «Кардинал: профили игроков»: профили, отрезок, прогонов на профиль, раса и профессия, ускорение; оценка времени и
## понятная причина, если начать нельзя.
static func _build_bot_profiles(main: Node, body: VBoxContainer) -> void:
	var S := BotScenarioCardinalProfiles
	body.add_child(_text("Честное прохождение отрезка острова разными «игроками»: опыт ×1, без бессмертия. Итог — время "
		+ "уровней и заданий, опыт и золото, смерти, застревания, гринд, нехватка зелий и золота, пробы окон и кнопок, "
		+ "подозрения с доказательствами. Правки профилей — файл user://cardinal_profiles.json.", UiScale.FONT_SMALL, MUTED))
	_head(body, "Профили")
	var g := _grid(body, 3)
	for pid in CardinalProfiles.IDS:
		var p := String(pid)
		_choice(g, "bot_prof_" + p, CardinalProfiles.profile_name(p), S.chosen.has(p), func() -> void:
			S.toggle_profile(p)
			_reopen(main))
	_head(body, "Отрезок")
	var g2 := _grid(body, 3)
	for sid in S.SEGMENT_IDS:
		var sg := String(sid)
		_choice(g2, "bot_seg_" + sg, String(S.SEGMENTS[sg]["name"]), S.segment == sg, func() -> void:
			S.segment = sg
			_reopen(main))
	_head(body, "Прогонов на профиль (разные seed)")
	var r := _row(body)
	for n in S.SEED_CHOICES:
		var nn := int(n)
		_choice(r, "bot_seeds_%d" % nn, "×%d" % nn, S.seeds == nn, func() -> void:
			S.seeds = nn
			_reopen(main))
	_head(body, "Раса героя (профессия — для отрезка «10 → 15 ур.»)")
	var r2 := _row(body)
	for rc in ["human", "light_elf", "dark_elf"]:
		var rr := String(rc)
		_choice(r2, "bot_race_" + rr, String(ClassData.race(rr).get("name", rr)), S.race == rr, func() -> void:
			S.race = rr
			S.job = ""
			_reopen(main))
	var r3 := _row(body)
	for jb in ClassData.jobs_of(S.race):
		var jj := String(jb)
		_choice(r3, "bot_job_" + jj, ClassData.job_name(jj), S.job_for_run() == jj, func() -> void:
			S.job = jj
			_reopen(main))
	_head(body, "Ускорение (шаг физики тот же 1/60 с, без 3D)")
	var r4 := _row(body)
	for k in S.ACCEL_CHOICES:
		var kk := int(k)
		_choice(r4, "bot_paccel_%d" % kk, "×%d" % kk, roundi(S.accel) == kk, func() -> void:
			S.accel = float(kk)
			_reopen(main))
	var why := S.validate()
	body.add_child(_text("Прогонов %d · примерно %d мин" % [S.chosen.size() * S.seeds, roundi(S.estimate_min())]
		+ ("" if why == "" else " — " + why), UiScale.FONT_SMALL, INFO if why == "" else BAD))


static func _reopen(main: Node) -> void:
	if is_open(main):
		open(main)


## Время и погода (админ-панель «Мир», только на эту игру).
static func set_time(main: Node, h: float) -> void:
	WorldClock.frozen = false
	WorldClock.set_hour(h)
	_reopen(main)


static func set_time_speed(main: Node, sp: float) -> void:
	var h := WorldClock.hour()
	WorldClock.frozen = false
	WorldClock.speed = sp
	WorldClock.set_hour(h)
	_reopen(main)


static func toggle_time_freeze(main: Node) -> void:
	if WorldClock.frozen:
		var h := WorldClock.frozen_hour
		WorldClock.frozen = false
		WorldClock.set_hour(h)
	else:
		WorldClock.frozen_hour = WorldClock.hour()
		WorldClock.frozen = true
	_reopen(main)


static func reset_time(main: Node) -> void:
	WorldClock.reset()
	Weather.force = ""
	_reopen(main)


static func set_weather(main: Node, id: String) -> void:
	Weather.force = id
	_reopen(main)


static func set_bot_accel(main: Node, k: int) -> void:
	BotScenarioCardinalStory.accel = float(k)
	if is_open(main):
		open(main)


static func toggle_bot_section(main: Node, sec_id: String) -> void:
	BotScenarioGame.toggle_chosen(sec_id)
	if is_open(main):
		open(main)


static func set_bot_mode(main: Node, mode_id: String) -> void:
	if BotScenario.create(mode_id) == null:
		return
	bot_mode = mode_id
	if is_open(main):
		open(main)


## «Начать»: окно закрывается (открытое окно ограничивает кадры — испортило бы замер), бот переключает героя.
static func bot_start(main: Node) -> String:
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.close_window()
	var err := TestBot.start(main, bot_mode)
	if err != "" and hud != null:
		hud.show_message("Тест-бот: " + err)
	return err


## «Продолжить» прерванный запуск (контрольная точка долгого режима): тот же режим и выбор, готовое не повторяется.
static func bot_resume(main: Node) -> String:
	var cp := TestBot.read_checkpoint()
	var hud := main.get("hud") as HUD
	if not bool(cp.get("ok", false)):
		var why := "Продолжить нельзя: " + String(cp.get("error", "контрольной точки нет"))
		if hud != null:
			hud.show_message("Тест-бот: " + why)
		return why
	if hud != null:
		hud.close_window()
	var err := TestBot.start(main, String(cp["mode"]), {"resume": cp})
	if err != "" and hud != null:
		hud.show_message("Тест-бот: " + err)
	return err


## «Забыть» прерванный запуск: контрольная точка удаляется.
static func bot_forget(main: Node) -> void:
	TestBot.drop_checkpoint()
	if is_open(main):
		open(main)


static func bot_stop(main: Node) -> void:
	TestBot.stop_current("Остановлен в админ-панели")
	var hud := main.get("hud") as HUD
	if hud != null and is_instance_valid(hud):
		hud.close_window()


## «Открыть отчёт» (share = false) или «Поделиться» последним отчётом.
static func bot_report(main: Node, share: bool) -> void:
	var last := TestBot.last_result()
	var msg := BotReport.share_report(last) if share else BotReport.open_report(last)
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.show_message(msg, 6.0)


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
