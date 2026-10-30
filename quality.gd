class_name Quality
extends RefCounted
## Настройки качества графики: пресеты «Низкое» / «Среднее» (по умолчанию) / «Высокое».
## Выбор хранится в user://settings.cfg (секция [graphics], ключ quality), читается при первом запросе.
## Геттеры статические: Quality.level(), Quality.grass_density(), Quality.shadows(), Quality.postfx()...
## Применение без перезапуска: Quality.apply(get_tree()) — тени солнца, постобработка (PostFx),
## дальность и контуры растительности. Плотность травы и цветов — при следующем построении мира.

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const PATH := "user://settings.cfg"
const NAMES := ["Низкое", "Среднее", "Высокое"]
const DESCRIPTIONS := [
	"Без теней и постобработки, трава редкая и только рядом, у кустов и камней нет контуров. Для слабых телефонов.",
	"Тени рядом с игроком, лёгкая цветокоррекция и виньетка, трава средней густоты. Рекомендуется.",
	"Тени дальше и чётче, мягкое свечение светлых мест, густая трава вдаль, тени от кустов и камней.",
]
## grass_density — доля от полной густоты травы; *_distance — дальность видимости, м;
## shadow_atlas — размер карты теней солнца; postfx — цветокоррекция и виньетка; bloom — свечение;
## outlines — контуры у мелочей (кусты, камни); small_shadows — тени от кустов и камней.
const PRESETS := [
	{
		"grass_density": 0.35, "grass_distance": 24.0, "grass_blades": 4, "flower_density": 0.45,
		"detail_distance": 45.0, "tree_distance": 90.0,
		"shadows": false, "shadow_distance": 0.0, "shadow_splits": false, "shadow_atlas": 1024,
		"small_shadows": false, "postfx": false, "bloom": false, "outlines": false,
	},
	{
		"grass_density": 0.65, "grass_distance": 38.0, "grass_blades": 5, "flower_density": 0.75,
		"detail_distance": 65.0, "tree_distance": 125.0,
		"shadows": true, "shadow_distance": 32.0, "shadow_splits": false, "shadow_atlas": 2048,
		"small_shadows": false, "postfx": true, "bloom": false, "outlines": true,
	},
	{
		"grass_density": 1.0, "grass_distance": 58.0, "grass_blades": 6, "flower_density": 1.0,
		"detail_distance": 95.0, "tree_distance": 175.0,
		"shadows": true, "shadow_distance": 60.0, "shadow_splits": true, "shadow_atlas": 4096,
		"small_shadows": true, "postfx": true, "bloom": true, "outlines": true,
	},
]

static var _level := -1


## Текущий пресет (LOW, MEDIUM, HIGH).
static func level() -> int:
	if _level < 0:
		_level = MEDIUM
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_level = clampi(int(cf.get_value("graphics", "quality", MEDIUM)), LOW, HIGH)
	return _level


## Выбирает пресет; save — записать в user://settings.cfg (другие секции файла сохраняются).
static func set_level(l: int, save: bool = true) -> void:
	_level = clampi(l, LOW, HIGH)
	if not save:
		return
	var cf := ConfigFile.new()
	cf.load(PATH)  # нет файла — начнём с пустого
	cf.set_value("graphics", "quality", _level)
	var err := cf.save(PATH)
	if err != OK:
		push_warning("Не удалось сохранить настройки графики: %d" % err)


## Перечитать выбор из файла при следующем запросе.
static func reload() -> void:
	_level = -1


static func level_name(l: int = -1) -> String:
	return String(NAMES[clampi(level() if l < 0 else l, LOW, HIGH)])


static func description(l: int = -1) -> String:
	return String(DESCRIPTIONS[clampi(level() if l < 0 else l, LOW, HIGH)])


static func _p(key: String) -> Variant:
	var preset: Dictionary = PRESETS[level()]
	return preset[key]


static func grass_density() -> float:
	return float(_p("grass_density"))


static func grass_distance() -> float:
	return float(_p("grass_distance"))


## Травинок в пучке травы (меньше — дешевле вершинный шейдер).
static func grass_blades() -> int:
	return int(_p("grass_blades"))


static func flower_density() -> float:
	return float(_p("flower_density"))


## Дальность кустов, камней и кристаллов, м.
static func detail_distance() -> float:
	return float(_p("detail_distance"))


static func tree_distance() -> float:
	return float(_p("tree_distance"))


static func shadows() -> bool:
	return bool(_p("shadows"))


static func shadow_distance() -> float:
	return float(_p("shadow_distance"))


static func small_shadows() -> bool:
	return bool(_p("small_shadows"))


static func postfx() -> bool:
	return bool(_p("postfx"))


static func bloom() -> bool:
	return bool(_p("bloom"))


## Контуры у мелочей (кусты, камни). У деревьев, персонажей и зверей контуры есть всегда.
static func outlines() -> bool:
	return bool(_p("outlines"))


## Применяет текущий пресет ко всему, что уже создано: солнце, постобработка, растительность.
static func apply(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	apply_lights(tree.root)
	for n in tree.get_nodes_in_group("postfx"):
		if n.has_method("apply_quality"):
			n.call("apply_quality")
	IslandVegetation.apply_quality(tree)


## Тени направленных источников света (солнце) в поддереве root.
static func apply_lights(root: Node) -> void:
	if root == null:
		return
	var preset: Dictionary = PRESETS[level()]
	var on := bool(preset["shadows"])
	if on:
		RenderingServer.directional_shadow_atlas_set_size(int(preset["shadow_atlas"]), true)
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := n as DirectionalLight3D
		if sun == null:
			continue
		sun.shadow_enabled = on
		if on:
			sun.directional_shadow_max_distance = float(preset["shadow_distance"])
			if bool(preset["shadow_splits"]):
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			else:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
