extends SceneTree
## Автотест без экрана: запускает main.tscn и проходит основной цикл игры:
## сенсорный ввод HUD, бой, приручение, помощь питомца, смерть игрока и питомца, респавн зверей.
## Запуск: godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd

const MAX_FRAMES := 60 * 240

var main: Node
var frame := 0
var step := 0
var wait := 0
var mob: Mob = null
var xp_before := 0
var gold_before := 0
var pet_fought := false
var done := false


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	if done:
		return true
	frame += 1
	if frame > MAX_FRAMES:
		_fail("таймаут на шаге %d" % step)
		return true
	if wait > 0:
		wait -= 1
		return false

	var player: Player = main.player
	match step:
		0:
			_check(player != null and main.hud != null, "игрок и HUD созданы")
			_check(_count_mobs() == main._slots.size(), "звери заспавнены: %d" % _count_mobs())
			_test_touch(main.hud)
			step = 1
		1:
			mob = _find_mob("Кабан")
			_check(mob != null, "найден кабан")
			step = 2
		2:
			# Ослабляем кабана ниже 50% HP
			if not _mob_ok():
				step = 1
				return false
			player.global_position = mob.global_position + Vector3(0, 0, 2.0)
			if mob.hp > mob.max_hp * 0.5:
				player.try_attack()
			else:
				print("Кабан ослаблен: %d/%d" % [mob.hp, mob.max_hp])
				step = 3
		3:
			# Приручаем (шанс 65%, кулдаун 1.5 с)
			if main.pet != null:
				print("Приручён питомец: %s" % main.pet.pet_name)
				xp_before = player.xp + player.level * 100000
				gold_before = player.gold
				step = 4
				return false
			if not _mob_ok():
				step = 1
				return false
			player.global_position = mob.global_position + Vector3(0, 0, 2.0)
			main._on_tame()
		4:
			mob = _find_mob("Кабан")
			_check(mob != null, "найден второй кабан")
			step = 5
		5:
			# Убиваем зверя вместе с питомцем
			if main.pet.target != null:
				pet_fought = true
			if not _mob_ok():
				_check(player.xp + player.level * 100000 > xp_before, "игрок получил опыт")
				_check(player.gold > gold_before, "игрок получил золото")
				_check(pet_fought, "питомец участвовал в бою")
				step = 6
				return false
			player.global_position = mob.global_position + Vector3(0, 0, 2.0)
			player.try_attack()
		6:
			player.take_damage(99999, null)
			_check(player.hp == player.max_hp, "игрок возродился с полным HP")
			_check(player.global_position.length() < 1.0, "игрок возродился в центре")
			main.pet.take_damage(99999, null)
			_check(main.pet.is_down, "питомец обессилел")
			wait = 60 * 11
			step = 7
		7:
			_check(not main.pet.is_down, "питомец вернулся через 10 с")
			wait = 60 * 21
			step = 8
		8:
			_check(_count_mobs() == main._slots.size(), "звери респавнятся: %d/%d" % [_count_mobs(), main._slots.size()])
			print("SMOKE TEST OK (кадров: %d)" % frame)
			done = true
			quit(0)
	return false


func _test_touch(hud: HUD) -> void:
	var view: Vector2 = hud._view
	if view.x < 400.0:
		print("Пропуск теста касаний: размер окна %s" % view)
		return
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = Vector2(view.x * 0.2, view.y * 0.6)
	hud._input(t)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = t.position + Vector2(80, 0)
	hud._input(d)
	_check(hud.move_vec.x > 0.5, "джойстик двигает вправо: %s" % hud.move_vec)

	var a := InputEventScreenTouch.new()
	a.index = 1
	a.pressed = true
	a.position = hud._attack_c
	hud._input(a)
	_check(hud._attack_idx == 1 and hud._joy_idx == 0, "мультитач: джойстик + атака")

	t.pressed = false
	hud._input(t)
	a.pressed = false
	hud._input(a)
	_check(hud._joy_idx == -1 and hud._attack_idx == -1, "касания отпущены")


func _find_mob(mob_name: String) -> Mob:
	var best: Mob = null
	for n in get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.mob_name == mob_name:
			if best == null or m.global_position.length() < best.global_position.length():
				best = m
	return best


func _mob_ok() -> bool:
	return is_instance_valid(mob) and not mob.is_dead


func _count_mobs() -> int:
	return get_nodes_in_group("mobs").size()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[OK] " + what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	if done:
		return
	printerr("[FAIL] " + what)
	done = true
	quit(1)
