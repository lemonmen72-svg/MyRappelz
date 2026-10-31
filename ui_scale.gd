class_name UiScale
extends RefCounted
## Масштаб интерфейса — единая точка настройки размеров: шрифты, высота кнопок, отступы, скругления, окна,
## круглые кнопки HUD, всплывающие числа и надписи над головами в мире.
## Все размеры ниже даны для «Среднего» (по умолчанию) при высоте экрана 720 (см. Quality.apply_resolution);
## «Мелкий» и «Крупный» умножают их на FACTORS. Выбор хранится в user://settings.cfg (секция [ui], ключ scale),
## читается при первом запросе. Тема Util.ui_theme() и HUD обновляются сразу (SettingsMenu), окна — при открытии.
## Пользоваться: UiScale.fs(UiScale.FONT_TEXT) — размер шрифта, UiScale.px(44) — пиксели, UiScale.v2(x, y).

const SMALL := 0
const MEDIUM := 1
const LARGE := 2
const PATH := "user://settings.cfg"
const NAMES := ["Мелкий", "Средний", "Крупный"]
## «Крупный» не больше ~1.15: окна (база до 1090×600) должны помещаться в 1280×720.
const FACTORS := [0.87, 1.0, 1.15]

## Шрифты, px («Средний»). Было до уменьшения: тема 24, заголовки окон 30, текст 18–23.
## Шрифт темы по умолчанию (кнопки, обычные подписи).
const FONT := 17
## Заголовок окна.
const FONT_TITLE := 22
## Крупное имя (герой, существо) и название в карточке.
const FONT_NAME := 20
## Заголовки разделов («Характеристики», «Цели», «Товары»…).
const FONT_HEAD := 17
## Основной текст окон (характеристики, реплики, цели).
const FONT_TEXT := 15
## Текст карточек и пояснения.
const FONT_BODY := 14
## Мелкие пояснения, подписи ячеек.
const FONT_SMALL := 13
## Самое мелкое: уровень на значке умения, число в ячейке.
const FONT_TINY := 12

## Кнопки и отступы, px («Средний»).
## Высота обычной кнопки в окне (было 52–64).
const BUTTON_H := 44
## Высота кнопки вкладки.
const TAB_H := 40
## Поля внутри окна и карточек.
const PAD := 12
## Поля внутри кнопки: по бокам и сверху/снизу.
const BTN_PAD_X := 12
const BTN_PAD_Y := 6
## Промежуток между элементами.
const GAP := 8
## Скругление окон и кнопок.
const RADIUS := 12
const BTN_RADIUS := 10
## Наименьший отступ окна от края экрана.
const SCREEN_MARGIN := 10

## Надписи в мире (Label3D): множитель к прежнему размеру («Средний»; было 1.0).
const WORLD := 0.66

static var _level := -1


## Текущий размер (SMALL, MEDIUM, LARGE).
static func level() -> int:
	if _level < 0:
		_level = MEDIUM
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_level = clampi(int(cf.get_value("ui", "scale", MEDIUM)), SMALL, LARGE)
	return _level


## Выбрать размер; save — записать в user://settings.cfg (другие секции файла сохраняются).
## Тему Util.ui_theme() обновляет сразу.
static func set_level(l: int, save: bool = true) -> void:
	_level = clampi(l, SMALL, LARGE)
	if save:
		var cf := ConfigFile.new()
		cf.load(PATH)  # нет файла — начнём с пустого
		cf.set_value("ui", "scale", _level)
		var err := cf.save(PATH)
		if err != OK:
			push_warning("Не удалось сохранить размер интерфейса: %d" % err)
	Util.refresh_theme()


## Перечитать выбор из файла при следующем запросе.
static func reload() -> void:
	_level = -1


static func level_name(l: int = -1) -> String:
	return String(NAMES[clampi(level() if l < 0 else l, SMALL, LARGE)])


## Множитель текущего размера (1.0 — «Средний»).
static func k() -> float:
	return float(FACTORS[level()])


## Размер шрифта: базовый («Средний») × множитель.
static func fs(base: float) -> int:
	return maxi(9, roundi(base * k()))


## Пиксели: базовые × множитель.
static func px(base: float) -> float:
	return roundf(base * k())


static func v2(x: float, y: float) -> Vector2:
	return Vector2(px(x), px(y))


## Высота обычной кнопки в окне.
static func button_h() -> float:
	return px(BUTTON_H)


## Размер окна: базовый × множитель, но не больше экрана view за вычетом полей.
static func window_size(base: Vector2, view: Vector2 = Vector2(1280, 720)) -> Vector2:
	var m := px(SCREEN_MARGIN) * 2.0
	return Vector2(minf(base.x * k(), view.x - m), minf(base.y * k(), view.y - m)).round()


## Размер пикселя надписи в мире (Label3D.pixel_size): прежний × WORLD × множитель.
static func world_px(old_pixel_size: float) -> float:
	return old_pixel_size * WORLD * k()
