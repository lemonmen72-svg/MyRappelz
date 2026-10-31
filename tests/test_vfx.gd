extends "res://tests/test_base.gd"
## Графика зверей и эффекты: модели всех зверей и всех стадий питомцев собираются (с малым
## числом вызовов отрисовки: детали слиты в один меш на скелете), анимация работает и двигает кости;
## пантера, черепаха и фазан — из файла (если он есть: клипы, украшения питомца, действия) и запасные
## из примитивов (всегда проверяются, с выключенными моделями из файлов);
## все функции Vfx создают эффекты, которые сами удаляются; всплывающий текст исчезает;
## метка приручения и крит-удар по зверю не ломают бой.

## Вызовов отрисовки на модель без контура: поверхности мешей + системы частиц.
## Цель оптимизации — зверь не дороже 8 вызовов (было ~25 мешей, у питомца до 36).
const MAX_MOB_DRAWS := 6
const MAX_PET_DRAWS := 8

var box: Node3D = null
var models: Array[Node3D] = []
var timer := 0


func run_step() -> void:
	match step:
		0:
			box = Node3D.new()
			box.name = "VfxTest"
			main.add_child(box)
			box.global_position = Vector3(0, 0, -5)
			_build_models()
			_spawn_effects()
			_test_mob()
			timer = 0
			step = 1
		1:
			# Несколько кадров анимации всех моделей (стоя и на бегу)
			timer += 1
			for n in models:
				var sp := String(n.get_meta("species"))
				var ca := CreatureModels.asset_of(n)
				if ca != null:
					ca.update(1.0 / 60.0, float(ca.info["run_speed"]) if timer % 20 < 10 else 0.0)
				else:
					CreatureModels.animate(n, sp, float(timer) * 0.05, 1.0 if timer % 2 == 0 else 0.0)
			if timer >= 30:
				check(_effects_left() > 0, "эффекты ещё видны: %d" % _effects_left())
				_check_bones()
				wait = 60 * 4
				step = 2
		2:
			check(_effects_left() == 0, "все эффекты удалились сами (осталось %d)" % _effects_left())
			check(box.get_child_count() == models.size(), "в контейнере остались только модели: %d/%d"
				% [box.get_child_count(), models.size()])
			var m := find_mob("boar")
			if m != null:
				m.set_tame_mark(false)
			box.queue_free()
			ok_done()


func _build_models() -> void:
	var x := -12.0
	for key in MobData.TYPES:
		var id := String(key)
		var d := MobData.get_type(id)
		var n := _holder(id, Vector3(x, 0, 0))
		var m := CreatureModels.build(n, id, d["color"], float(d["scale"]))
		check(m != null, "модель зверя %s собрана" % id)
		var ca := CreatureModels.asset_of(n)
		check((ca != null) == CreatureAsset.has_asset(id), "модель зверя %s: %s" % [id, "из файла" if ca != null else "из примитивов"])
		var cnt := _draws(n)
		check(cnt >= 1 and cnt <= MAX_MOB_DRAWS, "вызовов отрисовки у зверя %s: %d (мешей %d)" % [id, cnt, _meshes(n)])
		if ca != null:
			_check_asset(ca, id)
		else:
			_check_procedural(n, id)
		for st in PetData.STAGE_LEVELS.size():
			if not PetData.SPECIES.has(id):
				break  # летающие рыбы питомцами не бывают
			var lvl := int(PetData.STAGE_LEVELS[st])
			var sc := PetData.stage_scale(id, lvl)
			var p := _holder(id, Vector3(x, 0, 3.0 + 3.0 * float(st)))
			check(CreatureModels.build(p, id, PetData.stage_color(id, lvl), sc, PetData.asset_tint(id, lvl)) != null,
				"модель питомца %s собрана" % id)
			CreatureModels.decorate_pet(p, id, sc, PetData.stage_for(lvl), PetData.role(id))
			if CreatureModels.asset_of(p) != null:
				check(p.find_child("Charm", true, false) != null, "самоцвет роли у питомца %s (стадия %d)" % [id, st + 1])
				var am := CreatureModels.asset_of(p).material
				if am.albedo_texture != null:
					var tint := am.albedo_color
					check((st == 0) == tint.is_equal_approx(Color.WHITE), "оттенок стадии %d у %s: %s" % [st + 1, id, tint])
			else:
				check(p.find_child("Collar", true, false) != null, "ошейник у питомца %s (стадия %d)" % [id, st + 1])
				if st >= 1:
					check(p.find_child("Mark0", true, false) != null, "узоры у питомца %s (стадия %d)" % [id, st + 1])
			check((p.find_child("Halo", true, false) != null) == (st == 2), "нимб только на 3-й стадии: %s" % id)
			var pc := _draws(p)
			check(pc >= 1 and pc <= MAX_PET_DRAWS, "вызовов отрисовки у питомца %s стадии %d: %d" % [id, st + 1, pc])
		x += 4.0
	_build_fallbacks()


## Модель из примитивов: части для анимации и слитый меш на скелете.
func _check_procedural(n: Node3D, id: String) -> void:
	check(n.has_meta("anim"), "у модели %s есть части для анимации" % id)
	if CreatureModels.skinned:
		check(n.find_child("Skeleton", true, false) is Skeleton3D, "у модели %s слитый меш на скелете" % id)


## Модель из файла: свой toon-материал, скелет, клипы, действия не ломаются.
func _check_asset(ca: CreatureAsset, id: String) -> void:
	check(ca.material != null and ca.material.metallic == 0.0 and ca.material.emission_enabled,
		"материал модели %s свой (без металла, с эмиссией для вспышки)" % id)
	check(ca.skeleton != null, "у модели %s есть скелет" % id)
	check(ca.anim != null, "у модели %s есть AnimationPlayer" % id)
	print("  клипы %s: %s" % [id, ca.clips])
	for k in CreatureAsset.LOOPED:
		if ca.clips.has(k):
			var a := ca.anim.get_animation(ca.clips[k])
			check(a.loop_mode == Animation.LOOP_LINEAR, "клип %s у %s зациклен" % [k, id])
	check(ca.play_attack(1.3) >= 0.0, "атака %s" % id)
	ca.play_hit()
	ca.play_cast()
	ca.set_sleeping(true)
	check(ca.anim == null or not ca.anim.active, "спящий %s: анимации стоят" % id)
	ca.set_sleeping(false)
	check(ca.anim == null or ca.anim.active, "проснувшийся %s: анимации идут" % id)


## Запасные модели (файлов нет): пантера, черепаха, фазан из примитивов, высота и коллизия — по размерам вида.
func _build_fallbacks() -> void:
	check(CreatureAsset.clip_key("Armature|Walk") == "walk" and CreatureAsset.clip_key("lib/IDLE") == "idle",
		"имена клипов распознаются без учёта регистра и приставок")
	check(CreatureAsset.clip_key("Take 001") == "", "чужой клип не распознан")
	CreatureAsset.use_assets = false
	var x := -12.0
	for id in ["panther", "turtle", "pheasant"]:
		var d := MobData.get_type(id)
		var n := _holder(id, Vector3(x, 0, -4.0))
		var m := CreatureModels.build(n, id, d["color"], 1.0)
		check(m != null and CreatureModels.asset_of(n) == null, "запасная модель %s собрана" % id)
		_check_procedural(n, id)
		var cnt := _draws(n)
		check(cnt >= 1 and cnt <= MAX_MOB_DRAWS, "вызовов отрисовки у запасной модели %s: %d" % [id, cnt])
		var inf := CreatureAsset.info_for(id)
		check(is_equal_approx(CreatureModels.height(id, 2.0), float(inf["height"]) * 2.0), "высота %s по размерам вида" % id)
		var body := Node3D.new()
		var col := CreatureModels.add_collision(body, id, 1.0)
		var size := (col.shape as BoxShape3D).size
		check(is_equal_approx(size.y, float(inf["height"])) and size.x > 0.25, "коллизия %s: %s" % [id, size])
		body.free()
		x += 4.0
	CreatureAsset.use_assets = true


func _holder(id: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta("species", id)
	box.add_child(n)
	n.position = pos
	models.append(n)
	return n


func _spawn_effects() -> void:
	var p := box.global_position + Vector3(0, 1, 0)
	var roots: Array[Node3D] = [
		Vfx.hit_spark(box, p),
		Vfx.hit_spark(box, p, Color(1, 0.3, 0.3), 1.6),
		Vfx.slash_arc(box, p, Vector3(1, 0, 0), Color(1, 0.4, 0.4)),
		Vfx.slash_arc(box, p, Vector3.ZERO),
		Vfx.heal_sparkles(box, p),
		Vfx.level_up(box, p),
		Vfx.tame_success(box, p),
		Vfx.evolution(box, p),
		Vfx.pickup(box, p),
		Vfx.magic_burst(box, p, Color(0.6, 0.3, 1.0), 2.0),
		Vfx.death_puff(box, p, 1.5),
	]
	var ok := 0
	for r in roots:
		if r != null and r.is_in_group("vfx"):
			ok += 1
	check(ok == roots.size(), "все эффекты Vfx созданы: %d/%d" % [ok, roots.size()])
	Projectile.burst(box, p, Color(1, 0.4, 0.2), 1.5, 0.3)
	CreatureModels.spawn_ring(box, p, 3.0, Color(1, 0.5, 0.2), 0.5)
	Util.float_text(box, p, "123", Color.WHITE)
	Util.float_text(box, p, "45", Color(1, 0.8, 0.2), 1.5)
	Util.float_text(box, p, "Эволюция!", Color(1, 0.9, 0.4), 1.4)
	# Вне дерева сцены эффекты не создаются и не падают
	var lonely := Node3D.new()
	check(Vfx.hit_spark(lonely, Vector3.ZERO) == null, "эффект без сцены не создаётся")
	Util.float_text(lonely, Vector3.ZERO, "1", Color.WHITE)
	lonely.free()


func _test_mob() -> void:
	var m := find_mob("boar")
	check(m != null, "найден кабан")
	m.set_tame_mark(true)
	check(m.get("_mark") != null and m.tame_marked, "метка приручения построена")
	var hp0 := m.hp
	m.take_damage(1, null, true)
	check(m.hp == hp0 - 1, "крит-удар по зверю наносит урон")


## Сколько узлов эффектов (и текстов) осталось в контейнере, кроме моделей.
func _effects_left() -> int:
	return box.get_child_count() - models.size()


func _meshes(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()


## Вызовы отрисовки модели без контура и теней: по одному на поверхность меша и на систему частиц.
func _draws(n: Node) -> int:
	var c := 0
	for x in n.find_children("*", "GeometryInstance3D", true, false):
		if x is MeshInstance3D:
			var mesh := (x as MeshInstance3D).mesh
			if mesh is ArrayMesh:
				c += mesh.get_surface_count()
			elif mesh != null:
				c += 1
		elif x is CPUParticles3D or x is GPUParticles3D:
			c += 1
	return c


## После анимации кости скелета повторяют узлы-шарниры (лапы, голова и т. п.).
func _check_bones() -> void:
	if not CreatureModels.skinned:
		return
	var moved := 0
	var total := 0
	for n in models:
		if not n.has_meta("anim"):
			continue
		total += 1
		var a: Dictionary = n.get_meta("anim", {})
		var skel: Skeleton3D = a.get("skel")
		var bones: Array = a.get("bones", [])
		check(skel != null and skel.get_bone_count() == bones.size(),
			"кости скелета у %s: %d" % [String(n.get_meta("species")), bones.size()])
		if skel == null:
			continue
		for i in range(1, bones.size()):
			var node := bones[i] as Node3D
			if node.rotation.length() > 0.001 \
					and not skel.get_bone_pose_rotation(i).is_equal_approx(Quaternion.IDENTITY):
				moved += 1
				break
	check(moved == total, "анимация двигает кости у всех моделей из примитивов: %d/%d" % [moved, total])
