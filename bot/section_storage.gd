extends BotSection
## Раздел «Склад»: у Кладовщика Тобина — пункт «Склад» в диалоге открывает окно склада; вещи на склад и обратно
## (часть стопки и вся), золото на склад и обратно; отошёл от кладовщика — окно закрывается.

const ITEM := "potion_hp_r1"
const GOLD := 300


func id() -> String:
	return "storage"


func _build() -> void:
	do("Склад: герой, сумка", _setup)
	do("Склад: к Кладовщику Тобину, диалог", _open)
	wait(0.3)
	do("Склад: вещи и золото", _move)
	do("Склад: отойти от кладовщика", _walk_away)
	until("окно склада закрылось вдали от кладовщика", func() -> bool: return not economy().is_storage_open(), 3.0)


func _setup() -> void:
	hero(Game.class_id, 10)
	fresh_bag(1000)
	Game.storage.from_dict({})
	Game.storage_gold = 0


func _open() -> void:
	if not go_near(Economy.STORAGE_NPC):
		return
	npcs().talk_to(Economy.STORAGE_NPC)
	press_dialog("opt_storage")


func _move() -> void:
	var eco := economy()
	if not check(eco.is_storage_open(), "окно склада открыто"):
		return
	window_fits("Склад")
	Game.inventory.add(ITEM, 5)
	var cell := Game.inventory.find_cell(ITEM)
	check(eco.deposit(cell, 3) == 3 and Game.storage.count(ITEM) == 3 and Game.inventory.count(ITEM) == 2,
		"на склад 3 из 5 (%s)" % last_msg())
	cell = Game.inventory.find_cell(ITEM)
	check(eco.deposit(cell) == 2 and Game.storage.count(ITEM) == 5 and Game.inventory.count(ITEM) == 0,
		"на склад вся стопка")
	shot("Sklad")
	var sc := Game.storage.find_cell(ITEM)
	check(eco.withdraw(sc) == 5 and Game.storage.count(ITEM) == 0 and Game.inventory.count(ITEM) == 5,
		"со склада в сумку вся стопка (%s)" % last_msg())
	var gold0 := Game.gold
	check(eco.deposit_gold(GOLD) == GOLD and Game.gold == gold0 - GOLD and Game.storage_gold == GOLD,
		"золото на склад: %d" % GOLD)
	check(eco.withdraw_gold(-1) == GOLD and Game.gold == gold0 and Game.storage_gold == 0, "золото со склада — всё")


## Отойти на 10 м — окно склада закрывается само.
func _walk_away() -> void:
	var n := npc_node(Economy.STORAGE_NPC)
	var p := player()
	if n == null or p == null:
		return
	var w := IslandWorld.current
	var c := n.global_position
	for k in 16:
		var d := Vector3(10.0, 0.0, 0.0).rotated(Vector3.UP, TAU * float(k) / 16.0)
		if w == null or w.is_walkable(c.x + d.x, c.z + d.z):
			p.global_position = ground(c.x + d.x, c.z + d.z)
			return
