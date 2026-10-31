class_name PetManager
extends Node
## Питомцы: призыв из коллекции Game.pets, команды «Атакуй» / «За мной», опыт за убийства,
## окно питомцев (формирование существ из карт с душой, подробнее — окно существа, призвать, отозвать,
## воскресить свитком, отпустить).
## Призванный питомец всегда соответствует Game.active_pet: сверка идёт каждый кадр,
## поэтому после загрузки сохранения или отпускания другого питомца узел пересоздаётся сам.

## Питомец вида species призван (слушают задания — Quests).
signal summoned(species: String)

## Окно питомцев — для «Среднего» размера интерфейса (умножается на UiScale.k(); было 1040×600).
const WINDOW_SIZE := Vector2(900, 540)
## Радиус поиска цели для команды «Атакуй», если у игрока нет цели.
const ATTACK_RANGE := 12.0

var main: Node
## Призванный питомец (узел в мире) или null. Контракт узла (используют HUD и другие модули):
## поля pet_name, level, hp, max_hp, is_down (погиб/скрыт), метод heal(amount: int), сигнал stats_changed.
var active_pet: Pet = null
## Кнопки открытого окна питомцев: "form_<id карты>", "info_<i>", "summon_<i>", "recall_<i>", "revive_<i>",
## "release_<i>".
var window_buttons: Dictionary = {}
## Окно существа (характеристики и умения питомца).
var creature: CreatureWindow = null

var _window_body: VBoxContainer = null
## Индекс питомца, ждущего подтверждения «Отпустить» (второе нажатие), -1: никого.
var _release_confirm := -1


func setup(m: Node) -> void:
	main = m
	creature = CreatureWindow.new()
	creature.name = "CreatureWindow"
	add_child(creature)
	creature.setup(m, self)
	_sync()


func _process(_delta: float) -> void:
	if main != null:
		_sync()


## Обрабатывает действия: "pet_attack", "pet_follow", "pets_window", "creature_window". true, если действие своё.
func handle_action(id: String) -> bool:
	match id:
		"pet_attack":
			_cmd_attack()
			return true
		"pet_follow":
			_cmd_follow()
			return true
		"pets_window":
			_release_confirm = -1
			open_window()
			return true
		"creature_window":
			open_creature(Game.active_pet if Game.active_pet >= 0 else 0)
			return true
	return false


## Открыть окно существа для питомца i (вкладка which: "stats" | "skills" | "" — прежняя). true — открыто.
func open_creature(i: int, which: String = "") -> bool:
	if i < 0 or i >= Game.pets.size():
		_msg("Питомцев пока нет")
		return false
	_release_confirm = -1
	return creature.open(i, which)


## Зверь убит (игроком или питомцем): опыт призванному живому питомцу.
func on_mob_killed(mob: Mob) -> void:
	if mob == null or not _has_pet():
		return
	# Доля питомца × разница уровней зверя и питомца × множитель админ-панели (Combat.xp_for, Game.xp_mult)
	active_pet.gain_xp(Combat.xp_for(roundi(float(mob.xp_reward) * PetData.XP_SHARE), mob.level, active_pet.level))


## Призвать питомца из коллекции. true, если призван.
func summon(i: int) -> bool:
	if i < 0 or i >= Game.pets.size():
		return false
	var rec: Dictionary = Game.pets[i]
	if bool(rec.get("dead", false)):
		_msg("Питомец «%s» погиб — сначала воскресите его" % String(rec.get("name", "")))
		return false
	Game.active_pet = i
	_sync()
	if _has_pet():
		_msg("Питомец «%s» призван" % active_pet.pet_name)
	Game.changed.emit()
	summoned.emit(String(rec.get("species", "")))
	return true


## Отозвать призванного питомца.
func recall() -> void:
	var nm: String = active_pet.pet_name if _has_pet() else ""
	Game.active_pet = -1
	_sync()
	if nm != "":
		_msg("Питомец «%s» отозван" % nm)
	Game.changed.emit()


# ---------- Команды ----------

func _cmd_attack() -> void:
	if not _has_pet():
		_msg("Нет призванного питомца")
		return
	var pl: Node3D = main.player
	var t: Mob = null
	var ct = main.player.current_target
	if is_instance_valid(ct) and ct is Mob and not ct.is_dead:
		t = ct as Mob
	if t == null:
		t = Util.nearest(pl, "mobs", ATTACK_RANGE) as Mob
	if t == null:
		_msg("Рядом нет цели для питомца")
		return
	active_pet.command_attack(t)
	_msg("«%s» атакует: %s" % [active_pet.pet_name, t.mob_name])


func _cmd_follow() -> void:
	if not _has_pet():
		_msg("Нет призванного питомца")
		return
	if active_pet.mode == "follow":
		active_pet.set_mode("assist")
		_msg("«%s» снова помогает в бою" % active_pet.pet_name)
	else:
		active_pet.set_mode("follow")
		_msg("«%s» следует за вами и не вступает в бой" % active_pet.pet_name)


# ---------- Призванный питомец ----------

func _has_pet() -> bool:
	return is_instance_valid(active_pet) and not active_pet.is_down


## Приводит узел питомца в мире в соответствие с Game.active_pet.
func _sync() -> void:
	var want: Dictionary = {}
	var i: int = Game.active_pet
	if i >= 0 and i < Game.pets.size():
		var rec: Dictionary = Game.pets[i]
		if bool(rec.get("dead", false)):
			Game.active_pet = -1
		else:
			want = rec
	elif i != -1:
		Game.active_pet = -1
	if want.is_empty():
		if is_instance_valid(active_pet):
			_despawn()
		else:
			active_pet = null
	elif not _has_pet() or not is_same(active_pet.record, want):
		_spawn(want)


func _spawn(rec: Dictionary) -> void:
	_despawn()
	var pl: Node3D = main.player
	var p := Pet.new()
	p.setup(main.player, rec)
	p.position = pl.global_position + Vector3(1.5, 0.2, 1.5)
	main.add_child(p)
	p.stats_changed.connect(_on_pet_stats)
	p.died.connect(_on_pet_died.bind(p))
	active_pet = p
	main.hud.update_pet(p)


func _despawn() -> void:
	if is_instance_valid(active_pet):
		# Сразу «скрыт»: звери бросают его как цель, не дожидаясь удаления узла
		active_pet.is_down = true
		if active_pet.is_in_group("pets"):
			active_pet.remove_from_group("pets")
		active_pet.queue_free()
	active_pet = null
	if main != null and main.get("hud") != null:
		main.hud.update_pet(null)


func _on_pet_stats() -> void:
	if _has_pet():
		main.hud.update_pet(active_pet)
	else:
		main.hud.update_pet(null)


func _on_pet_died(p: Pet) -> void:
	if p != active_pet:
		return
	Game.active_pet = -1
	_despawn()
	Game.changed.emit()
	_refresh_window()


# ---------- Окно питомцев ----------

## Открывает (или перестраивает) окно питомцев.
func open_window() -> void:
	window_buttons.clear()
	var body: VBoxContainer = main.hud.create_window("Питомцы", WINDOW_SIZE)
	_window_body = body
	var head := Label.new()
	head.text = "Коллекция: %d/%d    Свитков воскрешения: %d" % [
		Game.pets.size(), Game.MAX_PETS, Game.inventory.count("revive_scroll")]
	head.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	body.add_child(head)
	_add_forming(body)
	if Game.pets.is_empty():
		var hint := Label.new()
		hint.text = "Питомцев пока нет. Возьмите карту существа нужного вида (базовые продаёт Учитель Кирк в центре города, другие " \
			+ "выпадают из зверей), нажмите «Приручить» рядом со зверем и победите его. Из карты с душой сформируйте существо."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(UiScale.px(WINDOW_SIZE.x - 60.0), 0)
		body.add_child(hint)
		return
	for i in Game.pets.size():
		_add_row(body, i)


## Карты с душой в сумке (id, по порядку сортировки сумки).
static func soul_cards() -> Array:
	var res: Array = []
	for id in Inventory.sorted_ids(Game.inventory.ids()):
		if ItemData.is_soul_card(String(id)):
			res.append(String(id))
	return res


## Блок «Формирование»: карты с душой из сумки, у каждой — «Сформировать».
func _add_forming(body: VBoxContainer) -> void:
	var cards := soul_cards()
	var title := Label.new()
	title.text = "Формирование" if not cards.is_empty() else "Формирование: карт с душой в сумке нет"
	title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.8) if not cards.is_empty() else Color(0.7, 0.72, 0.8))
	body.add_child(title)
	for c in cards:
		var id := String(c)
		var sp := ItemData.card_species(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
		body.add_child(row)
		var ic := ItemIcon.make(id, UiScale.px(36))
		row.add_child(ic)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
		var n: int = Game.inventory.count(id)
		info.text = "%s%s → «%s» (%s, ур. 1)" % [ItemData.item_name(id), " ×%d" % n if n > 1 else "",
			PetData.stage_name(sp, 1), PetData.role_name(sp)]
		info.modulate = ItemData.frame_color(id).lerp(Color.WHITE, 0.45)
		row.add_child(info)
		_add_button(row, "form_" + id, "Сформировать", _on_form.bind(id))


func _add_row(body: VBoxContainer, i: int) -> void:
	var rec: Dictionary = Game.pets[i]
	var sp := String(rec.get("species", "boar"))
	var lvl := int(rec.get("level", 1))
	var dead := bool(rec.get("dead", false))
	PetSkills.ensure_record(rec)
	var st := PetData.stats_for(sp, lvl, rec["skills"], rec["toggles"])
	var mhp := int(st["max_hp"])
	var cur := int(rec.get("hp", -1))
	if cur < 0 or cur > mhp:
		cur = mhp
	var active := i == Game.active_pet and not dead

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	body.add_child(row)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	var status: String = "погиб" if dead else "HP %d/%d" % [cur, mhp]
	info.text = "%s%s\n%s · %s, ур. %d, %s, JP %d" % [
		String(rec.get("name", "Питомец")), "  [призван]" if active else "",
		PetData.role_name(sp), MobData.rarity_name(sp), lvl, status, int(rec.get("jp", 0))]
	if dead:
		info.modulate = Color(1.0, 0.55, 0.5)
	elif active:
		info.modulate = Color(0.6, 0.95, 1.0)
	row.add_child(info)

	_add_button(row, "info_%d" % i, "Подробнее", _on_info.bind(i))
	if dead:
		_add_button(row, "revive_%d" % i, "Воскресить", _on_revive.bind(i))
	elif active:
		_add_button(row, "recall_%d" % i, "Отозвать", _on_recall.bind(i))
	else:
		_add_button(row, "summon_%d" % i, "Призвать", _on_summon.bind(i))
	var rel_text: String = "Точно отпустить?" if _release_confirm == i else "Отпустить"
	_add_button(row, "release_%d" % i, rel_text, _on_release.bind(i))


func _add_button(row: HBoxContainer, key: String, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiScale.button_h())
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	row.add_child(b)
	window_buttons[key] = b


func _on_form(card_id: String) -> void:
	_release_confirm = -1
	if main.get("taming") != null:
		main.taming.form(card_id)
	_refresh_window()


func _on_info(i: int) -> void:
	open_creature(i, "stats")


func _on_summon(i: int) -> void:
	_release_confirm = -1
	summon(i)
	_refresh_window()


func _on_recall(_i: int) -> void:
	_release_confirm = -1
	recall()
	_refresh_window()


func _on_revive(i: int) -> void:
	_release_confirm = -1
	if i < 0 or i >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[i]
	if not bool(rec.get("dead", false)):
		_refresh_window()
		return
	if not Game.inventory.remove("revive_scroll"):
		_msg("Нужен «%s» (продаётся у торговца)" % ItemData.item_name("revive_scroll"))
		_refresh_window()
		return
	PetSkills.ensure_record(rec)
	var st := PetData.stats_for(String(rec.get("species", "boar")), int(rec.get("level", 1)), rec["skills"], rec["toggles"])
	rec["dead"] = false
	rec["hp"] = maxi(1, int(float(st["max_hp"]) * 0.5))
	_msg("Питомец «%s» воскрешён" % String(rec.get("name", "")))
	Game.changed.emit()
	_refresh_window()


## Свиток воскрешения из сумки («Использовать»): воскрешает призванного погибшего питомца, иначе первого
## погибшего в коллекции. true — воскрешён.
func revive_any() -> bool:
	var idx := -1
	if Game.active_pet >= 0 and Game.active_pet < Game.pets.size() \
			and bool(Game.pets[Game.active_pet].get("dead", false)):
		idx = Game.active_pet
	else:
		for i in Game.pets.size():
			if bool(Game.pets[i].get("dead", false)):
				idx = i
				break
	if idx < 0:
		_msg("Нет погибших питомцев")
		return false
	_on_revive(idx)
	return not bool(Game.pets[idx].get("dead", false))


func _on_release(i: int) -> void:
	if i < 0 or i >= Game.pets.size():
		return
	if _release_confirm != i:
		_release_confirm = i
		_msg("Нажмите ещё раз, чтобы отпустить питомца навсегда")
		_refresh_window()
		return
	_release_confirm = -1
	var nm := String(Game.pets[i].get("name", ""))
	Game.remove_pet(i)
	_sync()
	_msg("Питомец «%s» отпущен на волю" % nm)
	_refresh_window()


## Перестраивает окно питомцев, если оно открыто.
func _refresh_window() -> void:
	if _window_is_ours():
		open_window()


func _window_is_ours() -> bool:
	if not is_instance_valid(_window_body):
		return false
	var n: Node = _window_body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


func _msg(t: String) -> void:
	main.hud.show_message(t)
