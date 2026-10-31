class_name JobFxWarrior
extends RefCounted
## Особые механики Воина (← Fighter из Rappelz, данные умений — JobSkills, раздел «Воин»); подключение —
## HeroSkillFx.JOB_FX_FILES (шесть функций, описание — шапка HeroSkillFx).
## • Искры духа: запас — пассивка «Запас искр» (бонус "sparks": 1…3). Искра загорается за каждые
##   HeroSkills.SPARK_HITS попавших обычных атак (удар топором, выстрел из лука, второй удар «Ярости дикаря»)
##   и от «Разжечь искру». Тратят: spark_cost умения (столько искр, без них умение не применяется — «Ударная
##   искра», «Стрела стужи»), spark_spend (все, но не больше числа, нужна хотя бы одна — «Вдох силы»,
##   «Искра крепости»; сила — за каждую потраченную). Счётчик у героя — значок «Запас искр» с числом у полоски HP
##   (StatusEffects, id "spark:charges"). Смерть и смена профессии гасят искры (reset).
## • «Ядовитый наконечник» (бонус "poison" — шанс): попавший выстрел из лука травит зверя на POISON_TIME с.
## Остальные умения Воина — данные движка (урон, площадь, оглушение, замедление, кровотечение, двойной удар).

const SPARK_COLOR := Color(1.0, 0.72, 0.28)
const POISON_COLOR := Color(0.45, 0.85, 0.3)
## Яд «Ядовитого наконечника»: доля атаки в секунду, длительность, с.
const POISON_DPS := 0.15
const POISON_TIME := 8.0
## Значок счётчика искр (StatusEffects).
const SPARK_FX := "spark:charges"


## Искр духа сейчас.
static func sparks(fx: HeroSkillFx) -> int:
	return int(fx.state.get("sparks", 0))


## Сколько искр можно держать («Запас искр»; 0 — не изучено).
static func max_sparks(fx: HeroSkillFx) -> int:
	return roundi(float(fx.p.skill_bonus.get("sparks", 0.0)))


## Прибавить (k > 0) или потратить (k < 0) искры в пределах запаса. Возвращает, на сколько изменилось.
static func add_sparks(fx: HeroSkillFx, k: int) -> int:
	var cur := sparks(fx)
	var mx := max_sparks(fx)
	var nv := clampi(cur + k, 0, maxi(mx, 0))
	fx.state["sparks"] = nv
	show_sparks(fx)
	var p := fx.p
	if nv > cur and p.is_inside_tree():
		Util.float_text(p.get_parent(), p.global_position + Vector3(0, 2.7, 0), "Искра духа %d/%d" % [nv, mx], SPARK_COLOR)
		Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.1, 0), SPARK_COLOR, 0.9, 0.3)
	return nv - cur


## Значок с числом искр у полоски HP героя (нет искр — значка нет).
static func show_sparks(fx: HeroSkillFx) -> void:
	var n := sparks(fx)
	var on := {}
	if n > 0:
		on[SPARK_FX] = {"name": "Искры духа %d/%d" % [n, max_sparks(fx)], "src": "Запас искр",
			"icon": IconView.hero_skill("spark_reserve"), "debuff": false, "count": n}
	fx.p.effects.sync_toggles("spark:", on)


static func _has_handler(sk: Dictionary, handler: String) -> bool:
	for e in sk.get("fx", []):
		var d: Dictionary = e
		if String(d.get("do", "")) == "special" and String(d.get("handler", "")) == handler:
			return true
	return false


# ---------- Подключение (HeroSkillFx.JOB_FX_FILES) ----------

## Проверить и списать искры умения (spark_cost / spark_spend); «Разжечь искру» — есть ли куда.
static func pre_cast(fx: HeroSkillFx, _sid: String, n: int, sk: Dictionary) -> String:
	if sk.has("spark_cost"):
		var need := maxi(1, roundi(HeroSkills.value_at(sk["spark_cost"], n)))
		if sparks(fx) < need:
			return "нужна искра духа (есть %d из %d)" % [sparks(fx), need]
		add_sparks(fx, -need)
		fx.state["spent"] = need
	elif sk.has("spark_spend"):
		var have := sparks(fx)
		if have < 1:
			return "нужна хотя бы одна искра духа"
		var k := mini(have, maxi(1, roundi(HeroSkills.value_at(sk["spark_spend"], n))))
		add_sparks(fx, -k)
		fx.state["spent"] = k
	elif _has_handler(sk, "spark_gain"):
		var mx := max_sparks(fx)
		if mx <= 0:
			return "нужно умение «Запас искр»"
		if sparks(fx) >= mx:
			return "искр духа уже %d — больше не удержать" % mx
	return ""


static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, _t: Mob, e: Dictionary) -> bool:
	var p := fx.p
	match handler:
		"spark_gain":
			add_sparks(fx, 1)
			return true
		"spark_heal":
			# «Вдох силы»: за каждую потраченную искру — доля макс. HP и MP
			var k := float(fx.state.get("spent", 1))
			p.heal(maxi(1, roundi(float(p.max_hp) * HeroSkills.value_at(e.get("hp", 0.0), n) * k)))
			p._gain_mp(float(p.max_mp) * HeroSkills.value_at(e.get("mp_pct", 0.0), n) * k)
			Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), SPARK_COLOR, 1.6, 0.45)
			return true
		"spark_vigor":
			# «Искра крепости»: Выносливость за каждую потраченную искру на время
			var k := float(fx.state.get("spent", 1))
			p.add_timed_bonus(sid, HeroSkills.value_at(e.get("time", 30.0), n), {"vit": HeroSkills.value_at(e.get("vit", 4.0), n) * k})
			Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), Color(0.95, 0.55, 0.3), 1.6, 0.45)
			return true
	return false


## Попавшая обычная атака: искры копятся; выстрел из лука с «Ядовитым наконечником» может отравить.
static func on_basic_hit(fx: HeroSkillFx, t: Mob, _dealt: int) -> void:
	var p := fx.p
	if max_sparks(fx) > 0:
		var h := int(fx.state.get("spark_hits", 0)) + 1
		if h >= HeroSkills.SPARK_HITS:
			h = 0
			if sparks(fx) < max_sparks(fx):
				add_sparks(fx, 1)
		fx.state["spark_hits"] = h
	var pc := float(p.skill_bonus.get("poison", 0.0))
	if pc > 0.0 and p.attack_kind == "ranged" and not t.is_dead and randf() < pc:
		var dps := float(p.cur_atk()) * POISON_DPS * p.damage_factor(t, false)
		t.add_dot("venom_tip", dps, POISON_TIME, p, false, StatusEffects.source_hero_skill("venom_tip"))
		fx.state["poisoned"] = int(fx.state.get("poisoned", 0)) + 1
		if p.is_inside_tree():
			Vfx.hit_spark(p.get_parent(), t.aim_point(), POISON_COLOR, 0.9)


static func on_hurt(_fx: HeroSkillFx, _attacker: Node3D, _amount: int) -> void:
	pass


static func tick(_fx: HeroSkillFx, _delta: float) -> void:
	pass


## Искры гаснут (смерть, смена профессии).
static func reset(fx: HeroSkillFx) -> void:
	fx.state.erase("sparks")
	fx.state.erase("spark_hits")
	fx.state.erase("spent")
	fx.p.effects.sync_toggles("spark:", {})
