shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;
// What the wind carries, dust haze and rain, moved in the shader: each quad (UV its corner -1..1,
// UV2.x its number) works out where it is from `age`, so nothing runs on the CPU. Every pass
// re-rolls a piece's randoms.
#include "storm.gdshaderinc"

// 0 gust (along -Z through a box 2 radius wide and 3.2 long), 1 swirl, 2 tornado (up the funnel),
// 3 burst (out from the centre, once from `fired`), 4 rain (down through a disc from `height`)
uniform int motion : hint_range(0, 4) = 0;
// 0 grain, 1 leaf, 2 flake, 3 petal, 4 ash (a quarter of it embers, in tint_b), 5 puff of dust
// (edge_color), 6 drop
uniform int shape : hint_range(0, 6) = 0;
uniform float size = 0.08;      // metres, half across
uniform vec4 tint_a : source_color = vec4(1.0);
uniform vec4 tint_b : source_color = vec4(1.0);
uniform float period = 1.6;     // seconds a piece takes through, give or take a third
uniform float fall = 0.0;       // metres a piece drops over its pass (below 0 rises)
uniform float flutter = 0.2;    // metres it wanders off its course
uniform float stretch = 0.0;    // drawn longer along its motion: sand, rain

varying vec4 rnd;
varying float fade;
varying float above;   // metres over the node's ground, for a puff to fade into it

vec3 debris_at(float t, vec4 h) {
	if (motion == 1) {
		float a = h.x * TAU + t * mix(1.5, 3.0, h.y) * TAU;
		float r = radius * mix(0.2, 1.0, h.z) * (1.0 - 0.3 * t);
		return vec3(cos(a) * r, 0.05 + height * mix(0.1, 0.6, h.w) * t, sin(a) * r);
	}
	if (motion == 2) {
		float r = radius * (0.12 + 0.88 * pow(t, 1.5)) * mix(0.8, 1.5, h.z) + flutter * sin(t * 13.0 + h.w * TAU);
		float a = h.x * TAU + t * mix(2.5, 4.5, h.y) * TAU;
		return vec3(cos(a) * r, height * t, sin(a) * r);
	}
	if (motion == 3) {
		float e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
		float r = radius * (0.1 + mix(0.5, 1.1, h.z) * e);
		float y = 0.04 + 4.0 * t * (1.0 - t) * height * 0.3 * h.y - fall * t * t;
		return vec3(cos(h.x * TAU) * r, max(y, 0.03), sin(h.x * TAU) * r);
	}
	if (motion == 4) {
		float r = sqrt(h.x) * radius;
		return vec3(cos(h.y * TAU) * r, height * (1.0 - t), sin(h.y * TAU) * r);
	}
	float l = radius * 1.6;
	vec3 p = vec3((h.x * 2.0 - 1.0) * radius, mix(0.05, height, h.y * h.y), l - 2.0 * l * t);
	p.x += sin(t * 9.0 + h.z * TAU) * flutter;
	p.y = max(p.y - fall * t + sin(t * 7.0 + h.w * TAU) * flutter * 0.6, 0.03);
	return p;
}

void vertex() {
	float id = UV2.x;
	vec4 h0 = storm_hash4(id, -1.0);
	float t;
	float pass;
	if (motion == 3) {
		t = (age - fired) / (period * mix(0.6, 1.0, h0.w));
		fade = step(0.0, t) * step(t, 1.0);
		t = clamp(t, 0.0, 1.0);
		pass = floor(fired * 3.0);
	} else {
		float p = age / (period * mix(0.7, 1.4, h0.w)) + h0.x;
		pass = floor(p);
		t = fract(p);
		fade = 1.0;
	}
	rnd = storm_hash4(id, pass);
	fade *= smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.8, t);
	vec3 at = debris_at(t, rnd);
	vec3 v0 = (MODELVIEW_MATRIX * vec4(at, 1.0)).xyz;
	vec2 way = (MODELVIEW_MATRIX * vec4(debris_at(t + 0.01, rnd), 1.0)).xy - v0.xy;
	float spin = rnd.z * TAU + age * mix(-4.0, 4.0, rnd.y);
	vec2 axis = vec2(sin(spin), cos(spin));
	vec2 s = vec2(size * mix(0.7, 1.3, rnd.w));
	if (stretch > 0.0 && length(way) > 1e-5) {
		axis = normalize(way);
		s.y += min(stretch * length(way), s.x * 8.0);   // a fast grain a streak, not a straw
	}
	if (shape == 1 || shape == 3) {   // tumbling
		s.x *= mix(0.25, 1.0, abs(cos(age * mix(2.0, 5.0, rnd.x) + rnd.w * 6.0)));
	}
	VERTEX = v0 + vec3(axis * UV.y * s.y + vec2(axis.y, -axis.x) * UV.x * s.x, 0.0);
	above = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 q = UV;
	float r = length(q);
	vec3 c = mix(tint_a.rgb, tint_b.rgb, rnd.y);
	float a = mix(tint_a.a, tint_b.a, rnd.y);
	if (shape == 1) {   // leaf: a pointed oval, a darker midrib, a stem
		float lens = max(length(q - vec2(0.62, 0.0)), length(q + vec2(0.62, 0.0)));
		a *= max(smoothstep(1.0, 0.94, lens), smoothstep(0.07, 0.0, abs(q.x)) * step(q.y, -0.6));
		c *= (1.0 - 0.35 * smoothstep(0.06, 0.0, abs(q.x))) * (0.85 + 0.25 * q.y);
	} else if (shape == 2) {   // flake: a soft dot with six arms
		float a6 = mod(atan(q.y, q.x) + PI / 6.0, PI / 3.0) - PI / 6.0;
		a *= max(exp(-r * r * 9.0), smoothstep(0.14, 0.04, r * abs(sin(a6))) * smoothstep(0.95, 0.6, r) * 0.8);
	} else if (shape == 3) {   // petal: round, notched at its tip, pale at its foot
		a *= smoothstep(0.85, 0.75, length(q * vec2(1.25, 1.0) + vec2(0.0, 0.1)))
				* smoothstep(0.15, 0.3, length(q - vec2(0.0, 0.85)));
		c = mix(c, vec3(1.0), smoothstep(0.7, 0.0, length(q + vec2(0.0, 0.6))) * 0.6);
	} else if (shape == 4) {   // ash, or an ember
		if (rnd.x < 0.25) {
			a = exp(-r * r * 6.0) * tint_b.a;
			c = tint_b.rgb * energy * (0.7 + 0.5 * sin(age * 9.0 + rnd.w * 20.0));
		} else {
			a = tint_a.a * smoothstep(0.75, 0.55, r + (storm_noise(q * 2.5 + rnd.zw * 40.0, 0.0) - 0.5) * 0.7);
			c = tint_a.rgb * mix(0.6, 1.1, rnd.y);
		}
	} else if (shape == 5) {   // a puff of dust
		float n = storm_fbm(q * 1.6 + rnd.xy * 30.0 + vec2(age * 0.25, 0.0), 0.0);
		a = edge_color.a * smoothstep(1.0, 0.1, r) * (0.3 + 0.7 * n) * 0.45
				* smoothstep(0.0, size * 0.6, above);
		c = edge_color.rgb;
	} else if (shape == 6) {   // drop
		a *= smoothstep(1.0, 0.1, abs(q.x)) * smoothstep(1.0, 0.4, abs(q.y));
	} else {   // grain
		a *= exp(-r * r * 4.0);
	}
	a = storm_alpha(a * fade, FRAGCOORD.xy);
	if (a < 0.0) {
		discard;
	}
	ALBEDO = c;
	ALPHA = a;
}
