class_name DungeonEditor
extends Node
## Редактор расстановки объектов подземелья (0.35.2; решение Максима: объекты по месту ставит он сам на телефоне, по
## образцу режима расстановки «Чайника безмятежности» Genshin Impact; я переношу файл в игру и слежу за коллизиями,
## проходами и нагрузкой). Только у администратора (AdminPanel.enabled()) и только в подземелье: админ-панель → «Мир»
## → «Открыть редактор» (start).
## Как в «Чайнике»:
##   • свободная камера — герой скрыт и стоит, джойстик ведёт точку обзора (pivot) над полом, палец — поворот камеры,
##     щипок — приближение (main.edit_cam: дальше и круче обычного, EDIT_DIST_MAX, EDIT_PITCH_MAX);
##   • касание объекта — выбор (золотая рамка по габаритам; у твёрдых DungeonProps.SOLID — красная коробка коллизии),
##     касание пустого места — снять выбор; выбранный объект тянется пальцем по полу (HUD.claim_touch: касание
##     выбранного не вращает камеру);
##   • снизу — полоса выбранного: название и замечания (красным, рамка красная: «в стене», «в воде», «задевает …»,
##     «на выходе портала» — problems; ставить всё равно можно), ползунки «Поворот», «Размер», «Высота», стрелки
##     сдвига на NUDGE м (удержание — повтор), «Копия», «Убрать»;
##   • «Каталог» — снизу вкладки разделов CATALOG и карточки с картинками (assets/icons/props/<id>.png — снимки
##     моделей, tools/render_prop_thumbs.gd; часть пакета icons), касание карточки — объект в точке пола в центре
##     экрана, выбран;
##   • сверху: «Каталог», «Отменить» (до UNDO_MAX шагов), «Сохранить», «Отправить», «Выйти».
## На время правки объекты подземелья — отдельные модели (склеенные меши участков, коробки коллизии и огни
## DungeonProps скрыты; мосты остаются), огни — у первых DungeonProps.MAX_LIGHTS объектов с огнём, как в игре.
## Раскладка сохраняется сама (AUTOSAVE с после правки, при выходе) в layout_path — user://dungeon_layout.json:
## {"format": 1, "layout_version": …, "saved": дата, "count": N, "props": [[id, x, z, поворот°, масштаб, высота], …]} —
## формат world/dungeon.json "props". DungeonProps.build берёт её вместо встроенной (props_for), пока у файла тот же
## layout_version, что у world/dungeon.json: перенёс я раскладку в игру и поднял версию — файл больше не действует.
## «Отправить» — копия в «Загрузки/DarkPact_test» и «Поделиться» системы (плагин, как отчёт тест-бота).
## «Выйти» — сохранение и сцена заново (DungeonProps склеивает новую раскладку), герой — там же (Game.arrive "editor").
## Для тестов: buttons — "ed_catalog", "ed_undo", "ed_save", "ed_share", "ed_exit", "ed_copy", "ed_delete",
## "ed_nudge_fwd", "ed_nudge_back", "ed_nudge_left", "ed_nudge_right", каталог — "ed_cat_tab_<n>", "ed_cat_<id>",
## "ed_cat_close"; sliders — "rot", "scale", "height"; press(ключ) — нажать (у стрелок — один шаг).

const LAYOUT_FILE := "user://dungeon_layout.json"
const THUMBS := "res://assets/icons/props/"
const FORMAT := 1
const UNDO_MAX := 60
const AUTOSAVE := 4.0
## Сдвиг стрелками, м; удержание: повтор через HOLD_DELAY с, дальше каждые HOLD_EVERY с.
const NUDGE := 0.1
const HOLD_DELAY := 0.35
const HOLD_EVERY := 0.06
## Касание: короче TAP_SEC и сдвиг меньше TAP_PX — выбор; объект — если касание не дальше его размера на экране
## (не меньше PICK_PX).
const PICK_PX := 34.0
const TAP_SEC := 0.45
const TAP_PX := 18.0
## Ползунки: [ключ, подпись, мин., макс., шаг].
const SLIDERS := [["rot", "Поворот", 0.0, 359.0, 5.0], ["scale", "Размер", 0.2, 3.0, 0.01], ["height", "Высота", -3.0, 6.0, 0.05]]
## Свободная камера: скорость точки обзора — доля расстояния камеры в секунду (не меньше PIVOT_MIN м/с).
const PIVOT_SPEED := 0.9
const PIVOT_MIN := 5.0
const EDIT_DIST_MAX := 45.0
const EDIT_PITCH_MAX := deg_to_rad(88.0)
## Может стоять у стены / в скале и в воде (иначе замечание).
const WALL_OK := ["dg_cliffs", "dg_cavern", "dg_mine", "dg_ladder", "dg_spire", "dg_crag", "dg_moss_stones",
	"dg_dripstone", "dg_amethyst_spires", "dg_ascent", "dg_crystal_purple", "dg_crystal_blue", "dg_glowcaps"]
const WATER_OK := ["dg_kelp", "dg_coral", "dg_rowboat", "dg_raft", "dg_wreck", "dg_dripstone", "dg_mast",
	"dg_crows_nest", "dg_mast_relic", "dg_leviathan", "dg_ship_deck", "dg_ship_bow", "dg_siren", "dg_anchor",
	"dg_tidepool", "dg_pier", "dg_dock", "dg_wharf", "dg_net"]
## Ближе PORTAL_KEEP м к точке выхода портала — замечание (там появляется герой).
const PORTAL_KEEP := 3.0
const BAR_W := 860.0
const COL_OK := Color(1.0, 0.82, 0.25)
const COL_BAD := Color(1.0, 0.3, 0.25)

const CATALOG := [
	["Секта и руны", ["dg_coral_altar", "dg_crypt_altar", "dg_obelisk", "dg_monolith", "dg_rune_arch", "dg_spiral", "dg_witch_brazier", "dg_candles", "dg_banner", "dg_oracle", "dg_prayer_rug"]],
	["Камни и кристаллы", ["dg_spire", "dg_crag", "dg_moss_stones", "dg_amethyst_spires", "dg_crystal_purple", "dg_crystal_blue", "dg_glowcaps", "dg_dripstone", "dg_cavern", "dg_cliffs", "dg_mine", "dg_ascent"]],
	["Лагерь", ["dg_tent", "dg_bedroll", "dg_bearskin", "dg_nest", "dg_stone_ring", "dg_cauldron", "dg_table", "dg_crates", "dg_barrel", "dg_spoils"]],
	["Оборона и кости", ["dg_palisade", "dg_barricade", "dg_spikes", "dg_barricade_moss", "dg_totem", "dg_throne", "dg_prison", "dg_armory", "dg_remains", "dg_mariner", "dg_mossy_remains", "dg_leviathan"]],
	["Сокровища", ["dg_relics", "dg_chest", "dg_chest_open", "dg_gold", "dg_hoard"]],
	["Свет", ["dg_torch", "dg_brazier", "dg_lantern", "dg_harbor_post"]],
	["Причал и корабль", ["dg_bell", "dg_dock", "dg_pier", "dg_wharf", "dg_net", "dg_anchor", "dg_raft", "dg_rowboat", "dg_siren", "dg_mast", "dg_crows_nest", "dg_mast_relic", "dg_helm", "dg_cannon", "dg_ladder", "dg_ship_deck", "dg_ship_bow", "dg_wreck"]],
	["Вода", ["dg_kelp", "dg_coral", "dg_tidepool"]],
]
const NAMES := {
	"dg_coral_altar": "Алтарь-череп из кораллов",
	"dg_crypt_altar": "Малый алтарь склепа",
	"dg_obelisk": "Проклятый обелиск",
	"dg_monolith": "Рунный монолит",
	"dg_rune_arch": "Рунная плита-арка",
	"dg_spiral": "Светящаяся спираль",
	"dg_witch_brazier": "Изумрудная жаровня",
	"dg_candles": "Изумрудные свечи",
	"dg_banner": "Знамя Изумрудного стража",
	"dg_oracle": "Морской оракул",
	"dg_prayer_rug": "Молитвенный коврик",
	"dg_spire": "Мшистый клык (столб)",
	"dg_crag": "Фиолетовая скала",
	"dg_moss_stones": "Мшистые камни",
	"dg_amethyst_spires": "Аметистовые шипы",
	"dg_crystal_purple": "Аметистовая корона",
	"dg_crystal_blue": "Лазурные кристаллы",
	"dg_glowcaps": "Светящиеся грибы",
	"dg_dripstone": "Аметистовые сталагмиты",
	"dg_cavern": "Мшистый грот",
	"dg_cliffs": "Мшистые утёсы",
	"dg_mine": "Заваленный вход в шахту",
	"dg_ascent": "Каменная лестница",
	"dg_tent": "Шалаш из вёсел и паруса",
	"dg_bedroll": "Спальник",
	"dg_bearskin": "Медвежья шкура",
	"dg_nest": "Гнездо с добычей",
	"dg_stone_ring": "Кострище",
	"dg_cauldron": "Котёл на огне",
	"dg_table": "Стол",
	"dg_crates": "Ящики",
	"dg_barrel": "Бочка",
	"dg_spoils": "Добыча торговца",
	"dg_palisade": "Частокол с черепами",
	"dg_barricade": "Баррикада",
	"dg_spikes": "Колья",
	"dg_barricade_moss": "Мшистая баррикада",
	"dg_totem": "Рогатый тотем из костей",
	"dg_throne": "Пиратский трон из костей",
	"dg_prison": "Клетка-тюрьма",
	"dg_armory": "Ржавая оружейная стойка",
	"dg_remains": "Останки",
	"dg_mariner": "Останки моряка",
	"dg_mossy_remains": "Мшистые останки",
	"dg_leviathan": "Кости левиафана",
	"dg_relics": "Затонувшие реликвии",
	"dg_chest": "Сундук",
	"dg_chest_open": "Открытый сундук с золотом",
	"dg_gold": "Золото россыпью",
	"dg_hoard": "Пиратский клад",
	"dg_torch": "Факел",
	"dg_brazier": "Жаровня",
	"dg_lantern": "Медный фонарь",
	"dg_harbor_post": "Столб с фонарём",
	"dg_bell": "Сигнальный колокол",
	"dg_dock": "Причальные мостки",
	"dg_pier": "Площадка мостков",
	"dg_wharf": "Пристань с навесом",
	"dg_rope_bridge": "Верёвочный мост",
	"dg_net": "Рыболовная сеть",
	"dg_anchor": "Древний якорь",
	"dg_raft": "Плот",
	"dg_rowboat": "Лодка",
	"dg_siren": "Сирена из плавника",
	"dg_mast": "Мачта «Глаз утопленника»",
	"dg_crows_nest": "Гнилое воронье гнездо",
	"dg_mast_relic": "Обломок мачты",
	"dg_helm": "Штурвал",
	"dg_cannon": "Ржавая пушка",
	"dg_ladder": "Верёвочная лестница",
	"dg_ship_deck": "Палуба корабля",
	"dg_ship_bow": "Нос корабля",
	"dg_wreck": "Изумрудный остов",
	"dg_kelp": "Золотая ламинария",
	"dg_coral": "Лазурный коралл",
	"dg_tidepool": "Лужа с сокровищами",
}

## Файл раскладки (тесты подменяют).
static var layout_path := LAYOUT_FILE
## Открытый редактор (null — закрыт).
static var current: DungeonEditor = null
## Куда поставить героя после выхода (Game.arrive "editor", main._build_player).
static var return_pos := Vector3.ZERO
static var return_yaw := 0.0

var main: Node = null
var world: DungeonWorld = null
## Раскладка: [{"id", "x", "z", "yaw" (°), "s", "dy", "node": Node3D}]
var items: Array = []
var sel := -1
var buttons := {}
var sliders := {}
var dirty := false
var saves := 0
## Точка обзора свободной камеры (main.cam_focus).
var pivot := Vector3.ZERO
var catalog_open := false
var cat_group := 0
var _undo: Array = []
var _save_t := 0.0
var _root: Node3D = null
var _mark: MeshInstance3D = null
var _lights: Node3D = null
var _top: HBoxContainer = null
var _hint: Label = null
var _bar: PanelContainer = null
var _bar_name: Label = null
var _catalog: PanelContainer = null
var _cards: HBoxContainer = null
var _hold_fn := Callable()
var _hold_t := 0.0
var _tap := {}
var _drag_idx := -1
var _drag_off := Vector2.ZERO
var _drag_y := 0.0
var _syncing := false
var _hero_vis := true


# ---------- Раскладка из файла (DungeonProps) ----------

## Список объектов подземелья: раскладка редактора, если она есть и действует, иначе world/dungeon.json "props".
static func props_for(w: IslandWorld) -> Array:
	var saved: Variant = saved_layout(w)
	if saved is Array:
		return saved
	return w.cfg.get("props", [])


## Раскладка из файла редактора: Array — действует (админ, тот же layout_version), иначе null.
static func saved_layout(w: IslandWorld) -> Variant:
	if not AdminPanel.enabled():
		return null
	var d := read_file()
	if d.is_empty() or int(d.get("layout_version", -1)) != layout_version(w):
		return null
	var p: Variant = d.get("props")
	return p if p is Array else null


static func read_file() -> Dictionary:
	if not FileAccess.file_exists(layout_path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if v is Dictionary and int((v as Dictionary).get("format", 0)) == FORMAT:
		return v
	return {}


static func has_file() -> bool:
	return FileAccess.file_exists(layout_path)


static func layout_version(w: IslandWorld) -> int:
	return int(w.cfg.get("layout_version", 0)) if w != null else 0


## Удалить свою раскладку (вернуть встроенную).
static func reset_file() -> void:
	if FileAccess.file_exists(layout_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(layout_path))


static func title(id: String) -> String:
	return String(NAMES.get(id, id))


## Картинка каталога (снимок модели) или null.
static func thumb(id: String) -> Texture2D:
	var p := THUMBS + id + ".png"
	return load(p) as Texture2D if Assets.exists(p) else null


# ---------- Вход и выход ----------

## Открыть редактор в главной сцене m (только админ, только подземелье). null — нельзя (сообщение в HUD).
static func start(m: Node) -> DungeonEditor:
	if current != null and is_instance_valid(current):
		return current
	var w := IslandWorld.current as DungeonWorld
	if not AdminPanel.enabled() or w == null or m == null:
		if m != null and m.get("hud") != null:
			(m.hud as HUD).show_message("Редактор объектов — только в подземелье")
		return null
	var ed := DungeonEditor.new()
	ed.name = "DungeonEditor"
	ed.main = m
	ed.world = w
	m.add_child(ed)
	current = ed
	ed._open()
	return ed


func _open() -> void:
	var file := read_file()
	var note := ""
	var src: Array = world.cfg.get("props", [])
	if not file.is_empty():
		if int(file.get("layout_version", -1)) == layout_version(world):
			src = file.get("props", src)
		else:
			note = " Ваш прошлый файл — от прежней раскладки: начато со встроенной."
	_hide_baked()
	_root = Node3D.new()
	_root.name = "EditorProps"
	world.add_child(_root)
	_lights = Node3D.new()
	_lights.name = "EditorLights"
	world.add_child(_lights)
	_mark = MeshInstance3D.new()
	_mark.name = "EditorMark"
	_mark.set_meta("no_outline", true)
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_mark)
	_load_entries(src)
	# Свободная камера: герой скрыт и стоит, камера следит за точкой обзора
	var p: Player = main.get("player")
	if p != null:
		pivot = p.global_position
		_hero_vis = p.visible
		p.visible = false
		p.move_input = Vector2.ZERO
	main.set("edit_cam", true)
	main.set("cam_dist", maxf(float(main.get("cam_dist")), 16.0))
	main.set("cam_pitch", maxf(float(main.get("cam_pitch")), deg_to_rad(55.0)))
	var hud: HUD = main.hud
	hud.edit_mode = true
	hud.claim_touch = _claim
	_build_ui()
	select(-1)
	_msg("Режим расстановки: %d объектов. Касание — выбрать, выбранный тяните пальцем.%s" % [items.size(), note], 5.0)


## Склеенные меши, запасные модели, коробки коллизии и огни DungeonProps — скрыть на время правки (мосты остаются).
func _hide_baked() -> void:
	var holder := world.get_node_or_null("DungeonProps")
	if holder == null:
		return
	for c in holder.get_children():
		if c is MeshInstance3D and c.name.begins_with("Props"):
			(c as MeshInstance3D).visible = false
		elif c is Node3D and c.name == "Fallback":
			(c as Node3D).visible = false
		elif c is OmniLight3D:
			(c as OmniLight3D).visible = false
		elif c is StaticBody3D:
			(c as StaticBody3D).collision_layer = 0


## Сохранить и выйти: сцена заново (DungeonProps склеит новую раскладку), герой — там, где стоял.
func exit_editor() -> void:
	save()
	var p: Node3D = main.get("player")
	if p != null:
		return_pos = p.global_position
	return_yaw = float(main.get("cam_yaw"))
	Game.arrive = "editor"
	current = null
	main.call("restart_scene")


func _exit_tree() -> void:
	if current == self:
		current = null


# ---------- Объекты ----------

func _load_entries(src: Array) -> void:
	for it in items:
		_free_node(it)
	items.clear()
	for e in src:
		var a: Array = e
		if a.is_empty():
			continue
		items.append({"id": String(a[0]), "x": float(a[1]), "z": float(a[2]),
			"yaw": float(a[3]) if a.size() > 3 else 0.0, "s": float(a[4]) if a.size() > 4 else 1.0,
			"dy": float(a[5]) if a.size() > 5 else 0.0, "node": null})
	for it in items:
		_make_node(it)
	_refresh_lights()


func _free_node(it: Dictionary) -> void:
	var n: Variant = it.get("node")
	if n is Node and is_instance_valid(n):
		(n as Node).queue_free()
	it["node"] = null


func _make_node(it: Dictionary) -> void:
	var id := String(it["id"])
	var n := Node3D.new()
	n.name = id
	if PropAsset.has(id) and PropAsset.mesh(id) != null:
		var mi := MeshInstance3D.new()
		mi.mesh = PropAsset.mesh(id)
		mi.material_override = PropAsset.material(PropAsset.page(id))
		mi.set_meta("no_outline", true)
		n.add_child(mi)
	else:
		DungeonProps._fallback(n, id, Transform3D.IDENTITY, DungeonProps._fallback_size(id))
	_root.add_child(n)
	it["node"] = n
	_place_node(it)


func _place_node(it: Dictionary) -> void:
	var n: Node3D = it["node"]
	if n == null:
		return
	n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(it["yaw"]))).scaled(Vector3.ONE * float(it["s"])),
		pos_of(it))
	if sel >= 0 and sel < items.size() and items[sel] == it:
		_update_mark()


## Точка основания объекта (как в DungeonProps.build).
func pos_of(it: Dictionary) -> Vector3:
	var x := float(it["x"])
	var z := float(it["z"])
	return Vector3(x, world.height_at(x, z) - 0.04 + float(it["dy"]), z)


func size_of(id: String) -> Vector3:
	return PropAsset.size(id) if PropAsset.has(id) else DungeonProps._fallback_size(id)


## Огни — как в игре: у первых MAX_LIGHTS объектов с огнём по порядку списка.
func _refresh_lights() -> void:
	for c in _lights.get_children():
		c.queue_free()
	var n := 0
	for it in items:
		var id := String(it["id"])
		if not DungeonProps.LIGHTS.has(id) or n >= DungeonProps.MAX_LIGHTS:
			continue
		DungeonProps._light(_lights, id, pos_of(it), float(it["s"]))
		n += 1


## Раскладка в формате world/dungeon.json "props".
func entries() -> Array:
	var res: Array = []
	for it in items:
		res.append([String(it["id"]), snappedf(float(it["x"]), 0.01), snappedf(float(it["z"]), 0.01),
			snappedf(fposmod(float(it["yaw"]), 360.0), 0.1), snappedf(float(it["s"]), 0.001), snappedf(float(it["dy"]), 0.01)])
	return res


## Замечания к месту объекта it ("" — всё хорошо): в стене, в воде, задевает твёрдый объект, на выходе портала.
func problems(it: Dictionary) -> String:
	var id := String(it["id"])
	var x := float(it["x"])
	var z := float(it["z"])
	var res: PackedStringArray = []
	if not world.is_walkable(x, z):
		if world.water_distance(x, z) < 1.0:
			if not WATER_OK.has(id):
				res.append("в воде")
		elif not WALL_OK.has(id) and not WATER_OK.has(id):
			res.append("в стене")
	var solid := DungeonProps.SOLID.has(id)
	var r := _radius(it)
	for o in items:
		if o == it:
			continue
		var oid := String(o["id"])
		if not solid and not DungeonProps.SOLID.has(oid):
			continue
		var d := Vector2(float(o["x"]) - x, float(o["z"]) - z).length()
		if d < (r + _radius(o)) * 0.8:
			res.append("задевает: " + title(oid).to_lower())
			break
	var pt: Portal = main.get("portal")
	if pt != null:
		var ep := pt.exit_point()
		if Vector2(ep.x - x, ep.z - z).length() < PORTAL_KEEP:
			res.append("на выходе портала")
	return ", ".join(res)


func _radius(it: Dictionary) -> float:
	var sz := size_of(String(it["id"]))
	return minf(sz.x, sz.z) * 0.5 * float(it["s"]) * DungeonProps.COLLIDE_K


# ---------- Выбор ----------

func selected() -> Dictionary:
	return items[sel] if sel >= 0 and sel < items.size() else {}


func select(i: int) -> void:
	sel = i if i >= 0 and i < items.size() else -1
	_update_mark()
	_sync_bar()


## Ближайший к точке обзора.
func select_nearest() -> void:
	if items.is_empty():
		select(-1)
		return
	var best := 0
	for i in items.size():
		if _flat(pos_of(items[i]), pivot) < _flat(pos_of(items[best]), pivot):
			best = i
	select(best)


## Объект под точкой экрана sp: ближайший к ней центр модели (с запасом на её размер на экране); −1 — нет.
func object_at(sp: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var best := -1
	var best_k := 1.0
	for i in items.size():
		var it: Dictionary = items[i]
		var sz := size_of(String(it["id"])) * float(it["s"])
		var c := pos_of(it) + Vector3(0, sz.y * 0.45, 0)
		if cam.is_position_behind(c):
			continue
		var at := cam.unproject_position(c)
		var edge := cam.unproject_position(c + cam.global_basis.x * maxf(sz.x, sz.z) * 0.5)
		var r := maxf(UiScale.px(PICK_PX), at.distance_to(edge))
		var k := at.distance_to(sp) / r
		if k < best_k:
			best_k = k
			best = i
	return best


## Касание экрана в точке sp — выбрать объект под ней (пусто — снять выбор). Возвращает номер.
func pick_at(sp: Vector2) -> int:
	var i := object_at(sp)
	select(i)
	return i


## Точка пола под точкой экрана sp (плоскость на высоте y, уточнённая рельефом); null — луч не попал в пол.
func ground_at(sp: Vector2, y: float) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if d.y > -0.02:
		return null
	var h := y
	var p := o
	for k in 3:
		p = o + d * ((h - o.y) / d.y)
		h = world.height_at(p.x, p.z)
	return p


# ---------- Правка ----------

## Снимок для «Отменить» (перед каждой правкой).
func _push_undo() -> void:
	_undo.append([entries(), sel])
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()


func undo() -> bool:
	if _undo.is_empty():
		_msg("Отменять нечего")
		return false
	var u: Array = _undo.pop_back()
	_load_entries(u[0])
	select(int(u[1]))
	_changed()
	return true


func _changed(lights := true) -> void:
	dirty = true
	_save_t = AUTOSAVE
	if lights:
		_refresh_lights()
	_sync_bar()


## Сдвиг выбранного относительно камеры на шаг NUDGE: fwd — от камеры вперёд, side — вправо.
func nudge(fwd: float, side: float) -> void:
	var it := selected()
	if it.is_empty():
		return
	var v := (Vector3(0, 0, -1) * fwd + Vector3(1, 0, 0) * side).rotated(Vector3.UP, float(main.get("cam_yaw"))) * NUDGE
	set_xz(it, float(it["x"]) + v.x, float(it["z"]) + v.z)
	_changed()


func set_xz(it: Dictionary, x: float, z: float) -> void:
	it["x"] = x
	it["z"] = z
	_place_node(it)


## Значение ползунка key ("rot" — поворот °, "scale" — размер, "height" — высота над полом) у выбранного.
func set_value(key: String, v: float) -> void:
	var it := selected()
	if it.is_empty():
		return
	match key:
		"rot":
			it["yaw"] = fposmod(v, 360.0)
		"scale":
			it["s"] = clampf(v, 0.2, 3.0)
		"height":
			it["dy"] = clampf(v, -3.0, 6.0)
	_place_node(it)
	_changed(key != "rot")


## Копия выбранного рядом (на 1.5 м вправо от камеры), выбрана копия.
func copy_selected() -> void:
	var it := selected()
	if it.is_empty():
		return
	_push_undo()
	var c := it.duplicate()
	var v := Vector3(1.5, 0, 0).rotated(Vector3.UP, float(main.get("cam_yaw")))
	c["x"] = float(c["x"]) + v.x
	c["z"] = float(c["z"]) + v.z
	c["node"] = null
	items.insert(sel + 1, c)
	_make_node(c)
	select(sel + 1)
	_changed()


func delete_selected() -> void:
	var it := selected()
	if it.is_empty():
		return
	_push_undo()
	var nm := title(String(it["id"]))
	_free_node(it)
	items.remove_at(sel)
	select(-1)
	_changed()
	_msg("Убрано: %s («Отменить» вернёт)" % nm)


## Новый объект id в точке пола в центре экрана (нет — у точки обзора), выбран.
func add(id: String) -> void:
	_push_undo()
	var at := pivot
	var view := get_viewport().get_visible_rect().size
	var g: Variant = ground_at(view * 0.5, pivot.y)
	if g is Vector3 and _flat(g, pivot) < 40.0:
		at = g
	var yaw := fposmod(rad_to_deg(float(main.get("cam_yaw"))), 360.0)
	var it := {"id": id, "x": at.x, "z": at.z, "yaw": snappedf(yaw, 15.0), "s": 1.0, "dy": 0.0, "node": null}
	items.append(it)
	_make_node(it)
	select(items.size() - 1)
	_changed()


# ---------- Файл ----------

func save() -> bool:
	var L := PackedStringArray()
	L.append("{")
	L.append('\t"format": %d,' % FORMAT)
	L.append('\t"layout_version": %d,' % layout_version(world))
	L.append('\t"saved": "%s",' % Time.get_datetime_string_from_system(false, true))
	L.append('\t"count": %d,' % items.size())
	L.append('\t"props": [')
	var es := entries()
	for i in es.size():
		L.append("\t\t" + JSON.stringify(es[i]) + ("," if i < es.size() - 1 else ""))
	L.append("\t]")
	L.append("}")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(layout_path.get_base_dir()))
	var f := FileAccess.open(layout_path, FileAccess.WRITE)
	if f == null:
		_msg("Не удалось сохранить раскладку")
		return false
	f.store_string("\n".join(L) + "\n")
	f.close()
	dirty = false
	saves += 1
	return true


## Копия файла в «Загрузки/DarkPact_test» и «Поделиться» (Android, плагин); на ПК — папка файла. Сообщение.
static func share_file() -> String:
	if not has_file():
		return "Файла раскладки ещё нет — откройте редактор и сохраните"
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var copy := "user://dungeon_layout_%s.json" % stamp
	DirAccess.copy_absolute(ProjectSettings.globalize_path(layout_path), ProjectSettings.globalize_path(copy))
	var pub := BotReport.publish(copy, "application/json")
	var v: Variant = BotReport.plugin_call("share", [ProjectSettings.globalize_path(copy), "application/json",
		"Раскладка подземелья Dark Pact"])
	if v is bool and bool(v):
		return "Выберите, куда отправить файл" + (" (копия: %s)" % pub["public"] if bool(pub["ok"]) else "")
	if bool(pub["ok"]):
		return "Файл раскладки: " + String(pub["public"])
	var dir := ProjectSettings.globalize_path(copy.get_base_dir())
	if DisplayServer.get_name() != "headless":
		OS.shell_open(dir)
	return "Файл раскладки: " + ProjectSettings.globalize_path(copy)


# ---------- Каждый кадр, касания ----------

func _process(delta: float) -> void:
	if _hold_fn.is_valid():
		_hold_t += delta
		while _hold_t >= HOLD_EVERY:
			_hold_t -= HOLD_EVERY
			_hold_fn.call()
	if dirty:
		_save_t -= delta
		if _save_t <= 0.0:
			save()
	var hud: HUD = main.get("hud")
	if hud == null:
		return
	# Джойстик ведёт точку обзора (быстрее, когда камера дальше)
	var mv := hud.move_vec
	if mv.length() > 0.15:
		var speed := maxf(PIVOT_MIN, float(main.get("cam_dist")) * PIVOT_SPEED)
		var d := Vector3(mv.x, 0.0, mv.y).rotated(Vector3.UP, float(main.get("cam_yaw"))) * speed * delta
		var lo := world.origin
		var hi := world.origin + Vector2(float(world.nx), float(world.nz)) * world.step
		pivot = Vector3(clampf(pivot.x + d.x, lo.x, hi.x), pivot.y, clampf(pivot.z + d.z, lo.y, hi.y))
	# Высота — пол без стен (над стеной камера не подпрыгивает)
	var fy := float(world.cfg.get("floor_y", 0.0))
	pivot.y = lerpf(pivot.y, clampf(world.height_at(pivot.x, pivot.z), fy - 3.0, fy + 6.0), 1.0 - exp(-6.0 * delta))
	var p: Player = main.get("player")
	if p != null:
		p.move_input = Vector2.ZERO
	var win := hud.is_window_open()
	_top.visible = not win
	_hint.visible = not win
	_bar.visible = not win and not catalog_open and sel >= 0
	_catalog.visible = not win and catalog_open
	_layout_ui()


## HUD.claim_touch: касание выбранного объекта — начать перетаскивание (камера не вращается).
func _claim(index: int, sp: Vector2) -> bool:
	if sel < 0 or catalog_open or object_at(sp) != sel:
		return false
	var it := selected()
	var base := pos_of(it)
	var g: Variant = ground_at(sp, base.y)
	if not g is Vector3:
		return false
	_push_undo()
	_drag_idx = index
	_drag_y = base.y
	_drag_off = Vector2(float(it["x"]) - (g as Vector3).x, float(it["z"]) - (g as Vector3).z)
	_tap.erase(index)
	return true


func _input(event: InputEvent) -> void:
	var hud: HUD = main.get("hud")
	if hud == null or hud.is_window_open():
		return
	var te := event as InputEventScreenTouch
	if te != null:
		if te.pressed:
			if te.index == _drag_idx or _over_ui(te.position) or hud.over_blocker(te.position):
				return
			_tap[te.index] = [te.position, Time.get_ticks_msec()]
		else:
			if te.index == _drag_idx:
				_drag_idx = -1
				_changed()
				return
			if _tap.has(te.index):
				var t: Array = _tap[te.index]
				_tap.erase(te.index)
				if (t[0] as Vector2).distance_to(te.position) < UiScale.px(TAP_PX) \
						and float(Time.get_ticks_msec() - int(t[1])) < TAP_SEC * 1000.0:
					pick_at(te.position)
		return
	var de := event as InputEventScreenDrag
	if de == null:
		return
	if de.index == _drag_idx:
		var it := selected()
		var g: Variant = ground_at(de.position, _drag_y)
		if not it.is_empty() and g is Vector3:
			set_xz(it, (g as Vector3).x + _drag_off.x, (g as Vector3).z + _drag_off.y)
			_sync_bar(false)
		return
	if _tap.has(de.index) and ((_tap[de.index] as Array)[0] as Vector2).distance_to(de.position) >= UiScale.px(TAP_PX):
		_tap.erase(de.index)


func _over_ui(sp: Vector2) -> bool:
	for c in [_top, _bar, _catalog]:
		var ctl := c as Control
		if ctl != null and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(sp):
			return true
	return false


# ---------- Рамка выбранного ----------

func _update_mark() -> void:
	if _mark == null:
		return
	var it := selected()
	if it.is_empty():
		_mark.visible = false
		return
	var id := String(it["id"])
	var s := float(it["s"])
	var sz := size_of(id) * s
	var bad := problems(it) != ""
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	_box_lines(im, Vector3(sz.x, sz.y, sz.z), COL_BAD if bad else COL_OK)
	if DungeonProps.SOLID.has(id):
		var k := DungeonProps.COLLIDE_K
		_box_lines(im, Vector3(sz.x * k, maxf(sz.y, 1.2), sz.z * k), Color(1.0, 0.45, 0.35, 0.8))
	# Стрелка «перед» модели (+Z) — куда смотрит фасад
	var f := sz.z * 0.5 + 0.7
	var green := Color(0.4, 1.0, 0.5)
	for pair in [[Vector3(0, 0.15, sz.z * 0.5), Vector3(0, 0.15, f)], [Vector3(0, 0.15, f), Vector3(-0.3, 0.15, f - 0.35)],
			[Vector3(0, 0.15, f), Vector3(0.3, 0.15, f - 0.35)]]:
		for v in pair:
			im.surface_set_color(green)
			im.surface_add_vertex(v)
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	im.surface_set_material(0, mat)
	_mark.mesh = im
	_mark.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(it["yaw"]))), pos_of(it))
	_mark.visible = true


static func _box_lines(im: ImmediateMesh, sz: Vector3, c: Color) -> void:
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var pts: Array[Vector3] = []
	for y in [0.0, sz.y]:
		pts.append_array([Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	var edges := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	for e in edges:
		for k in 2:
			im.surface_set_color(c)
			im.surface_add_vertex(pts[int(e[k])])


# ---------- Интерфейс ----------

func _build_ui() -> void:
	var hud: HUD = main.hud
	# Сверху справа — действия
	_top = HBoxContainer.new()
	_top.name = "EditorTop"
	_top.add_theme_constant_override("separation", int(UiScale.px(6)))
	_btn(_top, "ed_catalog", "Каталог", func() -> void: toggle_catalog(), 120.0)
	_btn(_top, "ed_undo", "Отменить", func() -> void: undo(), 120.0)
	_btn(_top, "ed_save", "Сохранить", func() -> void:
		if save():
			_msg("Раскладка сохранена (%d шт.)" % items.size()), 120.0)
	_btn(_top, "ed_share", "Отправить", func() -> void:
		save()
		_msg(DungeonEditor.share_file(), 6.0), 120.0)
	_btn(_top, "ed_exit", "Выйти", func() -> void: exit_editor(), 100.0)
	_add_ui(hud, _top)
	_hint = Label.new()
	_hint.name = "EditorHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", int(UiScale.px(4)))
	_hint.text = ("Режим расстановки · джойстик — двигать камеру, палец — повернуть, щипок — ближе / дальше\n"
		+ "касание объекта — выбрать, выбранный тяните пальцем по полу, пустое место — снять выбор")
	hud.add_child(_hint)
	_build_bar(hud)
	_build_catalog(hud)
	_layout_ui()


func _add_ui(hud: HUD, c: Control) -> void:
	c.set_meta("editor", true)
	hud.add_child(c)
	hud.add_blocker(c)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.88)
	sb.set_corner_radius_all(int(UiScale.px(12)))
	sb.set_content_margin_all(UiScale.px(8))
	sb.border_color = Color(0.85, 0.7, 0.35, 0.6)
	sb.set_border_width_all(int(UiScale.px(1)))
	p.add_theme_stylebox_override("panel", sb)
	return p


## Полоса выбранного объекта (снизу по центру).
func _build_bar(hud: HUD) -> void:
	_bar = _panel()
	_bar.name = "EditorBar"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiScale.px(4)))
	_bar.add_child(box)
	var r1 := _row(box)
	_bar_name = Label.new()
	_bar_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_name.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_BODY))
	_bar_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bar_name.clip_text = true
	r1.add_child(_bar_name)
	_btn(r1, "ed_copy", "Копия", func() -> void: copy_selected(), 100.0)
	_btn(r1, "ed_delete", "Убрать", func() -> void: delete_selected(), 100.0)
	var r2 := _row(box)
	_slider(r2, SLIDERS[0])
	_slider(r2, SLIDERS[1])
	var r3 := _row(box)
	_slider(r3, SLIDERS[2])
	var arrows := HBoxContainer.new()
	arrows.add_theme_constant_override("separation", int(UiScale.px(4)))
	arrows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_child(arrows)
	var tip := Label.new()
	tip.text = "Точно:"
	tip.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	arrows.add_child(tip)
	_hold(arrows, "ed_nudge_left", "◀", func() -> void: nudge(0.0, -1.0))
	_hold(arrows, "ed_nudge_fwd", "▲", func() -> void: nudge(1.0, 0.0))
	_hold(arrows, "ed_nudge_back", "▼", func() -> void: nudge(-1.0, 0.0))
	_hold(arrows, "ed_nudge_right", "▶", func() -> void: nudge(0.0, 1.0))
	_add_ui(hud, _bar)


func _slider(row: HBoxContainer, spec: Array) -> void:
	var key := String(spec[0])
	var l := Label.new()
	l.text = String(spec[1])
	l.custom_minimum_size = Vector2(UiScale.px(70), 0)
	l.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = float(spec[2])
	s.max_value = float(spec[3])
	s.step = float(spec[4])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(UiScale.px(170), UiScale.px(36))
	s.focus_mode = Control.FOCUS_NONE
	s.drag_started.connect(func() -> void: _push_undo())
	s.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			set_value(key, v))
	row.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(UiScale.px(56), 0)
	val.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	row.add_child(val)
	sliders[key] = s
	s.set_meta("value_label", val)


## Каталог (снизу): вкладки разделов и карточки с картинками.
func _build_catalog(hud: HUD) -> void:
	_catalog = _panel()
	_catalog.name = "EditorCatalog"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiScale.px(6)))
	_catalog.add_child(box)
	var tabs := _row(box)
	for gi in CATALOG.size():
		var g := gi
		var b := _make(tabs, "ed_cat_tab_%d" % g, String((CATALOG[g] as Array)[0]), 90.0)
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
		b.pressed.connect(func() -> void: show_group(g))
	_btn(tabs, "ed_cat_close", "×", func() -> void: toggle_catalog(), 44.0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, UiScale.px(150))
	box.add_child(sc)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(UiScale.px(6)))
	sc.add_child(_cards)
	_add_ui(hud, _catalog)
	show_group(cat_group)


func toggle_catalog() -> void:
	catalog_open = not catalog_open
	if catalog_open:
		show_group(cat_group)


func show_group(g: int) -> void:
	cat_group = clampi(g, 0, CATALOG.size() - 1)
	for gi in CATALOG.size():
		(buttons["ed_cat_tab_%d" % gi] as Button).button_pressed = gi == cat_group
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for idv in (CATALOG[cat_group] as Array)[1]:
		var id := String(idv)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(UiScale.px(118), UiScale.px(140))
		b.text = title(id)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TINY))
		b.icon = thumb(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", int(UiScale.px(84)))
		b.pressed.connect(func() -> void:
			catalog_open = false
			add(id))
		_cards.add_child(b)
		buttons["ed_cat_" + id] = b


## Раскладка панелей: сверху справа — действия, снизу по центру — полоса или каталог (джойстик слева свободен).
func _layout_ui() -> void:
	var hud: HUD = main.hud
	var view := hud.get_viewport().get_visible_rect().size if hud.get_viewport() != null else Vector2(1280, 720)
	var m := UiScale.px(8)
	_top.reset_size()
	_top.position = Vector2(view.x - _top.size.x - m, m)
	_hint.position = Vector2(m, m + UiScale.px(56))
	var left := view.x * 0.28
	var w := minf(UiScale.px(BAR_W), view.x - left - m)
	_bar.size = Vector2(w, 0)
	_bar.reset_size()
	_bar.size.x = maxf(_bar.size.x, w)
	_bar.position = Vector2(view.x - _bar.size.x - m, view.y - _bar.size.y - m)
	var cw := view.x - 2.0 * m
	_catalog.size = Vector2(cw, 0)
	_catalog.reset_size()
	_catalog.size.x = cw
	_catalog.position = Vector2(m, view.y - _catalog.size.y - m)


## Название, замечания и ползунки по выбранному (sliders — и значения ползунков).
func _sync_bar(slide := true) -> void:
	if _bar_name == null:
		return
	var it := selected()
	if it.is_empty():
		return
	var id := String(it["id"])
	var pr := problems(it)
	_bar_name.text = "%s%s" % [title(id), " — " + pr if pr != "" else ""]
	_bar_name.add_theme_color_override("font_color", COL_BAD if pr != "" else Color(1, 1, 1))
	var vals := {"rot": fposmod(float(it["yaw"]), 360.0), "scale": float(it["s"]), "height": float(it["dy"])}
	_syncing = true
	for k in sliders:
		var s: HSlider = sliders[k]
		if slide:
			s.value = float(vals[k])
		var l: Label = s.get_meta("value_label")
		l.text = "%d°" % roundi(float(vals[k])) if k == "rot" else ("×%.2f" % float(vals[k]) if k == "scale" else "%+.2f м" % float(vals[k]))
	_syncing = false
	_update_mark()


func _row(box: VBoxContainer) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", int(UiScale.px(6)))
	box.add_child(r)
	return r


func _make(parent: Control, key: String, text: String, min_w := 60.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(min_w), UiScale.px(42))
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_BODY))
	parent.add_child(b)
	buttons[key] = b
	return b


func _btn(parent: Control, key: String, text: String, cb: Callable, min_w := 60.0) -> void:
	_make(parent, key, text, min_w).pressed.connect(cb)


## Кнопка с повтором при удержании; снимок для «Отменить» — один на нажатие.
func _hold(parent: Control, key: String, text: String, cb: Callable) -> void:
	var b := _make(parent, key, text, 46.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.button_down.connect(func() -> void:
		_push_undo()
		cb.call()
		_hold_fn = cb
		_hold_t = -HOLD_DELAY)
	b.button_up.connect(func() -> void: _hold_fn = Callable())


## Нажать кнопку из кода (тесты): у кнопок с удержанием — один шаг.
func press(key: String) -> void:
	var b: Button = buttons.get(key)
	if b == null:
		return
	if b.button_down.get_connections().size() > 0:
		b.button_down.emit()
		b.button_up.emit()
	else:
		b.pressed.emit()


func _msg(t: String, sec := 3.0) -> void:
	var hud: HUD = main.get("hud")
	if hud != null:
		hud.show_message(t, sec)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
