class_name VfxMat
extends ShaderMaterial
## Материал эффекта (VFX 2.0): шейдер vfx_add / vfx_mix (vfx/vfx_common.gdshaderinc) с параметрами «вида» (LOOKS).
## albedo_color — как у StandardMaterial3D (цвет и прозрачность), его можно твинить ("albedo_color:a").

const ADD := preload("res://vfx/vfx_add.gdshader")
const MIX := preload("res://vfx/vfx_mix.gdshader")

## Виды: шум, ядро, яркость. Ключи — параметры шейдера.
const LOOKS := {
	"plain": {},
	# Пламя: шум бежит вверх, края рвутся, ядро раскалено, частица догорает
	"fire": {"noise_amt": 0.9, "noise_scale": Vector2(1.3, 1.1), "scroll": Vector2(0.05, 1.3), "distort": 0.2,
		"core_amt": 0.85, "hdr": 1.7, "age_dissolve": 0.55, "soft": 0.14, "edge": 0.6},
	# Энергия: мягкий шум, светлое ядро
	"energy": {"noise_amt": 0.45, "noise_scale": Vector2(1.6, 1.6), "scroll": Vector2(0.15, -0.5), "distort": 0.08,
		"core_amt": 0.7, "hdr": 1.6, "soft": 0.18},
	# Искры и звёзды: чисто и ярко
	"spark": {"core_amt": 0.6, "hdr": 2.0},
	# Дым: клубится и распадается к концу жизни
	"smoke": {"noise_amt": 0.75, "noise_scale": Vector2(1.2, 1.2), "scroll": Vector2(0.06, 0.25), "distort": 0.16,
		"age_dissolve": 0.5, "soft": 0.22},
	# Магический круг: шум по кругу, кромка, мерцание
	"magic": {"noise_amt": 0.25, "polar": 1.0, "twist": 0.6, "noise_scale": Vector2(3.0, 1.5), "scroll": Vector2(0.12, 0.0),
		"core_amt": 0.6, "hdr": 1.8, "soft": 0.1, "pulse": 5.0},
	# Волна на земле: рваное кольцо, бежит по кругу
	"wave": {"noise_amt": 0.6, "polar": 1.0, "twist": 0.0, "noise_scale": Vector2(4.0, 2.0), "scroll": Vector2(0.2, -0.4),
		"distort": 0.05, "core_amt": 0.7, "hdr": 1.7, "soft": 0.15},
	# Трещины: раскалённая середина
	"lava": {"noise_amt": 0.35, "noise_scale": Vector2(2.0, 2.0), "scroll": Vector2(0.0, 0.1), "core_amt": 0.9,
		"hdr": 1.8, "soft": 0.1, "pulse": 3.0},
	# Вихрь и спираль: закрутка
	"swirl": {"noise_amt": 0.5, "polar": 1.0, "twist": 1.4, "noise_scale": Vector2(2.0, 1.0), "scroll": Vector2(-0.4, 0.0),
		"core_amt": 0.6, "hdr": 1.6, "distort": 0.06},
	# Вода и капли: блик и рябь
	"water": {"noise_amt": 0.4, "noise_scale": Vector2(1.5, 1.5), "scroll": Vector2(0.1, 0.4), "distort": 0.1,
		"core_amt": 0.55, "hdr": 1.4},
	# Оболочка (щит, сфера взрыва): светятся края, по поверхности бежит энергия
	"shell": {"fresnel": 1.0, "noise_amt": 0.35, "noise_scale": Vector2(3.0, 2.0), "scroll": Vector2(0.25, -0.3),
		"core_amt": 0.5, "hdr": 1.6, "soft": 0.2},
	# Ядро взрыва (сфера): плотное, раскалённое, с краями
	"fireball": {"fresnel": 0.4, "noise_amt": 0.6, "noise_scale": Vector2(2.5, 2.5), "scroll": Vector2(0.1, 0.8),
		"distort": 0.1, "core_amt": 1.0, "hdr": 1.9, "soft": 0.25},
	# Луч и столб: шум бежит вдоль, края мягкие
	"beam": {"fresnel": 0.6, "noise_amt": 0.5, "noise_scale": Vector2(2.0, 1.2), "scroll": Vector2(0.0, -2.0),
		"core_amt": 0.8, "hdr": 2.0, "soft": 0.15},
	# Росчерк клинка: прожилки вдоль дуги
	"slash": {"noise_amt": 0.4, "noise_scale": Vector2(0.8, 5.0), "scroll": Vector2(-1.5, 0.0), "core_amt": 0.8,
		"hdr": 2.0, "soft": 0.1},
	# След снаряда и молния: прожилки вдоль
	"trail": {"noise_amt": 0.5, "noise_scale": Vector2(1.0, 3.0), "scroll": Vector2(-3.0, 0.0), "distort": 0.05,
		"core_amt": 0.8, "hdr": 1.9, "soft": 0.12},
	"bolt": {"noise_amt": 0.25, "noise_scale": Vector2(4.0, 1.0), "scroll": Vector2(-6.0, 0.0), "core_amt": 1.0,
		"hdr": 2.4, "soft": 0.08, "pulse": 40.0},
}

static var _noise_tex: Texture2D = null
static var _cell_tex: Texture2D = null

var albedo_color: Color = Color.WHITE:
	set(v):
		albedo_color = v
		set_shader_parameter("tint", v)


## Новый материал: цвет c, маска (текстура формы) tex, сложение цветов add, вид look (LOOKS или словарь),
## поворот к камере billboard (0–3), ядро core (по умолчанию — светлее c), seed — разброс шума.
static func make(c: Color, tex: Texture2D, add: bool, look: Variant = "plain", billboard: int = 0,
		core: Color = Color(0, 0, 0, 0), seed_v: float = 0.0) -> VfxMat:
	var m := VfxMat.new()
	m.shader = ADD if add else MIX
	m.set_shader_parameter("mask", tex if tex != null else VfxKit.tex("white"))
	var lk: Dictionary = look if look is Dictionary else LOOKS.get(String(look), {})
	m.set_shader_parameter("noise", cell_noise() if bool(lk.get("cell", false)) else fbm_noise())
	for k in lk:
		if String(k) != "cell":
			m.set_shader_parameter(String(k), lk[k])
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("core_color", core if core.a > 0.0 else Color(c.lightened(0.6), 1.0))
	m.set_shader_parameter("seed", seed_v if seed_v != 0.0 else randf() * 10.0)
	m.albedo_color = c
	return m


## Плавный бесшовный шум 128×128 (FastNoiseLite, в C++ — без задержки).
static func fbm_noise() -> Texture2D:
	if _noise_tex == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.seed = 1337
		fn.frequency = 0.035
		fn.fractal_type = FastNoiseLite.FRACTAL_FBM
		fn.fractal_octaves = 4
		_noise_tex = _to_tex(fn.get_seamless_image(128, 128))
	return _noise_tex


## Ячеистый шум (прожилки: лёд, молнии, трещины энергии).
static func cell_noise() -> Texture2D:
	if _cell_tex == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_CELLULAR
		fn.seed = 4242
		fn.frequency = 0.05
		fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		fn.fractal_type = FastNoiseLite.FRACTAL_NONE
		_cell_tex = _to_tex(fn.get_seamless_image(128, 128, true))
	return _cell_tex


static func _to_tex(img: Image) -> Texture2D:
	if img == null:
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 1.0))
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
