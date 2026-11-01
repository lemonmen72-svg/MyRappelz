class_name Overhead
extends Node3D
## Подпись над головой зверя и питомца (компактная): одна строка «Ур. N Имя» (Label3D, видна сквозь модели), под ней —
## тонкая полоска HP (Sprite3D: подложка и заливка по доле HP), над строкой — значок задания (Sprite3D с картинкой
## UiIcons quest_target — красный значок над зверем, нужным по взятому заданию; Quests.refresh_mob_marks).
## Было: две строки «Имя  Ур.N» и «HP/макс.» шрифтом 40. Размеры — в мире, с UiScale (world_px) и множителем size_k
## (питомец мельче — Pet.LABEL_PX). Узел стоит в начале координат хозяина: положения детей — от его земли.

## Шрифт строки и обводка.
const FONT := 34
const OUTLINE := 9
## Полоска HP: размер текстуры (px) и ширина в мире, м («Средний», size_k = 1).
const TEX_W := 100
const TEX_H := 7
const BAR_W := 0.72
## Дальше этого расстояния от камеры полоска HP не рисуется, м.
const BAR_RANGE := 40.0
## Значок задания: высота, м («Средний»); зазоры между полоской, строкой и значком.
const MARK_H := 0.32
const GAP := 0.03

var label: Label3D
var bar_bg: Sprite3D
var bar_fill: Sprite3D
var mark: Sprite3D

var _k := 1.0
var _frac := -1.0
var _top := 0.0

static var _bar_tex: ImageTexture = null


## size_k — множитель размера (1 — зверь), name_color — цвет имени, bar_color — цвет полоски HP.
func setup(size_k: float, name_color: Color, bar_color: Color) -> void:
	_k = size_k
	label = Label3D.new()
	label.name = "NameLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = UiScale.world_px(0.01 * size_k)
	label.font_size = FONT
	label.outline_size = OUTLINE
	label.modulate = name_color
	label.render_priority = 3
	label.outline_render_priority = 2
	add_child(label)
	var px := BAR_W * size_k * UiScale.k() / float(TEX_W)
	bar_bg = _sprite("BarBack", _bar_texture(), Color(0.04, 0.04, 0.1, 0.78), px, 0)
	bar_fill = _sprite("BarFill", _bar_texture(), bar_color, px, 1)
	bar_fill.region_enabled = true
	bar_fill.region_rect = Rect2(0, 0, TEX_W, TEX_H)
	# Полоска видна вблизи (дальние звери — только имя): меньше вызовов отрисовки
	bar_bg.visibility_range_end = BAR_RANGE
	bar_fill.visibility_range_end = BAR_RANGE
	var tex := UiIcons.texture("quest_target")
	mark = _sprite("QuestTarget", tex, Color.WHITE, MARK_H * size_k * UiScale.k() / maxf(1.0, float(tex.get_height())), 4)
	mark.centered = true
	mark.offset = Vector2.ZERO
	mark.visible = false


## Положение по высоте: top — верх модели, м (полоска чуть выше, над ней строка, над строкой значок).
func place(top: float) -> void:
	_top = top
	var lh := float(label.font_size) * label.pixel_size
	var bh := float(TEX_H) * bar_bg.pixel_size
	var y := top + 0.06 + bh * 0.5
	bar_bg.position.y = y
	bar_fill.position.y = y
	label.position.y = y + bh * 0.5 + GAP + lh * 0.5
	mark.position.y = label.position.y + lh * 0.55 + GAP + mark_height() * 0.5


## Высота значка задания в мире, м.
func mark_height() -> float:
	if mark == null or mark.texture == null:
		return 0.0
	return float(mark.texture.get_height()) * mark.pixel_size


func set_text(t: String) -> void:
	if label.text != t:
		label.text = t


func set_name_color(c: Color) -> void:
	if label.modulate != c:
		label.modulate = c


## Доля HP на полоске (перерисовка — только при заметном изменении).
func set_hp(hp: int, max_hp: int) -> void:
	var f := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	if absf(f - _frac) < 0.004:
		return
	_frac = f
	bar_fill.visible = f > 0.0
	bar_fill.region_rect = Rect2(0, 0, maxf(1.0, roundf(float(TEX_W) * f)), TEX_H)


## Доля HP на полоске (для тестов).
func hp_frac() -> float:
	return _frac


## Красный значок задания над строкой.
func set_mark(on: bool) -> void:
	if mark.visible != on:
		mark.visible = on


func mark_visible() -> bool:
	return mark != null and mark.visible


func _sprite(nm: String, tex: Texture2D, col: Color, px: float, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = nm
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.modulate = col
	s.pixel_size = px
	s.render_priority = prio
	# Левый край полосок — на одном месте (заливка укорачивается справа)
	s.centered = false
	s.offset = Vector2(-float(TEX_W) * 0.5, -float(TEX_H) * 0.5)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


## Белая текстура полоски (цвет — modulate), общая для всех.
static func _bar_texture() -> ImageTexture:
	if _bar_tex == null:
		var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_bar_tex = ImageTexture.create_from_image(img)
	return _bar_tex
