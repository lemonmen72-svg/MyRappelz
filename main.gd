extends Node3D
## Главная сцена: строит мир, игрока, зверей и интерфейс из кода.

var MOB_TYPES := [
	{"name": "Кабан", "level": 1, "hp": 30, "atk": 5, "speed": 3.0, "xp": 12, "color": Color(0.55, 0.35, 0.2), "scale": 0.9},
	{"name": "Волк", "level": 3, "hp": 50, "atk": 9, "speed": 4.4, "xp": 25, "color": Color(0.5, 0.5, 0.55), "scale": 1.0},
	{"name": "Медведь", "level": 6, "hp": 130, "atk": 16, "speed": 3.0, "xp": 70, "color": Color(0.3, 0.2, 0.15), "scale": 1.5},
]

# [тип зверя, количество, мин. радиус от центра, макс. радиус]
var SPAWNS := [
	[0, 8, 10.0, 24.0],
	[1, 6, 24.0, 38.0],
	[2, 4, 38.0, 55.0],
]

const RESPAWN_TIME := 20.0

var player: Player
var pet: Pet = null
var hud: HUD
var cam: Camera3D

var _slots: Array = []
var _tame_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1234
	_build_world()
	_build_hud()
	_build_player()
	_build_slots()
	for i in _slots.size():
		_spawn_slot(i)
	hud.update_player(player)
	hud.update_pet(null)


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(200, 1, 200)
	gcol.shape = gshape
	gcol.position.y = -0.5
	ground.add_child(gcol)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	gm.mesh = plane
	gm.material_override = Util.mat(Color(0.28, 0.5, 0.25))
	ground.add_child(gm)
	add_child(ground)

	for i in 90:
		var pos := Vector3(_rng.randf_range(-75, 75), 0.0, _rng.randf_range(-75, 75))
		if Vector2(pos.x, pos.z).length() < 6.0:
			continue
		_add_tree(pos)


func _add_tree(pos: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.position = pos
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.35
	cs.height = 2.4
	col.shape = cs
	col.position.y = 1.2
	tree.add_child(col)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.2
	tm.bottom_radius = 0.3
	tm.height = 2.4
	trunk.mesh = tm
	trunk.position.y = 1.2
	trunk.material_override = Util.mat(Color(0.4, 0.27, 0.15))
	tree.add_child(trunk)

	var r := _rng.randf_range(1.1, 1.7)
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	crown.mesh = sm
	crown.position.y = 2.6 + r * 0.4
	crown.material_override = Util.mat(Color(0.12, _rng.randf_range(0.35, 0.5), 0.15))
	tree.add_child(crown)
	add_child(tree)


func _build_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.tame_pressed.connect(_on_tame)


func _build_player() -> void:
	player = Player.new()
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	player.stats_changed.connect(func(): hud.update_player(player))
	player.message.connect(func(t: String): hud.show_message(t))

	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.global_position = player.global_position + Vector3(0, 12, 9.5)
	cam.current = true


func _build_slots() -> void:
	for group in SPAWNS:
		var cnt: int = group[1]
		for i in cnt:
			var ang := _rng.randf() * TAU
			var r := _rng.randf_range(group[2], group[3])
			_slots.append({"type": group[0], "pos": Vector3(cos(ang) * r, 0.1, sin(ang) * r)})


func _spawn_slot(i: int) -> void:
	var s: Dictionary = _slots[i]
	var m := Mob.new()
	m.setup(MOB_TYPES[s["type"]], i, s["pos"])
	m.gone.connect(_on_mob_gone)
	add_child(m)


func _on_mob_gone(mob: Mob, killed: bool) -> void:
	if killed:
		player.gain_xp(mob.xp_reward)
		if pet != null and not pet.is_down:
			pet.gain_xp(int(mob.xp_reward * 0.6))
		var g := randi_range(mob.level * 2, mob.level * 5)
		player.gold += g
		Util.float_text(self, mob.global_position + Vector3(0, 2.8, 0),
			"+%d оп.  +%d зол." % [mob.xp_reward, g], Color(1, 0.9, 0.3))
		hud.update_player(player)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_spawn_slot.bind(mob.slot))


func _on_tame() -> void:
	if _tame_cd > 0.0:
		return
	_tame_cd = 1.5
	if pet != null:
		hud.show_message("У вас уже есть питомец")
		return
	var m := Util.nearest(player, "mobs", 4.5) as Mob
	if m == null:
		hud.show_message("Рядом нет зверя")
		return
	if m.hp > m.max_hp * 0.5:
		hud.show_message("Сначала ослабьте зверя (HP ниже 50%)")
		return
	if randf() > 0.65:
		hud.show_message("Зверь вырвался! Попробуйте ещё раз")
		return

	pet = Pet.new()
	pet.setup(player, m.mob_name, m.color, m.body_scale, m.max_hp,
		int(m.atk * 0.9), maxf(m.speed * 1.4, 5.0))
	pet.position = m.position
	pet.stats_changed.connect(func(): hud.update_pet(pet))
	add_child(pet)
	m.consume()
	hud.update_pet(pet)
	hud.show_message("Вы приручили: %s!" % pet.pet_name)


func _process(delta: float) -> void:
	_tame_cd = maxf(0.0, _tame_cd - delta)

	var mv := hud.move_vec
	if mv.length() < 0.15:
		mv = Vector2.ZERO
	player.move_input = mv
	if hud.attack_held:
		player.try_attack()

	var want := player.global_position + Vector3(0, 12, 9.5)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-8.0 * delta))
	cam.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)
