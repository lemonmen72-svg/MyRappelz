// Земля тренировочного острова в «рисованном» аниме-стиле: мягкие пятна травы трёх оттенков,
// дороги с чистыми краями и редкими камешками, слоистые скалы на крутых склонах, песок у воды,
// тёмное дно под водой. Свет toon: тень (цветная, сиреневая) → полутон → свет, без контура.
//
// Вершинные данные (собирает IslandWorld._chunk_mesh):
//   COLOR.rgb — оттенок травы зоны (sRGB), COLOR.a — вес площадки постройки (0..1);
//   UV.x — расстояние до оси ближайшей дороги, м; UV.y — уровень ближайшей воды (море, река, пруд), м;
//   UV2.x — вес леса 0..1 (IslandWorld.bake_forest по деревьям; на площадках построек 0).
//
// Текстуры (WorldTextures, флаг textures; на «Низком» выключены — шейдер считает то же, что без них):
// рисованные «детальные маски» (среднее 0.5) умножают цвет слоя на tex * 2 — палитра сохраняется.
// Проекция по мировым XZ; у скал — по главной оси нормали (rich = false) или triplanar (rich = true).
// rich = true — у травы и дорог вторая выборка под углом, смешанная по крупному шуму: повтор не заметен.
// Выборки только у слоёв с ненулевым весом (textureGrad с производными, посчитанными до ветвлений):
// обычно 1 на пиксель («Среднее») / 2 («Высокое»), на краях дорог, песка и скал — больше.
// Площадь и улицы города (town_center, plaza_radius, paved_radius) — брусчатка, только с текстурами.
// Лесная подстилка (тёмная почва с листьями и мхом) — там, где вес леса велик, с рваным краем по шуму;
// только с текстурами (как и брусчатка): в лесу трава не выбирается, выборок столько же.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 dirt_light : source_color = vec3(0.80, 0.64, 0.44);
uniform vec3 dirt_dark : source_color = vec3(0.66, 0.50, 0.34);
uniform vec3 road_edge : source_color = vec3(0.54, 0.41, 0.28);
uniform vec3 pebble_color : source_color = vec3(0.84, 0.81, 0.74);
uniform vec3 packed_earth : source_color = vec3(0.68, 0.60, 0.44);
uniform vec3 sand_color : source_color = vec3(0.92, 0.84, 0.64);
uniform vec3 wet_sand : source_color = vec3(0.70, 0.62, 0.47);
uniform vec3 bed_deep : source_color = vec3(0.16, 0.38, 0.42);
uniform vec3 rock_light : source_color = vec3(0.66, 0.64, 0.62);
uniform vec3 rock_dark : source_color = vec3(0.43, 0.43, 0.49);
uniform vec3 moss_color : source_color = vec3(0.42, 0.58, 0.30);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.36, 0.62);
// Полуширина дороги, м (ширина дороги из конфига × 0.45).
uniform float road_half = 1.45;
// false — облегчённый режим для слабых пресетов (Quality): 2–3 шума на пиксель вместо 8,
// без мазков кистью, камешков на дорогах, слоёв породы и шумной кромки песка.
uniform bool rich = true;

// Рисованные текстуры (WorldTextures): включает Quality на «Среднем» и «Высоком».
uniform bool textures = false;
uniform sampler2D tex_grass : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dirt : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_sand : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rock : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_stone : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_forest : hint_default_white, filter_linear_mipmap, repeat_enable;
// Метров на повтор текстуры (рисунки Максима: брусчатка ~7 камней по 0.3 м, лист подстилки ~0.15 м).
uniform float grass_tile = 3.5;
uniform float dirt_tile = 3.0;
uniform float sand_tile = 4.0;
uniform float rock_tile = 5.0;
uniform float stone_tile = 2.2;
uniform float forest_tile = 2.5;
// Сила текстуры: 0 — нет, 1 — полная.
uniform float tex_strength : hint_range(0.0, 1.0) = 0.85;
// Город: центр, радиус мощёной площади и радиус, внутри которого дороги мощёные (0 — нет).
uniform vec2 town_center = vec2(0.0);
uniform float plaza_radius = 0.0;
uniform float paved_radius = 0.0;
uniform vec3 cobble_color : source_color = vec3(0.74, 0.71, 0.66);
// Лесная подстилка: цвет почвы (смешивается с оттенком травы зоны) и сила подстилки.
uniform vec3 forest_floor : source_color = vec3(0.44, 0.38, 0.27);
uniform float forest_strength : hint_range(0.0, 1.0) = 0.9;

varying vec3 v_pos;
varying vec3 v_nrm;

float it_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Плавный шум значений 0..1.
float it_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = it_hash(i);
	float b = it_hash(i + vec2(1.0, 0.0));
	float c = it_hash(i + vec2(0.0, 1.0));
	float d = it_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Вершинные цвета заданы в sRGB, свет считается в линейном пространстве.
vec3 to_linear(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

// Множитель цвета из детальной маски (среднее 0.5 → 1.0).
vec3 detail(vec3 t) {
	return mix(vec3(1.0), t * 2.0, tex_strength);
}

// Выборка по мировым XZ: p — точка, dx/dy — её производные по экрану, s — повторов на метр.
// full — вторая выборка (повёрнута на ~37° и сдвинута), смешанная по крупному шуму mixk.
vec3 tex_xz(sampler2D t, vec2 p, vec2 dx, vec2 dy, float s, bool full, float mixk) {
	vec3 a = textureGrad(t, p * s, dx * s, dy * s).rgb;
	if (full) {
		mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		vec3 b = textureGrad(t, r * p * s + vec2(0.37, 0.71), r * dx * s, r * dy * s).rgb;
		a = mix(a, b, smoothstep(0.42, 0.58, mixk));
	}
	return a;
}

// Скалы: triplanar (full, до 3 выборок; оси с малым весом пропускаются) или одна проекция
// по главной оси нормали. На боковых проекциях v = −y: слои породы на обрыве горизонтальны.
vec3 tex_cliff(sampler2D t, vec3 p, vec3 n, vec3 dx, vec3 dy, float s, bool full) {
	vec3 a = abs(n);
	if (full) {
		vec3 w = a * a;
		w = w * w;
		w /= (w.x + w.y + w.z);
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
		return c / max(ws, 0.0001);
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

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = v_pos.xz;
	float px = max(length(fwidth(p)), 0.002);
	float above = v_pos.y - UV.y;
	float ny = normalize(v_nrm).y;
	// Производные для выборок текстур — до любых ветвлений
	vec3 dpx = dFdx(v_pos);
	vec3 dpy = dFdy(v_pos);
	bool tex_on = textures;
	bool tex_full = textures && rich;

	// --- Маски слоёв (те же формулы, что и раньше; считаются заранее, чтобы не делать
	// выборки текстур там, где слой закрыт другим)
	float n1 = it_noise(p * 0.055);
	float n2 = rich ? it_noise(p * 0.19 + 17.0) : 0.5;
	float n3 = rich ? it_noise(p * 0.85 + 3.0) : 0.5;
	float rd = UV.x + (rich ? (it_noise(p * 0.32 + 1.7) - 0.5) * 0.55 : 0.0);
	float dry = smoothstep(0.05, 0.3, above);
	float road_m = (1.0 - smoothstep(road_half - px, road_half + px, rd)) * dry;
	float rn = rich ? it_noise(p * 0.28 + 31.0) : n1;
	float rock_m = 1.0 - smoothstep(0.66, 0.72, ny + (rn - 0.5) * 0.14);
	float sn = rich ? it_noise(p * 0.45 + 9.0) : 0.5;
	float ab = above - (sn - 0.5) * 0.5;
	float apx = max(fwidth(above), 0.01);
	float sand_m = (1.0 - smoothstep(0.38 - apx, 0.38 + apx, ab)) * (1.0 - rock_m * 0.85);
	// Город (только с текстурами): мощёная площадь и мощёные улицы внутри ограды
	float town_d = length(p - town_center) + (n1 - 0.5) * 1.2;
	float plaza_m = 0.0;
	float paved = 0.0;
	if (tex_on && plaza_radius > 0.0) {
		plaza_m = (1.0 - smoothstep(plaza_radius - px * 2.0, plaza_radius + px * 2.0, town_d)) * dry;
		paved = 1.0 - smoothstep(paved_radius - 2.0, paved_radius + 1.0, town_d);
		// На площади дорога не рисуется отдельно (без колеи и кромки)
		road_m *= 1.0 - plaza_m;
	}

	// Лес (только с текстурами): вес леса из вершин, рваный край по шуму
	float forest_m = 0.0;
	if (tex_on && UV2.x > 0.01) {
		forest_m = smoothstep(0.3, 0.6, UV2.x + (n1 - 0.5) * 0.3 + (n2 - 0.5) * 0.25) * forest_strength;
	}

	// --- Трава: крупные мягкие пятна (тёмное прохладное / основное / светлое тёплое) и мазки
	vec3 tint = to_linear(COLOR.rgb);
	float pat = rich ? n1 * 0.62 + n2 * 0.38 : n1;
	vec3 g_dark = tint * vec3(0.74, 0.82, 0.95);
	vec3 g_light = tint * vec3(1.22, 1.14, 0.80);
	vec3 col = mix(g_dark, tint, smoothstep(0.33, 0.41, pat));
	col = mix(col, g_light, smoothstep(0.60, 0.67, pat));
	float grass_vis = (1.0 - road_m) * (1.0 - rock_m) * (1.0 - sand_m) * (1.0 - plaza_m);
	if (tex_on) {
		// Мазки и травинки — из текстуры (под сплошной подстилкой не выбираются)
		if (grass_vis > 0.002 && forest_m < 0.995) {
			col *= detail(tex_xz(tex_grass, p, dpx.xz, dpy.xz, 1.0 / grass_tile, tex_full, n1));
		}
		// Лесная подстилка: почва с оттенком зоны (у тёмных эльфов холоднее), листья и мох — из текстуры
		if (grass_vis > 0.002 && forest_m > 0.005) {
			vec3 fl = mix(forest_floor, tint * 0.7, 0.3) * (0.92 + 0.12 * n3);
			fl *= detail(tex_xz(tex_forest, p, dpx.xz, dpy.xz, 1.0 / forest_tile, tex_full, n2));
			col = mix(col, fl, forest_m);
		}
	} else if (rich) {
		// Мазки кистью: вытянутые пятнышки чуть светлее
		float stroke = it_noise(vec2(p.x * 0.55 + p.y * 0.35, p.y * 1.4 - p.x * 0.5) + 41.0);
		col *= 0.94 + 0.07 * n3 + 0.06 * smoothstep(0.72, 0.8, stroke);
	}

	// --- Площадки построек: утоптанная земля проступает пятнами
	float flat_m = smoothstep(0.88, 0.97, COLOR.a + (n2 - 0.5) * 0.12);
	vec3 earth = packed_earth * (0.92 + 0.12 * n3);
	if (tex_on && flat_m * grass_vis > 0.002) {
		earth *= detail(tex_xz(tex_dirt, p, dpx.xz, dpy.xz, 1.0 / dirt_tile, false, 0.0));
	}
	col = mix(col, earth, flat_m * 0.32);

	// --- Мощёная площадь города (с текстурами): брусчатка, тёмный бордюр по краю
	if (plaza_m > 0.0) {
		vec3 cob = cobble_color * detail(tex_xz(tex_stone, p, dpx.xz, dpy.xz, 1.0 / stone_tile, false, 0.0));
		float curb = smoothstep(plaza_radius - 0.9, plaza_radius - 0.4, town_d);
		cob *= 1.0 - curb * 0.22;
		col = mix(col, cob, plaza_m);
	}

	// --- Дороги: чёткий край с лёгкой «рукотворной» волной, кромка притоптанной травы
	float verge = (1.0 - smoothstep(road_half, road_half + 0.75, rd)) * (1.0 - road_m) * dry;
	col = mix(col, col * vec3(1.1, 1.03, 0.74), verge * 0.65 * (1.0 - plaza_m));
	if (road_m > 0.0) {
		vec3 dirt = mix(dirt_dark, dirt_light, rich ? smoothstep(0.35, 0.65, it_noise(p * 0.42 + 5.0)) : n1);
		// Тёмная колея вдоль края
		float rut = smoothstep(road_half - 0.5, road_half - 0.12, rd);
		dirt = mix(dirt, road_edge, rut * 0.55);
		if (tex_on) {
			if (paved < 0.999) {
				dirt *= detail(tex_xz(tex_dirt, p, dpx.xz, dpy.xz, 1.0 / dirt_tile, tex_full, n1));
			}
			// Улицы города мощёные
			if (paved > 0.001) {
				vec3 cob = cobble_color * (1.0 - rut * 0.25)
					* detail(tex_xz(tex_stone, p, dpx.xz, dpy.xz, 1.0 / stone_tile, false, 0.0));
				dirt = mix(dirt, cob, paved);
			}
		} else if (rich) {
			// Редкие камешки
			vec2 cp = p * 1.6;
			vec2 cell = floor(cp);
			vec2 off = vec2(it_hash(cell + 13.1), it_hash(cell + 27.9)) * 0.5 + 0.25;
			float pr = 0.09 + 0.07 * it_hash(cell + 41.3);
			float pe = px * 1.6;
			float peb = (1.0 - smoothstep(pr - pe, pr + pe, length(fract(cp) - off))) * step(0.86, it_hash(cell));
			dirt = mix(dirt, pebble_color, peb);
		}
		col = mix(col, dirt, road_m);
	}

	// --- Скалы на крутых склонах: слои породы, светлые верхние грани, мох на кромке
	if (rock_m > 0.0) {
		float s = fract(v_pos.y * 0.85 + rn * 0.9 + n3 * 0.15);
		float band = rich ? smoothstep(0.42, 0.48, s) * (1.0 - smoothstep(0.86, 0.92, s)) : 0.5;
		vec3 rc = mix(rock_dark, rock_light, band * 0.75 + n3 * 0.25);
		rc *= mix(0.88, 1.1, smoothstep(0.25, 0.6, ny));
		if (tex_on) {
			rc *= detail(tex_cliff(tex_rock, v_pos, normalize(v_nrm), dpx, dpy, 1.0 / rock_tile, tex_full));
		}
		// Мох на верхнем крае обрыва
		float moss = smoothstep(0.55, 0.65, ny) * smoothstep(0.4, 0.6, n2) * dry;
		rc = mix(rc, moss_color, moss * 0.7);
		col = mix(col, rc, rock_m);
	}

	// --- Песок у воды (только на пологих местах), мокрая полоса у кромки
	vec3 sandc = mix(sand_color, wet_sand, 1.0 - smoothstep(-0.05, 0.14, above)) * (0.95 + 0.08 * n3);
	if (tex_on && sand_m > 0.002) {
		sandc *= detail(tex_xz(tex_sand, p, dpx.xz, dpy.xz, 1.0 / sand_tile, false, 0.0));
	}
	col = mix(col, sandc, sand_m);

	// --- Под водой: дно темнеет и зеленеет с глубиной (видно сквозь полупрозрачную воду)
	float depth = -above;
	col = mix(col, bed_deep, smoothstep(0.15, 3.2, depth) * 0.85);

	ALBEDO = col;
}

void light() {
	// Три тона: тень с сиреневым оттенком, полутон на склонах от солнца, полный свет
	float ndl = dot(NORMAL, LIGHT);
	// Тень от объектов — мягкий край (после фильтра PCF карты теней), не резкая ступенька по текселям
	float sh = smoothstep(0.15, 0.75, ATTENUATION);
	float lit = smoothstep(0.0, 0.06, ndl) * sh;
	float full = smoothstep(0.40, 0.48, ndl) * sh;
	vec3 tone = mix(shadow_tint * 0.6, vec3(0.8), lit);
	tone = mix(tone, vec3(1.0), full);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone / PI;
}
