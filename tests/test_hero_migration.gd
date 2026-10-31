extends "res://tests/test_base.gd"
## Перевод старого сохранения: герой «Люди · Воин» 6-го уровня (как у Максима на телефоне) загружается
## при запуске игры и становится тёмной эльфийкой-Наёмником. Уровень, опыт, золото, сумка и питомцы на месте,
## выдан набор оружия Наёмника и надеты парные мечи, JP — как будто копились с 1 уровня, стартовые умения на
## кнопках, есть MP и 7 статов, сообщение игроку при входе; окно героя — вкладки древа со значками из
## assets/icons/skills (загрузка через ResourceLoader — так же, как в APK). Повторная загрузка — без сообщения.

const OLD_LEVEL := 6
const OLD_GOLD := 345
const OLD_XP := 40


## Вместо нового персонажа — файл сохранения старой версии; мир загрузит его сам (Game.load_game в main).
func before_start() -> void:
	var old := {
		"version": 1, "name": "Максим", "race": "human", "class": "warrior",
		"level": OLD_LEVEL, "xp": OLD_XP, "gold": OLD_GOLD,
		"inventory": {"hp_potion": 4, "crystal_common": 2, "crystal_rare": 1, "boar_tusk": 5},
		"weapon": "",
		"hero": {"jp": 7, "jp_part": 0.5, "skills": {"cleave": 1, "war_cry": 1}, "toggles": {},
			"slots": ["cleave", "war_cry", "", ""]},
		"pets": [
			{"species": "wolf", "name": "Серохвост", "level": 4, "xp": 3, "hp": -1, "dead": false},
			{"species": "bear", "name": "Косолапик", "level": 2},
		],
		"active_pet": -1,
	}
	var f := FileAccess.open(game.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old, "\t"))
	f.close()
	game.reset()


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(game.has_character and game.char_name == "Максим", "старое сохранение загружено при запуске")
			check(game.race_id == "dark_elf" and game.class_id == "assassin", "воин стал Наёмником (тёмные эльфы)")
			check(game.job_changed and game.job_level_at_change == 0, "профессия уже получена (без сверх-эволюции)")
			# Редкий кристалл души → зеркальная карта + 30 зол.
			check(game.level == OLD_LEVEL and game.xp == OLD_XP and game.gold == OLD_GOLD + 30,
				"уровень, опыт и золото сохранены (+30 зол. за редкий кристалл): %d" % game.gold)
			var inv: Inventory = game.inventory
			check(inv.count("hp_potion") == 4 and inv.count("mirror_card") == 3 and inv.count("boar_tusk") == 5,
				"сумка сохранена, кристаллы души стали зеркальными картами")
			check(not inv.has("crystal_common") and not inv.has("crystal_rare"), "кристаллов в сумке нет")
			for id in ItemData.STARTER_WEAPONS["assassin"]:
				check(inv.has(String(id)), "выдано: %s" % ItemData.item_name(String(id)))
			check(game.weapon == "dual_swords_starter" and player.weapon_kind == "dual_swords", "надеты парные мечи")
			check(game.pets.size() == 2 and String(game.pets[0]["name"]) == "Серохвост"
				and String(game.pets[1]["species"]) == "panther", "питомцы сохранены (старый вид переведён)")
			var rec: Dictionary = game.hero
			check(int(rec["jp"]) == HeroSkills.default_jp(OLD_LEVEL), "JP как будто копились с 1 уровня: %d" % int(rec["jp"]))
			check(HeroSkills.skill_level(rec, "backstab") == 1 and HeroSkills.skill_level(rec, "shadow_step") == 1
				and HeroSkills.skill_level(rec, "cleave") == 0, "стартовые умения Наёмника, умений воина нет")
			check(player.skill_id("skill1") == "backstab" and player.skill_id("skill2") == "shadow_step",
				"на кнопках «Удар в спину» и «Шаг тени»")
			check(main.hud.button_text("skill1") == "Удар в спину" and not main.hud.is_blocked("skill1"),
				"кнопка 1 в HUD: «%s»" % main.hud.button_text("skill1"))
			check(player.max_mp > 0 and main.hud._mp_bar.visible, "MP %d и полоска MP в HUD" % player.max_mp)
			var d := HeroStats.derived("assassin", OLD_LEVEL)
			check(player.max_hp == int(d["max_hp"]) and player.eva > 0.0 and player.accuracy > 0,
				"статы Наёмника %d ур.: HP %d, уклонение %.1f%%, точность %d" % [OLD_LEVEL, player.max_hp,
				player.eva * 100.0, player.accuracy])
			check(main.hud._msg_label.text.contains("Наёмник") and game.load_note == "",
				"сообщение при входе: %s" % main.hud._msg_label.text)
			check(player.global_position.distance_to(main.world.spawn_point("dark_elf")) < 3.0, "старт в деревне тёмных эльфов")
			step = 1
		1:
			# Окно героя: 3 вкладки древа, значки из файлов (как в собранной игре — через ResourceLoader)
			var missing: Array = []
			for id in HeroSkills.list_for("assassin"):
				if SkillTree.load_icon(HeroSkills.icon_path(String(id))) == null:
					missing.append(String(id))
			check(missing.is_empty(), "все %d значков умений грузятся (нет: %s)" % [HeroSkills.list_for("assassin").size(), missing])
			var hw: CharacterWindow = main.hero_window
			check(hw.open("hero") and hw.is_open(), "окно героя открыто")
			for k in ["tab_common", "tab_blades", "tab_crossbow"]:
				check(hw.buttons.has(k), "вкладка %s" % k)
			for id in ItemData.STARTER_WEAPONS["assassin"]:
				check(hw.buttons.has("weapon_" + String(id)), "выбор оружия: %s" % String(id))
			hw.buttons["tab_blades"].pressed.emit()
			check(hw.tree != null and hw.tree.icons.size() == HeroSkills.list_tab("assassin", "blades").size(),
				"древо «Мечи и кинжалы»: %d значков" % (hw.tree.icons.size() if hw.tree != null else 0))
			var with_pic := 0
			for id in hw.tree.icons:
				if not (hw.tree.icons[id] as Control).find_children("*", "TextureRect", true, false).is_empty():
					with_pic += 1
			check(with_pic > 0, "в древе значки-картинки: %d" % with_pic)
			main.hud.close_window()
			# Сохранение уже в новом виде; повторная загрузка — без сообщения о переводе
			check(game.save_game(), "игра сохранена")
			var txt := FileAccess.get_file_as_string(game.save_path)
			var saved: Variant = JSON.parse_string(txt)
			check(saved is Dictionary and String((saved as Dictionary).get("class", "")) == "assassin",
				"в сохранении — Наёмник")
			check(game.load_game() and game.load_note == "" and game.class_id == "assassin", "повторная загрузка без перевода")
			check(int(game.hero["jp"]) == HeroSkills.default_jp(OLD_LEVEL), "JP после повторной загрузки те же")
			ok_done()
