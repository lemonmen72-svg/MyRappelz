class_name JobFxNeophyte
extends RefCounted
## Особые механики Неофита (огонь, молния, тьма) и общие помощники заклинателей (ими пользуются и Волшебник,
## и Мечник): вызываются из HeroSkillFx (job_special / job_check / status), данные — JobSkills.SKILLS.
##
## Ослабления зверя на время, меняющие его поле (MODS): "armor" — защита ниже (pdef), "ward" — маг. защита ниже
##   (mdef), "aslow" — бьёт медленнее (attack_every), "snare" — не может сдвинуться (speed = 0, бить рядом может).
##   Узел MobMod — ребёнок зверя: держит исходное значение, сверяет значок у полоски HP (Mob.effects) и по истечении
##   возвращает поле. Повтор — сильнейшее из двух и дольше. Эффект "status" движка с этими видами — HeroSkillFx.status.
## Имена обработчиков — с префиксом ne_. Зоны на земле (handler "ne_zone"): узел Zone в точке цели — видимый круг радиусом radius на time с, раз в
##   ZONE_TICK с бьёт всех зверей в круге (доля mult маг. атаки через маг. защиту, как урон со временем), может
##   замедлять бег (slow, slow_time) и удары (aslow). Одна зона умения за раз (повтор переносит её).
## Тела убитых зверей (on_mob_killed из main): CORPSE_TIME с лежат «остатки» (у Неофита с «Последним вздохом» или
##   «Остатком силы» — тёмный дымок на земле); "ne_corpse_hp" / "ne_corpse_mp" поглощают ближайшее тело в CORPSE_RANGE м:
##   HP или MP героя + доля pct от максимума.
## Прочее: "ne_volley" — серия снарядов (hits, gap) по цели («Град тьмы», «Шквал света»), "ne_burn_area" — горение всем
##   зверям вокруг цели, "ne_blood_gift" — лечит питомца ценой HP героя, "ne_mark" / "ne_pillar" — только вспышка
##   (на цели или на герое) и столб света / молния с неба.

## Ослабления зверя: вид → [поле Mob, название эффекта у значка].
const MODS := {
	"armor": ["pdef", "Защита ниже"],
	"ward": ["mdef", "Маг. защита ниже"],
	"aslow": ["attack_every", "Атакует медленнее"],
	"snare": ["speed", "Обездвижен"],
}
## Тела зверей: сколько лежат (с), сколько помним, с какого расстояния можно поглотить (м).
const CORPSE_TIME := 30.0
const CORPSE_MAX := 8
const CORPSE_RANGE := 12.0
## Зоны: удар раз в ZONE_TICK с; цвет круга по виду.
const ZONE_TICK := 1.0
const ZONE_COLORS := {
	"fire": Color(1.0, 0.45, 0.15), "storm": Color(0.55, 0.68, 1.0), "mire": Color(0.45, 0.72, 0.22),
}
const DARK := Color(0.55, 0.3, 0.85)

## Тела убитых зверей: {"pos": Vector3, "level": int, "name": String, "t": с (время смерти), "node": остатки или null}.
static var corpses: Array[Dictionary] = []


# ---------- Точки подключения (HeroSkillFx) ----------

## Особая механика handler умения sid уровня n по цели t (может быть null). false — обработчик не наш.
static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, t: Mob, e: Dictionary) -> bool:
	match handler:
		"ne_zone":
			_zone(fx, sid, n, t, e)
		"ne_volley":
			_volley(fx, sid, n, t, e)
		"ne_burn_area":
			_burn_area(fx, sid, n, t, e)
		"ne_corpse_hp", "ne_corpse_mp":
			_corpse(fx, sid, n, e, handler == "ne_corpse_hp")
		"ne_blood_gift":
			_blood_gift(fx, sid, n, e)
		"ne_mark":
			_mark(fx, sid, t, e)
		"ne_pillar":
			_pillar(fx, sid, t, e)
		_:
			return false
	return true


## Можно ли применить ("" — можно): тело зверя рядом, HP героя на «Кровный дар».
static func check(fx: HeroSkillFx, handler: String, n: int, e: Dictionary) -> String:
	match handler:
		"ne_corpse_hp", "ne_corpse_mp":
			if nearest_corpse(fx.p.global_position, CORPSE_RANGE) < 0:
				return "рядом нет тела зверя"
		"ne_blood_gift":
			if fx.p.hp <= _blood_cost(fx.p, n, e):
				return "не хватает HP"
	return ""


# ---------- Ослабления зверя ----------

## Наложить ослабление kind (MODS) на зверя m: value — доля (защита, маг. защита ниже на долю, удары реже на долю;
## у "snare" не важна), sec секунд, src — источник для значка (StatusEffects.source_*).
static func apply_mod(m: Mob, kind: String, value: float, sec: float, src: Dictionary) -> void:
	if m == null or not is_instance_valid(m) or m.is_dead or sec <= 0.0 or not MODS.has(kind):
		return
	var mul := 1.0 - clampf(value, 0.0, 0.9)
	if kind == "aslow":
		mul = 1.0 / (1.0 - clampf(value, 0.0, 0.9))
	elif kind == "snare":
		mul = 0.0
	var node_name := "Mod_" + kind
	var mm := m.get_node_or_null(node_name) as MobMod
	if mm == null:
		mm = MobMod.new()
		mm.name = node_name
		mm.setup(m, kind, String(MODS[kind][0]))
		m.add_child(mm)
	mm.push(mul, sec)
	var nm := String(MODS[kind][1])
	var icon: Dictionary = src.get("icon", {})
	if icon.is_empty():
		icon = IconView.glyph(nm.substr(0, 1), Color(0.9, 0.5, 0.4))
	m.effects.add(kind, mm.left, {"name": nm, "src": String(src.get("name", "")), "icon": icon, "debuff": true})


## Действует ли на звере ослабление kind.
static func has_mod(m: Mob, kind: String) -> bool:
	if m == null or not is_instance_valid(m):
		return false
	var mm := m.get_node_or_null("Mod_" + kind) as MobMod
	return mm != null and mm.left > 0.0


## Снять все ослабления MODS со зверя (поля возвращаются).
static func clear_mods(m: Mob) -> void:
	if m == null or not is_instance_valid(m):
		return
	for c in m.get_children():
		var mm := c as MobMod
		if mm != null and mm.left > 0.0:
			mm.restore()


## Ослабление поля зверя на время (узел-ребёнок зверя).
class MobMod extends Node:
	var mob: Mob
	var kind := ""
	var field := ""
	var base := 0.0
	var is_int := false
	var mul := 1.0
	var left := 0.0

	func setup(m: Mob, k: String, f: String) -> void:
		mob = m
		kind = k
		field = f
		var v: Variant = m.get(f)
		is_int = v is int
		base = float(v)

	## Наложить: повтор — сильнейшее (дальше от 1) и дольше.
	func push(new_mul: float, sec: float) -> void:
		if left <= 0.0 or absf(new_mul - 1.0) > absf(mul - 1.0):
			mul = new_mul
		left = maxf(left, sec)
		_write(base * mul)

	func _write(v: float) -> void:
		if not is_instance_valid(mob):
			return
		if is_int:
			mob.set(field, roundi(v))
		else:
			mob.set(field, v)

	func _process(delta: float) -> void:
		if left <= 0.0:
			return
		left -= delta
		if not is_instance_valid(mob) or mob.is_dead:
			return
		mob.effects.sync(kind, left)
		if left <= 0.0:
			restore()

	## Вернуть поле зверя и убрать узел.
	func restore() -> void:
		_write(base)
		left = 0.0
		if is_instance_valid(mob):
			mob.effects.remove(kind)
		name = "Mod_done_%d" % get_instance_id()
		queue_free()


# ---------- Зоны на земле ----------

## Зона умения sid в точке цели t («Пылающая земля», «Грозовой круг», «Топь»). Повтор переносит зону.
static func _zone(fx: HeroSkillFx, sid: String, n: int, t: Mob, e: Dictionary) -> void:
	if t == null or not is_instance_valid(t):
		return
	var parent := fx.p.get_parent()
	if parent == null or not parent.is_inside_tree():
		return
	for z in fx.p.get_tree().get_nodes_in_group("skill_zones"):
		var old := z as Zone
		if old != null and old.sid == sid:
			old.queue_free()
	var zone := Zone.new()
	zone.fx = fx
	zone.sid = sid
	zone.n = n
	zone.e = e
	zone.kind = String(e.get("zone", "fire"))
	zone.radius = HeroSkills.value_at(e.get("radius", 4.0), n)
	zone.left = HeroSkills.value_at(e.get("time", 10.0), n)
	zone.color = ZONE_COLORS.get(zone.kind, DARK)
	parent.add_child(zone)
	zone.global_position = t.global_position + Vector3(0, 0.08, 0)
	Vfx.magic_burst(parent, zone.global_position + Vector3(0, 0.4, 0), zone.color, zone.radius * 0.6, 0.4)


## Зона на земле: круг, искры, удар раз в ZONE_TICK с по всем зверям внутри.
class Zone extends Node3D:
	var fx: HeroSkillFx
	var sid := ""
	var n := 1
	var e: Dictionary = {}
	var kind := "fire"
	var radius := 4.0
	var left := 10.0
	var color := Color.WHITE
	## Сколько раз зона ударила зверей (для тестов).
	var hits := 0
	var _tick := 0.3
	var _ring: MeshInstance3D
	var _disk_mat: StandardMaterial3D
	var _t := 0.0

	func _ready() -> void:
		add_to_group("skill_zones")
		var disk := MeshInstance3D.new()
		disk.set_meta("no_outline", true)
		disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disk.mesh = Vfx._plane()
		_disk_mat = Vfx.fx_mat(Color(color, 0.32), Vfx.tex("dot"), true)
		disk.material_override = _disk_mat
		disk.scale = Vector3.ONE * radius * 1.15
		add_child(disk)
		_ring = MeshInstance3D.new()
		_ring.set_meta("no_outline", true)
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.mesh = Vfx._plane()
		_ring.material_override = Vfx.fx_mat(Color(color, 0.85), Vfx.tex("ring"), true)
		_ring.scale = Vector3.ONE * radius
		_ring.position.y = 0.02
		add_child(_ring)
		var sp := Vfx.ambient_sparkles(self, color, radius * 0.7, 10)
		sp.position.y = 0.5

	func _process(delta: float) -> void:
		if fx == null or not is_instance_valid(fx.p) or not fx.p.is_inside_tree():
			queue_free()
			return
		_t += delta
		left -= delta
		_tick -= delta
		_ring.rotation.y += delta * 0.9
		var pulse := 1.0 + 0.04 * sin(_t * 5.0)
		_ring.scale = Vector3.ONE * radius * pulse
		if left < 0.6:
			_disk_mat.albedo_color.a = 0.32 * maxf(left, 0.0) / 0.6
		if _tick <= 0.0:
			_tick += JobFxNeophyte.ZONE_TICK
			_strike()
		if left <= 0.0:
			queue_free()

	## Удар зоны по всем зверям в круге.
	func _strike() -> void:
		var p := fx.p
		var src := StatusEffects.source_hero_skill(sid)
		var magic := String(e.get("power", "matk")) == "matk"
		var power := float(p.cur_matk()) if magic else float(p.cur_atk())
		var raw := power * HeroSkills.value_at(e.get("mult", 0.3), n) * fx.skill_factor(sid)
		var parent := get_parent()
		for m in p._mobs_around(global_position, radius):
			if not p.skill_hits(m):
				continue
			m.take_damage(maxi(1, roundi(raw * p.damage_factor(m, magic))), p, false, true)
			hits += 1
			if m.is_dead:
				continue
			if e.has("slow"):
				m.slow(HeroSkills.value_at(e["slow"], n), HeroSkills.value_at(e.get("slow_time", 2.0), n), src)
			if e.has("aslow"):
				JobFxNeophyte.apply_mod(m, "aslow", HeroSkills.value_at(e["aslow"], n), JobFxNeophyte.ZONE_TICK + 1.0, src)
			Vfx.hit_spark(parent, m.aim_point(), color, 0.6)
		if kind == "storm" and hits > 0:
			# Молния бьёт в случайную точку круга
			var a := randf() * TAU
			var r := randf() * radius * 0.8
			JobFxNeophyte.lightning(parent, global_position + Vector3(cos(a) * r, 0.0, sin(a) * r), color, 0.12, 5.0)


# ---------- Тела зверей ----------

## Зверь убит: его тело можно поглотить CORPSE_TIME с (вызывает main._on_mob_gone).
static func on_mob_killed(mob: Mob) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	_prune()
	var c := {"pos": mob.global_position, "level": mob.level, "name": mob.mob_name, "t": _now(), "node": null}
	if _knows_corpses() and mob.is_inside_tree():
		c["node"] = _remains(mob.get_parent(), mob.global_position)
	corpses.append(c)
	while corpses.size() > CORPSE_MAX:
		_drop(0)


## Индекс ближайшего тела в r м от pos (-1 — нет).
static func nearest_corpse(pos: Vector3, r: float) -> int:
	_prune()
	var best := -1
	var bd := r
	for i in corpses.size():
		var cp: Vector3 = corpses[i]["pos"]
		var d := pos.distance_to(cp)
		if d <= bd:
			bd = d
			best = i
	return best


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _prune() -> void:
	var now := _now()
	var i := corpses.size() - 1
	while i >= 0:
		if now - float(corpses[i]["t"]) > CORPSE_TIME:
			_drop(i)
		i -= 1


static func _drop(i: int) -> void:
	var node: Variant = corpses[i].get("node")
	if is_instance_valid(node):
		(node as Node).queue_free()
	corpses.remove_at(i)


## Есть ли у героя умения, которые поглощают тела (тогда остатки видны).
static func _knows_corpses() -> bool:
	return HeroSkills.skill_level(Game.hero, "last_breath") > 0 or HeroSkills.skill_level(Game.hero, "soul_remnant") > 0


## Остатки на земле: тёмное пятно и дымок (исчезают через CORPSE_TIME с или при поглощении).
static func _remains(parent: Node, pos: Vector3) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var root := Node3D.new()
	root.name = "Remains"
	root.add_to_group("corpse_remains")
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.06, 0)
	var disk := MeshInstance3D.new()
	disk.set_meta("no_outline", true)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.mesh = Vfx._plane()
	disk.material_override = Vfx.fx_mat(Color(DARK, 0.45), Vfx.tex("dot"), true)
	disk.scale = Vector3.ONE * 0.8
	root.add_child(disk)
	var sp := Vfx.ambient_sparkles(root, DARK, 0.35, 4)
	sp.position.y = 0.3
	var tw := root.create_tween()
	tw.tween_interval(CORPSE_TIME)
	tw.tween_callback(root.queue_free)
	return root


## «Последний вздох» / «Остаток силы»: поглотить ближайшее тело — HP (или MP) героя + pct от максимума.
static func _corpse(fx: HeroSkillFx, sid: String, n: int, e: Dictionary, hp: bool) -> void:
	var p := fx.p
	var i := nearest_corpse(p.global_position, CORPSE_RANGE)
	if i < 0:
		return
	var pos: Vector3 = corpses[i]["pos"]
	_drop(i)
	var parent := p.get_parent()
	Vfx.magic_burst(parent, pos + Vector3(0, 0.5, 0), DARK, 1.0, 0.45)
	_streak(parent, pos + Vector3(0, 0.6, 0), p.global_position + Vector3(0, 1.1, 0), DARK)
	var pct := HeroSkills.value_at(e.get("pct", 0.15), n)
	if hp:
		p.heal(maxi(1, roundi(float(p.max_hp) * pct)))
	else:
		var add := maxi(1, roundi(float(p.max_mp) * pct))
		p.mp = mini(p.max_mp, p.mp + add)
		Util.float_text(parent, p.global_position + Vector3(0, 2.4, 0), "+%d MP" % add, Color(0.45, 0.65, 1.0))
		Vfx.magic_burst(parent, p.global_position + Vector3(0, 1.0, 0), Color(0.45, 0.6, 1.0), 0.9, 0.35)
		p.stats_changed.emit()


## Светящаяся точка летит от a к b (душа тела к герою).
static func _streak(parent: Node, a: Vector3, b: Vector3, c: Color) -> void:
	var root := Vfx._root(parent, a, 0.6)
	if root == null:
		return
	var orb := Vfx._sprite(root, "star", Color(c.lightened(0.3), 1.0), 0.7, 0.6)
	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", b, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ---------- Прочие механики ----------

## Серия снарядов по цели: hits штук через gap с (каждый — доля mult атаки или маг. атаки, может промахнуться).
static func _volley(fx: HeroSkillFx, sid: String, n: int, t: Mob, e: Dictionary) -> void:
	if t == null or not is_instance_valid(t):
		return
	var v := Volley.new()
	v.fx = fx
	v.sid = sid
	v.n = n
	v.target = t
	v.e = e
	v.left = maxi(1, int(HeroSkills.value_at(e.get("hits", 5), n)))
	v.gap = float(e.get("gap", 0.14))
	fx.p.add_child(v)
	v.fire()


## Серия снарядов: узел-ребёнок героя, стреляет раз в gap с, пока не кончатся снаряды или цель.
class Volley extends Node:
	var fx: HeroSkillFx
	var sid := ""
	var n := 1
	## Цель (может погибнуть и пропасть — без типа).
	var target: Variant = null
	var e: Dictionary = {}
	var left := 0
	var gap := 0.14
	var _wait := 0.0

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			fire()

	## Выпустить следующий снаряд; кончились или цели нет — узел удаляется.
	func fire() -> void:
		_wait = gap
		if left <= 0 or not is_instance_valid(target) or fx == null or not is_instance_valid(fx.p) \
				or not fx.p.is_inside_tree():
			queue_free()
			return
		var t := target as Mob
		if t == null or t.is_dead:
			queue_free()
			return
		left -= 1
		fx.p._shoot(t, fx.roll(e, n, sid), 0.75, Callable(), not fx.p.skill_hits(t))
		if left <= 0:
			queue_free()


## Горение всем зверям вокруг цели t (radius м): доля mult маг. атаки в секунду time секунд.
static func _burn_area(fx: HeroSkillFx, sid: String, n: int, t: Mob, e: Dictionary) -> void:
	if t == null or not is_instance_valid(t):
		return
	var p := fx.p
	var src := StatusEffects.source_hero_skill(sid)
	var mult := HeroSkills.value_at(e.get("mult", 0.2), n)
	var sec := HeroSkills.value_at(e.get("time", 8.0), n)
	var targets: Array[Mob] = []
	if not t.is_dead:
		targets.append(t)
	for m in p._mobs_around(t.global_position, HeroSkills.value_at(e.get("radius", 4.0), n)):
		if m != t:
			targets.append(m)
	for m in targets:
		if not p.skill_hits(m):
			continue
		var dps := float(p.cur_matk()) * mult * p.damage_factor(m, true) * fx.skill_factor(sid)
		m.add_dot(sid, dps, sec, p, false, src)


## «Кровный дар»: герой теряет cost макс. HP, питомец лечится на pct своего макс. HP.
static func _blood_gift(fx: HeroSkillFx, sid: String, n: int, e: Dictionary) -> void:
	var p := fx.p
	var pet := p._active_pet()
	if pet == null:
		return
	var cost := _blood_cost(p, n, e)
	p.hp = maxi(1, p.hp - cost)
	var parent := p.get_parent()
	var blood: Color = JobSkills.COLORS["blood"]
	Util.float_text(parent, p.global_position + Vector3(0, 2.4, 0), "-%d" % cost, blood)
	Vfx.magic_burst(parent, p.global_position + Vector3(0, 1.0, 0), blood, 0.8, 0.35)
	_streak(parent, p.global_position + Vector3(0, 1.1, 0), pet.global_position + Vector3(0, 0.8, 0), blood)
	var amount := maxi(1, roundi(float(pet.get("max_hp")) * HeroSkills.value_at(e.get("pct", 0.2), n)))
	pet.call("heal", amount)
	p.stats_changed.emit()


static func _blood_cost(p: Player, n: int, e: Dictionary) -> int:
	return maxi(1, roundi(float(p.max_hp) * HeroSkills.value_at(e.get("cost", 0.08), n)))


## Вспышка цвета умения на цели (или на герое, если цели нет).
static func _mark(fx: HeroSkillFx, sid: String, t: Mob, e: Dictionary) -> void:
	var col: Color = HeroSkills.get_skill(sid).get("color", DARK)
	var pos := fx.p.global_position + Vector3(0, 1.0, 0)
	if t != null and is_instance_valid(t):
		pos = t.aim_point()
	Vfx.magic_burst(fx.p.get_parent(), pos, col, float(e.get("size", 1.0)), 0.4)


## Столб света или молния с неба в цель.
static func _pillar(fx: HeroSkillFx, sid: String, t: Mob, e: Dictionary) -> void:
	if t == null or not is_instance_valid(t):
		return
	var col: Color = HeroSkills.get_skill(sid).get("color", DARK)
	lightning(fx.p.get_parent(), t.global_position, col, float(e.get("width", 0.2)), float(e.get("height", 7.0)))


## Столб света в точке pos (на земле): ширина width, высота height; короткий и яркий.
static func lightning(parent: Node, pos: Vector3, c: Color, width: float, height: float) -> void:
	var root := Vfx._root(parent, pos, 0.8)
	if root == null:
		return
	Vfx._pillar(root, Color(c.lightened(0.35), 0.85), width, height, 0.45)
	Vfx._sprite(root, "star", Color(1, 1, 1, 0.95), 1.6, 0.3, true, Vector3(0, 0.6, 0))
	Vfx._sprite(root, "ring", Color(c, 0.85), 1.8, 0.35, true, Vector3(0, 0.2, 0))
