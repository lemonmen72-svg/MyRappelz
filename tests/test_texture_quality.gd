extends "res://tests/test_base.gd"
## Качество текстур моделей (решение Максима: «текстуры на максимум от исходного»): у героев, жителей, зверей,
## атласов построек и предметов в руках .png.import — VRAM-сжатие высокого качества (compress/mode=2,
## compress/high_quality=true: ASTC 4×4 на телефоне вместо ETC2) и мипмапы. Размеры (по заголовку PNG): герои,
## жители и звери — 2048 (как исходники Meshy); атласы построек — по props.json, дома и башни в клетках 2048, мелочи
## и природа — 1024; оружие и предметы в руках — по handheld.json, не меньше 1024 (двуручное, луки, арбалеты,
## щиты — 2048). Треугольников у зверей — по creatures.json: не меньше 16 тыс. (овца — 10 тыс.).

const MODEL_DIRS := ["res://assets/characters/", "res://assets/creatures/", "res://assets/handheld/"]


func race_class() -> Array:
	return ["human", "wanderer"]


func run_step() -> void:
	match step:
		0:
			var n := 0
			for d in MODEL_DIRS:
				for f in DirAccess.get_files_at(String(d)):
					if f.get_extension() == "png":
						_check_import(String(d) + f)
						n += 1
			for f in DirAccess.get_files_at("res://assets/props/"):
				if f.begins_with("props_") and f.get_extension() == "png":
					_check_import("res://assets/props/" + f)
					n += 1
			check(n >= 38 + 22 + 30 + 6, "текстур моделей проверено %d" % n)
			_check_sizes()
			ok_done()


## .png.import: VRAM-сжатие высокого качества и мипмапы.
func _check_import(path: String) -> void:
	var cf := ConfigFile.new()
	var err := cf.load(path + ".import")
	check(err == OK, "%s.import читается" % path.get_file())
	if err != OK:
		return
	var mode := int(cf.get_value("params", "compress/mode", -1))
	var hq := bool(cf.get_value("params", "compress/high_quality", false))
	var mips := bool(cf.get_value("params", "mipmaps/generate", false))
	check(mode == 2 and hq and mips, "%s: VRAM-сжатие высокого качества и мипмапы (mode %d, high_quality %s, mipmaps %s)"
		% [path.get_file(), mode, hq, mips])


## Ширина и высота PNG по заголовку (IHDR), без загрузки картинки.
func _png_size(path: String) -> Vector2i:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	var b := f.get_buffer(24)
	if b.size() < 24:
		return Vector2i.ZERO
	var w := (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19]
	var h := (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23]
	return Vector2i(w, h)


func _json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _check_sizes() -> void:
	# Герои, жители, звери — 2048 (как исходники)
	for d in ["res://assets/characters/", "res://assets/creatures/"]:
		for f in DirAccess.get_files_at(String(d)):
			if f.get_extension() != "png":
				continue
			var s := _png_size(String(d) + f)
			check(s == Vector2i(2048, 2048), "%s: текстура %d×%d (2048)" % [f, s.x, s.y])
	# Звери: треугольников по creatures.json
	var cr := _json("res://assets/creatures/creatures.json")
	check(cr.size() >= 22, "creatures.json: зверей %d" % cr.size())
	for k in cr.keys():
		var tris := int((cr[k] as Dictionary).get("tris", 0))
		var need := 9500 if String(k) == "sheep" else 15500
		check(tris >= need and tris <= 30000, "%s: треугольников %d (%d…30000)" % [k, tris, need])
	# Атласы построек: размер страницы как в props.json, клетки домов 2048, остальные 1024
	var pr := _json("res://assets/props/props.json")
	var pages: Dictionary = pr.get("pages", {})
	check(pages.size() == 6, "страниц атласа построек %d" % pages.size())
	for pg in pages.keys():
		var info: Dictionary = pages[pg]
		var want: Array = info.get("size", [0, 0])
		var s := _png_size("res://assets/props/" + String(info.get("file", "")))
		check(s == Vector2i(int(want[0]), int(want[1])) and s.x >= 4096,
			"атлас %s: %d×%d (по props.json %s)" % [pg, s.x, s.y, want])
	var big := 0
	var props: Dictionary = pr.get("props", {})
	for id in props.keys():
		var slot: Array = (props[id] as Dictionary).get("slot", [0, 0, 0])
		check(int(slot[2]) >= 1024, "%s: клетка атласа %d (≥ 1024)" % [id, int(slot[2])])
		if int(slot[2]) >= 2048:
			big += 1
	check(big >= 13, "домов и башен в клетках 2048: %d" % big)
	# Оружие и предметы в руках: текстура по handheld.json, не меньше 1024
	var hh := _json("res://assets/handheld/handheld.json")
	var items: Dictionary = hh.get("items", {})
	check(items.size() >= 30, "предметов в руках %d" % items.size())
	for id in items.keys():
		var tex := int((items[id] as Dictionary).get("tex", 0))
		var s := _png_size("res://assets/handheld/%s.png" % id)
		check(tex >= 1024 and s == Vector2i(tex, tex), "%s: текстура %d×%d (по handheld.json %d)" % [id, s.x, s.y, tex])
		var kind := String((items[id] as Dictionary).get("kind", ""))
		if kind in ["sword_2h", "mace_2h", "axe_2h", "staff_2h", "spear", "bow", "crossbow", "shield"]:
			check(tex == 2048, "%s (%s): текстура 2048" % [id, kind])
