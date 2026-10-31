extends "res://tests/test_base.gd"
## Рисованные текстуры окружения (WorldTextures, assets/textures — листы Максима, tools/import_texture_sheet.py):
## все текстуры загружаются (512×512), включая новые (лесная подстилка, кладка, кора); у материала земли,
## построек и настила моста выставлены текстуры и флаги по качеству: «Низкое» — без текстур (выборок нет),
## «Среднее» — с текстурами (простые проекции), «Высокое» — с текстурами, triplanar и второй выборкой против
## повтора. Сэмплеров у toon-шейдера не больше 8 (предел GL Compatibility на телефонах). Детали моделей помечены
## номером текстуры в альфе цвета вершин (стены — штукатурка, крыши — черепица/солома, доски, цоколь и колодец —
## кладка, столбы — кора, жерди и перекладины — лежачее бревно). Вес леса запечён по деревьям и лежит в UV2 земли.

var _old_level := Quality.MEDIUM


func run_step() -> void:
	match step:
		0:
			_old_level = Quality.level()
			for tex_name in WorldTextures.ALL:
				var t := WorldTextures.texture(String(tex_name))
				check(t != null, "текстура %s загружена" % tex_name)
				check(t.get_width() == 512 and t.get_height() == 512, "текстура %s 512×512 (%dx%d)" % [
					tex_name, t.get_width(), t.get_height()])
			var w := IslandWorld.current
			check(w != null and w.terrain_material != null, "материал земли создан")
			for tex_name in ["forest", "masonry", "bark"]:
				check(WorldTextures.ALL.has(tex_name), "новая текстура %s в списке" % tex_name)
			# Сэмплеры: toon — albedo_texture + не больше 7 (блоки 0–7), земля — не больше 8
			check(_samplers("res://toon.gdshader") <= 8, "toon.gdshader: сэмплеров %d (≤ 8)" % _samplers("res://toon.gdshader"))
			check(_samplers("res://island_terrain.gdshader") <= 8,
				"island_terrain.gdshader: сэмплеров %d (≤ 8)" % _samplers("res://island_terrain.gdshader"))
			check(WorldTextures.TOON_SAMPLERS.size() + 1 == _samplers("res://toon.gdshader"),
				"toon: все сэмплеры текстур заданы WorldTextures")
			check(WorldTextures.TERRAIN_SAMPLERS.size() == _samplers("res://island_terrain.gdshader"),
				"земля: все сэмплеры текстур заданы WorldTextures")
			# Кодирование номера текстуры в альфе цвета вершины
			for layer in range(0, 16):
				var a := WorldTextures.layer_alpha(layer)
				# 8 бит на канал в меше: проверяем декодирование после округления до 1/255
				var a8 := roundf(a * 255.0) / 255.0
				check(roundi((1.0 - a8) * 16.0) == layer, "номер текстуры %d переживает 8-битную альфу" % layer)
			# Детали моделей помечены
			var house := _layers("town_house")
			for layer in [WorldTextures.WOOD, WorldTextures.MASONRY, WorldTextures.PLASTER, WorldTextures.TILES]:
				check(house.has(layer), "дом города: деталь с текстурой %d (есть: %s)" % [layer, house.keys()])
			check(_layers("human_house_red").has(WorldTextures.MASONRY), "цоколь дома людей — кладка")
			check(_layers("dark_elf_house").has(WorldTextures.MASONRY), "каменные стены тёмных эльфов — кладка")
			check(_layers("lighthouse").has(WorldTextures.MASONRY), "основание маяка — кладка")
			var well := _layers("well")
			check(well.has(WorldTextures.MASONRY), "колодец — кладка (есть: %s)" % [well.keys()])
			check(well.has(WorldTextures.LOG), "ворот колодца — лежачее бревно")
			var dummy := _layers("dummy")
			check(dummy.has(WorldTextures.BARK) and dummy.has(WorldTextures.LOG), "манекен: столб — кора, перекладина — бревно")
			check(_layers("campfire").has(WorldTextures.LOG), "брёвна-скамейки у костра — кора")
			check(_layers("bollard").has(WorldTextures.BARK), "тумба причала — кора")
			# Ограда (как в IslandPois._fence_ring): столбики — кора, жерди — лежачее бревно, без досок
			var fence := PoiModels.Kit.new()
			PoiModels.fence_post(fence, Vector3.ZERO, 1.3, PoiModels.WOOD.darkened(0.25))
			PoiModels.fence_post(fence, Vector3(2.4, 0.1, 0), 1.3, PoiModels.WOOD.darkened(0.25))
			PoiModels.fence_rails(fence, Vector3.ZERO, Vector3(2.4, 0.1, 0), 1.3, PoiModels.WOOD)
			var fl := _kit_layers(fence)
			check(fl.has(WorldTextures.BARK) and fl.has(WorldTextures.LOG) and fl.size() == 2,
				"ограда: столбики — кора, жерди — бревно (есть: %s)" % [fl.keys()])
			check(fence.tex == -1, "ограда не меняет Kit.tex после себя")
			check(house.has(WorldTextures.NONE), "дом города: окна (свечение) без текстуры")
			check(_layers("human_house_thatch").has(WorldTextures.THATCH), "соломенная крыша — солома")
			check(_layers("rock").has(WorldTextures.ROCK), "камень — текстура скалы")
			check(_layers("town_house_b").has(WorldTextures.TILES), "крыша не из палитры — всё равно черепица")
			check(_glow_untextured("town_house"), "светящиеся окна без текстуры")
			# «Среднее»: текстуры включены, простые проекции
			Quality.set_level(Quality.MEDIUM, false)
			Quality.apply(get_tree())
			_check_terrain(w.terrain_material, true, false, "«Среднее»")
			_check_toon(PoiModels.material("toon") as ShaderMaterial, true, false, "«Среднее», постройки")
			_check_toon(PoiModels.material("toon_ol") as ShaderMaterial, true, false, "«Среднее», мелочи")
			var deck := _deck_material()
			check(deck != null, "настил моста — toon-материал")
			if deck != null:
				check(int(deck.get_shader_parameter("tex_layer")) == WorldTextures.WOOD, "настил моста — доски")
				_check_toon(deck, true, false, "«Среднее», мост")
			# Площадь города мощёная (параметры заданы из конфига)
			check(float(w.terrain_material.get_shader_parameter("plaza_radius")) > 5.0, "площадь города задана")
			check(float(w.terrain_material.get_shader_parameter("paved_radius")) > 10.0, "мощёные улицы города")
			# Лесная подстилка: вес леса запечён по деревьям, в городе леса нет, в меше земли есть UV2
			var fmax := 0.0
			var forested := 0
			for f in w.forest_w:
				fmax = maxf(fmax, f)
				if f > 0.5:
					forested += 1
			check(not w.forest_w.is_empty() and fmax > 0.9, "вес леса запечён (макс. %.2f)" % fmax)
			check(forested > 0 and forested * 2 < w.forest_w.size(),
				"лес занимает часть острова (%d из %d клеток)" % [forested, w.forest_w.size()])
			check(w.forest_at(0.0, 0.0) < 0.01, "в центре города леса нет")
			var terr := w.get_node_or_null("Terrain")
			check(terr != null and terr.get_child_count() > 0, "меш земли построен")
			if terr != null and terr.get_child_count() > 0:
				var tm := (terr.get_child(0) as MeshInstance3D).mesh as ArrayMesh
				check(tm != null and (tm.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0,
					"в вершинах земли есть UV2 (вес леса)")
			# «Низкое»: без выборок текстур
			Quality.set_level(Quality.LOW, false)
			Quality.apply(get_tree())
			check(not Quality.textures(), "«Низкое»: Quality.textures() = false")
			check(not bool(w.terrain_material.get_shader_parameter("textures")), "«Низкое»: земля без текстур")
			check(not bool((PoiModels.material("toon") as ShaderMaterial).get_shader_parameter("textures")),
				"«Низкое»: постройки без текстур")
			if deck != null:
				check(not bool(deck.get_shader_parameter("textures")), "«Низкое»: мост без текстур")
			# «Высокое»: текстуры, triplanar, вторая выборка против повтора
			Quality.set_level(Quality.HIGH, false)
			Quality.apply(get_tree())
			_check_terrain(w.terrain_material, true, true, "«Высокое»")
			_check_toon(PoiModels.material("toon") as ShaderMaterial, true, true, "«Высокое», постройки")
			# Новый материал после смены качества сразу получает текущие флаги
			var fresh := PoiModels.toon_material(Color.WHITE, true)
			_check_toon(fresh, true, true, "новый toon-материал на «Высоком»")
			# Вернуть как было (в settings.cfg ничего не записывали)
			Quality.set_level(_old_level, false)
			Quality.apply(get_tree())
			ok_done()


func _check_terrain(m: ShaderMaterial, on: bool, full: bool, what: String) -> void:
	check(bool(m.get_shader_parameter("textures")) == on, what + ": флаг текстур земли = %s" % on)
	check(bool(m.get_shader_parameter("rich")) == full, what + ": полный режим земли = %s" % full)
	for param in WorldTextures.TERRAIN_SAMPLERS:
		check(m.get_shader_parameter(param) is Texture2D, what + ": у земли задана " + String(param))


func _check_toon(m: ShaderMaterial, on: bool, tri: bool, what: String) -> void:
	check(m != null, what + ": материал есть")
	if m == null:
		return
	check(bool(m.get_shader_parameter("textures")) == on, what + ": флаг текстур = %s" % on)
	check(bool(m.get_shader_parameter("tex_triplanar")) == tri, what + ": triplanar = %s" % tri)
	for param in WorldTextures.TOON_SAMPLERS:
		check(m.get_shader_parameter(param) is Texture2D, what + ": задана " + String(param))


## Сколько сэмплеров (текстурных uniform) у шейдера — по тексту (работает и без рендера).
func _samplers(path: String) -> int:
	var sh := load(path) as Shader
	if sh == null:
		return 99
	var re := RegEx.new()
	re.compile("(?m)^\\s*uniform\\s+sampler")
	return re.search_all(sh.code).size()


## Номера текстур в альфе цветов вершин модели (по всем поверхностям).
func _layers(kind: String) -> Dictionary:
	return _kit_layers(PoiModels.get_kit(kind))


func _kit_layers(kit: PoiModels.Kit) -> Dictionary:
	var res := {}
	for key in kit.surfs:
		var s: PoiModels.Surf = kit.surfs[key]
		for c: Color in s.colors:
			res[roundi((1.0 - c.a) * 16.0)] = true
	return res


func _glow_untextured(kind: String) -> bool:
	var kit := PoiModels.get_kit(kind)
	var s: PoiModels.Surf = kit.surfs.get("toon")
	if s == null:
		return false
	var glow := 0
	for i in s.colors.size():
		if s.uv2s[i].y > 0.5:
			glow += 1
			if s.colors[i].a < 0.999:
				return false
	return glow > 0


func _deck_material() -> ShaderMaterial:
	for b in get_tree().get_nodes_in_group("bridges"):
		for n in (b as Node).find_children("*", "MeshInstance3D", true, false):
			var m := (n as MeshInstance3D).material_override as ShaderMaterial
			if m != null:
				return m
	return null
