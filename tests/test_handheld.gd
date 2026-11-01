extends "res://tests/test_base.gd"
## Оружие и предметы в руках из файлов (Handheld, assets/handheld — модели Meshy, tools/prepare_handheld.py):
## каждый файл грузится (одна поверхность, текстура), размер — как в handheld.json, длина — как у вида, оси по
## контракту (начало — хват внутри рукояти, ось +Y, лезвие топора к +X, тетива к +Z, арбалет вперёд −Z, щит лицом
## +Z за ручкой, книги корешком к −X); у двуручных — точка второй руки ниже хвата; у каждого вида оружия ItemData
## и у каждого оружия-предмета есть модель из файла; у жителей — все 10 предметов (id — договорённость с моделями
## жителей). В руке героя из файла — меш из файла (не процедурный), пары — один файл в обеих руках, щит — в левой
## с поворотом рамки; без файлов (Handheld.force_missing) — прежние процедурные меши. У игрока в руках — модель
## надетого предмета.

## Все модели и их длина по главной оси (у арбалета — по Z, у остальных — по Y), м.
const LENGTHS := {
	"weapon_sword_1h_r1": 0.95, "weapon_sword_2h_r1": 1.45, "weapon_dagger_r1": 0.38, "weapon_mace_1h_r1": 0.75,
	"weapon_mace_2h_r1": 1.4, "weapon_axe_1h_r1": 0.7, "weapon_axe_2h_r1": 1.4, "weapon_staff_1h_r1": 0.8,
	"weapon_staff_2h_r1": 1.7, "weapon_spear_r1": 2.0, "weapon_crossbow_r1": 0.85, "weapon_shield_r1": 0.75,
	"weapon_sword_1h_r2": 0.95, "weapon_sword_2h_r2": 1.5, "weapon_dagger_r2": 0.38, "weapon_mace_1h_r2": 0.75,
	"weapon_mace_2h_r2": 1.45, "weapon_axe_1h_r2": 0.7, "weapon_axe_2h_r2": 1.45, "weapon_staff_1h_r2": 0.8,
	"weapon_staff_2h_r2": 1.7, "weapon_spear_r2": 2.0, "weapon_bow_r2": 1.4, "weapon_crossbow_r2": 0.85,
	"weapon_shield_r2": 0.8,
	"npc_longbow": 1.4, "npc_grimoire": 0.3, "npc_tome": 0.3, "npc_cane": 0.95, "npc_wand": 0.45,
	"npc_hammer": 0.6, "npc_antlerstaff": 1.7, "npc_quiver": 0.7, "npc_keys": 0.2, "npc_scroll": 0.3,
}
## Предметы жителей (договорённость с моделями жителей: id не менять).
const NPC_IDS := ["npc_grimoire", "npc_cane", "npc_wand", "npc_longbow", "npc_hammer", "npc_quiver", "npc_keys",
	"npc_scroll", "npc_tome", "npc_antlerstaff"]
## Двуручные (у них точка второй руки grip2).
const TWO_HANDED := ["weapon_sword_2h_r1", "weapon_mace_2h_r1", "weapon_axe_2h_r1", "weapon_staff_2h_r1",
	"weapon_spear_r1", "weapon_sword_2h_r2", "weapon_mace_2h_r2", "weapon_axe_2h_r2", "weapon_staff_2h_r2",
	"weapon_spear_r2"]
## Оружие 2-го ранга (модели Максима, tools/prepare_handheld.py): id модели → вид оружия ItemData.
const RANK2 := {
	"weapon_sword_1h_r2": "sword_1h", "weapon_sword_2h_r2": "sword_2h", "weapon_dagger_r2": "dagger",
	"weapon_mace_1h_r2": "mace_1h", "weapon_mace_2h_r2": "mace_2h", "weapon_axe_1h_r2": "axe_1h",
	"weapon_axe_2h_r2": "axe_2h", "weapon_staff_1h_r2": "staff_1h", "weapon_staff_2h_r2": "staff_2h",
	"weapon_spear_r2": "spear", "weapon_bow_r2": "bow", "weapon_crossbow_r2": "crossbow",
	"weapon_shield_r2": "shield",
}
## Бюджет треугольников модели в руке.
const MAX_TRIS := 16000
## Вид хвата героя → [узел в руке, id модели] (что должно оказаться в руках модели из файла).
const HELD := [
	["sword_1h", "weapon_sword_1h_r1", "", [["Sword", "weapon_sword_1h_r1"]]],
	["sword_2h", "weapon_sword_2h_r1", "", [["Sword", "weapon_sword_2h_r1"]]],
	["dagger", "weapon_dagger_r1", "", [["DaggerR", "weapon_dagger_r1"]]],
	["daggers", "weapon_dagger_r1", "weapon_dagger_r1", [["DaggerR", "weapon_dagger_r1"], ["DaggerL", "weapon_dagger_r1"]]],
	["dual_swords", "weapon_sword_1h_r1", "weapon_sword_1h_r1",
		[["Sword", "weapon_sword_1h_r1"], ["SwordL", "weapon_sword_1h_r1"]]],
	["dual_axes", "weapon_axe_1h_r1", "weapon_axe_1h_r1", [["Axe", "weapon_axe_1h_r1"], ["AxeL", "weapon_axe_1h_r1"]]],
	["axe_2h", "weapon_axe_2h_r1", "", [["Axe", "weapon_axe_2h_r1"]]],
	["mace_1h", "weapon_mace_1h_r1", "weapon_shield_r1", [["Mace", "weapon_mace_1h_r1"], ["Shield", "weapon_shield_r1"]]],
	["mace_2h", "weapon_mace_2h_r1", "", [["Mace", "weapon_mace_2h_r1"]]],
	["staff_1h", "weapon_staff_1h_r1", "", [["Staff", "weapon_staff_1h_r1"]]],
	["staff_2h", "weapon_staff_2h_r1", "", [["Staff", "weapon_staff_2h_r1"]]],
	["spear", "weapon_spear_r1", "", [["Spear", "weapon_spear_r1"]]],
	["crossbow", "crossbow_starter", "", [["Crossbow", "weapon_crossbow_r1"]]],
	["bow", "weapon_bow_r1", "", [["Bow", "npc_longbow"]]],
]

var models: Array[CharacterModel] = []


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	match step:
		0:
			_check_files()
			_check_rank2()
			_check_kinds()
			_spawn_held()
			wait = 10
			step = 1
		1:
			_check_held()
			_check_fallback()
			_check_player()
			for m in models:
				m.queue_free()
			models.clear()
			ok_done()


## Файлы, размеры и оси по контракту.
func _check_files() -> void:
	check(FileAccess.file_exists(Handheld.INFO_PATH), "handheld.json есть")
	check(Handheld.items().size() == LENGTHS.size(), "в handheld.json %d предметов (%d)" % [LENGTHS.size(),
		Handheld.items().size()])
	for k in LENGTHS:
		var id := String(k)
		check(ResourceLoader.exists(Handheld.DIR + id + ".glb"), "%s: файл модели" % id)
		check(ResourceLoader.exists(Handheld.DIR + id + ".png"), "%s: текстура" % id)
		check(Handheld.exists(id), "%s: модель есть" % id)
		var me := Handheld.mesh(id)
		check(me != null and me.get_surface_count() == 1, "%s: меш грузится (одна поверхность)" % id)
		if me == null:
			continue
		var mat := Handheld.material(id)
		check(mat.albedo_texture != null and mat.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON
			and mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "%s: toon-материал с текстурой, двусторонний" % id)
		var tris := (me as ArrayMesh).surface_get_array_index_len(0) / 3
		check(tris > 500 and tris <= MAX_TRIS, "%s: треугольников %d (до %d)" % [id, tris, MAX_TRIS])
		var bb := me.get_aabb()
		var inf := Handheld.info(id)
		var want := Handheld.point(id, "max") - Handheld.point(id, "min")
		check(bb.size.distance_to(want) < 0.03 * want.length() + 0.005, "%s: размер %s ≈ %s (handheld.json)" % [
			id, bb.size, want])
		var fr := Handheld.frame(id)
		var axis := 2 if fr == "crossbow" else 1
		var L := float(LENGTHS[id])
		check(absf(bb.size[axis] - L) < 0.03 * L and absf(float(inf.get("length", 0.0)) - L) < 0.001,
			"%s: длина %.3f м (%.2f)" % [id, bb.size[axis], L])
		# Главная ось — самая длинная (у щита и книг высота, у лука — плечи)
		if fr == "blade" or fr == "bow":
			check(bb.size.y >= bb.size.x and bb.size.y >= bb.size.z, "%s: ось предмета +Y (%s)" % [id, bb.size])
		# Хват внутри предмета (у щита — за ним, у книг — у корешка, у арбалета — под ложем)
		check(bb.grow(0.07).has_point(Vector3.ZERO), "%s: хват у предмета (рамка %s)" % [id, bb])
		match fr:
			"blade":
				check(bb.position.y < -0.005 and bb.end.y > 0.01, "%s: хват между концами (%.3f…%.3f)" % [
					id, bb.position.y, bb.end.y])
				check(absf(bb.position.x + bb.end.x) < bb.size.x and bb.size.z <= bb.size.x * 1.6 + 0.02,
					"%s: плоскость клинка XY" % id)
			"bow":
				check(bb.end.z > -bb.position.z, "%s: тетива к +Z (%.3f / %.3f)" % [id, bb.end.z, bb.position.z])
			"crossbow":
				check(-bb.position.z > bb.end.z and bb.size.x > bb.size.y * 3.0,
					"%s: ложе вперёд (−Z), дуги вдоль X (%s)" % [id, bb])
				check(bb.position.y > -0.03 and bb.position.y < 0.05, "%s: кулак под ложем (низ %.3f)" % [id, bb.position.y])
			"shield":
				# Щит перед кулаком (ручки-скобы сзади щита могут заходить за кулак на несколько сантиметров)
				check(bb.position.z > -0.05 and bb.position.z + bb.end.z > 0.0,
					"%s: щит перед ручкой, лицом к +Z (%.3f…%.3f)" % [id, bb.position.z, bb.end.z])
				check(bb.size.y > bb.size.x and bb.size.z < 0.2, "%s: верх +Y, тонкий по Z (%s)" % [id, bb.size])
			"book":
				check(bb.position.x > -0.01, "%s: корешок у хвата (−X; %.3f)" % [id, bb.position.x])
	# Топоры и молот: лезвие / боёк к +X (как у процедурного хвата: +X — к костяшкам)
	for id in ["weapon_axe_1h_r1", "weapon_axe_2h_r1", "weapon_axe_1h_r2", "weapon_axe_2h_r2"]:
		var bb := Handheld.mesh(id).get_aabb()
		check(bb.end.x > -bb.position.x, "%s: лезвие к +X (%.3f / %.3f)" % [id, bb.end.x, bb.position.x])
	for id in TWO_HANDED:
		var g2 := Handheld.point(id, "grip2", Vector3(9, 9, 9))
		check(g2.y < -0.1 and g2.length() < 1.0, "%s: вторая рука ниже хвата (%s)" % [id, g2])
	for id in NPC_IDS:
		check(Handheld.exists(String(id)) and Handheld.info(String(id)).get("kind", "") == "npc",
			"предмет жителя %s" % id)


## Оружие 2-го ранга: все 13 файлов, вид в handheld.json, готовый узел Handheld.make, хват внутри рукояти, у
## двуручных — вторая рука ниже по рукояти, размеры — не меньше и не намного больше 1-го ранга того же вида (лук —
## против лука жителя). Предметы ItemData с полем "model" держат именно эту модель (своего вида).
func _check_rank2() -> void:
	for k in RANK2:
		var id := String(k)
		var kind := String(RANK2[k])
		check(Handheld.exists(id), "2-й ранг: модель %s есть" % id)
		check(String(Handheld.info(id).get("kind", "")) == kind, "2-й ранг: %s — вид %s (%s)" % [id, kind,
			Handheld.info(id).get("kind", "")])
		var w := Handheld.make(id)
		check(w != null and w.mesh != null and w.material_override != null and String(w.get_meta("handheld", "")) == id,
			"2-й ранг: Handheld.make(%s) — узел с мешем и материалом" % id)
		if w == null or w.mesh == null:
			continue
		var bb := w.mesh.get_aabb()
		w.free()
		check(Handheld.point(id, "grip", Vector3(9, 9, 9)) == Vector3.ZERO, "2-й ранг: %s — точка хвата в начале" % id)
		check(bb.grow(0.07).has_point(Vector3.ZERO), "2-й ранг: %s — хват у предмета (%s)" % [id, bb])
		var g2 := Handheld.point(id, "grip2", Vector3(9, 9, 9))
		if TWO_HANDED.has(id):
			check(g2.y < -0.1 and g2.y > bb.position.y and absf(g2.x) < 0.05 and absf(g2.z) < 0.05,
				"2-й ранг: %s — вторая рука ниже хвата на рукояти (%s)" % [id, g2])
		else:
			check(Handheld.info(id).get("grip2", null) == null, "2-й ранг: %s — одноручное, без grip2" % id)
		var r1 := "npc_longbow" if kind == "bow" else String(Handheld.KIND_MODELS.get(kind, ""))
		check(Handheld.exists(r1), "2-й ранг: %s — есть модель 1-го ранга того же вида (%s)" % [id, r1])
		if not Handheld.exists(r1):
			continue
		var b1 := Handheld.mesh(r1).get_aabb()
		var big: float = bb.size[bb.size.max_axis_index()]
		var big1: float = b1.size[b1.size.max_axis_index()]
		check(big >= big1 * 0.95 and big <= big1 * 1.15, "2-й ранг: %s — размер %.2f м (1-й ранг %.2f)" % [id, big, big1])
		check(bb.size.x <= b1.size.x * 1.6 + 0.05 and bb.size.z <= b1.size.z * 2.0 + 0.05,
			"2-й ранг: %s — не шире 1-го ранга сверх меры (%s / %s)" % [id, bb.size, b1.size])
	for k in ItemData.ITEMS:
		var item := String(k)
		var model := String(ItemData.get_item(item).get("model", ""))
		if model == "" or not ItemData.is_weapon(item):
			continue
		check(Handheld.exists(model), "оружие «%s»: файл модели %s" % [ItemData.item_name(item), model])
		check(Handheld.model_for(item) == model, "оружие «%s»: в руках модель %s (%s)" % [ItemData.item_name(item),
			model, Handheld.model_for(item)])
		var wk := String(ItemData.get_item(item).get("weapon", ""))
		if wk != "":
			check(String(Handheld.info(model).get("kind", "")) == ItemData.single_kind(wk),
				"оружие «%s»: модель %s своего вида (%s)" % [ItemData.item_name(item), model, wk])


## У каждого вида оружия и каждого оружия-предмета — модель из файла.
func _check_kinds() -> void:
	for k in ItemData.WEAPON_KINDS:
		var kind := String(k)
		var single := ItemData.single_kind(kind)
		var id := Handheld.model_for("", single)
		check(id != "", "вид «%s»: модель из файла (%s)" % [ItemData.weapon_kind_name(kind), id])
		if Handheld.KIND_MODELS.has(kind):
			var want := String(Handheld.KIND_MODELS[kind])
			check(String(Handheld.info(want).get("kind", "")) == kind or want == "npc_longbow",
				"вид «%s» — модель своего вида (%s)" % [kind, want])
	for k in ItemData.ITEMS:
		var item := String(k)
		if not ItemData.is_weapon(item):
			continue
		check(Handheld.model_for(item) != "", "оружие «%s»: модель из файла (%s)" % [ItemData.item_name(item),
			Handheld.model_for(item)])
	check(Handheld.model_for("weapon_bow_r1") == "npc_longbow", "лук героя — лук жителя (npc_longbow)")
	check(Handheld.model_for("crossbow_heavy") == "weapon_crossbow_r1", "улучшенный арбалет — модель вида")


## Герои из файла с каждым видом хвата.
func _spawn_held() -> void:
	var x := -8.0
	for e in HELD:
		var kind := String(e[0])
		var off := String(e[2])
		var spec := CharacterModel.spec_for("dark_elf", "assassin", kind, "f", ItemData.is_shield(off), String(e[1]), off)
		var m := CharacterModel.new()
		m.setup(spec)
		main.add_child(m)
		m.position = Vector3(x, 0.0, 40.0)
		m.set_meta("case", e)
		x += 1.5
		models.append(m)


func _check_held() -> void:
	for m in models:
		var e: Array = m.get_meta("case")
		var who := "герой с «%s»" % String(e[0])
		check(m._asset != null, "%s: модель из файла" % who)
		for pair in e[3]:
			var node_name := String(pair[0])
			var id := String(pair[1])
			var w := m.find_child(node_name, true, false) as MeshInstance3D
			check(w != null, "%s: в руке %s" % [who, node_name])
			if w == null:
				continue
			check(String(w.get_meta("handheld", "")) == id and w.mesh == Handheld.mesh(id),
				"%s: %s — меш из файла %s (%s)" % [who, node_name, id, w.get_meta("handheld", "процедурный")])
			check(w.mesh != CharacterModel._sword_mesh() and w.mesh != CharacterModel._dagger_mesh(),
				"%s: %s — не процедурный меш" % [who, node_name])
			check(w.material_override == Handheld.material(id), "%s: %s — материал модели из файла" % [who, node_name])
			var hand := w.get_parent() as BoneAttachment3D
			check(hand != null, "%s: %s на метке кисти" % [who, node_name])
			if node_name == "Shield":
				check(hand != null and hand.name == "GripL", "%s: щит в левой руке" % who)
				# Хват кисти (_grip_xf): +X — к костяшкам; верх щита — обратно, к локтю; лицо — к −Z хвата
				var gb := w.transform.basis * Handheld.SHIELD_IN_HAND.inverse()
				check((w.transform.basis * Vector3.UP).dot(-(gb * Vector3.RIGHT)) > 0.99,
					"%s: верх щита — вдоль предплечья, к локтю" % who)
				check((w.transform.basis * Vector3.BACK).dot(-(gb * Vector3.BACK)) > 0.99,
					"%s: лицо щита — наружу (тыльная сторона кисти)" % who)
			if node_name.ends_with("L") or node_name == "Bow":
				check(hand != null and hand.name == "GripL", "%s: %s в левой руке" % [who, node_name])


## Без файлов — прежние процедурные меши.
func _check_fallback() -> void:
	Handheld.force_missing = true
	var m := CharacterModel.new()
	m.setup(CharacterModel.spec_for("dark_elf", "assassin", "sword_1h", "f", false, "weapon_sword_1h_r1"))
	main.add_child(m)
	var w := m.find_child("Sword", true, false) as MeshInstance3D
	check(w != null and w.mesh == CharacterModel._sword_mesh() and not w.has_meta("handheld"),
		"без файлов оружия — процедурный меч")
	check(Handheld.model_for("weapon_sword_1h_r1") == "", "без файлов модель предмета не выбирается")
	Handheld.force_missing = false
	m.queue_free()


## Игрок: в руках модель надетого предмета.
func _check_player() -> void:
	var player: Player = main.player
	var want := Handheld.model_for(game.weapon)
	check(want != "", "у надетого оружия игрока (%s) есть модель из файла" % game.weapon)
	var found := false
	for n in player._model.find_children("*", "MeshInstance3D", true, false):
		if String((n as Node).get_meta("handheld", "")) == want:
			found = true
	check(found, "у игрока в руке модель %s" % want)
