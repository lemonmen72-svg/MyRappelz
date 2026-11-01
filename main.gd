extends Node3D
## Главная сцена. Порядок экранов при запуске: пакет ресурсов (AssetLoader, если нужен) → вход в аккаунт
## (LoginScreen) → выбор персонажа из 4 слотов аккаунта (CharacterSelect) → создание, если слот пуст
## (CharacterCreate: раса → профессии расы → пол → ник) → мир. Уже есть герой (Game.has_character — автотесты) —
## сразу мир. «Сменить персонажа / выйти из аккаунта» в настройках — back_to_menu (сохранение, новая сцена с экраном
## выбора персонажа). Затем мир (тренировочный остров
## из конфига world/training_island.json), игрок в деревне своей расы, звери по зонам,
## модули (питомцы, приручение, предметы, окно героя, задания, NPC, выбор профессии) и интерфейс. Кнопки умений
## skill1…skill4 показывают умения, назначенные в окне героя (Game.hero.slots); неподходящие оружию — затемнены
## с подсказкой; у Бродяги умений нет — кнопки скрыты.
## Жители-NPC (Npcs): Учитель Кирк (задания, карты существ), мудрец, кузнец и кладовщик в центре города рядом
## с торговцем, старосты в деревнях рас, охотница в Западном лагере, глава наёмников у входа в пещеру.

## Возрождение зверя — MobData.respawn_time (обычные 20 с, боссы 6–10 мин).
const RESPAWN_TIME := MobData.RESPAWN_TIME
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
## Круглые кнопки HUD: центр от правого нижнего угла и радиус — для «Среднего» размера интерфейса
## (HUD умножает на UiScale.k()). Атака в углу, умения дугой вокруг неё (зазоры ≥ 10 px), выше — «Приручить»,
## левее — «Зелье», «Торговец», «Говорить». Было: атака r 85, умения r 50–55, остальные r 45–50.
const ATTACK_BUTTON := [Vector2(120, 120), 60.0]
## Кнопки умений: центр от правого нижнего угла, радиус, цвет.
const SKILL_BUTTONS := [
	["skill1", Vector2(243, 107), 37.0, Color(0.9, 0.55, 0.15, 0.45)],
	["skill2", Vector2(223, 189), 37.0, Color(0.6, 0.3, 0.9, 0.45)],
	["skill3", Vector2(154, 239), 35.0, Color(0.85, 0.3, 0.45, 0.45)],
	["skill4", Vector2(70, 233), 35.0, Color(0.25, 0.6, 0.8, 0.45)],
]
## Остальные круглые кнопки: [id, подпись, центр, радиус, цвет].
const OTHER_BUTTONS := [
	["tame", "Приручить", Vector2(60, 330), 34.0, Color(0.2, 0.7, 0.3, 0.45)],
	["potion", "Зелье", Vector2(340, 62), 32.0, Color(0.85, 0.15, 0.3, 0.45)],
	["shop", "Торговец", Vector2(330, 170), 34.0, Color(0.85, 0.7, 0.2, 0.45)],
	["talk", "Говорить", Vector2(420, 110), 34.0, Color(0.95, 0.6, 0.25, 0.45)],
]
## Кнопки команд питомца (HUD.add_pet_button — в ряд под панелью питомца, видны при призванном питомце):
## [id, подпись, цвет]. «Авто» — сам нападает на зверей рядом, «Атака» — бьёт выделенную цель героя, «Защита» —
## бьёт напавших на героя и его цель, «За мной» — следует без боя (PetManager, Pet.set_mode).
const PET_BUTTONS := [
	["pet_auto", "Авто", Color(0.3, 0.6, 0.95, 0.45)],
	["pet_attack", "Атака", Color(0.9, 0.3, 0.25, 0.45)],
	["pet_defend", "Защита", Color(0.35, 0.7, 0.45, 0.45)],
	["pet_follow", "За мной", Color(0.75, 0.6, 0.35, 0.45)],
]
## Цвет кнопки включённого переключаемого умения.
const TOGGLE_ON_COLOR := Color(0.3, 0.85, 0.45, 0.6)
## Значки круглых кнопок без своего источника (IconView): облачко речи, мешочек торговца.
## Умения — значок умения, «Атака» — надетое оружие, «Зелье» — зелье с числом, «Приручить» — карта существа цели.
const BUTTON_ICONS := {
	"talk": {"shape": "talk", "color": Color(0.95, 0.6, 0.25)},
	"shop": {"shape": "shop", "color": Color(0.85, 0.7, 0.2)},
	"pet_auto": {"shape": "pet_auto", "color": Color(0.45, 0.7, 1.0)},
	"pet_attack": {"shape": "pet_attack", "color": Color(1.0, 0.4, 0.3)},
	"pet_defend": {"shape": "pet_defend", "color": Color(0.35, 0.65, 0.45)},
	"pet_follow": {"shape": "pet_follow", "color": Color(0.85, 0.68, 0.4)},
}
## Карта на кнопке «Приручить», пока у цели своей карты нет.
const TAME_ICON_CARD := "card_panther"

var player: Player
var hud: HUD
var cam: Camera3D
var pets: PetManager
var taming: Taming
var economy: Economy
var world: IslandWorld
## Задания (журнал, трекер, события) и жители-NPC (расстановка, диалоги).
var quests: Quests
var npcs: Npcs
## Окно героя (характеристики, оружие, древо умений).
var hero_window: CharacterWindow
## Окно выбора первой профессии (сдача задания мудреца).
var job_window: JobWindow
## Поворот камеры вокруг игрока (0 — смотрим на север) и наклон над горизонтом.
var cam_yaw := 0.0
var cam_pitch := atan2(9.0, 8.5)
var cam_dist := CAM_DIST

## Экран до мира (вход, выбор или создание персонажа; null — мир).
var screen: Node = null

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
	# Пакет ресурсов (модели героев профессий, стадии зверей) — до первого обращения к моделям.
	# В редакторе и автотестах ресурсы встроены (Assets.available) — экрана нет, всё как раньше.
	if not Assets.available() and not Assets.skipped:
		var loader := AssetLoader.new()
		add_child(loader)
		loader.finished.connect(func(_with_pack: bool) -> void:
			loader.queue_free()
			_begin())
		return
	_begin()


## Вход в аккаунт, выбор или создание персонажа, затем мир (после пакета ресурсов). Герой уже есть — сразу мир.
func _begin() -> void:
	if Game.has_character:
		_start_world()
		return
	if Accounts.is_logged_in():
		show_select()
	else:
		show_login()


func _set_screen(n: Node) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = n
	if n != null:
		add_child(n)


## Экран входа: логин (последний подставлен), «Войти» / «Создать аккаунт».
func show_login() -> void:
	var ls := LoginScreen.new()
	_set_screen(ls)
	ls.logged_in.connect(show_select)


## Выбор персонажа (4 слота аккаунта). Сохранение до аккаунтов (user://save.json) у аккаунта без персонажей
## становится слотом 1 (Accounts.migrate_legacy).
func show_select() -> void:
	var moved := Accounts.migrate_legacy()
	var cs := CharacterSelect.new()
	if moved >= 0:
		cs.note = "Прежний герой перенесён в слот %d" % (moved + 1)
	_set_screen(cs)
	cs.play.connect(_on_play_slot.bind(cs))
	cs.create.connect(show_create)
	cs.switch_account.connect(_on_switch_account)


## «Играть»: загрузить героя слота i и войти в мир.
func _on_play_slot(i: int, cs: CharacterSelect) -> void:
	if not Game.load_slot(i):
		cs.show_error("Не удалось загрузить персонажа")
		return
	_set_screen(null)
	_start_world()


## «Сменить аккаунт»: выход и экран входа.
func _on_switch_account() -> void:
	Accounts.logout()
	AdminPanel.reset_session()
	show_login()


## Создание персонажа в слоте i: раса → профессии → пол → ник; «Назад» с первого шага — к выбору персонажа.
func show_create(i: int) -> void:
	var cc := CharacterCreate.new()
	_set_screen(cc)
	cc.cancelled.connect(show_select)
	cc.created.connect(_on_created.bind(i))


## Герой создан (CharacterCreate): новый Бродяга в слоте i, мир.
func _on_created(n: String, r: String, g: String, i: int) -> void:
	Game.new_character(n, r, ClassData.WANDERER, g)
	Game.enter_slot(i)
	_set_screen(null)
	_start_world()


## «Сменить персонажа / выйти из аккаунта» (настройки): сохранить героя, забыть его и запустить сцену заново —
## откроется выбор персонажа (аккаунт остаётся). Возвращает новую главную сцену (тесты).
func back_to_menu() -> Node:
	Game.leave_slot()
	AdminPanel.reset_session()
	JobFxNeophyte.corpses.clear()
	var fresh: Node = load("res://main.tscn").instantiate()
	var p := get_parent()
	var was_current := get_tree().current_scene == self
	var tree := get_tree()
	_started = false
	# До удаления (конец кадра) старая сцена не обновляется: герой уже забыт (Game.leave_slot)
	process_mode = Node.PROCESS_MODE_DISABLED
	if hud != null:
		hud.visible = false
	queue_free()
	p.add_child.call_deferred(fresh)
	if was_current:
		(func() -> void: tree.current_scene = fresh).call_deferred()
	return fresh


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
	hud.add_button("attack", "Атака", ATTACK_BUTTON[0], float(ATTACK_BUTTON[1]), Color(0.9, 0.2, 0.2, 0.45), true)
	for b in SKILL_BUTTONS:
		hud.add_button(String(b[0]), "", b[1], float(b[2]), b[3])
	for b in OTHER_BUTTONS:
		hud.add_button(String(b[0]), String(b[1]), b[2], float(b[3]), b[4])
	for b in PET_BUTTONS:
		hud.add_pet_button(String(b[0]), String(b[1]), b[2])
	hud.set_button_visible("shop", false)
	hud.set_button_visible("talk", false)
	for id in BUTTON_ICONS:
		hud.set_button_icon(String(id), BUTTON_ICONS[id])
	refresh_tame_icon(null)


func _build_player() -> void:
	player = Player.new()
	player.position = world.spawn_point(Game.race_id)
	add_child(player)
	player.stats_changed.connect(func():
		hud.update_player(player)
		refresh_skill_buttons())
	player.message.connect(func(t: String): hud.show_message(t))
	player.target_changed.connect(func(t: Node3D):
		hud.set_target(t)
		refresh_tame_icon(t))

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
	job_window = JobWindow.new()
	job_window.name = "JobWindow"
	add_child(job_window)
	job_window.setup(self)


func _build_slots() -> void:
	_slots = world.mob_slots(_rng)


func _spawn_slot(i: int) -> void:
	# Слот уже занят живым зверем (админ-панель возродила зверей раньше таймера) — второго не ставим
	for n in get_tree().get_nodes_in_group("mobs"):
		var o := n as Mob
		if o != null and o.slot == i:
			return
	var s: Dictionary = _slots[i]
	spawn_mob(String(s["type"]), int(s.get("level", -1)), s["pos"], i)


## Поставить зверя (или босса) вида type_id уровня lvl (≤ 0 — базовый уровень вида) в точку pos. slot — слот
## зверей острова (после смерти возрождается через MobData.respawn_time), −1 — поставлен вручную (админ-панель,
## тесты): не возрождается. Убийство — как обычно (опыт, добыча, задания).
func spawn_mob(type_id: String, lvl: int, pos: Vector3, slot: int = -1) -> Mob:
	var m := Mob.new()
	m.setup(type_id, slot, pos, lvl)
	m.gone.connect(_on_mob_gone)
	add_child(m)
	return m


func _on_mob_gone(mob: Mob, killed: bool) -> void:
	if killed:
		# Опыт: награда зверя × разница уровней (Combat.xp_for) × множитель админ-панели (Game.xp_mult; ×1 — обычно)
		var gained := Combat.xp_for(mob.xp_reward, mob.level, Game.level)
		player.gain_xp(gained)
		Util.float_text(self, mob.global_position + Vector3(0, 3.4, 0), "+%d оп." % gained, Color(0.6, 0.9, 1))
		pets.on_mob_killed(mob)
		taming.on_mob_killed(mob)
		economy.on_mob_killed(mob)
		quests.on_mob_killed(mob)
		# Тело зверя для умений Неофита («Последний вздох», «Остаток силы»)
		JobFxNeophyte.on_mob_killed(mob)
		# Победа над боссом — эмоция героя
		if mob.is_boss:
			player.play_emote("boss")
	# Звери, поставленные админ-панелью (slot -1), не возрождаются
	if mob.slot >= 0:
		get_tree().create_timer(MobData.respawn_time(mob.type_id)).timeout.connect(_spawn_slot.bind(mob.slot))


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
	# Полоса каста умения героя (название, сколько осталось)
	if player.casting != "":
		hud.update_cast(String(HeroSkills.get_skill(player.casting).get("name", player.casting)), player.cast_progress(),
			player.cast_total - player.cast_elapsed)
	else:
		hud.update_cast("", 0.0, 0.0)

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


## Подписи, значки, видимость и вид кнопок умений по назначенным умениям (Game.hero.slots) и надетому оружию:
## пустая кнопка скрыта, неподходящая оружию — затемнена с подсказкой (и красной меткой на значке),
## включённое переключаемое — зелёная. На «Атаке» — значок надетого оружия (без оружия — меч).
func refresh_skill_buttons() -> void:
	if hud == null or player == null:
		return
	if Game.weapon != "":
		hud.set_button_icon("attack", IconView.item(Game.weapon))
	else:
		hud.set_button_icon("attack", IconView.shape("sword", Color(0.85, 0.85, 0.95)))
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
		hud.set_button_icon(bid, IconView.hero_skill(sid))


## Значок «Приручить»: карта существа вида цели (если у вида есть карта), иначе базовая карта.
func refresh_tame_icon(t: Node3D) -> void:
	if hud == null:
		return
	var card := TAME_ICON_CARD
	if t != null and is_instance_valid(t) and t.get("type_id") is String:
		var own := "card_" + String(t.get("type_id"))
		if not ItemData.get_item(own).is_empty():
			card = own
	hud.set_button_icon("tame", IconView.item(card))


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
