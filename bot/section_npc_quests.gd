extends BotSection
## Раздел «Задания жителей» (0.32): новые жители острова (Рыбак Сигурд, Ветеран Борислав, Травница Мирта, Писарь
## Онфим) стоят на местах, у каждого в диалоге «Задания»; «Сбор трав» у Мирты — находки светятся в Светлой роще,
## подошёл — трава в сумке; заказ с доски писаря — цели выбраны по уровню героя; снаряжение питомца (вкладка
## «Оружие и доспехи», PetGear) — цель «надеть вещь питомцу» у Кирка.

const NEW_NPCS := ["fisher", "veteran", "herbalist", "scribe"]

var _herbs0 := 0


func id() -> String:
	return "npc_quests"


func _build() -> void:
	do("Задания жителей: герой", _setup)
	for n in NEW_NPCS:
		do("Житель «%s»: диалог и задания" % NpcData.npc_name(n), _talk.bind(n))
		wait(0.2)
	do("Сбор трав: взять у Мирты", _herbs_take)
	wait(0.6)
	do("Сбор трав: к находке", _herbs_go)
	wait(1.0)
	do("Сбор трав: трава сорвана", _herbs_check)
	do("Заказ с доски: взять у писаря", _contract)
	do("Снаряжение питомца: задание Кирка", _pet_gear)


func _setup() -> void:
	hero(ClassData.WANDERER, 12)
	fresh_bag(20000)
	no_pets()
	Game.quests_active.clear()


func _talk(npc_id: String) -> void:
	if not check(npc_node(npc_id) != null, "житель «%s» стоит в мире" % NpcData.npc_name(npc_id)):
		return
	if not go_near(npc_id):
		return
	npcs().talk_to(npc_id)
	check(hud().is_window_open(), "диалог «%s» открыт" % NpcData.npc_name(npc_id))
	check(not quests().npc_quests(npc_id).is_empty(), "у «%s» есть задания: %s" % [NpcData.npc_name(npc_id),
		", ".join(PackedStringArray(quests().npc_quests(npc_id)))])
	window_fits("Диалог: %s" % NpcData.npc_name(npc_id))
	if npc_id == "scribe":
		shot("Pisar")
	close_window()


func _herbs_take() -> void:
	var q := quests()
	check(q.accept("herb_gather") and q.is_active("herb_gather"), "«Сбор трав» взят (%s)" % last_msg())
	_herbs0 = Game.inventory.count("herb_silverleaf")
	q.poll(1.0)


func _herbs_go() -> void:
	var q := quests()
	var f := q.finds()
	if not check(not f.is_empty(), "находки в роще: %d" % f.size()):
		return
	var fp: Vector3 = (f[0] as Node3D).global_position
	player().global_position = fp + Vector3(0.8, 0.2, 0.0)
	shot("Nahodki")


func _herbs_check() -> void:
	check(Game.inventory.count("herb_silverleaf") > _herbs0, "подошёл — трава сорвана (%d)" %
		Game.inventory.count("herb_silverleaf"))
	quests().abandon("herb_gather")


func _contract() -> void:
	var q := quests()
	check(q.accept("scribe_contract") and q.is_active("scribe_contract"), "заказ с доски взят (%s)" % last_msg())
	var rec: Dictionary = Game.quests_active.get("scribe_contract", {})
	check(not (rec.get("goals", []) as Array).is_empty(), "у заказа своя цель: %s" % [rec.get("goals", [])])
	q.abandon("scribe_contract")


func _pet_gear() -> void:
	var i: int = AdminPanel.add_pet(main(), "wolf", 10)
	if not check(i >= 0, "волк 10 ур."):
		return
	var rec: Dictionary = Game.pets[i]
	var sk: Dictionary = rec.get("skills", {})
	sk["item_expert_wolf"] = maxi(1, int(sk.get("item_expert_wolf", 0)))
	rec["skills"] = sk
	Game.quests_done["kirk_bond_trial"] = 1
	Game.quests_done["kirk_pet_skills"] = 1
	var q := quests()
	check(q.accept("kirk_pet_gear"), "«Снаряжение для зверя» взято (%s)" % last_msg())
	Game.inventory.add("weapon_sword_1h_r1")
	var err := PetGear.equip(rec, "weapon_sword_1h_r1")
	check(err == "" and PetGear.gear_in(rec, "weapon") == "weapon_sword_1h_r1", "меч надет волку (%s)" % err)
	q.poll(1.0)
	check(q.is_ready("kirk_pet_gear"), "цель «надеть вещь питомцу» выполнена")
	if pets().creature != null:
		check(pets().creature.open(i, "gear"), "окно существа: вкладка «Оружие и доспехи»")
		window_fits("Существо: оружие и доспехи")
		shot("Snaryazhenie pitomca")
		close_window()
	q.abandon("kirk_pet_gear")
	no_pets()
