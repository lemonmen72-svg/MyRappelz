shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The particles: a quad turned to face the camera, drawn as a mote, sparkle, snowflake, bubble,
// ember, wisp, leaf or drop. Each particle's colour (its fade in and out) comes in as COLOR.
#include "area.gdshaderinc"

// 0 mote, 1 sparkle, 2 flake, 3 bubble, 4 ember, 5 wisp, 6 leaf, 7 drop (its tip up)
uniform float shape : hint_range(0.0, 7.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float s;
	float heat;
	if (shape < 0.5) {
		s = exp(-r * r * 7.0);
		heat = exp(-r * r * 24.0) * 1.2;
	} else if (shape < 1.5) {
		vec2 q = abs(p);
		s = max(smoothstep(0.14, 0.0, q.x) * (1.0 - q.y), smoothstep(0.14, 0.0, q.y) * (1.0 - q.x))
				+ exp(-r * r * 18.0);
		heat = s;
	} else if (shape < 2.5) {
		float a6 = mod(atan(p.y, p.x) + PI / 6.0, PI / 3.0) - PI / 6.0;
		s = smoothstep(0.12, 0.03, r * abs(sin(a6))) * step(r, 0.9) + exp(-r * r * 20.0) * 0.5;
		heat = s;
	} else if (shape < 3.5) {
		s = smoothstep(0.14, 0.0, abs(r - 0.72)) + smoothstep(0.25, 0.0, length(p - vec2(-0.3, 0.3))) * 0.8
				+ 0.15 * step(r, 0.72);
		heat = 0.3 + 0.7 * smoothstep(0.25, 0.0, length(p - vec2(-0.3, 0.3)));
	} else if (shape < 4.5) {
		s = exp(-r * r * 9.0);
		heat = 1.0;
	} else if (shape < 5.5) {
		s = exp(-r * r * 3.0) * (0.3 + 0.4 * area_noise(p * 2.5 + vec2(seed * 3.0, age * 0.5), 0.0));
		heat = 1.0 - r * 0.6;
	} else if (shape < 6.5) {
		vec2 q = vec2(p.x + p.y, p.y - p.x) * 0.7071;
		float e = length(q * vec2(1.0, 2.3));
		s = smoothstep(0.85, 0.65, e) * (0.75 + 0.25 * smoothstep(0.1, 0.0, abs(q.y)));
		heat = 0.35 + 0.65 * smoothstep(0.08, 0.0, abs(q.y)) * step(abs(q.x), 0.75);
	} else {
		float up = 0.5 * sqrt(clamp((p.y + 0.9) / 1.2, 0.0, 1.0));
		s = p.y < 0.3 ? smoothstep(up, up * 0.6, abs(p.x)) * step(-0.9, p.y)
				: smoothstep(0.5, 0.36, length(vec2(p.x, p.y - 0.3)));
		heat = 0.35 + 0.65 * exp(-dot(p - vec2(-0.15, 0.35), p - vec2(-0.15, 0.35)) * 12.0);
	}
	vec4 o = area_color(heat, s * COLOR.a * step(r, 1.0), FRAGCOORD.xy);
	if (o.a < 0.0) {
		discard;
	}
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
