extends "res://tests/test_base.gd"
## Раскадровки эффектов (VfxFlip, 0.46.1): листы Максима подготовлены (vfx/flip/flipbooks.json — вид, кадры, опора,
## варианты; файлы L8 сеткой 4×4 по 256 px, импорт «Image»), каждый лист раскодируется (в фоне при входе в мир и
## сразу), каждый лист берёт какой-то эффект; архетипы на трёх качествах строят нарисованный слой нужного вида
## (к камере — квад с поворотом к камере, «сбоку» — стоит на земле, опора у земли, «сверху» — лежит на земле,
## «вправо» — вдоль удара, отрезок — от героя до цели), кадры идут до конца, петля крутится дальше; тьма — с тёмным
## слоем под ней; удар, искра и снаряд обычных атак — с листами; выключатель и часть пакета «vfx» — откат на прежние
## слои; листов в видеопамяти не больше VfxFlip.MAX_LOADED.

var once_mat: VfxMat = null
var loop_mat: VfxMat = null
var waited := 0


func race_class() -> Array:
	return ["dark_elf", "neophyte"]


func hero_level() -> int:
	return 40


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			_meta()
			step = 1
		1:
			# Вход в мир запустил загрузку листов умений героя и обычных атак в фоне
			waited += 1
			if VfxFlip.busy() and waited < 60 * 20:
				return
			check(not VfxFlip.busy(), "фоновая загрузка листов закончилась за %.1f с" % (waited / 60.0))
			for id in ["cast_release", "cast_gather", "slash_arc", "hit_spark", "magic_orb"]:
				var f := String((VfxFlip.files_of(id)[0] as Dictionary)["file"])
				check(VfxFlip.ready(f), "лист «%s» загружен заранее (при входе в мир)" % id)
			VfxFlip.sync_load = true
			_archetypes()
			_play()
			wait = 80
			step = 2
		2:
			var f_once := float(once_mat.get_shader_parameter("flip_f"))
			check(is_equal_approx(f_once, 15.0), "разовый лист проигран до последнего кадра (кадр %.2f)" % f_once)
			var f_loop := float(loop_mat.get_shader_parameter("flip_f"))
			check(f_loop > 16.0, "петля крутится дальше 16 кадров (%.1f)" % f_loop)
			_basic()
			_fallback()
			_evict()
			VfxFlip.sync_load = false
			wait = 60 * 4
			step = 3
		3:
			var left := main.get_tree().get_nodes_in_group("vfx").size()
			check(left == 0, "эффекты с листами удалились сами (осталось %d)" % left)
			ok_done()


## Метаданные и файлы: всё, что берут архетипы, есть; каждый лист кем-то берётся.
func _meta() -> void:
	var m := VfxFlip.meta()
	check(m.size() >= 39, "раскадровок в flipbooks.json: %d (первая партия — 39 эффектов)" % m.size())
	var used := {}
	for a in VfxFlip.ARCH_SHEETS:
		for id in VfxFlip.ARCH_SHEETS[a]:
			used[String(id)] = true
			check(m.has(String(id)), "лист «%s» (архетип %s) есть в flipbooks.json" % [id, a])
	var files := 0
	for id in m:
		check(used.has(String(id)), "лист «%s» берёт какой-то эффект (VfxFlip.ARCH_SHEETS)" % id)
		var s: Dictionary = m[id]
		check(String(s.get("kind", "")) in ["once", "loop"], "«%s»: вид анимации %s" % [id, s.get("kind")])
		for r in s.get("files", []):
			var rec: Dictionary = r
			files += 1
			var f := String(rec["file"])
			var path := VfxFlip.DIR + f
			check(VfxFlip.has(String(id)) and VfxFlip.file_ok(f), "%s есть в игре" % f)
			check(FileAccess.get_file_as_string(path + ".import").contains("importer=\"image\""),
				"%s — импорт «Image» (в пакете — PNG, раскодирует игра)" % f)
			var img := VfxFlip._decode(f)
			var g := int(rec.get("grid", 0))
			check(img != null and img.get_format() == Image.FORMAT_L8 and img.get_width() == g * 256
				and img.get_height() == g * 256 and img.has_mipmaps(),
				"%s: L8 %d×%d с мипмапами" % [f, g * 256, g * 256])
			check(int(rec.get("frames", 0)) == g * g and (rec.get("energy", []) as Array).size() == g * g,
				"%s: кадров %d" % [f, g * g])
			var view := String(rec.get("view", ""))
			check(view in ["front", "side", "top", "right", "left", "head"], "%s: вид %s" % [f, view])
			var pv: Array = rec.get("pivot", [])
			check(pv.size() == 2 and float(pv[0]) >= 0.0 and float(pv[0]) <= 1.0 and float(pv[1]) >= 0.0
				and float(pv[1]) <= 1.0, "%s: опора в кадре %s" % [f, pv])
			if view == "side":
				check(float(pv[1]) >= 0.7 and float(pv[1]) <= 0.95, "%s: земля у вида «сбоку» внизу кадра (%.2f)" % [
					f, float(pv[1])])
			if String(s["kind"]) == "once":
				var en: Array = rec["energy"]
				check(float(en[en.size() - 1]) <= 0.2, "%s: разовый лист гаснет к концу (%.2f)" % [f, float(en[-1])])
	check(files >= 42, "листов (с вариантами): %d" % files)
	check(VfxFlip.files_of("blessing").size() == 2 and VfxFlip.files_of("shield_bubble").size() == 2
		and VfxFlip.files_of("arrow_impact").size() == 2, "вторые варианты: благословение, щит, попадание стрелы")


## Слои раскадровки в эффекте r: [MeshInstance3D].
func _flips(r: Node) -> Array:
	var out: Array = []
	if r == null:
		return out
	for n in r.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if m != null and m.get_shader_parameter("flip") is Vector2 and (m.get_shader_parameter("flip") as Vector2).x > 0.5:
			out.append(mi)
	return out


func _archetypes() -> void:
	var p: Player = main.player
	var at := p.global_position + Vector3(0, 1.0, 6.0)
	var o := {"ground": p.global_position + Vector3(0, 0, 6.0), "from": p.global_position + Vector3(0, 1.2, 0),
		"dir": Vector3.FORWARD, "height": 1.7}
	var views := {}
	for q in 3:
		for a in VfxArchetypes.LIST:
			if a == "orb" or not VfxFlip.ARCH_SHEETS.has(a):
				continue
			o["q"] = q
			var el := "dark" if a in ["shadow_burst", "cursed_sigil"] else "fire"
			var r := VfxArchetypes.build({"arch": a, "el": el, "dur": 0.6, "seed": 7}, main, at, o)
			var fl := _flips(r)
			check(not fl.is_empty(), "архетип %s — с нарисованным слоем (качество %d)" % [a, q])
			for mi in fl:
				var m := (mi as MeshInstance3D).material_override as ShaderMaterial
				var bb := int(m.get_shader_parameter("billboard"))
				# QuadMesh в Godot 4 — наследник PlaneMesh: плоскость на земле — PlaneMesh, но не QuadMesh
				var plane := (mi as MeshInstance3D).mesh is PlaneMesh and not ((mi as MeshInstance3D).mesh is QuadMesh)
				check(plane == (bb == 0), "%s: «сверху» — плоскость на земле, остальные — квад к камере (режим %d)" % [
					a, bb])
				check(bb in [0, 2, 4, 5], "%s: режим поворота %d" % [a, bb])
				views[bb] = true
				if bb == 4:
					var pv: Vector2 = m.get_shader_parameter("pivot")
					check(pv.y >= 0.7 and is_equal_approx((mi as MeshInstance3D).global_position.y, (o["ground"] as Vector3).y),
						"%s: «сбоку» — опора у земли (%.2f), квад стоит на земле" % [a, pv.y])
				if bb == 0:
					check((mi as MeshInstance3D).global_position.y > (o["ground"] as Vector3).y,
						"%s: «сверху» — над землёй, не в ней" % a)
			if a == "shadow_burst":
				var under := 0
				for mi in fl:
					var mm := (mi as MeshInstance3D).material_override as ShaderMaterial
					if mm.shader == VfxMat.MIX and mm.render_priority < 0:
						under += 1
				check(under == 1, "тьма: тёмный слой обычной прозрачности под светлым")
			if a == "stab":
				var sm := (fl[0] as MeshInstance3D).material_override as ShaderMaterial
				check(int(sm.get_shader_parameter("billboard")) == 5
					and (sm.get_shader_parameter("face_dir") as Vector3).is_equal_approx(Vector3.FORWARD),
					"укол — вдоль удара (+X кадра к цели)")
				var hot: Array = (VfxFlip.files_of("stab")[0] as Dictionary)["hot"]
				check((sm.get_shader_parameter("pivot") as Vector2).is_equal_approx(Vector2(float(hot[0]), float(hot[1]))),
					"укол: опора — вспышка на острие (в точке попадания)")
			if a in ["soul_drain", "lightning_bolt"]:
				var span := false
				for mi in fl:
					var sm2 := (mi as MeshInstance3D).material_override as ShaderMaterial
					if sm2.get_shader_parameter("face_span") == true:
						span = true
						check((sm2.get_shader_parameter("face_dir") as Vector3).is_equal_approx(
							at - (o["from"] as Vector3)), "%s: кадр растянут от героя до цели" % a)
				check(span, "%s: кадр — отрезок между героем и целью" % a)
			if r != null:
				r.remove_from_group("vfx")
				r.queue_free()
	check(views.has(0) and views.has(2) and views.has(4) and views.has(5),
		"все виды: на земле, к камере, стоит на земле, вдоль удара (%s)" % [views.keys()])
	# Снаряд стихии и каст
	var n3 := Node3D.new()
	main.add_child(n3)
	VfxArchetypes.dress_projectile(n3, "storm", 1.0, 1)
	check(not _flips(n3).is_empty(), "снаряд стихии — нарисованный сгусток")
	n3.queue_free()


## Время кадров: разовый лист проигрывается целиком, петля крутится дальше.
func _play() -> void:
	var p: Player = main.player
	var root := Vfx._root(main, p.global_position + Vector3(0, 1.0, 4.0), 3.0)
	var a := VfxKit.flipbook(root, "explosion", 3.0, 0.8, {"color": Color(1, 0.5, 0.2)})
	var b := VfxKit.flipbook(root, "tornado", 3.0, 2.5, {"color": Color(0.5, 1, 0.8), "speed": 14.0})
	check(a != null and b != null, "слои строятся сразу (лист загружен)")
	once_mat = a.material_override
	loop_mat = b.material_override
	check(not bool(once_mat.get_shader_parameter("flip_cycle")) and bool(loop_mat.get_shader_parameter("flip_cycle")),
		"взрыв — разовый, вихрь — петля (две половины цикла с растворением)")
	var lo: Color = loop_mat.get_shader_parameter("ramp_lo")
	check(lo.is_equal_approx(Color(Color(0.5, 1, 0.8).darkened(0.35), 1.0)), "цвет по яркости: тёмное — темнее основного")


## Обычные атаки: удар клинком, когти, укол, искра — нарисованные.
func _basic() -> void:
	var p: Player = main.player
	var at := p.global_position + Vector3(0, 1.2, 3.0)
	for sh in ["slash_arc", "claw", "stab"]:
		var r := Vfx.slash_arc(main, at, Vector3.FORWARD, Color(1, 0.8, 0.4), 1.0, sh)
		var fl := _flips(r)
		check(fl.size() == 1, "удар обычной атаки «%s» — нарисованный (%d слой)" % [sh, fl.size()])
		var arcs := 0
		for n in r.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).mesh is ArrayMesh:
				arcs += 1
		check(arcs == 0, "«%s»: объёмного серпа нет, есть лист" % sh)
	var s := Vfx.hit_spark(main, at, Color(1, 0.9, 0.5))
	check(_flips(s).size() == 1, "искра попадания — нарисованная")
	# Питомцы бьют когтями, скелет — клинком, кентавр — копьём
	check(String(Pet.SLASH_SHEET.get("wolf", "claw")) == "claw" and String(Pet.SLASH_SHEET["centaur"]) == "stab",
		"удар питомца: волк — когти, кентавр — укол")


## Откат: выключатель и без части пакета «vfx» — прежние слои.
func _fallback() -> void:
	var p: Player = main.player
	var at := p.global_position + Vector3(0, 1.0, 6.0)
	var o := {"ground": p.global_position + Vector3(0, 0, 6.0), "q": 2}
	VfxFlip.enabled = false
	var r := VfxArchetypes.build({"arch": "explosion", "el": "fire", "dur": 0.6, "seed": 3}, main, at, o)
	check(_flips(r).is_empty(), "раскадровки выключены — слоёв с листами нет")
	var spheres := 0
	for n in r.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh is SphereMesh:
			spheres += 1
	check(spheres >= 2, "взрыв без листа — прежний огненный шар и оболочка (%d)" % spheres)
	r.remove_from_group("vfx")
	r.queue_free()
	VfxFlip.enabled = true
	Assets.simulate_missing(true)
	check(not VfxFlip.has("explosion"), "без части пакета «vfx» листов нет")
	var r2 := VfxArchetypes.build({"arch": "claw", "el": "beast", "dur": 0.6, "seed": 3}, main, at, o)
	check(_flips(r2).is_empty() and r2.find_children("*", "MeshInstance3D", true, false).size() >= 3,
		"без части — когти из прежних слоёв")
	r2.remove_from_group("vfx")
	r2.queue_free()
	Assets.simulate_missing(false)
	check(VfxFlip.has("explosion"), "часть снова на месте — листы есть")


## Листов в видеопамяти не больше предела: загрузить все — давно не нужные выгружаются.
func _evict() -> void:
	var all := 0
	for id in VfxFlip.meta():
		for r in VfxFlip.files_of(String(id)):
			all += 1
			VfxFlip.texture(String((r as Dictionary)["file"]))
	check(all > VfxFlip.MAX_LOADED and VfxFlip.loaded_count() <= VfxFlip.MAX_LOADED,
		"листов загружено %d из %d — не больше предела %d" % [VfxFlip.loaded_count(), all, VfxFlip.MAX_LOADED])
	check(VfxFlip.loads >= all, "каждый лист раскодировался (%d)" % VfxFlip.loads)
