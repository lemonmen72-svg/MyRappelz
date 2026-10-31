extends "res://tests/test_base.gd"
## Жители-NPC: данные (имена, падежи, титулы, реплики, пункты «скоро»), все поставлены в мир со своими именами
## над головой; стоят в своих деревнях / городе / лагере / у пещеры (по зоне и ближайшей POI), на проходимой
## земле, не на дороге, не в постройках и мелочах, в безопасных зонах (звери туда не заходят, не в логове анатем),
## не ближе 3 м друг к другу и к торговцу / Кирку, вдали от точек старта; своя внешность у каждого (модель из
## примитивов, лёгкая; заготовка npc_<id>.glb); рядом — кнопка «Говорить» выбирает ближайшего, диалог
## открывается у каждого, пункты «скоро» и справочник мудреца показывают текст, «Склад» у кладовщика открывает
## окно склада; реплики по положению героя; задания мудреца после старосты (четыре сразу, «Взять все»), задание
## «Городской склад» (поговорить с кладовщиком, положить вещь на склад) берётся и сдаётся.

## Кто где стоит: id → [POI, ближайшая из POI этого вида должна быть она].
const HOMES := {
	"sage": "town", "smith": "town", "storekeeper": "town",
	"elder_human": "human_village", "elder_light": "light_elf_village", "elder_dark": "dark_elf_village",
	"hunter": "tent_w1", "merc_chief": "cave",
}
## Особые детали модели: id → [вид оружия, узлы].
const PARTS := {
	"elder_human": ["cane", ["Cane"]],
	"smith": ["hammer", ["Hammer"]],
	"sage": ["scroll_staff", ["ScrollStaff", "Book"]],
	"storekeeper": ["", ["Keys", "Book"]],
	"hunter": ["", ["Bow", "Quiver"]],
	"merc_chief": ["", ["Scabbard", "Cape"]],
	"elder_light": ["", []],
	"elder_dark": ["", ["Cape"]],
}

## Порядок разговоров и номер текущего.
var order: Array = []
var idx := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var npcs: Npcs = main.npcs
	var hud: HUD = main.hud
	match step:
		0:
			_unit_data()
			_check_world()
			_check_models()
			_check_situations()
			order = NpcData.placed_ids()
			idx = 0
			step = 1
		1:
			# Подойти к очередному жителю
			if idx >= order.size():
				step = 10
				return
			npcs.close_dialog()
			_stand_by(String(order[idx]), 1.8)
			wait = 4
			step = 2
		2:
			var id := String(order[idx])
			check(hud.is_button_visible("talk") and npcs.nearest_talker() == id, "у %s — кнопка «Говорить» (ближайший: %s)"
				% [id, npcs.nearest_talker()])
			main._on_action("talk")
			check(npcs.is_dialog_open() and npcs.dialog_npc == id and npcs.page == "main", "диалог с %s открыт" % id)
			check(npcs.reply != "" and npcs.reply == npcs.greeting(id), "%s: реплика «%s»" % [id, npcs.reply])
			check(_has_text(NpcData.npc_name(id)) and _has_text(String(NpcData.npc(id)["title"])), "%s: имя и титул в окне" % id)
			check(npcs.buttons.has("opt_bye") and not npcs.buttons.has("opt_trade"), "%s: «До встречи», торговли нет" % id)
			check(npcs.buttons.has("opt_quests") == Npcs.gives_quests(id), "%s: «Задания» — только если есть задания" % id)
			for e in NpcData.talk_options(id):
				var d: Dictionary = e
				var key := "opt_" + String(d["id"])
				check(npcs.buttons.has(key), "%s: пункт «%s»" % [id, d["label"]])
				if not npcs.buttons.has(key):
					continue
				var label := (npcs.buttons[key] as Button).text
				check(label.contains("скоро") == bool(d.get("soon", false)), "%s: подпись «%s»" % [id, label])
				if d.has("action"):
					# Пункт-окно: «Склад» у кладовщика
					_press(key)
					check(main.economy.is_storage_open() and not npcs.is_dialog_open(), "%s: «%s» открывает окно склада"
						% [id, d["label"]])
					hud.close_window()
					npcs.open_dialog(id)
					continue
				_press(key)
				check(npcs.page == "info" and npcs.reply == String(d["text"]) and _has_text(String(d["text"]).left(20)),
					"%s / %s: текст «%s»" % [id, d["id"], npcs.reply.left(40)])
				var topics: Array = d.get("topics", [])
				for t in topics:
					var td: Dictionary = t
					_press("opt_" + String(td["id"]))
					check(npcs.page_info == String(d["id"]) + "/" + String(td["id"]) and npcs.reply == String(td["text"]),
						"%s: справочник «%s»" % [id, td["label"]])
					_press("back")
					check(npcs.page_info == String(d["id"]), "назад — к списку тем")
				_press("back")
				check(npcs.page == "main", "%s: назад — главная страница" % id)
			_press("opt_bye")
			check(not npcs.is_dialog_open() and not hud.is_window_open(), "%s: «До встречи» закрывает диалог" % id)
			idx += 1
			step = 1
		10:
			# Цепочка старосты сдана — у мудреца четыре задания сразу
			for qid in QuestData.ELDER_CHAIN:
				game.quests_done[String(qid)] = 1
			game.level = 5
			game.xp = 0
			main.quests._changed()
			npcs.refresh_marks()
			var sage: Npc = npcs.npc("sage")
			check(sage.mark_text() == "!", "над мудрецом «!»: «%s»" % sage.mark_text())
			_stand_by("sage", 1.8)
			wait = 4
			step = 11
		11:
			var q: Quests = main.quests
			npcs.talk_to("sage")
			check(npcs.reply == NpcData.greet("sage", "offer"), "мудрец предлагает дело: " + npcs.reply)
			check((npcs.buttons["opt_quests"] as Button).text.contains("(!)"), "у «Задания» отметка нового")
			_press("opt_quests")
			for qid in ["sage_path", "sage_storage", "sage_shop", "sage_teacher"]:
				check(npcs.buttons.has("dq_" + String(qid)), "у мудреца задание «%s»" % QuestData.quest_name(String(qid)))
			check(not npcs.buttons.has("dq_sage_to_hunter"), "«К охотнице» — только после склада, лавки и учителя")
			check(npcs.buttons.has("accept_all") and (npcs.buttons["accept_all"] as Button).text.contains("4"),
				"кнопка «Взять все задания (4)»")
			_press("dq_sage_storage")
			check(npcs.reply == QuestData.text("sage_storage", "offer"), "реплика при выдаче")
			check(_has_text("Поговорить с Кладовщиком Тобином") and _has_text("Положить вещь на склад"), "цели склада")
			_press("accept")
			check(q.state("sage_storage") == "active", "«Городской склад» взято")
			npcs.close_dialog()
			_stand_by("storekeeper", 1.8)
			wait = 4
			step = 12
		12:
			var q: Quests = main.quests
			var eco: Economy = main.economy
			main._on_action("talk")
			check(npcs.dialog_npc == "storekeeper" and q.goal_done("sage_storage", 0), "поговорили с кладовщиком")
			check(not q.is_ready("sage_storage"), "склад ещё пуст — задание не выполнено")
			check(not (npcs.buttons["opt_storage"] as Button).text.contains("скоро"), "«Склад» — рабочий пункт")
			_press("opt_storage")
			check(eco.is_storage_open() and _has_text("Склад"), "окно склада открыто")
			game.inventory.add("wolf_pelt", 2)
			eco.window.refresh()
			eco.window.select_cell(game.inventory.find_cell("wolf_pelt"))
			check(eco.window.buttons.has("act_store") and eco.window.buttons.has("act_store_all"), "кнопки «На склад»")
			(eco.window.buttons["act_store"] as Button).pressed.emit()
			check(game.storage.count("wolf_pelt") == 1 and game.inventory.count("wolf_pelt") == 1, "одна шкура на складе")
			check(q.is_ready("sage_storage"), "«Городской склад» выполнено")
			check(last_hud_text().contains("вернитесь к Мудрецу Альдерику"), "сообщение: " + last_hud_text())
			hud.close_window()
			_stand_by("sage", 1.8)
			wait = 4
			step = 13
		13:
			var q: Quests = main.quests
			main._on_action("talk")
			check(npcs.dialog_npc == "sage" and npcs.reply == NpcData.greet("sage", "ready"), "мудрец: есть что сдать")
			_press("opt_quests")
			_press("dq_sage_storage")
			var g0: int = game.gold
			var xp0 := _total_xp()
			_press("complete")
			check(q.state("sage_storage") == "done", "«Городской склад» сдано")
			check(game.gold == g0 + 15 and _total_xp() == xp0 + 160, "награда: 160 оп., 15 зол.")
			check(npcs.reply == QuestData.text("sage_storage", "done"), "слова мудреца при сдаче")
			check(npcs.npc("sage").mark_text() == "!", "у мудреца остались задания — «!»")
			check(main.quests.state("kirk_first_card") == "available", "цепочка Кирка не задета")
			npcs.close_dialog()
			ok_done()


# ---------- Проверки ----------

func _unit_data() -> void:
	var names := {}
	for k in NpcData.NPCS:
		var id := String(k)
		var d := NpcData.npc(id)
		for f in ["name", "gen", "dat", "title", "where"]:
			check(String(d.get(f, "")) != "", "%s: поле %s" % [id, f])
		check(not names.has(NpcData.npc_name(id)), "%s: имя своё — %s" % [id, NpcData.npc_name(id)])
		names[NpcData.npc_name(id)] = true
		check(NpcData.greet(id, "idle") != "", "%s: приветствие" % id)
		check(NpcData.has_dialog(id) == (id != "merchant"), "%s: разговор %s" % [id, NpcData.has_dialog(id)])
	check(NpcData.npc_name("merchant") == "Торговец Гордей" and NpcData.shop_title("merchant") == "Торговец",
		"торговец получил имя, окно торговли — «Торговец»")
	var want := {"elder_human": "Староста Ольвин", "elder_light": "Староста Элиарна", "elder_dark": "Староста Вейрис",
		"storekeeper": "Кладовщик Тобин", "smith": "Кузнец Гуннар", "sage": "Мудрец Альдерик", "hunter": "Охотница Ярра",
		"merc_chief": "Корвен, глава наёмников"}
	for k in want:
		check(NpcData.npc_name(String(k)) == String(want[k]), "имя %s: %s" % [k, NpcData.npc_name(String(k))])
	check(NpcData.placed_ids().size() == HOMES.size(), "жителей по spot: %d" % NpcData.placed_ids().size())
	for k in NpcData.placed_ids():
		var id := String(k)
		check(HOMES.has(id), "%s: известно, где стоит" % id)
		var soon := 0
		for e in NpcData.talk_options(id):
			var d: Dictionary = e
			check(String(d.get("label", "")) != "" and String(d.get("text", "")) != "", "%s: пункт %s с текстом" % [id, d.get("id")])
			if bool(d.get("soon", false)):
				soon += 1
		# Дела, которых ещё нет, — с пометкой «скоро» (кузница, подземелье); у мудреца, кладовщика (склад), старост
		# и охотницы (задания) пункты рабочие
		check(soon >= 1 or ["sage", "storekeeper", "elder_human", "elder_light", "elder_dark", "hunter"].has(id),
			"%s: будущее дело с пометкой «скоро»" % id)
		check(not NpcData.is_trader(id), "%s: не торгует" % id)
	check(String(NpcData.talk_entry("sage", "profession").get("text", "")).contains("десятого уровня")
		and not bool(NpcData.talk_entry("sage", "profession").get("soon", false)), "мудрец о первой профессии (рабочий пункт)")
	check(String(NpcData.talk_entry("sage", "guide/pets").get("text", "")).contains("Кирк"), "справочник мудреца: питомцы — к Кирку")
	check(NpcData.talk_entry("sage", "guide/nope").is_empty() and NpcData.talk_entry("smith", "").is_empty(),
		"неизвестный пункт — пусто")
	check(not QuestData.has_quest("sage_town_tour"), "«Знакомство с городом» заменено заданиями мудреца")
	check(String(NpcData.talk_entry("storekeeper", "storage").get("action", "")) == "storage", "у кладовщика — «Склад»")
	check(NpcData.talk_entry("smith", "forge").get("soon", false) and NpcData.talk_entry("merc_chief", "dungeon").get("soon", false),
		"кузница и подземелье — «скоро»")


func _check_world() -> void:
	var w := IslandWorld.current
	var npcs: Npcs = main.npcs
	check(w != null, "остров построен")
	if w == null:
		return
	var all: Array = []
	for k in NpcData.NPCS:
		var id := String(k)
		var n: Npc = npcs.npc(id)
		check(n != null and n.is_inside_tree() and n.is_in_group("npc"), "%s в мире" % id)
		if n == null:
			continue
		all.append(id)
		var lbl := n.get_node_or_null("NameLabel") as Label3D
		check(lbl != null and lbl.text == NpcData.npc_name(id), "%s: имя над головой «%s»" % [id, lbl.text if lbl != null else ""])
	var fps: Array = w.get_meta("poi_footprints", [])
	var props: Array = w.get_meta("poi_props", [])
	check(not props.is_empty(), "мелочи без коллизии учтены: %d" % props.size())
	for k in NpcData.placed_ids():
		var id := String(k)
		var n: Npc = npcs.npc(id)
		if n == null:
			continue
		var p := Vector2(n.global_position.x, n.global_position.z)
		var info := Npcs.spot_info(w, id)
		var home := String(HOMES[id])
		var hc := IslandWorld.v2(w.poi(home)["center"])
		print("  %s: (%.1f, %.1f), до %s %.1f м" % [id, p.x, p.y, home, p.distance_to(hc)])
		# Своё место: в круге своей зоны / POI, ближайшая POI того же вида — своя
		var area_c: Vector2 = info["area_c"]
		check(p.distance_to(area_c) <= float(info["area_r"]) + 0.01, "%s: в своём месте (%.1f м от центра)"
			% [id, p.distance_to(area_c)])
		var ptype := String(w.poi(home).get("type", ""))
		var nearest := ""
		var nd := INF
		for e in w.pois_of_type(ptype):
			var pd: Dictionary = e
			var d := p.distance_to(IslandWorld.v2(pd["center"]))
			if d < nd:
				nd = d
				nearest = String(pd["id"])
		check(nearest == home, "%s: ближайшая POI «%s» — %s" % [id, ptype, nearest])
		check(w.is_walkable(p.x, p.y), "%s: на проходимой земле" % id)
		check(w.road_distance(p.x, p.y) >= Npcs.ROAD_CLEAR, "%s: не на дороге (%.1f м)" % [id, w.road_distance(p.x, p.y)])
		check(absf(n.global_position.y - w.height_at(p.x, p.y)) < 0.05, "%s: стоит на земле" % id)
		check(w.in_safe_zone(n.global_position), "%s: в безопасной зоне (звери не заходят)" % id)
		var gap := INF
		for f in fps:
			var fd: Dictionary = f
			var fc: Vector2 = fd["c"]
			gap = minf(gap, p.distance_to(fc) - float(fd["r"]))
		check(gap >= 0.5, "%s: не в постройке (%.1f м до следа)" % [id, gap])
		for f in props:
			var fd: Dictionary = f
			var fc: Vector2 = fd["c"]
			check(p.distance_to(fc) >= float(fd["r"]) + 0.3, "%s: не в мелочах у %s" % [id, fc])
		# Не в зонах зверей, кроме безопасных; логово анатем и подступы — точно нет
		for z in w.cfg.get("mob_zones", []):
			var zd: Dictionary = z
			var inside := p.distance_to(IslandWorld.v2(zd["center"])) <= float(zd.get("radius", 10.0))
			if String(zd.get("id", "")).begins_with("cave_"):
				check(not inside, "%s: не в зоне %s" % [id, zd["id"]])
		var spawns: Dictionary = w.cfg.get("spawn_points", {})
		for e in spawns.values():
			check(p.distance_to(IslandWorld.v2(e)) > Npcs.TALK_RANGE + 0.5, "%s: далеко от точки старта %s" % [id, e])
		for s in main._slots:
			var sl: Dictionary = s
			var mp: Vector3 = sl["pos"]
			check(Vector2(mp.x, mp.z).distance_to(p) > 1.5, "%s: звери не появляются вплотную" % id)
	# Не ближе 3 м друг к другу (торговец и Кирк — тоже)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Npc = npcs.npc(String(all[i]))
			var b: Npc = npcs.npc(String(all[j]))
			var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
			check(d >= 3.0, "%s и %s не толпятся: %.1f м" % [all[i], all[j], d])
	# Глава наёмников — у входа в пещеру
	var cave := w.get_node("Pois").find_child("Cave", true, false) as Node3D
	var mc: Npc = npcs.npc("merc_chief")
	if cave != null and mc != null:
		var dc := Vector2(cave.global_position.x - mc.global_position.x, cave.global_position.z - mc.global_position.z).length()
		check(dc < 12.0, "Корвен у входа в пещеру: %.1f м" % dc)
	# Охотница — в лагере у костра
	var camp_c := IslandWorld.v2(w.poi("tent_w1")["center"])
	var hn: Npc = npcs.npc("hunter")
	if hn != null:
		check(Vector2(hn.global_position.x, hn.global_position.z).distance_to(camp_c) < 8.0, "охотница в Западном лагере")
	if not props.is_empty():
		var pd: Dictionary = props[0]
		var pc: Vector2 = pd["c"]
		check(not Npcs.spot_ok(w, pc, []), "в мелочах NPC не ставится")


func _check_models() -> void:
	var npcs: Npcs = main.npcs
	var specs := {}
	for k in NpcData.NPCS:
		var id := String(k)
		var n: Npc = npcs.npc(id)
		if n == null:
			continue
		var m: CharacterModel = n._model
		check(m != null, "%s: модель" % id)
		if m == null:
			continue
		var key := var_to_str(m.spec)
		check(not specs.has(key), "%s: своя внешность" % id)
		specs[key] = true
		var path := CharacterModel.npc_asset(id)
		check(path == "res://assets/characters/npc_%s.glb" % id, "заготовка модели из файла: " + path)
		if ResourceLoader.exists(path):
			check(String(m.spec.get("asset", "")) == path, "%s: модель из файла %s" % [id, path])
			continue
		check(not m.spec.has("asset"), "%s: файла нет — модель из примитивов" % id)
		check(m.mesh_count() <= 4 and m.surface_count() <= 5, "%s: модель лёгкая (мешей %d, поверхностей %d)"
			% [id, m.mesh_count(), m.surface_count()])
		var head := m.find_child("Head", true, false) as Node3D
		check(head != null and head.global_position.y - n.global_position.y > 1.4, "%s: рост как у человека" % id)
		if PARTS.has(id):
			var e: Array = PARTS[id]
			check(m.weapon_kind == String(e[0]), "%s: в руках «%s»" % [id, m.weapon_kind])
			for part in e[1]:
				check(m.find_child(String(part), true, false) != null, "%s: есть %s" % [id, part])
	for id in ["elder_light", "elder_dark"]:
		var n: Npc = npcs.npc(id)
		if n != null and not n._model.spec.has("asset"):
			check(n._model.has_ears(), "%s: эльфийские уши" % id)
	var sp := CharacterModel.npc_spec("sage")
	var kp := CharacterModel.kirk_spec()
	check(String(sp["outfit"]) != String(kp["outfit"]) and sp["main"] != kp["main"], "мудрец не похож на Кирка")
	# Модель из файла без оружия: руки пустые (на модели героя)
	var hero := CharacterModel.new()
	var hs := CharacterModel.spec_for("dark_elf", "assassin")
	if hs.has("asset"):
		hs["weapon"] = ""
		hero.setup(hs)
		main.add_child(hero)
		check(hero.weapon_kind == "" and hero.find_child("Sword", true, false) == null, "житель из файла — без оружия")
		hero.queue_free()
	else:
		hero.free()


## Реплики по положению героя.
func _check_situations() -> void:
	var lv: int = game.level
	game.level = 1
	check(Npcs.situation("merc_chief") == "young", "Корвен гонит новичка")
	check(Npcs.situation("elder_dark") == "kin", "староста тёмных эльфов — своему")
	check(Npcs.situation("elder_human") == "idle", "староста людей — гостю")
	check(Npcs.situation("smith") == "young", "кузнец — новичку")
	game.level = 10
	check(Npcs.situation("merc_chief") == "veteran" and Npcs.situation("hunter") == "veteran", "ветерану — своё")
	game.level = 9
	check(Npcs.situation("merc_chief") == "kin", "Корвен — наёмнику")
	game.level = lv
	var inv: Inventory = game.inventory
	var free_n := Inventory.CAPACITY - inv.used_cells()
	inv.add("sword_steel", free_n)
	check(Npcs.situation("storekeeper") == "full_bag", "кладовщик видит полную сумку")
	inv.remove("sword_steel", inv.count("sword_steel"))
	check(Npcs.situation("storekeeper") == "idle", "сумка свободна — обычная реплика")


# ---------- Помощники ----------

## Игрок в dist м перед жителем (на проходимой земле), HP полное.
func _stand_by(id: String, dist: float) -> void:
	var n: Npc = main.npcs.npc(id)
	var w := IslandWorld.current
	var p: Player = main.player
	var c := n.global_position
	var fwd := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw))
	var pos := c + fwd * dist
	for k in 8:
		var dir := fwd.rotated(Vector3.UP, TAU * float(k) / 8.0)
		var q := c + dir * dist
		if w == null or w.is_walkable(q.x, q.z):
			pos = q
			break
	if w != null:
		pos.y = w.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	p.hp = p.max_hp


func _press(key: String) -> void:
	var b: Button = main.npcs.buttons.get(key)
	check(b != null, "кнопка диалога %s" % key)
	if b != null:
		b.pressed.emit()


func _has_text(part: String) -> bool:
	if not main.hud.is_window_open():
		return false
	for n in main.hud._window.find_children("*", "Label", true, false):
		if (n as Label).text.contains(part) and not n.is_queued_for_deletion():
			return true
	return false


func last_hud_text() -> String:
	return main.hud._msg_label.text


## Весь опыт героя с 1 уровня.
func _total_xp() -> int:
	var t: int = game.xp
	for l in range(1, game.level):
		t += game.xp_to_next(l)
	return t
