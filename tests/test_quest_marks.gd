extends "res://tests/test_base.gd"
## Значки заданий: над жителем — «!» (можно взять), «?» (взято, не выполнено), «=» (выполнено — можно сдать),
## ничего — когда заданий нет; картинка UiIcons (quest_available / quest_active / quest_complete), если файл есть,
## иначе буква. Над зверем — красный значок (UiIcons quest_target), пока он нужен по взятому заданию: цель kill
## (фазаны старосты, вожак-босс охотницы) и collect с drop_from (шкуры волков); цель выполнена — значок исчезает.
## Значок не перекрывает подпись над головой.


func race_class() -> Array:
	return ["human", "wanderer"]


var _boss: Mob = null


func run_step() -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	match step:
		0:
			wait = 10
			step = 1
		1:
			var elder := npcs.npc("elder_human")
			check(elder != null, "староста людей стоит")
			npcs.refresh_marks()
			_check_mark(elder, "offer", "!", "староста: можно взять «Тревогу в округе»")
			_check_mark(npcs.kirk, "offer", "!", "Кирк: можно взять «Первую карту»")
			_check_mark(npcs.npc("smith"), "", "", "у кузнеца заданий нет")
			# Значок над именем, не на нём
			var lbl := elder.get_node("NameLabel") as Label3D
			var name_top := lbl.position.y + 0.5 * float(lbl.font_size) * lbl.pixel_size
			check(elder.mark_height() - 0.5 * Npc.MARK_H * UiScale.k() >= name_top - 0.005,
				"значок над именем: центр %.2f м, верх имени %.2f м" % [elder.mark_height(), name_top])
			# Взято — «?», фазаны помечены, волки нет
			check(q.accept("elder_hunt"), "задание «Тревога в округе» взято")
			npcs.refresh_marks()
			_check_mark(elder, "active", "?", "староста: задание взято, не выполнено")
			var ph := find_mob("pheasant")
			var wolf := find_mob("wolf")
			check(ph != null and wolf != null, "фазан и волк в мире")
			check(q.target_species().has("pheasant") and not q.target_species().has("wolf"), "цели: фазаны %s" % [q.target_species()])
			check(ph.quest_target and ph.quest_mark_visible(), "над фазаном красный значок")
			check(not wolf.quest_mark_visible(), "над волком значка нет")
			var ov: Overhead = ph._over
			check(ov.mark.texture != null and ov.mark.position.y - ov.mark_height() * 0.5 > ph._label.position.y,
				"значок зверя — над подписью «%s»" % ph._label.text)
			# Три победы — выполнено: «=», значок над фазанами пропал
			for i in 3:
				q.on_mob_killed(ph)
			check(q.is_ready("elder_hunt"), "три фазана — задание выполнено")
			npcs.refresh_marks()
			_check_mark(elder, "ready", "=", "староста: выполнено, можно сдать")
			check(not ph.quest_mark_visible(), "над фазаном значок пропал")
			check(q.complete("elder_hunt"), "задание сдано")
			npcs.refresh_marks()
			_check_mark(elder, "", "", "староста: следующее задание — со 2 ур., значка нет")
			game.level = 2
			game.changed.emit()
			npcs.refresh_marks()
			_check_mark(elder, "offer", "!", "староста: на 2 ур. — «Шкуры»")
			check(q.accept("elder_trophies"), "задание «Шкуры» взято")
			npcs.refresh_marks()
			check(wolf.quest_mark_visible(), "над волком красный значок (победить и шкуры)")
			for i in 3:
				q.on_mob_killed(wolf)
			npcs.refresh_marks()
			check(not q.is_ready("elder_trophies") and wolf.quest_mark_visible(),
				"волки побеждены, шкур нет — значок остаётся (квестовая добыча)")
			game.inventory.add("wolf_pelt", 3)
			npcs.refresh_marks()
			check(q.is_ready("elder_trophies") and not wolf.quest_mark_visible(), "шкуры собраны — значок над волком пропал")
			_check_mark(elder, "ready", "=", "староста: «Шкуры» можно сдать")
			# Вожак охотницы: босс помечен, пока не побеждён
			game.quests_active["hunter_boss_pheasant"] = {"progress": [0]}
			q._changed()
			var p: Player = main.player
			_boss = main.spawn_mob("boss_pheasant", 15, p.global_position + Vector3(0, 0, -6), -1)
			wait = 3
			step = 2
		2:
			q.refresh_mob_marks()
			check(is_instance_valid(_boss) and _boss.quest_mark_visible(), "над вожаком из задания охотницы красный значок")
			q.on_mob_killed(_boss)
			q.refresh_mob_marks()
			check(not _boss.quest_mark_visible(), "вожак побеждён — значок пропал")
			_boss.consume()
			# Процедурный значок и картинка: оба дают текстуру
			for id in ["quest_available", "quest_active", "quest_complete", "quest_target"]:
				check(UiIcons.texture(String(id)) != null, "значок %s: %s" % [id, "файл" if UiIcons.has_file(String(id)) else "рисунок"])
			ok_done()


## Значок над жителем n: вид kind, буква text; картинка — если файл значка есть, иначе буква (Label3D).
func _check_mark(n: Npc, kind: String, text: String, what: String) -> void:
	check(n != null, what + ": житель есть")
	if n == null:
		return
	check(n.mark_kind == kind and n.mark_text() == text, "%s: «%s» (%s)" % [what, n.mark_text(), n.mark_kind])
	if kind == "":
		check(not n.mark_shown(), what + ": значка нет")
		return
	var icon_id := String(Npc.MARKS[kind][2])
	var spr := n.get_node("QuestMarkIcon") as Sprite3D
	var lbl := n.get_node("QuestMark") as Label3D
	if UiIcons.has_file(icon_id):
		check(spr.visible and not lbl.visible and spr.texture != null, what + ": картинка " + icon_id)
	else:
		check(lbl.visible and not spr.visible and lbl.text == text, what + ": буква «%s»" % text)
