extends "res://tests/test_base.gd"
## Модели стадий эволюции и волк «Обычной» редкости:
## у пантеры, фазана, черепахи и волка свои файлы моделей 1/2/3 стадии (<вид>, <вид>_2, <вид>_3), в каждой
## все 7 клипов; питомец на 2-й и 3-й стадии строит модель своей стадии (без оттенка и без нимба), при эволюции
## модель меняется, окно существа показывает модель стадии; дикие звери — на модели 1-й стадии.
## Редкость «Обычный» (uncommon): название, ранг, синяя карта; дикий волк сильнее базового зверя того же уровня,
## питомец-волк — с силой редкости, Ловкость — его главный стат; у базовых видов сила 1.0.

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


## Дикий волк сильнее базового зверя (кабана) того же уровня: HP, атака, опыт.
func _check_wild() -> void:
	for lvl in [3, 5]:
		var w := Mob.new()
		w.setup("wolf", -1, Vector3.ZERO, lvl)
		var b := Mob.new()
		b.setup("boar", -1, Vector3.ZERO, lvl)
		check(w.rarity == "uncommon", "дикий волк — «Обычный»")
		check(float(w.max_hp) >= float(b.max_hp) * 1.15 and w.atk > b.atk and w.xp_reward > b.xp_reward,
			"ур.%d: волк сильнее кабана — HP %d/%d, атака %d/%d, опыт %d/%d" % [lvl, w.max_hp, b.max_hp, w.atk, b.atk,
			w.xp_reward, b.xp_reward])
		w.free()
		b.free()
	var m := find_mob("wolf")
	check(m != null, "волк есть в мире")
	if m != null:
		check(m._asset != null and m._asset.species == "wolf", "дикий волк в мире — модель wolf (1-я стадия)")
		check(m.max_hp > int(MobData.get_type("wolf")["hp"]) or m.level != int(MobData.get_type("wolf")["level"]),
			"у дикого волка HP с силой редкости: %d" % m.max_hp)


func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w != null and is_instance_valid(w):
		for n in w.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
	return t
