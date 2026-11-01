class_name HUD
extends CanvasLayer
## Интерфейс: плавающий джойстик (левая нижняя часть экрана), круглые кнопки действий справа,
## панели игрока (HP, MP, опыт), питомца и цели, окна (герой, питомцы, сумка, торговец).
## У зверя-цели слева от полоски HP — значок приручения (Taming.badge_state): зелёный кружок — можно приручить
## и нужная карта существа в сумке, жёлто-серый — можно, но карты нет, фиолетовый — нельзя приручить;
## левее — квадратик цвета тира карты (коричневый, синий, фиолетовый, жёлтый).
## Панели компактные: у игрока — кружок с уровнем у начала полосок, ник мелко над полосками (справа — золото со
## значком), числа HP / MP и доля опыта — внутри своих полосок мелким шрифтом с обводкой; у питомца — так же
## (кружок уровня, имя над полосками, HP и MP в полосках); у цели — «Ур. N Имя · редкость» над полоской, HP в полоске.
## Меню справа вверху — значками (UiIcons: menu_hero, menu_pets, menu_bag, menu_quests, menu_settings): подпись —
## подсказкой при наведении мыши (ПК) и по долгому касанию (HOLD_TIP с — подпись под значком, кнопка не нажимается).
## Под меню — трекер заданий (Quests; касание по нему не вращает камеру — add_blocker). Джойстик — картинки
## joystick_base / joystick_knob, если они есть в assets/icons/ui, иначе кружки. «Закрыть» в окнах — значок ×.
## Размеры (джойстик, кнопки, панели, меню, окна) — из UiScale: базовые числа ниже даны для «Среднего» размера
## интерфейса и умножаются на UiScale.k(); смена размера в «Настройках» — apply_ui_scale() (HUD перестраивается сразу).
## На ПК: WASD/стрелки, Пробел = атака, 1–4 = умения, T = приручить, Q = зелье, K = окно героя,
## P = питомцы, C = окно существа, I или B = сумка, E = торговец, R = говорить, J = задания,
## питомец: Z = «Авто», F = «Атака» (цель героя), X = «Защита», G = «За мной»; O = настройки.
## Кнопки питомца (add_pet_button) — круглые, рядом под его панелью слева вверху (над зоной джойстика), видны
## только при призванном питомце; кнопка текущего режима питомца (поле mode: "pet_" + mode) — с кольцом.
## Круглые кнопки со значками (set_button_icon → IconView: умение, оружие, зелье с числом, карта существа, рисунок);
## перезарядка — тёмный сектор по часовой стрелке, неподходящее оружию — красная метка. Справа от полосок HP
## игрока, питомца и цели — значки действующих эффектов (StatusRow по реестру StatusEffects сущности);
## касание по значку эффекта — подпись (название, сколько осталось).
## Полоса каста (update_cast): пока герой кастует умение — под героем по центру экрана, название умения и сколько
## осталось; не на кнопках и не на джойстике (tests/test_ui_scale.gd).

## Нажатие кнопки действия (касание, клавиша или кнопка меню).
signal action(id: String)
## Размер интерфейса изменился (apply_ui_scale): модули перестраивают свои элементы на HUD (трекер заданий).
signal scale_changed

## Базовые размеры («Средний», умножаются на UiScale.k()).
## Джойстик: радиус основы и ручки, центр в покое — от левого нижнего угла (было 110 / 45 / (210, 190)).
const JOY_RADIUS := 80.0
const JOY_KNOB := 32.0
const JOY_HOME := Vector2(150, 140)
## Джойстик не начинается выше этой линии: там панели и кнопки меню.
const JOY_TOP := 190.0
## Вращение камеры не начинается выше этой линии (кнопки меню справа вверху).
const CAM_TOP := 66.0
## Наименьший радиус круглой кнопки после масштаба, px (диаметр не меньше 56 — под палец).
const BUTTON_MIN_R := 28.0
## Зона касания круглой кнопки — радиус × TOUCH_K.
const TOUCH_K := 1.1
const KEYS := {
	KEY_SPACE: "attack", KEY_1: "skill1", KEY_2: "skill2", KEY_3: "skill3", KEY_4: "skill4", KEY_T: "tame",
	KEY_Q: "potion", KEY_K: "hero_window",
	KEY_P: "pets_window", KEY_I: "bag_window", KEY_E: "shop", KEY_F: "pet_attack", KEY_G: "pet_follow", KEY_O: "settings_window",
	KEY_Z: "pet_auto", KEY_X: "pet_defend",
	KEY_C: "creature_window", KEY_B: "bag_window", KEY_R: "talk", KEY_J: "quest_window",
}
## Кнопки меню — квадратные значки: сторона и поле вокруг значка; «Существо» у панели питомца — того же вида.
## Долгое касание по значку меню (HOLD_TIP с) — подпись под ним вместо нажатия.
const MENU_ICON := 38.0
const MENU_PAD := 4
const MENU_GAP := 5.0
const HOLD_TIP := 0.45
## Панель игрока («Средний»): отступ от левого и верхнего края, диаметр кружка уровня, ширина полосок, высоты полосок
## HP / MP / опыта и зазор между ними, строка ника над полосками (высота, шрифт), шрифты чисел в полосках.
## Было: полоски 260 × 18 / 8 / 5 и строка «ник, уровень, HP, MP, золото» шрифтом 14 под ними (высота панели ≈ 56 px,
## ширина строки до ≈ 380 px); стало ≈ 52 × 257 px, числа — в полосках.
const PANEL_X := 14.0
const PANEL_Y := 10.0
const LVL_D := 32.0
const PANEL_W := 220.0
const HP_H := 14.0
const MP_H := 10.0
const XP_H := 9.0
const BAR_GAP := 2.0
const NAME_H := 14.0
const NAME_FONT := 12
const HP_FONT := 12
const MP_FONT := 10
const XP_FONT := 9
## Панель питомца: кружок уровня, ширина и высоты полосок HP / MP, шрифты (было: строка «имя, уровень, HP» шрифтом 14
## над полосками 180 × 10 / 6).
const PET_LVL_D := 24.0
const PET_W := 170.0
const PET_HP_H := 13.0
const PET_MP_H := 10.0
const PET_FONT := 11
const PET_MP_FONT := 9
## Панель цели: ширина полоски, высота полоски и шрифт числа HP в ней, наименьший отступ слева (правее панели
## игрока), шрифт подписи «Ур. N Имя · редкость» над полоской (было 15 и полоска 12 без чисел).
const TARGET_W := 240.0
const TARGET_BAR_H := 14.0
const TARGET_HP_FONT := 11
const TARGET_MIN_X := 430.0
const TARGET_FONT := 13
## Цвет кружков уровня и их рамки.
const LVL_BG := Color(0.1, 0.12, 0.26, 0.92)
const LVL_RIM := Color(1.0, 0.85, 0.4, 0.95)
## Значки меню HUD: id действия → id значка UiIcons.
const MENU_ICONS := [
	["hero_window", "menu_hero"], ["pets_window", "menu_pets"], ["bag_window", "menu_bag"],
	["quest_window", "menu_quests"], ["settings_window", "menu_settings"],
]
## Сообщения на экране: высота строки сверху и шрифт (было 190 / 28).
const MSG_Y := 165.0
const MSG_FONT := 19
## Значки эффектов у полосок HP: размер и зазор («Средний»), ширина ряда питомца.
const FX_ICON := 26.0
const FX_GAP := 4.0
const FX_PET_W := 240.0
## Круглые кнопки питомца: радиус («Средний»; не меньше BUTTON_MIN_R), зазор между ними и отступ от полосок питомца.
const PET_BTN_R := 28.0
const PET_BTN_GAP := 6.0
const PET_BTN_TOP := 6.0
## Кольцо на кнопке текущего режима питомца.
const PET_MODE_ON := Color(0.35, 0.9, 1.0, 0.7)
## Полоса каста: ширина, высота, шрифт подписи и где по высоте экрана центр полосы (доля: под героем, выше кнопок
## «Говорить» / «Торговец»).
const CAST_W := 240.0
const CAST_H := 12.0
const CAST_FONT := 15
const CAST_Y := 0.7
const CAST_COLOR := Color(1.0, 0.78, 0.3)

var move_vec := Vector2.ZERO

## id -> {"panel": Panel, "label": Label, "offset": Vector2, "r": float, "hold": bool, "touch": int,
## "color": Color (заливка), "blocked": bool (не подходит оружию — затемнена),
## "base_offset": Vector2, "base_r": float (как передано в add_button, для «Среднего»),
## "icon": IconView или null (значок вместо подписи — set_button_icon)}.
## offset и r — уже с масштабом UiScale.
var _buttons := {}
var _joy_idx := -1
## Касания камеры (индекс → последняя позиция): один палец в правой половине экрана вне кнопок
## вращает камеру, два пальца щипком приближают и отдаляют. Накопленные сдвиг и множитель дальности.
var _cam_touches := {}
var _cam_drag := Vector2.ZERO
var _cam_zoom := 1.0
var _joy_center := Vector2.ZERO
## Радиус джойстика с масштабом.
var _joy_r := JOY_RADIUS
var _view := Vector2(1280, 720)
var _window: Control = null
var _target: Node3D = null

var _joy_base: Panel
var _joy_knob: Panel
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
## Числа внутри полосок игрока, кружок уровня (с числом), ник и золото над полосками.
var _hp_text: Label
var _mp_text: Label
var _xp_text: Label
var _lvl: Panel
var _lvl_text: Label
var _name_label: Label
var _gold_icon: TextureRect
var _gold_label: Label
var _pet_box: Control
var _pet_label: Label
var _pet_lvl: Panel
var _pet_lvl_text: Label
var _pet_bar: ProgressBar
var _pet_mp_bar: ProgressBar
var _pet_hp_text: Label
var _pet_mp_text: Label
var _target_box: Control
var _target_label: Label
var _target_bar: ProgressBar
var _target_hp_text: Label
## Долгое касание по значку меню: какая кнопка держится (до button_up), сколько, показана ли подпись (тогда
## отпускание не нажимает кнопку).
var _hold_btn: Button = null
var _hold_t := 0.0
var _hold_shown := false
## Значок приручения цели и квадратик тира карты.
var _tame_badge: Panel
var _tame_tier: Panel
## Что сейчас показывает значок: "" (скрыт), Taming.BADGE_READY / BADGE_NEED_CARD / BADGE_NO.
var target_tame_state := ""
## Тир карты цели ("basic", "rare", "special", "unique"; "" — значок скрыт).
var target_card_tier := ""
var _msg_label: Label
var _msg_time := 0.0
var _menu: HBoxContainer
## Кнопка «Существо» (окно существа) правее круглых кнопок питомца.
var _pet_btns: HBoxContainer
## Круглые кнопки питомца по порядку (add_pet_button) и верх их ряда в панели питомца (с масштабом).
var _pet_ids: Array[String] = []
var _pet_row_y := 0.0
## Элементы интерфейса поверх мира (трекер заданий): касание по ним не начинает джойстик и вращение камеры.
var _blockers: Array[Control] = []
## Значки эффектов справа от полосок HP игрока, питомца и цели; подпись по касанию значка.
var _fx_player: StatusRow
var _fx_pet: StatusRow
var _fx_target: StatusRow
var _fx_tip: Label
var _fx_tip_time := 0.0
## Полоса каста: рамка (подпись над полосой), полоса, подпись.
var _cast_box: Control
var _cast_bar: ProgressBar
var _cast_label: Label


func _ready() -> void:
	_joy_base = _circle(JOY_RADIUS, Color(1, 1, 1, 0.12))
	_joy_knob = _circle(JOY_KNOB, Color(1, 1, 1, 0.35))
	_skin_joystick(_joy_base, "joystick_base")
	_skin_joystick(_joy_knob, "joystick_knob")

	_hp_bar = _bar(self, Color(0.85, 0.2, 0.2))
	_mp_bar = _bar(self, Color(0.35, 0.5, 1.0))
	_xp_bar = _bar(self, Color(0.9, 0.8, 0.2))
	_hp_text = _bar_text(_hp_bar)
	_mp_text = _bar_text(_mp_bar)
	_xp_text = _bar_text(_xp_bar)
	_lvl = _square(self, 16)
	_lvl_text = _bar_text(_lvl)
	_style_level(_lvl)
	_name_label = _label(self)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_gold_icon = TextureRect.new()
	_gold_icon.texture = UiIcons.texture("gold")
	_gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gold_icon)
	_gold_label = _label(self)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_pet_box = Control.new()
	_pet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pet_box)
	_pet_label = _label(_pet_box)
	_pet_label.clip_text = true
	_pet_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pet_bar = _bar(_pet_box, Color(0.3, 0.75, 1.0))
	_pet_mp_bar = _bar(_pet_box, Color(0.55, 0.45, 1.0))
	_pet_hp_text = _bar_text(_pet_bar)
	_pet_mp_text = _bar_text(_pet_mp_bar)
	_pet_lvl = _square(_pet_box, 12)
	_pet_lvl_text = _bar_text(_pet_lvl)
	_style_level(_pet_lvl)
	_pet_btns = HBoxContainer.new()
	_pet_box.add_child(_pet_btns)
	_pet_btns.add_child(_menu_button("menu_creature", "creature_window"))

	_target_box = Control.new()
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_box)
	_target_label = _label(_target_box)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.clip_text = true
	_target_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_target_bar = _bar(_target_box, Color(0.9, 0.35, 0.2))
	_target_hp_text = _bar_text(_target_bar)
	_tame_badge = _square(_target_box, 2)
	_tame_tier = _square(_target_box, 2)
	_set_tame_badge("", "")
	_target_box.visible = false
	_fx_player = StatusRow.new()
	add_child(_fx_player)
	_fx_pet = StatusRow.new()
	_pet_box.add_child(_fx_pet)
	_fx_target = StatusRow.new()
	_target_box.add_child(_fx_target)

	_msg_label = _label(self)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))

	_fx_tip = _label(self)
	_fx_tip.visible = false

	_cast_box = Control.new()
	_cast_box.name = "CastBar"
	_cast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cast_box)
	_cast_label = _label(_cast_box)
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_cast_bar = _bar(_cast_box, CAST_COLOR)
	_cast_bar.max_value = 1.0
	_cast_box.visible = false

	_menu = HBoxContainer.new()
	_menu.name = "Menu"
	add_child(_menu)
	for e in MENU_ICONS:
		_menu.add_child(_menu_button(String(e[1]), String(e[0])))

	_apply_sizes()
	update_pet(null)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Размер интерфейса изменился (UiScale.set_level): тема, панели, кнопки, джойстик и открытое окно — заново.
func apply_ui_scale() -> void:
	Util.refresh_theme()
	_apply_sizes()
	for id in _buttons:
		_size_button(String(id))
	_layout()
	if is_window_open():
		var base: Vector2 = _window.get_meta("base_size", _window.size)
		_window.size = UiScale.window_size(base, _view)
		_keep_window_on_screen()
	scale_changed.emit()


## Размеры и шрифты панелей, джойстика и меню по UiScale (положение на экране — в _layout).
func _apply_sizes() -> void:
	_joy_r = UiScale.px(JOY_RADIUS)
	_resize_circle(_joy_base, _joy_r)
	_resize_circle(_joy_knob, UiScale.px(JOY_KNOB))

	# Игрок: кружок уровня слева, над полосками — ник и золото, полоски HP / MP / опыта с числами внутри
	var x := UiScale.px(PANEL_X)
	var top := UiScale.px(PANEL_Y)
	var w := UiScale.px(PANEL_W)
	var gap := UiScale.px(BAR_GAP)
	var hp_h := UiScale.px(HP_H)
	var mp_h := UiScale.px(MP_H)
	var xp_h := UiScale.px(XP_H)
	var name_h := UiScale.px(NAME_H)
	var ld := UiScale.px(LVL_D)
	var bx := x + ld + UiScale.px(5)
	var by := top + name_h
	var bars_h := hp_h + gap + mp_h + gap + xp_h
	_size_bar(_hp_bar, Vector2(bx, by), Vector2(w, hp_h))
	_size_bar(_mp_bar, Vector2(bx, by + hp_h + gap), Vector2(w, mp_h))
	_size_bar(_xp_bar, Vector2(bx, by + hp_h + gap + mp_h + gap), Vector2(w, xp_h))
	_fit_bar_text(_hp_text, _hp_bar, UiScale.fs(HP_FONT))
	_fit_bar_text(_mp_text, _mp_bar, UiScale.fs(MP_FONT))
	_fit_bar_text(_xp_text, _xp_bar, UiScale.fs(XP_FONT))
	_place_square(_lvl, Vector2(x, by + (bars_h - ld) * 0.5), ld, int(ld * 0.5))
	(_lvl.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	_fit_bar_text(_lvl_text, _lvl, UiScale.fs(UiScale.FONT_BODY))
	var nf := UiScale.fs(NAME_FONT)
	_font(_name_label, nf)
	_font(_gold_label, nf)
	var gi := float(nf) * 1.1
	_gold_label.size = Vector2(UiScale.px(70), name_h)
	_gold_label.position = Vector2(bx + w - _gold_label.size.x, top + (name_h - _line_h(_gold_label)) * 0.5)
	_gold_label.size.y = _line_h(_gold_label)
	_gold_icon.size = Vector2(gi, gi)
	_name_label.position = Vector2(bx + UiScale.px(2), top + (name_h - _line_h(_name_label)) * 0.5)
	_name_label.size = Vector2(w - UiScale.px(70) - gi - UiScale.px(6), _line_h(_name_label))
	_place_gold()

	# Питомец: кружок уровня, имя над полосками, полоски HP / MP с числами
	var pw := UiScale.px(PET_W)
	var pld := UiScale.px(PET_LVL_D)
	var pbx := pld + UiScale.px(4)
	var pname := UiScale.px(NAME_H)
	var php := UiScale.px(PET_HP_H)
	var pmp := UiScale.px(PET_MP_H)
	_pet_box.position = Vector2(x, by + bars_h + UiScale.px(8))
	_font(_pet_label, nf)
	_pet_label.position = Vector2(pbx + UiScale.px(2), (pname - _line_h(_pet_label)) * 0.5)
	_pet_label.size = Vector2(pw, _line_h(_pet_label))
	_size_bar(_pet_bar, Vector2(pbx, pname), Vector2(pw, php))
	_size_bar(_pet_mp_bar, Vector2(pbx, pname + php + gap), Vector2(pw, pmp))
	_fit_bar_text(_pet_hp_text, _pet_bar, UiScale.fs(PET_FONT))
	_fit_bar_text(_pet_mp_text, _pet_mp_bar, UiScale.fs(PET_MP_FONT))
	var pet_bars := php + gap + pmp
	_place_square(_pet_lvl, Vector2(0, pname + (pet_bars - pld) * 0.5), pld, int(pld * 0.5))
	(_pet_lvl.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	_fit_bar_text(_pet_lvl_text, _pet_lvl, UiScale.fs(UiScale.FONT_TINY))
	_pet_row_y = pname + pet_bars + UiScale.px(PET_BTN_TOP)
	_pet_btns.add_theme_constant_override("separation", int(UiScale.px(6)))
	for b in _pet_btns.get_children():
		_compact(b as Button)
	_pet_btns.reset_size()

	# Цель: «Ур. N Имя · редкость» над полоской, HP — в полоске
	var tw := UiScale.px(TARGET_W)
	var tf := UiScale.fs(TARGET_FONT)
	_font(_target_label, tf)
	_target_label.position = Vector2(-tw * 0.25, 0)
	_target_label.size = Vector2(tw * 1.5, _line_h(_target_label))
	var bar_y := _line_h(_target_label) + 1.0
	var bar_h := UiScale.px(TARGET_BAR_H)
	_size_bar(_target_bar, Vector2(0, bar_y), Vector2(tw, bar_h))
	_fit_bar_text(_target_hp_text, _target_bar, UiScale.fs(TARGET_HP_FONT))
	var bs := UiScale.px(18)
	_place_square(_tame_badge, Vector2(-bs - UiScale.px(6), bar_y + (bar_h - bs) * 0.5), bs, int(bs * 0.5))
	var ts := UiScale.px(10)
	_place_square(_tame_tier, Vector2(-bs - ts - UiScale.px(10), bar_y + (bar_h - ts) * 0.5), ts, 2)

	_font(_msg_label, UiScale.fs(MSG_FONT))
	var cw := UiScale.px(CAST_W)
	var cf := UiScale.fs(CAST_FONT)
	_font(_cast_label, cf)
	_cast_label.position = Vector2.ZERO
	_cast_label.size = Vector2(cw, float(cf) * 1.4)
	_size_bar(_cast_bar, Vector2(0, float(cf) * 1.4), Vector2(cw, UiScale.px(CAST_H)))
	_cast_box.size = Vector2(cw, float(cf) * 1.4 + UiScale.px(CAST_H))
	_font(_fx_tip, UiScale.fs(UiScale.FONT_SMALL))
	var fx := UiScale.px(FX_ICON)
	_fx_player.position = Vector2(bx + w + UiScale.px(8), by + (hp_h + gap + mp_h - fx) * 0.5)
	_fx_pet.position = Vector2(pbx + pw + UiScale.px(8), pname + (pet_bars - fx) * 0.5)
	_fx_pet.set_layout(fx, UiScale.px(FX_GAP), UiScale.px(FX_PET_W))

	_menu.add_theme_constant_override("separation", int(UiScale.px(MENU_GAP)))
	for b in _menu.get_children():
		_compact(b as Button)
	_menu.reset_size()


# ---------- Кнопки действий ----------

## Круглая кнопка. offset: центр, отсчитанный от правого нижнего угла экрана.
## hold = true: кнопку можно держать (is_held), иначе срабатывает action при касании.
## offset и radius — для «Среднего» размера интерфейса (умножаются на UiScale.k(); радиус не меньше BUTTON_MIN_R).
## Длинная подпись переносится по словам в ширину кружка (button_text — исходный текст).
func add_button(id: String, text: String, offset: Vector2, radius: float, color: Color, hold := false) -> void:
	var p := _circle(radius, color)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_buttons[id] = {"panel": p, "label": l, "offset": offset, "r": radius, "hold": hold, "touch": -1,
		"color": color, "blocked": false, "base_offset": offset, "base_r": radius, "text": text, "icon": null}
	_size_button(id)
	_layout()


## Круглая кнопка питомца (команды «Авто», «Атака», «Защита», «За мной»): в ряд под панелью питомца слева
## вверху, по порядку добавления; видна только вместе с панелью питомца (update_pet).
func add_pet_button(id: String, text: String, color: Color) -> void:
	add_button(id, text, Vector2.ZERO, PET_BTN_R, color)
	_buttons[id]["pet"] = _pet_ids.size()
	_pet_ids.append(id)
	set_button_visible(id, _pet_box.visible)
	_layout()


## id круглых кнопок питомца по порядку.
func pet_button_ids() -> Array[String]:
	var res: Array[String] = []
	res.append_array(_pet_ids)
	return res


## Радиус, центр и шрифт круглой кнопки по UiScale.
func _size_button(id: String) -> void:
	var b: Dictionary = _buttons[id]
	var r := maxf(BUTTON_MIN_R, UiScale.px(float(b["base_r"])))
	b["r"] = r
	b["offset"] = (b["base_offset"] as Vector2) * UiScale.k()
	var p: Panel = b["panel"]
	_resize_circle(p, r)
	var l: Label = b["label"]
	l.add_theme_font_size_override("font_size", int(clampf(r * 0.33, 11.0, 22.0)))
	l.add_theme_constant_override("outline_size", 4)
	_fit_button_text(id)
	var ic: IconView = b["icon"]
	if ic != null:
		var inset := (3.0 if r < 45.0 else 4.0) + 1.0
		ic.position = Vector2(inset, inset)
		ic.size = Vector2(r - inset, r - inset) * 2.0


## Подпись кнопки: перенос по словам в ширину кружка, по центру кружка.
func _fit_button_text(id: String) -> void:
	var b: Dictionary = _buttons[id]
	var r := float(b["r"])
	var l: Label = b["label"]
	l.text = _wrap_words(l, String(b["text"]), r * 2.0 * 0.86)
	var ms := l.get_combined_minimum_size()
	l.size = ms
	l.position = (Vector2(r, r) - ms / 2.0).round()


## Текст с переносами: слова по строкам не шире max_w (шрифт подписи l); переносы в тексте сохраняются.
static func _wrap_words(l: Label, text: String, max_w: float) -> String:
	var font := l.get_theme_font("font")
	var fsz := l.get_theme_font_size("font_size")
	if font == null:
		return text
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for w in String(para).split(" ", false):
			var word := String(w)
			var cand: String = word if line == "" else line + " " + word
			if line != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > max_w:
				out.append(line)
				line = word
			else:
				line = cand
		out.append(line)
	return "\n".join(out)


func set_button_visible(id: String, v: bool) -> void:
	if _buttons.has(id):
		_buttons[id]["panel"].visible = v


func set_button_text(id: String, text: String) -> void:
	if _buttons.has(id) and String(_buttons[id]["text"]) != text:
		_buttons[id]["text"] = text
		_fit_button_text(id)


## frac > 0: кнопка на перезарядке (затемнена; у значка — тёмный сектор доли frac, край идёт по часовой стрелке).
## Кнопка с неподходящим оружием (set_blocked) — темнее всегда.
func set_cooldown(id: String, frac: float) -> void:
	if _buttons.has(id):
		var ic: IconView = _buttons[id]["icon"]
		var a := 0.35 if frac > 0.0 else 1.0
		if ic != null:
			if frac > 0.0:
				ic.set_sector(1.0 - frac, 1.0)
			else:
				ic.set_sector(0.0, 0.0)
			a = 0.75 if frac > 0.0 else 1.0
		if bool(_buttons[id]["blocked"]):
			a = 0.28 if ic == null else 0.5
		_buttons[id]["panel"].modulate = Color(1, 1, 1, a)


## Значок на круглой кнопке вместо подписи (спецификация IconView; пустая — снова подпись).
## Подпись остаётся в button_text (для подсказок и тестов). Тот же значок — ничего не перестраивается.
func set_button_icon(id: String, spec: Dictionary) -> void:
	if not _buttons.has(id):
		return
	var b: Dictionary = _buttons[id]
	var ic: IconView = b["icon"]
	if spec.is_empty():
		if ic != null:
			ic.visible = false
		(b["label"] as Label).visible = true
		return
	if ic == null:
		ic = IconView.new()
		(b["panel"] as Panel).add_child(ic)
		b["icon"] = ic
		_size_button(id)
		ic.set_blocked(bool(b["blocked"]))
	ic.visible = true
	ic.set_spec(spec)
	(b["label"] as Label).visible = false


## Значок кнопки (null — у кнопки подпись).
func button_icon(id: String) -> IconView:
	if not _buttons.has(id):
		return null
	var ic: IconView = _buttons[id]["icon"]
	return ic if ic != null and ic.visible else null


## Число на значке кнопки (зелья в сумке); -1 — без числа.
func set_button_count(id: String, n: int) -> void:
	var ic := button_icon(id)
	if ic != null:
		ic.set_count(n)


## Кнопка недоступна (например, умение не подходит к оружию): затемнена, нажатие всё равно шлёт действие
## (модуль объясняет, почему нельзя).
func set_blocked(id: String, blocked: bool) -> void:
	if _buttons.has(id):
		_buttons[id]["blocked"] = blocked
		var ic: IconView = _buttons[id]["icon"]
		if ic != null:
			ic.set_blocked(blocked)


func is_blocked(id: String) -> bool:
	return _buttons.has(id) and bool(_buttons[id]["blocked"])


## Цвет заливки круглой кнопки (включённое переключаемое умение и т. п.); null-цвет не бывает — передайте исходный.
func set_button_color(id: String, c: Color) -> void:
	if not _buttons.has(id):
		return
	var p: Panel = _buttons[id]["panel"]
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = c
	# Значок почти закрывает заливку: включённое (цвет не исходный) — ещё и кольцо этого цвета
	var ic: IconView = _buttons[id]["icon"]
	if ic != null:
		var base: Color = _buttons[id]["color"]
		ic.set_ring(Color(c.r, c.g, c.b, 1.0) if c != base else Color(0, 0, 0, 0), UiScale.px(4))


## Исходный цвет кнопки (как при add_button).
func button_color(id: String) -> Color:
	if _buttons.has(id):
		return _buttons[id]["color"]
	return Color.WHITE


## Подпись кнопки как задана (без переносов, которые добавляет HUD).
func button_text(id: String) -> String:
	if _buttons.has(id):
		return String(_buttons[id]["text"])
	return ""


func is_button_visible(id: String) -> bool:
	return _buttons.has(id) and (_buttons[id]["panel"] as Panel).visible


func is_held(id: String) -> bool:
	if not _buttons.has(id):
		return false
	if _buttons[id]["touch"] != -1:
		return true
	for k in KEYS:
		if KEYS[k] == id and Input.is_key_pressed(k):
			return true
	return false


## Сдвиг пальца для вращения камеры с прошлого вызова (пиксели); обнуляется.
func take_camera_drag() -> Vector2:
	var d := _cam_drag
	_cam_drag = Vector2.ZERO
	return d


## Множитель дальности камеры с прошлого вызова (щипок, колесо мыши): < 1 — ближе; сбрасывается в 1.
func take_camera_zoom() -> float:
	var z := _cam_zoom
	_cam_zoom = 1.0
	return z


# ---------- Окна ----------

## Элемент поверх мира (трекер и т. п.): касание по нему не начинает джойстик и вращение камеры.
func add_blocker(c: Control) -> void:
	if not _blockers.has(c):
		_blockers.append(c)


## Точка p на видимом элементе-блокере.
func over_blocker(p: Vector2) -> bool:
	for c in _blockers:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


## Кнопки меню (Герой, Питомцы, …): id действия → кнопка.
func menu_buttons() -> Dictionary:
	var res := {}
	for c in _menu.get_children():
		var b := c as Button
		if b != null:
			res[String(b.get_meta("action", ""))] = b
	return res


## Прямоугольник меню на экране.
func menu_rect() -> Rect2:
	return Rect2(_menu.position, _menu.get_combined_minimum_size())


## Прямоугольник полоски HP цели (и подписи над ней) на экране.
func target_rect() -> Rect2:
	return Rect2(_target_box.position, Vector2(_target_bar.size.x, _target_bar.position.y + _target_bar.size.y))


## Прямоугольник панели игрока (полоски HP/MP/опыта и строка под ними) на экране.
func player_rect() -> Rect2:
	var r := Rect2(_hp_bar.position, _hp_bar.size)
	for c in [_mp_bar, _xp_bar, _lvl, _name_label, _gold_label, _gold_icon]:
		var ctl := c as Control
		var ms := ctl.get_combined_minimum_size()
		r = r.merge(Rect2(ctl.position, Vector2(maxf(ctl.size.x, ms.x), maxf(ctl.size.y, ms.y))))
	return r


## Прямоугольник открытого окна на экране (Rect2() — окна нет).
func window_rect() -> Rect2:
	if not is_window_open():
		return Rect2()
	return Rect2(_window.position, _window.size)


## Создаёт окно по центру экрана и возвращает контейнер для содержимого.
## sz — размер для «Среднего» размера интерфейса: окно = sz × UiScale.k(), но не больше экрана.
## Если содержимое шире или выше, окно растёт и всё равно держится по центру (_keep_window_on_screen).
## Пока окно открыто, джойстик и круглые кнопки не работают. Открыто только одно окно.
func create_window(title: String, sz: Vector2) -> VBoxContainer:
	close_window()
	Quality.set_menu_open(true)
	var panel := PanelContainer.new()
	panel.theme = Util.ui_theme()
	panel.set_meta("base_size", sz)
	var wsz := UiScale.window_size(sz, _view)
	panel.size = wsz
	panel.position = _centered(wsz)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TITLE))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	var close := UiIcons.icon_button("close", UiScale.TAB_H)
	close.name = "CloseButton"
	close.custom_minimum_size = UiScale.v2(54, UiScale.TAB_H)
	close.pressed.connect(close_window)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	scroll.add_child(body)
	add_child(panel)
	_window = panel
	_release_all()
	return body


## Окно по центру экрана: содержимое могло его расширить (минимальный размер больше заданного).
func _keep_window_on_screen() -> void:
	if not is_window_open():
		return
	var pos := _centered(_window.size)
	if _window.position != pos:
		_window.position = pos


## Левый верхний угол прямоугольника sz по центру экрана (не левее и не выше края).
func _centered(sz: Vector2) -> Vector2:
	return Vector2(maxf(0.0, roundf((_view.x - sz.x) / 2.0)), maxf(0.0, roundf((_view.y - sz.y) / 2.0)))


func close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null
	Quality.set_menu_open(false)


func is_window_open() -> bool:
	return _window != null and is_instance_valid(_window)


# ---------- Панели ----------

func update_player(p: Player) -> void:
	_fx_player.bind(p.effects)
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = p.hp
	_set_text(_hp_text, "%d/%d" % [p.hp, p.max_hp])
	_mp_bar.visible = p.max_mp > 0
	if _mp_bar.visible:
		_mp_bar.max_value = p.max_mp
		_mp_bar.value = p.mp
		_set_text(_mp_text, "%d/%d" % [p.mp, p.max_mp])
	var need := Game.xp_to_next(Game.level)
	_xp_bar.max_value = need
	_xp_bar.value = Game.xp
	_set_text(_xp_text, "%.1f%%" % (100.0 * float(Game.xp) / float(maxi(1, need))))
	_set_text(_lvl_text, str(Game.level))
	_set_text(_name_label, Game.char_name)
	if _set_text(_gold_label, str(Game.gold)):
		_place_gold()


## Текст подписи; true — изменился (иначе подпись не трогается: без лишней перекладки текста каждый кадр).
static func _set_text(l: Label, t: String) -> bool:
	if l.text == t:
		return false
	l.text = t
	return true


## Строка панели игрока для тестов и скриншотов: «ник · Ур. N · HP a/b · MP c/d · опыт e% · золото g».
func player_summary() -> String:
	var t := "%s · Ур. %s · HP %s" % [_name_label.text, _lvl_text.text, _hp_text.text]
	if _mp_bar.visible:
		t += " · MP " + _mp_text.text
	return t + " · опыт %s · золото %s" % [_xp_text.text, _gold_label.text]


## pet: узел питомца с полями pet_name, level, hp, max_hp и (необязательно) mp, max_mp, или null.
func update_pet(pet: Node) -> void:
	if pet == null or not is_instance_valid(pet):
		_pet_box.visible = false
		_fx_pet.bind(null)
		for id in _pet_ids:
			set_button_visible(id, false)
		return
	_pet_box.visible = true
	# Кнопки питомца: видны, текущий режим — с кольцом
	var mode: Variant = pet.get("mode")
	for id in _pet_ids:
		set_button_visible(id, true)
		var on := mode is String and id == "pet_" + String(mode)
		set_button_color(id, PET_MODE_ON if on else button_color(id))
	_fx_pet.bind(pet.get("effects") as StatusEffects)
	_set_text(_pet_label, String(pet.get("pet_name")))
	_set_text(_pet_lvl_text, str(pet.get("level")))
	var php := int(pet.get("hp"))
	var pmax := int(pet.get("max_hp"))
	_pet_bar.max_value = pmax
	_pet_bar.value = php
	_set_text(_pet_hp_text, "%d/%d" % [php, pmax])
	var mmp: Variant = pet.get("max_mp")
	_pet_mp_bar.visible = mmp is int and int(mmp) > 0
	if _pet_mp_bar.visible:
		_pet_mp_bar.max_value = int(mmp)
		_pet_mp_bar.value = int(pet.get("mp"))
		_set_text(_pet_mp_text, "%d/%d" % [int(pet.get("mp")), int(mmp)])


## Цель игрока: узел с полями mob_name, level, hp, max_hp, is_dead (или null).
func set_target(t: Node3D) -> void:
	_target = t
	_refresh_target()


## Полоса каста: skill_name — что кастуется ("" — скрыть), frac — доля пройденного (0..1), left — сколько
## осталось, с.
func update_cast(skill_name: String, frac: float, left: float) -> void:
	if skill_name == "":
		_cast_box.visible = false
		return
	_cast_box.visible = true
	_cast_bar.value = clampf(frac, 0.0, 1.0)
	var t := "%s  %.1f с" % [skill_name, maxf(0.0, left)]
	if t != _cast_label.text:
		_cast_label.text = t


## Видна ли полоса каста и где она (для тестов).
func is_cast_visible() -> bool:
	return _cast_box.visible


func cast_rect() -> Rect2:
	return Rect2(_cast_box.position, _cast_box.size)


## Сообщение внизу экрана на sec секунд.
func show_message(t: String, sec: float = 3.0) -> void:
	_msg_label.text = t
	_msg_time = sec


# ---------- Внутреннее ----------

func _circle(radius: float, fill: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = Color(1.0, 0.95, 0.82, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	_resize_circle(p, radius)
	add_child(p)
	return p


## Новый радиус кружка (центр сохраняется): размер, скругление, толщина рамки и тень.
func _resize_circle(p: Panel, radius: float) -> void:
	var c := p.position + p.size / 2.0
	p.size = Vector2(radius * 2.0, radius * 2.0)
	p.position = c - p.size / 2.0
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.set_corner_radius_all(int(radius))
		sb.set_border_width_all(3 if radius < 45.0 else 4)
		sb.shadow_size = 4 if radius < 45.0 else 6


## Маленький значок (кружок или квадратик со скруглением radius) на панели цели; размер — _place_square.
func _square(parent: Node, radius: int) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1.0, 0.95, 0.82, 0.9)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _place_square(p: Panel, pos: Vector2, sz: float, radius: int) -> void:
	p.position = pos
	p.size = Vector2(sz, sz)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.set_corner_radius_all(radius)


## Значок приручения цели: state — Taming.BADGE_* ("" — скрыть), tier — тир карты.
func _set_tame_badge(state: String, tier: String) -> void:
	if state == target_tame_state and tier == target_card_tier and _tame_badge.visible == (state != ""):
		return
	target_tame_state = state
	target_card_tier = tier
	_tame_badge.visible = state != ""
	_tame_tier.visible = state != "" and tier != ""
	if state == "":
		return
	var c := Color(0.62, 0.36, 0.95)
	if state == Taming.BADGE_READY:
		c = Color(0.3, 0.92, 0.42)
	elif state == Taming.BADGE_NEED_CARD:
		c = Color(0.74, 0.7, 0.5)
	(_tame_badge.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = c
	if tier != "":
		(_tame_tier.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = ItemData.card_tier_color(tier)


## Полоска (HP, MP, опыт); положение и размер — _size_bar.
func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.2, 0.6)
	bg.border_color = Color(1.0, 0.95, 0.82, 0.8)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _size_bar(b: ProgressBar, pos: Vector2, sz: Vector2) -> void:
	var r := int(sz.y / 2.0)
	var fill := b.get_theme_stylebox("fill") as StyleBoxFlat
	var bg := b.get_theme_stylebox("background") as StyleBoxFlat
	if fill != null:
		fill.set_corner_radius_all(r)
	if bg != null:
		bg.set_corner_radius_all(r)
		bg.set_border_width_all(1 if sz.y < 8.0 else 2)
	b.position = pos
	b.size = sz


## Подпись поверх мира с чёрной обводкой; размер шрифта — _font.
func _label(parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _font(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", clampi(roundi(float(font_size) * 0.28), 3, 6))


## Кнопка меню значком UiIcons icon_id (действие id): подсказка — название; долгое касание — подпись под значком.
func _menu_button(icon_id: String, id: String) -> Button:
	var b := UiIcons.icon_button(icon_id, MENU_ICON)
	b.name = "Menu_" + id
	b.theme = Util.ui_theme()
	b.set_meta("action", id)
	b.button_down.connect(func() -> void:
		_hold_btn = b
		_hold_t = 0.0
		_hold_shown = false)
	b.button_up.connect(func() -> void:
		if _hold_btn == b:
			_hold_btn = null)
	b.pressed.connect(func() -> void:
		# Отпустили после подписи (долгое касание) — без действия
		var was_long := _hold_shown
		_hold_shown = false
		if not was_long:
			action.emit(id))
	return b


## Кнопка меню и «Существо»: квадрат MENU_ICON, поле MENU_PAD вокруг значка (с масштабом UiScale).
func _compact(b: Button) -> void:
	if b == null:
		return
	var th := Util.ui_theme()
	for st in ["normal", "hover", "pressed", "disabled"]:
		var src := th.get_stylebox(st, "Button") as StyleBoxFlat
		if src == null:
			continue
		var sb := src.duplicate() as StyleBoxFlat
		sb.content_margin_left = UiScale.px(MENU_PAD)
		sb.content_margin_right = UiScale.px(MENU_PAD)
		sb.content_margin_top = UiScale.px(MENU_PAD)
		sb.content_margin_bottom = UiScale.px(MENU_PAD)
		sb.set_corner_radius_all(int(UiScale.px(8)))
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(UiScale.px(MENU_ICON), UiScale.px(MENU_ICON))
	b.reset_size()


## Подпись значка меню (долгое касание): под кнопкой, в пределах экрана.
func _show_menu_tip(b: Button) -> void:
	_fx_tip.text = b.tooltip_text
	_fx_tip.reset_size()
	var sz := _fx_tip.get_combined_minimum_size()
	var r := b.get_global_rect()
	_fx_tip.position = Vector2(clampf(r.get_center().x - sz.x * 0.5, 4.0, _view.x - sz.x - 4.0), r.end.y + UiScale.px(4))
	_fx_tip.visible = true
	_fx_tip_time = 1.8


## Подписи значков меню и «Существо» (id действия → подпись) — для тестов.
func menu_titles() -> Dictionary:
	var res := {}
	for b in menu_buttons().values():
		var btn := b as Button
		res[String(btn.get_meta("action", ""))] = btn.tooltip_text
	return res


## Джойстик из картинок UiIcons (joystick_base / joystick_knob), если они есть: картинка на весь кружок,
## заливка и рамка кружка прозрачные. Нет картинки — прежний кружок.
func _skin_joystick(p: Panel, icon_id: String) -> void:
	if not UiIcons.has_file(icon_id):
		return
	var tr := TextureRect.new()
	tr.name = "Skin"
	tr.texture = UiIcons.texture(icon_id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(tr)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0, 0, 0, 0)
		sb.shadow_color = Color(0, 0, 0, 0)


## Джойстик нарисован картинками (для тестов).
func joystick_skinned() -> bool:
	return _joy_base.get_node_or_null("Skin") != null


## Подпись внутри полоски (или кружка уровня): по центру, белая с обводкой; размер — _fit_bar_text.
func _bar_text(parent: Control) -> Label:
	var l := _label(parent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94))
	return l


## Шрифт подписи и её место — по центру полоски (подпись бывает чуть выше тонкой полоски — выступает поровну).
func _fit_bar_text(l: Label, bar: Control, font_size: int) -> void:
	_font(l, font_size)
	l.add_theme_constant_override("outline_size", clampi(roundi(float(font_size) * 0.3), 2, 5))
	var h := _line_h(l)
	l.size = Vector2(bar.size.x, h)
	l.position = Vector2(0.0, roundf((bar.size.y - l.size.y) * 0.5))


## Высота строки подписи (по шрифту; пустая подпись меряется по «0»).
func _line_h(l: Label) -> float:
	var t := l.text
	if t == "":
		l.text = "0"
	var h := l.get_combined_minimum_size().y
	l.text = t
	return h


## Кружок уровня: тёмная заливка, золотая рамка.
func _style_level(p: Panel) -> void:
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = LVL_BG
		sb.border_color = LVL_RIM


## Значок золота — вплотную слева от числа (число выровнено по правому краю полосок).
func _place_gold() -> void:
	var f := _gold_label.get_theme_font("font")
	var fsz := _gold_label.get_theme_font_size("font_size")
	var tw := f.get_string_size(_gold_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x if f != null else 0.0
	var gi := _gold_icon.size.x
	_gold_icon.position = Vector2(_gold_label.position.x + _gold_label.size.x - tw - gi - UiScale.px(3),
		_gold_label.position.y + (_gold_label.size.y - gi) * 0.5)


func _layout() -> void:
	_view = get_viewport().get_visible_rect().size
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var p: Panel = b["panel"]
		p.position = _view - b["offset"] - p.size / 2.0
	_place_pet_buttons()
	_cast_box.position = Vector2((_view.x - _cast_box.size.x) * 0.5, _view.y * CAST_Y - _cast_box.size.y * 0.5)
	_msg_label.position = Vector2(0, UiScale.px(MSG_Y))
	_msg_label.size = Vector2(_view.x, float(UiScale.fs(MSG_FONT)) * 1.5)
	var edge := UiScale.px(12)
	_menu.position = Vector2(_view.x - _menu.get_combined_minimum_size().x - edge, edge)
	_place_target()
	_keep_window_on_screen()
	if _joy_idx == -1:
		_reset_joy()


## Кнопки питомца: круглые в ряд под полосками питомца, правее — «Существо» (по центру ряда).
func _place_pet_buttons() -> void:
	var origin := _pet_box.position + Vector2(0, _pet_row_y)
	var x := 0.0
	var h := 0.0
	for id in _pet_ids:
		var b: Dictionary = _buttons[id]
		var r := float(b["r"])
		var p: Panel = b["panel"]
		p.position = origin + Vector2(x, 0)
		x += r * 2.0 + UiScale.px(PET_BTN_GAP)
		h = maxf(h, r * 2.0)
	_pet_btns.reset_size()
	var bh := _pet_btns.get_combined_minimum_size().y
	_pet_btns.position = Vector2(x + UiScale.px(PET_BTN_GAP), _pet_row_y + maxf(0.0, (h - bh) * 0.5))


## Панель цели: чуть левее центра, но не под кнопками меню справа вверху и не на панели игрока слева.
func _place_target() -> void:
	var tw := UiScale.px(TARGET_W)
	var tx := minf((_view.x - tw) / 2.0 - UiScale.px(50), _menu.position.x - tw - UiScale.px(20))
	var min_x := maxf(UiScale.px(TARGET_MIN_X), player_rect().end.x + UiScale.px(16))
	_target_box.position = Vector2(maxf(min_x, tx), UiScale.px(10))
	_place_fx()


## Ряды значков эффектов: у игрока — до панели цели; у цели — справа от полоски до меню,
## а если там меньше трёх значков — под полоской.
func _place_fx() -> void:
	var fx := UiScale.px(FX_ICON)
	var g := UiScale.px(FX_GAP)
	_fx_player.set_layout(fx, g, _target_box.position.x - _fx_player.position.x - UiScale.px(10))
	var tw := UiScale.px(TARGET_W)
	var right := _menu.position.x - (_target_box.position.x + tw + UiScale.px(8)) - UiScale.px(6)
	if right >= (fx + g) * 3.0:
		_fx_target.position = Vector2(tw + UiScale.px(8), _target_bar.position.y + (_target_bar.size.y - fx) * 0.5)
		_fx_target.set_layout(fx, g, right)
	else:
		_fx_target.position = Vector2(0, _target_bar.position.y + _target_bar.size.y + UiScale.px(4))
		_fx_target.set_layout(fx, g, tw)


func _reset_joy() -> void:
	_joy_idx = -1
	_joy_center = Vector2(UiScale.px(JOY_HOME.x), _view.y - UiScale.px(JOY_HOME.y))
	_joy_base.position = _joy_center - _joy_base.size / 2.0
	_joy_knob.position = _joy_center - _joy_knob.size / 2.0
	move_vec = Vector2.ZERO


func _release_all() -> void:
	_reset_joy()
	_cam_touches.clear()
	for id in _buttons:
		_buttons[id]["touch"] = -1


func _button_at(p: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var panel: Panel = b["panel"]
		if not panel.visible:
			continue
		var c := panel.position + panel.size / 2.0
		if p.distance_to(c) <= float(b["r"]) * TOUCH_K:
			return id
	return ""


func _input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo and KEYS.has(ke.keycode):
		var kid: String = KEYS[ke.keycode]
		if kid != "attack":
			action.emit(kid)
		return

	if is_window_open():
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom /= 0.9

	var te := event as InputEventScreenTouch
	if te != null:
		if te.pressed:
			var p := te.position
			if _show_fx_tip(p):
				return
			var id := _button_at(p)
			if id == "" and over_blocker(p):
				return
			if id != "":
				if _buttons[id]["hold"]:
					_buttons[id]["touch"] = te.index
				action.emit(id)
			elif _joy_idx == -1 and p.x < _view.x * 0.5 and p.y > UiScale.px(JOY_TOP):
				_joy_idx = te.index
				_joy_center = p
				_joy_base.position = p - _joy_base.size / 2.0
				_joy_knob.position = p - _joy_knob.size / 2.0
			elif p.y > UiScale.px(CAM_TOP) and _cam_touches.size() < 2 and (p.x >= _view.x * 0.5 or _cam_touches.size() == 1):
				# Второй палец (для щипка) может быть и в левой половине
				_cam_touches[te.index] = p
		else:
			if te.index == _joy_idx:
				_reset_joy()
			_cam_touches.erase(te.index)
			for id in _buttons:
				if _buttons[id]["touch"] == te.index:
					_buttons[id]["touch"] = -1
		return

	var de := event as InputEventScreenDrag
	if de != null and _cam_touches.has(de.index):
		var prev: Vector2 = _cam_touches[de.index]
		if _cam_touches.size() == 1:
			_cam_drag += de.position - prev
		else:
			var other := prev
			for k in _cam_touches:
				if k != de.index:
					other = _cam_touches[k]
			var before := other.distance_to(prev)
			var after := other.distance_to(de.position)
			if before > 10.0 and after > 10.0:
				_cam_zoom *= before / after
		_cam_touches[de.index] = de.position
		return
	if de != null and de.index == _joy_idx:
		var d := de.position - _joy_center
		var dist := minf(d.length(), _joy_r)
		var dir := Vector2.ZERO
		if d.length() > 0.001:
			dir = d.normalized()
		move_vec = dir * (dist / _joy_r)
		_joy_knob.position = _joy_center + dir * dist - _joy_knob.size / 2.0


func _process(delta: float) -> void:
	if _joy_idx == -1:
		var v := Vector2.ZERO
		if not is_window_open():
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				v.y -= 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				v.y += 1.0
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				v.x -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				v.x += 1.0
		move_vec = v.normalized()

	_refresh_target()
	_keep_window_on_screen()
	if _hold_btn != null:
		if not is_instance_valid(_hold_btn) or not _hold_btn.is_visible_in_tree():
			_hold_btn = null
		else:
			_hold_t += delta
			if _hold_t >= HOLD_TIP and not _hold_shown:
				_hold_shown = true
				_show_menu_tip(_hold_btn)
	_fx_player.refresh()
	_fx_pet.refresh()
	_fx_target.refresh()
	if _fx_tip_time > 0.0:
		_fx_tip_time -= delta
		_fx_tip.visible = _fx_tip_time > 0.0

	if _msg_time > 0.0:
		_msg_time -= delta
	_msg_label.modulate.a = clampf(_msg_time, 0.0, 1.0)


func _refresh_target() -> void:
	if _target == null or not is_instance_valid(_target) or _target.get("is_dead") == true:
		_target = null
		_target_box.visible = false
		_set_tame_badge("", "")
		_fx_target.bind(null)
		return
	_target_box.visible = true
	_fx_target.bind(_target.get("effects") as StatusEffects)
	var tid = _target.get("type_id")
	if tid is String:
		var sp := String(tid)
		var st := Taming.badge_state(sp)
		_set_tame_badge(st, MobData.card_tier(sp) if st != Taming.BADGE_NO else "")
	else:
		_set_tame_badge("", "")
	var rarity: Variant = _target.get("rarity")
	var head := "Ур. %d %s" % [int(_target.get("level")), String(_target.get("mob_name"))]
	if _target.get("is_boss") == true:
		head += " · Босс"
	elif rarity is String:
		head += " · " + MobData.rarity_label(String(rarity))
	_set_text(_target_label, head)
	var thp := int(_target.get("hp"))
	var tmax := int(_target.get("max_hp"))
	_target_bar.max_value = tmax
	_target_bar.value = thp
	_set_text(_target_hp_text, "%d/%d" % [maxi(0, thp), tmax])


## Касание по значку эффекта: подпись рядом (название, источник, сколько осталось). true — касание по значку.
func _show_fx_tip(p: Vector2) -> bool:
	for row in [_fx_player, _fx_pet, _fx_target]:
		var e: Dictionary = (row as StatusRow).entry_at(p)
		if e.is_empty():
			continue
		_fx_tip.text = StatusEffects.describe(e)
		_fx_tip.reset_size()
		var sz := _fx_tip.get_combined_minimum_size()
		_fx_tip.position = Vector2(clampf(p.x - sz.x * 0.5, 4.0, _view.x - sz.x - 4.0), p.y + UiScale.px(FX_ICON) * 0.7)
		_fx_tip.visible = true
		_fx_tip_time = 2.5
		return true
	return false


## Ряд значков эффектов: "player", "pet" или "target" (для тестов и скриншотов).
func status_row(which: String) -> StatusRow:
	match which:
		"pet":
			return _fx_pet
		"target":
			return _fx_target
	return _fx_player
