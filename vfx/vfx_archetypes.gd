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
		"root": root, "pos": pos, "pal": palette(String(pr.get("el", "steel")), tint), "el": String(pr.get("el", "steel")),
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



## Смещение земли под эффектом от корня (для слоёв, которым нужна локальная позиция).
static func _goff(P: Dictionary) -> Vector3:
	return (P["ground"] as Vector3) - (P["root"] as Node3D).global_position


# ---------- Общие слои VFX 2.0 ----------

## Магический круг (MagicArea, VfxKit.magic_circle) на земле под эффектом или в точке at: радиус в метрах,
## kind "circle" / "ripple". false — сторонние блоки выключены (тогда архетип рисует свой знак).
static func _circle(P: Dictionary, radius: float, time: float, kind: String = "circle", delay: float = 0.0,
		appear: float = 0.35, at: Variant = null) -> bool:
	var g: Vector3 = P["ground"] if at == null else at
	var life := minf(time, float(P["dur"]) + 1.5 - delay)
	return VfxKit.magic_circle(P["root"], P["pal"], String(P["el"]), g, radius, life, kind, int(P["q"]), delay,
		minf(appear, life * 0.4)) != null


## Треск разряда — картинка Kenney (spark_01…04) к камере.
static func _crackle(P: Dictionary, size: float, t: float, offset: Vector3, c: Color) -> void:
	var rng: RandomNumberGenerator = P["rng"]
	var fl := VfxKit.flash(P["root"], "k:spark_0%d" % (1 + rng.randi() % 4), c, size, t, true, offset, 0.5)
	VfxKit.spin(fl, rng.randf_range(-0.3, 0.3), t, rng.randf() * TAU)


## Земля и щебень брызгами (Kenney dirt, обычная прозрачность).
static func _dirt(P: Dictionary, n: float, size: float, speed: float, t: float, at: Vector3, col: Color) -> void:
	var rng: RandomNumberGenerator = P["rng"]
	var d := VfxKit.particles(P["root"], {"amount": _n(P, n), "life": t, "color": col, "color2": Color(col, 0.0),
		"size": size, "speed": speed, "tex": "k:dirt_0%d" % (1 + rng.randi() % 3), "add": false, "dir": Vector3.UP,
		"spread": 60.0, "gravity": Vector3(0, -9.0, 0), "spin": 120.0, "radius": 0.3})
	d.global_position = at

## Ядро удара: раскалённая искра-вспышка, ореол, кольцо-толчок к камере.
static func _hot_core(P: Dictionary, size: float, t: float, offset: Vector3 = Vector3.ZERO) -> void:
	var r: Node3D = P["root"]
	VfxKit.flash(r, "star", _c(P, "core"), 2.2 * size, t * 0.4, true, offset, 0.15)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.8), 3.2 * size, t * 0.55, true, offset, 0.3)
	if _rich(P):
		VfxKit.flash(r, "ring", Color(_c(P, "c"), 0.9), 2.6 * size, t * 0.45, true, offset, 0.1, 0.0, "spark")


## Искры-росчерки во все стороны (длинные, вдоль скорости), с гравитацией.
static func _streaks(P: Dictionary, n: float, size: float, speed: float, t: float, offset: Vector3 = Vector3.ZERO,
		dir: Vector3 = Vector3.UP, spread: float = 180.0, grav: float = -6.0) -> CPUParticles3D:
	return VfxKit.particles(P["root"], {"amount": _n(P, n), "life": t, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": size, "speed": speed, "tex": "streak", "align": true,
		"gravity": Vector3(0, grav, 0), "damping": 1.5, "offset": offset, "dir": dir, "spread": spread})


## Тлеющие угольки / искорки, медленно поднимаются и мерцают.
static func _embers(P: Dictionary, n: float, size: float, t: float, at: Vector3, radius: float) -> void:
	var e := VfxKit.particles(P["root"], {"amount": _n(P, n), "life": t, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": size, "speed": 1.2, "tex": "star", "gravity": Vector3(0, 0.9, 0),
		"damping": 0.8, "radius": radius, "curve": "twinkle", "explosive": 0.6, "orbit": 1.5})
	e.global_position = at


## Дым или пыль кольцом у земли (обычная прозрачность).
static func _dust(P: Dictionary, n: float, size: float, speed: float, t: float, radius: float,
		delay: float = 0.0) -> void:
	var d := VfxKit.particles(P["root"], {"amount": _n(P, n), "life": t, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": size, "speed": speed, "tex": "smoke", "add": false,
		"shape": "ring", "radius": radius, "dir": Vector3.UP, "spread": 80.0, "damping": 2.8, "curve": "grow",
		"delay": delay})
	d.global_position = (P["ground"] as Vector3) + Vector3(0, 0.25, 0)


## Обломки (камни с освещением) вверх и в стороны.
static func _debris(P: Dictionary, n: float, size: float, speed: float, t: float, at: Vector3,
		col: Color) -> void:
	var d := VfxKit.particles(P["root"], {"amount": _n(P, n), "life": t, "color": col, "color2": col.darkened(0.3),
		"size": size, "speed": speed, "mesh": "rock", "lit": true, "dir": Vector3.UP, "spread": 55.0,
		"gravity": Vector3(0, -16.0, 0), "spin": 420.0, "radius": 0.3})
	d.global_position = at


# ---------- Огонь ----------

static func _a_explosion(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	_hot_core(P, 1.5 * s, t)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.95), 1.5 * s, t * 0.75, Vector3.ZERO, true, 0.15, 0.0, "fireball")
	VfxKit.sphere(r, Color(_c(P, "b"), 0.6), 2.3 * s, t * 0.85, Vector3.ZERO, true, 0.3, 0.0, "shell")
	VfxKit.particles(r, {"amount": _n(P, 30), "life": t * 0.95, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 1.1 * s, "speed": 5.0 * s, "tex": "flame", "damping": 4.5, "gravity": Vector3(0, 3.5, 0),
		"radius": 0.35 * s, "curve": "grow", "hue": 0.05})
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t * 1.1, "color": _c(P, "core"), "color2": Color(_c(P, "a"), 0.0),
		"size": 1.3 * s, "speed": 3.0 * s, "tex": "flame", "dir": Vector3.UP, "spread": 22.0, "damping": 2.0,
		"gravity": Vector3(0, 5.0, 0), "curve": "grow"})
	_streaks(P, 24, 0.35 * s, 9.0 * s, t * 0.9)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 5.0 * s, t * 0.7, true)
	VfxKit.wall(r, Color(_c(P, "a"), 0.85), g, 4.2 * s, 1.4 * s, t * 0.7)
	if _rich(P):
		VfxKit.decal(r, "crack", Color(_c(P, "b"), 0.95), g, 3.4 * s, t * 2.6, true, 0.7, 0.12, 0.0, 0.0, 0.0, "lava")
		VfxKit.decal(r, "smoke", Color(0.08, 0.04, 0.03, 0.75), g, 3.2 * s, t * 3.0, false, 0.8, 0.1)
		VfxKit.decal(r, "k:scorch_0%d" % (1 + (P["rng"] as RandomNumberGenerator).randi() % 3),
			Color(0.05, 0.03, 0.02, 0.85), g, 3.6 * s, t * 3.0, false, 0.6, 0.12, 0.0, 0.0, 0.0, "plain")
		_circle(P, 2.6 * s, t * 1.4, "ripple", 0.0, 0.12)
		VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 2.0, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.6 * s, "speed": 1.8 * s, "tex": "smoke", "add": false,
			"gravity": Vector3(0, 1.6, 0), "damping": 1.5, "radius": 0.7 * s, "curve": "grow", "delay": t * 0.15})
		_debris(P, 10, 0.22 * s, 7.0 * s, t * 1.2, g + Vector3(0, 0.3, 0), Color(0.25, 0.18, 0.14))
		_embers(P, 16, 0.12 * s, t * 2.2, r.global_position, 1.0 * s)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 5.0, 8.0 * s, t * 0.7)
	VfxKit.shake(r, 0.55 * minf(s, 1.5))


static func _a_flame_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	_hot_core(P, 0.9 * s, t)
	VfxKit.flash(r, "flame", Color(_c(P, "a"), 1.0), 2.4 * s, t * 0.7, true, Vector3(0, 0.45 * s, 0), 0.3)
	VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 0.85, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.75 * s, "speed": 3.2 * s, "tex": "flame", "dir": Vector3.UP, "spread": 70.0, "damping": 2.0,
		"gravity": Vector3(0, 5.0, 0), "curve": "grow", "hue": 0.05})
	_streaks(P, 14, 0.25 * s, 6.5 * s, t * 0.8)
	if _rich(P):
		VfxKit.sphere(r, Color(_c(P, "a"), 0.8), 0.9 * s, t * 0.5, Vector3.ZERO, true, 0.2, 0.0, "fireball")
		VfxKit.particles(r, {"amount": _n(P, 7), "life": t * 1.7, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.9 * s, "speed": 1.0, "tex": "smoke", "add": false,
			"gravity": Vector3(0, 1.8, 0), "curve": "grow", "delay": t * 0.2})
		_embers(P, 10, 0.1 * s, t * 1.8, r.global_position, 0.5 * s)
	VfxKit.shake(r, 0.12)


# ---------- Лёд и вода ----------

static func _a_frost_nova(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.flash(r, "snow", _c(P, "core"), 2.8 * s, t * 0.5, true, Vector3.ZERO, 0.2)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.8), 4.0 * s, t * 0.6)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 5.6 * s, t * 0.8, true)
	if not _circle(P, 2.0 * s, t * 1.7, "circle", 0.0, 0.2):
		VfxKit.decal(r, "rune", Color(_c(P, "c"), 0.85), g, 3.8 * s, t * 1.6, true, 0.8, 0.2, 0.2)
	if _rich(P):
		_circle(P, 2.9 * s, t * 1.2, "ripple", 0.05, 0.2)
	VfxKit.wall(r, Color(_c(P, "a"), 0.8), g, 4.6 * s, 1.6 * s, t * 0.8)
	VfxKit.spikes(r, _c(P, "a"), g, maxi(4, _n(P, 12)), 2.4 * s, 1.5 * s, t * 1.6, rng, false, true)
	var ring := VfxKit.particles(r, {"amount": _n(P, 24), "life": t * 0.95, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.55 * s, "speed": 6.0 * s, "mesh": "crystal", "shape": "ring",
		"radius": 0.4 * s, "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -11.0, 0), "align": true})
	ring.global_position = g + Vector3(0, 0.2, 0)
	if _rich(P):
		_dust(P, 12, 1.6 * s, 2.8 * s, t * 1.9, 0.6 * s)
		var flakes := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 2.0, "color": _c(P, "core"),
			"size": 0.18 * s, "speed": 1.5 * s, "tex": "snow", "spin": 180.0, "gravity": Vector3(0, -0.5, 0),
			"radius": 2.0 * s, "curve": "twinkle", "explosive": 0.5})
		flakes.global_position = g + Vector3(0, 1.0, 0)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 3.0, 7.0 * s, t * 0.6)
	VfxKit.shake(r, 0.3)


static func _a_ice_shards(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.flash(r, "snow", _c(P, "core"), 1.9 * s, t * 0.5, true, Vector3.ZERO, 0.2)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.85), 2.4 * s, t * 0.5)
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 0.85, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.2),
		"size": 0.5 * s, "speed": 6.0 * s, "mesh": "crystal", "gravity": Vector3(0, -9.0, 0), "align": true})
	VfxKit.particles(r, {"amount": _n(P, 12), "life": t, "color": _c(P, "core"), "size": 0.2 * s, "speed": 2.8 * s,
		"tex": "snow", "spin": 220.0, "curve": "twinkle"})
	_streaks(P, 10, 0.22 * s, 6.0 * s, t * 0.6)
	if _rich(P):
		VfxKit.spikes(r, _c(P, "a"), _local_ground(P), maxi(3, _n(P, 6)), 0.7 * s, 1.1 * s, t * 1.4, rng, false, true)
		VfxKit.particles(r, {"amount": _n(P, 5), "life": t * 1.4, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.9 * s, "speed": 0.8, "tex": "smoke", "add": false,
			"curve": "grow"})
	VfxKit.shake(r, 0.1)


static func _a_water_splash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "glow", Color(_c(P, "c"), 0.9), 2.2 * s, t * 0.45)
	VfxKit.flash(r, "star", _c(P, "core"), 1.4 * s, t * 0.35)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.7), 1.1 * s, t * 0.6, Vector3.ZERO, true, 0.3, 0.0, "shell")
	VfxKit.torus(r, Color(_c(P, "a"), 0.8), 1.4 * s, t * 0.7, Vector3.ZERO, true, Vector3(PI / 2.0, 0, 0))
	VfxKit.particles(r, {"amount": _n(P, 26), "life": t * 0.95, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.3 * s, "speed": 5.5 * s, "tex": "drop", "dir": Vector3.UP, "spread": 70.0,
		"gravity": Vector3(0, -13.0, 0), "align": true})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.8, "color": _c(P, "core"), "size": 0.6 * s,
		"speed": 2.4 * s, "tex": "soft", "damping": 3.0, "curve": "grow"})
	if _rich(P):
		VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.85), _local_ground(P), 2.8 * s, t * 0.8, true)
		_dust(P, 6, 0.9 * s, 1.5 * s, t * 1.2, 0.4 * s)
	VfxKit.shake(r, 0.08)


static func _a_water_wave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 6.0 * s, t * 0.9, true)
	VfxKit.decal(r, "wave", Color(_c(P, "c"), 0.85), g, 4.0 * s, t * 0.9, true, 0.1, 1.0, 0.0, t * 0.18)
	VfxKit.wall(r, Color(_c(P, "a"), 0.85), g, 5.2 * s, 1.8 * s, t * 0.9, true, 0.15, "water")
	VfxKit.wall(r, Color(_c(P, "c"), 0.6), g, 3.6 * s, 1.0 * s, t * 0.8, true, 0.1, "water")
	var drops := VfxKit.particles(r, {"amount": _n(P, 32), "life": t, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.32 * s, "speed": 6.0 * s, "tex": "drop", "shape": "ring",
		"radius": 1.2 * s, "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, -13.0, 0), "align": true})
	drops.global_position = g + Vector3(0, 0.2, 0)
	if _rich(P):
		_dust(P, 14, 1.0 * s, 3.2 * s, t * 1.3, 0.8 * s)
	VfxKit.shake(r, 0.2)


# ---------- Земля ----------

static func _a_rock_impact(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	_hot_core(P, 0.9 * s, t)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 1.1, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.9),
		"size": 0.32 * s, "speed": 5.5 * s, "mesh": "rock", "lit": true, "gravity": Vector3(0, -15.0, 0),
		"spin": 380.0})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 1.4, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 2.2 * s, "tex": "smoke", "add": false,
		"damping": 3.0, "gravity": Vector3(0, 0.6, 0), "curve": "grow"})
	_streaks(P, 10, 0.22 * s, 6.0 * s, t * 0.6)
	if _rich(P):
		VfxKit.decal(r, "crack", Color(_c(P, "c"), 0.85), g, 2.6 * s, t * 2.2, true, 0.7, 0.12, 0.0, 0.0, 0.0, "lava")
		VfxKit.wall(r, Color(_c(P, "smoke"), 0.7), g, 2.0 * s, 0.7 * s, t * 0.6, false, 0.2, "smoke")
		_dirt(P, 8, 0.9 * s, 4.5 * s, t * 1.1, g + Vector3(0, 0.3, 0), Color(_c(P, "b"), 0.95))
	VfxKit.shake(r, 0.3)


static func _a_ground_spike(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.decal(r, "crack", Color(_c(P, "c"), 0.95), g, 4.0 * s, t * 2.2, true, 0.5, 0.12, 0.0, 0.0, 0.0, "lava")
	VfxKit.spikes(r, _c(P, "a"), g, maxi(3, _n(P, 10)), 1.4 * s, 1.9 * s, t * 1.6, rng)
	VfxKit.flash(r, "glow", Color(_c(P, "c"), 0.8), 3.0 * s, t * 0.4, true, g - r.global_position + Vector3(0, 0.3, 0))
	VfxKit.wall(r, Color(_c(P, "smoke"), 0.8), g, 3.2 * s, 1.0 * s, t * 0.8, false, 0.2, "smoke")
	_dust(P, 14, 1.1 * s, 2.6 * s, t * 1.5, 0.9 * s)
	if _rich(P):
		VfxKit.spikes(r, _c(P, "b"), g, maxi(3, _n(P, 7)), 2.4 * s, 1.1 * s, t * 1.3, rng)
		_debris(P, 12, 0.24 * s, 6.0 * s, t, g + Vector3(0, 0.2, 0), _c(P, "b"))
		_dirt(P, 10, 1.1 * s, 5.0 * s, t * 1.2, g + Vector3(0, 0.3, 0), Color(_c(P, "b"), 0.95))
		_streaks(P, 10, 0.3 * s, 6.0 * s, t * 0.6, g - r.global_position + Vector3(0, 0.3, 0), Vector3.UP, 60.0)
	VfxKit.shake(r, 0.45)


static func _a_shockwave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	VfxKit.flash(r, "glow", Color(_c(P, "c"), 0.85), 3.4 * s, t * 0.4, true, off + Vector3(0, 0.4, 0))
	VfxKit.decal(r, "wave", Color(_c(P, "c"), 0.95), g, 5.8 * s, t * 0.75, true)
	VfxKit.wall(r, Color(_c(P, "a"), 0.9), g, 5.0 * s, 1.5 * s, t * 0.75)
	VfxKit.wall(r, Color(_c(P, "smoke"), 0.75), g, 4.2 * s, 1.1 * s, t * 0.9, false, 0.15, "smoke")
	VfxKit.torus(r, Color(_c(P, "a"), 0.7), 3.0 * s, t * 0.7, off + Vector3(0, 0.3, 0), true, Vector3.ZERO, 0.8)
	VfxKit.decal(r, "crack", Color(_c(P, "b"), 0.9), g, 3.6 * s, t * 2.2, true, 0.6, 0.12, 0.0, 0.0, 0.0, "lava")
	_dust(P, 20, 1.1 * s, 5.0 * s, t * 1.3, 0.6 * s)
	_circle(P, 3.0 * s, t * 1.2, "ripple", 0.0, 0.12)
	if _rich(P):
		_debris(P, 12, 0.22 * s, 5.0 * s, t, g + Vector3(0, 0.2, 0), _c(P, "a"))
		_dirt(P, 10, 1.0 * s, 5.5 * s, t * 1.2, g + Vector3(0, 0.3, 0), Color(_c(P, "b"), 0.9))
	VfxKit.shake(r, 0.6)


# ---------- Молния ----------

## Молния с неба (как на референсах Максима): магический круг вспыхивает под целью, с неба бьёт ветвистый разряд
## (StormFX), рядом — ещё один-два, оранжевые искры веером, треск разряда, обломки, голубой дым, трещины.
static func _a_lightning_strike(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	var g := _local_ground(P)
	var at := r.global_position
	var off := g - at
	var q := int(P["q"])
	var sky := at + Vector3(rng.randf_range(-1.0, 1.0), 10.0, rng.randf_range(-1.0, 1.0))
	if VfxKit.sky_strike(r, P["pal"], String(P["el"]), g, 1.8 * s, 10.0, q, 0.0, maxf(0.6, t)) == null:
		VfxKit.bolt(r, Color(_c(P, "a"), 0.85), sky + Vector3(0.3, 0, 0), g + Vector3(0, 0.1, 0), 0.6 * s, t * 0.7,
			rng, 9, 0.9)
	VfxKit.bolt(r, Color(_c(P, "core"), 1.0), sky, g + Vector3(0, 0.1, 0), 0.18 * s, t * 0.7, rng, 12, 0.7, 3)
	VfxKit.pillar(r, Color(_c(P, "a"), 0.5), g, 0.5 * s, 10.0, t * 0.4)
	# Знаки на земле: круг под ударом и рябь от него
	_circle(P, 1.9 * s, t + 1.0, "circle", 0.0, 0.16)
	if _rich(P):
		_circle(P, 2.9 * s, t + 0.5, "ripple", 0.08, 0.2)
		# Ещё удары рядом — каждый со своим кругом
		for i in (2 if _hi(P) else 1):
			var ang := rng.randf() * TAU
			var pg := g + Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(1.8, 2.8) * s
			var dl := 0.16 + 0.17 * float(i)
			VfxKit.sky_strike(r, P["pal"], String(P["el"]), pg, 0.9 * s, 8.0, q, dl, 0.45)
			_circle(P, 0.9 * s, t + 0.4, "circle", dl, 0.12, pg)
	_hot_core(P, 1.4 * s, t, off + Vector3(0, 0.4, 0))
	_crackle(P, 3.2 * s, t * 0.45, off + Vector3(0, 0.7, 0), Color(_c(P, "c"), 1.0))
	# Оранжевые искры веером: раскалённые брызги от удара (тёплый цвет на фоне холодного разряда)
	VfxKit.particles(r, {"amount": _n(P, 30), "life": t * 0.95, "color": Color(1.0, 0.86, 0.5),
		"color2": Color(1.0, 0.45, 0.12, 0.0), "size": 0.3 * s, "speed": 9.0 * s, "tex": "streak", "align": true,
		"gravity": Vector3(0, -10.0, 0), "damping": 1.0, "offset": off + Vector3(0, 0.3, 0), "dir": Vector3.UP,
		"spread": 80.0})
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.9), g, 3.6 * s, t * 0.6, true)
	if _rich(P):
		VfxKit.decal(r, "crack", Color(_c(P, "b"), 0.85), g, 2.6 * s, t * 1.4, true, 0.8, 0.1, 0.0, 0.0, 0.0, "lava")
		_debris(P, 12, 0.2 * s, 7.0 * s, t * 1.2, g + Vector3(0, 0.3, 0), Color(0.32, 0.3, 0.34))
		_dirt(P, 6, 0.9 * s, 4.0 * s, t, g + Vector3(0, 0.3, 0), Color(0.35, 0.33, 0.4, 0.9))
		# Голубой дым от удара
		_dust(P, 14, 1.5 * s, 2.4 * s, t * 2.0, 0.8 * s, 0.08)
		for i in 4:
			var d := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized()
			VfxKit.bolt(r, Color(_c(P, "c"), 0.9), g + Vector3(0, 0.15, 0), g + d * 1.8 * s + Vector3(0, 0.1, 0),
				0.1 * s, t * 0.5, rng, 5, 0.25)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 6.0, 9.0 * s, t * 0.4)
	VfxKit.shake(r, 0.55)


static func _a_lightning_bolt(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	var a: Vector3 = P["from"]
	var b := r.global_position
	VfxKit.bolt(r, Color(_c(P, "core"), 1.0), a, b, 0.18 * s, t * 0.7, rng, 10, 0.45, 2)
	VfxKit.bolt(r, Color(_c(P, "b"), 0.8), a, b, 0.5 * s, t * 0.6, rng, 7, 0.6)
	_a_spark_hit(P)


static func _a_spark_hit(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var rng: RandomNumberGenerator = P["rng"]
	_hot_core(P, 1.0 * s, t)
	_streaks(P, 16, 0.28 * s, 7.0 * s, t * 0.5)
	_crackle(P, 2.2 * s, t * 0.4, Vector3.ZERO, Color(_c(P, "c"), 1.0))
	if _rich(P):
		var at := r.global_position
		for i in 4:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
			VfxKit.bolt(r, Color(_c(P, "a"), 0.95), at, at + d * 1.4 * s, 0.1 * s, t * 0.5, rng, 5, 0.25)
		VfxKit.sphere(r, Color(_c(P, "a"), 0.6), 0.9 * s, t * 0.4, Vector3.ZERO, true, 0.3, 0.0, "shell")
	VfxKit.shake(r, 0.1)


# ---------- Свет и лечение ----------

static func _a_heal_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	if not _circle(P, 1.5 * s, t * 1.5, "circle", 0.0, 0.3):
		VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.9), g, 2.8 * s, t * 1.5, true, 0.5, 0.3, 0.25)
	VfxKit.helix(r, Color(_c(P, "a"), 0.95), g, 0.75 * s, h + 0.5, t * 1.2, 1.6, 0.14)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.7), 2.6 * s, t * 0.9, true, off + Vector3(0, h * 0.55, 0))
	var up := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.2, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.38 * s, "speed": 2.4 * s, "tex": "plus", "shape": "ring",
		"radius": 0.6 * s, "dir": Vector3.UP, "spread": 12.0, "curve": "twinkle"})
	up.global_position = g + Vector3(0, 0.2, 0)
	var spark := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.3, "color": _c(P, "c"), "size": 0.18 * s,
		"speed": 1.8 * s, "tex": "star", "shape": "ring", "radius": 0.8 * s, "dir": Vector3.UP, "spread": 25.0,
		"orbit": 3.0, "curve": "twinkle"})
	spark.global_position = g + Vector3(0, 0.4, 0)
	if _rich(P):
		VfxKit.helix(r, Color(_c(P, "c"), 0.8), g, 0.9 * s, h + 0.8, t * 1.3, 1.3, 0.1, PI)
		VfxKit.pillar(r, Color(_c(P, "b"), 0.35), g, 0.8 * s, h + 0.8, t * 1.2)
		VfxKit.torus(r, Color(_c(P, "b"), 0.6), 1.0 * s, t * 1.1, off + Vector3(0, 0.6, 0), true)


static func _a_holy_beam(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	VfxKit.pillar(r, Color(_c(P, "a"), 0.8), g, 1.0 * s, 11.0, t * 1.1)
	VfxKit.pillar(r, Color(_c(P, "core"), 1.0), g, 0.4 * s, 11.0, t * 0.9)
	VfxKit.pillar(r, Color(_c(P, "b"), 0.3), g, 1.7 * s, 8.0, t * 1.2)
	_hot_core(P, 1.4 * s, t, off + Vector3(0, 0.5, 0))
	VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.95), g, 3.4 * s, t * 1.4, true, 0.5, 0.25, 0.3)
	VfxKit.wall(r, Color(_c(P, "a"), 0.8), g, 3.6 * s, 1.2 * s, t * 0.7)
	var fall := VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 1.2, "color": _c(P, "c"), "size": 0.2 * s,
		"speed": 1.0, "tex": "star", "shape": "box", "box": Vector3(0.9, 0.2, 0.9) * s, "dir": Vector3.DOWN,
		"spread": 10.0, "gravity": Vector3(0, -3.0, 0), "curve": "twinkle", "explosive": 0.2})
	fall.global_position = g + Vector3(0, 5.0, 0)
	if _rich(P):
		_streaks(P, 14, 0.45 * s, 7.0 * s, t * 0.6, off + Vector3(0, 0.3, 0), Vector3.UP, 70.0, 0.0)
		_embers(P, 12, 0.12 * s, t * 2.0, g + Vector3(0, 0.6, 0), 1.0 * s)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 4.0, 8.0 * s, t * 0.7)
	VfxKit.shake(r, 0.35)


static func _a_holy_nova(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	_hot_core(P, 1.6 * s, t, off + Vector3(0, 0.6, 0))
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.95), g, 6.2 * s, t * 0.8, true)
	if not _circle(P, 2.3 * s, t * 1.5, "circle", 0.0, 0.2):
		VfxKit.decal(r, "rune", Color(_c(P, "c"), 0.9), g, 4.4 * s, t * 1.4, true, 0.7, 0.2, 0.2)
	_circle(P, 3.1 * s, t * 1.1, "ripple", 0.0, 0.15)
	VfxKit.wall(r, Color(_c(P, "a"), 0.85), g, 5.4 * s, 1.6 * s, t * 0.8)
	VfxKit.torus(r, Color(_c(P, "b"), 0.7), 3.0 * s, t * 0.8, off + Vector3(0, 0.5, 0), true)
	var rays := VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 0.8, "color": _c(P, "a"), "size": 0.5 * s,
		"speed": 8.0 * s, "tex": "streak", "align": true, "shape": "ring", "radius": 0.3, "dir": Vector3.UP,
		"spread": 75.0, "damping": 4.0})
	rays.global_position = g + Vector3(0, 0.4, 0)
	if _rich(P):
		VfxKit.pillar(r, Color(_c(P, "core"), 0.8), g, 0.6 * s, 6.0, t * 0.6)
		_embers(P, 18, 0.14 * s, t * 1.8, g + Vector3(0, 0.6, 0), 1.6 * s)
	if _hi(P):
		VfxKit.light(r, _c(P, "a"), 3.5, 8.0 * s, t * 0.6)
	VfxKit.shake(r, 0.25)


static func _a_shield(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var h := float(P["h"])
	var center := Vector3(0, h * 0.5, 0) + _goff(P)
	var rad := 1.25 * s * maxf(h / 1.7, 0.7)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.85), rad, t, center, true, 0.6, 0.55, "shell")
	VfxKit.sphere(r, Color(_c(P, "b"), 0.4), rad * 1.08, t * 0.9, center, true, 0.3, 0.4, "shell")
	var t1 := VfxKit.torus(r, Color(_c(P, "b"), 0.9), 1.3 * s, t * 0.85, center, true, Vector3(0.4, 0, 0.2))
	var t2 := VfxKit.torus(r, Color(_c(P, "c"), 0.8), 1.2 * s, t * 0.85, center, true, Vector3(-0.5, 0, -0.3))
	var tw := t1.create_tween().set_parallel(true)
	tw.tween_property(t1, "rotation:y", TAU * 0.5, t)
	tw.tween_property(t2, "rotation:y", -TAU * 0.5, t)
	VfxKit.flash(r, "star", Color(_c(P, "core"), 1.0), 2.4 * s, t * 0.4, true, center)
	if not _circle(P, 1.3 * s, t, "circle", 0.0, 0.3):
		VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.8), _local_ground(P), 2.6 * s, t, true, 0.6, 0.3, 0.15)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 0.9, "color": _c(P, "c"), "size": 0.18 * s,
			"speed": 0.6, "tex": "star", "radius": 1.1 * s, "orbit": 4.0, "curve": "twinkle", "offset": center,
			"explosive": 0.4})


static func _a_blessing(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	if not _circle(P, 1.6 * s, t * 1.5, "circle", 0.0, 0.3):
		VfxKit.decal(r, "rune", Color(_c(P, "a"), 0.95), g, 3.0 * s, t * 1.5, true, 0.4, 0.3, 0.35)
	VfxKit.helix(r, Color(_c(P, "a"), 0.95), g, 0.7 * s, h + 0.4, t * 1.1, 2.0, 0.12)
	VfxKit.torus(r, Color(_c(P, "c"), 0.95), 0.55 * s, t * 1.2, off + Vector3(0, h + 0.35, 0), true, Vector3.ZERO, 0.6)
	var up := VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 1.1, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.24 * s, "speed": 2.8, "tex": "star", "shape": "ring",
		"radius": 0.7 * s, "dir": Vector3.UP, "spread": 8.0, "orbit": 5.0, "curve": "twinkle", "explosive": 0.6})
	up.global_position = g + Vector3(0, 0.15, 0)
	VfxKit.flash(r, "star", _c(P, "core"), 2.0 * s, t * 0.5, true, off + Vector3(0, h + 0.35, 0), 0.25, t * 0.3)
	if _rich(P):
		VfxKit.helix(r, Color(_c(P, "b"), 0.8), g, 0.85 * s, h + 0.6, t * 1.2, 1.6, 0.09, PI)
		VfxKit.pillar(r, Color(_c(P, "b"), 0.35), g, 0.75 * s, h + 0.6, t * 1.1)


static func _a_buff_up(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	VfxKit.decal(r, "ring", Color(_c(P, "a"), 0.95), g, 2.6 * s, t * 0.9, true)
	_circle(P, 1.2 * s, t * 1.2, "circle", 0.0, 0.2)
	VfxKit.helix(r, Color(_c(P, "a"), 0.95), g, 0.65 * s, h + 0.3, t * 0.9, 1.5, 0.12)
	VfxKit.torus(r, Color(_c(P, "a"), 0.8), 0.85 * s, t, off + Vector3(0, 0.2, 0), true)
	VfxKit.orb(r, Color(_c(P, "c"), 0.8), 1.4 * s, t * 0.6, off + Vector3(0, h * 0.55, 0), 0.0)
	var up := VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.1, "color": _c(P, "c"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.22 * s, "speed": 3.0, "tex": "star", "shape": "ring",
		"radius": 0.55 * s, "dir": Vector3.UP, "spread": 6.0, "orbit": 6.0, "curve": "twinkle", "explosive": 0.5})
	up.global_position = g + Vector3(0, 0.1, 0)
	if _rich(P):
		_streaks(P, 12, 0.4 * s, 4.5, t * 0.8, off + Vector3(0, 0.3, 0), Vector3.UP, 15.0, 0.0)


# ---------- Тьма, кровь, секта ----------

static func _a_shadow_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.sphere(r, _c(P, "core"), 1.2 * s, t * 0.8, Vector3.ZERO, false, 0.4, 0.0, "fireball")
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 1.0), 2.8 * s, t * 0.75)
	VfxKit.spin(sw, -1.0, t * 0.75)
	VfxKit.flash(r, "star", Color(_c(P, "b"), 0.9), 1.6 * s, t * 0.4)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.6), 3.0 * s, t * 0.6)
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 1.3, "color": _c(P, "smoke"),
		"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 2.6 * s, "tex": "smoke", "add": false,
		"damping": 2.0, "gravity": Vector3(0, 0.8, 0), "curve": "grow"})
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 0.9, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.18 * s, "speed": 5.5 * s, "tex": "star", "damping": 2.0, "curve": "twinkle", "hue": 0.06})
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.8, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
			"size": 0.6 * s, "speed": 0.4, "tex": "soft", "radius": 1.8 * s, "radial": -9.0, "curve": "grow",
			"explosive": 0.8})
		VfxKit.decal(r, "sigil", Color(_c(P, "a"), 0.8), _local_ground(P), 2.6 * s, t * 1.2, true, 0.6, 0.25, -0.3)
	VfxKit.shake(r, 0.15)


static func _a_cursed_sigil(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	VfxKit.decal(r, "sigil", Color(_c(P, "a"), 1.0), g, 3.8 * s, t * 1.4, true, 0.85, 0.3, -0.25, 0.0, 0.25)
	VfxKit.decal(r, "soft", Color(_c(P, "smoke"), 0.8), g, 4.4 * s, t * 1.4, false, 0.9, 0.3)
	_circle(P, 2.4 * s, t * 1.4, "circle", 0.0, 0.3)
	VfxKit.wall(r, Color(_c(P, "a"), 0.6), g, 2.0 * s, 1.6 * s, t * 1.2, true, 0.95, "swirl")
	var wisp := VfxKit.particles(r, {"amount": _n(P, 20), "life": t * 1.3, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.4 * s, "speed": 2.4, "tex": "soft", "shape": "ring",
		"radius": 1.4 * s, "dir": Vector3.UP, "spread": 10.0, "orbit": 2.0, "curve": "twinkle", "explosive": 0.3})
	wisp.global_position = g + Vector3(0, 0.1, 0)
	if _rich(P):
		for i in 5:
			var ang := TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
			VfxKit.pillar(r, Color(_c(P, "a"), 0.7), g + Vector3(cos(ang), 0, sin(ang)) * 1.7 * s, 0.12 * s,
				2.2 * s, t * 0.9)
		var sp := VfxKit.particles(r, {"amount": _n(P, 12), "life": t, "color": _c(P, "c"), "size": 0.16 * s,
			"speed": 3.0, "tex": "star", "shape": "ring", "radius": 1.6 * s, "dir": Vector3.UP, "spread": 20.0,
			"curve": "twinkle"})
		sp.global_position = g + Vector3(0, 0.1, 0)
	VfxKit.shake(r, 0.15)


static func _a_emerald_curse(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	VfxKit.decal(r, "sigil", Color(_c(P, "a"), 1.0), g, 2.8 * s, t * 1.3, true, 0.5, 0.25, 0.4)
	_circle(P, 2.0 * s, t * 1.1, "ripple", 0.0, 0.25)
	VfxKit.helix(r, Color(_c(P, "a"), 0.95), g, 0.7 * s, h + 0.4, t * 1.1, 2.2, 0.1)
	VfxKit.torus(r, Color(_c(P, "a"), 0.85), 0.9 * s, t, off + Vector3(0, h * 0.55, 0), true, Vector3(0.3, 0, 0), 0.7)
	VfxKit.torus(r, Color(_c(P, "c"), 0.7), 0.75 * s, t, off + Vector3(0, h * 0.85, 0), true, Vector3(-0.3, 0, 0.2), 0.6)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.9), 2.0 * s, t * 0.6, true, off + Vector3(0, h * 0.6, 0))
	VfxKit.spin(sw, 1.0, t * 0.6)
	var wisp := VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.2, "color": _c(P, "a"),
		"color2": Color(_c(P, "c"), 0.0), "size": 0.3 * s, "speed": 1.4, "tex": "soft", "shape": "ring",
		"radius": 0.6 * s, "dir": Vector3.UP, "spread": 10.0, "orbit": 4.0, "curve": "twinkle", "explosive": 0.3})
	wisp.global_position = g + Vector3(0, 0.1, 0)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 1.4, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 0.8, "tex": "smoke", "add": false,
			"offset": off + Vector3(0, h * 0.5, 0), "radius": 0.5 * s, "curve": "grow", "gravity": Vector3(0, 0.6, 0)})


static func _a_soul_drain(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var a := r.global_position
	var b: Vector3 = P["from"]
	var to := b - a
	var life := t * 0.9
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.95), 1.9 * s, t * 0.7)
	VfxKit.spin(sw, -1.2, t * 0.7)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.7), 2.4 * s, t * 0.6)
	# Души летят от цели к герою: скорость — расстояние за время жизни, без разлёта
	VfxKit.particles(r, {"amount": _n(P, 18), "life": life, "color": _c(P, "a"), "color2": Color(_c(P, "c"), 0.2),
		"size": 0.34 * s, "speed": to.length() / maxf(life, 0.1), "tex": "soft", "dir": to.normalized(),
		"spread": 6.0, "explosive": 0.1, "radius": 0.3, "curve": "twinkle"})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": life, "color": _c(P, "c"), "size": 0.4 * s,
		"speed": to.length() / maxf(life, 0.1), "tex": "streak", "align": true, "dir": to.normalized(),
		"spread": 4.0, "explosive": 0.3, "radius": 0.2})
	VfxKit.beam(r, Color(_c(P, "b"), 0.6), a, b, 0.1 * s, t * 0.8)
	if _rich(P):
		VfxKit.orb(r, Color(_c(P, "c"), 0.9), 1.3 * s, life, to, 0.0)
		VfxKit.flash(r, "star", Color(_c(P, "c"), 0.9), 1.4 * s, t * 0.5, true, to, 0.25, life * 0.8)


static func _a_toxic_pool(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "soft", Color(_c(P, "b"), 0.9), g, 3.6 * s, t, false, 0.4, 0.15, 0.0, 0.0, 0.05, "smoke")
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.8), g, 3.2 * s, t, true, 0.4, 0.2, 0.1)
	VfxKit.decal(r, "crack", Color(_c(P, "a"), 0.6), g, 2.6 * s, t, true, 0.5, 0.2, -0.1, 0.0, 0.0, "lava")
	_circle(P, 1.8 * s, t, "ripple", 0.0, 0.4)
	var bub := VfxKit.particles(r, {"amount": _n(P, 16), "life": 0.9, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.24 * s, "speed": 0.9, "tex": "ring", "shape": "box",
		"box": Vector3(1.1, 0.05, 1.1) * s, "dir": Vector3.UP, "spread": 10.0, "curve": "pop", "explosive": 0.0})
	bub.global_position = g + Vector3(0, 0.1, 0)
	bub.one_shot = false
	var tw := bub.create_tween()
	tw.tween_interval(maxf(t - 0.9, 0.1))
	tw.tween_callback(func() -> void: bub.emitting = false)
	if _rich(P):
		var fume := VfxKit.particles(r, {"amount": _n(P, 10), "life": 1.6, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.1 * s, "speed": 0.6, "tex": "smoke", "add": false,
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
	VfxKit.flash(r, "star", Color(_c(P, "c"), 1.0), 1.7 * s, t * 0.4)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.7), 2.4 * s, t * 0.5)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "a"), 0.95), 2.2 * s, t * 0.6)
	VfxKit.spin(sw, 0.8, t * 0.6)
	VfxKit.particles(r, {"amount": _n(P, 22), "life": t * 0.9, "color": _c(P, "a"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.3 * s, "speed": 5.0 * s, "tex": "drop", "gravity": Vector3(0, -11.0, 0), "align": true})
	VfxKit.arc(r, Color(_c(P, "a"), 0.95), P["dir"], 1.1 * s, t * 0.8, 0.8, Vector3.ZERO, 1.6, 1.0)
	if _rich(P):
		VfxKit.decal(r, "smoke", Color(_c(P, "b"), 0.8), _local_ground(P), 1.8 * s, t * 1.8, false, 0.5, 0.2)
		VfxKit.particles(r, {"amount": _n(P, 6), "life": t * 1.2, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.8 * s, "speed": 1.0, "tex": "smoke", "add": false,
			"curve": "grow"})
	VfxKit.shake(r, 0.1)


static func _a_ritual_circle(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var rng: RandomNumberGenerator = P["rng"]
	if not _circle(P, 2.6 * s, t * 1.4, "circle", 0.0, 0.45):
		VfxKit.decal(r, "rune", Color(_c(P, "a"), 1.0), g, 5.0 * s, t * 1.3, true, 0.9, 0.25, 0.3, 0.0, 0.2)
	VfxKit.decal(r, "sigil", Color(_c(P, "c"), 0.9), g, 3.2 * s, t * 1.3, true, 0.9, 0.25, -0.5, 0.0, 0.2)
	if _rich(P):
		_circle(P, 3.4 * s, t * 1.2, "ripple", 0.15, 0.3)
	VfxKit.wall(r, Color(_c(P, "a"), 0.7), g, 2.5 * s, 1.0 * s, t * 1.1, true, 0.98, "magic")
	VfxKit.pillar(r, Color(_c(P, "a"), 0.7), g, 0.5 * s, 4.0 * s, t * 0.8)
	if _rich(P):
		for i in 6:
			var ang := TAU * float(i) / 6.0 + rng.randf_range(-0.15, 0.15)
			var pg := g + Vector3(cos(ang), 0, sin(ang)) * 2.2 * s
			VfxKit.pillar(r, Color(_c(P, "a"), 0.75), pg, 0.18 * s, 2.8 * s, t)
	var wisp := VfxKit.particles(r, {"amount": _n(P, 24), "life": t * 1.1, "color": _c(P, "a"),
		"color2": Color(_c(P, "b"), 0.0), "size": 0.32 * s, "speed": 2.2, "tex": "soft", "shape": "ring",
		"radius": 2.2 * s, "dir": Vector3.UP, "spread": 8.0, "orbit": 3.0, "curve": "twinkle", "explosive": 0.2})
	wisp.global_position = g + Vector3(0, 0.1, 0)
	VfxKit.shake(r, 0.25)


static func _a_ghost(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	# Призрачная фигура: клубящееся тело поднимается и тает, два светящихся глаза, след из огоньков
	var g := VfxKit.flash(r, "smoke", Color(_c(P, "a"), 0.8), 2.0 * s, t, true, Vector3(0, 0.3, 0), 0.6, 0.0, "fire")
	var tw := g.create_tween()
	tw.tween_property(g, "position:y", 1.6 * s, t).set_trans(Tween.TRANS_SINE)
	var g2 := VfxKit.flash(r, "glow", Color(_c(P, "b"), 0.5), 2.6 * s, t, true, Vector3(0, 0.3, 0), 0.6)
	var tw0 := g2.create_tween()
	tw0.tween_property(g2, "position:y", 1.5 * s, t).set_trans(Tween.TRANS_SINE)
	for i in 2:
		var e := VfxKit.flash(r, "star", Color(_c(P, "core"), 1.0), 0.4 * s, t * 0.8, true,
			Vector3((float(i) - 0.5) * 0.35 * s, 0.75 * s, 0.25), 0.8)
		var te := e.create_tween()
		te.tween_property(e, "position:y", 2.0 * s, t).set_trans(Tween.TRANS_SINE)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.28 * s, "speed": 1.3, "tex": "soft", "dir": Vector3.UP, "spread": 30.0, "curve": "twinkle",
		"explosive": 0.3})
	VfxKit.decal(r, "soft", Color(_c(P, "b"), 0.7), _local_ground(P), 2.2 * s, t, true, 0.6, 0.3)
	if _rich(P):
		VfxKit.helix(r, Color(_c(P, "a"), 0.7), _local_ground(P), 0.6 * s, 2.2 * s, t, 1.4, 0.08)


# ---------- Ветер ----------

static func _a_wind_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	VfxKit.arc(r, Color(_c(P, "a"), 1.0), d, 1.4 * s, t * 0.9, 0.5, Vector3.ZERO, 1.8, 1.1)
	VfxKit.arc(r, Color(_c(P, "c"), 0.9), d, 1.1 * s, t * 0.8, -0.6, Vector3(0, 0.2, 0), 1.6, 0.8)
	VfxKit.arc(r, Color(_c(P, "core"), 0.7), d, 1.6 * s, t * 0.7, 0.1, Vector3(0, -0.1, 0), 2.0, 0.4)
	VfxKit.particles(r, {"amount": _n(P, 16), "life": t * 0.7, "color": _c(P, "c"), "color2": Color(_c(P, "b"), 0.0),
		"size": 0.4 * s, "speed": 5.5 * s, "tex": "streak", "align": true, "orbit": 8.0})
	if _rich(P):
		VfxKit.gust(r, P["pal"], String(P["el"]), _local_ground(P) - d * 1.2 * s, d, 1.0 * s, 1.8, t + 0.7, int(P["q"]))
		VfxKit.torus(r, Color(_c(P, "a"), 0.6), 1.4 * s, t * 0.6, Vector3.ZERO, true, Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.5)
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 1.1, "color": _c(P, "b"), "size": 0.2 * s,
			"speed": 3.0 * s, "mesh": "crystal", "gravity": Vector3(0, -2.0, 0), "spin": 400.0})
	VfxKit.shake(r, 0.08)


static func _a_tornado(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	VfxKit.decal(r, "swirl", Color(_c(P, "a"), 0.9), g, 4.0 * s, t * 1.2, true, 0.5, 0.3, 1.5)
	VfxKit.funnel(r, Color(_c(P, "a"), 0.85), g, 0.9 * s, 3.6 * s, t, true, 3.0)
	VfxKit.funnel(r, Color(_c(P, "c"), 0.6), g, 0.6 * s, 3.0 * s, t * 0.9, true, -2.0)
	var pivot := Node3D.new()
	r.add_child(pivot)
	pivot.global_position = g
	VfxKit.particles(pivot, {"amount": _n(P, 28), "life": t * 0.9, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.45 * s, "speed": 3.2 * s, "tex": "streak", "shape": "ring",
		"radius": 0.9 * s, "dir": Vector3.UP, "spread": 5.0, "orbit": 14.0, "radial": 1.5, "local": true,
		"explosive": 0.4, "align": true})
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation:y", TAU * 2.0, t)
	if _rich(P):
		VfxKit.particles(pivot, {"amount": _n(P, 12), "life": t * 1.1, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 1.0 * s, "speed": 2.0, "tex": "smoke", "add": false,
			"shape": "ring", "radius": 1.0 * s, "dir": Vector3.UP, "spread": 20.0, "orbit": 6.0, "curve": "grow",
			"local": true, "explosive": 0.3})
		_debris(P, 8, 0.16 * s, 5.0 * s, t, g + Vector3(0, 0.2, 0), _c(P, "smoke"))
		VfxKit.gust(r, P["pal"], String(P["el"]), g - (P["dir"] as Vector3) * 2.0 * s, P["dir"], 1.4 * s, 2.4 * s,
			t + 0.8, int(P["q"]))
	VfxKit.shake(r, 0.2)


# ---------- Оружие ----------

static func _a_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	var rng: RandomNumberGenerator = P["rng"]
	var tilt := rng.randf_range(-0.6, 0.6)
	VfxKit.arc(r, Color(_c(P, "a"), 1.0), d, 1.4 * s, t, tilt, Vector3.ZERO, 1.6, 1.2)
	VfxKit.arc(r, Color(_c(P, "core"), 1.0), d, 1.3 * s, t * 0.85, tilt, Vector3.ZERO, 1.5, 0.45)
	VfxKit.flash(r, "star", _c(P, "core"), 1.6 * s, t * 0.35, true, Vector3.ZERO, 0.15)
	_streaks(P, 14, 0.25 * s, 7.0 * s, t * 0.45, Vector3.ZERO, d, 70.0, -5.0)
	if _rich(P):
		VfxKit.arc(r, Color(_c(P, "b"), 0.45), d, 1.6 * s, t * 0.9, tilt, Vector3.ZERO, 1.7, 2.0)
		VfxKit.flash(r, "glow", Color(_c(P, "b"), 0.6), 2.0 * s, t * 0.4)
	VfxKit.shake(r, 0.08)


static func _a_cleave(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	var g := _local_ground(P)
	VfxKit.arc(r, Color(_c(P, "a"), 1.0), d, 1.8 * s, t, 1.25, Vector3(0, 0.3, 0), 1.8, 1.5)
	VfxKit.arc(r, Color(_c(P, "core"), 1.0), d, 1.65 * s, t * 0.85, 1.25, Vector3(0, 0.3, 0), 1.7, 0.5)
	VfxKit.arc(r, Color(_c(P, "b"), 0.45), d, 2.0 * s, t, 1.25, Vector3(0, 0.3, 0), 1.9, 2.2)
	_hot_core(P, 1.1 * s, t)
	VfxKit.decal(r, "crack", Color(_c(P, "c"), 0.85), g, 2.8 * s, t * 2.0, true, 0.7, 0.12, 0.0, 0.0, 0.0, "lava")
	VfxKit.wall(r, Color(_c(P, "smoke"), 0.7), g, 2.4 * s, 0.8 * s, t * 0.7, false, 0.2, "smoke")
	_streaks(P, 16, 0.3 * s, 8.0 * s, t * 0.55, Vector3.ZERO, Vector3.UP, 180.0, -7.0)
	if _rich(P):
		_dust(P, 10, 0.9 * s, 2.4 * s, t * 1.2, 0.5 * s)
		_debris(P, 6, 0.16 * s, 5.0 * s, t, g + Vector3(0, 0.2, 0), _c(P, "smoke"))
	VfxKit.shake(r, 0.35)


static func _a_stab(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	var at := r.global_position
	VfxKit.flash(r, "star", _c(P, "core"), 1.7 * s, t * 0.35, true, Vector3.ZERO, 0.15)
	VfxKit.beam(r, Color(_c(P, "a"), 0.95), at - d * 1.2 * s, at + d * 0.6 * s, 0.09 * s, t * 0.45)
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.45, "color": _c(P, "core"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.55 * s, "speed": 10.0 * s, "tex": "streak", "align": true, "dir": d, "spread": 10.0,
		"offset": -d * 0.8})
	VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.6, "color": _c(P, "c"), "size": 0.16 * s, "speed": 4.5 * s,
		"tex": "star", "dir": d, "spread": 60.0, "curve": "twinkle"})
	if _rich(P):
		VfxKit.torus(r, Color(_c(P, "a"), 0.8), 0.7 * s, t * 0.5, Vector3.ZERO, true,
			Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.6)
		VfxKit.torus(r, Color(_c(P, "c"), 0.6), 0.45 * s, t * 0.45, d * 0.4 * s, true,
			Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.5)
	VfxKit.shake(r, 0.1)


static func _a_blunt_hit(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	_hot_core(P, 1.2 * s, t)
	VfxKit.torus(r, Color(_c(P, "a"), 0.9), 1.2 * s, t * 0.55, Vector3.ZERO, true,
		Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.7)
	VfxKit.sphere(r, Color(_c(P, "a"), 0.55), 1.0 * s, t * 0.4, Vector3.ZERO, true, 0.3, 0.0, "shell")
	VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
		"size": 0.22 * s, "speed": 6.5 * s, "tex": "star", "gravity": Vector3(0, -7.0, 0), "curve": "twinkle"})
	if _rich(P):
		VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.8), _local_ground(P), 2.4 * s, t * 0.6, true)
		VfxKit.wall(r, Color(_c(P, "smoke"), 0.6), _local_ground(P), 1.8 * s, 0.6 * s, t * 0.6, false, 0.2, "smoke")
	VfxKit.shake(r, 0.3)


static func _a_spin_slash(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position + Vector3(0, 0.9, 0)
	VfxKit.arc(r, Color(_c(P, "a"), 1.0), Vector3.FORWARD, 2.1 * s, t, 0.0, off, TAU * 0.95, 1.1)
	VfxKit.arc(r, Color(_c(P, "core"), 0.95), Vector3.BACK, 1.9 * s, t * 0.9, 0.15, off + Vector3(0, 0.25, 0),
		TAU * 0.9, 0.5)
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.85), g, 5.0 * s, t * 0.7, true)
	VfxKit.wall(r, Color(_c(P, "a"), 0.7), g, 3.6 * s, 0.9 * s, t * 0.7)
	var sp := VfxKit.particles(r, {"amount": _n(P, 20), "life": t * 0.6, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.32 * s, "speed": 6.5 * s, "tex": "streak", "align": true,
		"shape": "ring", "radius": 1.0 * s, "dir": Vector3.UP, "spread": 85.0, "orbit": 10.0})
	sp.position = off
	if _rich(P):
		VfxKit.arc(r, Color(_c(P, "b"), 0.4), Vector3.RIGHT, 2.3 * s, t, -0.1, off - Vector3(0, 0.2, 0), TAU * 0.95, 2.0)
		_dust(P, 12, 0.9 * s, 3.2 * s, t * 1.1, 1.2 * s)
	VfxKit.shake(r, 0.25)


static func _a_arrow_impact(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	VfxKit.flash(r, "star", Color(_c(P, "core"), 1.0), 1.3 * s, t * 0.35, true, Vector3.ZERO, 0.15)
	VfxKit.flash(r, "ring", Color(_c(P, "a"), 0.9), 1.6 * s, t * 0.45, true, Vector3.ZERO, 0.2, t * 0.05, "spark")
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.6), 1.8 * s, t * 0.4)
	_streaks(P, 12, 0.22 * s, 5.5 * s, t * 0.5)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 5), "life": t * 0.9, "color": _c(P, "smoke"),
			"color2": Color(_c(P, "smoke"), 0.0), "size": 0.55 * s, "speed": 1.2 * s, "tex": "smoke", "add": false,
			"curve": "grow"})
	VfxKit.shake(r, 0.06)


# ---------- Звери, дух ----------

static func _a_claw(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var d: Vector3 = P["dir"]
	var rng: RandomNumberGenerator = P["rng"]
	# Три параллельных росчерка когтей наискосок
	var tilt := rng.randf_range(0.7, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	var side := d.cross(Vector3.UP).normalized()
	for i in 3:
		var off := side * (float(i) - 1.0) * 0.28 * s
		VfxKit.arc(r, Color(_c(P, "a"), 1.0), d, 1.1 * s, t * (0.8 + 0.08 * float(i)), tilt, off, 1.3, 0.5)
		VfxKit.arc(r, Color(_c(P, "core"), 0.9), d, 1.05 * s, t * (0.7 + 0.08 * float(i)), tilt, off, 1.25, 0.2)
	VfxKit.flash(r, "star", _c(P, "core"), 1.4 * s, t * 0.35, true, Vector3.ZERO, 0.15)
	_streaks(P, 12, 0.25 * s, 5.5 * s, t * 0.5)
	if _rich(P):
		VfxKit.flash(r, "glow", Color(_c(P, "b"), 0.6), 2.0 * s, t * 0.45)
		VfxKit.particles(r, {"amount": _n(P, 8), "life": t * 0.8, "color": _c(P, "b"), "size": 0.16 * s,
			"speed": 3.5 * s, "tex": "star", "curve": "twinkle"})
	VfxKit.shake(r, 0.1)


static func _a_roar(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var h := float(P["h"])
	var g := _local_ground(P)
	var off := g - r.global_position + Vector3(0, h * 0.85, 0)
	for i in 3:
		VfxKit.flash(r, "ring", Color(_c(P, "a" if i % 2 == 0 else "b"), 0.9), (2.4 + float(i)) * s, t * 0.6, true,
			off, 0.2, float(i) * t * 0.15, "wave")
	VfxKit.decal(r, "wave", Color(_c(P, "a"), 0.85), g, 5.0 * s, t * 0.8, true)
	VfxKit.wall(r, Color(_c(P, "a"), 0.65), g, 4.2 * s, 1.3 * s, t * 0.8)
	VfxKit.torus(r, Color(_c(P, "c"), 0.7), 2.6 * s, t * 0.7, off, true, Vector3.ZERO, 0.6)
	if _rich(P):
		VfxKit.particles(r, {"amount": _n(P, 14), "life": t * 0.6, "color": _c(P, "c"), "size": 0.4 * s,
			"speed": 7.0 * s, "tex": "streak", "align": true, "offset": off, "spread": 90.0, "dir": Vector3.UP})
		_dust(P, 10, 1.0 * s, 3.0 * s, t * 1.1, 1.0 * s)
	VfxKit.shake(r, 0.3)


static func _a_spirit_burst(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	_hot_core(P, 1.1 * s, t)
	var sw := VfxKit.flash(r, "swirl", Color(_c(P, "b"), 0.9), 2.3 * s, t * 0.7)
	VfxKit.spin(sw, 0.7, t * 0.7)
	VfxKit.particles(r, {"amount": _n(P, 18), "life": t * 1.1, "color": _c(P, "a"), "color2": Color(_c(P, "c"), 0.0),
		"size": 0.32 * s, "speed": 3.2 * s, "tex": "soft", "orbit": 5.0, "damping": 2.0, "curve": "twinkle",
		"hue": 0.08})
	if _rich(P):
		VfxKit.sphere(r, Color(_c(P, "a"), 0.6), 1.2 * s, t * 0.6, Vector3.ZERO, true, 0.3, 0.0, "shell")
		_embers(P, 12, 0.14 * s, t * 1.4, r.global_position, 0.6 * s)
	VfxKit.shake(r, 0.1)


# ---------- Каст, выпуск, снаряд ----------

## Каст на герое: магический круг под ногами (два кольца рун крутятся навстречу), силы стекаются к рукам,
## сгусток в руках растёт, вверх бегут огоньки. Длится dur (время каста); прервали — VfxArchetypes.stop(узел).
static func _a_cast_gather(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	var hand: Vector3 = off + Vector3(0, h * 0.62, 0) + (P["dir"] as Vector3) * 0.4
	if not _circle(P, 1.45 * s, t + 0.6, "circle", 0.0, minf(0.5, t * 0.6)):
		VfxKit.decal(r, "rune", Color(_c(P, "a"), 1.0), g, 2.9 * s, t + 0.4, true, 0.2, 0.18, 0.5, 0.0, 0.1)
	VfxKit.decal(r, "glow", Color(_c(P, "a"), 0.45), g, 3.4 * s, t + 0.4, true, 0.3, 0.2)
	var gather := VfxKit.loop(r, {"amount": _n(P, 18), "life": 0.6, "color": _c(P, "c"),
		"color2": Color(_c(P, "a"), 0.0), "size": 0.3 * s, "speed": 0.3, "tex": "streak", "align": true,
		"shape": "sphere", "radius": 1.6 * s, "radial": -9.0, "orbit": 2.0, "dir": Vector3.UP, "spread": 180.0,
		"offset": hand})
	gather.set_meta("vfx_stop_at", t)
	var tw := gather.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(VfxKit.stop_loop.bind(gather))
	var core := VfxKit.orb(r, Color(_c(P, "a"), 0.95), 0.9 * s, t + 0.3, hand, 3.0)
	var grow := core.create_tween()
	grow.tween_property(core, "scale", Vector3.ONE * 1.4 * s, t).set_delay(0.3)
	VfxKit.flash(r, "star", Color(_c(P, "core"), 0.9), 0.9 * s, t + 0.3, true, hand, 0.6)
	if _rich(P):
		VfxKit.decal(r, "rune", Color(_c(P, "c"), 0.8), g, 1.8 * s, t + 0.4, true, 0.2, 0.18, -0.8, 0.0, 0.15)
		var rise := VfxKit.loop(r, {"amount": _n(P, 12), "life": 0.9, "color": _c(P, "b"),
			"color2": Color(_c(P, "a"), 0.0), "size": 0.32 * s, "speed": 1.8, "tex": "soft", "shape": "ring",
			"radius": 1.0 * s, "dir": Vector3.UP, "spread": 5.0, "curve": "twinkle", "offset": off + Vector3(0, 0.1, 0)})
		var tw3 := rise.create_tween()
		tw3.tween_interval(t)
		tw3.tween_callback(VfxKit.stop_loop.bind(rise))
		if t >= 0.6:
			VfxKit.helix(r, Color(_c(P, "a"), 0.7), g, 0.8 * s, h * 0.9, t, 1.2, 0.08)


## Выпуск силы на герое (мгновенное умение, конец каста): вспышка у рук, кольцо-толчок, выброс искр вперёд.
static func _a_release(P: Dictionary) -> void:
	var r: Node3D = P["root"]
	var s := float(P["s"])
	var t := float(P["dur"])
	var g := _local_ground(P)
	var off := g - r.global_position
	var h := float(P["h"])
	var d: Vector3 = P["dir"]
	var hand := off + Vector3(0, h * 0.62, 0) + d * 0.45
	VfxKit.flash(r, "star", _c(P, "core"), 1.7 * s, t * 0.45, true, hand, 0.15)
	VfxKit.flash(r, "glow", Color(_c(P, "a"), 0.85), 2.2 * s, t * 0.55, true, hand)
	VfxKit.torus(r, Color(_c(P, "a"), 0.8), 0.8 * s, t * 0.5, hand, true, Vector3(PI / 2.0, atan2(d.x, d.z), 0), 0.5)
	_streaks(P, 14, 0.3 * s, 6.0 * s, t * 0.5, hand, d, 30.0, 0.0)
	if _rich(P):
		VfxKit.decal(r, "ring", Color(_c(P, "a"), 0.85), g, 2.4 * s, t * 0.6, true)
		_circle(P, 1.4 * s, t * 0.9, "ripple", 0.0, 0.1)
		VfxKit.particles(r, {"amount": _n(P, 10), "life": t * 0.6, "color": _c(P, "c"), "color2": Color(_c(P, "a"), 0.0),
			"size": 0.2 * s, "speed": 4.0 * s, "tex": "star", "dir": d, "spread": 35.0, "offset": hand,
			"curve": "twinkle"})


## Остановить эффект каста (прервали каст): постоянные частицы гаснут, картинки тают.
static func stop(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	for n in root.find_children("*", "CPUParticles3D", true, false):
		VfxKit.stop_loop(n)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE * 0.01, 0.2)
	t.tween_callback(root.queue_free)


## Одеть снаряд node (Projectile, размер size) в вид стихии el: сияющее ядро, ореол, частицы своего вида и след-лента
## (VfxTrail) за ним. q — качество.
static func dress_projectile(node: Node3D, el: String, size: float, q: int, tint: Color = Color(0, 0, 0, 0)) -> void:
	var pal := palette(el, tint)
	var core: Color = pal["core"]
	var a: Color = pal["a"]
	var b: Color = pal["b"]
	var c: Color = pal["c"]
	var qm := float(QMUL[clampi(q, 0, 2)])
	var n := func(x: float) -> int: return maxi(1, int(roundf(x * qm)))
	VfxKit.orb(node, Color(a, 0.95), 0.9 * size, 9.0, Vector3.ZERO, 6.0)
	VfxKit.flash(node, "glow", Color(a, 0.55), 2.0 * size, 9.0, true, Vector3.ZERO, 1.0)
	VfxKit.trail(node, Color(a, 0.9), 0.22 * size, 0.28 if q >= 1 else 0.18)
	if q >= 2:
		VfxKit.trail(node, Color(core, 0.9), 0.08 * size, 0.18)
	match el:
		"fire":
			VfxKit.flash(node, "flame", Color(a, 1.0), 1.1 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(18), "life": 0.45, "color": a, "color2": Color(b, 0.0), "size": 0.55 * size,
				"speed": 0.6, "tex": "flame", "gravity": Vector3(0, 2.5, 0), "curve": "grow", "radius": 0.1})
			VfxKit.loop(node, {"amount": n.call(10), "life": 0.6, "color": c, "size": 0.12 * size, "speed": 0.8,
				"tex": "star", "gravity": Vector3(0, -2.0, 0), "curve": "twinkle"})
		"ice":
			var sh := VfxKit._mi(node, VfxKit.shard_mesh(), VfxKit.glow_particle_mat())
			sh.scale = Vector3(0.45, 0.85, 0.45) * size
			sh.rotation.x = PI / 2.0
			var tw := sh.create_tween().set_loops()
			tw.tween_property(sh, "rotation:y", TAU, 0.4).from(0.0)
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.5, "color": core, "size": 0.16 * size, "speed": 0.4,
				"tex": "snow", "spin": 200.0, "curve": "twinkle"})
		"earth":
			var rk := VfxKit._mi(node, VfxKit.rock_mesh(), Util.mat(a))
			rk.scale = Vector3.ONE * 0.5 * size
			var tw2 := rk.create_tween().set_loops()
			tw2.tween_property(rk, "rotation", Vector3(TAU, TAU * 0.5, 0), 0.6).from(Vector3.ZERO)
			VfxKit.loop(node, {"amount": n.call(10), "life": 0.6, "color": pal["smoke"], "size": 0.45 * size,
				"speed": 0.3, "tex": "smoke", "add": false, "curve": "grow"})
		"dark", "emerald":
			var dc := VfxKit._mi(node, Vfx._unit_sphere(), VfxKit.fx(pal["core"] if el == "dark" else Color(0.02, 0.1, 0.07, 0.9),
				"white", false, "plain"))
			dc.scale = Vector3.ONE * 0.18 * size
			var sw := VfxKit.flash(node, "swirl", Color(a, 1.0), 1.2 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.spin(sw, -18.0, 9.0)
			VfxKit.loop(node, {"amount": n.call(14), "life": 0.55, "color": a, "color2": Color(c, 0.0), "size": 0.34 * size,
				"speed": 0.4, "tex": "soft", "curve": "shrink"})
		"storm":
			VfxKit.flash(node, "star", Color(core, 1.0), 1.1 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(16), "life": 0.25, "color": c, "color2": Color(a, 0.0), "size": 0.3 * size,
				"speed": 3.0, "tex": "streak", "align": true, "radius": 0.1})
		"water", "poison", "blood":
			var bl := VfxKit._mi(node, Vfx._unit_sphere(), VfxKit.fx(Color(a, 0.8), "white", true, "shell"))
			bl.scale = Vector3.ONE * 0.24 * size
			VfxKit.loop(node, {"amount": n.call(12), "life": 0.5, "color": c, "color2": Color(b, 0.0), "size": 0.2 * size,
				"speed": 0.8, "tex": "drop", "gravity": Vector3(0, -5.0, 0), "align": true})
		"wind":
			var arcp := Node3D.new()
			node.add_child(arcp)
			var am := VfxKit._mi(arcp, VfxKit.crescent_mesh(4.0, 0.3), VfxKit.fx(Color(a, 0.95), "slash", true, "slash"))
			am.scale = Vector3.ONE * 0.6 * size
			var tw4 := arcp.create_tween().set_loops()
			tw4.tween_property(arcp, "rotation:y", TAU, 0.3).from(0.0)
			VfxKit.loop(node, {"amount": n.call(10), "life": 0.4, "color": c, "size": 0.3 * size, "speed": 0.5,
				"tex": "streak", "align": true})
		_:
			VfxKit.flash(node, "star", Color(core, 1.0), 1.0 * size, 9.0, true, Vector3.ZERO, 1.0)
			VfxKit.loop(node, {"amount": n.call(14), "life": 0.45, "color": a, "color2": Color(b, 0.0), "size": 0.24 * size,
				"speed": 0.3, "tex": "star", "curve": "twinkle"})
