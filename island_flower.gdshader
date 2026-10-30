// Цветы острова (MultiMesh участками, IslandVegetation): цвет вершин (стебель, серединка), лепестки
// (UV.x = 1) красятся цветом экземпляра INSTANCE_CUSTOM.rgb (линейный), INSTANCE_CUSTOM.a — фаза.
// Лёгкое покачивание от ветра и плавное исчезновение вдали (fade_start..fade_end, м).
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://world_common.gdshaderinc"

uniform vec2 wind_dir = vec2(0.86, 0.5);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.5;
uniform float fade_start = 24.0;
uniform float fade_end = 34.0;

varying vec3 v_color;

void vertex() {
	float h = UV.y;
	vec3 root = MODEL_MATRIX[3].xyz;
	float height = length(MODEL_MATRIX[1].xyz);
	v_color = mix(COLOR.rgb, INSTANCE_CUSTOM.rgb, UV.x);

	float t = TIME * wind_speed + INSTANCE_CUSTOM.a * 6.28;
	float ph = dot(root.xz, wind_dir) * 0.15;
	float wave = sin(t + ph) * 0.5 + 0.5;
	float bend = h * h * height * wind_strength * (0.3 + wave * 0.9);
	VERTEX.xz += wind_dir * bend;

	float k = 1.0 - smoothstep(fade_start, fade_end, distance(root, CAMERA_POSITION_WORLD));
	VERTEX = root + (VERTEX - root) * k;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = v_color;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void light() {
	DIFFUSE_LIGHT += wc_toon(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR);
}
