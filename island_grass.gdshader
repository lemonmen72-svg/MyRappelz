// Трава острова (MultiMesh пучков участками, IslandVegetation). Цвет зоны — INSTANCE_CUSTOM.rgb
// (линейный, как вершинные цвета рельефа), тёмный корень → светлый кончик, покачивание от ветра.
// Вдали пучки плавно «уходят в землю» (fade_start..fade_end, м), поэтому граница дальности
// участков не мигает. UV.y — высота точки травинки (0 у корня), INSTANCE_CUSTOM.a — фаза ветра.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://world_common.gdshaderinc"

uniform vec2 wind_dir = vec2(0.86, 0.5);
uniform float wind_strength = 0.32;
uniform float wind_speed = 1.5;
uniform vec3 tip_color : source_color = vec3(0.86, 0.92, 0.5);
uniform float tip_mix = 0.22;
uniform float fade_start = 28.0;
uniform float fade_end = 40.0;

varying vec3 v_color;

void vertex() {
	float h = UV.y;
	vec3 root = MODEL_MATRIX[3].xyz;
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 base = INSTANCE_CUSTOM.rgb;
	vec3 tip = mix(base * 1.3, tip_color, tip_mix);
	v_color = mix(base * 0.62, tip, smoothstep(0.0, 0.95, h));

	float t = TIME * wind_speed + INSTANCE_CUSTOM.a * 6.28;
	float ph = dot(root.xz, wind_dir) * 0.15;
	float wave = sin(t + ph) * 0.5 + 0.5;
	float gust = sin(t * 0.31 + ph * 0.4) * 0.5 + 0.5;
	float flutter = sin(t * 3.3 + INSTANCE_CUSTOM.a * 12.0) * 0.12;
	float bend = h * h * height * wind_strength * (0.3 + wave * (0.5 + gust) + flutter);
	VERTEX.xz += wind_dir * bend;
	VERTEX.y -= bend * bend * 0.6;

	// Плавное исчезновение вдали: пучок сжимается к корню
	float k = 1.0 - smoothstep(fade_start, fade_end, distance(root, CAMERA_POSITION_WORLD));
	VERTEX = root + (VERTEX - root) * k;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = v_color;
	// Нормаль «вверх» для обеих сторон травинки: свет как у земли, без тёмных изнанок
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void light() {
	DIFFUSE_LIGHT += wc_toon(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR);
}
