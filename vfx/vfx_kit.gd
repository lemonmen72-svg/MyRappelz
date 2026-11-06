class_name VfxKit
extends RefCounted
## Слои генератора эффектов (docs/vfx/VFX_ARCHITECTURE.md, VFX 2.0): маски-текстуры, рисуемые кодом, меши и
## строительные блоки, из которых VfxArchetypes собирают эффекты. Материал всех слоёв — свой шейдер VfxMat
## (vfx/vfx_common.gdshaderinc): «живой» шум (пламя рвётся и бежит вверх, энергия переливается, дым клубится),
## раскалённое ядро, растворение, свечение краёв, росчерк клинка, бегущий по дуге. Всё — штатный Godot 4.3,
## одинаково в Mobile (Vulkan) и Compatibility. Эффект — узел Node3D в группе "vfx" (Vfx._root), удаляет себя сам.
## Число частиц — уже с учётом качества (передаёт сборщик).

static var _tex := {}
static var _mesh := {}
static var _pmat := {}
static var _imgs := {}
static var _lock := Mutex.new()
static var _task := -1
## Сколько кратких огней (OmniLight3D) эффектов сейчас горит — не больше MAX_LIGHTS.
static var lights_alive := 0
const MAX_LIGHTS := 3

## Маски, которые рисует этот файл (остальные — Vfx.tex: dot, plus, heart, puff).
const OWN := ["soft", "flame", "smoke", "sigil", "rune", "claw", "streak", "drop", "snow", "crack", "wave", "shard",
	"swirl", "white", "star", "ring", "slash", "beam", "trail", "pillar", "vgrad", "orb", "glow"]
const BIG := {"sigil": 192, "rune": 192, "crack": 128, "swirl": 128, "claw": 128, "wave": 128, "slash": 128,
	"ring": 128, "star": 96}

## Вид материала по маске (VfxMat.LOOKS).
const LOOK_OF := {"flame": "fire", "smoke": "smoke", "puff": "smoke", "soft": "energy", "orb": "energy",
	"glow": "energy", "dot": "energy", "rune": "magic", "sigil": "magic", "wave": "wave", "ring": "wave",
	"crack": "lava", "swirl": "swirl", "drop": "water", "claw": "slash", "slash": "slash", "beam": "trail",
	"trail": "trail", "pillar": "beam", "vgrad": "beam"}


# ---------- Текстуры ----------

## Маска слоя (белая, форма — в альфе): "soft" (мягкое пятно), "flame" (язык пламени), "smoke" (клуб дыма),
## "sigil" (знак секты: глаз и щупальца-спирали), "rune" (магический круг: кольца, письмена, гексаграмма),
## "claw" (три следа когтей), "streak" (росчерк), "drop" (капля), "snow" (снежинка), "crack" (трещины),
## "wave" (рваное кольцо волны), "shard" (осколок), "swirl" (вихрь), "star" (искра с лучами), "ring" (тонкое
## кольцо со свечением), "slash" (поперечник росчерка клинка: яркая кромка, мягкий хвост внутрь), "beam" (луч:
## яркая ось), "trail" (след: ярко у головы, тает к хвосту), "pillar" (столб: снизу ярко, вверх тает), "vgrad"
## (стена волны: яркий низ), "orb" (шар с ядром), "glow" (широкий ореол), "white".
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	if not kind in OWN:
		return Vfx.tex(kind)
	var img: Image = null
	_lock.lock()
	if _imgs.has(kind):
		img = _imgs[kind]
		_imgs.erase(kind)
	_lock.unlock()
	if img == null:
		img = _make_image(kind)
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Картинка маски (можно в фоновом потоке: только чистые функции).
static func _make_image(kind: String) -> Image:
	var n: int = BIG.get(kind, 64)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(_alpha(kind, u, v), 0.0, 1.0)))
	img.generate_mipmaps()
	return img


## Фоновый поток: все маски, которых ещё нет (крупные знаки рисуются кодом 0.2–0.6 с — не на главном потоке).
static func _gen_all(kinds: Array) -> void:
	for k in kinds:
		var img := _make_image(String(k))
		_lock.lock()
		_imgs[String(k)] = img
		_lock.unlock()


static func _alpha(kind: String, u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	var ang := atan2(v, u)
	var yy := (v + 1.0) * 0.5
	var xx := (u + 1.0) * 0.5
	match kind:
		"white":
			return 1.0
		"soft":
			var k := clampf(1.0 - d, 0.0, 1.0)
			return k * k * (3.0 - 2.0 * k)
		"orb":
			var k1 := clampf(1.0 - d, 0.0, 1.0)
			return clampf(k1 * k1 * 0.75 + clampf(1.0 - d * 2.2, 0.0, 1.0), 0.0, 1.0)
		"glow":
			return pow(clampf(1.0 - d, 0.0, 1.0), 2.6)
		"star":
			# Искра: ядро, четыре длинных тонких луча, четыре коротких косых, ореол
			var core := pow(clampf(1.0 - d * 3.2, 0.0, 1.0), 1.5)
			var ray := maxf(exp(-u * u * 900.0) * pow(clampf(1.0 - absf(v), 0.0, 1.0), 1.4),
				exp(-v * v * 900.0) * pow(clampf(1.0 - absf(u), 0.0, 1.0), 1.4))
			var du := (u + v) * 0.7071
			var dv := (u - v) * 0.7071
			var ray2 := maxf(exp(-du * du * 1400.0) * pow(clampf(1.0 - absf(dv) * 1.8, 0.0, 1.0), 2.0),
				exp(-dv * dv * 1400.0) * pow(clampf(1.0 - absf(du) * 1.8, 0.0, 1.0), 2.0)) * 0.6
			var halo := pow(clampf(1.0 - d, 0.0, 1.0), 3.0) * 0.35
			return maxf(maxf(core, ray), maxf(ray2, halo))
		"ring":
			var e := exp(-pow((d - 0.86) / 0.035, 2.0))
			var gl := exp(-pow((d - 0.84) / 0.14, 2.0)) * 0.45
			return maxf(e, gl) * clampf((1.0 - d) * 12.0, 0.0, 1.0)
		"flame":
			# Капля острием вверх (v < 0 — верх картинки): широкое основание, острый язык
			var w := 0.15 + 0.75 * pow(yy, 0.8)
			var side := clampf(1.0 - absf(u) / maxf(w, 0.05), 0.0, 1.0)
			var bottom := clampf((1.0 - v) * 2.5, 0.0, 1.0)
			return pow(side, 1.2) * bottom * (0.5 + 0.5 * yy)
		"smoke":
			var nn := _noise(u * 2.6, v * 2.6, 7) * 0.5 + _noise(u * 5.2, v * 5.2, 13) * 0.25
			var k2 := clampf(1.0 - d * (1.0 + nn * 0.6), 0.0, 1.0)
			return k2 * k2 * 0.9
		"sigil":
			# Внешнее кольцо, внутреннее кольцо, глаз в центре, шесть щупалец-спиралей между кольцами
			var a := 0.0
			a = maxf(a, _band(d, 0.92, 0.03))
			a = maxf(a, _band(d, 0.86, 0.012) * 0.8)
			a = maxf(a, _band(d, 0.62, 0.02) * 0.8)
			a = maxf(a, _glyphs(d, ang, 0.885, 0.035, 48, 11) * 0.8)
			a = maxf(a, _eye(u, v))
			if d < 0.28 or d > 0.88:
				return a
			for i in 6:
				var base := TAU * float(i) / 6.0
				for s in 9:
					var t := float(s) / 8.0
					var r := 0.34 + 0.48 * t
					var aa := base + t * 1.6
					var px := cos(aa) * r
					var py := sin(aa) * r
					var dd := sqrt((u - px) * (u - px) + (v - py) * (v - py))
					a = maxf(a, clampf(1.0 - dd / (0.05 - 0.025 * t), 0.0, 1.0))
			return a
		"rune":
			# Магический круг: двойное внешнее кольцо с письменами, гексаграмма, внутреннее кольцо, точки
			var a2 := maxf(_band(d, 0.95, 0.022), _band(d, 0.78, 0.016) * 0.95)
			a2 = maxf(a2, _glyphs(d, ang, 0.865, 0.055, 36, 3))
			a2 = maxf(a2, _band(d, 0.36, 0.016) * 0.85)
			a2 = maxf(a2, _band(d, 0.18, 0.012) * 0.6)
			a2 = maxf(a2, _glyphs(d, ang, 0.27, 0.05, 16, 7) * 0.7)
			for i in 3:
				var a0 := TAU * float(i) / 3.0 - PI / 2.0
				var a1 := a0 + TAU / 3.0
				var p0 := Vector2(cos(a0), sin(a0)) * 0.76
				var p1 := Vector2(cos(a1), sin(a1)) * 0.76
				a2 = maxf(a2, _seg(Vector2(u, v), p0, p1, 0.016) * 0.9)
				var q0 := Vector2(cos(a0 + PI), sin(a0 + PI)) * 0.76
				var q1 := Vector2(cos(a1 + PI), sin(a1 + PI)) * 0.76
				a2 = maxf(a2, _seg(Vector2(u, v), q0, q1, 0.016) * 0.9)
			for i in 6:
				var ap := TAU * float(i) / 6.0 + PI / 6.0
				var pp := Vector2(cos(ap), sin(ap)) * 0.76
				var dp := Vector2(u, v).distance_to(pp)
				a2 = maxf(a2, clampf(1.0 - absf(dp - 0.05) / 0.012, 0.0, 1.0))
			a2 = maxf(a2, exp(-pow(d / 0.6, 2.0)) * 0.12)
			return a2
		"claw":
			var a3 := 0.0
			for i in 3:
				var off := (float(i) - 1.0) * 0.38
				var p0 := Vector2(-0.75 + off * 0.4, -0.8 + off)
				var p1 := Vector2(0.75 + off * 0.4, 0.8 + off)
				var t2 := clampf((Vector2(u, v) - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
				var w2 := 0.08 * sin(PI * t2)
				a3 = maxf(a3, _seg(Vector2(u, v), p0, p1, maxf(w2, 0.008)))
				a3 = maxf(a3, _seg(Vector2(u, v), p0, p1, maxf(w2 * 3.0, 0.02)) * 0.35)
			return a3
		"streak":
			var k3 := clampf(1.0 - absf(v) / 0.25, 0.0, 1.0)
			var e2 := clampf(1.0 - absf(u), 0.0, 1.0)
			return pow(k3, 1.6) * pow(e2, 0.5)
		"drop":
			var w3 := 0.08 + 0.5 * sin(PI * clampf(yy * 1.05, 0.0, 1.0)) * yy
			var k4 := clampf(1.0 - absf(u) / maxf(w3, 0.03), 0.0, 1.0)
			return pow(k4, 0.8) * clampf((0.95 - v) * 6.0, 0.0, 1.0) * clampf((v + 0.95) * 4.0, 0.0, 1.0)
		"snow":
			var arm := clampf(1.0 - absf(sin(ang * 3.0)) * d * 5.0, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0)
			return maxf(arm, clampf(1.0 - d * 4.0, 0.0, 1.0))
		"crack":
			var a4 := 0.0
			for i in 9:
				var aa2 := TAU * float(i) / 9.0 + _noise(float(i), 0.5, 3) * 0.6
				var bend := _noise(float(i) * 3.1, d * 3.0, 5) * 0.45
				var da := absf(wrapf(ang - aa2 - bend * d, -PI, PI))
				var w4 := 0.07 * (1.0 - d) + 0.008
				a4 = maxf(a4, clampf(1.0 - da * d / w4, 0.0, 1.0) * clampf((0.95 - d) * 5.0, 0.0, 1.0)
					* clampf(d * 8.0, 0.0, 1.0))
			a4 = maxf(a4, clampf(1.0 - d * 5.0, 0.0, 1.0))
			return a4
		"wave":
			var k5 := clampf(1.0 - absf(d - 0.72) / 0.28, 0.0, 1.0)
			var rim := exp(-pow((d - 0.92) / 0.04, 2.0))
			return maxf(k5 * k5 * (3.0 - 2.0 * k5) * 0.85, rim) * clampf((1.0 - d) * 10.0, 0.0, 1.0)
		"shard":
			var dd2 := absf(u) / 0.45 + absf(v)
			return clampf((1.0 - dd2) * 5.0, 0.0, 1.0) * (0.7 + 0.3 * clampf(-v, 0.0, 1.0))
		"swirl":
			var arms := 0.0
			for i in 3:
				var target := fposmod(log(maxf(d, 0.01)) * 2.2 + float(i) * TAU / 3.0, TAU)
				var da2 := absf(wrapf(ang - target, -PI, PI))
				arms = maxf(arms, clampf(1.0 - da2 / 0.5, 0.0, 1.0))
			return arms * clampf((1.0 - d) * 3.0, 0.0, 1.0) * clampf(d * 4.0, 0.0, 1.0)
		"slash":
			# По UV.x — вдоль дуги, по UV.y — от внешней кромки (0) внутрь (1)
			var edge := exp(-pow((yy - 0.1) / 0.06, 2.0))
			var body := pow(clampf(1.0 - yy, 0.0, 1.0), 2.2) * 0.7
			var ends := clampf(xx * 14.0, 0.0, 1.0) * clampf((1.0 - xx) * 5.0, 0.0, 1.0)
			return maxf(edge, body) * ends
		"beam":
			var ax := exp(-pow(v / 0.36, 2.0)) * 0.75 + exp(-pow(v / 0.1, 2.0))
			return clampf(ax, 0.0, 1.0) * clampf((1.0 - absf(u)) * 20.0, 0.0, 1.0)
		"trail":
			var ax2 := exp(-pow(v / 0.4, 2.0)) * 0.7 + exp(-pow(v / 0.12, 2.0))
			return clampf(ax2, 0.0, 1.0) * pow(clampf(1.0 - xx, 0.0, 1.0), 1.3) * clampf(xx * 30.0, 0.0, 1.0)
		"pillar":
			return clampf(yy * 14.0, 0.0, 1.0) * pow(clampf(1.0 - yy, 0.0, 1.0), 0.8)
		"vgrad":
			return clampf(yy * 30.0, 0.0, 1.0) * pow(clampf(1.0 - yy, 0.0, 1.0), 2.4)
	return 0.0


## Пояс письмен по кругу: число знаков count, у каждого свой рисунок (черты, точки) — «магические руны».
static func _glyphs(d: float, ang: float, r: float, h: float, count: int, seed_v: int) -> float:
	if absf(d - r) > h * 0.5:
		return 0.0
	var a01 := fposmod(ang / TAU, 1.0) * float(count)
	var seg := int(floor(a01))
	var lx := a01 - float(seg)
	var ly := (d - (r - h * 0.5)) / h
	var hsh := absf(_hash(seg, seed_v, 17))
	var kind := int(hsh * 6.0) % 6
	var bar := func(x0: float, x1: float, y0: float, y1: float) -> float:
		return clampf(minf(minf(lx - x0, x1 - lx), minf(ly - y0, y1 - ly)) * 25.0, 0.0, 1.0)
	match kind:
		0:
			return bar.call(0.42, 0.58, 0.1, 0.9)
		1:
			return maxf(bar.call(0.25, 0.4, 0.1, 0.9), bar.call(0.6, 0.75, 0.1, 0.9))
		2:
			return maxf(bar.call(0.42, 0.58, 0.1, 0.9), bar.call(0.2, 0.8, 0.42, 0.58))
		3:
			return maxf(bar.call(0.2, 0.8, 0.1, 0.25), bar.call(0.42, 0.58, 0.1, 0.9))
		4:
			var dd := Vector2(lx - 0.5, (ly - 0.5) * 0.6).length()
			return clampf(1.0 - absf(dd - 0.22) / 0.07, 0.0, 1.0)
	return maxf(bar.call(0.2, 0.8, 0.75, 0.9), bar.call(0.3, 0.45, 0.1, 0.9))


## Глаз секты: веки-дуги и зрачок.
static func _eye(u: float, v: float) -> float:
	var lid_top := absf(v + 0.0 - (0.0 - 0.22 * (1.0 - u * u / 0.09))) if absf(u) < 0.3 else 9.0
	var lid_bot := absf(v - (0.22 * (1.0 - u * u / 0.09))) if absf(u) < 0.3 else 9.0
	var a := clampf(1.0 - minf(lid_top, lid_bot) / 0.025, 0.0, 1.0)
	var pupil := clampf(1.0 - sqrt(u * u + v * v) / 0.09, 0.0, 1.0)
	return maxf(a, clampf(pupil * 2.0, 0.0, 1.0))


static func _band(d: float, r: float, w: float) -> float:
	return clampf(1.0 - absf(d - r) / w, 0.0, 1.0)


static func _seg(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var dd := (p - (a + ab * t)).length()
	return clampf(1.0 - dd / w, 0.0, 1.0)


## Гладкий шум 2D по сетке (детерминированный, без FastNoiseLite): −1…1.
static func _noise(x: float, y: float, seed_v: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - float(xi)
	var fy := y - float(yi)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sy := fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(xi, yi, seed_v)
	var b := _hash(xi + 1, yi, seed_v)
	var c := _hash(xi, yi + 1, seed_v)
	var d := _hash(xi + 1, yi + 1, seed_v)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 2001) / 1000.0 - 1.0


# ---------- Меши ----------

## Осколок: вытянутая четырёхгранная призма (лёд, камень, кость), единичного размера.
static func shard_mesh() -> Mesh:
	if _mesh.has("shard"):
		return _mesh["shard"]
	var p := PrismMesh.new()
	p.size = Vector3(0.35, 1.0, 0.25)
	_mesh["shard"] = p
	return p


## Шип из земли: конус высотой 1, основание на y = 0.
static func spike_mesh() -> Mesh:
	if _mesh.has("spike"):
		return _mesh["spike"]
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	_mesh["spike"] = c
	return c


## Камешек: низкополигональная сфера.
static func rock_mesh() -> Mesh:
	if _mesh.has("rock"):
		return _mesh["rock"]
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.8
	s.radial_segments = 5
	s.rings = 3
	_mesh["rock"] = s
	return s


## Тор (кольцо-волна в пространстве): внутренний радиус 0.8, внешний 1.
static func torus_mesh() -> Mesh:
	if _mesh.has("torus"):
		return _mesh["torus"]
	var t := TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	_mesh["torus"] = t
	return t


## Длинная частица-росчерк (вдоль скорости): узкий квадрат 0.3 × 1.
static func long_quad() -> Mesh:
	if _mesh.has("long"):
		return _mesh["long"]
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 1.0)
	_mesh["long"] = q
	return q


## Открытая труба радиуса 1 от y = 0 до y = 1 (стена волны, столб, луч): UV.x — по кругу, UV.y — 0 внизу, 1 вверху.
## top — радиус верха (воронка вихря — больше 1).
static func wall_mesh(top: float = 1.0) -> Mesh:
	var key := "wall|%.2f" % top
	if _mesh.has(key):
		return _mesh[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var b0 := Vector3(cos(a0), 0.0, sin(a0))
		var b1 := Vector3(cos(a1), 0.0, sin(a1))
		var t0 := b0 * top + Vector3.UP
		var t1 := b1 * top + Vector3.UP
		var u0 := float(i) / float(n)
		var u1 := float(i + 1) / float(n)
		_tri(st, b0, Vector2(u0, 0.0), b1, Vector2(u1, 0.0), t1, Vector2(u1, 1.0))
		_tri(st, b0, Vector2(u0, 0.0), t1, Vector2(u1, 1.0), t0, Vector2(u0, 1.0))
	st.generate_normals()
	var m := st.commit()
	_mesh[key] = m
	return m


static func _tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


## Серп росчерка клинка в плоскости XZ радиусом 1 вокруг −Z на угол sweep (рад): UV.x — вдоль взмаха
## (0 — начало справа, 1 — конец слева), UV.y — от внешней кромки (0) внутрь (1); толщина width, к концам тоньше.
static func crescent_mesh(sweep: float, width: float) -> Mesh:
	var key := "cres|%.1f|%.2f" % [sweep, width]
	if _mesh.has(key):
		return _mesh[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := clampi(int(sweep * 12.0), 12, 64)
	for i in n:
		var k0 := float(i) / float(n)
		var k1 := float(i + 1) / float(n)
		var a0 := lerpf(sweep * 0.5, -sweep * 0.5, k0)
		var a1 := lerpf(sweep * 0.5, -sweep * 0.5, k1)
		var w0 := width * (0.25 + 0.75 * pow(sin(PI * clampf(k0 * 0.85 + 0.15, 0.0, 1.0)), 0.7))
		var w1 := width * (0.25 + 0.75 * pow(sin(PI * clampf(k1 * 0.85 + 0.15, 0.0, 1.0)), 0.7))
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		_tri(st, o0, Vector2(k0, 0.0), o1, Vector2(k1, 0.0), o0 * (1.0 - w0), Vector2(k0, 1.0))
		_tri(st, o1, Vector2(k1, 0.0), o1 * (1.0 - w1), Vector2(k1, 1.0), o0 * (1.0 - w0), Vector2(k0, 1.0))
	var m := st.commit()
	_mesh[key] = m
	return m


## Спираль-лента вокруг оси Y: радиус 1, от y = 0 до y = 1, turns оборотов, ширина ленты width (по вертикали);
## UV.x — вдоль ленты (0 — низ), UV.y — поперёк.
static func helix_mesh(turns: float, width: float) -> Mesh:
	var key := "helix|%.1f|%.2f" % [turns, width]
	if _mesh.has(key):
		return _mesh[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := clampi(int(turns * 32.0), 16, 96)
	for i in n:
		var k0 := float(i) / float(n)
		var k1 := float(i + 1) / float(n)
		var a0 := TAU * turns * k0
		var a1 := TAU * turns * k1
		var c0 := Vector3(cos(a0), k0, sin(a0))
		var c1 := Vector3(cos(a1), k1, sin(a1))
		var h := Vector3(0, width * 0.5, 0)
		_tri(st, c0 - h, Vector2(k0, 1.0), c1 - h, Vector2(k1, 1.0), c1 + h, Vector2(k1, 0.0))
		_tri(st, c0 - h, Vector2(k0, 1.0), c1 + h, Vector2(k1, 0.0), c0 + h, Vector2(k0, 0.0))
	var m := st.commit()
	_mesh[key] = m
	return m


# ---------- Материалы ----------

## Материал слоя: цвет c, маска kind, сложение цветов add, вид look ("" — по маске, LOOK_OF), поворот к камере
## billboard (0 — нет, 2 — картинка к камере), core — цвет ядра.
static func fx(c: Color, kind: String, add: bool = true, look: String = "", billboard: int = 0,
		core: Color = Color(0, 0, 0, 0)) -> VfxMat:
	var lk := look if look != "" else String(LOOK_OF.get(kind, "spark"))
	var m := VfxMat.make(c, tex(kind), add, lk, billboard, core)
	if not add:
		m.set_shader_parameter("hdr", 1.0)
		m.set_shader_parameter("core_amt", 0.35)
	return m


## Материал частиц (общий на маску): поворот к камере или вдоль скорости (align).
static func particle_mat(kind: String, add: bool, align: bool = false) -> VfxMat:
	var key := "%s|%s|%s" % [kind, add, align]
	if _pmat.has(key):
		return _pmat[key]
	var m := fx(Color.WHITE, kind, add, "", 3 if align else 1, Color(1, 1, 1, 1))
	# Цвет частицы — из её градиента: ядро светлее его же цвета
	m.set_shader_parameter("core_color", Color(1.0, 0.98, 0.92, 1.0))
	_pmat[key] = m
	return m


## Материал для меша частиц-осколков (камень, лёд): без освещения, цвет из градиента частиц.
static func solid_particle_mat(lit: bool) -> StandardMaterial3D:
	var key := "solid|%s" % lit
	if _pmat.has(key):
		return _pmat[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	if not lit:
		m.emission_enabled = false
	_pmat[key] = m
	return m


## Светящийся кристалл (лёд, кристаллы духа): сложение цветов, края светятся.
static func glow_particle_mat() -> VfxMat:
	if _pmat.has("glowmesh"):
		return _pmat["glowmesh"]
	var m := VfxMat.make(Color.WHITE, tex("white"), true, {"fresnel": 0.7, "core_amt": 0.6, "hdr": 1.8}, 0,
		Color(1, 1, 1, 1))
	_pmat["glowmesh"] = m
	return m


## Плавно менять параметр шейдера name материала m от a до b за time (в твине tw).
static func _param(tw: Tween, m: ShaderMaterial, name: String, a: float, b: float, time: float,
		delay: float = 0.0) -> void:
	m.set_shader_parameter(name, a)
	tw.tween_method(func(x: float) -> void:
		if is_instance_valid(m):
			m.set_shader_parameter(name, x), a, b, time).set_delay(delay)


# ---------- Строительные блоки ----------

static func _mi(root: Node3D, mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.material_override = m
	root.add_child(mi)
	return mi


## Частицы. o: amount, life, color (Color), color2 (конец, по умолчанию прозрачный color), size, speed, tex,
## add, mesh ("quad" | "shard" | "rock" | "spike" | "crystal"), lit (у меша — с освещением), dir, spread, gravity,
## damping, radius, shape ("sphere" | "ring" | "box" | "point"), box (Vector3), explosive, local, curve, align
## (по скорости — длинный росчерк), spin (град/с), radial (ускорение к центру < 0 / от центра), orbit (по кругу),
## hue (разброс оттенка 0…1), offset, delay, loop (непрерывно), randomness.
static func particles(root: Node3D, o: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, int(o.get("amount", 8)))
	p.lifetime = maxf(0.05, float(o.get("life", 0.6)))
	var loop_on := bool(o.get("loop", false))
	p.one_shot = not loop_on
	p.explosiveness = float(o.get("explosive", 0.0 if loop_on else 0.95))
	p.randomness = float(o.get("randomness", 0.3))
	p.local_coords = bool(o.get("local", false))
	var align := bool(o.get("align", false))
	var mesh_kind := String(o.get("mesh", "quad"))
	match mesh_kind:
		"shard", "crystal":
			p.mesh = shard_mesh()
		"rock":
			p.mesh = rock_mesh()
		"spike":
			p.mesh = spike_mesh()
		_:
			p.mesh = long_quad() if align else Vfx._quad()
	if mesh_kind == "quad":
		p.material_override = particle_mat(String(o.get("tex", "star")), bool(o.get("add", true)), align)
	elif mesh_kind == "crystal":
		p.material_override = glow_particle_mat()
	else:
		p.material_override = solid_particle_mat(bool(o.get("lit", false)))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 180.0))
	var speed := float(o.get("speed", 2.0))
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = o.get("gravity", Vector3.ZERO)
	var damp := float(o.get("damping", 0.0))
	p.damping_min = damp * 0.8
	p.damping_max = damp
	p.angle_min = 0.0
	p.angle_max = 360.0
	var spin_v := float(o.get("spin", 0.0))
	if spin_v != 0.0:
		p.angular_velocity_min = -spin_v
		p.angular_velocity_max = spin_v
	var size := float(o.get("size", 0.3))
	if align:
		size *= 1.8
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.scale_amount_curve = Vfx._curve(String(o.get("curve", "shrink")))
	p.particle_flag_align_y = align
	var radial := float(o.get("radial", 0.0))
	if radial != 0.0:
		p.radial_accel_min = radial * 0.8
		p.radial_accel_max = radial
	var orbit := float(o.get("orbit", 0.0))
	if orbit != 0.0:
		p.tangential_accel_min = orbit * 0.8
		p.tangential_accel_max = orbit
	var hue := float(o.get("hue", 0.0))
	if hue > 0.0:
		p.hue_variation_min = -hue
		p.hue_variation_max = hue
	var c: Color = o.get("color", Color.WHITE)
	var c2: Color = o.get("color2", Color(c, 0.0))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	g.colors = PackedColorArray([Color(c.lightened(0.6), c.a), Color(c.lightened(0.2), c.a), c, c2])
	p.color_ramp = g
	match String(o.get("shape", "sphere")):
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.05
			p.emission_ring_radius = float(o.get("radius", 0.5))
			p.emission_ring_inner_radius = float(o.get("radius", 0.5)) * 0.85
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = o.get("box", Vector3.ONE * 0.3)
		"point":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		_:
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(o.get("radius", 0.15))
	root.add_child(p)
	p.position = o.get("offset", Vector3.ZERO)
	var delay := float(o.get("delay", 0.0))
	if delay > 0.0:
		p.emitting = false
		var t := p.create_tween()
		t.tween_interval(delay)
		t.tween_callback(p.restart)
	else:
		p.emitting = true
	return p


## Вспышка-картинка к камере: выпрыгивает и тает. look — вид материала ("" — по маске).
static func flash(root: Node3D, kind: String, c: Color, size: float, time: float, add: bool = true,
		offset: Vector3 = Vector3.ZERO, start: float = 0.25, delay: float = 0.0, look: String = "") -> MeshInstance3D:
	var mi := _mi(root, Vfx._quad(), fx(c, kind, add, look, 2))
	var m: VfxMat = mi.material_override
	mi.position = offset
	mi.scale = Vector3.ONE * size * start
	var t := mi.create_tween().set_parallel(true)
	if delay > 0.0:
		mi.visible = false
		t.tween_callback(mi.show).set_delay(delay)
	t.tween_property(mi, "scale", Vector3.ONE * size, time * 0.6).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(delay + time * 0.4)
	return mi


## Повернуть картинку-вспышку mi (к камере) на turns оборотов за time.
static func spin(mi: MeshInstance3D, turns: float, time: float, from: float = 0.0) -> void:
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var t := mi.create_tween()
	_param(t, mi.material_override, "rot", from, from + TAU * turns, time)


## Плоская картинка на земле (кольцо, трещины, знак, лужа) в точке ground (мировые координаты): растёт от
## start × radius до radius за grow долю time, держится и тает. spin_t — оборотов за time.
static func decal(root: Node3D, kind: String, c: Color, ground: Vector3, radius: float, time: float,
		add: bool = false, start: float = 0.15, grow: float = 1.0, spin_t: float = 0.0, delay: float = 0.0,
		fade_in: float = 0.0, look: String = "") -> MeshInstance3D:
	var mi := _mi(root, Vfx._plane(), fx(c, kind, add, look))
	var m: VfxMat = mi.material_override
	mi.global_position = ground + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * radius * start * 0.5
	var t := mi.create_tween().set_parallel(true)
	if delay > 0.0:
		mi.visible = false
		t.tween_callback(mi.show).set_delay(delay)
	if fade_in > 0.0:
		var a := c.a
		m.albedo_color = Color(c, 0.0)
		t.tween_property(m, "albedo_color:a", a, time * fade_in).set_delay(delay)
	t.tween_property(mi, "scale", Vector3.ONE * radius * 0.5, time * grow).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)
	if spin_t != 0.0:
		t.tween_property(mi, "rotation:y", TAU * spin_t, time).set_delay(delay)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.45).set_delay(delay + time * 0.55)
	# Тает, растворяясь по шуму
	if kind in ["wave", "crack", "rune", "sigil", "soft", "smoke"]:
		_param(t, m, "dissolve", 0.0, 0.7, time * 0.45, delay + time * 0.55)
	return mi


## Расширяющаяся и тающая сфера: look "shell" — оболочка со светящимися краями (щит, волна), "fireball" —
## плотное раскалённое ядро взрыва, "plain" — ровная.
static func sphere(root: Node3D, c: Color, radius: float, time: float, offset: Vector3 = Vector3.ZERO,
		add: bool = false, start: float = 0.2, hold: float = 0.0, look: String = "shell") -> MeshInstance3D:
	var mi := _mi(root, Vfx._unit_sphere(), fx(c, "white", add, look))
	var m: VfxMat = mi.material_override
	mi.position = offset
	mi.scale = Vector3.ONE * radius * start
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time * (1.0 - hold)).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * (1.0 - hold) * 0.7).set_delay(time * hold + time * 0.3)
	_param(t, m, "dissolve", 0.0, 0.8, time * 0.5, time * hold + time * 0.5)
	return mi


## Кольцо-волна в пространстве (тор), лежит горизонтально или повёрнуто tilt; растёт до radius.
static func torus(root: Node3D, c: Color, radius: float, time: float, offset: Vector3 = Vector3.ZERO,
		add: bool = true, tilt: Vector3 = Vector3.ZERO, thick: float = 1.0) -> MeshInstance3D:
	var mi := _mi(root, torus_mesh(), fx(c, "white", add, "energy"))
	var m: VfxMat = mi.material_override
	m.set_shader_parameter("noise_scale", Vector2(6.0, 1.0))
	m.set_shader_parameter("scroll", Vector2(1.2, 0.0))
	mi.position = offset
	mi.rotation = tilt
	mi.scale = Vector3(radius * 0.2, thick * radius * 0.2, radius * 0.2)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3(radius, thick * 0.5, radius), time).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	_param(t, m, "dissolve", 0.0, 0.7, time * 0.5, time * 0.5)
	return mi


## Столб света от земли (ground) вверх: шум бежит вверх, края мягко светятся, к концу сужается.
static func pillar(root: Node3D, c: Color, ground: Vector3, radius: float, height: float, time: float,
		add: bool = true) -> MeshInstance3D:
	var mi := _mi(root, wall_mesh(), fx(c, "pillar", add, "beam"))
	var m: VfxMat = mi.material_override
	mi.global_position = ground
	mi.scale = Vector3(radius, 0.01, radius)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale:y", height, time * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "scale:x", radius * 0.12, time * 0.55).set_delay(time * 0.45).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	t.tween_property(mi, "scale:z", radius * 0.12, time * 0.55).set_delay(time * 0.45).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.5).set_delay(time * 0.5)
	return mi


## Стена ударной волны: открытое кольцо у земли, разлетается от start до radius, высота height тает к концу.
static func wall(root: Node3D, c: Color, ground: Vector3, radius: float, height: float, time: float,
		add: bool = true, start: float = 0.15, look: String = "beam") -> MeshInstance3D:
	var mi := _mi(root, wall_mesh(1.08), fx(c, "vgrad", add, look))
	var m: VfxMat = mi.material_override
	m.set_shader_parameter("fresnel", 0.0)
	m.set_shader_parameter("scroll", Vector2(0.3, -1.2))
	mi.global_position = ground
	mi.scale = Vector3(radius * start, height, radius * start)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale:x", radius, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "scale:z", radius, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "scale:y", height * 0.25, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_param(t, m, "dissolve", 0.0, 0.85, time * 0.6, time * 0.4)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.4).set_delay(time * 0.6)
	return mi


## Воронка вихря: конус шире кверху, крутится, шум бежит по кругу и вверх.
static func funnel(root: Node3D, c: Color, ground: Vector3, radius: float, height: float, time: float,
		add: bool = true, turns: float = 3.0) -> MeshInstance3D:
	var mi := _mi(root, wall_mesh(2.4), fx(c, "pillar", add, "swirl"))
	var m: VfxMat = mi.material_override
	m.set_shader_parameter("polar", 0.0)
	m.set_shader_parameter("noise_scale", Vector2(3.0, 1.5))
	m.set_shader_parameter("scroll", Vector2(-1.6, -0.8))
	m.set_shader_parameter("noise_amt", 0.75)
	mi.global_position = ground
	mi.scale = Vector3(radius * 0.3, height * 0.2, radius * 0.3)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3(radius, height, radius), time * 0.3).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "rotation:y", TAU * turns, time)
	_param(t, m, "dissolve", 0.0, 0.9, time * 0.35, time * 0.65)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.3).set_delay(time * 0.7)
	return mi


## Спираль-лента, взмывающая вокруг героя (усиление, исцеление): голова бежит снизу вверх, хвост тает.
static func helix(root: Node3D, c: Color, ground: Vector3, radius: float, height: float, time: float,
		turns: float = 2.0, width: float = 0.1, phase: float = 0.0) -> MeshInstance3D:
	var mi := _mi(root, helix_mesh(turns, width), fx(c, "trail", true, "trail"))
	var m: VfxMat = mi.material_override
	m.set_shader_parameter("mask", tex("beam"))
	m.set_shader_parameter("reveal_tail", 0.45)
	mi.global_position = ground
	mi.rotation.y = phase
	mi.scale = Vector3(radius, height, radius)
	var t := mi.create_tween().set_parallel(true)
	_param(t, m, "reveal", 0.0, 1.5, time * 0.85)
	t.tween_property(mi, "rotation:y", phase + 1.2, time)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.3).set_delay(time * 0.7)
	return mi


## Росчерк клинка в точке offset, повёрнут по dir (горизонт), tilt — наклон плоскости (рад), radius; голова
## проносится по дуге sweep рад за 40 % time, хвост тает, по дуге бегут прожилки. width — толщина серпа.
static func arc(root: Node3D, c: Color, dir: Vector3, radius: float, time: float, tilt: float = 0.0,
		offset: Vector3 = Vector3.ZERO, sweep: float = 1.2, width: float = 1.0) -> MeshInstance3D:
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.position = offset
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		pivot.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	pivot.rotate_object_local(Vector3.FORWARD, tilt)
	var span := minf(sweep + 0.7, TAU * 0.98)
	var m := fx(c, "slash", true, "slash")
	m.set_shader_parameter("reveal_tail", 0.75)
	var mi := _mi(pivot, crescent_mesh(snappedf(span, 0.1), clampf(0.32 * width, 0.08, 0.6)), m)
	mi.scale = Vector3(radius, radius, radius)
	var t := mi.create_tween().set_parallel(true)
	_param(t, m, "reveal", 0.0, 1.8, time * 0.55)
	t.tween_property(mi, "scale", Vector3.ONE * radius * 1.12, time * 0.55).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.35).set_delay(time * 0.4)
	return mi


## Молния: ломаная лента от a до b (мировые) с ярким стержнем и ореолом, segments изломов, отклонение jitter,
## branches веток; два перекрещенных полотна — видна с любой стороны. Дважды меняет излом (треск) и гаснет.
static func bolt(root: Node3D, c: Color, a: Vector3, b: Vector3, width: float, time: float, rng: RandomNumberGenerator,
		segments: int = 8, jitter: float = 0.35, branches: int = 0) -> MeshInstance3D:
	var shapes: Array = []
	for k in 3:
		shapes.append(_bolt_mesh(root, a, b, width, rng, segments, jitter, branches))
	var mi := _mi(root, shapes[0], fx(c, "beam", true, "bolt", 0, Color(1, 1, 1, 1)))
	var m: VfxMat = mi.material_override
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", c.a * 0.4, time * 0.12)
	t.tween_callback(func() -> void: mi.mesh = shapes[1])
	t.tween_property(m, "albedo_color:a", c.a, time * 0.08)
	t.tween_interval(time * 0.12)
	t.tween_callback(func() -> void: mi.mesh = shapes[2])
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.68)
	return mi


static func _bolt_mesh(root: Node3D, a: Vector3, b: Vector3, width: float, rng: RandomNumberGenerator,
		segments: int, jitter: float, branches: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := _bolt_points(root, a, b, rng, segments, jitter)
	_ribbon(st, pts, a, b, width)
	for i in branches:
		var k := rng.randi_range(1, maxi(1, pts.size() - 2))
		var p0: Vector3 = pts[k] + root.global_position
		var axis := b - a
		var side := axis.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		var dir := (axis.normalized() * 0.6 + side.normalized() * rng.randf_range(-1.0, 1.0)
			+ Vector3(0, rng.randf_range(-0.5, 0.5), 0)).normalized()
		var p1 := p0 + dir * axis.length() * rng.randf_range(0.15, 0.3)
		_ribbon(st, _bolt_points(root, p0, p1, rng, 4, jitter * 0.6), p0, p1, width * 0.55)
	return st.commit()


static func _bolt_points(root: Node3D, a: Vector3, b: Vector3, rng: RandomNumberGenerator, segments: int,
		jitter: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var axis := b - a
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var side2 := axis.cross(side).normalized()
	for i in segments + 1:
		var k := float(i) / float(segments)
		var p := a + axis * k
		if i > 0 and i < segments:
			p += side * rng.randf_range(-jitter, jitter) + side2 * rng.randf_range(-jitter, jitter)
		pts.append(p - root.global_position)
	return pts


## Лента по точкам pts (локальные) двумя перекрещенными полотнами: UV.x — вдоль, UV.y — поперёк.
static func _ribbon(st: SurfaceTool, pts: Array[Vector3], a: Vector3, b: Vector3, width: float) -> void:
	var axis := b - a
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var side2 := axis.cross(side).normalized()
	var n := pts.size()
	for plane in [side, side2]:
		for i in n - 1:
			var k0 := float(i) / float(n - 1)
			var k1 := float(i + 1) / float(n - 1)
			var w0: Vector3 = plane * width * (1.0 - 0.45 * k0)
			var w1: Vector3 = plane * width * (1.0 - 0.45 * k1)
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			_tri(st, p0 - w0, Vector2(k0, 1.0), p1 - w1, Vector2(k1, 1.0), p1 + w1, Vector2(k1, 0.0))
			_tri(st, p0 - w0, Vector2(k0, 1.0), p1 + w1, Vector2(k1, 0.0), p0 + w0, Vector2(k0, 0.0))


## Луч между a и b (мировые): труба с бегущим шумом, вспыхивает и сужается.
static func beam(root: Node3D, c: Color, a: Vector3, b: Vector3, radius: float, time: float) -> MeshInstance3D:
	var mi := _mi(root, wall_mesh(), fx(c, "white", true, "beam"))
	var m: VfxMat = mi.material_override
	m.set_shader_parameter("noise_scale", Vector2(1.0, maxf(a.distance_to(b), 1.0) * 0.6))
	var len := maxf(a.distance_to(b), 0.05)
	mi.global_position = a
	var up := (b - a).normalized()
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(up).normalized()
	mi.global_basis = Basis(x * radius, up * len, z * radius)
	var t := mi.create_tween().set_parallel(true)
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(mi):
			mi.global_basis = Basis(x * radius * k, up * len, z * radius * k), 1.0, 0.1, time)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.5).set_delay(time * 0.5)
	return mi


## Шипы из земли: n конусов по кругу radius вокруг ground, вырастают на height и уходят обратно. glow — светящиеся
## кристаллы (лёд, свет, тьма) вместо камня.
static func spikes(root: Node3D, c: Color, ground: Vector3, n: int, radius: float, height: float, time: float,
		rng: RandomNumberGenerator, lit: bool = true, glow: bool = false) -> void:
	var m: Material
	if glow:
		var vm := VfxMat.make(Color(c, 0.9), tex("white"), true, {"fresnel": 0.6, "core_amt": 0.5, "hdr": 1.7,
			"noise_amt": 0.3, "noise_scale": Vector2(2.0, 2.0), "scroll": Vector2(0.0, -0.6)}, 0, Color(c.lightened(0.7), 1.0))
		m = vm
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = c
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.disable_receive_shadows = true
		sm.emission_enabled = true
		sm.emission = c.darkened(0.6)
		m = sm
	for i in n:
		var ang := TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
		var r := radius * rng.randf_range(0.25, 1.0) if n > 1 else 0.0
		var mi := _mi(root, spike_mesh(), m)
		var h := height * rng.randf_range(0.6, 1.0)
		var w := h * rng.randf_range(0.3, 0.45)
		mi.global_position = ground + Vector3(cos(ang) * r, -h * 0.5, sin(ang) * r)
		var lean := Vector3(cos(ang), 0, sin(ang)) * 0.35
		mi.rotation = Vector3(lean.z + rng.randf_range(-0.15, 0.15), rng.randf_range(0, TAU), -lean.x + rng.randf_range(-0.15, 0.15))
		mi.scale = Vector3(w, h, w)
		var y := mi.position.y
		var t := mi.create_tween()
		t.tween_property(mi, "position:y", y + h * 0.5, time * 0.12).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(float(i) * time * 0.025)
		t.tween_interval(time * 0.5)
		t.tween_property(mi, "position:y", y - h * 0.1, time * 0.3).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)


## Светящийся шар-ядро к камере (сгусток силы в руках, ядро снаряда): пульсирует.
static func orb(root: Node3D, c: Color, size: float, time: float, offset: Vector3 = Vector3.ZERO,
		pulse_hz: float = 2.0) -> MeshInstance3D:
	var mi := _mi(root, Vfx._quad(), fx(c, "orb", true, "energy", 2))
	mi.position = offset
	mi.scale = Vector3.ONE * size * 0.3
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * size, minf(time * 0.3, 0.3)).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	if pulse_hz > 0.0 and time > 0.5:
		var n := maxi(1, int(time * pulse_hz) - 1)
		for i in n:
			t.tween_property(mi, "scale", Vector3.ONE * size * 1.18, 0.5 / pulse_hz)
			t.tween_property(mi, "scale", Vector3.ONE * size * 0.92, 0.5 / pulse_hz)
	return mi


## Постоянная аура вокруг узла (каст, усиление): непрерывные частицы. Не удаляется сама — stop_loop.
static func loop(parent: Node3D, o: Dictionary) -> CPUParticles3D:
	var d := o.duplicate()
	d["loop"] = true
	var p := particles(parent, d)
	p.add_to_group("vfx_loop")
	return p


## Остановить постоянную ауру: новые частицы не появляются, узел удаляется, когда старые догорят.
static func stop_loop(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p is CPUParticles3D:
		var cp := p as CPUParticles3D
		cp.emitting = false
		var t := cp.create_tween()
		t.tween_interval(cp.lifetime + 0.1)
		t.tween_callback(cp.queue_free)
	else:
		p.queue_free()


## Краткий огонь (только «Высокое» качество, не больше MAX_LIGHTS сразу): вспышка взрыва, молнии.
static func light(root: Node3D, c: Color, energy: float, rng_m: float, time: float, offset: Vector3 = Vector3.ZERO) -> void:
	if lights_alive >= MAX_LIGHTS:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	root.add_child(l)
	l.position = offset
	lights_alive += 1
	l.tree_exiting.connect(func() -> void: lights_alive = maxi(0, lights_alive - 1))
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Тряска камеры от мощного удара в точке at (сила 0…1; дальше от камеры — слабее; только картинка).
static func shake(root: Node3D, strength: float) -> void:
	VfxShake.kick(root, root.global_position, strength)


## След за узлом who (снаряд): лента к камере, голова у узла, хвост тает. Узел следа живёт в мире и гаснет
## сам после исчезновения who.
static func trail(who: Node3D, c: Color, width: float, life: float, look: String = "trail") -> VfxTrail:
	return VfxTrail.attach(who, fx(c, "trail", true, look), width, life)


## Подготовить маски, шум и меши заранее (вход в мир — без задержки на первом эффекте): маски рисуются в фоновом
## потоке (WorkerThreadPool), текстуры из них создаёт первый tex() или finish_prewarm().
static func prewarm() -> void:
	VfxMat.fbm_noise()
	VfxMat.cell_noise()
	if _task < 0:
		var todo: Array = []
		for k in OWN:
			if not _tex.has(String(k)):
				todo.append(String(k))
		if not todo.is_empty():
			_task = WorkerThreadPool.add_task(_gen_all.bind(todo), false, "VfxKit masks")
	for k in ["dot", "plus", "puff", "heart"]:
		tex(k)
	wall_mesh()
	wall_mesh(1.08)
	wall_mesh(2.4)
	long_quad()


## Поток масок закончил — дождаться (освободить задачу) и создать текстуры. true — готово.
static func finish_prewarm(force: bool = false) -> bool:
	if _task < 0:
		return true
	if not force and not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	for k in OWN:
		tex(String(k))
	return true
