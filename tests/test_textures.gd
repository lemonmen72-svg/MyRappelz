extends "res://tests/test_base.gd"
## Рисованные текстуры окружения (WorldTextures, assets/textures, tools/gen_textures.py):
## все текстуры загружаются (512×512); у материала земли, построек и настила моста выставлены
## текстуры и флаги по качеству: «Низкое» — без текстур, «Среднее» — с текстурами (простые проекции),
## «Высокое» — с текстурами, triplanar и второй выборкой против повтора. Детали моделей помечены
## номером текстуры в альфе цвета вершин (стены — штукатурка, крыши — черепица/солома, доски, камень).

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
			# Кодирование номера текстуры в альфе цвета вершины
			for layer in range(0, 7):
				var a := WorldTextures.layer_alpha(layer)
				# 8 бит на канал в меше: проверяем декодирование после округления до 1/255
				var a8 := roundf(a * 255.0) / 255.0
				check(roundi((1.0 - a8) * 16.0) == layer, "номер текстуры %d переживает 8-битную альфу" % layer)
			# Детали моделей помечены
			var house := _layers("town_house")
			for layer in [WorldTextures.WOOD, WorldTextures.STONE, WorldTextures.PLASTER, WorldTextures.TILES]:
				check(house.has(layer), "дом города: деталь с текстурой %d (есть: %s)" % [layer, house.keys()])
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


## Номера текстур в альфе цветов вершин модели (по всем поверхностям).
func _layers(kind: String) -> Dictionary:
	var res := {}
	var kit := PoiModels.get_kit(kind)
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
