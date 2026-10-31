class_name JobFxShaman
extends RefCounted
## Особые механики Шамана (← Kahuna из Rappelz, данные умений — JobSkills, раздел «Шаман»); подключение —
## HeroSkillFx.JOB_FX_FILES (шесть функций, описание — шапка HeroSkillFx).
## • Зачарование оружия — четыре лезвия стихий (переключаемые, группа "edge": одно за раз). Каждая попавшая
##   обычная атака (удар топором, сгусток посоха, второй удар) добавляет урон стихией: бонус "edge" — доля маг.
##   атаки, против маг. защиты зверя; огонь — сильнее, молния — шанс оглушить ("edge_stun", STUN_TIME с),
##   земля — шанс отравить ("edge_poison", яд POISON_TIME с), вода — шанс вернуть MP ("edge_mp", WATER_MP запаса).
## • «Огненная кожа» (бонус "thorns"): зверь, ударивший шамана ближе THORNS_RANGE м, получает огнём долю маг. атаки.
## • «Неистовство огня» — огонь жжёт шамана (self_burn: доля макс. HP в секунду, не до смерти, значок у полоски HP);
##   «Неистовство грома» — цена HP при применении (hp_cost). Сами усиления — эффект "buff" движка.
## Остальные умения Шамана — данные движка (заклинания, удержание, сон, лечение со временем, ауры, усиления).

const EDGES := {
	"fire_edge": Color(1.0, 0.5, 0.2), "storm_edge": Color(0.6, 0.7, 1.0),
	"stone_edge": Color(0.7, 0.55, 0.3), "water_edge": Color(0.35, 0.7, 1.0),
}
const STUN_TIME := 1.5
## Яд «Каменного лезвия»: доля маг. атаки в секунду, длительность, с.
const POISON_DPS := 0.12
const POISON_TIME := 6.0
## «Водное лезвие»: доля запаса MP за срабатывание.
const WATER_MP := 0.03
const THORNS_RANGE := 4.0
const FIRE := Color(1.0, 0.45, 0.15)


## Включённое лезвие ("" — нет).
static func active_edge() -> String:
	for id in EDGES:
		if HeroSkills.toggle_on(Game.hero, String(id)):
			return String(id)
	return ""


# ---------- Подключение (HeroSkillFx.JOB_FX_FILES) ----------

static func pre_cast(_fx: HeroSkillFx, _sid: String, _n: int, _sk: Dictionary) -> String:
	return ""


static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, _t: Mob, e: Dictionary) -> bool:
	var p := fx.p
	match handler:
		"self_burn":
			var sec := HeroSkills.value_at(e.get("time", 15.0), n)
			fx.state["burn"] = {"id": sid, "left": sec, "pct": HeroSkills.value_at(e.get("pct", 0.01), n), "acc": 0.0}
			var info := StatusEffects.effect_info("dot", StatusEffects.source_hero_skill(sid))
			info["name"] = "Огонь жжёт шамана"
			p.effects.add("burn:" + sid, sec, info)
			Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), FIRE, 1.6, 0.45)
			return true
		"hp_cost":
			var cost := roundi(float(p.max_hp) * HeroSkills.value_at(e.get("pct", 0.1), n))
			cost = mini(cost, p.hp - 1)
			if cost > 0:
				p.hp -= cost
				Util.float_text(p.get_parent(), p.global_position + Vector3(0, 2.4, 0), "−%d" % cost, Color(1, 0.4, 0.35))
				p.stats_changed.emit()
			Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), EDGES["storm_edge"], 1.6, 0.45)
			return true
	return false


## Попавшая обычная атака с лезвием: урон стихией и свойство лезвия.
static func on_basic_hit(fx: HeroSkillFx, t: Mob, _dealt: int) -> void:
	var p := fx.p
	var edge := float(p.skill_bonus.get("edge", 0.0))
	if edge <= 0.0 or t.is_dead:
		return
	var sid := active_edge()
	var col: Color = EDGES.get(sid, FIRE)
	var dmg := maxi(1, roundi(float(p.cur_matk()) * edge * p.damage_factor(t, true)))
	t.take_damage(dmg, p, false, true)
	fx.state["edge_hits"] = int(fx.state.get("edge_hits", 0)) + 1
	if p.is_inside_tree():
		Vfx.hit_spark(p.get_parent(), t.aim_point(), col, 1.1)
	if t.is_dead:
		return
	var src: Dictionary = StatusEffects.source_hero_skill(sid) if sid != "" else {}
	var st := float(p.skill_bonus.get("edge_stun", 0.0))
	if st > 0.0 and randf() < st:
		t.stun(STUN_TIME, src)
	var po := float(p.skill_bonus.get("edge_poison", 0.0))
	if po > 0.0 and randf() < po:
		t.add_dot("stone_edge", float(p.cur_matk()) * POISON_DPS * p.damage_factor(t, true), POISON_TIME, p, false, src)
	var wm := float(p.skill_bonus.get("edge_mp", 0.0))
	if wm > 0.0 and randf() < wm:
		p._gain_mp(float(p.max_mp) * WATER_MP)
		fx.state["edge_mp_hits"] = int(fx.state.get("edge_mp_hits", 0)) + 1


## «Огненная кожа»: ответ огнём зверю, ударившему вблизи.
static func on_hurt(fx: HeroSkillFx, attacker: Node3D, _amount: int) -> void:
	var p := fx.p
	var th := float(p.skill_bonus.get("thorns", 0.0))
	if th <= 0.0 or not is_instance_valid(attacker) or not (attacker is Mob):
		return
	var m := attacker as Mob
	if m.is_dead or m.global_position.distance_to(p.global_position) > THORNS_RANGE:
		return
	m.take_damage(maxi(1, roundi(float(p.cur_matk()) * th * p.damage_factor(m, true))), p, false, true)
	fx.state["thorns_hits"] = int(fx.state.get("thorns_hits", 0)) + 1
	if p.is_inside_tree():
		Vfx.hit_spark(p.get_parent(), m.aim_point(), FIRE, 1.2)


## Горение «Неистовства огня»: доля макс. HP в секунду (не ниже 1 HP).
static func tick(fx: HeroSkillFx, delta: float) -> void:
	if not fx.state.has("burn"):
		return
	var p := fx.p
	var b: Dictionary = fx.state["burn"]
	b["left"] = float(b["left"]) - delta
	b["acc"] = float(b["acc"]) + float(p.max_hp) * float(b["pct"]) * delta
	var whole := int(float(b["acc"]))
	if whole >= 1:
		b["acc"] = float(b["acc"]) - float(whole)
		if p.hp > 1:
			p.hp = maxi(1, p.hp - whole)
			p.stats_changed.emit()
	var id := "burn:" + String(b["id"])
	p.effects.sync(id, float(b["left"]))
	if float(b["left"]) <= 0.0:
		fx.state.erase("burn")


static func reset(fx: HeroSkillFx) -> void:
	if fx.state.has("burn"):
		fx.p.effects.remove("burn:" + String((fx.state["burn"] as Dictionary)["id"]))
		fx.state.erase("burn")
