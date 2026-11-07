class_name BotSection
extends RefCounted
## Раздел игрового сценария тест-бота (этап 4): «Бой и умения», «Питомцы», «Приручение», «Торговля», «Склад»,
## «Задания», «Экипировка», «Мир», «Интерфейс», «Подземелье». Раздел ставит шаги в очередь бота (TestBot: do / wait / wait_until /
## tick, проверки check, снимки shot) — сам по себе, с любого состояния: в начале готовит героя (профессия, уровень,
## сумка, золото, питомцы), состояние между разделами возвращает бот (TestBot._reset_between_sections). quick — короткий
## проход (режим «Быстрый»: меньше профессий, видов питомцев, мест), иначе полный.
## Новый раздел: файл bot/section_<id>.gd (extends BotSection: id(), title(), _build()), строка в SECTIONS (оценка
## времени быстрого и полного прохода, с — для лимита режима «По разделам» и подписи на вкладке «Тест-бот»).
## Помощники для разделов — ниже (герой, питомец, звери, NPC, окна, кнопки HUD).

## Разделы по порядку: id, название, файл, оценка времени быстрого и полного прохода, с.
const SECTIONS := [
	{"id": "combat", "name": "Бой и умения", "script": "res://bot/section_combat.gd", "quick": 110, "full": 210},
	{"id": "pets", "name": "Питомцы", "script": "res://bot/section_pets.gd", "quick": 30, "full": 60},
	{"id": "taming", "name": "Приручение", "script": "res://bot/section_taming.gd", "quick": 10, "full": 20},
	{"id": "trade", "name": "Торговля", "script": "res://bot/section_trade.gd", "quick": 6, "full": 10},
	{"id": "storage", "name": "Склад", "script": "res://bot/section_storage.gd", "quick": 5, "full": 5},
	{"id": "quests", "name": "Задания", "script": "res://bot/section_quests.gd", "quick": 15, "full": 20},
	{"id": "npc_quests", "name": "Задания жителей", "script": "res://bot/section_npc_quests.gd", "quick": 10, "full": 12},
	{"id": "equipment", "name": "Экипировка", "script": "res://bot/section_equipment.gd", "quick": 8, "full": 12},
	{"id": "bags", "name": "Торба и пояс", "script": "res://bot/section_bags.gd", "quick": 5, "full": 6},
	{"id": "world", "name": "Мир", "script": "res://bot/section_world.gd", "quick": 45, "full": 205},
	{"id": "ui", "name": "Интерфейс", "script": "res://bot/section_ui.gd", "quick": 15, "full": 40},
	# Последним: переходит через портал в подземелье и обратно (разделы выше — на острове)
	{"id": "dungeon", "name": "Подземелье", "script": "res://bot/section_dungeon.gd", "quick": 70, "full": 180},
]
## Место для боя (поле восточнее города, вне безопасных зон; как сцена «Бой» режима «Производительность»).
const ARENA := Vector2(34, 24)
## Дальше этого от NPC окно торговли и диалог закрываются — подходим ближе.
const NEAR_NPC := 2.2

var bot: TestBot
var quick := false


static func info(sec_id: String) -> Dictionary:
	for e in SECTIONS:
		if String((e as Dictionary)["id"]) == sec_id:
			return e
	return {}


static func ids() -> Array:
	var res: Array = []
	for e in SECTIONS:
		res.append(String((e as Dictionary)["id"]))
	return res


static func section_name(sec_id: String) -> String:
	return String(info(sec_id).get("name", sec_id))


## Оценка времени раздела, с.
static func estimate(sec_id: String, is_quick: bool) -> float:
	return float(info(sec_id).get("quick" if is_quick else "full", 30))


## Раздел по id (null — нет такого).
static func create(sec_id: String) -> BotSection:
	var path := String(info(sec_id).get("script", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scr := load(path) as GDScript
	if scr == null:
		return null
	return scr.new() as BotSection


func id() -> String:
	return "section"


func title() -> String:
	return section_name(id())


## Поставить шаги раздела в очередь бота b (первый — начало раздела).
func build(b: TestBot, is_quick: bool) -> void:
	bot = b
	quick = is_quick
	b.section(id(), title())
	_build()


func _build() -> void:
	pass


# ---------- Очередь (короткие имена) ----------

func do(t: String, fn: Callable) -> void:
	bot.do(t, fn)


func wait(sec: float) -> void:
	bot.wait(sec)


func until(t: String, cond: Callable, timeout: float) -> void:
	bot.wait_until(t, cond, timeout)


func check(ok: bool, text: String) -> bool:
	return bot.check(ok, text)


func note(text: String) -> void:
	bot.note(text)


func shot(label: String) -> void:
	bot.shot(label)


# ---------- Мир и герой ----------

func main() -> Node:
	return bot.main


func player() -> Player:
	return bot.player()


func hud() -> HUD:
	if bot.main == null or not is_instance_valid(bot.main):
		return null
	return bot.main.get("hud") as HUD


func economy() -> Economy:
	return bot.main.get("economy") as Economy


func npcs() -> Npcs:
	return bot.main.get("npcs") as Npcs


func quests() -> Quests:
	return bot.main.get("quests") as Quests


func pets() -> PetManager:
	return bot.main.get("pets") as PetManager


## Последнее сообщение HUD (причина отказа и т. п.).
func last_msg() -> String:
	var h := hud()
	if h == null or h._msg_label == null:
		return ""
	return h._msg_label.text


## Герой: профессия job (если другая — как админ-панель), уровень lvl, HP и MP полные.
func hero(job: String, lvl: int) -> void:
	if Game.class_id != job:
		bot.set_job(job)
	bot.set_level(lvl)
	refill()


func refill() -> void:
	var p := player()
	if p == null:
		return
	p.recalc_stats()
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.stats_changed.emit()


## Сумка пуста (надетое остаётся), золото — gold.
func fresh_bag(gold: int) -> void:
	AdminPanel.clear_bag(bot.main)
	Game.gold = gold
	Game.changed.emit()


## Отпустить всех питомцев.
func no_pets() -> void:
	AdminPanel.clear_pets(bot.main)


## Призванный живой питомец или null.
func pet() -> Pet:
	var pm := pets()
	if pm == null or not is_instance_valid(pm.active_pet):
		return null
	var pt := pm.active_pet as Pet
	if pt == null or pt.is_down:
		return null
	return pt


## Точка на земле (y по рельефу).
func ground(x: float, z: float) -> Vector3:
	var w := IslandWorld.current
	if w == null:
		return Vector3(x, 0.0, z)
	return w.ground(x, z)


## Перенос к месту для боя (ARENA): свободная ровная точка.
func to_arena() -> Vector3:
	bot.reset_camera()
	return bot.teleport(ARENA, "Поле для боя")


## Живой ли зверь (без типа: освобождённый узел).
static func alive(m: Variant) -> bool:
	return is_instance_valid(m) and not (m as Mob).is_dead


## Убить зверя как обычное убийство героем (опыт, добыча, задания, приручение).
func kill(m: Variant) -> void:
	if not alive(m):
		return
	var mob := m as Mob
	mob.hp = 1
	mob.take_damage(maxi(999999, mob.max_hp * 100), player())


## Зверь вида type_id уровня lvl в dist м перед камерой (side — вбок), не возрождается, убирается между разделами.
func spawn_ahead(type_id: String, lvl: int, dist: float, side: float = 0.0) -> Mob:
	return bot.spawn(type_id, lvl, bot.ahead(dist, side))


## Узел NPC id (торговец — Economy.merchant) или null.
func npc_node(npc_id: String) -> Node3D:
	if npc_id == "merchant":
		var eco := economy()
		if eco != null and is_instance_valid(eco.merchant):
			return eco.merchant as Node3D
	var n := npcs()
	if n == null:
		return null
	return n.npc(npc_id)


## Встать рядом с NPC (в dist м, на проходимой земле), камера по умолчанию. false — NPC нет.
func go_near(npc_id: String, dist: float = NEAR_NPC) -> bool:
	var n := npc_node(npc_id)
	var p := player()
	if n == null or p == null:
		check(false, "NPC «%s» есть в мире" % NpcData.npc_name(npc_id))
		return false
	var c := n.global_position
	var w := IslandWorld.current
	var pos := c + Vector3(0, 0, dist)
	if w != null:
		# Сторона к центру острова, потом по кругу — первая проходимая
		var base := Vector3(-c.x, 0.0, -c.z)
		base = base.normalized() if base.length() > 0.1 else Vector3(0, 0, 1)
		for k in 12:
			var d := base.rotated(Vector3.UP, TAU * float(k) / 12.0) * dist
			if w.is_walkable(c.x + d.x, c.z + d.z):
				pos = w.ground(c.x + d.x, c.z + d.z)
				break
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var pt := pet()
	if pt != null and w != null:
		pt.global_position = w.ground(pos.x + 1.2, pos.z + 1.2, 0.2)
	bot.reset_camera()
	return true


## Нажать круглую кнопку или пункт меню HUD (действие id) — как касание.
func press(action_id: String) -> void:
	var h := hud()
	if h != null:
		h.action.emit(action_id)


## Нажать кнопку диалога NPC (Npcs.buttons) — false, если её нет.
func press_dialog(key: String) -> bool:
	var n := npcs()
	if n == null or not n.buttons.has(key) or not is_instance_valid(n.buttons[key]):
		check(false, "в диалоге есть кнопка «%s» (%s)" % [key, last_msg()])
		return false
	(n.buttons[key] as Button).pressed.emit()
	return true


## Открытое окно помещается в экран (как tests/test_ui_scale.gd). what — что за окно.
func window_fits(what: String) -> bool:
	var h := hud()
	if not check(h != null and h.is_window_open(), "%s: окно открыто" % what):
		return false
	var view: Vector2 = h._view
	var r := h.window_rect()
	var need: Vector2 = h._window.get_combined_minimum_size()
	var fits := r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= view.x + 0.5 and r.end.y <= view.y + 0.5
	return check(fits and need.x <= view.x + 0.5 and need.y <= view.y + 0.5, "%s помещается в экран %s (окно %s, нужно %s)"
		% [what, view, r.size, need])


func close_window() -> void:
	var h := hud()
	if h != null:
		h.close_window()
