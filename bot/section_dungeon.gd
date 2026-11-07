extends BotSection
## Раздел «Подземелье» (0.44, просьба Максима «добавь тест подземелья»).
## Портал у пещеры острова: без задания Корвена не пускает (герой остаётся на острове, причина — в сообщении), с
## заданием «Следы у скал» пускает — сцена строится заново только с подземельем (острова и жителей нет, герой у
## портала подземелья, цель «спуститься» засчитана). Зоны монстров (world/dungeon.json mob_zones; быстрый проход —
## QUICK_ZONES): монстры своих видов рядом (поток «В подземелье» поставил их), модели из файлов и оружие в руке (если
## пакет ресурсов загружен). Победа над монстром — опыт и мешочек. Проклятый капитан на палубе корабля: «Клятва
## бездны» (удар по площади) ранит, проклятия ложатся значками (оглушение, ослабления, яд), с половины HP — ярость и
## реплика, победа — добыча. Ногами от портала (джойстиком, путь CardinalWalk — как Кардинал) до залов и от причала по
## мосткам на палубу корабля: застрял — ошибка с местом и снимок. Питомцы подземелья: Скелет (модель и меч), Спрут.
## Свитки главы I — окно с текстом помещается в экран. «В подземелье»: объекты нарезаны по выбранной дальности,
## монстры дальше дальности не живут (если дальность не задана тестом). Портал подземелья возвращает к пещере.
## Редактор расстановки не открывается: при выходе он пишет user://dungeon_layout.json — файл игрока (Максима).

## Зоны монстров (id mob_zones): быстрый и полный проход. Капитан — отдельно.
const QUICK_ZONES := ["dg_crypt", "dg_treasury"]
const FULL_ZONES := ["dg_goblins", "dg_goblin_chief", "dg_mine", "dg_crypt", "dg_dead_knight", "dg_sanctuary",
	"dg_elder_priest", "dg_treasury"]
## Прогулки ногами от портала (id pois): быстрый и полный проход; потом — причал → палуба корабля.
const QUICK_WALKS := ["crypt"]
const FULL_WALKS := ["boss_room", "crypt", "goblin_camp", "mine", "treasury"]
## Свитки главы I (Story.TEXTS).
const QUICK_STORIES := ["goblin_exodus_scroll"]
const FULL_STORIES := ["goblin_exodus_scroll", "priest_order_scroll", "captain_confession"]
## Сколько ждать мир после портала, с.
const WORLD_TIMEOUT := 90.0
## Ждать поток монстров после переноса, с (main._mob_stream — раз в 0.5 с).
const MOB_WAIT := 1.2
## Монстры зоны — ближе её радиуса + этого, м.
const ZONE_MARGIN := 10.0
## Ходьба: дошёл ближе, м; застрял — за STUCK_TIME с сдвинулся меньше STUCK_MOVE м.
const REACH := 1.3
const STUCK_TIME := 3.0
const STUCK_MOVE := 0.5
## Предел одной прогулки, с.
const WALK_LIMIT := 110.0
## Палуба корабля: цель у борта, куда приходит мостик с причала (ось корабля x = 32).
const DECK_GOAL := Vector2(32.0, 31.0)
## Замах «Клятвы бездны» 1.1 с (MobData slam): ждём удара, не паузы (в тесте паузы бота ×0.5)
const SLAM_WAIT := 6.0
## Отойти перед победой: мешочек в LootDrop.PICKUP_RANGE (2.5 м) герой подбирает сам через 0.4 с
const STEP_AWAY := 4.5
## Мешочек лежит на полу или палубе: высота не дальше этого от ног монстра
const DROP_Y_OK := 0.8
const PIER := Vector2(-36.0, 21.4)

var _main0: Node = null
var _exit := Vector3.ZERO
var _cap: Mob = null
var _hp0 := 0
var _maxhp0 := 0
var _uses0 := 0
var _victim: Mob = null
var _victim_at := Vector3.ZERO
var _xp0 := 0
var _drops0 := 0
var _cap_at := Vector3.ZERO
var _walker: CardinalWalk = null
var _walk_name := ""
var _walk_t := 0.0
var _st_t := 0.0
var _st_from := Vector3.ZERO
var _walk_end := false
var _walk_ok := false
var _walks_bad := 0
var _dg0 := -1


func id() -> String:
	return "dungeon"


func _build() -> void:
	do("Подземелье: герой и задания до Корвена", _setup)
	do("Портал у пещеры: без задания", _gate_closed)
	wait(1.5)
	do("Портал: без задания — на острове", _gate_check)
	do("Портал: задание «Следы у скал», вход", _gate_open)
	until("мир подземелья построен", _in_dungeon, WORLD_TIMEOUT)
	do("Подземелье: мир, портал, задание", _world_check)
	for z in (QUICK_ZONES if quick else FULL_ZONES):
		var zid := String(z)
		do("Зона «%s»: перенос" % zid, _zone_go.bind(zid))
		wait(MOB_WAIT)
		do("Зона «%s»: монстры, модели, оружие" % zid, _zone_check.bind(zid))
	do("Монстр: победа", _kill_one)
	wait(0.8)
	do("Монстр: опыт и мешочек", _kill_check)
	do("Проклятый капитан: на палубе", _cap_find)
	wait(MOB_WAIT)
	do("Капитан: «Клятва бездны»", _slam_start)
	until("«Клятва бездны» ударила", _slammed, SLAM_WAIT)
	do("Капитан: удар ранил", _slam_done)
	do("Капитан: проклятия", _curses)
	do("Капитан: ярость и реплики", _enrage)
	do("Капитан: победа", _cap_kill)
	wait(0.8)
	do("Капитан: добыча", _cap_loot)
	for wv in (QUICK_WALKS if quick else FULL_WALKS):
		var wid := String(wv)
		do("Ногами от портала: «%s»" % wid, _walk_poi.bind(wid))
		until("дошёл: «%s»" % wid, _walked, WALK_LIMIT)
		do("Ногами: «%s» — итог" % wid, _walk_done)
	do("Ногами: причал → мостки → палуба корабля", _walk_deck)
	until("дошёл до палубы корабля", _walked, WALK_LIMIT)
	do("Палуба корабля — итог", _walk_done)
	do("Питомец подземелья: Скелет", _pet.bind("skeleton"))
	until("Скелет призван", _pet_up.bind("skeleton"), 5.0)
	do("Скелет: модель и меч", _pet_check.bind("skeleton"))
	if not quick:
		do("Питомец подземелья: Спрут", _pet.bind("octopus"))
		until("Спрут призван", _pet_up.bind("octopus"), 5.0)
		do("Спрут: модель", _pet_check.bind("octopus"))
	for st in (QUICK_STORIES if quick else FULL_STORIES):
		do("Свиток «%s»" % String(st), _story.bind(String(st)))
	do("«В подземелье»: дальность объектов", _props_range)
	do("«В подземелье»: монстры ближе 20 м", _mob_range_start)
	wait(1.5)
	do("«В подземелье»: монстры — итог", _mob_range_check)
	do("Портал подземелья: назад", _back)
	until("вернулись на остров", _on_island, WORLD_TIMEOUT)
	do("Остров: у пещеры", _island_check)


# ---------- Портал ----------

func _setup() -> void:
	hero(Game.class_id, maxi(Game.level, 25))
	no_pets()
	bot.clear_spawned()
	Dungeon.force_open = false
	# Цепочка до Корвена сдана, «Следы у скал» — ещё нет (проверка запрета)
	for qid in ["sage_to_merc", "merc_closed_cave"]:
		Game.quests_done[qid] = 1
	Game.quests_active.erase(QuestData.DUNGEON_QUEST)
	Game.quests_done.erase(QuestData.DUNGEON_QUEST)


func _portal() -> Portal:
	return bot.main.get("portal") as Portal if bot.main != null and is_instance_valid(bot.main) else null


func _world() -> IslandWorld:
	if bot.main == null or not is_instance_valid(bot.main):
		return null
	var w: Variant = bot.main.get("world")
	return w as IslandWorld if w != null and is_instance_valid(w) else null


func _put(p3: Vector3) -> void:
	var p := player()
	var w := _world()
	if p == null or w == null:
		return
	p.global_position = w.ground(p3.x, p3.z, 0.2)
	p.velocity = Vector3.ZERO
	bot.reset_camera()


func _gate_closed() -> void:
	var pt := _portal()
	if not check(pt != null and _world() != null and _world().location() == "island", "портал у пещеры острова есть"):
		return
	var why := Dungeon.enter_block()
	check(why.contains("Корвен"), "без задания портал не пускает: «%s»" % why)
	_main0 = bot.main
	_put(pt.exit_point())
	_put(pt.front_point())
	shot("Podzemelye portal zakryt")


func _gate_check() -> void:
	check(bot.main == _main0 and _world() != null and _world().location() == "island",
		"без задания герой остался на острове (%s)" % last_msg())


func _gate_open() -> void:
	var q := quests()
	if not check(q != null and q.accept(QuestData.DUNGEON_QUEST), "задание «%s» взято" % QuestData.quest_name(QuestData.DUNGEON_QUEST)):
		Dungeon.force_open = true
	check(Dungeon.enter_block() == "", "с заданием портал пускает (%s)" % Dungeon.enter_block())
	var pt := _portal()
	if pt == null:
		return
	_main0 = bot.main
	_put(pt.exit_point())
	_put(pt.front_point())


func _in_dungeon() -> bool:
	var m := bot.main
	if m == null or not is_instance_valid(m) or m == _main0 or not m.is_inside_tree() or not bool(m.get("_started")):
		return false
	return _world() is DungeonWorld


func _world_check() -> void:
	var w := _world() as DungeonWorld
	if not check(w != null, "мир — подземелье (DungeonWorld)"):
		return
	var m := bot.main
	check(Game.location == "dungeon", "локация героя — подземелье")
	check(m.find_child("Island", false, false) == null and m.find_child("Vegetation", true, false) == null, "острова в сцене нет")
	var n := npcs()
	check(n == null or n.npc("sage") == null, "жителей в подземелье нет")
	var pt := _portal()
	check(pt != null and pt.to == "island", "в подземелье — портал на остров")
	var p := player()
	if pt != null and p != null:
		_exit = w.ground(pt.exit_point().x, pt.exit_point().z, 0.2)
		var d := Vector2(p.global_position.x - pt.global_position.x, p.global_position.z - pt.global_position.z).length()
		check(d < 8.0, "герой у портала подземелья (%.1f м)" % d)
	var q := quests()
	check(q != null and q.goal_progress(QuestData.DUNGEON_QUEST, 0) >= 1, "цель «Спуститься в подземелье» засчитана")
	var holder := w.get_node_or_null("DungeonProps")
	check(holder != null and holder.get_child_count() > 0, "объекты подземелья расставлены (%d узлов)" % (
		holder.get_child_count() if holder != null else 0))
	shot("Podzemelye vhod")


# ---------- Монстры ----------

func _zone(zid: String) -> Dictionary:
	var w := _world()
	if w == null:
		return {}
	for z in w.cfg.get("mob_zones", []):
		if String((z as Dictionary).get("id", "")) == zid:
			return z
	return {}


func _zone_go(zid: String) -> void:
	var z := _zone(zid)
	if not check(not z.is_empty(), "зона «%s» есть в подземелье" % zid):
		return
	var c := IslandWorld.v2(z["center"])
	bot.teleport(c, "зона " + zid)


## Монстры видов зоны рядом, у каждого — модель из файла и оружие (если пакет загружен и у вида есть оружие).
func _zone_check(zid: String) -> void:
	var z := _zone(zid)
	if z.is_empty():
		return
	var c := IslandWorld.v2(z["center"])
	var r := float(z.get("radius", 8.0)) + ZONE_MARGIN
	var found := {}
	for node in bot.get_tree().get_nodes_in_group("mobs"):
		var m := node as Mob
		if m == null or m.is_dead or m.slot < 0:
			continue
		if Vector2(m.global_position.x, m.global_position.z).distance_to(c) > r:
			continue
		if not found.has(m.type_id):
			found[m.type_id] = m
	var miss := PackedStringArray()
	for e in z.get("mobs", []):
		var sp := String((e as Array)[0])
		if not found.has(sp):
			miss.append(String(MobData.get_type(sp).get("name", sp)))
	check(miss.is_empty(), "зона «%s»: монстры всех видов рядом (%d видов)%s" % [zid, found.size(),
		"" if miss.is_empty() else "; нет: " + ", ".join(miss)])
	if not Assets.available():
		note("Зона «%s»: пакет ресурсов не загружен — модели из примитивов, оружие не проверяется" % zid)
		return
	for sp in found:
		var m := found[sp] as Mob
		var asset: Variant = m.get("_asset")
		check(asset != null, "«%s»: модель из файла" % m.mob_name)
		if asset != null and MobData.weapon_of(String(sp), m.model_stage) != "":
			check((asset as CreatureAsset).weapon_node != null, "«%s»: оружие в руке (%s)" % [m.mob_name,
				MobData.weapon_of(String(sp), m.model_stage)])
	shot("Zona %s" % zid)


## Обычный монстр рядом (не мини-босс): победа героем — опыт, мешочек добычи.
func _kill_one() -> void:
	var p := player()
	if p == null:
		return
	_victim = null
	var best := INF
	for node in bot.get_tree().get_nodes_in_group("mobs"):
		var m := node as Mob
		if m == null or m.is_dead or m.is_boss or MobData.is_mini_boss(m.type_id) or not MobData.is_dungeon(m.type_id):
			continue
		var d := m.global_position.distance_to(p.global_position)
		if d < best:
			best = d
			_victim = m
	if not check(_victim != null, "обычный монстр подземелья рядом"):
		return
	_victim_at = _victim.global_position
	_step_away(_victim_at)
	_xp0 = CardinalRun.cumulative_xp(Game.level, Game.xp)
	_drops0 = _drops_near(_victim_at, 6.0)
	kill(_victim)


## Отойти от точки at на STEP_AWAY м по плоскости — мешочек добычи не подберётся сам до проверки: проходимая точка
## на той же высоте (пол зала, палуба), сначала — в ту сторону, где герой уже стоит.
func _step_away(at: Vector3) -> void:
	var p := player()
	var w := _world()
	if p == null or w == null:
		return
	var away := Vector2(p.global_position.x - at.x, p.global_position.z - at.z)
	var dirs: Array = [away.normalized() if away.length() > 0.1 else Vector2(0, 1), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 0), Vector2(-1, 0)]
	for dv in dirs:
		var q := Vector2(at.x, at.z) + (dv as Vector2) * STEP_AWAY
		var y := Economy.drop_height(Vector3(q.x, at.y, q.y))
		if w.is_walkable(q.x, q.y) and absf(y - at.y) < 1.0:
			p.global_position = Vector3(q.x, y + 0.3, q.y)
			p.velocity = Vector3.ZERO
			return


## Ближайший к at мешочек добычи (дальше r — null).
func _drop_near(at: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for node in bot.get_tree().get_nodes_in_group("loot_drops"):
		var ld := node as Node3D
		if ld == null:
			continue
		var d := Vector2(ld.global_position.x - at.x, ld.global_position.z - at.z).length()
		if d < bd:
			bd = d
			best = ld
	return best


## Мешочек у точки at на её высоте (до 0.44 мешочек ложился на y = 0 — в подземелье под пол и в корпус корабля).
func _drop_on_floor(at: Vector3, what: String) -> void:
	var ld := _drop_near(at, 6.0)
	if ld != null:
		check(absf(ld.global_position.y - at.y) < DROP_Y_OK, "%s лежит на полу: высота %.2f м, монстр — %.2f м" % [
			what, ld.global_position.y, at.y])


func _drops_near(at: Vector3, r: float) -> int:
	var n := 0
	for node in bot.get_tree().get_nodes_in_group("loot_drops"):
		var ld := node as Node3D
		if ld != null and ld.global_position.distance_to(at) < r:
			n += 1
	return n


func _kill_check() -> void:
	if _victim == null:
		return
	var dead := not is_instance_valid(_victim) or _victim.is_dead
	check(dead, "монстр побеждён")
	var xp1 := CardinalRun.cumulative_xp(Game.level, Game.xp)
	check(xp1 > _xp0, "опыт за монстра подземелья: +%d" % (xp1 - _xp0))
	if check(_drops_near(_victim_at, 6.0) > _drops0, "мешочек добычи у монстра"):
		_drop_on_floor(_victim_at, "мешочек")


# ---------- Проклятый капитан ----------

func _cap_find() -> void:
	var w := _world() as DungeonWorld
	var z := _zone("dg_captain")
	if w == null or not check(not z.is_empty(), "зона капитана есть"):
		return
	var c := IslandWorld.v2(z["center"])
	var p := player()
	if p != null:
		# На палубу у капитана (высота палубы, не воды)
		var q := c + Vector2(0.0, 2.5)
		p.global_position = Vector3(q.x, w._ground_or_deck(q) + 0.3, q.y)
		p.velocity = Vector3.ZERO
	bot.reset_camera()


func _captain() -> Mob:
	for node in bot.get_tree().get_nodes_in_group("mobs"):
		var m := node as Mob
		if m != null and not m.is_dead and m.type_id == "dg_captain":
			return m
	return null


func _slam_start() -> void:
	_cap = _captain()
	if not check(_cap != null, "Проклятый капитан на палубе"):
		return
	check(_cap.is_boss and _cap.aggressive, "капитан — босс, нападает сам")
	_cap_at = _cap.global_position
	var p := player()
	# Удар по площади ранит: бессмертие на время снято, запас HP (как tests/test_dungeon_boss.gd)
	AdminPanel.god = false
	p.global_position = _cap.global_position + Vector3(0.0, 0.2, 1.6)
	p.velocity = Vector3.ZERO
	_maxhp0 = p.max_hp
	p.max_hp = 10000000
	p.hp = p.max_hp
	_hp0 = p.hp
	# Без уклонения и блока (щит, пояс, умения): иначе удар мог уйти в щит — HP прежний (вернёт recalc_stats)
	p.eva = 0.0
	p.shade_eva = 0.0
	p.aura_eva = 0.0
	p.block = 0.0
	_uses0 = _cap.skill_uses
	_cap.target = p
	_cap.start_slam()
	shot("Kapitan zamah")


func _slammed() -> bool:
	return _cap == null or not is_instance_valid(_cap) or _cap.is_dead or _cap.skill_uses > _uses0


func _slam_done() -> void:
	var p := player()
	if _cap == null or p == null:
		AdminPanel.god = true
		return
	check(_cap.skill_uses > _uses0, "«Клятва бездны» ударила")
	check(p.hp < _hp0, "удар по площади ранил героя (%d → %d)" % [_hp0, p.hp])
	AdminPanel.god = true
	p.recalc_stats()
	p.hp = p.max_hp


## Проклятия: каждое из списка капитана — эффект со значком; оглушение держит героя.
func _curses() -> void:
	var p := player()
	if _cap == null or not is_instance_valid(_cap) or p == null:
		return
	var list: Array = MobData.curses_of("dg_captain").get("list", [])
	if not check(not list.is_empty(), "у капитана есть проклятия"):
		return
	var seen := PackedStringArray()
	for i in 24:
		_cap.curse_now(p)
		var kind := String(_cap.last_curse[0]) if not _cap.last_curse.is_empty() else ""
		if kind != "" and not seen.has(kind):
			seen.append(kind)
		if seen.size() >= list.size():
			break
	var stun := seen.has("stun") and p.stun_left > 0.0
	check(seen.size() >= mini(3, list.size()), "проклятия капитана ложатся: %s" % ", ".join(seen))
	if seen.has("stun"):
		check(stun or p.effects.has("curse:stun"), "оглушение держит героя (%.1f с)" % p.stun_left)
	shot("Kapitan proklyatiya")
	p.clear_buffs()
	p.stun_left = 0.0


func _enrage() -> void:
	if _cap == null or not is_instance_valid(_cap):
		return
	var base := _cap.attack_every
	_cap.take_damage(_cap.hp - int(float(_cap.max_hp) * 0.4), player())
	check(_cap.enraged and _cap.attack_every < base * 0.9, "ярость с половины HP: удар раз в %.2f с (было %.2f)" % [
		_cap.attack_every, base])
	# Реплики капитана — при вступлении в бой (MobData says "aggro", с ответом героя «> »; на половине HP своей нет —
	# вместо неё всплывает надпись ярости «Клятва сильнее смерти!»)
	var aggro := MobData.says_of("dg_captain", "aggro")
	var said: Dictionary = _cap.get("_said") if _cap.get("_said") is Dictionary else {}
	check(not aggro.is_empty() and said.has("aggro") and _cap.last_said.size() >= 1,
		"реплики капитана в бою (%d, ответ героя: %s): %s" % [aggro.size(),
		"да" if aggro.any(func(l: Variant) -> bool: return String(l).begins_with("> ")) else "нет",
		String(_cap.last_said[0]).left(60) if not _cap.last_said.is_empty() else "нет"])


func _cap_kill() -> void:
	if _cap == null or not is_instance_valid(_cap):
		return
	_cap_at = _cap.global_position
	_step_away(_cap_at)
	_drops0 = _drops_near(_cap_at, 8.0)
	kill(_cap)


func _cap_loot() -> void:
	if _cap == null:
		return
	check(not is_instance_valid(_cap) or _cap.is_dead, "Проклятый капитан побеждён")
	if check(_drops_near(_cap_at, 8.0) > _drops0, "добыча капитана на палубе"):
		_drop_on_floor(_cap_at, "мешочек капитана")
	var p := player()
	if p != null:
		p.max_hp = maxi(_maxhp0, 1)
		p.recalc_stats()
		p.hp = p.max_hp
	shot("Kapitan pobezhden")


# ---------- Ходьба ----------

func _poi(pid: String) -> Vector2:
	var w := _world()
	if w != null:
		for e in w.cfg.get("pois", []):
			if String((e as Dictionary).get("id", "")) == pid:
				return IslandWorld.v2(e["center"])
	return Vector2.INF


func _walk_poi(pid: String) -> void:
	var c := _poi(pid)
	if not check(c.is_finite(), "место «%s» есть" % pid):
		_walk_end = true
		return
	_walk_from(_exit, Vector3(c.x, 0.0, c.y), "от портала: " + pid)


func _walk_deck() -> void:
	var w := _world()
	if w == null:
		_walk_end = true
		return
	_walk_from(w.ground(PIER.x, PIER.y, 0.2), Vector3(DECK_GOAL.x, 0.0, DECK_GOAL.y), "причал → палуба корабля")


func _walk_from(start: Vector3, goal: Vector3, nm: String) -> void:
	var p := player()
	if p == null or start == Vector3.ZERO:
		_walk_end = true
		check(false, "ходьба «%s»: герой и старт есть" % nm)
		return
	p.global_position = start
	p.velocity = Vector3.ZERO
	bot.reset_camera()
	_walk_name = nm
	_walker = CardinalWalk.new()
	_walker.begin(p.global_position, goal, REACH, 14.0)
	_walk_t = 0.0
	_st_t = 0.0
	_st_from = p.global_position
	_walk_end = false
	_walk_ok = false
	bot.set_tick(_drive)


## Каждый кадр: джойстик по пути (как палец: HUD.move_vec относительно камеры).
func _drive(dt: float) -> void:
	var p := player()
	var h := hud()
	if p == null or h == null or _walker == null or _walk_end:
		return
	var pos := p.global_position
	_walk_t += dt
	var dir := _walker.step(pos, dt)
	if _walker.status == "arrived":
		_walk_ok = true
		_stop_walk()
		return
	var why := ""
	if _walker.status == "stuck":
		why = "остаток пути %.1f м не короче 14 с" % _walker.remaining(pos)
	_st_t += dt
	if why == "" and _st_t >= STUCK_TIME:
		if Vector2(pos.x - _st_from.x, pos.z - _st_from.z).length() < STUCK_MOVE:
			why = "за %.0f с сдвинулся меньше %.1f м" % [STUCK_TIME, STUCK_MOVE]
		_st_t = 0.0
		_st_from = pos
	if why != "":
		check(false, "ходьба «%s»: ЗАСТРЯЛ у (%.1f, %.1f, %.1f) — %s" % [_walk_name, pos.x, pos.y, pos.z, why])
		shot("Zastryal %s" % _walk_name)
		_walks_bad += 1
		_stop_walk()
		return
	var yaw := float(bot.main.get("cam_yaw"))
	var mv := Vector3(dir.x, 0.0, dir.z).rotated(Vector3.UP, -yaw)
	h.move_vec = Vector2(mv.x, mv.z)
	p.move_input = Vector2(dir.x, dir.z)


func _stop_walk() -> void:
	_walk_end = true
	var p := player()
	var h := hud()
	if h != null:
		h.move_vec = Vector2.ZERO
	if p != null:
		p.move_input = Vector2.ZERO


func _walked() -> bool:
	return _walk_end


func _walk_done() -> void:
	bot.set_tick(Callable())
	if not _walk_end:
		_stop_walk()
		check(false, "ходьба «%s»: не дошёл за %.0f с" % [_walk_name, WALK_LIMIT])
		return
	if _walk_ok:
		check(true, "ходьба «%s»: дошёл за %.1f с (путь пересчитан %d, обходов %d)" % [_walk_name, _walk_t,
			_walker.repaths, _walker.detours])


# ---------- Питомцы, свитки, дальность ----------

func _pet(sp: String) -> void:
	no_pets()
	var i := Game.add_pet(sp, PetData.stage_name(sp, 0), 22)
	if check(i >= 0, "питомец «%s» в коллекции" % sp):
		pets().summon(i)


func _pet_up(sp: String) -> bool:
	var pt := pet()
	return pt != null and pt.species == sp


func _pet_check(sp: String) -> void:
	var pt := pet()
	if not check(pt != null and pt.species == sp, "питомец «%s» призван в подземелье" % sp):
		return
	if not Assets.available():
		return
	var asset: Variant = pt.get("_asset")
	check(asset != null, "питомец «%s»: модель из файла" % sp)
	if sp == "skeleton" and asset != null:
		check((asset as CreatureAsset).weapon_node != null, "Скелет: меч в руке")
	shot("Pitomec %s" % sp)


func _story(sid: String) -> void:
	var h := hud()
	if h == null:
		return
	check(Story.open(h, sid), "свиток «%s» открывается" % sid)
	window_fits("Свиток «%s»" % sid)
	shot("Svitok %s" % sid)
	close_window()


## Объекты нарезаны по дальности «В подземелье» (участки дальше не рисуются; «Все» — без предела).
func _props_range() -> void:
	var w := _world()
	var holder := w.get_node_or_null("DungeonProps") if w != null else null
	if holder == null:
		return
	var view := Quality.dungeon_range()
	var n := 0
	var bad := 0
	for c in holder.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not mi.name.begins_with("Props"):
			continue
		n += 1
		if view > 0.0 and (mi.visibility_range_end <= view or mi.visibility_range_end > view + 80.0):
			bad += 1
		elif view <= 0.0 and mi.visibility_range_end > 0.0:
			bad += 1
	check(n > 0 and bad == 0, "объекты по дальности «%s»: участков %d, не по дальности %d" % [
		String(Quality.DUNGEON_RANGE_LABELS[Quality.dungeon_range_level()]), n, bad])


## Монстры дальше дальности не живут: дальность 20 м на время (без записи), через 1.5 с — нет живых дальше 20 + запас.
func _mob_range_start() -> void:
	_dg0 = Quality.dungeon_range_level()
	if Quality.mob_range_override >= 0:
		return
	Quality.set_dungeon_range_level(0, false)


func _mob_range_check() -> void:
	if Quality.mob_range_override >= 0:
		note("«В подземелье»: дальность монстров задана тестом — поток не проверяется")
		return
	var p := player()
	var far := 0
	var lim := Quality.dungeon_range() + 12.0 + 4.0
	if p != null:
		for node in bot.get_tree().get_nodes_in_group("mobs"):
			var m := node as Mob
			if m != null and not m.is_dead and m.slot >= 0 and m.target == null and not m.returning \
					and m.global_position.distance_to(p.global_position) > lim:
				far += 1
	check(far == 0, "«В подземелье» 20 м: спокойных монстров дальше %.0f м нет (%d)" % [lim, far])
	if _dg0 >= 0:
		Quality.set_dungeon_range_level(_dg0, false)


# ---------- Назад на остров ----------

func _back() -> void:
	no_pets()
	var pt := _portal()
	if pt == null or not (_world() is DungeonWorld):
		check(false, "портал подземелья есть — возврат через админ-панель")
		AdminPanel.go_location(bot.main, "island")
		return
	_main0 = bot.main
	_put(pt.exit_point())
	_put(pt.front_point())


func _on_island() -> bool:
	var m := bot.main
	if m == null or not is_instance_valid(m) or m == _main0 or not m.is_inside_tree() or not bool(m.get("_started")):
		return false
	var w := _world()
	return w != null and not (w is DungeonWorld)


func _island_check() -> void:
	var w := _world()
	if not check(w != null and w.location() == "island" and Game.location == "island", "портал подземелья вернул на остров"):
		# Дальше — разделы острова: на остров без портала
		AdminPanel.go_location(bot.main, "island")
		return
	var cp: Dictionary = w.poi("cave")
	var p := player()
	if not cp.is_empty() and p != null:
		var c := IslandWorld.v2(cp["center"])
		var d := Vector2(p.global_position.x - c.x, p.global_position.z - c.y).length()
		check(d < 14.0, "герой у пещеры острова (%.1f м)" % d)
	check(_walks_bad == 0, "ходьба в подземелье без застреваний (%d)" % _walks_bad)
	shot("Ostrov posle podzemelya")
