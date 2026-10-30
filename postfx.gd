class_name PostFx
extends CanvasLayer
## Постобработка поверх 3D и под интерфейсом (layer = -1; HUD — слой 1): полноэкранный ColorRect
## со своим canvas_item-шейдером postfx.gdshader — виньетка, насыщенность и тёплый баланс,
## на «Высоком» ещё мягкое свечение светлых мест. Касания не перехватывает (MOUSE_FILTER_IGNORE).
## Включается по Quality.postfx(); на «Среднем» облегчённый вариант шейдера (без свечения и mip-уровней).
## Создание: add_child(PostFx.new()); после смены качества — Quality.apply(get_tree()).

const SHADER_PATH := "res://postfx.gdshader"

static var _full: Shader = null
static var _lite: Shader = null

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


## Включает, выключает или переключает вариант шейдера по текущему Quality.
func apply_quality() -> void:
	if _rect == null:
		return
	var on := Quality.postfx()
	visible = on
	_rect.visible = on
	if not on:
		return
	var bloom := Quality.bloom()
	var sh := _shader(bloom)
	if _mat.shader != sh:
		_mat.shader = sh
	_mat.set_shader_parameter("bloom_strength", 0.3 if bloom else 0.0)


## Полный шейдер или облегчённый (тот же код с #define POSTFX_LITE вместо строки-метки).
static func _shader(bloom: bool) -> Shader:
	if _full == null:
		_full = load(SHADER_PATH)
	if bloom:
		return _full
	if _lite == null:
		_lite = Shader.new()
		_lite.code = _full.code.replace("// @VARIANT", "#define POSTFX_LITE")
	return _lite
