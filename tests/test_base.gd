extends Node
## Основа автотестов (без экрана). Входит тестовым аккаунтом (test_login(), по умолчанию Dedok_max — с админ-панелью;
## хранилище аккаунтов тестов — TEST_ACCOUNTS, стирается в начале), создаёт нового персонажа в слоте 1 аккаунта
## (Game.enter_slot(0): game.save_path — файл слота), запускает main.tscn (герой есть — сразу мир) и каждый кадр
## вызывает run_step(), пока не вызван ok_done() или fail(). Пропуск кадров: wait = N.
## Наследник: extends "res://tests/test_base.gd", переопределяет run_step() и при нужде
## race_class() / hero_level() / before_start(). Герой с профессией в race_class() (например, ["dark_elf", "assassin"])
## создаётся уже сменившим профессию (Game.new_character); ["human", "wanderer"] — новичок-Бродяга.
## Помощники профессий: become_job(job) — сменить профессию сразу (как админ-панель), learn_skills(ids) — изучить
## умения (JP добавляются). Запуск:
## godot --headless --fixed-fps 60 --path . res://tests/runner.tscn -- res://tests/<файл>.gd

const MAX_FRAMES := 60 * 300
## Хранилище аккаунтов автотестов (Accounts.use_storage): настоящие аккаунты и user://save.json не трогаются.
const TEST_ACCOUNTS := "user://test_accounts/"

var main: Node
var game: Node
var frame := 0
var step := 0
var wait := 0
var done := false
var last_msg := ""


## [раса, профессия] персонажа для теста (профессия — уже получена; "wanderer" — Бродяга).
func race_class() -> Array:
	return ["human", "warrior"]


## Уровень героя в начале теста (JP — как накоплены к этому уровню).
func hero_level() -> int:
	return 1


## Логин тестового аккаунта (создаётся автоматически). Dedok_max — администратор: админ-панель в настройках.
func test_login() -> String:
	return "Dedok_max"


## Вызывается после создания персонажа, до запуска мира (можно выдать предметы, питомцев).
func before_start() -> void:
	pass


## Шаг сценария, вызывается каждый кадр. Используйте step, wait, check(), ok_done().
func run_step() -> void:
	ok_done()


func _ready() -> void:
	game = Game
	Accounts.use_storage(TEST_ACCOUNTS, true)
	var err := Accounts.create(test_login())
	if err != "":
		printerr("[FAIL] тестовый аккаунт: " + err)
	game.slot = -1
	var rc := race_class()
	game.new_character("Тест", rc[0], rc[1])
	game.enter_slot(0)
	var lvl := hero_level()
	if lvl > 1:
		game.level = lvl
		game.hero["jp"] = HeroSkills.default_jp(lvl)
	before_start()
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_delta: float) -> void:
	if done or main == null or not main.is_inside_tree():
		return
	frame += 1
	if frame > MAX_FRAMES:
		fail("таймаут на шаге %d" % step)
		return
	log_messages()
	if wait > 0:
		wait -= 1
		return
	run_step()


func ok_done() -> void:
	if done:
		return
	print("TEST OK (кадров: %d)" % frame)
	done = true
	game.delete_save()
	get_tree().quit(0)


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
	get_tree().quit(1)


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
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.type_id == type_id:
			if best == null or m.global_position.length() < best.global_position.length():
				best = m
	return best


## Без типа у параметра: удалённый зверь (умер и освобождён) с типом Mob дал бы ошибку вызова.
func mob_ok(m: Variant) -> bool:
	return is_instance_valid(m) and not (m as Mob).is_dead


## Ставит игрока рядом со зверем (в радиусе атаки зверя, чтобы тот не бегал) и держит HP полным.
func stand_near(m: Mob, dist: float = 1.5) -> void:
	var p: Player = main.player
	var pos := m.global_position + Vector3(0, 0, dist)
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	p.hp = p.max_hp


func count_mobs() -> int:
	return get_tree().get_nodes_in_group("mobs").size()


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


## Сменить профессию героя сразу (как админ-панель: умения прежней — сброс с возвратом JP, оружие профессии).
func become_job(job: String) -> void:
	game.admin_set_job(job)
	main.player.apply_class()


## Изучить умения ids (по порядку; JP добавляются, нужен уровень game.level) и пересчитать игрока.
func learn_skills(ids: Array) -> void:
	game.hero["jp"] = int(game.hero.get("jp", 0)) + 500
	for id in ids:
		var sid := String(id)
		var why := HeroSkills.learn_block(game.hero, game.class_id, game.level, sid)
		check(HeroSkills.learn(game.hero, game.class_id, game.level, sid), "изучено «%s» %s" % [
			String(HeroSkills.get_skill(sid).get("name", sid)), why])
	main.player.refresh_skills()


## Применить умение по кнопке или id и дождаться конца каста (у мгновенных — то же, что use_skill): оставшееся время
## каста проходит одним тиком каста (Player._tick_cast — тот же путь, что в игре: проверки цели, выпуск, MP,
## перезарядка). true — умение сработало (у каста — и начало, и конец). Каст по шагам — tests/test_skill_cast.gd.
func use_now(p: Player, slot: String) -> bool:
	var ok := p.use_skill(slot)
	if not ok or p.casting == "":
		return ok
	p._tick_cast(p.cast_total - p.cast_elapsed + 0.0001)
	return p.casting == "" and p.cast_ok
