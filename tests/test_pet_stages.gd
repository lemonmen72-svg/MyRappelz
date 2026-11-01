extends "res://tests/test_base.gd"
## Модели стадий эволюции и волк «Обычной» редкости:
## у пантеры, фазана, черепахи и волка свои файлы моделей 1/2/3 стадии (<вид>, <вид>_2, <вид>_3), в каждой
## все 7 клипов; питомец на 2-й и 3-й стадии строит модель своей стадии (без оттенка и без нимба), при эволюции
## модель меняется, окно существа показывает модель стадии; дикие звери — на модели 1-й стадии.
## Редкость «Обычный» (uncommon): название, ранг, синяя карта; дикий волк сильнее базового зверя того же уровня,
## питомец-волк — с силой редкости, Ловкость — его главный стат; у базовых видов сила 1.0.
## UV моделей зверей (_check_uv): нет треугольников, растянутых через атлас (у centaur_3 после упрощения «по сваренным
## позициям» было 14 % — пёстрые клочки чужих частей текстуры на теле); та же мера, что uv_check в prepare_creatures.py.

const STAGED := ["panther", "pheasant", "turtle", "wolf"]

var pet_idx := -1


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	pet_idx = game.add_pet("panther", PetData.stage_name("panther", 14), 14)
	game.active_pet = pet_idx


func run_step() -> void:
	var pm: PetManager = main.pets
	match step:
		0:
			_check_files()
			_check_uv()
			_check_rarity()
			_check_wild()
			step = 1
		1:
			# Питомец 1-й стадии (ур. 14) — модель «panther»
			var pet: Pet = pm.active_pet
			check(pet != null and pet.species == "panther" and pet.stage == 0, "призвана пантера 1-й стадии")
			check(pet.model_id == "panther" and pet._asset != null and pet._asset.species == "panther",
				"1-я стадия: модель panther (%s)" % pet.model_id)
			check(pet.find_child("Halo", true, false) == null, "нимба на 1-й стадии нет")
			# До 15 уровня — эволюция во 2-ю стадию: модель меняется на panther_2
			pet.gain_xp(PetData.xp_to_next(pet.level) - pet.xp)
			check(pet.level == 15 and pet.stage == 1, "эволюция: ур. %d, стадия %d" % [pet.level, pet.stage + 1])
			check(pet.model_id == "panther_2" and pet._asset != null and pet._asset.species == "panther_2",
				"2-я стадия: модель panther_2 (%s)" % pet.model_id)
			check(pet._asset.stage_model and pet._asset.material.albedo_color.is_equal_approx(Color.WHITE),
				"у модели стадии текстура без оттенка")
			check(is_equal_approx(pet._height, CreatureModels.height("panther_2", PetData.stage_scale("panther", 15))),
				"высота подписи — по модели стадии")
			wait = 5
			step = 2
		2:
			var pet: Pet = pm.active_pet
			var models := 0
			for c in pet.get_children():
				if c is Node3D and CreatureModels.asset_of(c as Node3D) != null:
					models += 1
			check(models == 1, "после эволюции у питомца одна модель (старая удалена): %d" % models)
			# До 30 уровня — 3-я стадия: panther_3, без нимба и сияния (стадию видно по самой модели)
			while pet.level < 30:
				pet.gain_xp(PetData.xp_to_next(pet.level) - pet.xp)
			check(pet.stage == 2 and pet.model_id == "panther_3" and pet._asset.species == "panther_3",
				"3-я стадия: модель panther_3 (%s)" % pet.model_id)
			check(pet.find_child("Halo", true, false) == null and pet.find_child("Aura", true, false) == null,
				"у модели 3-й стадии нет процедурного нимба и сияния")
			check(pet.find_child("Charm", true, false) != null, "самоцвет роли над головой остался")
			check(String(game.pets[pet_idx]["species"]) == "panther" and int(game.pets[pet_idx]["level"]) == 30,
				"запись питомца: вид прежний, уровень 30")
			wait = 5
			step = 3
		3:
			# Окно существа: превью — модель 3-й стадии
			main._on_action("creature_window")
			var cw: CreatureWindow = pm.creature
			check(cw.is_open(), "окно существа открыто")
			var ca := CreatureModels.asset_of(cw._holder)
			check(ca != null and ca.species == "panther_3", "превью в окне существа — panther_3 (%s)"
				% (ca.species if ca != null else "нет"))
			main.hud.close_window()
			# Волк-питомец: окно показывает редкость «Обычный»
			var wi: int = game.add_pet("wolf", PetData.stage_name("wolf", 30), 30)
			check(cw.open(wi, "stats"), "окно существа волка открыто")
			check(_window_text().contains("Обычный"), "в окне существа волка редкость «Обычный»")
			var wa := CreatureModels.asset_of(cw._holder)
			check(wa != null and wa.species == "wolf_3", "превью волка 3-й стадии — wolf_3")
			main.hud.close_window()
			ok_done()


## Файлы моделей стадий и их клипы: строим каждую модель так же, как питомца.
func _check_files() -> void:
	var box := Node3D.new()
	main.add_child(box)
	for sp in STAGED:
		var id := String(sp)
		for st in 3:
			var want := id if st == 0 else "%s_%d" % [id, st + 1]
			check(ResourceLoader.exists(CreatureAsset.path_for(want)), "файл модели %s есть" % want)
			check(CreatureAsset.model_for(id, st) == want, "стадия %d вида %s → %s" % [st + 1, id, CreatureAsset.model_for(id, st)])
			check(CreatureAsset.species_of(want) == id and CreatureAsset.is_asset_species(want), "%s — модель вида %s" % [want, id])
			var lvl := int(PetData.STAGE_LEVELS[st])
			var sc := PetData.stage_scale(id, lvl)
			var n := Node3D.new()
			box.add_child(n)
			CreatureModels.build(n, id, PetData.stage_color(id, lvl), sc, PetData.asset_tint(id, lvl), st)
			CreatureModels.decorate_pet(n, id, sc, st, PetData.role(id))
			var ca := CreatureModels.asset_of(n)
			check(ca != null and ca.species == want, "питомец %s стадии %d — модель %s" % [id, st + 1, want])
			if ca == null:
				continue
			for k in CreatureAsset.CLIPS:
				check(ca.clips.has(k), "у модели %s есть клип %s (%s)" % [want, k, ca.clips])
			check(ca.skeleton != null and ca.anim != null, "у модели %s скелет и анимации" % want)
			var inf := CreatureAsset.info_for(want)
			check(float(inf["height"]) > 0.3 and (inf["clips"] as Dictionary).size() == 7, "размеры и клипы %s в creatures.json" % want)
			check(n.find_child("Halo", true, false) == null, "у %s нет нимба (своя модель или 1-я стадия)" % want)
			check(n.find_child("Charm", true, false) != null, "самоцвет роли у %s" % want)
			check(ca.stage_model == (st > 0), "%s: своя модель стадии — %s" % [want, ca.stage_model])
			if st > 0:
				check(ca.material.albedo_color.is_equal_approx(Color.WHITE), "%s без оттенка стадии" % want)
	# Без своей модели стадии (кабан) — как прежде: модель вида и украшения стадии
	check(CreatureAsset.model_for("boar", 2) == "boar" and CreatureAsset.model_for("golem", 1) == "golem",
		"у кабана и стража моделей стадий нет")
	# Дикий зверь (stage 0 по умолчанию) — модель 1-й стадии
	var w := Node3D.new()
	box.add_child(w)
	CreatureModels.build(w, "wolf", MobData.get_type("wolf")["color"], 1.0)
	var wa := CreatureModels.asset_of(w)
	check(wa != null and wa.species == "wolf" and not wa.stage_model, "дикий волк — модель wolf из файла")
	box.queue_free()


## UV всех зверей из creatures.json: доля треугольников, растянутых через атлас (разброс UV > 0.25 и плотность UV
## на метр в 4 раза выше средней по мешу), меньше 0.5 %; 99-й перцентиль разброса у centaur_3 — меньше 0.1.
func _check_uv() -> void:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(CreatureAsset.INFO_PATH))
	check(info is Dictionary and (info as Dictionary).has("centaur_3"), "creatures.json читается, в нём centaur_3")
	if not info is Dictionary:
		return
	for k in (info as Dictionary).keys():
		var id := String(k)
		var path := CreatureAsset.path_for(id)
		if not Assets.exists(path):
			continue
		var ps := load(path) as PackedScene
		check(ps != null, "%s: модель загружается" % id)
		if ps == null:
			continue
		var root := ps.instantiate()
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() > 0, "%s: есть меш" % id)
		var bad := 0
		var total := 0
		var spreads := PackedFloat32Array()
		for mi in meshes:
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				if uvs.size() != verts.size() or idx.is_empty():
					continue
				var area_uv := 0.0
				var area_3d := 0.0
				var t := 0
				while t + 2 < idx.size():
					var a := uvs[idx[t]]
					var b := uvs[idx[t + 1]]
					var c := uvs[idx[t + 2]]
					area_uv += absf((b - a).cross(c - a)) * 0.5
					var p := verts[idx[t]]
					area_3d += (verts[idx[t + 1]] - p).cross(verts[idx[t + 2]] - p).length() * 0.5
					t += 3
				var dens := sqrt(area_uv / maxf(area_3d, 1e-12))
				t = 0
				while t + 2 < idx.size():
					var ua := uvs[idx[t]]
					var ub := uvs[idx[t + 1]]
					var uc := uvs[idx[t + 2]]
					var sp := maxf(maxf(ua.x, maxf(ub.x, uc.x)) - minf(ua.x, minf(ub.x, uc.x)),
						maxf(ua.y, maxf(ub.y, uc.y)) - minf(ua.y, minf(ub.y, uc.y)))
					spreads.append(sp)
					var pa := verts[idx[t]]
					var pb := verts[idx[t + 1]]
					var pc := verts[idx[t + 2]]
					var per_uv := ua.distance_to(ub) + ub.distance_to(uc) + uc.distance_to(ua)
					var per_3d := pa.distance_to(pb) + pb.distance_to(pc) + pc.distance_to(pa)
					if sp > 0.25 and per_uv / maxf(per_3d, 1e-9) > 4.0 * dens:
						bad += 1
					total += 1
					t += 3
		root.free()
		check(total > 0, "%s: треугольники с UV есть" % id)
		if total == 0:
			continue
		var share := float(bad) / float(total)
		check(share < 0.005, "%s: растянутых через атлас треугольников %.2f %% (< 0.5 %%)" % [id, share * 100.0])
		if id == "centaur_3":
			spreads.sort()
			var p99 := spreads[int(spreads.size() * 0.99)]
			check(p99 < 0.1, "centaur_3: 99-й перцентиль разброса UV в треугольнике %.3f (< 0.1)" % p99)


## Редкость «Обычный»: название, ранг, тир карты, сила; базовые виды без изменений.
func _check_rarity() -> void:
	check(MobData.rarity_label("uncommon") == "Обычный" and MobData.rarity_name("wolf") == "Обычный", "волк — «Обычный»")
	check(MobData.RARITY_TIER["common"] < MobData.RARITY_TIER["uncommon"]
		and MobData.RARITY_TIER["uncommon"] < MobData.RARITY_TIER["rare"]
		and MobData.RARITY_TIER["rare"] < MobData.RARITY_TIER["unique"], "ранги: базовый < обычный < редкий < уникальный")
	check(MobData.rarity_tier("wolf") > MobData.rarity_tier("panther"), "волк по рангу выше пантеры")
	check(MobData.card_tier("wolf") == "rare" and ItemData.card_tier("card_wolf") == "rare", "карта волка — синяя")
	check(is_equal_approx(Taming.CHANCE["rare"], 0.45), "шанс синей карты 45%")
	check(ItemData.grade_name("card_wolf") == "Синяя (обычная)", "подпись карты волка: " + ItemData.grade_name("card_wolf"))
	check(not MobData.rarity_color("uncommon").is_equal_approx(MobData.rarity_color("common")), "у «Обычного» свой цвет подписи")
	for sp in ["panther", "pheasant", "turtle", "boar", "golem"]:
		check(is_equal_approx(MobData.power(sp), 1.0), "сила %s — 1.0 (баланс прежний)" % sp)
	check(MobData.power("wolf") > 1.1, "сила волка %.2f" % MobData.power("wolf"))
	check(MobData.RARITY_POWER["common"] < MobData.RARITY_POWER["uncommon"]
		and MobData.RARITY_POWER["uncommon"] < MobData.RARITY_POWER["rare"]
		and MobData.RARITY_POWER["rare"] < MobData.RARITY_POWER["unique"], "сила растёт с редкостью")
	# Питомец: прежние числа базовых видов на 1 ур. (PetData.SPECIES), у волка — ×сила редкости
	for sp in ["panther", "pheasant", "turtle", "boar"]:
		var d := PetStats.derived(sp, 1)
		var s := PetData.get_species(sp)
		check(int(d["max_hp"]) == int(s["hp"]) and int(d["atk"]) == int(s["atk"]), "%s ур.1: HP %d, атака %d — как прежде"
			% [sp, int(d["max_hp"]), int(d["atk"])])
	var wd := PetStats.derived("wolf", 1)
	var ws := PetData.get_species("wolf")
	check(int(wd["max_hp"]) == roundi(float(ws["hp"]) * MobData.power("wolf")), "волк ур.1: HP ×сила редкости (%d)" % int(wd["max_hp"]))
	# «Существо ловкости»: Ловкость — самый высокий стат на всех стадиях
	for lvl in [1, 14, 15, 29, 30, 50]:
		var st := PetStats.base_stats("wolf", lvl)
		var best := ""
		for k in PetStats.STATS:
			if best == "" or int(st[k]) > int(st[best]):
				best = String(k)
		check(best == "agi", "волк ур.%d: главный стат — %s (Ловкость %d, Сила %d)" % [lvl, best, int(st["agi"]), int(st["str"])])
	var bd := PetStats.derived("boar", 30)
	var wd30 := PetStats.derived("wolf", 30)
	check(float(wd30["eva"]) > float(bd["eva"]) and int(wd30["aspd"]) > int(bd["aspd"]),
		"волк уклоняется и бьёт быстрее кабана (уклон %.1f / %.1f, скорость %d / %d)"
		% [float(wd30["eva"]), float(bd["eva"]), int(wd30["aspd"]), int(bd["aspd"])])


## Дикий волк сильнее базового зверя (кабана) того же уровня: «эффективная сила» против героя (Combat), опыт.
## На высоких уровнях дикие звери — модели старших стадий (MobStats.stage_for).
func _check_wild() -> void:
	var hprof := Combat.profile_of(main.player)
	for lvl in [3, 5]:
		var w := Mob.new()
		w.setup("wolf", -1, Vector3.ZERO, lvl)
		var b := Mob.new()
		b.setup("boar", -1, Vector3.ZERO, lvl)
		check(w.rarity == "uncommon", "дикий волк — «Обычный»")
		var rw := Combat.power_ratio(hprof, Combat.profile_of(w))
		var rb := Combat.power_ratio(hprof, Combat.profile_of(b))
		check(rw > rb * 1.15 and w.xp_reward > b.xp_reward,
			"ур.%d: волк сильнее кабана — сила %.2f / %.2f, опыт %d/%d" % [lvl, rw, rb, w.xp_reward, b.xp_reward])
		w.free()
		b.free()
	var m := find_mob("wolf")
	check(m != null, "волк есть в мире")
	if m != null:
		var want := CreatureAsset.model_for("wolf", MobStats.stage_for("wolf", m.level))
		check(m._asset != null and m._asset.species == want, "дикий волк %d ур. в мире — модель %s" % [m.level, want])
		check(m.max_hp == int(MobStats.derived("wolf", m.level)["max_hp"]), "у дикого волка HP по статам: %d" % m.max_hp)
	check(MobStats.stage_for("wolf", 5) == 0 and MobStats.stage_for("wolf", 12) == 1 and MobStats.stage_for("wolf", 22) == 2,
		"дикие звери: с 12 ур. — 2-я стадия, с 22 — 3-я")
	var hi := Mob.new()
	hi.setup("wolf", -1, Vector3.ZERO, 24)
	check(hi.model_id == "wolf_3" and hi.body_scale > 1.3, "волк 24 ур. — модель wolf_3, крупнее (×%.2f)" % hi.body_scale)
	hi.free()


func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w != null and is_instance_valid(w):
		for n in w.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
	return t
