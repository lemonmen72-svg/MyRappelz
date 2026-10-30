// Флажок на шесте: полотнище волнуется (UV.x — от шеста к концу), полоса посередине, toon-свет.
shader_type spatial;
render_mode cull_disabled;

#include "res://world_common.gdshaderinc"

uniform vec3 main_color : source_color = vec3(0.16, 0.66, 0.74);
uniform vec3 stripe_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 3.2 - k * 5.0 + phase) * 0.16 * k;
	VERTEX.y += sin(TIME * 2.1 - k * 3.0 + phase) * 0.04 * k;
}

void fragment() {
	float stripe = step(0.38, UV.y) * step(UV.y, 0.62);
	stripe = max(stripe, step(UV.x, 0.08));
	ALBEDO = mix(main_color, stripe_color, stripe);
}

void light() {
	DIFFUSE_LIGHT += wc_toon(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR);
}
