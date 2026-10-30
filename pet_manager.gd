class_name PetManager
extends Node
## Питомцы: призыв из коллекции Game.pets, команды «Атакуй» / «За мной», опыт за убийства,
## окно питомцев (призвать, отозвать, воскресить свитком, отпустить).
## Призванный питомец всегда соответствует Game.active_pet: сверка идёт каждый кадр,
## поэтому после загрузки сохранения или отпускания другого питомца узел пересоздаётся сам.

const WINDOW_SIZE := Vector2(820, 560)
## Радиус поиска цели для команды «Атакуй», если у игрока нет цели.
const ATTACK_RANGE := 12.0

var main: Node
## Призванный питомец (узел в мире) или null. Контракт узла (используют HUD и другие модули):
## поля pet_name, level, hp, max_hp, is_down (погиб/скрыт), метод heal(amount: int), сигнал stats_changed.
var active_pet: Pet = null
## Кнопки открытого окна питомцев: "summon_<i>", "recall_<i>", "revive_<i>", "release_<i>".
var window_buttons: Dictionary = {}

var _window_body: VBoxContainer = null
## Индекс питомца, ждущего подтверждения «Отпустить» (второе нажатие), -1: никого.
var _release_confirm := -1


func setup(m: Node) -> void:
	main = m
	_sync()


func _process(_delta: float) -> void:
	if main != null:
		_sync()


## Обрабатывает действия: "pet_attack", "pet_follow", "pets_window". true, если действие своё.
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
	return false


## Зверь убит (игроком или питомцем): опыт призванному живому питомцу.
func on_mob_killed(mob: Mob) -> void:
	if mob == null or not _has_pet():
		return
	active_pet.gain_xp(maxi(1, roundi(mob.xp_reward * PetData.XP_SHARE)))


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
	if Game.pets.is_empty():
		var hint := Label.new()
		hint.text = "Питомцев пока нет. Нажмите «Приручить» рядом со зверем (нужен кристалл души), затем добейте его."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(WINDOW_SIZE.x - 60.0, 0)
		body.add_child(hint)
		return
	for i in Game.pets.size():
		_add_row(body, i)


func _add_row(body: VBoxContainer, i: int) -> void:
	var rec: Dictionary = Game.pets[i]
	var sp := String(rec.get("species", "boar"))
	var lvl := int(rec.get("level", 1))
	var dead := bool(rec.get("dead", false))
	var st := PetData.stats_for(sp, lvl)
	var mhp := int(st["max_hp"])
	var cur := int(rec.get("hp", -1))
	if cur < 0 or cur > mhp:
		cur = mhp
	var active := i == Game.active_pet and not dead

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status: String = "погиб" if dead else "HP %d/%d" % [cur, mhp]
	info.text = "%s%s\n%s, ур. %d, %s" % [
		String(rec.get("name", "Питомец")), "  [призван]" if active else "",
		PetData.role_name(sp), lvl, status]
	if dead:
		info.modulate = Color(1.0, 0.55, 0.5)
	elif active:
		info.modulate = Color(0.6, 0.95, 1.0)
	row.add_child(info)

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
	b.pressed.connect(cb)
	row.add_child(b)
	window_buttons[key] = b


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
	var st := PetData.stats_for(String(rec.get("species", "boar")), int(rec.get("level", 1)))
	rec["dead"] = false
	rec["hp"] = maxi(1, int(float(st["max_hp"]) * 0.5))
	_msg("Питомец «%s» воскрешён" % String(rec.get("name", "")))
	Game.changed.emit()
	_refresh_window()


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
