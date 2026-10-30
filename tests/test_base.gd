extends SceneTree
## Основа автотестов (без экрана). Создаёт нового персонажа, запускает main.tscn и каждый кадр
## вызывает run_step(), пока не вызван ok_done() или fail(). Пропуск кадров: wait = N.
## Наследник: extends "res://tests/test_base.gd", переопределяет run_step() и при нужде
## race_class() / before_start(). Запуск: godot --headless --fixed-fps 60 --path . -s tests/<файл>.gd

const MAX_FRAMES := 60 * 300

var main: Node
var game: Node
var frame := 0
var step := 0
var wait := 0
var done := false
var last_msg := ""


## [раса, класс] персонажа для теста.
func race_class() -> Array:
	return ["human", "warrior"]


## Вызывается после создания персонажа, до запуска мира (можно выдать предметы, питомцев).
func before_start() -> void:
	pass


## Шаг сценария, вызывается каждый кадр. Используйте step, wait, check(), ok_done().
func run_step() -> void:
	ok_done()


func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.delete_save()
	var rc := race_class()
	game.new_character("Тест", rc[0], rc[1])
	before_start()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	if done:
		return true
	frame += 1
	if frame > MAX_FRAMES:
		fail("таймаут на шаге %d" % step)
		return true
	log_messages()
	if wait > 0:
		wait -= 1
		return false
	run_step()
	return false


func ok_done() -> void:
	if done:
		return
	print("TEST OK (кадров: %d)" % frame)
	done = true
	game.delete_save()
	quit(0)


func check(ok: bool, what: String) -> void:
	if ok:
		print("[OK] " + what)
	else:
		fail(what)


func fail(what: String) -> void:
	if done:
		return
	printerr("[FAIL] " + what)
	done = true
	quit(1)


## Печатает новые сообщения HUD в лог теста.
func log_messages() -> void:
	if main == null or main.get("hud") == null:
		return
	var t: String = main.hud._msg_label.text
	if t != last_msg:
		last_msg = t
		print("  HUD: " + t)


## Ближайший к центру живой зверь вида type_id.
func find_mob(type_id: String) -> Mob:
	var best: Mob = null
	for n in get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.type_id == type_id:
			if best == null or m.global_position.length() < best.global_position.length():
				best = m
	return best


func mob_ok(m: Mob) -> bool:
	return is_instance_valid(m) and not m.is_dead


## Ставит игрока рядом со зверем (в радиусе атаки зверя, чтобы тот не бегал) и держит HP полным.
func stand_near(m: Mob, dist: float = 1.5) -> void:
	var p: Player = main.player
	p.global_position = m.global_position + Vector3(0, 0, dist)
	p.hp = p.max_hp


func count_mobs() -> int:
	return get_nodes_in_group("mobs").size()


## Касание экрана для HUD: pressed, индекс пальца, позиция.
func touch(pressed: bool, index: int, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = pos
	main.hud._input(t)


## Центр круглой кнопки HUD на экране.
func button_center(id: String) -> Vector2:
	var p: Panel = main.hud._buttons[id]["panel"]
	return p.position + p.size / 2.0
