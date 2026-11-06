extends SceneTree
## Картинки каталога редактора объектов подземелья (DungeonEditor.CATALOG): assets/icons/props/<id>.png — снимок
## модели 3/4 спереди-справа, 128×128, прозрачный фон. Запуск (нужен экран — xvfb):
##   xvfb-run -a godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . \
##     -s tools/render_prop_thumbs.gd
## затем godot --headless --path . --import (новые .png.import).

const OUT := "res://assets/icons/props/"
const SIZE := 256

func _initialize() -> void:
	_run()

func _run() -> void:
	Assets._embedded = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.85)
	e.ambient_light_energy = 0.9
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	var ids: Array = []
	for g in DungeonEditor.CATALOG:
		ids.append_array((g as Array)[1])
	var n := 0
	for idv in ids:
		var id := String(idv)
		if not PropAsset.has(id):
			print("нет модели ", id)
			continue
		mi.mesh = PropAsset.mesh(id)
		mi.material_override = PropAsset.material(PropAsset.page(id))
		var ab := mi.mesh.get_aabb()
		var c := ab.get_center()
		var r := ab.size.length() * 0.5
		var dir := Vector3(0.55, 0.62, 1.0).normalized()
		var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * 1.0
		cam.look_at_from_position(c + dir * dist, c, Vector3.UP)
		cam.near = 0.05
		cam.far = dist * 4.0
		for k in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
		n += 1
	print("THUMBS ", n)
	quit()
