extends "res://tests/test_base.gd"
## Скриншоты подземелья для Максима (локально, под xvfb, не в списке автотестов): портал у пещеры острова, затем по
## паре кадров на зал подземелья — общий сверху и ближе под углом. Кадры — в user://dungeon_shots/ (или SHOTS_DIR).
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility --rendering-driver opengl3 \
##   --fixed-fps 30 --path . res://tests/runner.tscn -- res://tests/dungeon_shots.gd

## [имя кадра, x, z героя, поворот камеры°, наклон°, расстояние]
const SHOTS := [
	["01_vhod_obshiy", -72.0, -12.0, 20.0, 62.0, 22.0],
	["02_vhod_portal", -74.0, -5.0, 170.0, 24.0, 10.0],
	["03_kanal_mosty", -32.0, -8.0, 180.0, 45.0, 18.0],
	["04_altar_obshiy", -45.5, -38.0, 0.0, 50.0, 22.0],
	["05_altar_blizko", -45.5, -47.0, 0.0, 25.0, 12.0],
	["06_sklep_obshiy", 8.0, -34.0, 0.0, 60.0, 22.0],
	["07_sklep_blizko", 12.0, -40.0, 330.0, 26.0, 12.0],
	["08_goblin_obshiy", 60.0, -40.0, 0.0, 58.0, 22.0],
	["09_goblin_blizko", 64.0, -42.0, 20.0, 26.0, 12.0],
	["10_shahta", 46.0, -16.0, 270.0, 35.0, 13.0],
	["11_sokrovish_obshiy", -64.0, 18.0, 180.0, 58.0, 20.0],
	["12_sokrovish_blizko", -66.0, 22.0, 160.0, 26.0, 10.0],
	["13_prichal", -36.0, 21.0, 270.0, 42.0, 20.0],
	["14_mostki", -10.0, 33.0, 270.0, 38.0, 20.0],
	["15_korabl_obshiy", 41.0, 23.2, 340.0, 62.0, 22.0],
	["16_korabl_blizko", 36.0, 25.6, 298.0, 30.0, 11.0],
]

var idx := 0
var dir := ""


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 20


func before_start() -> void:
	Dungeon.force_open = true
	AdminPanel.god = true
	dir = OS.get_environment("SHOTS_DIR")
	if dir == "":
		dir = ProjectSettings.globalize_path("user://dungeon_shots")
	DirAccess.make_dir_recursive_absolute(dir)


func run_step() -> void:
	match step:
		0:
			# Остров: портал у пещеры
			var pt: Portal = main.get("portal")
			var ep := pt.exit_point()
			main.player.global_position = main.world.ground(ep.x, ep.z, 0.2)
			main.cam_yaw = pt.rotation.y + 0.45
			main.cam_pitch = deg_to_rad(22.0)
			main.cam_dist = 11.0
			main.hud.visible = false
			wait = 90
			step = 1
		1:
			_save("00_ostrov_portal_u_peshery")
			main.travel("dungeon")
			step = 2
		2:
			if main.get("world") == null or not (main.world is DungeonWorld) or not bool(main.get("_started")):
				return
			main.hud.visible = false
			wait = 30
			step = 3
		3:
			# SHOTS_ONLY=13,14 — только кадры с этими номерами
			var only := OS.get_environment("SHOTS_ONLY")
			while idx < SHOTS.size() and only != "" and not only.split(",").has(String((SHOTS[idx] as Array)[0]).left(2)):
				idx += 1
			if idx >= SHOTS.size():
				ok_done()
				return
			var s: Array = SHOTS[idx]
			main.player.global_position = main.world.ground(float(s[1]), float(s[2]), 0.2)
			main.cam_yaw = deg_to_rad(float(s[3]))
			main.cam_pitch = deg_to_rad(float(s[4]))
			main.cam_dist = float(s[5])
			main.cam_focus = Vector3.INF
			wait = 45
			step = 4
		4:
			_save(String((SHOTS[idx] as Array)[0]))
			idx += 1
			step = 3


func _save(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := dir.path_join(n + ".png")
	img.save_png(path)
	print("[OK] кадр " + path)
