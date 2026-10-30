// Общий toon-шейдер построек и предметов (аниме cel-shading «в духе Genshin»):
// 2–3 тона света с чёткой границей, цветные (не чёрные) тени, подсветка края (rim) со стороны света,
// цвет из параметра, текстуры и/или цвета вершин, по желанию — покачивание от ветра (колосья, ткань).
// Контур — отдельным материалом next_pass (outline.gdshader); у построек слабый или без него.
// Цвета вершин ожидаются в линейном пространстве (PoiModels.Kit переводит их при сборке).
// Склеенные меши построек (PoiModels.Kit): свечение (окна, огни) — вершины с UV2.y = 1 в той же
// поверхности (без освещения, цвет вершины), высота для покачивания ткани — UV.x.
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

varying vec3 v_color;
varying float v_glow;

void vertex() {
	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
	v_glow = uv2_glow ? UV2.y : 0.0;
	if (sway > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float h = sway_uv_height ? max(UV.x, 0.0) : max(VERTEX.y - root.y, 0.0);
		float ph = dot(root.xz, wind_dir) * 0.3 + sin(root.x * 1.7 + root.z * 2.3) * 1.3;
		float t = TIME * sway_speed + ph;
		float bend = sway * h * h * (0.55 + 0.45 * sin(t) + 0.12 * sin(t * 2.9 + 1.3));
		VERTEX.xz += wind_dir * bend;
		VERTEX.y -= bend * bend * 0.5;
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb * v_color;
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
	// Тень от объектов (ATTENUATION) переводит точку на теневую сторону
	float v = min(dot(NORMAL, LIGHT), ATTENUATION * 2.0 - 1.0);
	float t;
	if (tones >= 3) {
		t = 0.5 * smoothstep(threshold - 0.4 - softness, threshold - 0.4 + softness, v)
			+ 0.5 * smoothstep(threshold + 0.3 - softness, threshold + 0.3 + softness, v);
	} else {
		t = smoothstep(threshold - softness, threshold + softness, v);
	}
	float k = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	vec3 tone = mix(shadow_color.rgb, vec3(1.0), t);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * k / PI;
	// Светлая кромка по силуэту, ярче на освещённой стороне
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width - 0.04, 1.0 - rim_width + 0.04, edge);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim_color.rgb * rim * rim_strength * (0.3 + 0.7 * t) * k / PI;
}
