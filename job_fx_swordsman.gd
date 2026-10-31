class_name JobFxSwordsman
extends RefCounted
## Особые механики Мечника (страж со щитом); подключение — HeroSkillFx.JOB_FX_FILES (шесть функций, описание —
## шапка HeroSkillFx), данные — JobSkills.SKILLS. Угроза зверя — статус "taunt" движка (зверь бросает цель и бьёт героя; у «Грома щита» — все
## звери вокруг цели), блок щитом — бонус "block" (Player.take_damage), «Колючий щит» — бонус "reflect" на время
## (on_hurt: доля полученного урона — ударившему зверю), «Непробиваемый заслон» — бонус "guard" на время.
## Здесь (имена обработчиков с префиксом sw_): "sw_rush" — рывок к цели (вплотную, вспышки в начале и в конце),
## "sw_cross" — вторая дуга крест-накрест («Крест рассвета»), "sw_mana" — герой получает долю pct нанесённого умением урона в MP («Разбитая воля»).

const SHIELD := Color(0.45, 0.6, 0.88)
const LIGHT := Color(1.0, 0.86, 0.45)


## Особая механика handler умения sid уровня n по цели t (может быть null). false — обработчик не наш.
static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, t: Mob, e: Dictionary) -> bool:
	match handler:
		"sw_rush":
			_rush(fx, t)
		"sw_cross":
			_cross(fx, sid, t)
		"sw_mana":
			_mana(fx, n, e)
		_:
			return false
	return true


## Особых условий у умений Мечника нет.
static func pre_cast(_fx: HeroSkillFx, _sid: String, _n: int, _sk: Dictionary) -> String:
	return ""


static func on_basic_hit(_fx: HeroSkillFx, _t: Mob, _dealt: int) -> void:
	pass


## «Колючий щит» (бонус "reflect" на время): доля полученного урона — ударившему зверю (fx.state["reflect_hits"]).
static func on_hurt(fx: HeroSkillFx, attacker: Node3D, amount: int) -> void:
	var r := fx.bonus("reflect")
	if r <= 0.0 or amount <= 0 or not is_instance_valid(attacker) or not (attacker is Mob):
		return
	var m := attacker as Mob
	if m.is_dead:
		return
	var p := fx.p
	m.take_damage(maxi(1, roundi(float(amount) * r)), p, false, true)
	fx.state["reflect_hits"] = int(fx.state.get("reflect_hits", 0)) + 1
	if p.is_inside_tree():
		Vfx.hit_spark(p.get_parent(), m.aim_point(), SHIELD.lightened(0.2), 0.9)


static func tick(_fx: HeroSkillFx, _delta: float) -> void:
	pass


static func reset(_fx: HeroSkillFx) -> void:
	pass


## «Натиск щита»: рывок к зверю t — герой оказывается вплотную (1.4 м), лицом к нему.
static func _rush(fx: HeroSkillFx, t: Mob) -> void:
	if t == null or not is_instance_valid(t):
		return
	var p := fx.p
	var parent := p.get_parent()
	var away := p.global_position - t.global_position
	away.y = 0.0
	if away.length() < 1.6:
		return
	Vfx.magic_burst(parent, p.global_position + Vector3(0, 1.0, 0), SHIELD, 0.9, 0.3)
	var dest := t.global_position + away.normalized() * 1.4
	dest.y = maxf(t.global_position.y, p.global_position.y - 2.0)
	if IslandWorld.current != null:
		dest.y = IslandWorld.current.height_at(dest.x, dest.z) + 0.1
	p.global_position = dest
	p.velocity = Vector3.ZERO
	p._face(t.global_position)
	Vfx.magic_burst(parent, p.global_position + Vector3(0, 1.0, 0), SHIELD.lightened(0.3), 1.1, 0.35)


## «Крест рассвета»: вторая дуга поперёк первой и звезда света.
static func _cross(fx: HeroSkillFx, sid: String, t: Mob) -> void:
	if t == null or not is_instance_valid(t):
		return
	var col: Color = HeroSkills.get_skill(sid).get("color", LIGHT)
	var dir := t.global_position - fx.p.global_position
	var side := Vector3(-dir.z, 0.0, dir.x)
	Vfx.slash_arc(fx.p.get_parent(), t.aim_point(), side, col.lightened(0.2), 1.25)
	Vfx.hit_spark(fx.p.get_parent(), t.aim_point(), col, 1.2)


## «Разбитая воля»: доля pct урона умения (HeroSkillFx.last_dealt) — в MP героя.
static func _mana(fx: HeroSkillFx, n: int, e: Dictionary) -> void:
	var add := roundi(float(fx.last_dealt) * HeroSkills.value_at(e.get("pct", 0.2), n))
	var p := fx.p
	if add < 1 or p.max_mp <= 0:
		return
	p.mp = mini(p.max_mp, p.mp + add)
	Util.float_text(p.get_parent(), p.global_position + Vector3(0, 2.4, 0), "+%d MP" % add, Color(0.45, 0.65, 1.0))
	p.stats_changed.emit()
