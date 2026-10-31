// Общий toon-шейдер построек и предметов (аниме cel-shading «в духе Genshin»):
// 2–3 тона света с чёткой границей, цветные (не чёрные) тени, подсветка края (rim) со стороны света,
// цвет из параметра, текстуры и/или цвета вершин, по желанию — покачивание от ветра (колосья, ткань).
// Контур — отдельным материалом next_pass (outline.gdshader); у построек слабый или без него.
// Цвета вершин ожидаются в линейном пространстве (PoiModels.Kit переводит их при сборке).
// Склеенные меши построек (PoiModels.Kit): свечение (окна, огни) — вершины с UV2.y = 1 в той же
// поверхности (без освещения, цвет вершины), высота для покачивания ткани — UV.x.
//
// Рисованные текстуры материалов (WorldTextures, флаг textures; на «Низком» выключены — выборок нет):
// номер текстуры детали — в альфе цвета вершины (COLOR.a = 1 − номер / 16; 0 — без текстуры)
// или tex_layer у всего материала. Текстура — «детальная маска» (среднее 0.5): цвет × tex × 2.
// У склеенных мешей нет UV, поэтому проекция по мировым координатам (render_mode world_vertex_coords:
// VERTEX и NORMAL в vertex() уже мировые — передаём их во fragment через varying):
// - стены, доски, кладка, скалы, стоячие брёвна (кора): одна проекция по главной оси нормали
//   («Среднее») или triplanar (tex_triplanar, «Высокое»; оси с малым весом пропускаются — у боксов
//   это всё равно 1 выборка); на боковых гранях v = −y — доски и ряды кладки горизонтальны,
//   волокна коры вертикальны;
// - крыши (черепица, солома): проекция вдоль ската — ряды черепицы идут вдоль конька при любом
//   повороте дома, низ текстуры — к карнизу; 1 выборка;
// - лежачие брёвна (кора, LOG): волокна вдоль бревна — ось бревна перпендикулярна горизонтальной
//   части нормали (у жердей ограды под любым углом); 1 выборка.
// Выборки — textureGrad с производными, посчитанными до ветвлений.
// Сэмплеров 8 (albedo_texture + 7) — предел для GL Compatibility на телефонах с 16 блоками
// (верхние 8 блоков Godot держит под тени, небо, отражения и экран), см. WorldTextures.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, world_vertex_coords;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_vertex_color = false;
// Количество тонов: 2 — свет/тень, 3 — свет/полутень/тень.
uniform int tones : hint_range(2, 3) = 2;
// Граница света и тени (по dot(N, L)) и мягкость ступеньки.
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.001, 0.3) = 0.035;
// Цвет тени: множитель солнечного света на теневой стороне (сиреневый/голубой вместо чёрного).
uniform vec4 shadow_color : source_color = vec4(0.72, 0.68, 0.88, 1.0);
// Тень от других объектов (карта теней, ATTENUATION солнца): мягкая ступенька в cel-полосу. Края карты теней
// после фильтра PCF — плавный переход 0..1 на 1–2 текселя: его растягиваем (shadow_lo..shadow_hi), а не режем
// по 0.5 — иначе «лесенка» текселей и рябь самозатенения. На гранях почти вдоль солнца (dot(N, L) у границы
// света) тень карты гаснет до shadow_fade: там она — в основном рябь, а сторона и так уходит в cel-тень.
uniform float shadow_lo : hint_range(0.0, 1.0) = 0.15;
uniform float shadow_hi : hint_range(0.0, 1.0) = 0.8;
uniform float shadow_fade : hint_range(0.0, 1.0) = 0.15;
// Подсветка края (rim): сила, ширина (0..1), цвет.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
// Собственное свечение (окна, руны).
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Покачивание от ветра: смещение (м) на квадрат высоты над началом объекта; 0 — выключено.
uniform float sway = 0.0;
uniform float sway_speed = 1.6;
uniform vec2 wind_dir = vec2(0.86, 0.5);
// Нормаль «вверх» (тонкие плоскости: колосья, трава) — свет как у земли, без тёмных изнанок.
uniform bool normal_up = false;
// Вершины с UV2.y > 0.5 светятся (неосвещаемый цвет вершины) — окна и огни склеенных мешей.
uniform bool uv2_glow = false;
// Высота над основанием объекта для покачивания — из UV.x (иначе от начала координат меша).
uniform bool sway_uv_height = false;

// Рисованные текстуры (WorldTextures): включает Quality на «Среднем» и «Высоком».
uniform bool textures = false;
uniform bool tex_triplanar = false;
// Номер текстуры для всего материала (WorldTextures.WOOD...); −1 — из альфы цвета вершин.
uniform int tex_layer = -1;
uniform sampler2D tex_wood : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_masonry : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_plaster : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_tiles : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_thatch : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rock : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_bark : hint_default_white, filter_linear_mipmap, repeat_enable;
// Метров на повтор текстуры (рисунки Максима: ~9 досок по 0.2 м, ~9 рядов кладки по 0.18 м
// с блоками ~0.5 м, ~4 ряда черепицы по 0.3 м, ~2.5 ряда снопов соломы, ~7 полос коры).
uniform float wood_tile = 1.8;
uniform float masonry_tile = 1.6;
uniform float plaster_tile = 3.0;
uniform float tiles_tile = 1.3;
uniform float thatch_tile = 1.5;
uniform float rock_tile = 3.0;
uniform float bark_tile = 1.0;
// Сила текстуры: 0 — нет, 1 — полная.
uniform float tex_strength : hint_range(0.0, 1.0) = 0.8;

varying vec3 v_color;
varying float v_glow;
varying vec3 v_wpos;
varying vec3 v_wnrm;
varying float v_layer;

// Проекция по главной оси нормали (1 выборка) или triplanar (до 3). На боковых гранях v = −y:
// доски и ряды кладки горизонтальны.
vec3 tex_box(sampler2D t, vec3 p, vec3 n, vec3 dx, vec3 dy, float s, bool tri) {
	vec3 a = abs(n);
	if (tri) {
		vec3 w = a * a;
		w = w * w;
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 c = vec3(0.0);
		float ws = 0.0;
		if (w.x > 0.02) {
			c += w.x * textureGrad(t, vec2(p.z, -p.y) * s, vec2(dx.z, -dx.y) * s, vec2(dy.z, -dy.y) * s).rgb;
			ws += w.x;
		}
		if (w.y > 0.02) {
			c += w.y * textureGrad(t, p.xz * s, dx.xz * s, dy.xz * s).rgb;
			ws += w.y;
		}
		if (w.z > 0.02) {
			c += w.z * textureGrad(t, vec2(p.x, -p.y) * s, vec2(dx.x, -dx.y) * s, vec2(dy.x, -dy.y) * s).rgb;
			ws += w.z;
		}
		return ws > 0.0 ? c / ws : vec3(0.5);
	}
	vec2 uv;
	vec2 gx;
	vec2 gy;
	if (a.y >= a.x && a.y >= a.z) {
		uv = p.xz;
		gx = dx.xz;
		gy = dy.xz;
	} else if (a.x >= a.z) {
		uv = vec2(p.z, -p.y);
		gx = vec2(dx.z, -dx.y);
		gy = vec2(dy.z, -dy.y);
	} else {
		uv = vec2(p.x, -p.y);
		gx = vec2(dx.x, -dx.y);
		gy = vec2(dy.x, -dy.y);
	}
	return textureGrad(t, uv * s, gx * s, gy * s).rgb;
}

// Проекция вдоль ската (крыши): v — расстояние вниз по скату (низ текстуры — к карнизу),
// u — та мировая горизонтальная ось, что ближе к направлению конька. 1 выборка.
vec3 tex_roof(sampler2D t, vec3 p, vec3 n, vec3 dx, vec3 dy, float s) {
	float h = length(n.xz);
	vec2 d = h > 0.001 ? n.xz / h : vec2(0.0, 1.0);
	// Касательная вниз по скату: (d * n.y, −h) — единичная, т. к. n.y² + h² = 1
	float v = dot(p.xz, d) * n.y - p.y * h;
	float gvx = dot(dx.xz, d) * n.y - dx.y * h;
	float gvy = dot(dy.xz, d) * n.y - dy.y * h;
	bool along_z = abs(d.x) > abs(d.y);
	float u = along_z ? p.z : p.x;
	float gux = along_z ? dx.z : dx.x;
	float guy = along_z ? dy.z : dy.x;
	return textureGrad(t, vec2(u, v) * s, vec2(gux, gvx) * s, vec2(guy, gvy) * s).rgb;
}

// Лежачее бревно: волокна (вертикаль текстуры) — вдоль оси бревна. Ось — горизонталь,
// перпендикулярная горизонтальной части нормали (у боковых граней жерди и цилиндра-полена она
// одна и та же; знак приведён к одному, чтобы на коньке бревна не было шва). Поперёк — высота
// на боковых гранях, горизонталь поперёк оси на верхних и нижних. 1 выборка.
vec3 tex_log(sampler2D t, vec3 p, vec3 n, vec3 dx, vec3 dy, float s) {
	float h = length(n.xz);
	vec2 ax = h > 0.001 ? vec2(-n.z, n.x) / h : vec2(1.0, 0.0);
	if (dot(ax, vec2(1.0, 0.001)) < 0.0) {
		ax = -ax;
	}
	vec2 side = vec2(-ax.y, ax.x);
	float v = dot(p.xz, ax);
	float gvx = dot(dx.xz, ax);
	float gvy = dot(dy.xz, ax);
	bool lies = abs(n.y) > h;
	float u = lies ? dot(p.xz, side) : -p.y;
	float gux = lies ? dot(dx.xz, side) : -dx.y;
	float guy = lies ? dot(dy.xz, side) : -dy.y;
	return textureGrad(t, vec2(u, v) * s, vec2(gux, gvx) * s, vec2(guy, gvy) * s).rgb;
}

void vertex() {
	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
	v_glow = uv2_glow ? UV2.y : 0.0;
	v_layer = tex_layer >= 0 ? float(tex_layer) : floor((1.0 - COLOR.a) * 16.0 + 0.5);
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float h = sway_uv_height ? max(UV.x, 0.0) : max(VERTEX.y - root.y, 0.0);
		float ph = dot(root.xz, wind_dir) * 0.3 + sin(root.x * 1.7 + root.z * 2.3) * 1.3;
		float t = TIME * sway_speed + ph;
		float bend = sway * h * h * (0.55 + 0.45 * sin(t) + 0.12 * sin(t * 2.9 + 1.3));
		VERTEX.xz += wind_dir * bend;
		VERTEX.y -= bend * bend * 0.5;
	}
	// world_vertex_coords: VERTEX и NORMAL здесь уже в мировых координатах
	v_wpos = VERTEX;
	v_wnrm = NORMAL;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb * v_color;
	// Рисованная текстура материала детали (производные — до ветвлений)
	vec3 dpx = dFdx(v_wpos);
	vec3 dpy = dFdy(v_wpos);
	if (textures && v_layer > 0.5 && v_glow < 0.5) {
		vec3 n = normalize(v_wnrm);
		int layer = int(v_layer + 0.5);
		vec3 d = vec3(0.5);
		if (layer == 1) {
			d = tex_box(tex_wood, v_wpos, n, dpx, dpy, 1.0 / wood_tile, tex_triplanar);
		} else if (layer == 2) {
			d = tex_box(tex_masonry, v_wpos, n, dpx, dpy, 1.0 / masonry_tile, tex_triplanar);
		} else if (layer == 3) {
			d = tex_box(tex_plaster, v_wpos, n, dpx, dpy, 1.0 / plaster_tile, tex_triplanar);
		} else if (layer == 4) {
			d = tex_roof(tex_tiles, v_wpos, n, dpx, dpy, 1.0 / tiles_tile);
		} else if (layer == 5) {
			d = tex_roof(tex_thatch, v_wpos, n, dpx, dpy, 1.0 / thatch_tile);
		} else if (layer == 6) {
			d = tex_box(tex_rock, v_wpos, n, dpx, dpy, 1.0 / rock_tile, tex_triplanar);
		} else if (layer == 7) {
			d = tex_box(tex_bark, v_wpos, n, dpx, dpy, 1.0 / bark_tile, tex_triplanar);
		} else if (layer == 8) {
			d = tex_log(tex_bark, v_wpos, n, dpx, dpy, 1.0 / bark_tile);
		}
		ALBEDO *= mix(vec3(1.0), d * 2.0, tex_strength);
	}
	EMISSION = emission_color.rgb * emission_energy;
	if (v_glow > 0.5) {
		// Свечение: как неосвещаемый материал — только свой цвет, без света, тени и бликов
		EMISSION += v_color;
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
	}
	if (normal_up) {
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t;
	if (tones >= 3) {
		t = 0.5 * smoothstep(threshold - 0.4 - softness, threshold - 0.4 + softness, ndl)
			+ 0.5 * smoothstep(threshold + 0.3 - softness, threshold + 0.3 + softness, ndl);
	} else {
		t = smoothstep(threshold - softness, threshold + softness, ndl);
	}
	float k = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		// Тень от объектов — мягко в ту же cel-полосу (цветная тень shadow_color, не чёрная)
		float sh = smoothstep(shadow_lo, shadow_hi, ATTENUATION);
		t *= mix(1.0, sh, smoothstep(threshold, threshold + shadow_fade, ndl));
	} else {
		k = ATTENUATION;
	}
	vec3 tone = mix(shadow_color.rgb, vec3(1.0), t);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * k / PI;
	// Светлая кромка по силуэту, ярче на освещённой стороне
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.04, 1.0 - rim_width + 0.04, edge);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim_color.rgb * rim * rim_strength * (0.3 + 0.7 * t) * k / PI;
}
