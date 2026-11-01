class_name Quality
extends RefCounted
## Настройки графики (вкладка «Графика» окна настроек, SettingsMenu): общий пресет «Низкое» / «Среднее»
## (по умолчанию) / «Высокое» / «Максимальное» и отдельные настройки, как в мобильных RPG. Изменили хоть одну
## настройку вручную, и она не совпадает с пресетом — пресет «Свои» (CUSTOM).
## Хранится в user://settings.cfg, секция [graphics]: quality — пресет (0–3, 4 — «Свои»), по ключу на каждую
## настройку (OPTIONS) и fps. Старый файл (только quality 0–2) читается: настройки — по пресету.
## Геттеры статические: Quality.level(), Quality.option("shadows"), Quality.grass_density(), Quality.shadows()...
## Применение без перезапуска: Quality.apply(get_tree()) — разрешение 3D и MSAA окна, солнце и тени, постобработка
## и FXAA (PostFx), дальность растительности и мелочей построек, контуры (и у уже созданных моделей),
## текстуры, тени на моделях персонажей. Густота травы и цветов — при следующем построении мира.
##
## Тени (главное, см. CLAUDE.md «Графика»): карта теней с мягким фильтром PCF (5 или 13 выборок, у GL Compatibility
## по умолчанию на телефоне — жёсткая, одна выборка), каскады PSSM — первый вплотную к герою (камера в 12 м);
## в toon/prop-шейдерах тень мягко входит в cel-полосу; модели персонажей и зверей не затеняют сами себя
## (model_shadows = 0: только cel-свет, тень на землю они бросают).
## Сглаживание: MSAA 2×/4× 3D-кадра (в Compatibility 4.3 есть) или FXAA своим проходом в postfx.gdshader.
##
## Бережение телефона (жалоба Максима «выкрутил всё на максимум — телефон раскалился»):
## - у пресета свой предел кадров (PRESET_FPS: 30 / 60 / 45 / 45 — выбор пресета ставит его, кнопки кадров/с
##   меняют его отдельно и в пресет не входят); «Высокое» и «Максимальное» — 900p, а не родное разрешение (на
##   экране 2400×1080 родное — в 2.8 раза больше пикселей, чем 720p), тени 2 каскада в атласе 2048 (было 4 каскада
##   в 4096 — каждый отбрасывающий тень объект рисовался до 4 раз, атлас — 64 МБ записи за кадр);
## - порог LOD мешей (Viewport.mesh_lod_threshold, VIEW_LEVELS "lod"): модели героев, жителей и зверей импортируются
##   с LOD (meshes/generate_lods), выбор LOD работает и в GL Compatibility, и для мешей со скелетом;
## - контур моделей и растительности — только вблизи (outline_far, veg_outline_far; ModelLod, IslandVegetation);
## - открыто окно или экран до мира — не больше MENU_FPS кадров/с, игра свёрнута или без фокуса — BACKGROUND_FPS;
## - авто-снижение (ThermalGuard, настройка «Беречь телефон от перегрева», guard): телефон нагрелся (статус
##   температуры Android из плагина) или кадры стабильно не успевают — шаги THROTTLE_STEPS: потолки настроек
##   поверх выбранных (кадры/с → разрешение 3D → тени → сглаживание и постобработка → всё ниже). Настройки
##   игрока не меняются: option() — выбранное, геттеры (shadows(), msaa()…) — с потолком throttle_level().
##
## Рендерер (RendererGuard; на Android с нормальным Vulkan — Mobile, иначе и в CI — Compatibility): настройки те же,
## различия — ветками по mobile_renderer():
## - разрешение 3D ниже экрана (720p, 900p) — FSR 1.0 вместо билинейного растяжения (в Compatibility 4.3 его нет);
##   540p (слабый телефон, шаг 5 авто-снижения) — билинейно, дешевле всего;
## - FXAA — встроенный (Viewport.screen_space_aa, в проходе тонмаппинга Mobile, почти бесплатно), свой проход PostFx
##   — только в Compatibility (postfx_fxaa());
## - фильтр теней — по числу выборок RD (SHADOW_LEVELS "filter_mobile": SOFT_LOW 4 / SOFT_MEDIUM 8 выборок вместо
##   PCF 5 / 13 Compatibility);
## - цветокоррекция и свечение — тот же PostFx в обоих рендерерах (одна картинка; проверена снимками CI).
## Атлас и фильтр теней передаются RenderingServer только при изменении (в Mobile смена фильтра пересобирает
## специализации шейдеров).

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3
## Настройки изменены вручную и не совпадают ни с одним пресетом.
const CUSTOM := 4
const PATH := "user://settings.cfg"
const SECTION := "graphics"
const NAMES := ["Низкое", "Среднее", "Высокое", "Максимальное", "Свои"]
const DESCRIPTIONS := [
	"Без теней, рисованных текстур и постобработки, трава редкая и только рядом, без контуров. Для слабых телефонов.",
	"Мягкие тени рядом с героем, сглаживание MSAA 2×, рисованные текстуры, трава средней густоты, 60 кадров/с. "
		+ "Рекомендуется.",
	"Чёткая картинка (900p), тени дальше и мягче, свечение светлых мест, густая трава вдаль. 45 кадров/с.",
	"Для мощных телефонов: тени дальше всех и от кустов и камней, MSAA 4×, дальше всего видно. 45 кадров/с, "
		+ "900p (родное разрешение — вручную, телефон греется сильнее).",
	"Настройки изменены вручную.",
]

## Порядок настроек во вкладке «Графика».
const OPTIONS := ["render", "shadows", "aa", "view", "grass", "textures", "outlines", "postfx", "effects", "model_shadows"]
const TITLES := {
	"render": "Разрешение 3D", "shadows": "Тени", "aa": "Сглаживание", "view": "Дальность прорисовки",
	"grass": "Густота травы", "textures": "Детализация текстур", "outlines": "Контуры", "postfx": "Постобработка",
	"effects": "Качество эффектов", "model_shadows": "Тени на персонажах",
}
## Подписи вариантов (номер варианта — значение настройки).
const LABELS := {
	"render": ["540p", "720p", "900p", "Родное"],
	"shadows": ["Выкл", "Низкие", "Средние", "Высокие"],
	"aa": ["Выкл", "FXAA", "MSAA 2×", "MSAA 4×"],
	"view": ["Близко", "Средне", "Далеко", "Макс."],
	"grass": ["Редкая", "Средняя", "Густая"],
	"textures": ["Низкая", "Средняя", "Высокая"],
	"outlines": ["Выкл", "Вкл"],
	"postfx": ["Выкл", "Цвет", "Свечение"],
	"effects": ["Низкое", "Среднее", "Высокое"],
	"model_shadows": ["Выкл", "Вкл"],
}
## Подсказки под настройками.
const HINTS := {
	"render": "Высота кадра 3D-мира (интерфейс всегда чёткий). Меньше — быстрее, но мягче картинка. «Родное» на "
		+ "большом экране телефона — самое тяжёлое, телефон греется.",
	"shadows": "Выше — тени дальше, чётче и с мягким краем, но тяжелее для телефона.",
	"aa": "Убирает «лесенку» на краях моделей и контурах. MSAA — чище, FXAA — дешевле.",
	"view": "Как далеко видны трава, кусты, камни, деревья и мелочи у построек.",
	"grass": "Меняется при следующем запуске игры.",
	"textures": "Рисованные текстуры земли и построек; «Высокая» — без заметного повтора.",
	"outlines": "Тёмная обводка персонажей, зверей, построек и растительности (аниме-стиль).",
	"postfx": "«Цвет» — цветокоррекция и виньетка, «Свечение» — ещё мягкое сияние светлых мест.",
	"effects": "Сколько частиц у умений, ударов и искр.",
	"model_shadows": "Тени от карты теней на самих моделях. Выкл — чистый cel-свет (рекомендуется).",
}
## Значения настроек по пресетам (LOW, MEDIUM, HIGH, ULTRA). «Высокое» и «Максимальное» — 900p (было родное:
## на телефоне 2400×1080 — 2.6 млн пикселей против 1.8 млн, с MSAA 4× и свечением — главный нагрев видеочипа).
const PRESETS := [
	{"render": 1, "shadows": 0, "aa": 0, "view": 0, "grass": 0, "textures": 0, "outlines": 0, "postfx": 0,
		"effects": 0, "model_shadows": 0},
	{"render": 1, "shadows": 1, "aa": 2, "view": 1, "grass": 1, "textures": 1, "outlines": 1, "postfx": 0,
		"effects": 1, "model_shadows": 0},
	{"render": 2, "shadows": 2, "aa": 2, "view": 2, "grass": 2, "textures": 2, "outlines": 1, "postfx": 2,
		"effects": 2, "model_shadows": 0},
	{"render": 2, "shadows": 3, "aa": 3, "view": 3, "grass": 2, "textures": 2, "outlines": 1, "postfx": 2,
		"effects": 2, "model_shadows": 0},
]
## Предел кадров пресета (выбор пресета ставит его; кнопки «Кадров в секунду» — отдельно, в пресет не входят).
## «Высокое» и «Максимальное» — 45: кадр тяжелее, а 60 кадров/с при нём — главный путь к нагреву.
const PRESET_FPS := [30, 60, 45, 45]

## Разрешение 3D: высота кадра мира, px (0 — родное разрешение экрана).
const RENDER_HEIGHTS := [540, 720, 900, 0]
## Тени по уровню (0 — выключены): размер карты теней (атлас солнца), режим каскадов, дальность, м,
## доли дальности границ каскадов, фильтр (RenderingServer.SHADOW_QUALITY_*: в Compatibility SOFT_LOW/MEDIUM —
## PCF 5 выборок, SOFT_HIGH — 13), смешивание каскадов, тени от кустов и камней.
## Было (замер CI до оптимизации): «Средние» — атлас 4096, 50 м, тени кустов; «Высокие» — 4096, 4 каскада, 80 м
## (первый каскад 0–5.6 м — между камерой и героем, почти пустой; каждый объект с тенью — до 4 проходов).
## Стало: везде 2 каскада в атласе 2048 (первый каскад 13–15 м — герой и всё вокруг него в нём; 1.3–1.5 см на
## тексель при фильтре PCF — разницы с 4096 не видно), «Средние» 45 м без теней кустов, «Высокие» 60 м.
## "filter_mobile" — фильтр в Mobile (RendererSceneRenderRD 4.3: SOFT_LOW — 4 выборки, SOFT_MEDIUM — 8, SOFT_HIGH —
## 16 и шире ядро; 13 выборок PCF Compatibility ≈ SOFT_MEDIUM, 16 — лишний нагрев).
const SHADOW_LEVELS := [
	{},
	{"atlas": 2048, "splits": 2, "distance": 32.0, "split": [0.42, 0.7, 0.9], "filter": 2, "filter_mobile": 2,
		"blend": false, "small": false},
	{"atlas": 2048, "splits": 2, "distance": 45.0, "split": [0.33, 0.6, 0.85], "filter": 4, "filter_mobile": 3,
		"blend": true, "small": false},
	{"atlas": 2048, "splits": 2, "distance": 60.0, "split": [0.25, 0.6, 0.85], "filter": 4, "filter_mobile": 3,
		"blend": true, "small": true},
]
## Сдвиг тени (против «ряби» — самозатенения карты теней на гранях): по глубине и вдоль нормали.
## У Godot по умолчанию 0.1 / 1.0; у построек cull_disabled (двусторонние грани) рябь сильнее — нормаль больше.
const SHADOW_BIAS := 0.08
const SHADOW_NORMAL_BIAS := 1.5
## Дальность прорисовки по уровню, м: трава, кусты/камни/кристаллы, деревья, мелочи у построек (ящики,
## бочки, огни), декор полей (колосья); "lod" — порог LOD мешей, пикселей (Viewport.mesh_lod_threshold: больше —
## раньше упрощаются модели героев, жителей, зверей); "outline" — контур моделей персонажей и зверей до стольких м
## (ModelLod), "veg_outline" — контур участков деревьев, кустов и камней до стольких м (IslandVegetation).
## Было: «Далеко» 58 / 95 / 175 / 110 / 120, «Макс.» 72 / 120 / 220 / 140 / 150 (деревья до 248 м, контуры везде).
const VIEW_LEVELS := [
	{"grass": 24.0, "detail": 45.0, "trees": 90.0, "props": 70.0, "decor": 80.0, "lod": 3.0, "outline": 25.0,
		"veg_outline": 40.0},
	{"grass": 38.0, "detail": 65.0, "trees": 125.0, "props": 90.0, "decor": 100.0, "lod": 1.5, "outline": 30.0,
		"veg_outline": 45.0},
	{"grass": 50.0, "detail": 85.0, "trees": 150.0, "props": 100.0, "decor": 110.0, "lod": 1.25, "outline": 40.0,
		"veg_outline": 55.0},
	{"grass": 60.0, "detail": 100.0, "trees": 180.0, "props": 120.0, "decor": 130.0, "lod": 1.0, "outline": 50.0,
		"veg_outline": 65.0},
]
## Густота травы по уровню: доля полной густоты, травинок в пучке, доля цветов.
const GRASS_LEVELS := [
	{"density": 0.35, "blades": 4, "flowers": 0.45},
	{"density": 0.65, "blades": 5, "flowers": 0.75},
	{"density": 1.0, "blades": 6, "flowers": 1.0},
]
## Доля частиц эффектов по уровню.
const EFFECTS_SCALE := [0.5, 0.75, 1.0]
## Резкость FSR 1.0 (Viewport.fsr_sharpness: 0 — резче всего, 2 — мягко); у Godot по умолчанию 0.2.
const FSR_SHARPNESS := 0.3
## FSR — только если 3D-кадр заметно меньше экрана (при масштабе ~1 растягивать нечего).
const FSR_MAX_SCALE := 0.99

## Ограничение частоты кадров. Без него экраны 90–120 Гц рисуют в 1.5–2 раза больше кадров,
## чем нужно, и телефон греется. 30 — меньше всего греется и дольше держит батарея.
const FPS_OPTIONS := [30, 45, 60]
## Предел кадров «Среднего» (по умолчанию) и для неверного значения.
const DEFAULT_FPS := 60
## Предел кадров при открытом окне и на экранах до мира (вход, выбор и создание персонажа, загрузка ресурсов).
const MENU_FPS := 30
## Игра без фокуса (шторка уведомлений, другое окно поверх) или свёрнута.
const BACKGROUND_FPS := 10

## Авто-снижение графики (ThermalGuard): шаг N — потолки настроек (берётся меньшее из выбранного и потолка) и
## кадров/с. Порядок по стоимости для глаза: кадры/с → разрешение 3D → тени → сглаживание и постобработка → всё.
const THROTTLE_STEPS := [
	{},
	{"fps": 30},
	{"fps": 30, "render": 1},
	{"fps": 30, "render": 1, "shadows": 1},
	{"fps": 30, "render": 1, "shadows": 1, "aa": 2, "postfx": 0},
	{"fps": 30, "render": 0, "shadows": 0, "aa": 0, "postfx": 0, "view": 1, "effects": 1, "outlines": 0},
]

static var _level := -1
static var _opts: Dictionary = {}
static var _fps := -1
static var _menu_open := false
## Экран до мира (вход, выбор, создание персонажа, загрузка ресурсов) — как открытое окно.
static var _screen_idle := false
## Игра без фокуса или свёрнута (ThermalGuard по уведомлениям приложения).
static var _background := false
## Шаг авто-снижения (0 — нет, THROTTLE_STEPS) и включено ли оно (настройка guard, по умолчанию да; −1 — не прочитано).
static var _throttle := 0
static var _guard := -1
static var _resize_hooked := false
## Тесты: 1 — считать рендерер Mobile, 0 — Compatibility, −1 — как есть (RendererGuard.is_vulkan()).
static var renderer_override := -1
## Последние атлас и фильтр теней, переданные RenderingServer (−1 — ещё не передавали).
static var _last_atlas := -1
static var _last_filter := -1
## Материалы моделей (персонажи, звери, питомцы): тени на модели по model_shadows — WeakRef.
static var _model_mats: Array[WeakRef] = []
## Материалы с контуром (next_pass по outlines; контур — meta "outline") — WeakRef.
static var _outline_mats: Array[WeakRef] = []


# ---------- Пресет и настройки ----------

static func _ensure() -> void:
	if _level >= 0:
		return
	_level = MEDIUM
	var cf := ConfigFile.new()
	var loaded := cf.load(PATH) == OK
	if loaded:
		_level = clampi(int(cf.get_value(SECTION, "quality", MEDIUM)), LOW, CUSTOM)
	var base: Dictionary = PRESETS[mini(_level, ULTRA) if _level != CUSTOM else MEDIUM]
	_opts = {}
	for k in OPTIONS:
		var key := String(k)
		var v := int(base[key])
		if loaded and cf.has_section_key(SECTION, key):
			v = int(cf.get_value(SECTION, key, v))
		_opts[key] = clampi(v, 0, option_count(key) - 1)
	_level = _match_preset()


## Пресет, с которым совпадают все настройки, иначе CUSTOM.
static func _match_preset() -> int:
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var same := true
		for k in OPTIONS:
			if int(p[k]) != int(_opts.get(k, -1)):
				same = false
				break
		if same:
			return i
	return CUSTOM


## Текущий пресет (LOW, MEDIUM, HIGH, ULTRA) или CUSTOM.
static func level() -> int:
	_ensure()
	return _level


## Выбирает пресет (все настройки — по нему); save — записать в user://settings.cfg (другие секции сохраняются).
## CUSTOM ничего не меняет.
static func set_level(l: int, save: bool = true) -> void:
	_ensure()
	if l < LOW or l > ULTRA:
		return
	var p: Dictionary = PRESETS[l]
	for k in OPTIONS:
		_opts[k] = int(p[k])
	_level = l
	# Предел кадров пресета (дальше игрок может выбрать свой)
	_fps = int(PRESET_FPS[l])
	if save:
		_save_all()


## Значение настройки (номер варианта, см. LABELS) — выбранное игроком (без авто-снижения).
static func option(key: String) -> int:
	_ensure()
	return int(_opts.get(key, 0))


## Действующее значение настройки: выбранное, но не выше потолка шага авто-снижения (THROTTLE_STEPS).
static func effective(key: String) -> int:
	var v := option(key)
	var caps: Dictionary = THROTTLE_STEPS[clampi(_throttle, 0, THROTTLE_STEPS.size() - 1)]
	if caps.has(key):
		v = mini(v, int(caps[key]))
	return v


## Сколько вариантов у настройки.
static func option_count(key: String) -> int:
	var labels: Array = LABELS.get(key, [])
	return labels.size()


## Меняет одну настройку; пресет — тот, с которым совпадают все настройки, иначе «Свои».
static func set_option(key: String, value: int, save: bool = true) -> void:
	_ensure()
	if not LABELS.has(key):
		return
	_opts[key] = clampi(value, 0, option_count(key) - 1)
	_level = _match_preset()
	if save:
		_save_all()


static func option_title(key: String) -> String:
	return String(TITLES.get(key, key))


static func option_label(key: String, v: int = -1) -> String:
	var labels: Array = LABELS.get(key, [])
	if labels.is_empty():
		return ""
	return String(labels[clampi(option(key) if v < 0 else v, 0, labels.size() - 1)])


static func option_hint(key: String) -> String:
	return String(HINTS.get(key, ""))


## Предел кадров пресета l (−1 — текущего; «Свои» — «Среднего»).
static func preset_fps(l: int = -1) -> int:
	var lv := level() if l < 0 else l
	if lv < LOW or lv > ULTRA:
		return DEFAULT_FPS
	return int(PRESET_FPS[lv])


## Предел кадров в секунду (одно из FPS_OPTIONS): записанный в файле, иначе — пресета (preset_fps). Выбор
## пресета ставит его предел; кнопки кадров/с меняют только его.
static func fps_limit() -> int:
	if _fps < 0:
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_fps = int(cf.get_value(SECTION, "fps", -1))
		if not FPS_OPTIONS.has(_fps):
			_fps = preset_fps()
	return _fps


static func set_fps_limit(v: int, save: bool = true) -> void:
	_fps = v if FPS_OPTIONS.has(v) else preset_fps()
	if save:
		_save({"fps": _fps})
	apply_fps()


## Действующий предел кадров: игра без фокуса — BACKGROUND_FPS; иначе fps_limit(), не выше потолка шага
## авто-снижения, а при открытом окне и на экране до мира — не выше MENU_FPS.
static func current_fps_cap() -> int:
	if _background:
		return BACKGROUND_FPS
	var f := fps_limit()
	var caps: Dictionary = THROTTLE_STEPS[clampi(_throttle, 0, THROTTLE_STEPS.size() - 1)]
	if caps.has("fps"):
		f = mini(f, int(caps["fps"]))
	if _menu_open or _screen_idle:
		f = mini(f, MENU_FPS)
	return f


## Включить предел кадров (в headless-тестах не ограничиваем — они идут быстрее реального времени).
static func apply_fps() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = current_fps_cap()


## Открыто окно (герой, питомцы, сумка, настройки): мир под окном рисуется не чаще MENU_FPS кадров
## в секунду — меньше нагрев, на вид разницы нет.
static func set_menu_open(on: bool) -> void:
	if _menu_open == on:
		return
	_menu_open = on
	apply_fps()


## Открыто окно или экран до мира (предел MENU_FPS).
static func menu_open() -> bool:
	return _menu_open or _screen_idle


## Экран до мира (вход, выбор и создание персонажа, загрузка ресурсов): не больше MENU_FPS кадров/с.
static func set_screen_idle(on: bool) -> void:
	if _screen_idle == on:
		return
	_screen_idle = on
	apply_fps()


## Игра без фокуса или свёрнута (ThermalGuard по уведомлениям приложения): BACKGROUND_FPS кадров/с.
static func set_background(on: bool) -> void:
	if _background == on:
		return
	_background = on
	apply_fps()


static func in_background() -> bool:
	return _background


# ---------- Авто-снижение (ThermalGuard) ----------

## «Беречь телефон от перегрева» (по умолчанию включено; ключ guard секции [graphics]).
static func guard_enabled() -> bool:
	if _guard < 0:
		_guard = 1
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			_guard = 1 if bool(cf.get_value(SECTION, "guard", true)) else 0
	return _guard == 1


## Включить или выключить авто-снижение; выключили — графика сразу как выбрана (применить — Quality.apply).
static func set_guard_enabled(on: bool, save: bool = true) -> void:
	_guard = 1 if on else 0
	if not on:
		_throttle = 0
	if save:
		_save({"guard": on})


## Шаг авто-снижения (0 — графика как выбрана).
static func throttle_level() -> int:
	return _throttle


static func throttle_max() -> int:
	return THROTTLE_STEPS.size() - 1


## Задать шаг авто-снижения (применить — Quality.apply).
static func set_throttle(n: int) -> void:
	_throttle = clampi(n, 0, throttle_max())


static func _save_all() -> void:
	var vals := {"quality": _level, "fps": fps_limit()}
	for k in OPTIONS:
		vals[k] = int(_opts[k])
	_save(vals)


## Записать ключи секции [graphics] (другие ключи и секции файла сохраняются).
static func _save(vals: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)  # нет файла — начнём с пустого
	for k in vals:
		cf.set_value(SECTION, String(k), vals[k])
	var err := cf.save(PATH)
	if err != OK:
		push_warning("Не удалось сохранить настройки графики: %d" % err)


## Перечитать выбор из файла при следующем запросе.
static func reload() -> void:
	_level = -1
	_fps = -1
	_guard = -1


static func level_name(l: int = -1) -> String:
	return String(NAMES[clampi(level() if l < 0 else l, LOW, CUSTOM)])


static func description(l: int = -1) -> String:
	return String(DESCRIPTIONS[clampi(level() if l < 0 else l, LOW, CUSTOM)])


# ---------- Производные параметры ----------

static func _view() -> Dictionary:
	return VIEW_LEVELS[effective("view")]


static func _grass() -> Dictionary:
	return GRASS_LEVELS[option("grass")]


static func _shadow() -> Dictionary:
	return SHADOW_LEVELS[effective("shadows")]


static func grass_density() -> float:
	return float(_grass()["density"])


static func grass_distance() -> float:
	return float(_view()["grass"])


## Травинок в пучке травы (меньше — дешевле вершинный шейдер).
static func grass_blades() -> int:
	return int(_grass()["blades"])


static func flower_density() -> float:
	return float(_grass()["flowers"])


## Дальность кустов, камней и кристаллов, м.
static func detail_distance() -> float:
	return float(_view()["detail"])


static func tree_distance() -> float:
	return float(_view()["trees"])


## Дальность мелочей у построек (ящики, бочки, огни — меши «Props» зон IslandPois), м.
static func props_distance() -> float:
	return float(_view()["props"])


## Дальность декора полей (колосья), м.
static func decor_distance() -> float:
	return float(_view()["decor"])


## Порог LOD мешей, пикселей (Viewport.mesh_lod_threshold).
static func lod_threshold() -> float:
	return float(_view()["lod"])


## Контур моделей персонажей, жителей и зверей — до стольких м от камеры (ModelLod).
static func outline_far() -> float:
	return float(_view()["outline"])


## Контур участков деревьев, кустов и камней — до стольких м (до центра участка; IslandVegetation).
static func veg_outline_far() -> float:
	return float(_view()["veg_outline"])


static func shadows() -> bool:
	return effective("shadows") > 0


static func shadow_distance() -> float:
	return float(_shadow().get("distance", 0.0))


## Тени от кустов и камней.
static func small_shadows() -> bool:
	return bool(_shadow().get("small", false))


## Цветокоррекция и виньетка (PostFx).
static func postfx() -> bool:
	return effective("postfx") >= 1


## Мягкое свечение светлых мест (PostFx, полный вариант шейдера).
static func bloom() -> bool:
	return effective("postfx") >= 2


## Выбрано сглаживание FXAA (в Compatibility — свой проход PostFx, в Mobile — встроенный).
static func fxaa() -> bool:
	return effective("aa") == 1


## Рендерер Mobile (Vulkan): свои ветки разрешения, FXAA и фильтра теней.
static func mobile_renderer() -> bool:
	if renderer_override >= 0:
		return renderer_override == 1
	return RendererGuard.is_vulkan()


## FXAA своим проходом PostFx — только в Compatibility (в Mobile — встроенный, screen_aa()).
static func postfx_fxaa() -> bool:
	return fxaa() and not mobile_renderer()


## Встроенное экранное сглаживание окна (Viewport.screen_space_aa): FXAA в Mobile, иначе выключено.
static func screen_aa() -> Viewport.ScreenSpaceAA:
	if fxaa() and mobile_renderer():
		return Viewport.SCREEN_SPACE_AA_FXAA
	return Viewport.SCREEN_SPACE_AA_DISABLED


## FSR 1.0 для экрана высотой screen_h px: Mobile, 720p или 900p и кадр заметно меньше экрана.
static func use_fsr(screen_h: float) -> bool:
	if not mobile_renderer():
		return false
	var r := effective("render")
	return r >= 1 and RENDER_HEIGHTS[r] > 0 and render_scale_for(screen_h) < FSR_MAX_SCALE


## Способ растяжения 3D-кадра: FSR 1.0 (use_fsr) или билинейно.
static func scaling_mode_for(screen_h: float) -> Viewport.Scaling3DMode:
	return Viewport.SCALING_3D_MODE_FSR if use_fsr(screen_h) else Viewport.SCALING_3D_MODE_BILINEAR


## Фильтр карты теней (RenderingServer.SHADOW_QUALITY_*) текущего уровня теней и рендерера; −1 — тени выключены.
static func shadow_filter() -> int:
	var sh := _shadow()
	if sh.is_empty():
		return -1
	return int(sh["filter_mobile"] if mobile_renderer() else sh["filter"])


## Что Quality.apply передаст окну и солнцу на экране высотой screen_h (для тестов и отчёта): рендерер, масштаб и
## способ растяжения 3D, MSAA, встроенный FXAA, FXAA PostFx, фильтр теней.
static func render_params(screen_h: float) -> Dictionary:
	return {
		"mobile": mobile_renderer(),
		"scale": render_scale_for(screen_h),
		"scaling": scaling_mode_for(screen_h),
		"msaa": msaa(),
		"screen_aa": screen_aa(),
		"postfx_fxaa": postfx_fxaa(),
		"shadow_filter": shadow_filter(),
	}


## MSAA 3D-кадра (Viewport.MSAA_*).
static func msaa() -> Viewport.MSAA:
	match effective("aa"):
		2:
			return Viewport.MSAA_2X
		3:
			return Viewport.MSAA_4X
	return Viewport.MSAA_DISABLED


## Полные (дорогие) версии шейдеров земли и воды; иначе — облегчённые.
static func rich_shaders() -> bool:
	return option("textures") >= 2


## Рисованные текстуры земли и построек (WorldTextures). Полный режим (две выборки против повтора,
## triplanar) — вместе с rich_shaders().
static func textures() -> bool:
	return option("textures") >= 1


## Контуры (персонажи, звери, постройки, растительность).
static func outlines() -> bool:
	return effective("outlines") >= 1


## Доля частиц эффектов (Vfx).
static func effects_scale() -> float:
	return float(EFFECTS_SCALE[effective("effects")])


## Число частиц эффекта с учётом качества (не меньше 1).
static func particles(amount: int) -> int:
	return maxi(1, int(roundf(float(amount) * effects_scale())))


## Тени карты теней на моделях персонажей и зверей (самозатенение). Выкл — только cel-свет.
static func model_shadows() -> bool:
	return option("model_shadows") >= 1


## Высота кадра 3D-мира, px (0 — родное разрешение).
static func render_height() -> int:
	return int(RENDER_HEIGHTS[effective("render")])


## Масштаб 3D-кадра (Viewport.scaling_3d_scale) для экрана высотой screen_h px.
static func render_scale_for(screen_h: float) -> float:
	var h := render_height()
	if h <= 0 or screen_h < 2.0:
		return 1.0
	return clampf(float(h) / screen_h, 0.25, 1.0)


# ---------- Применение ----------

## Применяет текущие настройки ко всему, что уже создано.
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
	_set_group_range(tree, "poi_props", props_distance(), 8.0)
	_set_group_range(tree, "poi_decor", decor_distance(), 8.0)
	_apply_models()
	_apply_scene_models(tree.root)
	# Контур дальних моделей — по расстоянию (дальность — из «Дальности прорисовки»)
	ModelLod.update_all()


## Разрешение и сглаживание окна. Интерфейс рисуется в родном разрешении (растяжение canvas_items, база
## 1280×720 — раскладка та же), 3D-мир — с высотой render_height() и растягивается билинейно
## (Viewport.scaling_3d_scale; в GL Compatibility 4.3 есть только билинейное), в Mobile — FSR 1.0 (use_fsr).
## MSAA — у 3D-кадра; FXAA в Mobile — встроенный (screen_aa).
static func apply_resolution(tree: SceneTree) -> void:
	var win := tree.root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_size = Vector2i(1280, 720)
	win.msaa_3d = msaa()
	win.screen_space_aa = screen_aa()
	win.scaling_3d_mode = scaling_mode_for(float(win.size.y))
	win.fsr_sharpness = FSR_SHARPNESS
	win.scaling_3d_scale = render_scale_for(float(win.size.y))
	# Порог LOD мешей (модели героев, жителей, зверей — с LOD из импорта; выбор LOD есть и в Compatibility)
	win.mesh_lod_threshold = lod_threshold()
	# Окно сменило размер (поворот, выход из полноэкранного режима) — масштаб 3D по новой высоте
	if not _resize_hooked:
		_resize_hooked = true
		var on_resize := func() -> void:
			if is_instance_valid(win):
				win.scaling_3d_mode = Quality.scaling_mode_for(float(win.size.y))
				win.scaling_3d_scale = Quality.render_scale_for(float(win.size.y))
		win.size_changed.connect(on_resize)


## Тени направленных источников света (солнце) в поддереве root.
static func apply_lights(root: Node) -> void:
	if root == null:
		return
	var sh := _shadow()
	var on := not sh.is_empty()
	if on:
		# Только при изменении: в Mobile смена фильтра пересобирает специализации шейдеров сцены
		var atlas := int(sh["atlas"])
		if atlas != _last_atlas:
			_last_atlas = atlas
			RenderingServer.directional_shadow_atlas_set_size(atlas, true)
		var filter := shadow_filter()
		if filter != _last_filter:
			_last_filter = filter
			RenderingServer.directional_soft_shadow_filter_set_quality(filter as RenderingServer.ShadowQuality)
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := n as DirectionalLight3D
		if sun == null:
			continue
		sun.shadow_enabled = on
		if not on:
			continue
		sun.shadow_bias = SHADOW_BIAS
		sun.shadow_normal_bias = SHADOW_NORMAL_BIAS
		sun.directional_shadow_max_distance = float(sh["distance"])
		sun.directional_shadow_blend_splits = bool(sh["blend"])
		sun.directional_shadow_fade_start = 0.85
		var sp: Array = sh["split"]
		sun.directional_shadow_split_1 = float(sp[0])
		sun.directional_shadow_split_2 = float(sp[1])
		sun.directional_shadow_split_3 = float(sp[2])
		if int(sh["splits"]) >= 4:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		else:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


static func _set_group_range(tree: SceneTree, group: String, dist: float, margin: float) -> void:
	for n in tree.get_nodes_in_group(group):
		var gi := n as GeometryInstance3D
		if gi == null:
			continue
		gi.visibility_range_end = dist
		gi.visibility_range_end_margin = margin


## Материал модели персонажа, зверя или питомца: тени на модели — по model_shadows(), контур outline
## (null — без контура) — по outlines(). Меняются сразу при смене настроек (apply).
static func track_model(m: Material, outline: Material = null) -> void:
	if m == null:
		return
	if m is BaseMaterial3D:
		(m as BaseMaterial3D).disable_receive_shadows = not model_shadows()
		m.set_meta("model_mat", true)
		_model_mats = _alive(_model_mats)
		_model_mats.append(weakref(m))
	if outline != null:
		track_outline(m, outline)


## Материал с контуром: next_pass = outline, если контуры включены (иначе null). Меняется сразу (apply).
static func track_outline(m: Material, outline: Material) -> void:
	if m == null or outline == null:
		return
	m.set_meta("outline", outline)
	m.next_pass = outline if outlines() else null
	_outline_mats = _alive(_outline_mats)
	_outline_mats.append(weakref(m))


## Список без умерших ссылок (чистится, когда вырос).
static func _alive(list: Array[WeakRef]) -> Array[WeakRef]:
	if list.size() < 64 or list.size() % 32 != 0:
		return list
	var out: Array[WeakRef] = []
	for wr in list:
		if wr.get_ref() != null:
			out.append(wr)
	return out


## Обход сцены: материалы моделей (meta "model_mat" — тени на модели) и с контуром (meta "outline") у всех мешей —
## не зависит от списков WeakRef (в автотесте они оказывались пустыми, и контур героя не выключался).
static func _apply_scene_models(root: Node) -> void:
	if root == null:
		return
	var recv := not model_shadows()
	var ol := outlines()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mats: Array[Material] = [mi.material_override]
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
		for mat in mats:
			if mat == null:
				continue
			if mat.has_meta("model_mat") and mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				if bm.disable_receive_shadows != recv:
					bm.disable_receive_shadows = recv
			if mat.has_meta("outline"):
				var want: Material = (mat.get_meta("outline") as Material) if ol and not ModelLod.is_far(mat) else null
				if mat.next_pass != want:
					mat.next_pass = want


static func _apply_models() -> void:
	var recv := not model_shadows()
	var ol := outlines()
	var alive: Array[WeakRef] = []
	for wr in _model_mats:
		var m := wr.get_ref() as BaseMaterial3D
		if m == null:
			continue
		alive.append(wr)
		if m.disable_receive_shadows != recv:
			m.disable_receive_shadows = recv
		# Контур модели — здесь же (модель героя или зверя с контуром: meta "outline")
		if m.has_meta("outline"):
			var mw: Material = (m.get_meta("outline") as Material) if ol and not ModelLod.is_far(m) else null
			if m.next_pass != mw:
				m.next_pass = mw
	_model_mats = alive
	var alive_ol: Array[WeakRef] = []
	for wr in _outline_mats:
		var om := wr.get_ref() as Material
		if om == null or not om.has_meta("outline"):
			continue
		alive_ol.append(wr)
		var want: Material = (om.get_meta("outline") as Material) if ol and not ModelLod.is_far(om) else null
		if om.next_pass != want:
			om.next_pass = want
	_outline_mats = alive_ol
