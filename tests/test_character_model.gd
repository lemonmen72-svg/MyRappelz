extends "res://tests/test_base.gd"
## Аниме-модель персонажа (CharacterModel): собирается для всех 6 сочетаний раса/класс,
## у эльфов есть уши, у каждого класса — своё оружие, бюджет мешей и вызовов отрисовки
## (детали склеены в меш со скелетом), кости скелета повторяют узлы, анимации без ошибок.
## Модель игрока и торговца — CharacterModel; экран создания строит 3D-превью.

## Узлы оружия, которые должны быть у модели (по полю weapon класса).
const WEAPON_PARTS := {
	"axe": ["Axe"],
	"bow": ["Bow", "Quiver"],
	"sword_shield": ["Sword", "Shield"],
	"staff": ["Staff", "Orb"],
	"daggers": ["DaggerR", "DaggerL"],
}
## Body (освещаемое), Glow (свечение, если есть), Face — и запас.
const MAX_MESHES := 4
## Поверхностей = вызовов отрисовки без контура (контур +1 на Body).
const MAX_SURFACES := 5

var models: Array[CharacterModel] = []
var create: CharacterCreate = null


func run_step() -> void:
	match step:
		0:
			var x := -9.0
			for cid in ClassData.CLASSES:
				var c := ClassData.cls(String(cid))
				var rid := String(c["race"])
				var wk := String(c["weapon"])
				var m := CharacterModel.new()
				m.setup(CharacterModel.spec_for(rid, String(cid)))
				main.add_child(m)
				m.position = Vector3(x, 0.0, 30.0)
				x += 3.0
				models.append(m)
				var who := "%s/%s" % [rid, String(cid)]
				check(m.weapon_kind == wk, "%s: оружие %s" % [who, wk])
				for part in WEAPON_PARTS[wk]:
					check(m.find_child(String(part), true, false) != null, "%s: есть %s" % [who, String(part)])
				var elf: bool = ClassData.race(rid)["ears"]
				check(m.has_ears() == elf, "%s: уши %s" % [who, "эльфа" if elf else "человека"])
				var n := m.mesh_count()
				check(n >= 2 and n <= MAX_MESHES, "%s: мешей %d (до %d)" % [who, n, MAX_MESHES])
				var sc := m.surface_count()
				check(sc >= 2 and sc <= MAX_SURFACES, "%s: поверхностей %d (до %d)" % [who, sc, MAX_SURFACES])
				_check_skin(m, who)
				var head := m.find_child("Head", true, false) as Node3D
				check(head != null, "%s: есть голова" % who)
				var hy := head.global_position.y
				check(hy > 1.45 and hy < 1.75, "%s: голова на высоте %.2f м (рост ~1.8 м)" % [who, hy])
				check(m.find_child("Face", true, false) != null, "%s: есть лицо" % who)
				m.set_move_speed(6.5)
				m.play_attack()
			wait = 20
			step = 1
		1:
			for m in models:
				_check_bones(m)
				m.play_hit()
				m.play_cast()
				m.set_move_speed(0.0)
			wait = 20
			step = 2
		2:
			for m in models:
				m.play_shoot()
				m.play_bash()
				m.play_buff()
			wait = 15
			step = 3
		3:
			for m in models:
				m.play_spin()
			wait = 40
			step = 4
		4:
			for m in models:
				check(is_zero_approx(m.rotation.y), "после кругового удара модель развёрнута обратно")
				m.play_wave()
			wait = 10
			step = 5
		5:
			var player: Player = main.player
			check(player._model is CharacterModel, "у игрока модель CharacterModel")
			check(player._guard_fx != null and player._guard_fx.get_parent() == player._model,
				"сияние «Щита света» на модели игрока")
			var mer: Merchant = main.economy.merchant
			check(mer._model is CharacterModel and mer._model.weapon_kind == "",
				"торговец — CharacterModel без оружия")
			check(mer._model.mesh_count() <= MAX_MESHES, "мешей у торговца: %d" % mer._model.mesh_count())
			check(mer._model.surface_count() <= MAX_SURFACES, "поверхностей у торговца: %d" % mer._model.surface_count())
			_check_skin(mer._model, "торговец")
			# Урон по игроку запускает анимацию получения урона без ошибок
			player.take_damage(1, null)
			player.hp = player.max_hp
			for m in models:
				m.queue_free()
			models.clear()
			create = CharacterCreate.new()
			get_tree().root.add_child(create)
			wait = 5
			step = 6
		6:
			check(create._preview_model != null and is_instance_valid(create._preview_model),
				"экран создания: 3D-превью построено")
			create._select_race("dark_elf")
			create._select_class("warlock")
			wait = 5
			step = 7
		7:
			var pm: CharacterModel = create._preview_model
			check(pm != null and pm.weapon_kind == "staff" and pm.has_ears(), "превью обновилось: чернокнижник")
			create.queue_free()
			ok_done()


## Склеенный меш привязан к скелету: связка на каждую кость, в вершинах есть кости и веса.
func _check_skin(m: CharacterModel, who: String) -> void:
	var skel := m.find_child("Skeleton", false, false) as Skeleton3D
	check(skel != null and skel.get_bone_count() >= 10, "%s: скелет с костями" % who)
	var body := m.find_child("Body", true, false) as MeshInstance3D
	check(body != null and body.mesh != null and body.skin != null, "%s: меш Body со связкой" % who)
	if skel == null or body == null or body.mesh == null or body.skin == null:
		return
	check(body.skin.get_bind_count() == skel.get_bone_count(), "%s: связка на каждую кость" % who)
	var fmt := (body.mesh as ArrayMesh).surface_get_format(0)
	check((fmt & Mesh.ARRAY_FORMAT_BONES) != 0 and (fmt & Mesh.ARRAY_FORMAT_WEIGHTS) != 0
		and (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0, "%s: в вершинах кости, веса и цвет" % who)
	var face := m.find_child("Face", true, false) as MeshInstance3D
	check(face != null and face.skin != null, "%s: лицо привязано к скелету" % who)


## Позы костей скелета совпадают с узлами-костями (после анимации нескольких кадров).
func _check_bones(m: CharacterModel) -> void:
	m._sync_bones()
	var skel: Skeleton3D = m._skel
	var worst := 0.0
	for i in m._bone_nodes.size():
		var want := _model_xf(m, m._bone_nodes[i])
		var got := skel.get_bone_global_pose(i)
		worst = maxf(worst, want.origin.distance_to(got.origin))
		worst = maxf(worst, (want.basis * Vector3.UP).distance_to(got.basis * Vector3.UP))
		worst = maxf(worst, (want.basis * Vector3.FORWARD).distance_to(got.basis * Vector3.FORWARD))
	check(worst < 0.002, "кости скелета повторяют узлы (отклонение %.4f)" % worst)


## Трансформ узла относительно модели.
func _model_xf(m: CharacterModel, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node3D = n
	while p != null and p != m:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t
