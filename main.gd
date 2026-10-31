extends Node3D
## Главная сцена: создание персонажа (если нет сохранения), затем мир (тренировочный остров
## из конфига world/training_island.json), игрок в деревне своей расы, звери по зонам,
## модули (питомцы, приручение, предметы, окно героя, задания, NPC) и интерфейс. Кнопки умений skill1…skill4
## показывают умения, назначенные в окне героя (Game.hero.slots); неподходящие оружию — затемнены с подсказкой.
## Учитель Кирк (NPC с разговором, заданиями и картами существ) стоит в центре города рядом с торговцем (Npcs).

const RESPAWN_TIME := 20.0
const AUTOSAVE_TIME := 30.0
## Камера от третьего лица: вращается вокруг игрока (перетаскивание по правой части экрана).
const CAM_DIST := 12.4
## Приближение камеры (щипок двумя пальцами, колесо мыши): от CAM_DIST_MIN до CAM_DIST_MAX, м.
const CAM_DIST_MIN := 3.0
const CAM_DIST_MAX := 22.0
const CAM_LOOK_Y := 1.2
## Вблизи камера смотрит на уровень груди и головы, а не пояса.
const CAM_LOOK_Y_NEAR := 1.45
const CAM_PITCH_MIN := deg_to_rad(18.0)
const CAM_PITCH_MAX := deg_to_rad(75.0)
## Чувствительность вращения камеры, радиан на пиксель.
const CAM_SENS := 0.006
## Кнопки умений: центр от правого нижнего угла, радиус, цвет.
const SKILL_BUTTONS := [
	["skill1", Vector2(330, 110), 55.0, Color(0.9, 0.55, 0.15, 0.45)],
	["skill2", Vector2(310, 270), 55.0, Color(0.6, 0.3, 0.9, 0.45)],
	["skill3", Vector2(440, 330), 50.0, Color(0.85, 0.3, 0.45, 0.45)],
	["skill4", Vector2(270, 400), 50.0, Color(0.25, 0.6, 0.8, 0.45)],
]
## Цвет кнопки включённого переключаемого умения.
const TOGGLE_ON_COLOR := Color(0.3, 0.85, 0.45, 0.6)

var player: Player
var hud: HUD
var cam: Camera3D
var pets: PetManager
var taming: Taming
var economy: Economy
var world: IslandWorld
## Задания (журнал, трекер, события) и жители-NPC (Учитель Кирк, диалоги).
var quests: Quests
var npcs: Npcs
## Окно героя (характеристики, оружие, древо умений).
var hero_window: CharacterWindow
## Поворот камеры вокруг игрока (0 — смотрим на север) и наклон над горизонтом.
var cam_yaw := 0.0
var cam_pitch := atan2(9.0, 8.5)
var cam_dist := CAM_DIST

var _slots: Array = []
var _rng := RandomNumberGenerator.new()
var _started := false
var _autosave := 0.0
var _transition_cd := 0.0


func _ready() -> void:
	_rng.seed = 1234
	Quality.apply_resolution(get_tree())
	Quality.apply_fps()
	get_tree().node_added.connect(_on_node_added)
	if Game.has_character or Game.load_game():
		_start_world()
		return
	var cc := CharacterCreate.new()
	add_child(cc)
	cc.created.connect(func(n: String, r: String, c: String):
		Game.new_character(n, r, c)
		cc.queue_free()
		_start_world())


func _start_world() -> void:
	_build_world()
	_build_hud()
	_build_player()
	_build_modules()
	_build_slots()
	for i in _slots.size():
		_spawn_slot(i)
	hud.update_player(player)
	refresh_skill_buttons()
	Game.changed.connect(func():
		hud.update_player(player)
		refresh_skill_buttons())
	_started = true
	# Старое сохранение переведено (герой стал Наёмником): сказать игроку и сохранить уже в новом виде
	if Game.load_note != "":
		hud.show_message(Game.load_note, 8.0)
		Game.load_note = ""
	Game.save_game()


func _build_world() -> void:
	world = IslandWorld.new()
	world.name = "Island"
	add_child(world)
	world.build(_rng)
	add_child(PostFx.new())
	Quality.apply(get_tree())


## Каждый новый меш в игре получает аниме-стиль (toon-свет и контур). Отложенно, чтобы
## код, создавший меш, успел назначить материал.
func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D:
		Util.toonify_mesh.call_deferred(n)


func _build_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.action.connect(_on_action)
	# Центры кнопок отсчитываются от правого нижнего угла экрана
	hud.add_button("attack", "Атака", Vector2(170, 180), 85.0, Color(0.9, 0.2, 0.2, 0.45), true)
	for b in SKILL_BUTTONS:
		hud.add_button(String(b[0]), "", b[1], float(b[2]), b[3])
	hud.add_button("tame", "Приручить", Vector2(130, 345), 48.0, Color(0.2, 0.7, 0.3, 0.45))
	hud.add_button("potion", "Зелье", Vector2(470, 80), 45.0, Color(0.85, 0.15, 0.3, 0.45))
	hud.add_button("shop", "Торговец", Vector2(480, 210), 50.0, Color(0.85, 0.7, 0.2, 0.45))
	hud.set_button_visible("shop", false)
	hud.add_button("talk", "Говорить", Vector2(590, 150), 50.0, Color(0.95, 0.6, 0.25, 0.45))
	hud.set_button_visible("talk", false)


func _build_player() -> void:
	player = Player.new()
	player.position = world.spawn_point(Game.race_id)
	add_child(player)
	player.stats_changed.connect(func():
		hud.update_player(player)
		refresh_skill_buttons())
	player.message.connect(func(t: String): hud.show_message(t))
	player.target_changed.connect(func(t: Node3D): hud.set_target(t))

	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.global_position = player.global_position + _cam_offset()
	cam.current = true


func _build_modules() -> void:
	economy = Economy.new()
	add_child(economy)
	economy.setup(self)
	taming = Taming.new()
	add_child(taming)
	taming.setup(self)
	pets = PetManager.new()
	add_child(pets)
	pets.setup(self)
	hero_window = CharacterWindow.new()
	hero_window.name = "CharacterWindow"
	add_child(hero_window)
	hero_window.setup(self)
	quests = Quests.new()
	quests.name = "Quests"
	add_child(quests)
	quests.setup(self)
	npcs = Npcs.new()
	npcs.name = "Npcs"
	add_child(npcs)
	npcs.setup(self)


func _build_slots() -> void:
	_slots = world.mob_slots(_rng)


func _spawn_slot(i: int) -> void:
	var s: Dictionary = _slots[i]
	var m := Mob.new()
	m.setup(s["type"], i, s["pos"], int(s.get("level", -1)))
	m.gone.connect(_on_mob_gone)
	add_child(m)


func _on_mob_gone(mob: Mob, killed: bool) -> void:
	if killed:
		player.gain_xp(mob.xp_reward)
		Util.float_text(self, mob.global_position + Vector3(0, 3.4, 0), "+%d оп." % mob.xp_reward, Color(0.6, 0.9, 1))
		pets.on_mob_killed(mob)
		taming.on_mob_killed(mob)
		economy.on_mob_killed(mob)
		quests.on_mob_killed(mob)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_spawn_slot.bind(mob.slot))


func _on_action(id: String) -> void:
	match id:
		"attack":
			pass  # удержание обрабатывается в _process
		"skill1", "skill2", "skill3", "skill4":
			player.use_skill(id)
		"hero_window":
			if hero_window.is_open():
				hud.close_window()
			else:
				hero_window.open()
		"settings_window":
			SettingsMenu.open(hud)
		_:
			if quests.handle_action(id):
				return
			if npcs.handle_action(id):
				return
			if pets.handle_action(id):
				return
			if taming.handle_action(id):
				return
			economy.handle_action(id)


func _process(delta: float) -> void:
	if not _started:
		return

	# Камера: перетаскивание по экрану вне кнопок и джойстика
	var drag := hud.take_camera_drag()
	cam_yaw -= drag.x * CAM_SENS
	cam_pitch = clampf(cam_pitch + drag.y * CAM_SENS, CAM_PITCH_MIN, CAM_PITCH_MAX)
	cam_dist = clampf(cam_dist * hud.take_camera_zoom(), CAM_DIST_MIN, CAM_DIST_MAX)

	# Движение относительно камеры: «вверх» на джойстике — от камеры вперёд
	var mv := hud.move_vec
	if mv.length() < 0.15:
		mv = Vector2.ZERO
	var dir := Vector3(mv.x, 0.0, mv.y).rotated(Vector3.UP, cam_yaw)
	player.move_input = Vector2(dir.x, dir.z)
	if hud.is_held("attack"):
		player.try_attack()
	for b in SKILL_BUTTONS:
		var bid := String(b[0])
		hud.set_cooldown(bid, player.cooldown_frac(bid))

	var want := player.global_position + _cam_offset()
	# Не прятать камеру в холм
	var ground := world.height_at(want.x, want.z) + 1.0
	if want.y < ground:
		want.y = ground
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-8.0 * delta))
	cam.look_at(player.global_position + Vector3(0, _cam_look_y(), 0), Vector3.UP)

	_check_transitions(delta)

	_autosave += delta
	if _autosave >= AUTOSAVE_TIME:
		_autosave = 0.0
		Game.save_game()


## Подписи, видимость и вид кнопок умений по назначенным умениям (Game.hero.slots) и надетому оружию:
## пустая кнопка скрыта, неподходящая оружию — затемнена с подсказкой, включённое переключаемое — зелёная.
func refresh_skill_buttons() -> void:
	if hud == null or player == null:
		return
	for b in SKILL_BUTTONS:
		var bid := String(b[0])
		var sid := player.skill_id(bid)
		hud.set_button_visible(bid, sid != "")
		if sid == "":
			continue
		var sk := HeroSkills.get_skill(sid)
		var text := String(sk.get("name", sid))
		var why := player.slot_block(bid)
		hud.set_blocked(bid, why != "")
		if why != "":
			text += "\n(" + why.to_lower() + ")"
		var on := HeroSkills.kind(sid) == "toggle" and HeroSkills.toggle_on(Game.hero, sid)
		hud.set_button_color(bid, TOGGLE_ON_COLOR if on else hud.button_color(bid))
		hud.set_button_text(bid, text)


func _cam_offset() -> Vector3:
	return Vector3(0.0, sin(cam_pitch), cos(cam_pitch)).rotated(Vector3.UP, cam_yaw) * cam_dist


## Высота точки, куда смотрит камера: вблизи — на уровне груди и головы.
func _cam_look_y() -> float:
	var near := clampf((CAM_DIST - cam_dist) / (CAM_DIST - CAM_DIST_MIN), 0.0, 1.0)
	return lerpf(CAM_LOOK_Y, CAM_LOOK_Y_NEAR, near)


## Переходы из конфига (порт → материк): пока заглушка с сообщением.
func _check_transitions(delta: float) -> void:
	_transition_cd = maxf(0.0, _transition_cd - delta)
	if _transition_cd > 0.0:
		return
	for t in world.transitions():
		var tr: Dictionary = t
		var c := IslandWorld.v2(tr["center"])
		if Vector2(player.global_position.x, player.global_position.z).distance_to(c) < float(tr.get("radius", 3.0)):
			hud.show_message(String(tr.get("message", "Переход пока закрыт")))
			_transition_cd = 4.0
			return
