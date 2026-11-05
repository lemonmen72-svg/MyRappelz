extends "res://tests/test_base.gd"
## «Звери вокруг» (Quality.mob_range, main._mob_stream; просьба Максима: дальше выбранного зверей нет совсем,
## появляются при подходе): при 40 м в мире только звери слотов рядом с героем (узлы дальних не созданы), перенос
## героя в другую часть острова — у прежнего места звери убраны (узлов нет), у нового — появились на своих слотах;
## занятый зверь (с целью, по пути домой, помечен приручением) не убирается, даже если герой далеко; убитый зверь ждёт возрождения — «звери вокруг» его не
## ставят раньше таймера; «Все» — все слоты острова заполнены; настройка в «Настройки → Графика» (кнопки mobs_N).

var far_spot := Vector2(-90.0, 40.0)
var fighter: Mob = null
var fighter_slot := -1
var killed_slot := -1
var total := 0
var retries := 0


func before_start() -> void:
	Quality.mob_range_override = 0


func _slot_mobs() -> Array:
	var res: Array = []
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and m.slot >= 0 and m.get_parent() == main:
			res.append(m)
	return res


func _hero_xz() -> Vector2:
	return Vector2(main.player.global_position.x, main.player.global_position.z)


func _move_hero(c: Vector2) -> void:
	main.player.global_position = main.world.ground(c.x, c.y, 0.3)
	main.player.velocity = Vector3.ZERO


func run_step() -> void:
	match step:
		0:
			total = main._slots.size()
			check(total >= 150, "слотов зверей на острове: %d" % total)
			wait = 40
			step = 1
		1:
			var live := _slot_mobs()
			var r: float = Quality.mob_range() + float(main.MOB_STREAM_HYST)
			var far := 0
			for m in live:
				if Vector2((m as Mob).global_position.x, (m as Mob).global_position.z).distance_to(_hero_xz()) > r:
					far += 1
			check(Quality.mob_range() == 40.0, "дальность 40 м")
			check(live.size() > 0 and live.size() < total / 3, "при 40 м в мире %d зверей из %d" % [live.size(), total])
			check(far == 0, "дальше 40 м зверей нет (%d)" % far)
			check(main.live_slot_mobs() == live.size(), "учёт слотов совпадает: %d" % main.live_slot_mobs())
			# Занятый зверь (помечен приручением; так же — с целью и по пути домой) — не убирается
			fighter = live[0] as Mob
			fighter_slot = fighter.slot
			fighter.tame_marked = true
			_move_hero(far_spot)
			wait = 90
			step = 2
		2:
			var live := _slot_mobs()
			var near := 0
			for m in live:
				if Vector2((m as Mob).global_position.x, (m as Mob).global_position.z).distance_to(_hero_xz()) < 40.0:
					near += 1
			check(near > 0, "у нового места звери появились: %d" % near)
			check(is_instance_valid(fighter) and fighter.is_inside_tree(), "занятый зверь (метка приручения) не убран")
			var stale := 0
			for m in live:
				var d := Vector2((m as Mob).global_position.x, (m as Mob).global_position.z).distance_to(_hero_xz())
				if m != fighter and d > Quality.mob_range() + float(main.MOB_STREAM_HYST):
					stale += 1
			check(stale == 0, "у прежнего места звери убраны (осталось %d)" % stale)
			# Отпустили — уберётся
			fighter.tame_marked = false
			wait = 60
			step = 3
		3:
			# Без цели зверь идёт домой (returning), дома — убирается
			var gone := not is_instance_valid(fighter) or fighter.is_queued_for_deletion() or not fighter.is_inside_tree()
			if not gone and retries < 40:
				retries += 1
				wait = 30
				return
			check(gone, "зверь без цели вдали — убран")
			check(main._slot_mob[fighter_slot] == null, "его слот пуст")
			# Убитый зверь ждёт возрождения
			var live := _slot_mobs()
			var victim := live[0] as Mob
			killed_slot = victim.slot
			victim.hp = 1
			victim.take_damage(999999, main.player)
			wait = 60
			step = 4
		4:
			check(main._slot_wait[killed_slot], "убитый ждёт возрождения — слот занят таймером")
			var back := false
			for m in _slot_mobs():
				if (m as Mob).slot == killed_slot:
					back = true
			check(not back, "до таймера звери вокруг его не ставят")
			Quality.mob_range_override = 3
			wait = 60
			step = 5
		5:
			var live := _slot_mobs().size()
			var waiting := 0
			for w in main._slot_wait:
				if w:
					waiting += 1
			check(live + waiting == total, "«Все»: в мире %d + ждут %d = %d слотов" % [live, waiting, total])
			# Настройка в окне графики
			Quality.mob_range_override = -1
			SettingsMenu.open(main.hud, "graphics")
			check(SettingsMenu.buttons.has("mobs_0") and SettingsMenu.buttons.has("mobs_3"), "«Звери вокруг» в настройках")
			main.hud.close_window()
			ok_done()
