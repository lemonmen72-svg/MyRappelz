class_name VfxArchetypes
extends RefCounted
## Архетипы эффектов (генератор VFX, docs/vfx/VFX_ARCHITECTURE.md): пресет {arch, el, scale, dur, k, seed, …} →
## узел эффекта из слоёв VfxKit. Палитра — по стихии (PALETTES: ядро, основной, второй, искры, дым), у каждого
## эффекта 3–6 слоёв разного вида (вспышка, частицы, волна, след на земле, дым, искры), а не один цвет.
## Качество q: 0 — низкое (меньше частиц, без вторичных слоёв), 1 — среднее, 2 — высокое (+ краткий огонь).
## Фазы: "cast" (на герое во время каста — постоянный, останавливает stop()), "release" (выпуск на герое),
## "impact" (попадание по цели), "area" (по площади), "buff" (усиление на ком-то), "projectile" (вид снаряда).

const QMUL := [0.4, 0.7, 1.0]

## Палитры стихий: core — раскалённое ядро, a — основной, b — второй, c — искры/акцент, smoke — дым и пыль.
const PALETTES := {
	"fire": {"core": Color(1.0, 0.96, 0.75), "a": Color(1.0, 0.55, 0.12), "b": Color(0.95, 0.18, 0.06),
		"c": Color(1.0, 0.85, 0.3), "smoke": Color(0.28, 0.2, 0.18, 0.75)},
	"ice": {"core": Color(0.92, 1.0, 1.0), "a": Color(0.45, 0.85, 1.0), "b": Color(0.3, 0.5, 1.0),
		"c": Color(0.8, 0.98, 1.0), "smoke": Color(0.85, 0.95, 1.0, 0.55)},
	"water": {"core": Color(0.85, 1.0, 1.0), "a": Color(0.22, 0.65, 1.0), "b": Color(0.1, 0.38, 0.9),
		"c": Color(0.55, 0.95, 1.0), "smoke": Color(0.9, 0.97, 1.0, 0.6)},
	"earth": {"core": Color(1.0, 0.9, 0.6), "a": Color(0.78, 0.56, 0.3), "b": Color(0.48, 0.34, 0.2),
		"c": Color(1.0, 0.78, 0.35), "smoke": Color(0.62, 0.52, 0.4, 0.7)},
	"storm": {"core": Color(1.0, 1.0, 1.0), "a": Color(0.5, 0.7, 1.0), "b": Color(0.72, 0.45, 1.0),
		"c": Color(1.0, 1.0, 0.65), "smoke": Color(0.55, 0.6, 0.85, 0.45)},
	"light": {"core": Color(1.0, 1.0, 0.95), "a": Color(1.0, 0.86, 0.42), "b": Color(1.0, 0.68, 0.3),
		"c": Color(1.0, 0.98, 0.8), "smoke": Color(1.0, 0.95, 0.8, 0.45)},
	"heal": {"core": Color(0.95, 1.0, 0.9), "a": Color(0.42, 1.0, 0.55), "b": Color(0.75, 1.0, 0.45),
		"c": Color(1.0, 0.95, 0.6), "smoke": Color(0.8, 1.0, 0.85, 0.45)},
	"dark": {"core": Color(0.1, 0.03, 0.16, 0.9), "a": Color(0.58, 0.28, 0.95), "b": Color(0.92, 0.3, 0.82),
		"c": Color(0.75, 0.55, 1.0), "smoke": Color(0.16, 0.06, 0.22, 0.8)},
	# Секта Мрака: кислотно-изумрудный #39FF8A только для ритуалов, душ, проклятий (ТЗ, раздел 5)
	"emerald": {"core": Color(0.85, 1.0, 0.9), "a": Color(0.22, 1.0, 0.54), "b": Color(0.05, 0.55, 0.5),
		"c": Color(0.55, 0.25, 0.85), "smoke": Color(0.03, 0.12, 0.09, 0.8)},
	"poison": {"core": Color(0.9, 1.0, 0.7), "a": Color(0.55, 1.0, 0.25), "b": Color(0.3, 0.72, 0.15),
		"c": Color(0.8, 1.0, 0.35), "smoke": Color(0.3, 0.45, 0.15, 0.7)},
	"blood": {"core": Color(1.0, 0.75, 0.75), "a": Color(0.95, 0.12, 0.22), "b": Color(0.55, 0.04, 0.12),
		"c": Color(1.0, 0.45, 0.4), "smoke": Color(0.35, 0.05, 0.08, 0.75)},
	"wind": {"core": Color(0.95, 1.0, 0.97), "a": Color(0.5, 1.0, 0.78), "b": Color(0.3, 0.85, 0.72),
		"c": Color(0.85, 1.0, 0.92), "smoke": Color(0.85, 1.0, 0.95, 0.45)},
	"spirit": {"core": Color(1.0, 0.97, 0.85), "a": Color(1.0, 0.72, 0.32), "b": Color(1.0, 0.48, 0.82),
		"c": Color(0.6, 0.85, 1.0), "smoke": Color(1.0, 0.9, 0.8, 0.45)},
	"mind": {"core": Color(0.95, 0.95, 1.0), "a": Color(0.48, 0.68, 1.0), "b": Color(0.78, 0.55, 1.0),
		"c": Color(0.9, 0.95, 1.0), "smoke": Color(0.75, 0.8, 1.0, 0.45)},
	"steel": {"core": Color(1.0, 1.0, 1.0), "a": Color(0.82, 0.88, 1.0), "b": Color(0.55, 0.7, 1.0),
		"c": Color(1.0, 0.88, 0.55), "smoke": Color(0.75, 0.75, 0.8, 0.5)},
	"shield": {"core": Color(0.95, 0.98, 1.0), "a": Color(0.45, 0.72, 1.0), "b": Color(0.85, 0.95, 1.0),
		"c": Color(1.0, 0.85, 0.4), "smoke": Color(0.75, 0.85, 1.0, 0.45)},
	"beast": {"core": Color(1.0, 0.95, 0.8), "a": Color(0.75, 1.0, 0.38), "b": Color(1.0, 0.65, 0.25),
		"c": Color(1.0, 0.9, 0.5), "smoke": Color(0.55, 0.5, 0.35, 0.6)},
}

## Архетипы: фаза, категория ТЗ, название (каталог).
const LIST := {
	"explosion": {"phase": "area", "cat": "fire", "title": "Огненный взрыв"},
	"flame_burst": {"phase": "impact", "cat": "fire", "title": "Вспышка пламени"},
	"frost_nova": {"phase": "area", "cat": "ice", "title": "Морозная волна"},
	"ice_shards": {"phase": "impact", "cat": "ice", "title": "Ледяные осколки"},
	"water_splash": {"phase": "impact", "cat": "water", "title": "Всплеск воды"},
	"water_wave": {"phase": "area", "cat": "water", "title": "Водяная волна"},
	"rock_impact": {"phase": "impact", "cat": "earth", "title": "Удар камня"},
	"ground_spike": {"phase": "area", "cat": "earth", "title": "Шипы из земли"},
	"shockwave": {"phase": "area", "cat": "earth", "title": "Ударная волна"},
	"lightning_strike": {"phase": "impact", "cat": "storm", "title": "Молния с неба"},
	"lightning_bolt": {"phase": "impact", "cat": "storm", "title": "Разряд от героя"},
	"spark_hit": {"phase": "impact", "cat": "storm", "title": "Искры разряда"},
	"heal_burst": {"phase": "buff", "cat": "light", "title": "Исцеление"},
	"holy_beam": {"phase": "impact", "cat": "light", "title": "Столб света"},
	"holy_nova": {"phase": "area", "cat": "light", "title": "Сияющий круг"},
	"shield": {"phase": "buff", "cat": "light", "title": "Щит"},
	"blessing": {"phase": "buff", "cat": "light", "title": "Благословение"},
	"shadow_burst": {"phase": "impact", "cat": "dark", "title": "Взрыв тьмы"},
	"cursed_sigil": {"phase": "area", "cat": "dark", "title": "Проклятый знак"},
	"soul_drain": {"phase": "impact", "cat": "dark", "title": "Похищение жизни"},
	"emerald_curse": {"phase": "buff", "cat": "dark", "title": "Изумрудное проклятие"},
	"toxic_pool": {"phase": "area", "cat": "dark", "title": "Ядовитая лужа"},
	"blood_burst": {"phase": "impact", "cat": "dark", "title": "Кровавый всплеск"},
	"wind_slash": {"phase": "impact", "cat": "wind", "title": "Ветряной серп"},
	"tornado": {"phase": "area", "cat": "wind", "title": "Вихрь"},
	"slash": {"phase": "impact", "cat": "weapon", "title": "Удар клинком"},
	"cleave": {"phase": "impact", "cat": "weapon", "title": "Тяжёлый удар"},
	"stab": {"phase": "impact", "cat": "weapon", "title": "Укол"},
	"blunt_hit": {"phase": "impact", "cat": "weapon", "title": "Дробящий удар"},
	"spin_slash": {"phase": "area", "cat": "weapon", "title": "Круговой удар"},
	"arrow_impact": {"phase": "impact", "cat": "weapon", "title": "Попадание стрелы"},
	"claw": {"phase": "impact", "cat": "beast", "title": "Удар когтями"},
	"roar": {"phase": "buff", "cat": "beast", "title": "Рёв"},
	"spirit_burst": {"phase": "impact", "cat": "spirit", "title": "Вспышка духа"},
	"ritual_circle": {"phase": "area", "cat": "dark", "title": "Ритуальный круг"},
	"ghost": {"phase": "impact", "cat": "dark", "title": "Призрак"},
	"cast_gather": {"phase": "cast", "cat": "cast", "title": "Каст: сбор силы"},
	"release": {"phase": "release", "cat": "cast", "title": "Выпуск силы"},
	"buff_up": {"phase": "buff", "cat": "buff", "title": "Усиление"},
	"orb": {"phase": "projectile", "cat": "projectile", "title": "Снаряд стихии"},
}


## Палитра стихии el (нет такой — steel). tint ≠ прозрачный — основной цвет заменяется оттенком tint.
static func palette(el: String, tint: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var p: Dictionary = (PALETTES.get(el, PALETTES["steel"]) as Dictionary).duplicate()
	if tint.a > 0.0:
		p["a"] = tint
	return p


## Собрать эффект пресета pr в точке pos у родителя parent. o: q (качество 0–2), dir (направление удара),
## ground (точка земли под эффектом), from (откуда — герой), to (куда — цель), height (рост цели).
## Возвращает корень эффекта (удаляется сам) или null.
static func build(pr: Dictionary, parent: Node, pos: Vector3, o: Dictionary = {}) -> Node3D:
	var arch := String(pr.get("arch", ""))
	if not LIST.has(arch) or arch == "orb":
		return null
	var dur := clampf(float(pr.get("dur", 0.8)), 0.2, 12.0)
	var root := Vfx._root(parent, pos, dur + 1.6)
	if root == null:
		return null
	root.set_meta("vfx_arch", arch)
	var P := _ctx(pr, root, pos, o)
	match arch:
		"explosion":
			_a_explosion(P)
		"flame_burst":
			_a_flame_burst(P)
		"frost_nova":
			_a_frost_nova(P)
		"ice_shards":
			_a_ice_shards(P)
		"water_splash":
			_a_water_splash(P)
		"water_wave":
			_a_water_wave(P)
		"rock_impact":
			_a_rock_impact(P)
		"ground_spike":
			_a_ground_spike(P)
		"shockwave":
			_a_shockwave(P)
		"lightning_strike":
			_a_lightning_strike(P)
		"lightning_bolt":
			_a_lightning_bolt(P)
		"spark_hit":
			_a_spark_hit(P)
		"heal_burst":
			_a_heal_burst(P)
		"holy_beam":
			_a_holy_beam(P)
		"holy_nova":
			_a_holy_nova(P)
		"shield":
			_a_shield(P)
		"blessing":
			_a_blessing(P)
		"buff_up":
			_a_buff_up(P)
		"shadow_burst":
			_a_shadow_burst(P)
		"cursed_sigil":
			_a_cursed_sigil(P)
		"emerald_curse":
			_a_emerald_curse(P)
		"soul_drain":
			_a_soul_drain(P)
		"toxic_pool":
			_a_toxic_pool(P)
		"blood_burst":
			_a_blood_burst(P)
		"ritual_circle":
			_a_ritual_circle(P)
		"ghost":
			_a_ghost(P)
		"wind_slash":
			_a_wind_slash(P)
		"tornado":
			_a_tornado(P)
		"slash":
			_a_slash(P)
		"cleave":
			_a_cleave(P)
		"stab":
			_a_stab(P)
		"blunt_hit":
			_a_blunt_hit(P)
		"spin_slash":
			_a_spin_slash(P)
		"arrow_impact":
			_a_arrow_impact(P)
		"claw":
			_a_claw(P)
		"roar":
			_a_roar(P)
		"spirit_burst":
			_a_spirit_burst(P)
		"cast_gather":
			_a_cast_gather(P)
		"release":
			_a_release(P)
	return root


static func _ctx(pr: Dictionary, root: Node3D, pos: Vector3, o: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pr.get("seed", 1))
	var tint: Color = Color(0, 0, 0, 0)
	if pr.has("tint"):
		var t: Array = pr["tint"]
		tint = Color(float(t[0]), float(t[1]), float(t[2]))
	var dir: Vector3 = o.get("dir", Vector3.FORWARD)
	if Vector3(dir.x, 0, dir.z).length() < 0.01:
		dir = Vector3.FORWARD
	return {
		"root": root, "pos": pos, "pal": palette(String(pr.get("el", "steel")), tint),
		"s": clampf(float(pr.get("scale", 1.0)), 0.3, 4.0), "dur": clampf(float(pr.get("dur", 0.8)), 0.2, 12.0),
		"k": clampf(float(pr.get("k", 1.0)), 0.3, 2.0), "q": clampi(int(o.get("q", 1)), 0, 2), "rng": rng,
		"dir": Vector3(dir.x, 0, dir.z).normalized(), "ground": o.get("ground", pos - Vector3(0, 1.0, 0)),
		"from": o.get("from", pos + Vector3(0, 0, 2)), "to": o.get("to", pos),
		"h": float(o.get("height", 1.7)),
	}


## Число частиц с учётом качества и интенсивности.
static func _n(P: Dictionary, base: float) -> int:
	return maxi(1, int(roundf(base * float(QMUL[int(P["q"])]) * float(P["k"]))))


static func _c(P: Dictionary, key: String) -> Color:
	return (P["pal"] as Dictionary)[key]


## Вторичные слои — со среднего качества.
static func _rich(P: Dictionary) -> bool:
	return int(P["q"]) >= 1


static func _hi(P: Dictionary) -> bool:
	return int(P["q"]) >= 2


static func _local_ground(P: Dictionary) -> Vector3:
	return P["ground"]


# ---------- Огонь ----------

static func _a_explosion(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", _c(P, "core"), 2.6 * s, t * 0.5)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.85), 1.4 * s, t * 0.7, Vector3.ZERO, true)
	VfxKit.sphere(r, Color(_c(P, "b"), 0.55), 1.9 * s, t * 0.9, Vector3.ZERO, false, 0.3)
	VfxKit.particles(r, {"amount": _n(P, 26), "life": t * 0.9, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.9 * s, "speed": 4.2 * s, "tex": "flame", "damping": 4.0, "gravity": Vector3(0, 3.0, 0),
		"radius": 0.3 * s, "curve": "grow", "hue": 0.04})
	VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 1.3, "color": _c(P, "c"), "size": 0.16 * s,
		"speed": 7.0 * s, "tex": "star", "gravity": Vector3(0, -5.0, 0), "damping": 1.2, "curve": "twinkle"})
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.9), _local_ground(P), 4.2 * s, t * 0.7, true)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 1.8, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.3 * s, "speed": 1.6 * s, "tex": "smoke", "add": false,
			"gravity": Vector3(0, 1.4, 0), "damping": 1.5, "radius": 0.6 * s, "curve": "grow", "delay": t * 0.12})
		VfxKit.decal(r, "crack", Color(0.15, 0.06, 0.03, 0.85), _local_ground(P), 3.0 * s, t * 2.2, false, 0.6, 0.15)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 4.0, 7.0 * s, t * 0.6)


static func _a_flame_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", _c(P, "core"), 1.6 * s, t * 0.45)
	VfxKit.flash(r, "flame", Color(_c(P, "a"), 0.95), 1.9 * s, t * 0.6, true, Vector3(0, 0.3 * s, 0))
	VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 0.8, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.6 * s, "speed": 2.6 * s, "tex": "flame", "dir": Vector3.UP, "spread": 70.0, "damping": 2.0,
		"gravity": Vector3(0, 4.0, 0), "curve": "grow", "hue": 0.04})
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 1.1, "color": _c(P, "c"), "size": 0.12 * s, "speed": 5.0 * s,
		"tex": "star", "gravity": Vector3(0, -4.0, 0), "curve": "twinkle"})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 6), "life": t * 1.6, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.8 * s, "speed": 1.0, "tex": "smoke", "add": false,
			"gravity": Vector3(0, 1.6, 0), "curve": "grow", "delay": t * 0.2})


# ---------- Лёд и вода ----------

static func _a_frost_nova(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.flash(r, "snow", _c(P, "core"), 2.4 * s, t * 0.5)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 5.0 * s, t * 0.8, true)
	VfxKit.decal(r, "rune", Color(_c(P, "c"), 0.7), g, 3.4 * s, t * 1.4, true, 0.8, 0.2, 0.15)
	var ring := VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 0.9, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.5 * s, "speed": 5.0 * s, "mesh": "shard", "shape": "ring",
		"radius": 0.4 * s, "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -9.0, 0), "align": true})
	ring.global_position = g + Vector3(0, 0.2, 0)
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.2, "color": _c(P, "core"), "size": 0.2 * s,
		"speed": 3.5 * s, "tex": "snow", "gravity": Vector3(0, -1.0, 0), "spin": 180.0, "curve": "twinkle"})
	if _rich(P):
		var mist := VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 1.8, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.4 * s, "speed": 2.4 * s, "tex": "smoke", "add": false,
			"shape": "ring", "radius": 0.5 * s, "dir": Vector3.UP, "spread": 90.0, "damping": 2.0, "curve": "grow"})
		mist.global_position = g + Vector3(0, 0.3, 0)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 2.5, 6.0 * s, t * 0.5)


static func _a_ice_shards(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "snow", _c(P, "core"), 1.6 * s, t * 0.5)
	VfxKit.flash(r, "star", Color(_c(P, "a"), 0.9), 1.3 * s, t * 0.4)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.8, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.2),
		"size": 0.45 * s, "speed": 5.5 * s, "mesh": "shard", "gravity": Vector3(0, -8.0, 0), "align": true})
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t, "color": _c(P, "core"), "size": 0.18 * s, "speed": 2.5 * s,
		"tex": "snow", "spin": 200.0, "curve": "twinkle"})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 5), "life": t * 1.3, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.8 * s, "speed": 0.8, "tex": "smoke", "add": false,
			"curve": "grow"})


static func _a_water_splash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "soft", Color(_c(P, "c"), 0.9), 1.6 * s, t * 0.4)
	VfxKit.torus(r, Color(_c(P, "a"), 0.7), 1.3 * s, t * 0.7, Vector3.ZERO, true, Vector3(PI / 2.0, 0, 0))
	VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 0.9, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.28 * s, "speed": 5.0 * s, "tex": "drop", "dir": Vector3.UP, "spread": 65.0,
		"gravity": Vector3(0, -12.0, 0), "align": true})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.8, "color": _c(P, "core"), "size": 0.5 * s,
		"speed": 2.2 * s, "tex": "soft", "damping": 3.0, "curve": "grow"})
	if _rich(P):
		VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.8), _local_ground(P), 2.6 * s, t * 0.8, true)


static func _a_water_wave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 5.5 * s, t * 0.9, true)
	VfxKit.decal(r, "wave", Color(_c(P, "c"), 0.8), g, 3.6 * s, t * 0.9, true, 0.1, 1.0, 0.0, t * 0.18)
	VfxKit.torus(r, Color(_c(P, "a"), 0.6), 2.6 * s, t * 0.8, g - r.global_position + Vector3(0, 0.3, 0), true,
		Vector3.ZERO, 1.4)
	var drops := VfxKit.particles(r, {"amount": _n(P, 28), "life": t, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.3 * s, "speed": 5.5 * s, "tex": "drop", "shape": "ring",
		"radius": 1.2 * s, "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, -12.0, 0), "align": true})
	drops.global_position = g + Vector3(0, 0.2, 0)
	if _rich(P):
		var foam := VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 1.3, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.9 * s, "speed": 3.0 * s, "tex": "soft", "add": false,
			"shape": "ring", "radius": 0.8 * s, "dir": Vector3.UP, "spread": 85.0, "damping": 3.0, "curve": "grow"})
		foam.global_position = g + Vector3(0, 0.2, 0)


# ---------- Земля ----------

static func _a_rock_impact(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", Color(_c(P, "c"), 0.9), 1.4 * s, t * 0.35)
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 1.1, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.9),
		"size": 0.3 * s, "speed": 5.0 * s, "mesh": "rock", "lit": true, "gravity": Vector3(0, -14.0, 0),
		"spin": 360.0})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 1.4, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 0.9 * s, "speed": 2.0 * s, "tex": "smoke", "add": false,
		"damping": 3.0, "gravity": Vector3(0, 0.6, 0), "curve": "grow"})
	if _rich(P):
		VfxKit.decal(r, "crack", Color(0.18, 0.12, 0.06, 0.8), _local_ground(P), 2.2 * s, t * 2.0, false, 0.7, 0.12)
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 0.7, "color": _c(P, "c"), "size": 0.12 * s,
			"speed": 6.0 * s, "tex": "star", "gravity": Vector3(0, -6.0, 0), "curve": "twinkle"})


static func _a_ground_spike(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.decal(r, "crack", Color(0.2, 0.12, 0.05, 0.9), g, 3.6 * s, t * 2.0, false, 0.5, 0.12)
	VfxKit.spikes(r, _c(P, "a"), g, maxi(3, _n(P, 9)), 1.3 * s, 1.6 * s, t * 1.5, rng)
	var dust := VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 1.4, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 2.4 * s, "tex": "smoke", "add": false,
		"shape": "ring", "radius": 0.9 * s, "dir": Vector3.UP, "spread": 70.0, "damping": 2.5, "curve": "grow"})
	dust.global_position = g + Vector3(0, 0.2, 0)
	if _rich(P):
		var rocks := VfxKit.particles(r, {"amount": _n(P, 10), "life": t, "color": _c(P, "b"), "size": 0.22 * s,
			"speed": 5.0 * s, "mesh": "rock", "lit": true, "dir": Vector3.UP, "spread": 50.0,
			"gravity": Vector3(0, -14.0, 0), "spin": 300.0})
		rocks.global_position = g + Vector3(0, 0.2, 0)
		VfxKit.flash(r, "star", Color(_c(P, "c"), 0.8), 2.0 * s, t * 0.35, true, g - r.global_position)


static func _a_shockwave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	VfxKit.decal(r, "wave", Color(_c(P, "c"), 0.95), g, 5.2 * s, t * 0.75, true)
	VfxKit.torus(r, Color(_c(P, "a"), 0.65), 2.8 * s, t * 0.7, off + Vector3(0, 0.25, 0), true, Vector3.ZERO, 0.8)
	VfxKit.decal(r, "crack", Color(0.18, 0.1, 0.04, 0.85), g, 3.2 * s, t * 2.0, false, 0.6, 0.12)
	var dust := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.3, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 4.5 * s, "tex": "smoke", "add": false,
		"shape": "ring", "radius": 0.6 * s, "dir": Vector3.UP, "spread": 88.0, "damping": 3.0, "curve": "grow"})
	dust.global_position = g + Vector3(0, 0.2, 0)
	if _rich(P):
		var rocks := VfxKit.particles(r, {"amount": _n(P, 10), "life": t, "color": _c(P, "a"), "size": 0.2 * s,
			"speed": 4.5 * s, "mesh": "rock", "lit": true, "shape": "ring", "radius": 0.8 * s, "dir": Vector3.UP,
			"spread": 40.0, "gravity": Vector3(0, -14.0, 0), "spin": 300.0})
		rocks.global_position = g + Vector3(0, 0.2, 0)


# ---------- Молния ----------

static func _a_lightning_strike(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	var at := r.global_position
	var sky := at + Vector3(rng.randf_range(-1.0, 1.0), 9.0, rng.randf_range(-1.0, 1.0))
	VfxKit.bolt(r, Color(_c(P, "core"), 1.0), sky, at, 0.32 * s, t * 0.8, rng, 10, 0.7)
	VfxKit.bolt(r, Color(_c(P, "a"), 0.8), sky + Vector3(0.4, 0, 0), at, 0.6 * s, t * 0.7, rng, 8, 1.0)
	VfxKit.flash(r, "star", _c(P, "core"), 2.8 * s, t * 0.45)
	VfxKit.flash(r, "soft", Color(_c(P, "b"), 0.7), 3.2 * s, t * 0.6)
	VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.35 * s, "speed": 7.0 * s, "tex": "streak", "align": true, "gravity": Vector3(0, -6.0, 0)})
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.85), _local_ground(P), 3.0 * s, t * 0.6, true)
	if _rich(P):
		VfxKit.decal(r, "crack", Color(_c(P, "b"), 0.6), _local_ground(P), 2.2 * s, t * 1.2, true, 0.8, 0.1)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 5.0, 8.0 * s, t * 0.4)


static func _a_lightning_bolt(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	var a: Vector3 = P["from"]
	var b := r.global_position
	VfxKit.bolt(r, Color(_c(P, "core"), 1.0), a, b, 0.25 * s, t * 0.7, rng, 9, 0.45)
	VfxKit.bolt(r, Color(_c(P, "b"), 0.75), a, b, 0.5 * s, t * 0.6, rng, 7, 0.6)
	_a_spark_hit(P)


static func _a_spark_hit(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.flash(r, "star", _c(P, "core"), 1.7 * s, t * 0.4)
	VfxKit.flash(r, "soft", Color(_c(P, "a"), 0.8), 2.0 * s, t * 0.5)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.5, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.3 * s, "speed": 6.0 * s, "tex": "streak", "align": true})
	if _rich(P):
		var at := r.global_position
		for i in 3:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
			VfxKit.bolt(r, Color(_c(P, "a"), 0.9), at, at + d * 1.2 * s, 0.12 * s, t * 0.5, rng, 4, 0.25)


# ---------- Свет и лечение ----------

static func _a_heal_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.85), g, 2.6 * s, t * 1.4, true, 0.6, 0.3, 0.25)
	VfxKit.flash(r, "soft", Color(_c(P, "a"), 0.6), 2.4 * s, t * 0.8, true, off + Vector3(0, 1.0, 0))
	var up := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.2, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.35 * s, "speed": 2.2 * s, "tex": "plus", "shape": "ring",
		"radius": 0.6 * s, "dir": Vector3.UP, "spread": 12.0, "curve": "twinkle"})
	up.global_position = g + Vector3(0, 0.2, 0)
	var spark := VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.3, "color": _c(P, "c"), "size": 0.16 * s,
		"speed": 1.6 * s, "tex": "star", "shape": "ring", "radius": 0.8 * s, "dir": Vector3.UP, "spread": 25.0,
		"orbit": 3.0, "curve": "twinkle"})
	spark.global_position = g + Vector3(0, 0.4, 0)
	if _rich(P):
		VfxKit.torus(r, Color(_c(P, "b"), 0.55), 1.0 * s, t * 1.1, off + Vector3(0, 0.6, 0), true)


static func _a_holy_beam(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.pillar(r, Color(_c(P, "a"), 0.75), g, 0.9 * s, 9.0, t * 1.1)
	VfxKit.pillar(r, Color(_c(P, "core"), 0.9), g, 0.35 * s, 9.0, t * 0.9)
	VfxKit.flash(r, "star", _c(P, "core"), 2.8 * s, t * 0.5)
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.9), g, 3.0 * s, t * 1.3, true, 0.5, 0.25, 0.3)
	var fall := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.2, "color": _c(P, "c"), "size": 0.18 * s,
		"speed": 1.0, "tex": "star", "shape": "box", "box": Vector3(0.8, 0.2, 0.8) * s, "dir": Vector3.DOWN,
		"spread": 10.0, "gravity": Vector3(0, -3.0, 0), "curve": "twinkle", "explosive": 0.2})
	fall.global_position = g + Vector3(0, 4.5, 0)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 0.6, "color": _c(P, "a"), "size": 0.45 * s,
			"speed": 6.0 * s, "tex": "streak", "align": true, "dir": Vector3.UP, "spread": 90.0})
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 3.5, 7.0 * s, t * 0.7)


static func _a_holy_nova(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.flash(r, "star", _c(P, "core"), 3.0 * s, t * 0.5)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 5.6 * s, t * 0.8, true)
	VfxKit.decal(r, "rune", Color(_c(P, "c"), 0.8), g, 4.0 * s, t * 1.3, true, 0.7, 0.2, 0.2)
	VfxKit.torus(r, Color(_c(P, "b"), 0.6), 2.8 * s, t * 0.8, g - r.global_position + Vector3(0, 0.4, 0), true)
	var rays := VfxKit.particles(r, {"amount": _n(P, 20), "life": t * 0.8, "color": _c(P, "a"), "size": 0.5 * s,
		"speed": 7.0 * s, "tex": "streak", "align": true, "shape": "ring", "radius": 0.3, "dir": Vector3.UP,
		"spread": 75.0, "damping": 4.0})
	rays.global_position = g + Vector3(0, 0.4, 0)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.4, "color": _c(P, "c"), "size": 0.2 * s,
			"speed": 2.5 * s, "tex": "star", "gravity": Vector3(0, 0.8, 0), "curve": "twinkle", "radius": 1.5 * s})
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 3.0, 8.0 * s, t * 0.6)


static func _a_shield(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var h := float(P["h"])
	var center := Vector3(0, h * 0.5, 0) + (_local_ground(P) - r.global_position)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.32), 1.25 * s * maxf(h / 1.7, 0.7), t, center, true, 0.7, 0.55)
	VfxKit.torus(r, Color(_c(P, "b"), 0.8), 1.3 * s, t * 0.8, center, true, Vector3(0.4, 0, 0.2))
	VfxKit.torus(r, Color(_c(P, "c"), 0.7), 1.2 * s, t * 0.8, center, true, Vector3(-0.5, 0, -0.3))
	VfxKit.flash(r, "star", Color(_c(P, "core"), 0.9), 2.2 * s, t * 0.4, true, center)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.9, "color": _c(P, "c"), "size": 0.16 * s,
			"speed": 0.6, "tex": "star", "radius": 1.1 * s, "orbit": 4.0, "curve": "twinkle", "offset": center,
			"explosive": 0.4})


static func _a_blessing(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.9), g, 2.8 * s, t * 1.4, true, 0.4, 0.3, 0.35)
	VfxKit.torus(r, Color(_c(P, "c"), 0.9), 0.55 * s, t * 1.2, off + Vector3(0, h + 0.35, 0), true, Vector3.ZERO, 0.6)
	var up := VfxKit.particles(r, {"amount": _n(P, 20), "life": t * 1.1, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.22 * s, "speed": 2.6, "tex": "star", "shape": "ring",
		"radius": 0.7 * s, "dir": Vector3.UP, "spread": 8.0, "orbit": 5.0, "curve": "twinkle", "explosive": 0.6})
	up.global_position = g + Vector3(0, 0.15, 0)
	VfxKit.flash(r, "star", _c(P, "core"), 1.8 * s, t * 0.5, true, off + Vector3(0, h + 0.35, 0), 0.25, t * 0.3)
	if _rich(P):
		VfxKit.pillar(r, Color(_c(P, "b"), 0.35), g, 0.75 * s, h + 0.6, t * 1.1)


static func _a_buff_up(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	VfxKit.decal(r, "ring", Color(_c(P, "a"), 0.9), g, 2.4 * s, t * 0.9, true)
	VfxKit.torus(r, Color(_c(P, "a"), 0.75), 0.8 * s, t, off + Vector3(0, 0.2, 0), true)
	var up := VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.1, "color": _c(P, "c"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.2 * s, "speed": 3.0, "tex": "star", "shape": "ring",
		"radius": 0.55 * s, "dir": Vector3.UP, "spread": 6.0, "orbit": 6.0, "curve": "twinkle", "explosive": 0.5})
	up.global_position = g + Vector3(0, 0.1, 0)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.8, "color": _c(P, "b"), "size": 0.4 * s, "speed": 4.0,
			"tex": "streak", "align": true, "dir": Vector3.UP, "spread": 15.0, "offset": off + Vector3(0, 0.3, 0),
			"radius": 0.5 * s})


# ---------- Тьма, кровь, секта ----------

static func _a_shadow_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.sphere(r, _c(P, "core"), 1.1 * s, t * 0.8, Vector3.ZERO, false, 0.4)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.95), 2.4 * s, t * 0.7)
	var tw := sw.create_tween()
	tw.tween_property(sw, "rotation:z", -TAU, t * 0.7)
	VfxKit.flash(r, "star", Color(_c(P, "b"), 0.8), 1.4 * s, t * 0.4)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 1.2, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 0.9 * s, "speed": 2.2 * s, "tex": "smoke", "add": false,
		"damping": 2.0, "gravity": Vector3(0, 0.8, 0), "curve": "grow"})
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 0.9, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.16 * s, "speed": 5.0 * s, "tex": "star", "damping": 2.0, "curve": "twinkle", "hue": 0.06})


static func _a_cursed_sigil(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "sigil", Color(_c(P, "a"), 0.95), g, 3.4 * s, t * 1.4, true, 0.85, 0.3, -0.25, 0.0, 0.25)
	VfxKit.decal(r, "soft", Color(_c(P, "smoke"), 0.7), g, 4.0 * s, t * 1.4, false, 0.9, 0.3)
	var wisp := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.3, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.35 * s, "speed": 2.2, "tex": "soft", "shape": "ring",
		"radius": 1.2 * s, "dir": Vector3.UP, "spread": 10.0, "orbit": 2.0, "curve": "twinkle", "explosive": 0.3})
	wisp.global_position = g + Vector3(0, 0.1, 0)
	if _rich(P):
		var sp := VfxKit.particles(r, {"amount": _n(P, 10), "life": t, "color": _c(P, "c"), "size": 0.14 * s,
			"speed": 3.0, "tex": "star", "shape": "ring", "radius": 1.5 * s, "dir": Vector3.UP, "spread": 20.0,
			"curve": "twinkle"})
		sp.global_position = g + Vector3(0, 0.1, 0)


static func _a_emerald_curse(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	VfxKit.decal(r, "sigil", Color(_c(P, "a"), 1.0), g, 2.6 * s, t * 1.3, true, 0.5, 0.25, 0.4)
	VfxKit.torus(r, Color(_c(P, "a"), 0.8), 0.9 * s, t, off + Vector3(0, h * 0.55, 0), true, Vector3(0.3, 0, 0), 0.7)
	VfxKit.torus(r, Color(_c(P, "c"), 0.6), 0.75 * s, t, off + Vector3(0, h * 0.85, 0), true, Vector3(-0.3, 0, 0.2), 0.6)
	VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.85), 1.8 * s, t * 0.6, true, off + Vector3(0, h * 0.6, 0))
	var wisp := VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.2, "color": _c(P, "a"),
		"color2": Color(_c(P, "c"), 0.0), "size": 0.28 * s, "speed": 1.4, "tex": "soft", "shape": "ring",
		"radius": 0.6 * s, "dir": Vector3.UP, "spread": 10.0, "orbit": 4.0, "curve": "twinkle", "explosive": 0.3})
	wisp.global_position = g + Vector3(0, 0.1, 0)


static func _a_soul_drain(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var a := r.global_position
	var b: Vector3 = P["from"]
	var to := b - a
	var life := t * 0.9
	VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.9), 1.6 * s, t * 0.6)
	# Души летят от цели к герою: скорость — расстояние за время жизни, без разлёта
	VfxKit.particles(r, {"amount": _n(P, 16), "life": life, "color": _c(P, "a"), "color2": Color(_c(P, "c"), 0.2),
		"size": 0.3 * s, "speed": to.length() / maxf(life, 0.1), "tex": "soft", "dir": to.normalized(),
		"spread": 6.0, "explosive": 0.1, "radius": 0.3, "curve": "twinkle"})
	VfxKit.beam(r, Color(_c(P, "b"), 0.45), a, b, 0.08 * s, t * 0.8)
	if _rich(P):
		VfxKit.flash(r, "star", Color(_c(P, "c"), 0.8), 1.2 * s, t * 0.5, true, to, 0.25, life * 0.8)


static func _a_toxic_pool(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "soft", Color(_c(P, "b"), 0.85), g, 3.4 * s, t, false, 0.4, 0.15, 0.0, 0.0, 0.05)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.7), g, 3.0 * s, t, true, 0.4, 0.2)
	var bub := VfxKit.particles(r, {"amount": _n(P, 14), "life": 0.9, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.22 * s, "speed": 0.9, "tex": "ring", "shape": "box",
		"box": Vector3(1.1, 0.05, 1.1) * s, "dir": Vector3.UP, "spread": 10.0, "curve": "pop", "explosive": 0.0})
	bub.global_position = g + Vector3(0, 0.1, 0)
	bub.one_shot = false
	var tw := bub.create_tween()
	tw.tween_interval(maxf(t - 0.9, 0.1))
	tw.tween_callback(func() -> void: bub.emitting = false)
	if _rich(P):
		var fume := VfxKit.particles(r, {"amount": _n(P, 8), "life": 1.6, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 0.6, "tex": "smoke", "add": false,
			"shape": "box", "box": Vector3(1.0, 0.05, 1.0) * s, "dir": Vector3.UP, "spread": 15.0, "curve": "grow",
			"explosive": 0.0})
		fume.global_position = g + Vector3(0, 0.2, 0)
		fume.one_shot = false
		var tw2 := fume.create_tween()
		tw2.tween_interval(maxf(t - 1.6, 0.1))
		tw2.tween_callback(func() -> void: fume.emitting = false)


static func _a_blood_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", Color(_c(P, "c"), 0.95), 1.5 * s, t * 0.4)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.85), 1.9 * s, t * 0.6)
	var tw := sw.create_tween()
	tw.tween_property(sw, "rotation:z", TAU * 0.8, t * 0.6)
	VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 0.9, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.26 * s, "speed": 4.5 * s, "tex": "drop", "gravity": Vector3(0, -10.0, 0), "align": true})
	if _rich(P):
		VfxKit.decal(r, "smoke", Color(_c(P, "b"), 0.7), _local_ground(P), 1.6 * s, t * 1.6, false, 0.5, 0.2)


static func _a_ritual_circle(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.95), g, 4.6 * s, t * 1.3, true, 0.9, 0.25, 0.3, 0.0, 0.2)
	VfxKit.decal(r, "sigil", Color(_c(P, "c"), 0.8), g, 3.0 * s, t * 1.3, true, 0.9, 0.25, -0.5, 0.0, 0.2)
	if _rich(P):
		for i in 4:
			var ang := TAU * float(i) / 4.0 + rng.randf_range(-0.2, 0.2)
			var pg := g + Vector3(cos(ang), 0, sin(ang)) * 2.0 * s
			VfxKit.pillar(r, Color(_c(P, "a"), 0.6), pg, 0.18 * s, 2.6 * s, t)
	var wisp := VfxKit.particles(r, {"amount": _n(P, 20), "life": t * 1.1, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.3 * s, "speed": 2.0, "tex": "soft", "shape": "ring",
		"radius": 2.0 * s, "dir": Vector3.UP, "spread": 8.0, "orbit": 3.0, "curve": "twinkle", "explosive": 0.2})
	wisp.global_position = g + Vector3(0, 0.1, 0)


static func _a_ghost(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	# Призрачная фигура: дымное тело поднимается и тает, два светящихся глаза, след из огоньков
	var g := VfxKit.flash(r, "smoke", Color(_c(P, "a"), 0.7), 1.8 * s, t, true, Vector3(0, 0.3, 0), 0.6)
	var tw := g.create_tween()
	tw.tween_property(g, "position:y", 1.6 * s, t).set_trans(Tween.TRANS_SINE)
	for i in 2:
		var e := VfxKit.flash(r, "star", Color(_c(P, "core"), 1.0), 0.35 * s, t * 0.8, true,
			Vector3((float(i) - 0.5) * 0.35 * s, 0.75 * s, 0.25), 0.8)
		var te := e.create_tween()
		te.tween_property(e, "position:y", 2.0 * s, t).set_trans(Tween.TRANS_SINE)
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.25 * s, "speed": 1.2, "tex": "soft", "dir": Vector3.UP, "spread": 30.0, "curve": "twinkle",
		"explosive": 0.3})
	VfxKit.decal(r, "soft", Color(_c(P, "b"), 0.6), _local_ground(P), 2.0 * s, t, true, 0.6, 0.3)


# ---------- Ветер ----------

static func _a_wind_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	VfxKit.arc(r, Color(_c(P, "a"), 0.95), d, 1.3 * s, t * 0.9, 0.5, Vector3.ZERO, 1.6)
	VfxKit.arc(r, Color(_c(P, "c"), 0.8), d, 1.0 * s, t * 0.8, -0.6, Vector3(0, 0.2, 0), 1.4)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.7, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.4 * s, "speed": 5.0 * s, "tex": "streak", "align": true, "orbit": 8.0})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 1.1, "color": _c(P, "b"), "size": 0.18 * s,
			"speed": 3.0 * s, "mesh": "shard", "gravity": Vector3(0, -2.0, 0), "spin": 400.0})


static func _a_tornado(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "swirl", Color(_c(P, "a"), 0.85), g, 3.6 * s, t * 1.2, true, 0.5, 0.3, 1.5)
	var pivot := Node3D.new()
	r.add_child(pivot)
	pivot.global_position = g
	VfxKit.particles(pivot, {"amount": _n(P, 26), "life": t * 0.9, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.45 * s, "speed": 3.0 * s, "tex": "streak", "shape": "ring",
		"radius": 0.9 * s, "dir": Vector3.UP, "spread": 5.0, "orbit": 14.0, "radial": 1.5, "local": true,
		"explosive": 0.4, "align": true})
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation:y", TAU * 2.0, t)
	if _rich(P):
		VfxKit.particles(pivot, {"amount": _n(P, 10), "life": t * 1.1, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 2.0, "tex": "smoke", "add": false,
			"shape": "ring", "radius": 1.0 * s, "dir": Vector3.UP, "spread": 20.0, "orbit": 6.0, "curve": "grow",
			"local": true, "explosive": 0.3})


# ---------- Оружие ----------

static func _a_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	var rng: RandomNumberGenerator = P["rng"]
	var tilt := rng.randf_range(-0.6, 0.6)
	VfxKit.arc(r, Color(_c(P, "a"), 0.95), d, 1.35 * s, t, tilt, Vector3.ZERO, 1.5, 1.2)
	VfxKit.arc(r, Color(_c(P, "core"), 0.9), d, 1.15 * s, t * 0.8, tilt, Vector3.ZERO, 1.4, 0.6)
	VfxKit.flash(r, "star", _c(P, "core"), 1.3 * s, t * 0.4)
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 0.5, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.25 * s, "speed": 6.0 * s, "tex": "streak", "align": true, "gravity": Vector3(0, -5.0, 0)})
	if _rich(P):
		VfxKit.flash(r, "soft", Color(_c(P, "b"), 0.6), 1.8 * s, t * 0.5)


static func _a_cleave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	VfxKit.arc(r, Color(_c(P, "a"), 1.0), d, 1.7 * s, t, 1.25, Vector3(0, 0.3, 0), 1.7, 1.5)
	VfxKit.arc(r, Color(_c(P, "core"), 0.9), d, 1.45 * s, t * 0.8, 1.25, Vector3(0, 0.3, 0), 1.6, 0.7)
	VfxKit.flash(r, "star", _c(P, "core"), 1.9 * s, t * 0.45)
	VfxKit.decal(r, "crack", Color(0.18, 0.1, 0.05, 0.8), _local_ground(P), 2.4 * s, t * 1.8, false, 0.7, 0.12)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.3 * s, "speed": 7.0 * s, "tex": "streak", "align": true, "gravity": Vector3(0, -6.0, 0)})
	if _rich(P):
		var dust := VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 1.2, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.8 * s, "speed": 2.0 * s, "tex": "smoke", "add": false,
			"dir": Vector3.UP, "spread": 80.0, "damping": 2.5, "curve": "grow"})
		dust.global_position = _local_ground(P) + Vector3(0, 0.2, 0)


static func _a_stab(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	VfxKit.flash(r, "star", _c(P, "core"), 1.4 * s, t * 0.35)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.45, "color": _c(P, "core"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.55 * s, "speed": 9.0 * s, "tex": "streak", "align": true, "dir": d, "spread": 10.0,
		"offset": -d * 0.8})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.6, "color": _c(P, "c"), "size": 0.14 * s, "speed": 4.0 * s,
		"tex": "star", "dir": d, "spread": 60.0, "curve": "twinkle"})
	if _rich(P):
		VfxKit.torus(r, Color(_c(P, "a"), 0.7), 0.6 * s, t * 0.5, Vector3.ZERO, true,
			Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.6)


static func _a_blunt_hit(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	VfxKit.flash(r, "star", _c(P, "core"), 2.0 * s, t * 0.45)
	VfxKit.torus(r, Color(_c(P, "a"), 0.85), 1.1 * s, t * 0.55, Vector3.ZERO, true,
		Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.7)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.22 * s, "speed": 6.0 * s, "tex": "star", "gravity": Vector3(0, -7.0, 0), "curve": "twinkle"})
	if _rich(P):
		VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.7), _local_ground(P), 2.2 * s, t * 0.6, true)
		VfxKit.flash(r, "ring", Color(_c(P, "b"), 0.8), 2.4 * s, t * 0.5, true, Vector3.ZERO, 0.3, t * 0.08)


static func _a_spin_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position + Vector3(0, 0.9, 0)
	VfxKit.arc(r, Color(_c(P, "a"), 0.95), Vector3.FORWARD, 2.0 * s, t, 0.0, off, TAU * 0.95, 1.1)
	VfxKit.arc(r, Color(_c(P, "core"), 0.85), Vector3.BACK, 1.75 * s, t * 0.9, 0.15, off + Vector3(0, 0.25, 0),
		TAU * 0.9, 0.6)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.8), g, 4.6 * s, t * 0.7, true)
	var sp := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 0.6, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.32 * s, "speed": 6.0 * s, "tex": "streak", "align": true,
		"shape": "ring", "radius": 1.0 * s, "dir": Vector3.UP, "spread": 85.0, "orbit": 10.0})
	sp.position = off
	if _rich(P):
		var dust := VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 1.1, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.8 * s, "speed": 3.0 * s, "tex": "smoke", "add": false,
			"shape": "ring", "radius": 1.2 * s, "dir": Vector3.UP, "spread": 85.0, "damping": 3.0, "curve": "grow"})
		dust.global_position = g + Vector3(0, 0.15, 0)


static func _a_arrow_impact(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", Color(_c(P, "core"), 0.95), 1.1 * s, t * 0.35)
	VfxKit.flash(r, "ring", Color(_c(P, "a"), 0.85), 1.3 * s, t * 0.45, true, Vector3.ZERO, 0.2, t * 0.05)
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.5, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.22 * s, "speed": 5.0 * s, "tex": "streak", "align": true, "gravity": Vector3(0, -6.0, 0)})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 5), "life": t * 0.9, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.5 * s, "speed": 1.2 * s, "tex": "smoke", "add": false,
			"curve": "grow"})


# ---------- Звери, дух ----------

static func _a_claw(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	var c := VfxKit.flash(r, "claw", Color(_c(P, "a"), 1.0), 1.9 * s, t * 0.6, true, Vector3.ZERO, 0.6)
	c.rotation.z = rng.randf_range(-0.6, 0.6)
	var c2 := VfxKit.flash(r, "claw", Color(_c(P, "core"), 0.8), 1.5 * s, t * 0.45, true, Vector3.ZERO, 0.6)
	c2.rotation.z = c.rotation.z
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 0.5, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.25 * s, "speed": 5.0 * s, "tex": "streak", "align": true, "gravity": Vector3(0, -6.0, 0)})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 0.8, "color": _c(P, "b"), "size": 0.14 * s,
			"speed": 3.5 * s, "tex": "star", "curve": "twinkle"})


static func _a_roar(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var h := float(P["h"])
	var off := _local_ground(P) - r.global_position + Vector3(0, h * 0.85, 0)
	for i in 3:
		VfxKit.flash(r, "ring", Color(_c(P, "a" if i % 2 == 0 else "b"), 0.85), (2.2 + float(i)) * s, t * 0.6, true,
			off, 0.2, float(i) * t * 0.15)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.8), _local_ground(P), 4.4 * s, t * 0.8, true)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 0.6, "color": _c(P, "c"), "size": 0.4 * s,
			"speed": 6.0 * s, "tex": "streak", "align": true, "offset": off, "spread": 90.0, "dir": Vector3.UP})


static func _a_spirit_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", _c(P, "core"), 1.8 * s, t * 0.5)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "b"), 0.8), 2.0 * s, t * 0.7)
	var tw := sw.create_tween()
	tw.tween_property(sw, "rotation:z", TAU * 0.7, t * 0.7)
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.1, "color": _c(P, "a"), "color2": Color(_c(P, "c"), 0.0),
		"size": 0.3 * s, "speed": 3.0 * s, "tex": "soft", "orbit": 5.0, "damping": 2.0, "curve": "twinkle",
		"hue": 0.08})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.9, "color": _c(P, "c"), "size": 0.16 * s,
			"speed": 4.5 * s, "tex": "star", "curve": "twinkle"})


# ---------- Каст, выпуск, снаряд ----------

## Каст на герое: круг под ногами цвета стихии, силы стекаются к герою, свечение у рук. Длится dur (время каста);
## прервали — VfxArchetypes.stop(узел).
static func _a_cast_gather(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.9), g, 2.6 * s, t + 0.4, true, 0.3, 0.25, 0.5, 0.0, 0.1)
	var gather := VfxKit.loop(r, {"amount": _n(P, 16), "life": 0.7, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.2 * s, "speed": 0.2, "tex": "star", "shape": "ring",
		"radius": 1.3 * s, "radial": -5.0, "orbit": 3.0, "dir": Vector3.UP, "spread": 10.0, "curve": "twinkle",
		"offset": off + Vector3(0, 0.5, 0)})
	gather.set_meta("vfx_stop_at", t)
	var tw := gather.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(VfxKit.stop_loop.bind(gather))
	var glow := VfxKit.flash(r, "soft", Color(_c(P, "a"), 0.75), 1.2 * s, t + 0.3, true,
		off + Vector3(0, h * 0.62, 0) + P["dir"] * 0.35, 0.2)
	var tw2 := glow.create_tween().set_loops(maxi(1, int(t / 0.5)))
	tw2.tween_property(glow, "scale", Vector3.ONE * 1.4 * s, 0.25)
	tw2.tween_property(glow, "scale", Vector3.ONE * 1.0 * s, 0.25)
	if _rich(P):
		var rise := VfxKit.loop(r, {"amount": _n(P, 10), "life": 0.9, "color": _c(P, "b"),
			"color2": Color(_c(P, "a"), 0.0), "size": 0.3 * s, "speed": 1.6, "tex": "soft", "shape": "ring",
			"radius": 0.9 * s, "dir": Vector3.UP, "spread": 5.0, "curve": "twinkle", "offset": off + Vector3(0, 0.1, 0)})
		var tw3 := rise.create_tween()
		tw3.tween_interval(t)
		tw3.tween_callback(VfxKit.stop_loop.bind(rise))


## Выпуск силы на герое (мгновенное умение, конец каста): вспышка у рук и короткий выброс искр вперёд.
static func _a_release(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	var d: Vector3 = P["dir"]
	var hand := off + Vector3(0, h * 0.62, 0) + d * 0.45
	VfxKit.flash(r, "star", _c(P, "core"), 1.3 * s, t * 0.45, true, hand)
	VfxKit.flash(r, "soft", Color(_c(P, "a"), 0.8), 1.6 * s, t * 0.55, true, hand)
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.2 * s, "speed": 4.0 * s, "tex": "star", "dir": d, "spread": 35.0, "offset": hand, "curve": "twinkle"})
	if _rich(P):
		VfxKit.decal(r, "ring", Color(_c(P, "a"), 0.8), g, 2.0 * s, t * 0.6, true)


## Остановить эффект каста (прервали каст): постоянные частицы гаснут, картинки тают.
static func stop(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	for n in root.find_children("*", "CPUParticles3D", true, false):
		VfxKit.stop_loop(n)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE * 0.01, 0.2)
	t.tween_callback(root.queue_free)


## Одеть снаряд node (Projectile, размер size) в вид стихии el: ядро, ореол и след своего вида. q — качество.
static func dress_projectile(node: Node3D, el: String, size: float, q: int, tint: Color = Color(0, 0, 0, 0)) -> void:
	var pal := palette(el, tint)
	var core: Color = pal["core"]
	var a: Color = pal["a"]
	var b: Color = pal["b"]
	var c: Color = pal["c"]
	var qm := float(QMUL[clampi(q, 0, 2)])
	var n := func(x: float) -> int: return maxi(1, int(roundf(x * qm)))
	var star := VfxKit._mi(node, Vfx._quad(), Vfx.fx_mat(Color(a, 0.9), VfxKit.tex("soft"), true,
		BaseMaterial3D.BILLBOARD_ENABLED))
	star.scale = Vector3.ONE * 1.0 * size
	match el:
		"fire":
			VfxKit.flash(node, "flame", Color(a, 0.95), 0.9 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(16), "life": 0.45, "color": a, "color2": Color(b, 0.0), "size": 0.45 * size,
				"speed": 0.6, "tex": "flame", "gravity": Vector3(0, 2.5, 0), "curve": "grow", "radius": 0.08})
			VfxKit.loop(node, {"amount": n.call(8), "life": 0.6, "color": c, "size": 0.1 * size, "speed": 0.8,
				"tex": "star", "gravity": Vector3(0, -2.0, 0), "curve": "twinkle"})
		"ice":
			var sh := VfxKit._mi(node, VfxKit.shard_mesh(), Vfx.fx_mat(Color(c, 0.95), null, false))
			sh.scale = Vector3(0.45, 0.8, 0.45) * size
			sh.rotation.x = PI / 2.0
			var tw := sh.create_tween().set_loops()
			tw.tween_property(sh, "rotation:y", TAU, 0.4).from(0.0)
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.5, "color": core, "size": 0.14 * size, "speed": 0.4,
				"tex": "snow", "spin": 200.0, "curve": "twinkle"})
		"earth":
			var rk := VfxKit._mi(node, VfxKit.rock_mesh(), Util.mat(a))
			rk.scale = Vector3.ONE * 0.5 * size
			var tw2 := rk.create_tween().set_loops()
			tw2.tween_property(rk, "rotation", Vector3(TAU, TAU * 0.5, 0), 0.6).from(Vector3.ZERO)
			VfxKit.loop(node, {"amount": n.call(10), "life": 0.6, "color": pal["smoke"], "size": 0.4 * size,
				"speed": 0.3, "tex": "smoke", "add": false, "curve": "grow"})
		"dark", "emerald":
			var dc := VfxKit._mi(node, Vfx._unit_sphere(), Vfx.fx_mat(pal["core"] if el == "dark" else Color(0.02, 0.1, 0.07, 0.9), null, false))
			dc.scale = Vector3.ONE * 0.16 * size
			var sw := VfxKit.flash(node, "swirl", Color(a, 0.95), 1.0 * size, 9.0, true, Vector3.ZERO, 1.0)
			var tw3 := sw.create_tween().set_loops()
			tw3.tween_property(sw, "rotation:z", -TAU, 0.5).from(0.0)
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.55, "color": a, "color2": Color(c, 0.0), "size": 0.3 * size,
				"speed": 0.4, "tex": "soft", "curve": "shrink"})
		"storm":
			VfxKit.flash(node, "star", Color(core, 1.0), 0.9 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(14), "life": 0.25, "color": c, "color2": Color(a, 0.0), "size": 0.3 * size,
				"speed": 3.0, "tex": "streak", "align": true, "radius": 0.1})
		"water", "poison", "blood":
			var bl := VfxKit._mi(node, Vfx._unit_sphere(), Vfx.fx_mat(Color(a, 0.75), null, false))
			bl.scale = Vector3.ONE * 0.2 * size
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.5, "color": c, "color2": Color(b, 0.0), "size": 0.18 * size,
				"speed": 0.8, "tex": "drop", "gravity": Vector3(0, -5.0, 0), "align": true})
		"wind":
			var arcp := Node3D.new()
			node.add_child(arcp)
			var m := Vfx.fx_mat(Color(a, 0.9), null, true)
			m.vertex_color_use_as_albedo = true
			var am := VfxKit._mi(arcp, Vfx._arc_mesh(), m)
			am.scale = Vector3.ONE * 0.6 * size
			var tw4 := arcp.create_tween().set_loops()
			tw4.tween_property(arcp, "rotation:y", TAU, 0.3).from(0.0)
			VfxKit.loop(node, {"amount": n.call(10), "life": 0.4, "color": c, "size": 0.3 * size, "speed": 0.5,
				"tex": "streak", "align": true})
		_:
			VfxKit.flash(node, "star", Color(core, 0.95), 0.85 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.45, "color": a, "color2": Color(b, 0.0), "size": 0.22 * size,
				"speed": 0.3, "tex": "star", "curve": "twinkle"})
