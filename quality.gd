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
	"Без теней, текстур и постобработки, трава редкая и только рядом, у кустов и камней нет контуров. Для слабых телефонов.",
	"Тени рядом с игроком, рисованные текстуры земли и построек, трава средней густоты. Рекомендуется.",
	"Тени дальше и чётче, мягкое свечение светлых мест, густая трава вдаль, тени от кустов и камней.",
]
## grass_density — доля от полной густоты травы; *_distance — дальность видимости, м;
## shadow_atlas — размер карты теней солнца; postfx — цветокоррекция и виньетка; bloom — свечение;
## outlines — контуры (персонажи, звери, постройки, растительность); small_shadows — тени от кустов и камней;
## render_scale — меньше 1: кадр рисуется высотой 720 px и растягивается (см. apply_resolution);
## textures — рисованные текстуры земли и построек (WorldTextures; на «Низком» без выборок текстур).
const PRESETS := [
	{
		"grass_density": 0.35, "grass_distance": 24.0, "grass_blades": 4, "flower_density": 0.45,
		"detail_distance": 45.0, "tree_distance": 90.0,
		"shadows": false, "shadow_distance": 0.0, "shadow_splits": false, "shadow_atlas": 1024,
		"small_shadows": false, "postfx": false, "bloom": false, "outlines": false,
		"render_scale": 0.6, "rich_shaders": false, "textures": false,
	},
	{
		"grass_density": 0.65, "grass_distance": 38.0, "grass_blades": 5, "flower_density": 0.75,
		"detail_distance": 65.0, "tree_distance": 125.0,
		"shadows": true, "shadow_distance": 28.0, "shadow_splits": false, "shadow_atlas": 1024,
		"small_shadows": false, "postfx": false, "bloom": false, "outlines": true,
		"render_scale": 0.75, "rich_shaders": false, "textures": true,
	},
	{
		"grass_density": 1.0, "grass_distance": 58.0, "grass_blades": 6, "flower_density": 1.0,
		"detail_distance": 95.0, "tree_distance": 175.0,
		"shadows": true, "shadow_distance": 60.0, "shadow_splits": true, "shadow_atlas": 4096,
		"small_shadows": true, "postfx": true, "bloom": true, "outlines": true,
		"render_scale": 1.0, "rich_shaders": true, "textures": true,
	},
]

## Ограничение частоты кадров. Без него экраны 90–120 Гц рисуют в 1.5–2 раза больше кадров,
## чем нужно, и телефон греется. 30 — меньше всего греется и дольше держит батарея.
const FPS_OPTIONS := [30, 45, 60]
const DEFAULT_FPS := 60

static var _level := -1
static var _fps := -1


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
	if save:
		_save("quality", _level)


## Предел кадров в секунду (одно из FPS_OPTIONS), по умолчанию 60.
static func fps_limit() -> int:
	if _fps < 0:
		_fps = DEFAULT_FPS
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_fps = int(cf.get_value("graphics", "fps", DEFAULT_FPS))
		if not FPS_OPTIONS.has(_fps):
			_fps = DEFAULT_FPS
	return _fps


static func set_fps_limit(v: int, save: bool = true) -> void:
	_fps = v if FPS_OPTIONS.has(v) else DEFAULT_FPS
	if save:
		_save("fps", _fps)
	apply_fps()


## Включить предел кадров (в headless-тестах не ограничиваем — они идут быстрее реального времени).
static func apply_fps() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = fps_limit()


## Записать ключ секции [graphics] (другие ключи и секции файла сохраняются).
static func _save(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)  # нет файла — начнём с пустого
	cf.set_value("graphics", key, value)
	var err := cf.save(PATH)
	if err != OK:
		push_warning("Не удалось сохранить настройки графики: %d" % err)


## Перечитать выбор из файла при следующем запросе.
static func reload() -> void:
	_level = -1
	_fps = -1


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
## Полные (дорогие) версии шейдеров земли и воды; иначе — облегчённые.
static func rich_shaders() -> bool:
	return bool(_p("rich_shaders"))


## Рисованные текстуры земли и построек (WorldTextures). Полный режим (две выборки против повтора,
## triplanar) — вместе с rich_shaders().
static func textures() -> bool:
	return bool(_p("textures"))


static func outlines() -> bool:
	return bool(_p("outlines"))


## Применяет текущий пресет ко всему, что уже создано: солнце, постобработка, растительность.
static func apply(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	apply_lights(tree.root)
	apply_resolution(tree)
	apply_fps()
	if IslandWorld.current != null and IslandWorld.current.terrain_material != null:
		IslandWorld.current.terrain_material.set_shader_parameter("rich", rich_shaders())
	if IslandWater.material != null:
		IslandWater.material.set_shader_parameter("rich", rich_shaders())
	for n in tree.get_nodes_in_group("postfx"):
		if n.has_method("apply_quality"):
			n.call("apply_quality")
	IslandVegetation.apply_quality(tree)
	PoiModels.apply_quality()
	WorldTextures.apply_quality()


## Разрешение рендера: на «Низком» и «Среднем» кадр рисуется высотой 720 пикселей (ширина — по
## пропорциям экрана) и растягивается на экран. У телефонов 2400×1080 и больше это в 2–3 раза меньше
## пикселей. Интерфейс свёрстан под высоту 720, поэтому раскладка не меняется. «Высокое» — родное разрешение.
static func apply_resolution(tree: SceneTree) -> void:
	var win := tree.root
	if float(_p("render_scale")) >= 0.999:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_size = Vector2i(1280, 720)
		return
	var screen := Vector2(DisplayServer.window_get_size())
	if screen.x < 2.0 or screen.y < 2.0:
		return
	var h := minf(720.0, screen.y)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_size = Vector2i(int(roundf(h * screen.x / screen.y)), int(h))


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
