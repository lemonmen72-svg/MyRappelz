extends BotSection
## Раздел «Задания» — настоящим путём, через разговор: староста своей деревни — значок «!» над ним, диалог
## «Задания» → задание «Тревога в округе» → «Взять задание» (значок «?»); на поле — фазаны с красным значком
## задания над головой, герой побеждает их обычными атаками — прогресс 3/3, значок «=» над старостой; диалог →
## «Сдать задание» — задание сдано, награда (золото). Затем Учитель Кирк: «Первая карта» — взять, купить карту в его
## лавке (цель «купить у Кирка»), сдать. Задания героя перед разделом сбрасываются.

const HUNT := "elder_hunt"
const CARD_QUEST := "kirk_first_card"
const TARGET := "pheasant"
const TARGET_LEVEL := 2
## Бить зверей не дольше, с; потом — добить (как «Убить цель» админ-панели).
const FIGHT := 20.0

var _gold0 := 0
var _fight_t := 0.0


func id() -> String:
	return "quests"


func _build() -> void:
	do("Задания: герой, задания с начала", _setup)
	do("Староста: значок «!», диалог", _talk_offer.bind(HUNT))
	wait(0.3)
	do("Староста: «Задания»", func() -> void: press_dialog("opt_quests"))
	wait(0.2)
	do("Староста: задание", func() -> void: press_dialog("dq_" + HUNT))
	wait(0.2)
	do("Староста: «Взять задание»", _accept.bind(HUNT))
	do("Фазаны: красный значок задания", _spawn_targets)
	until("значок задания над фазанами", _targets_marked, 3.0)
	do("Фазаны: бой", _fight_start)
	until("задание выполнено (3/3)", func() -> bool: return quests().is_ready(HUNT), FIGHT + 5.0)
	do("Староста: значок «=», сдать", _talk_ready.bind(HUNT))
	wait(0.3)
	do("Староста: «Задания»", func() -> void: press_dialog("opt_quests"))
	wait(0.2)
	do("Староста: задание", func() -> void: press_dialog("dq_" + HUNT))
	wait(0.2)
	do("Староста: «Сдать задание»", _complete.bind(HUNT))
	# Учитель Кирк: «Первая карта» — купить карту у него
	do("Кирк: значок «!», диалог", _talk_offer.bind(CARD_QUEST))
	wait(0.3)
	do("Кирк: «Задания»", func() -> void: press_dialog("opt_quests"))
	wait(0.2)
	do("Кирк: задание", func() -> void: press_dialog("dq_" + CARD_QUEST))
	wait(0.2)
	do("Кирк: «Взять задание»", _accept.bind(CARD_QUEST))
	do("Кирк: купить карту", _buy_card)
	do("Кирк: значок «=», сдать", _talk_ready.bind(CARD_QUEST))
	wait(0.3)
	do("Кирк: «Задания»", func() -> void: press_dialog("opt_quests"))
	wait(0.2)
	do("Кирк: задание", func() -> void: press_dialog("dq_" + CARD_QUEST))
	wait(0.2)
	do("Кирк: «Сдать задание»", _complete.bind(CARD_QUEST))
	do("Задания: журнал", _journal)
	wait(0.2)
	do("Задания: журнал помещается", _journal_check)


func _setup() -> void:
	hero(Game.class_id, 15)
	fresh_bag(500)
	no_pets()
	Game.quests_active.clear()
	Game.quests_done.clear()
	Game.quest_tracked = ""
	quests().refresh_tracker()
	npcs().refresh_marks()


## К NPC, который выдаёт задание qid: значок «!», разговор.
func _talk_offer(qid: String) -> void:
	close_window()
	var giver := QuestData.giver(qid)
	if not go_near(giver):
		return
	check(quests().state(qid) == "available", "«%s» можно взять (%s)" % [QuestData.quest_name(qid), quests().state(qid)])
	check(quests().npc_mark(giver) == "offer", "над «%s» — «!» (%s)" % [NpcData.npc_name(giver), quests().npc_mark(giver)])
	npcs().talk_to(giver)
	check(npcs().is_dialog_open(), "диалог с «%s»" % NpcData.npc_name(giver))


func _accept(qid: String) -> void:
	if not press_dialog("accept"):
		return
	check(quests().is_active(qid), "«%s» взято (%s)" % [QuestData.quest_name(qid), last_msg()])
	var giver := QuestData.giver(qid)
	check(quests().npc_mark(QuestData.turn_in(qid)) == "active" or quests().is_ready(qid),
		"над «%s» — «?» (%s)" % [NpcData.npc_name(giver), quests().npc_mark(QuestData.turn_in(qid))])
	shot("Zadanie %s" % qid)
	close_window()


## Фазаны на поле (цель задания) — красный значок над ними.
func _spawn_targets() -> void:
	to_arena()
	for i in 3:
		spawn_ahead(TARGET, TARGET_LEVEL, 5.0, float(i - 1) * 2.5)
	npcs().refresh_marks()


func _targets_marked() -> bool:
	var all := bot.spawned_alive()
	if all.is_empty():
		return false
	for v in all:
		if not (v as Mob).quest_target:
			return false
	return true


## Бой: ближайший живой фазан бота — цель, подойти и бить; дольше FIGHT — добить.
func _fight(dt: float) -> void:
	var p := player()
	if p == null:
		return
	_fight_t += dt
	var t: Mob = null
	for v in bot.spawned_alive():
		var m := v as Mob
		if t == null or m.global_position.distance_to(p.global_position) < t.global_position.distance_to(p.global_position):
			t = m
	if t == null:
		bot.set_tick(Callable())
		return
	if _fight_t > FIGHT:
		kill(t)
		return
	if p.current_target != t:
		p.select_target(t)
	var d := t.global_position - p.global_position
	d.y = 0.0
	if d.length() > p.attack_range * 0.8:
		var dir := d.normalized()
		p.global_position = ground(t.global_position.x - dir.x * 1.5, t.global_position.z - dir.z * 1.5)
	p.try_attack()


## К NPC, которому сдавать: значок «=», разговор.
func _talk_ready(qid: String) -> void:
	bot.set_tick(Callable())
	close_window()
	var to := QuestData.turn_in(qid)
	check(quests().is_ready(qid), "«%s» выполнено: %s" % [QuestData.quest_name(qid), str(quests().progress(qid))])
	if not go_near(to):
		return
	check(quests().npc_mark(to) == "ready", "над «%s» — «=» (%s)" % [NpcData.npc_name(to), quests().npc_mark(to)])
	npcs().talk_to(to)
	_gold0 = Game.gold


func _complete(qid: String) -> void:
	if not press_dialog("complete"):
		return
	check(quests().is_done(qid) and not quests().is_active(qid), "«%s» сдано (%s)" % [QuestData.quest_name(qid), last_msg()])
	var gold := int(QuestData.get_quest(qid).get("rewards", {}).get("gold", 0))
	check(Game.gold >= _gold0 + gold, "награда: золото %d → %d (+%d по заданию)" % [_gold0, Game.gold, gold])
	close_window()


## «Первая карта»: окно лавки Кирка, карта фазана куплена у него — цель засчитана.
func _buy_card() -> void:
	var eco := economy()
	eco.open_shop("kirk")
	check(eco.buy(ItemData.card_for(TARGET), 1, "kirk"), "карта куплена у Кирка (%s)" % last_msg())
	close_window()


func _journal() -> void:
	quests().window.open(CARD_QUEST)


func _journal_check() -> void:
	window_fits("Журнал заданий")
	shot("Zhurnal zadaniy")
	close_window()


func _fight_start() -> void:
	_fight_t = 0.0
	bot.set_tick(_fight)
