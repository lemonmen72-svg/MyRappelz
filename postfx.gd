class_name PostFx
extends CanvasLayer
## Постобработка поверх 3D и под интерфейсом (layer = -1; HUD — слой 1): полноэкранный ColorRect
## со своим canvas_item-шейдером postfx.gdshader — сглаживание FXAA, цветокоррекция (насыщенность, тёплый
## баланс, виньетка), мягкое свечение светлых мест. Касания не перехватывает (MOUSE_FILTER_IGNORE).
## Что включено — по Quality: postfx_fxaa() (сглаживание «FXAA» в Compatibility; в Mobile FXAA встроенный —
## Viewport.screen_space_aa, здесь не считается), postfx() (цвет), bloom() (свечение). Ничего —
## слой скрыт, экран не копируется (на «Низком» и «Среднем» прохода нет). Вариант шейдера собирается из одного
## кода с #define вместо строки-метки (USE_FXAA, USE_GRADE, USE_BLOOM): лишние выборки не считаются.
## Создание: add_child(PostFx.new()); после смены настроек — Quality.apply(get_tree()).

const SHADER_PATH := "res://postfx.gdshader"

static var _base: Shader = null
## Варианты шейдера по ключу "fxaa|grade|bloom".
static var _variants: Dictionary = {}

var _rect: ColorRect = null
var _mat: ShaderMaterial = null


func _init() -> void:
	name = "PostFx"
	layer = -1


func _ready() -> void:
	add_to_group("postfx")
	_mat = ShaderMaterial.new()
	_rect = ColorRect.new()
	_rect.name = "Screen"
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _mat
	add_child(_rect)
	apply_quality()


## Включает, выключает или переключает вариант шейдера по текущим настройкам Quality.
func apply_quality() -> void:
	if _rect == null:
		return
	var fxaa := Quality.postfx_fxaa()
	var grade := Quality.postfx()
	var bloom := Quality.bloom()
	var on := fxaa or grade
	visible = on
	_rect.visible = on
	if not on:
		return
	var sh := shader_for(fxaa, grade, bloom)
	if _mat.shader != sh:
		_mat.shader = sh
	_mat.set_shader_parameter("bloom_strength", 0.16 if bloom else 0.0)


## Текущий шейдер (null — постобработка выключена).
func current_shader() -> Shader:
	return _mat.shader if _rect != null and _rect.visible else null


## Вариант шейдера (кэш): тот же код с #define вместо строки-метки.
static func shader_for(fxaa: bool, grade: bool, bloom: bool) -> Shader:
	if _base == null:
		_base = load(SHADER_PATH)
	bloom = bloom and grade
	var key := "%s|%s|%s" % [fxaa, grade, bloom]
	if _variants.has(key):
		return _variants[key]
	var defs := ""
	if fxaa:
		defs += "#define USE_FXAA\n"
	if grade:
		defs += "#define USE_GRADE\n"
	if bloom:
		defs += "#define USE_BLOOM\n"
	var sh := Shader.new()
	sh.code = _base.code.replace("// @VARIANT", defs)
	_variants[key] = sh
	return sh
