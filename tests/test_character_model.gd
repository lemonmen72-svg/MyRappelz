extends "res://tests/test_base.gd"
## Аниме-модель персонажа (CharacterModel): собирается для всех 6 сочетаний раса/класс,
## у эльфов есть уши, у каждого класса — своё оружие, бюджет мешей и вызовов отрисовки
## (детали склеены в меш со скелетом), кости скелета повторяют узлы, анимации без ошибок.
## Модель игрока и торговца — CharacterModel; экран создания строит 3D-превью.
## Главный герой — модель из файла (glTF): загружается, анимации шага, бега и ударов, меч в руке.

## Узлы оружия, которые должны быть у модели (по полю weapon класса).
const WEAPON_PARTS := {
	"axe": ["Axe"],
	"bow": ["Bow", "Quiver"],
	"sword_shield": ["Sword", "Shield"],
	"sword": ["Sword"],
	"staff": ["Staff", "Orb"],
	"daggers": ["DaggerR", "DaggerL"],
	"dual_swords": ["Sword", "SwordL"],
	"crossbow": ["Crossbow"],
}
## Body (освещаемое), Glow (свечение, если есть), Face — и запас.
const MAX_MESHES := 4
## Поверхностей = вызовов отрисовки без контура (контур +1 на Body).
const MAX_SURFACES := 5

var models: Array[CharacterModel] = []
var create: CharacterCreate = null
var hero: CharacterModel = null


func run_step() -> void:
	match step:
		0:
			# Модели из примитивов (запасной вариант, торговец) — для всех сочетаний
			CharacterModel.use_assets = false
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
			CharacterModel.use_assets = true
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
			_hero_start()
			wait = 30
			step = 50
		50:
			_hero_check_run()
			hero.play_attack()
			wait = 4
			step = 51
		51:
			var slash := hero._anim.current_animation
			check(slash == hero._pick(CharacterModel.ASSET_ACTIONS["slash"])[0],
				"герой: удар играет клип атаки (%s)" % slash)
			hero.set_move_speed(0.0)
			wait = 70
			step = 52
		52:
			check(hero._act_end < 0.0 and hero._loco == "idle", "герой: после удара — стойка покоя")
			check(hero._anim.current_animation == hero._clip("idle"),
				"герой: покой играет клип Idle (%s)" % hero._anim.current_animation)
			_hero_check_pose("в покое")
			# Стоя без дела — подбор добычи
			hero.play_pickup()
			check(hero._anim.current_animation == hero._pick(CharacterModel.ASSET_ACTIONS["pickup"])[0],
				"герой: подбор добычи играет свой клип (%s)" % hero._anim.current_animation)
			# Усиление перебивает подбор; урон во время действия клип не сбивает
			hero.play_buff()
			hero.play_hit()
			wait = 10
			step = 53
		53:
			check(hero._anim.current_animation == hero._pick(CharacterModel.ASSET_ACTIONS["buff"])[0],
				"герой: усиление играет свой клип (%s)" % hero._anim.current_animation)
			hero.play_dash()
			wait = 5
			step = 55
		55:
			check(hero._anim.current_animation == hero._pick(CharacterModel.ASSET_ACTIONS["leap"])[0],
				"герой: умение «Шаг тени» играет клип рывка (%s)" % hero._anim.current_animation)
			hero.queue_free()
			wait = 2
			step = 54
		54:
			var player: Player = main.player
			check(player._model is CharacterModel, "у игрока модель CharacterModel")
			check(player._model._asset != null, "игрок — главный герой из файла")
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
			# Доступна одна профессия — Бродяга: другие расы и классы затемнены («скоро») и не выбираются
			check(create._race == "dark_elf" and create._class == "assassin", "по умолчанию — тёмная эльфийка-Бродяга")
			var hb: Button = create._race_btns["human"]
			check(hb.disabled and hb.text.contains("скоро"), "раса «Люди» затемнена: %s" % hb.text)
			check(not (create._race_btns["dark_elf"] as Button).disabled, "тёмные эльфы доступны")
			var wl: Button = null
			for b in create._class_box.get_children():
				if (b as Button).text.begins_with("Чернокнижник"):
					wl = b as Button
			check(wl != null and wl.disabled and wl.text.contains("скоро"), "класс «Чернокнижник» затемнён")
			create._select_race("human")
			create._select_class("warlock")
			check(create._race == "dark_elf" and create._class == "assassin", "недоступные раса и класс не выбираются")
			check(create._class_stats7.visible and create._class_stats7.text.contains("Ловкость"),
				"у Бродяги 7 статов: %s" % create._class_stats7.text)
			wait = 5
			step = 7
		7:
			var pm: CharacterModel = create._preview_model
			check(pm != null and pm._asset != null and pm.has_ears(), "превью: главный герой из файла")
			check(create._preview_caption.text.contains("Бродяга"), "превью: подпись «%s»" % create._preview_caption.text)
			var got: Array = []
			create.created.connect(func(n: String, r: String, c: String): got.append_array([n, r, c]))
			create._on_start()
			check(got.size() == 3 and got[1] == "dark_elf" and got[2] == "assassin", "«Начать игру» — Бродяга: %s" % [got])
			create.queue_free()
			ok_done()


## Главный герой из файла: загрузка, материалы, метки, меч, клипы, бёдра без смещения по земле.
func _hero_start() -> void:
	var spec := CharacterModel.spec_for("human", "warrior")
	check(spec.get("asset", "") == CharacterModel.MAIN_ASSET, "главный герой у всех рас и классов")
	hero = CharacterModel.new()
	hero.setup(spec)
	main.add_child(hero)
	hero.position = Vector3(12.0, 0.0, 30.0)
	check(hero._asset != null, "герой: модель из файла загружена")
	check(hero._anim != null, "герой: есть проигрыватель анимаций")
	if hero._asset == null or hero._anim == null:
		return
	for kind in CharacterModel.ASSET_ACTIONS:
		check(not hero._pick(CharacterModel.ASSET_ACTIONS[kind]).is_empty(), "герой: есть клип для «%s»" % kind)
	check(not hero._pick(CharacterModel.ASSET_IDLE).is_empty(), "герой: есть поза покоя")
	# Клипы, перенесённые из Quaternius UAL скриптом tools/retarget_animations.py
	for c in ["idle", "sword_slash", "sword_attack", "sword_combo", "sword_heavy_combo", "sword_dash",
			"sword_block", "dodge", "hit", "death", "cast", "pickup", "sword_slash_b", "sword_slash_c", "crossbow_idle",
			"crossbow_shoot"]:
		check(hero._clips.has(c), "герой: есть клип «%s» (Quaternius UAL)" % c)
	if hero._clips.has("idle"):
		check(hero._anim.get_animation(hero._clip("idle")).loop_mode == Animation.LOOP_LINEAR, "герой: покой зациклен")
	check(not hero._pick(CharacterModel.ASSET_WALK).is_empty(), "герой: есть шаг")
	check(not hero._pick(CharacterModel.ASSET_RUN).is_empty(), "герой: есть бег")
	check(hero.weapon_kind == "sword" and hero.find_child("Sword", true, false) != null, "герой: меч в руке")
	check(hero.has_ears(), "герой: эльфийские уши")
	var head := hero.find_child("Head", true, false) as Node3D
	check(head != null, "герой: метка головы")
	if head != null:
		var hy := head.global_position.y
		check(hy > 1.3 and hy < 1.85, "герой: голова на высоте %.2f м" % hy)
	check(hero.find_child("Face", true, false) != null, "герой: метка лица")
	var n := hero.mesh_count()
	check(n >= 2 and n <= MAX_MESHES, "герой: мешей %d (до %d)" % [n, MAX_MESHES])
	for mi in hero.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		check(m != null and m.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "герой: toon-материал у %s" % mi.name)
		if m != null and mi.name != "Sword":
			check(m.albedo_texture != null, "герой: текстура у %s" % mi.name)
	var a := hero._anim.get_animation(hero._pick(CharacterModel.ASSET_ACTIONS["leap"])[0])
	var pinned := false
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(a.track_get_path(t).get_concatenated_subnames()).ends_with("Hips"):
			var k0: Vector3 = a.track_get_key_value(t, 0)
			pinned = true
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				if absf(v.z - k0.z) > 0.001 or absf(v.x - k0.x) > 0.001:
					pinned = false
	check(pinned, "герой: смещение бёдер по земле убрано (удары на месте)")
	check(a.loop_mode == Animation.LOOP_NONE and
		hero._anim.get_animation(hero._clip("running")).loop_mode == Animation.LOOP_LINEAR, "герой: бег зациклен")
	hero.set_move_speed(6.5)


## Поза героя по костям скелета: голова на высоте человека, стопы у земли (перенос анимаций цел).
func _hero_check_pose(when: String) -> void:
	var skels := hero.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		check(false, "герой: нет скелета")
		return
	var skel := skels[0] as Skeleton3D
	var base := hero.global_position.y
	var ys := {}
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		for b in ["Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
			if bn == b or bn.ends_with("_" + b) or bn.ends_with(":" + b):
				ys[b] = (skel.global_transform * skel.get_bone_global_pose(i).origin).y - base
	check(ys.size() == 5, "герой: найдены кости головы, кистей и стоп")
	if ys.size() < 5:
		return
	check(ys["Head"] > 1.3 and ys["Head"] < 1.65, "герой %s: голова на высоте %.2f м" % [when, ys["Head"]])
	for b in ["LeftFoot", "RightFoot"]:
		check(ys[b] > 0.0 and ys[b] < 0.3, "герой %s: стопа %s у земли (%.2f м)" % [when, b, ys[b]])
	for b in ["LeftHand", "RightHand"]:
		check(ys[b] > 0.6 and ys[b] < 1.3, "герой %s: кисть %s у бедра (%.2f м)" % [when, b, ys[b]])


func _hero_check_run() -> void:
	if hero._anim == null:
		check(false, "герой: нет анимаций")
		return
	check(hero._anim.current_animation == hero._clip("running"), "герой: на скорости 6.5 м/с — бег (%s)"
		% hero._anim.current_animation)
	check(hero._anim.speed_scale > 1.0, "герой: темп бега по скорости (%.2f)" % hero._anim.speed_scale)


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
