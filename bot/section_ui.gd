extends BotSection
## Раздел «Интерфейс»: при каждом размере интерфейса («Мелкий», «Средний», «Крупный» — без записи в настройки,
## в конце — как был) открыть и закрыть окна: меню HUD (герой, питомцы, сумка, задания, настройки — касанием значка),
## вкладки настроек, админ-панели, окна героя (древо профессии), существа, диалоги жителей, лавку, склад, кузницу,
## выбор профессии — окно открыто и помещается в экран (как tests/test_ui_scale.gd), ошибки скриптов — в логе раздела.
## Быстрый проход — основные окна, полный — все.

const SIZES := [UiScale.SMALL, UiScale.MEDIUM, UiScale.LARGE]
const MENU := [["hero_window", "Герой (меню)"], ["pets_window", "Питомцы (меню)"], ["bag_window", "Сумка (меню)"],
	["quest_window", "Задания (меню)"], ["settings_window", "Настройки (меню)"]]
const JOB := "assassin"

var _scale0 := UiScale.MEDIUM


func id() -> String:
	return "ui"


func _build() -> void:
	do("Интерфейс: герой, питомец", _setup)
	for l in SIZES:
		var lvl := int(l)
		var sz := UiScale.level_name(lvl)
		do("Размер «%s»" % sz, _set_size.bind(lvl))
		wait(0.3)
		for e in _windows():
			var w: Array = e
			var what := "%s · %s" % [String(w[1]), sz]
			do("Открыть: %s" % what, Callable(self, String(w[0])).bindv(w.slice(2)))
			wait(0.15)
			do("Окно: %s" % what, _check.bind(what))
	do("Интерфейс: размер как был", _restore)


## Окна: [метод, что за окно, аргументы метода…].
func _windows() -> Array:
	var res: Array = []
	for e in MENU:
		res.append(["_w_menu", String(e[1]), String(e[0])])
	for t in SettingsMenu.TABS:
		res.append(["_w_settings", "Настройки: %s" % String(t[1]), String(t[0])])
	if quick:
		res.append(["_w_admin", "Админ-панель: Тест-бот", "bot"])
		res.append(["_w_dialog", "Диалог: Учитель Кирк", "kirk"])
		res.append(["_w_shop", "Лавка Кирка", "kirk"])
		return res
	for t in AdminPanel.TABS:
		res.append(["_w_admin", "Админ-панель: %s" % String(t[1]), String(t[0])])
	for t in HeroSkills.tabs_for(JOB):
		res.append(["_w_hero", "Окно героя: %s" % String(t[1]), String(t[0])])
	res.append(["_w_creature", "Существо: характеристики", "stats"])
	res.append(["_w_creature", "Существо: умения", "skills"])
	res.append(["_w_job", "Выбор профессии"])
	var n := npcs()
	if n != null:
		for k in n.nodes:
			var nid := String(k)
			if NpcData.has_dialog(nid):
				res.append(["_w_dialog", "Диалог: %s" % NpcData.npc_name(nid), nid])
	for who in ["merchant", "weaponsmith", "armorer", "jeweler", "kirk", "rare_merchant"]:
		res.append(["_w_shop", "Лавка: %s" % NpcData.npc_name(String(who)), String(who)])
	res.append(["_w_storage", "Склад"])
	res.append(["_w_forge", "Кузница"])
	return res


func _setup() -> void:
	_scale0 = UiScale.level()
	hero(JOB, 30)
	bot.learn_all()
	no_pets()
	bot.add_pet("wolf", 15)
	fresh_bag(1000)
	Game.inventory.add("potion_hp_r1", 3)
	Game.inventory.add(ItemData.cube_id("attack", 1), 1)


func _set_size(lvl: int) -> void:
	close_window()
	UiScale.set_level(lvl, false)
	var h := hud()
	if h != null:
		h.apply_ui_scale()


func _restore() -> void:
	close_window()
	UiScale.set_level(_scale0, false)
	var h := hud()
	if h != null:
		h.apply_ui_scale()


func _check(what: String) -> void:
	window_fits(what)
	if UiScale.level() == UiScale.MEDIUM:
		shot("UI %s" % what)
	close_window()


# ---------- Как открыть ----------

## Значок меню HUD — касание (как пальцем).
func _w_menu(action_id: String) -> void:
	close_window()
	var h := hud()
	var b: Variant = h.menu_buttons().get(action_id) if h != null else null
	if not check(b is Button, "значок меню «%s»" % action_id):
		return
	(b as Button).pressed.emit()


func _w_settings(tab: String) -> void:
	close_window()
	SettingsMenu.open(hud(), tab)


func _w_admin(tab: String) -> void:
	close_window()
	AdminPanel.open(bot.main, tab)


func _w_hero(tab: String) -> void:
	close_window()
	bot.main.get("hero_window").call("open", tab)


func _w_creature(tab: String) -> void:
	close_window()
	pets().open_creature(0, tab)


func _w_job() -> void:
	close_window()
	bot.main.get("job_window").call("open", "")


func _w_dialog(npc_id: String) -> void:
	close_window()
	if go_near(npc_id):
		npcs().open_dialog(npc_id)


func _w_shop(npc_id: String) -> void:
	close_window()
	if go_near(npc_id):
		economy().open_shop(npc_id)


func _w_storage() -> void:
	close_window()
	if go_near(Economy.STORAGE_NPC):
		economy().open_storage()


func _w_forge() -> void:
	close_window()
	if go_near(Enchant.SMITH_NPC):
		economy().open_forge()
		economy().window.put_forge(Game.weapon, "weapon")
