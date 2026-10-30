// Трава (MultiMesh пучков): цвет от луга под пучком, тёмный корень → светлый кончик,
// покачивание от ветра. UV.y — высота точки травинки (0 у корня). INSTANCE_CUSTOM: x — оттенок, y — фаза.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://world_common.gdshaderinc"

uniform vec2 wind_dir = vec2(0.86, 0.5);
uniform float wind_strength = 0.3;
uniform float wind_speed = 1.5;
uniform vec3 tip_color : source_color = vec3(0.78, 0.90, 0.42);

varying vec3 v_color;

void vertex() {
	float h = UV.y;
	vec2 root = MODEL_MATRIX[3].xz;
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 base = wc_meadow(root);
	float shade = 0.88 + 0.24 * INSTANCE_CUSTOM.x;
	vec3 tip = mix(base * 1.18, tip_color, 0.3);
	v_color = mix(base * 0.6, tip, smoothstep(0.0, 0.95, h)) * shade;

	float t = TIME * wind_speed + INSTANCE_CUSTOM.y * 1.5;
	float ph = dot(root, wind_dir) * 0.15;
	float wave = sin(t + ph) * 0.5 + 0.5;
	float gust = sin(t * 0.31 + ph * 0.4) * 0.5 + 0.5;
	float flutter = sin(t * 3.3 + INSTANCE_CUSTOM.x * 6.28) * 0.12;
	float bend = h * h * height * wind_strength * (0.3 + wave * (0.5 + gust) + flutter);
	VERTEX.xz += wind_dir * bend;
	VERTEX.y -= bend * bend * 0.6;
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
