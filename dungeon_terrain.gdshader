// Пол и стены подземелья (DungeonWorld) в том же рисованном стиле, что земля острова: каменный пол в сиренево-серых
// тонах с пятнами мха и светящейся изумрудной плесени, утоптанная земля лагеря и шахты, мокрая кромка у воды,
// скальный край (слои породы, triplanar) с мхом наверху, тёмное дно под водой. Свет toon, как у island_terrain.
//
// Вершинные данные (DungeonWorld._dungeon_chunk): COLOR.r — вид пола (0 камень, 0.5 земля, 1 палуба / мостки);
// UV.x — расстояние до пола (< 0 — пол), м; UV.y — расстояние до воды (< 0 — вода), м.
// Текстуры (WorldTextures, флаг textures): камень пола — tex_stone (брусчатка) и tex_rock, земля — tex_dirt.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 stone_light : source_color = vec3(0.37, 0.35, 0.42);
uniform vec3 stone_dark : source_color = vec3(0.23, 0.22, 0.29);
uniform vec3 dirt_color : source_color = vec3(0.55, 0.44, 0.33);
uniform vec3 deck_color : source_color = vec3(0.36, 0.28, 0.21);
uniform vec3 moss_color : source_color = vec3(0.24, 0.36, 0.22);
uniform vec3 glow_moss : source_color = vec3(0.30, 1.0, 0.55);
uniform vec3 rock_light : source_color = vec3(0.44, 0.40, 0.52);
uniform vec3 rock_dark : source_color = vec3(0.22, 0.20, 0.29);
uniform vec3 bed_deep : source_color = vec3(0.04, 0.16, 0.16);
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.30, 0.52);
uniform float water_y = -0.45;
uniform float floor_y = 0.0;
uniform bool rich = true;
uniform bool textures = false;
uniform sampler2D tex_dirt : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rock : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_stone : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float stone_tile = 2.6;
uniform float dirt_tile = 3.0;
uniform float rock_tile = 4.0;
uniform float tex_strength : hint_range(0.0, 1.0) = 0.85;

varying vec3 v_pos;
varying vec3 v_nrm;

float dt_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float dt_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dt_hash(i), dt_hash(i + vec2(1.0, 0.0)), u.x), mix(dt_hash(i + vec2(0.0, 1.0)), dt_hash(i + vec2(1.0)), u.x), u.y);
}

vec3 detail(vec3 t) {
	return mix(vec3(1.0), t * 2.0, tex_strength);
}

vec3 tex_cliff(sampler2D t, vec3 p, vec3 n, vec3 dx, vec3 dy, float s) {
	vec3 a = abs(n);
	vec2 uv;
	vec2 gx;
	vec2 gy;
	if (a.y >= a.x && a.y >= a.z) {
		uv = p.xz; gx = dx.xz; gy = dy.xz;
	} else if (a.x >= a.z) {
		uv = vec2(p.z, -p.y); gx = vec2(dx.z, -dx.y); gy = vec2(dy.z, -dy.y);
	} else {
		uv = vec2(p.x, -p.y); gx = vec2(dx.x, -dx.y); gy = vec2(dy.x, -dy.y);
	}
	return textureGrad(t, uv * s, gx * s, gy * s).rgb;
}

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 p = v_pos.xz;
	vec3 dpx = dFdx(v_pos);
	vec3 dpy = dFdy(v_pos);
	float ny = normalize(v_nrm).y;
	float fsd = UV.x;
	float wsd = UV.y;
	float n1 = dt_noise(p * 0.11);
	float n2 = rich ? dt_noise(p * 0.45 + 7.0) : 0.5;
	float n3 = rich ? dt_noise(p * 1.7 + 3.0) : 0.5;

	// --- Пол: камень (крупные плиты-пятна светлее и темнее), земля лагеря, доски палуб
	vec3 stone = mix(stone_dark, stone_light, n1 * 0.7 + n3 * 0.3);
	if (textures) {
		stone *= detail(textureGrad(tex_stone, p / stone_tile, dpx.xz / stone_tile, dpy.xz / stone_tile).rgb);
	}
	vec3 col = stone;
	float kind = COLOR.r;
	if (kind > 0.25 && kind < 0.75) {
		vec3 dirt = dirt_color * (0.85 + 0.25 * n2);
		if (textures) {
			dirt *= detail(textureGrad(tex_dirt, p / dirt_tile, dpx.xz / dirt_tile, dpy.xz / dirt_tile).rgb);
		}
		col = mix(stone, dirt, smoothstep(0.3, 0.6, n1 + 0.25));
	} else if (kind >= 0.75) {
		col = deck_color * (0.85 + 0.2 * n3);
	}
	// Мох и светящаяся плесень редкими пятнами
	float moss = smoothstep(0.66, 0.74, n2) * (kind < 0.75 ? 1.0 : 0.0);
	col = mix(col, moss_color, moss * 0.4);
	float glow = rich ? smoothstep(0.9, 0.95, n2 * 0.6 + n3 * 0.5) * (kind < 0.25 ? 1.0 : 0.0) : 0.0;
	// К стенам пол темнее (тень у подножия скалы)
	col *= mix(1.0, 0.72, smoothstep(-2.5, 0.0, fsd));

	// --- Мокрая кромка у воды: темнее
	float wet = 1.0 - smoothstep(0.0, 1.6, wsd);
	col *= mix(1.0, 0.62, wet * step(water_y - 0.05, v_pos.y));

	// --- Скальный край: крутые склоны и всё выше пола — порода слоями, мох наверху
	float steep = 1.0 - smoothstep(0.55, 0.8, ny);
	float rim = max(steep, smoothstep(floor_y + 0.35, floor_y + 0.9, v_pos.y) * step(0.2, fsd)) * (kind >= 0.75 ? 0.0 : 1.0);
	if (rim > 0.001) {
		float s = fract(v_pos.y * 0.9 + n2 * 0.9);
		float band = rich ? smoothstep(0.42, 0.48, s) * (1.0 - smoothstep(0.86, 0.92, s)) : 0.5;
		vec3 rc = mix(rock_dark, rock_light, band * 0.7 + n3 * 0.3);
		if (textures) {
			rc *= detail(tex_cliff(tex_rock, v_pos, normalize(v_nrm), dpx, dpy, 1.0 / rock_tile));
		}
		float top_moss = smoothstep(0.7, 0.85, ny) * smoothstep(0.45, 0.65, n2);
		rc = mix(rc, moss_color * 0.9, top_moss * 0.6);
		col = mix(col, rc, rim);
		glow *= 1.0 - rim;
	}
	// Ниже пола у края пустоты — в темноту
	col *= mix(0.25, 1.0, smoothstep(floor_y - 8.0, floor_y - 1.0, v_pos.y) + step(0.0, -wsd));

	// --- Под водой: дно темнеет с глубиной
	float depth = water_y - v_pos.y;
	col = mix(col, bed_deep, smoothstep(0.05, 1.2, depth) * 0.85);

	ALBEDO = col;
	EMISSION = glow_moss * glow * 0.9;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Солнце: тень от объектов — в ступенях тона; огни (omni): затухание по расстоянию на всё (иначе «цвет тени»
	// каждого огня, назначенного участку рельефа, подсвечивал участок целиком — резкая граница по участкам)
	float sh = LIGHT_IS_DIRECTIONAL ? smoothstep(0.15, 0.75, ATTENUATION) : 1.0;
	float k = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float lit = smoothstep(0.0, 0.06, ndl) * sh;
	float full = smoothstep(0.40, 0.48, ndl) * sh;
	vec3 tone = mix(shadow_tint * 0.6, vec3(0.8), lit);
	tone = mix(tone, vec3(1.0), full);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * k / PI;
}
