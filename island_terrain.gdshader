// Земля тренировочного острова в «рисованном» аниме-стиле: мягкие пятна травы трёх оттенков,
// дороги с чистыми краями и редкими камешками, слоистые скалы на крутых склонах, песок у воды,
// тёмное дно под водой. Свет toon: тень (цветная, сиреневая) → полутон → свет, без контура.
//
// Вершинные данные (собирает IslandWorld._chunk_mesh):
//   COLOR.rgb — оттенок травы зоны (sRGB), COLOR.a — вес площадки постройки (0..1);
//   UV.x — расстояние до оси ближайшей дороги, м; UV.y — уровень ближайшей воды (море, река, пруд), м.
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

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = v_pos.xz;
	float px = max(length(fwidth(p)), 0.002);
	float above = v_pos.y - UV.y;
	float ny = normalize(v_nrm).y;

	// --- Трава: крупные мягкие пятна (тёмное прохладное / основное / светлое тёплое) и мазки
	vec3 tint = to_linear(COLOR.rgb);
	float n1 = it_noise(p * 0.055);
	float n2 = rich ? it_noise(p * 0.19 + 17.0) : 0.5;
	float n3 = rich ? it_noise(p * 0.85 + 3.0) : 0.5;
	float pat = rich ? n1 * 0.62 + n2 * 0.38 : n1;
	vec3 g_dark = tint * vec3(0.74, 0.82, 0.95);
	vec3 g_light = tint * vec3(1.22, 1.14, 0.80);
	vec3 col = mix(g_dark, tint, smoothstep(0.33, 0.41, pat));
	col = mix(col, g_light, smoothstep(0.60, 0.67, pat));
	// Мазки кистью: вытянутые пятнышки чуть светлее
	if (rich) {
		float stroke = it_noise(vec2(p.x * 0.55 + p.y * 0.35, p.y * 1.4 - p.x * 0.5) + 41.0);
		col *= 0.94 + 0.07 * n3 + 0.06 * smoothstep(0.72, 0.8, stroke);
	}

	// --- Площадки построек: утоптанная земля проступает пятнами
	float flat_m = smoothstep(0.88, 0.97, COLOR.a + (n2 - 0.5) * 0.12);
	col = mix(col, packed_earth * (0.92 + 0.12 * n3), flat_m * 0.32);

	// --- Дороги: чёткий край с лёгкой «рукотворной» волной, кромка притоптанной травы
	float rd = UV.x + (rich ? (it_noise(p * 0.32 + 1.7) - 0.5) * 0.55 : 0.0);
	float dry = smoothstep(0.05, 0.3, above);
	float road_m = (1.0 - smoothstep(road_half - px, road_half + px, rd)) * dry;
	float verge = (1.0 - smoothstep(road_half, road_half + 0.75, rd)) * (1.0 - road_m) * dry;
	col = mix(col, col * vec3(1.1, 1.03, 0.74), verge * 0.65);
	if (road_m > 0.0) {
		vec3 dirt = mix(dirt_dark, dirt_light, rich ? smoothstep(0.35, 0.65, it_noise(p * 0.42 + 5.0)) : n1);
		// Тёмная колея вдоль края
		float rut = smoothstep(road_half - 0.5, road_half - 0.12, rd);
		dirt = mix(dirt, road_edge, rut * 0.55);
		// Редкие камешки
		if (rich) {
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
	float rn = rich ? it_noise(p * 0.28 + 31.0) : n1;
	float rock_m = 1.0 - smoothstep(0.66, 0.72, ny + (rn - 0.5) * 0.14);
	if (rock_m > 0.0) {
		float s = fract(v_pos.y * 0.85 + rn * 0.9 + n3 * 0.15);
		float band = rich ? smoothstep(0.42, 0.48, s) * (1.0 - smoothstep(0.86, 0.92, s)) : 0.5;
		vec3 rc = mix(rock_dark, rock_light, band * 0.75 + n3 * 0.25);
		rc *= mix(0.88, 1.1, smoothstep(0.25, 0.6, ny));
		// Мох на верхнем крае обрыва
		float moss = smoothstep(0.55, 0.65, ny) * smoothstep(0.4, 0.6, n2) * dry;
		rc = mix(rc, moss_color, moss * 0.7);
		col = mix(col, rc, rock_m);
	}

	// --- Песок у воды (только на пологих местах), мокрая полоса у кромки
	float sn = rich ? it_noise(p * 0.45 + 9.0) : 0.5;
	float ab = above - (sn - 0.5) * 0.5;
	float apx = max(fwidth(above), 0.01);
	float sand_m = (1.0 - smoothstep(0.38 - apx, 0.38 + apx, ab)) * (1.0 - rock_m * 0.85);
	vec3 sandc = mix(sand_color, wet_sand, 1.0 - smoothstep(-0.05, 0.14, above));
	col = mix(col, sandc * (0.95 + 0.08 * n3), sand_m);

	// --- Под водой: дно темнеет и зеленеет с глубиной (видно сквозь полупрозрачную воду)
	float depth = -above;
	col = mix(col, bed_deep, smoothstep(0.15, 3.2, depth) * 0.85);

	ALBEDO = col;
}

void light() {
	// Три тона: тень с сиреневым оттенком, полутон на склонах от солнца, полный свет
	float ndl = dot(NORMAL, LIGHT);
	float sh = smoothstep(0.25, 0.55, ATTENUATION);
	float lit = smoothstep(0.0, 0.06, ndl) * sh;
	float full = smoothstep(0.40, 0.48, ndl) * sh;
	vec3 tone = mix(shadow_tint * 0.6, vec3(0.8), lit);
	tone = mix(tone, vec3(1.0), full);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone / PI;
}
