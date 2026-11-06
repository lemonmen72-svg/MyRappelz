extends "res://tests/test_base.gd"
## Глава I «Шёпот из глубин» (0.38; канон — docs/story/DUNGEON_CHAPTER1_STORY.md): 11 заданий Корвена и мудреца по
## порядку (QuestData.CH1_CHAIN), количества целей по канону, монстры подземелья — настоящие (убиты в мире подземелья:
## событие смерти → Quests.on_mob_killed), убитые до взятия задания не в счёт, свитки вождя и Старшего жреца —
## гарантированная квестовая добыча, в сумке открываются окном (Story), признание капитана — окном после его смерти,
## реплики боссов (MobData.says), награда — один раз; Кардинал знает монстров подземелья и их уровни.

const Q := ["merc_dungeon", "ch1_proof", "ch1_chief", "ch1_below", "ch1_last_watch", "ch1_forgotten_name",
	"ch1_order", "ch1_gifts", "ch1_captain", "ch1_truth", "ch1_horizon"]
var q: Quests = null
var cap_t := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 30


func before_start() -> void:
	Game.location = "dungeon"
	AdminPanel.god = true
	for id in ["sage_to_merc", "merc_closed_cave"]:
		Game.quests_done[id] = 1


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			q = main.quests
			_data()
			_chain_a()
			_says()
			wait = 10
			step = 1
		1:
			_chain_b()
			wait = int(Quests.CONFESSION_DELAY * 60.0) + 20
			step = 2
		2:
			check(Story.last_opened == "captain_confession", "после смерти капитана — окно с его последними словами (%s)" % Story.last_opened)
			_chain_c()
			ok_done()


func _data() -> void:
	check(QuestData.CH1_CHAIN == Q, "глава I — 11 заданий по порядку")
	for i in Q.size():
		var id := String(Q[i])
		check(QuestData.has_quest(id), "задание %s есть" % id)
		if i > 0:
			check(QuestData.prereqs(id) == [String(Q[i - 1])], "%s — после %s" % [id, Q[i - 1]])
		for f in ["desc", "offer", "done"]:
			check(String(QuestData.get_quest(id).get(f, "")) != "", "%s: текст %s" % [id, f])
	check(QuestData.quest_name("merc_dungeon") == "Следы у скал" and QuestData.DUNGEON_QUEST == "merc_dungeon",
		"Q01 «Следы у скал» — то же задание, что открывает портал")
	check(QuestData.giver("ch1_horizon") == "sage" and QuestData.turn_in("ch1_gifts") == "smith", "мудрец — финал, кузнец — дары")
	# Количества — по канону
	var need := {"ch1_proof": [10, 10], "ch1_below": [3], "ch1_last_watch": [5, 5, 1], "ch1_forgotten_name": [10, 1, 1],
		"ch1_captain": [10, 1]}
	for id in need:
		var gs := QuestData.goals(String(id))
		var got: Array = []
		for g in gs:
			got.append(QuestData.goal_need(g))
		check(got == need[id], "%s: цели %s" % [id, got])
	for d in ["goblin_exodus_scroll", "priest_order_scroll"]:
		check(ItemData.item_type(d) == "document" and int(ItemData.get_item(d)["sell"]) == 0 and Story.has(d),
			"документ %s — с текстом, не продаётся" % d)
	check(Story.plain("captain_confession").contains("Мрак никогда не уходил"), "признание капитана — по канону")
	check(Story.plain("goblin_exodus_scroll").contains("Мёртвые люди ходят по воде"), "свиток вождя — по канону")
	check(Story.plain("priest_order_scroll").contains("Хранителя Изумрудной Клятвы"), "приказ жреца — по канону")
	# Кардинал проходит и главу I: ходки в подземелье за монстрами её заданий
	for id in Q:
		check(CardinalStory.scope_ids().has(id), "Кардинал проходит %s" % id)
	check(CardinalStory.dungeon_species(["dg_goblin", "dg_captain"]) and not CardinalStory.dungeon_species(["wolf", "dg_goblin"]),
		"Кардинал отличает монстров подземелья")
	check(CardinalStory.dungeon_levels("dg_captain") == [30, 30] and CardinalStory.dungeon_levels("dg_goblin") == [20, 22],
		"уровни монстров подземелья — по зонам (%s)" % [CardinalStory.dungeon_levels("dg_goblin")])


func _kill(type_id: String, n: int = 1) -> Mob:
	var last: Mob = null
	for i in n:
		var p: Vector3 = main.player.global_position + Vector3(4.0, 0.0, float(i % 3))
		var m: Mob = main.spawn_mob(type_id, -1, p)
		m.take_damage(m.hp + 10, main.player)
		last = m
	return last


func _take(id: String) -> void:
	check(q.state(id) == "available", "%s можно взять (%s)" % [id, q.state(id)])
	check(q.accept(id), "%s взято" % id)


func _finish(id: String) -> void:
	check(q.is_ready(id), "%s выполнено (%s)" % [id, q.progress(id)])
	check(q.complete(id), "%s сдано" % id)
	check(not q.complete(id) and q.is_done(id), "%s: награда один раз" % id)


func _chain_a() -> void:
	check(q.state("ch1_proof") == "locked", "Q02 закрыто, пока не сдано Q01")
	# Q01: спуск засчитан событием «вошёл в подземелье», первый гоблин
	_take("merc_dungeon")
	q.on_entered("dungeon")
	_kill("dg_goblin")
	_finish("merc_dungeon")
	# Q02: убитые до взятия не в счёт; знак — квестовая добыча с каждого гоблина
	_kill("dg_goblin", 2)
	_take("ch1_proof")
	check(q.goal_progress("ch1_proof", 0) == 0, "убитые до взятия гоблины не засчитаны")
	check(q.quest_loot("dg_goblin").has("goblin_token"), "пока задание взято, знак падает с гоблина")
	_kill("dg_goblin", 10)
	Game.inventory.add("goblin_token", 10)
	_finish("ch1_proof")
	check(Game.inventory.count("goblin_token") == 0, "знаки забраны при сдаче")
	# Q03: вождь и его свиток (гарантированно, пока цель не выполнена) — окно для чтения
	_take("ch1_chief")
	check(q.quest_loot("dg_goblin_chief").has("goblin_exodus_scroll"), "свиток вождя — квестовая добыча")
	_kill("dg_goblin_chief")
	Story.last_opened = ""
	Game.inventory.add("goblin_exodus_scroll", 1)
	q.poll()
	check(q.story_shown.has("goblin_exodus_scroll"), "свиток вождя открыт для чтения")
	_finish("ch1_chief")
	check(Game.inventory.count("goblin_exodus_scroll") == 1, "свиток остаётся у героя")
	check(not q.quest_loot("dg_goblin_chief").has("goblin_exodus_scroll"), "после сдачи свиток больше не падает")
	# Q04: трое мертвецов суммарно
	_take("ch1_below")
	_kill("dg_sailor")
	_kill("dg_wight")
	_kill("dg_graveguard")
	_finish("ch1_below")
	# Q05: 5 матросов, 5 рыцарей, Мёртвый рыцарь
	_take("ch1_last_watch")
	_kill("dg_sailor", 5)
	_kill("dg_graveguard", 3)
	_kill("dg_wight", 2)
	check(not q.is_ready("ch1_last_watch"), "без Мёртвого рыцаря не готово")
	_kill("dg_dead_knight")
	_finish("ch1_last_watch")


func _says() -> void:
	var p: Vector3 = main.player.global_position + Vector3(6.0, 0.0, 0.0)
	var k: Mob = main.spawn_mob("dg_dead_knight", -1, p)
	k.say("aggro")
	var hud: HUD = main.hud
	check(hud._msg_label.text == "Мёртвый рыцарь: «Проход… закрыт…»", "реплика Мёртвого рыцаря: %s" % hud._msg_label.text)
	k.take_damage(k.hp - int(float(k.max_hp) * 0.4), main.player)
	check(k.last_said == MobData.says_of("dg_dead_knight", "half"), "на половине HP — «Приказ… должен быть исполнен…»")
	k.consume()
	for id in ["dg_goblin_chief", "dg_elder_priest", "dg_captain"]:
		check(not MobData.says_of(id, "aggro").is_empty(), "%s говорит перед боем" % id)


func _chain_b() -> void:
	# Q06: 10 жрецов, Старший жрец; приказ — квестовая добыча
	_take("ch1_forgotten_name")
	for sp in ["dg_bone_oracle", "dg_grave_oracle", "dg_plague_shaman", "dg_sect_wraith"]:
		_kill(sp, 2)
	_kill("dg_bone_oracle", 2)
	_kill("dg_elder_priest")
	check(q.quest_loot("dg_elder_priest").has("priest_order_scroll"), "приказ жреца — квестовая добыча")
	Game.inventory.add("priest_order_scroll", 1)
	q.poll()
	_finish("ch1_forgotten_name")
	# Q07: свиток в сумке засчитан сразу, разговор с Корвеном — тем, у кого взято
	_take("ch1_order")
	q.on_talk("merc_chief")
	_finish("ch1_order")
	# Q08: материалы у кузнеца
	_take("ch1_gifts")
	var cubes := Game.inventory.count("cube_attack_r2")
	q.on_talk("smith")
	_finish("ch1_gifts")
	check(Game.inventory.count("cube_attack_r2") >= cubes + 2, "кузнец отдал материалы")
	# Q09: команда (10) и капитан — его смерть открывает признание
	_take("ch1_captain")
	_kill("dg_rot_corsair", 4)
	_kill("dg_coral_corsair", 3)
	_kill("dg_reef_wraith", 3)
	Story.last_opened = ""
	_kill("dg_captain")
	check(q.story_shown.has("captain_confession"), "смерть капитана при взятом задании — признание")


func _chain_c() -> void:
	_finish("ch1_captain")
	# Повторная смерть капитана (фарм) — признания больше нет
	var n := q.story_shown.size()
	_kill("dg_captain")
	check(q.story_shown.size() == n, "капитан убит снова — без признания")
	_take("ch1_truth")
	q.on_talk("merc_chief")
	_finish("ch1_truth")
	_take("ch1_horizon")
	q.on_talk("sage")
	_finish("ch1_horizon")
	for id in Q:
		check(q.is_done(id), "%s сдано" % id)
	# Окно документа из сумки
	check(Story.open(main.hud, "priest_order_scroll") and main.hud.is_window_open(), "документ открывается окном")
	main.hud.close_window()
