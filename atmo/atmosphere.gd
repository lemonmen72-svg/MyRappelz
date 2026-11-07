class_name Atmosphere
extends Node
## Атмосфера мира (0.46, задача Максима 07.11): смена дня и ночи (WorldClock: сутки 24 мин), погода (Weather), небо
## (atmo/atmo_sky.gdshader), свет солнца и луны (один DirectionalLight3D: днём — солнце, ночью — луна; на заре
## тёплый), окружение (ambient), туман (цвет и плотность по времени и погоде), дождь (RainFx), молнии, общие
## параметры шейдеров (shader globals: atmo_night, atmo_wet, atmo_rain, atmo_flash, atmo_sun_dir, atmo_sun_color,
## atmo_sky_color, atmo_fog). Ставит его мир (IslandWorld.setup_atmosphere, DungeonWorld — подземный вариант:
## вечная «ночь» для огней, без неба и дождя). Погода и свет меняются плавно (SMOOTH с). Настройки «Графика»: дождь —
## по доле частиц (Quality.particles), ночные огни — NightLights.
##
## Значения сейчас — current (последний поставленный узел): night() 0…1 (огни и кристаллы ярче), wet(), rain(),
## flash(); тесты — tick(dt) без кадров.

const SMOOTH := 5.0
## Свет днём (полдень), на заре, ночью (луна).
const SUN_NOON := Color(1.0, 0.95, 0.84)
const SUN_DUSK := Color(1.0, 0.6, 0.36)
const MOON_LIGHT := Color(0.55, 0.66, 0.98)
const SUN_ENERGY := 0.85
const MOON_ENERGY := 0.24
## Окружение (тени): день, заря, ночь.
const AMB_DAY := Color(0.72, 0.84, 1.0)
const AMB_DUSK := Color(0.86, 0.68, 0.72)
const AMB_NIGHT := Color(0.28, 0.36, 0.62)
const AMB_DAY_E := 0.55
const AMB_NIGHT_E := 0.42
## Туман: день, заря, ночь, дождь; плотность — база, дождь, туман погоды.
const FOG_DAY := Color(0.74, 0.86, 1.0)
const FOG_DUSK := Color(0.92, 0.66, 0.52)
const FOG_NIGHT := Color(0.10, 0.13, 0.24)
const FOG_RAIN := Color(0.52, 0.56, 0.62)
const FOG_BASE := 0.0045
const FOG_RAINY := 0.010
const FOG_MIST := 0.022
## Молнии в грозу: пауза между вспышками, с.
const FLASH_MIN := 5.0
const FLASH_MAX := 16.0

static var current: Atmosphere = null
## Глобальные параметры шейдеров (project.godot [shader_globals]): тип для проверки.
const GLOBALS := ["atmo_night", "atmo_wet", "atmo_rain", "atmo_flash", "atmo_sun_dir", "atmo_sun_color",
	"atmo_sky_color", "atmo_fog"]

var env: Environment
var light: DirectionalLight3D
var sky_mat: ShaderMaterial
var dungeon := false
var rain_fx: Node3D = null
## Сглаженная погода и время суток.
var w := {"cloud": 0.3, "rain": 0.0, "storm": 0.0, "fog": 0.0, "wet": 0.0, "wind": 0.3}
var hour := 12.0
var day := 1.0
var dusk_k := 0.0
var flash_k := 0.0
var lightnings := 0
## Последние значения глобальных параметров шейдеров (тесты: фиктивный рендер без окна их не хранит).
var globals := {}
var _first := true
var _cloud_off := Vector2.ZERO
var _flash_t := 8.0
var _rng := RandomNumberGenerator.new()
var _strike_cb: Callable


## Остров: свет, окружение и небо мира (WorldBuilder._build_environment).
func setup(env_: Environment, light_: DirectionalLight3D, sky_: ShaderMaterial) -> void:
	env = env_
	light = light_
	sky_mat = sky_
	dungeon = false
	current = self
	_rng.seed = 20261107
	name = "Atmosphere"


## Подземелье: неба нет, огни — как ночью, дождя нет.
func setup_dungeon(env_: Environment, light_: DirectionalLight3D) -> void:
	env = env_
	light = light_
	dungeon = true
	current = self
	name = "Atmosphere"


func _ready() -> void:
	tick(0.0)


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(delta: float) -> void:
	tick(delta)


## Шаг атмосферы на dt с (тесты зовут сами).
func tick(dt: float) -> void:
	if dungeon:
		_set_globals_dungeon()
		return
	hour = WorldClock.hour()
	var target := Weather.sample(hour, WorldClock.day_index())
	var k := 1.0 if _first else clampf(dt / SMOOTH, 0.0, 1.0)
	_first = false
	for key in ["cloud", "rain", "storm", "fog", "wet", "wind"]:
		w[key] = lerpf(float(w[key]), float(target[key]), k)
	w["state"] = target["state"]
	day = WorldClock.daylight_at(hour)
	dusk_k = WorldClock.dusk_at(hour)
	_cloud_off += Vector2(1.0, 0.35) * dt * (0.004 + 0.02 * float(w["wind"]))
	_tick_flash(dt)
	_apply()


func _tick_flash(dt: float) -> void:
	flash_k = maxf(0.0, flash_k - dt * 3.5)
	if float(w["storm"]) < 0.4:
		_flash_t = maxf(_flash_t, FLASH_MIN)
		return
	_flash_t -= dt
	if _flash_t <= 0.0:
		_flash_t = _rng.randf_range(FLASH_MIN, FLASH_MAX)
		flash_k = 1.0
		lightnings += 1
		if _strike_cb.is_valid():
			_strike_cb.call()


## Молния: вызывать cb при каждой вспышке (IslandAtmo — удар вдали).
func on_strike(cb: Callable) -> void:
	_strike_cb = cb


func _apply() -> void:
	var sun := WorldClock.sun_dir_at(hour)
	var moon := WorldClock.moon_dir_at(hour)
	var cloud := float(w["cloud"])
	var rain_v := float(w["rain"])
	var fog_v := float(w["fog"])
	# Свет: днём солнце, ночью луна — один свет, направление меняется, когда его почти не видно
	var sun_side := day > 0.12
	var dir := sun if sun_side else moon
	var dim := 1.0 - cloud * 0.45 - rain_v * 0.2
	var sun_col := SUN_NOON.lerp(SUN_DUSK, dusk_k)
	var energy := 0.0
	var lcol := MOON_LIGHT
	if sun_side:
		energy = SUN_ENERGY * smoothstep(0.12, 0.45, day) * dim
		lcol = sun_col
	else:
		energy = MOON_ENERGY * smoothstep(0.88, 0.6, day) * (1.0 - cloud * 0.6)
	energy += flash_k * 1.4
	if light != null:
		light.light_color = lcol.lerp(Color(0.85, 0.9, 1.0), flash_k)
		light.light_energy = energy
		if dir.y > 0.02:
			var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
			light.global_transform = Transform3D(Basis.looking_at(-dir, up), light.global_position)
	# Окружение: голубые тени днём, розоватые на заре, синие ночью; облака и дождь — серее
	var amb := AMB_NIGHT.lerp(AMB_DAY, day).lerp(AMB_DUSK, dusk_k * 0.6)
	amb = amb.lerp(Color(0.6, 0.64, 0.7), rain_v * 0.5)
	var amb_e := lerpf(AMB_NIGHT_E, AMB_DAY_E, day) * (1.0 - rain_v * 0.15) + flash_k * 0.6
	var fog_col := FOG_NIGHT.lerp(FOG_DAY, day).lerp(FOG_DUSK, dusk_k * 0.7).lerp(FOG_RAIN * lerpf(0.35, 1.0, day), rain_v * 0.8)
	var fog_d := FOG_BASE + FOG_RAINY * rain_v + FOG_MIST * fog_v
	if env != null:
		env.ambient_light_color = amb
		env.ambient_light_energy = amb_e
		env.fog_light_color = fog_col
		env.fog_density = fog_d
	if sky_mat != null:
		sky_mat.set_shader_parameter("sun_dir", sun)
		sky_mat.set_shader_parameter("moon_dir", moon)
		sky_mat.set_shader_parameter("daylight", day)
		sky_mat.set_shader_parameter("dusk", dusk_k)
		sky_mat.set_shader_parameter("cloud_cover", cloud)
		sky_mat.set_shader_parameter("rain", rain_v)
		sky_mat.set_shader_parameter("flash", flash_k)
		sky_mat.set_shader_parameter("cloud_offset", _cloud_off)
		sky_mat.set_shader_parameter("moon_phase", fposmod(float(WorldClock.day_index()) / 8.0, 1.0))
	_set_globals(sun if sun_side else moon, lcol * energy, fog_col)


func _set_globals(dir: Vector3, col: Color, fog_col: Color) -> void:
	_g("atmo_night", 1.0 - day)
	_g("atmo_wet", float(w["wet"]))
	_g("atmo_rain", float(w["rain"]))
	_g("atmo_flash", flash_k)
	_g("atmo_sun_dir", dir)
	_g("atmo_sun_color", col)
	_g("atmo_sky_color", fog_col)
	_g("atmo_fog", float(w["fog"]))


func _set_globals_dungeon() -> void:
	_g("atmo_night", 1.0)
	_g("atmo_wet", 0.0)
	_g("atmo_rain", 0.0)
	_g("atmo_flash", 0.0)
	_g("atmo_fog", 0.0)


func _g(name_: String, v: Variant) -> void:
	globals[name_] = v
	RenderingServer.global_shader_parameter_set(name_, v)


# ---------- Для огней, кристаллов, воды ----------

## Насколько ночь (0…1; в подземелье — 1, без атмосферы — по часам мира).
static func night() -> float:
	if current != null and is_instance_valid(current):
		return 1.0 if current.dungeon else 1.0 - current.day
	return WorldClock.night()


static func rain() -> float:
	return float(current.w["rain"]) if current != null and is_instance_valid(current) and not current.dungeon else 0.0


static func wet() -> float:
	return float(current.w["wet"]) if current != null and is_instance_valid(current) and not current.dungeon else 0.0


static func fog() -> float:
	return float(current.w["fog"]) if current != null and is_instance_valid(current) and not current.dungeon else 0.0


## Строка для админ-панели: «14:35 · День · Ясно».
static func status_text() -> String:
	var st := Weather.state_name(String(Weather.now().get("state", "clear")))
	return "%s · %s · %s" % [WorldClock.clock_text(), WorldClock.phase_name(), st]
