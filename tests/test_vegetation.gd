extends "res://tests/test_base.gd"
## Растительность и качество графики: растительность построена по зонам; деревья, кусты и камни
## не на дорогах, не в безопасных зонах и не на площадках построек; пресеты качества сразу меняют
## тени солнца и постобработку и сохраняются в user://settings.cfg; окно настроек открывается.

var _had_cfg := false
var _old_level := Quality.MEDIUM
var _fx: PostFx = null


func run_step() -> void:
	match step:
		0:
			var holders := get_tree().get_nodes_in_group("vegetation")
			check(holders.size() == 1, "растительность построена")
			var holder: Node = holders[0]
			var stats: Dictionary = holder.get_meta("stats", {})
			print("  растительность: ", stats)
			check(int(stats.get("trees", 0)) >= 80, "деревья: %d" % int(stats.get("trees", 0)))
			check(int(stats.get("bushes", 0)) >= 40, "кусты: %d" % int(stats.get("bushes", 0)))
			check(int(stats.get("rocks", 0)) >= 40, "камни: %d" % int(stats.get("rocks", 0)))
			check(int(stats.get("grass", 0)) >= 2000, "трава: %d" % int(stats.get("grass", 0)))
			check(int(stats.get("flowers", 0)) >= 200, "цветы: %d" % int(stats.get("flowers", 0)))
			check(get_tree().get_nodes_in_group("veg_grass").size() >= 20, "трава участками MultiMesh")
			check(get_tree().get_nodes_in_group("veg_trees").size() >= 5, "деревья слиты по участкам")
			var w := IslandWorld.current
			var road_half := float(w.cfg.get("roads", {}).get("width", 3.2)) * 0.5
			var pts: PackedVector3Array = holder.get_meta("solid_points", PackedVector3Array())
			var bad_safe := 0
			var bad_road := 0
			var bad_flat := 0
			for p in pts:
				if w.in_safe_zone(p):
					bad_safe += 1
				if w.road_distance(p.x, p.z) < road_half + 0.35:
					bad_road += 1
				var cell := w._cell(p.x, p.z)
				if w._flat_w[w._idx(cell.x, cell.y)] > 0.1:
					bad_flat += 1
			check(bad_safe == 0, "в безопасных зонах нет деревьев, кустов и камней (плохих: %d)" % bad_safe)
			check(bad_road == 0, "на дорогах нет деревьев, кустов и камней (плохих: %d)" % bad_road)
			check(bad_flat == 0, "на площадках построек нет деревьев, кустов и камней (плохих: %d)" % bad_flat)
			# Тёмные земли — мёртвые деревья, светлые — без мёртвых (участки Decor<группа>_x_z)
			var dead_dark := false
			var dead_light := false
			var vd := IslandWorld.v2(w.poi("dark_elf_village")["center"])
			var vl := IslandWorld.v2(w.poi("light_elf_village")["center"])
			for n in get_tree().get_nodes_in_group("veg_trees"):
				var mi := n as MeshInstance3D
				if mi == null or not String(mi.name).begins_with("Decor%d_" % IslandVegetation.G_DEAD):
					continue
				var q := Vector2(mi.position.x, mi.position.z)
				if q.distance_to(vd) < 70.0:
					dead_dark = true
				if q.distance_to(vl) < 25.0:
					dead_light = true
			check(dead_dark, "у деревни тёмных эльфов мёртвые деревья")
			check(not dead_light, "у деревни светлых эльфов нет мёртвых деревьев")
			step = 1
		1:
			_had_cfg = FileAccess.file_exists(Quality.PATH)
			_old_level = Quality.level()
			_fx = PostFx.new()
			main.add_child(_fx)
			check(_fx.layer < main.hud.layer, "постобработка рисуется под HUD")
			var rect := _fx.get_child(0) as Control
			check(rect != null and rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "постобработка не перехватывает касания")
			Quality.set_level(Quality.LOW)
			Quality.apply(get_tree())
			var sun := _sun()
			check(sun != null, "солнце найдено")
			check(not sun.shadow_enabled, "«Низкое»: без теней")
			check(not _fx.visible, "«Низкое»: без постобработки")
			Quality.set_level(Quality.HIGH)
			Quality.apply(get_tree())
			check(sun.shadow_enabled, "«Высокое»: тени включены сразу")
			check(_fx.visible, "«Высокое»: постобработка включена сразу")
			var cf := ConfigFile.new()
			check(cf.load(Quality.PATH) == OK and int(cf.get_value("graphics", "quality", -1)) == Quality.HIGH,
				"качество сохранено в settings.cfg")
			Quality.reload()
			check(Quality.level() == Quality.HIGH, "качество прочитано из settings.cfg")
			Quality.set_fps_limit(30)
			Quality.reload()
			check(Quality.fps_limit() == 30, "предел кадров сохранён и прочитан")
			check(Quality.level() == Quality.HIGH, "предел кадров не сбросил качество")
			Quality.set_fps_limit(999, false)
			check(Quality.fps_limit() == Quality.DEFAULT_FPS, "неверный предел кадров — по умолчанию")
			Quality.set_level(Quality.MEDIUM, false)
			Quality.apply(get_tree())
			check(sun.shadow_enabled and not _fx.visible, "«Среднее»: тени без постобработки (экономия на телефоне)")
			IslandVegetation.set_far_view(get_tree(), true)
			var g := get_tree().get_nodes_in_group("veg_grass")[0] as GeometryInstance3D
			check(g.visibility_range_end == 0.0, "вид издалека: дальность травы не ограничена")
			IslandVegetation.set_far_view(get_tree(), false)
			check(g.visibility_range_end > 0.0, "обычный вид: дальность травы ограничена")
			SettingsMenu.open(main.hud)
			check(main.hud.is_window_open(), "окно настроек открыто")
			wait = 5
			step = 2
		2:
			main.hud.close_window()
			# Вернуть настройки как было
			Quality.set_level(_old_level, _had_cfg)
			Quality.set_fps_limit(Quality.DEFAULT_FPS, _had_cfg)
			if not _had_cfg:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
			ok_done()


func _sun() -> DirectionalLight3D:
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		return n as DirectionalLight3D
	return null
