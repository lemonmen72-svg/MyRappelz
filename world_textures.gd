class_name WorldTextures
extends RefCounted
## Рисованные текстуры окружения (assets/textures/*.png, их делает tools/gen_textures.py).
## Текстуры — «детальные маски»: почти серые, среднее 0.5; шейдеры умножают цвет на tex * 2,
## поэтому палитра острова и цвета построек сохраняются, а текстура добавляет мазки, швы, доски.
##
## Земля (island_terrain.gdshader): трава, утоптанная земля, песок, скала, брусчатка города.
## Постройки (toon.gdshader): номер текстуры детали — в альфе цвета вершины (PoiModels.Kit,
## layer_alpha) или параметр tex_layer у материала целиком (настил моста).
##
## Качество (Quality.textures()): на «Низком» выборок текстур нет (флаг textures = false, шейдеры
## как раньше). «Среднее» — одна выборка на слой (земля — по XZ, постройки — по главной оси нормали).
## «Высокое» (Quality.rich_shaders()) — земля: две выборки травы и дорог против заметного повтора,
## triplanar на скалах; постройки: triplanar (у боксов всё равно одна выборка — веса 0 пропускаются).
## Текстуры загружаются только при включённом флаге. Смена качества — apply_quality().

const DIR := "res://assets/textures/"

## Номера текстур построек (альфа цвета вершины = 1 − номер / 16; 0 — без текстуры).
const NONE := 0
const WOOD := 1
const STONE := 2
const PLASTER := 3
const TILES := 4
const THATCH := 5
const ROCK := 6

## Параметр шейдера → имя файла текстуры.
const TERRAIN_SAMPLERS := {
	"tex_grass": "grass", "tex_dirt": "dirt", "tex_sand": "sand", "tex_rock": "rock", "tex_stone": "stone",
}
const TOON_SAMPLERS := {
	"tex_wood": "wood", "tex_stone": "stone", "tex_plaster": "plaster", "tex_tiles": "tiles",
	"tex_thatch": "thatch", "tex_rock": "rock",
}
const ALL := ["grass", "dirt", "sand", "rock", "stone", "wood", "tiles", "thatch", "plaster"]

static var _cache := {}
## Материалы, которые переключает apply_quality() (WeakRef: материалы могут освободиться).
static var _terrain: Array[WeakRef] = []
static var _toon: Array[WeakRef] = []


## Текстура по имени (кэш).
static func texture(tex_name: String) -> Texture2D:
	if not _cache.has(tex_name):
		_cache[tex_name] = load(DIR + tex_name + ".png") as Texture2D
	return _cache[tex_name]


## Альфа цвета вершины с номером текстуры (читает toon.gdshader).
static func layer_alpha(layer: int) -> float:
	return 1.0 - float(clampi(layer, 0, 15)) / 16.0


## Материал земли (island_terrain.gdshader): выставляет текстуры и флаги по качеству, запоминает.
static func register_terrain(m: ShaderMaterial) -> void:
	_terrain.append(weakref(m))
	_apply(m, TERRAIN_SAMPLERS, true)


## Toon-материал (toon.gdshader): то же.
static func register_toon(m: ShaderMaterial) -> void:
	_toon.append(weakref(m))
	_apply(m, TOON_SAMPLERS, false)


## Применяет текущее качество ко всем запомненным материалам (без перезапуска).
static func apply_quality() -> void:
	_terrain = _apply_all(_terrain, TERRAIN_SAMPLERS, true)
	_toon = _apply_all(_toon, TOON_SAMPLERS, false)


static func _apply_all(list: Array[WeakRef], samplers: Dictionary, terrain: bool) -> Array[WeakRef]:
	var alive: Array[WeakRef] = []
	for wr in list:
		var m := wr.get_ref() as ShaderMaterial
		if m == null:
			continue
		alive.append(wr)
		_apply(m, samplers, terrain)
	return alive


static func _apply(m: ShaderMaterial, samplers: Dictionary, terrain: bool) -> void:
	var on := Quality.textures()
	if on:
		for param in samplers:
			if m.get_shader_parameter(param) == null:
				m.set_shader_parameter(param, texture(String(samplers[param])))
	m.set_shader_parameter("textures", on)
	if terrain:
		m.set_shader_parameter("rich", Quality.rich_shaders())
	else:
		m.set_shader_parameter("tex_triplanar", Quality.rich_shaders())
