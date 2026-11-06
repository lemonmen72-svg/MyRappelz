extends "res://tests/test_base.gd"
## Редактор объектов подземелья (0.35.2, DungeonEditor): админ-панель «Мир» → «Открыть редактор» — объекты подземелья
## становятся отдельными моделями (склеенные меши и коробки коллизии скрыты, мосты остаются), панель справа — блокер
## (касание по ней не нажимает кнопки HUD под ней); выбор — «Ближний», ◀ ▶, касание объекта на экране; сдвиг
## относительно камеры, поворот, высота, размер, копия, удаление, «К герою», каталог «Добавить…», «Отменить»;
## сохранение — файл в формате world/dungeon.json "props"; «Выйти» — сцена заново: DungeonProps ставит раскладку из
## файла, герой на том же месте; файл другой layout_version не действует; «Отправить» без плагина — путь копии;
## «Сбросить» — встроенная раскладка.

const TEST_FILE := "user://test_dungeon_layout.json"

var ed: DungeonEditor = null
var first_main: Node = null
var base_count := 0
var saved: Array = []
var hero_at := Vector3.ZERO
var tries := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 25


func before_start() -> void:
	Game.location = "dungeon"
	DungeonEditor.layout_path = TEST_FILE
	DungeonEditor.reset_file()


func _w() -> DungeonWorld:
	return main.get("world") as DungeonWorld


func _holder() -> Node:
	return _w().get_node_or_null("DungeonProps")


func _press(key: String) -> void:
	ed.press(key)


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				wait = 5
				return
			first_main = main
			var w := _w()
			check(w != null, "старт в подземелье")
			base_count = (w.cfg.get("props", []) as Array).size()
			check(int(w.cfg.get("layout_version", 0)) >= 1, "у раскладки подземелья есть layout_version")
			check(DungeonEditor.props_for(w).size() == base_count, "своей раскладки нет — встроенная (%d)" % base_count)
			# Вне подземелья кнопка неактивна; здесь — активна
			AdminPanel.open(main, "world")
			check(AdminPanel.buttons.has("editor_start"), "в «Мире» есть «Открыть редактор»")
			check(not (AdminPanel.buttons["editor_start"] as Button).disabled, "в подземелье редактор доступен")
			check((AdminPanel.buttons["editor_share"] as Button).disabled, "файла ещё нет — «Отправить файл» неактивна")
			(AdminPanel.buttons["editor_start"] as Button).pressed.emit()
			ed = DungeonEditor.current
			check(ed != null and is_instance_valid(ed), "редактор открыт")
			check(not main.hud.is_window_open(), "окно админ-панели закрыто")
			check(ed.items.size() == base_count, "в редакторе все объекты (%d)" % ed.items.size())
			check(_same(ed.entries(), w.cfg["props"]), "раскладка редактора = встроенная")
			var hidden := true
			var bridges := 0
			var bodies_on := 0
			for c in _holder().get_children():
				if c is MeshInstance3D and c.name.begins_with("Props") and (c as MeshInstance3D).visible:
					hidden = false
				if c is MeshInstance3D and c.name.begins_with("Bridges") and (c as MeshInstance3D).visible:
					bridges += 1
				if c is StaticBody3D and (c as StaticBody3D).collision_layer != 0:
					bodies_on += 1
			check(hidden, "склеенные меши объектов скрыты")
			check(bodies_on == 0, "коробки коллизии объектов выключены на время правки")
			if PropAsset.has(DungeonProps.BRIDGE_PROP) and not w.bridges.is_empty():
				check(bridges > 0, "мосты видны (%d участков)" % bridges)
			wait = 3
			step = 1
		1:
			# Свободная камера: герой скрыт, джойстик ведёт точку обзора, герой стоит
			var p: Player = main.player
			hero_at = p.global_position
			check(not p.visible, "герой скрыт в режиме расстановки")
			check(bool(main.get("edit_cam")) and main.hud.edit_mode, "свободная камера и режим HUD")
			main.cam_yaw = 0.0
			# Джойстик «вверх» (палец держит джойстик — HUD не перезаписывает move_vec клавиатурой)
			main.hud._joy_idx = 99
			main.hud.move_vec = Vector2(0, -1)
			wait = 30
			step = 11
		11:
			main.hud._joy_idx = -1
			main.hud.move_vec = Vector2.ZERO
			var p: Player = main.player
			check(ed.sel == -1 and not ed._bar.visible, "сначала ничего не выбрано — полосы нет")
			check(ed.pivot.z < hero_at.z - 3.0, "джойстик ведёт камеру вперёд (на %.1f м)" % (hero_at.z - ed.pivot.z))
			check(Vector2(p.global_position.x - hero_at.x, p.global_position.z - hero_at.z).length() < 0.3, "герой стоит")
			check(main.cam_focus.distance_to(ed.pivot) < 1.0, "камера следит за точкой обзора")
			check(not main.hud.is_button_visible("attack"), "круглые кнопки HUD скрыты")
			ed.pivot = hero_at
			ed.select_nearest()
			var it := ed.selected()
			check(not it.is_empty(), "выбран ближний объект")
			var x0 := float(it["x"])
			var z0 := float(it["z"])
			var yaw0 := float(it["yaw"])
			var s0 := float(it["s"])
			main.cam_yaw = 0.0
			ed.press("ed_nudge_fwd")
			check(is_equal_approx(float(it["z"]), z0 - DungeonEditor.NUDGE) and is_equal_approx(float(it["x"]), x0),
				"«▲» — на %.1f м от камеры" % DungeonEditor.NUDGE)
			main.cam_yaw = PI * 0.5
			ed.press("ed_nudge_right")
			check(is_equal_approx(float(it["z"]), z0 - 2.0 * DungeonEditor.NUDGE), "«▶» — вправо от повёрнутой камеры")
			main.cam_yaw = 0.0
			ed._push_undo()
			(ed.sliders["rot"] as HSlider).value = fposmod(yaw0 + 90.0, 360.0)
			check(is_equal_approx(fposmod(float(it["yaw"]) - yaw0, 360.0), 90.0), "ползунок «Поворот»")
			ed._push_undo()
			(ed.sliders["scale"] as HSlider).value = 1.5
			check(is_equal_approx(float(it["s"]), 1.5), "ползунок «Размер»")
			ed._push_undo()
			(ed.sliders["height"] as HSlider).value = 0.5
			check(is_equal_approx(float(it["dy"]), 0.5), "ползунок «Высота»")
			var n: Node3D = it["node"]
			check(n.global_position.distance_to(ed.pos_of(it)) < 0.01, "модель на месте записи")
			for k in 6:
				ed.press("ed_undo")
			var back := ed.selected()
			check(is_equal_approx(float(back["x"]), x0) and is_equal_approx(float(back["z"]), z0)
				and is_equal_approx(float(back["s"]), s0), "«Отменить» возвращает прежнее")
			check(_same(ed.entries(), _w().cfg["props"]), "после отмен — снова встроенная раскладка")
			step = 2
		2:
			var c0 := ed.items.size()
			var sel0 := ed.sel
			var id0 := String(ed.selected()["id"])
			ed.press("ed_copy")
			check(ed.items.size() == c0 + 1 and ed.sel == sel0 + 1 and String(ed.selected()["id"]) == id0, "копия рядом, выбрана")
			ed.press("ed_delete")
			check(ed.items.size() == c0 and ed.sel == -1, "«Убрать» — выбор снят")
			ed.press("ed_catalog")
			check(ed.catalog_open, "каталог открыт")
			var all := 0
			for g in DungeonEditor.CATALOG:
				for idv in (g as Array)[1]:
					all += 1
					if not DungeonEditor.NAMES.has(String(idv)):
						fail("у %s нет названия" % idv)
					if PropAsset.has(String(idv)) and DungeonEditor.thumb(String(idv)) == null:
						fail("у %s нет картинки каталога" % idv)
			check(all == DungeonEditor.NAMES.size() - 1, "в каталоге все объекты, кроме моста, с картинками (%d)" % all)
			ed.press("ed_cat_tab_5")
			check(ed.buttons.has("ed_cat_dg_torch"), "раздел «Свет» — факел")
			ed.pivot = hero_at
			ed.press("ed_cat_dg_torch")
			check(not ed.catalog_open, "каталог закрылся")
			var t := ed.selected()
			check(ed.items.size() == c0 + 1 and String(t["id"]) == "dg_torch", "факел добавлен и выбран")
			var d := Vector2(float(t["x"]) - hero_at.x, float(t["z"]) - hero_at.z).length()
			check(d < 25.0, "факел у точки обзора (%.1f м)" % d)
			# Поставить факел на ровное место рядом с героем для касаний
			ed.set_xz(t, hero_at.x, hero_at.z - 3.0)
			main.cam_dist = 14.0
			main.cam_pitch = deg_to_rad(55.0)
			wait = 20
			step = 3
		3:
			# Касание объекта на экране выбирает его; касание выбранного и протяжка — двигает по полу
			var cam := get_viewport().get_camera_3d()
			var target := ed.sel
			var it := ed.selected()
			var c := ed.pos_of(it) + Vector3(0, ed.size_of(String(it["id"])).y * float(it["s"]) * 0.45, 0)
			var at := cam.unproject_position(c)
			ed.select(-1)
			_tap(5, at)
			check(ed.sel == target, "касание объекта выбирает его")
			var x0 := float(it["x"])
			var z0 := float(it["z"])
			touch(true, 6, at)
			check(ed._drag_idx == 6, "касание выбранного — перетаскивание (камера не вращается)")
			check(not main.hud._cam_touches.has(6), "камера этот палец не взяла")
			var to := at + Vector2(120, 0)
			var dr := InputEventScreenDrag.new()
			dr.index = 6
			dr.position = to
			ed._input(dr)
			var g: Variant = ed.ground_at(to, ed.pos_of(it).y)
			check(g is Vector3 and Vector2(float(it["x"]) - x0, float(it["z"]) - z0).length() > 0.5,
				"объект едет за пальцем (%.2f м)" % Vector2(float(it["x"]) - x0, float(it["z"]) - z0).length())
			var up := InputEventScreenTouch.new()
			up.index = 6
			up.position = to
			up.pressed = false
			ed._input(up)
			main.hud._input(up)
			check(ed._drag_idx == -1, "палец отпущен — перетаскивание кончилось")
			ed.press("ed_undo")
			check(is_equal_approx(float(ed.selected()["x"]), x0), "«Отменить» после перетаскивания")
			# Замечание: в стене
			var w := _w()
			var wall := Vector2.INF
			for k in 400:
				var q := Vector2(hero_at.x + float(k % 20) * 2.0 - 20.0, hero_at.z + float(k / 20) * 2.0 - 20.0)
				if not w.is_walkable(q.x, q.y) and w.water_distance(q.x, q.y) > 3.0:
					wall = q
					break
			if wall.is_finite():
				var t2 := ed.selected()
				ed.set_xz(t2, wall.x, wall.y)
				check(ed.problems(t2).contains("в стене"), "факел в стене — замечание «%s»" % ed.problems(t2))
				ed.press("ed_undo")
			# Пустое место — снять выбор
			_tap(7, Vector2(get_viewport().get_visible_rect().size.x * 0.5, 120))
			for e in ["_top", "_bar", "_catalog"]:
				var ctl: Control = ed.get(e)
				var r := ctl.get_global_rect()
				var view := ctl.get_viewport_rect().size
				ctl.visible = true
				check(r.position.x >= -1 and r.end.x <= view.x + 1 and r.end.y <= view.y + 1, "%s в экране (%s)" % [e, r])
			var br: Rect2 = ed._bar.get_global_rect()
			check(br.position.x > get_viewport().get_visible_rect().size.x * 0.25, "полоса справа от джойстика")
			check(main.hud.over_blocker(br.get_center()), "полоса — блокер касаний")
			step = 4
		4:
			check(ed.save(), "раскладка сохранена")
			var f := DungeonEditor.read_file()
			saved = ed.entries()
			check(not f.is_empty() and (f["props"] as Array).size() == saved.size(), "файл: %d объектов" % saved.size())
			check(int(f["layout_version"]) == DungeonEditor.layout_version(_w()), "в файле layout_version раскладки")
			check(_same(f["props"], saved), "файл = раскладка редактора")
			var msg := DungeonEditor.share_file()
			check(msg.contains("Файл раскладки"), "«Отправить» без плагина — путь копии: %s" % msg)
			_clean_copies()
			ed.press("ed_exit")
			step = 5
		5:
			if main == first_main or not bool(main.get("_started")):
				tries += 1
				if tries > 1200:
					fail("сцена после выхода из редактора не построилась")
				return
			check(DungeonEditor.current == null, "редактор закрыт")
			var w := _w()
			check(w != null, "снова подземелье")
			var lay := DungeonEditor.props_for(w)
			check(_same(lay, saved), "DungeonProps ставит раскладку из файла (%d)" % lay.size())
			var hp := (main.player as Player).global_position
			check(Vector2(hp.x - hero_at.x, hp.z - hero_at.z).length() < 1.0, "герой там же, где был в редакторе")
			var placed := int(_holder().get_meta("placed", 0))
			check(placed >= saved.size(), "объектов поставлено %d" % placed)
			# Файл от прежней раскладки не действует
			var txt := FileAccess.get_file_as_string(TEST_FILE).replace('"layout_version": %d' % DungeonEditor.layout_version(w),
				'"layout_version": 999')
			var fw := FileAccess.open(TEST_FILE, FileAccess.WRITE)
			fw.store_string(txt)
			fw.close()
			check(DungeonEditor.props_for(w).size() == base_count, "файл другой layout_version не действует")
			AdminPanel.open(main, "world")
			check(not (AdminPanel.buttons["editor_share"] as Button).disabled, "файл есть — «Отправить файл» активна")
			main.hud.close_window()
			DungeonEditor.reset_file()
			check(not DungeonEditor.has_file(), "«Сбросить» удаляет свою раскладку")
			check(DungeonEditor.props_for(w).size() == base_count, "после сброса — встроенная")
			DungeonEditor.layout_path = DungeonEditor.LAYOUT_FILE
			ok_done()


## Списки раскладок равны (числа — с округлением редактора).
func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Array = a[i]
		var y: Array = b[i]
		if String(x[0]) != String(y[0]):
			return false
		var dx := [0.0, 0.0, 0.0, 1.0, 0.0]
		for k in range(1, 6):
			var vx := float(x[k]) if x.size() > k else float(dx[k - 1])
			var vy := float(y[k]) if y.size() > k else float(dx[k - 1])
			if k == 3:
				vx = fposmod(vx, 360.0)
				vy = fposmod(vy, 360.0)
			if absf(vx - vy) > 0.011:
				return false
	return true


func _tap(index: int, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = true
	ed._input(ev)
	main.hud._input(ev)
	var ev2 := ev.duplicate() as InputEventScreenTouch
	ev2.pressed = false
	ed._input(ev2)
	main.hud._input(ev2)


func _clean_copies() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("dungeon_layout_") and f.ends_with(".json"):
			d.remove(f)
