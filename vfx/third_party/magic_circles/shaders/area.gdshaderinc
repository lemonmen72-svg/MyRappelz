// Shared by every Magic Circles shader. MagicArea sets these uniforms; the including shader sets
// its render_mode, ends with area_color() and discards where that returns alpha below 0.

uniform vec4 color : source_color = vec4(0.85, 0.75, 1.0, 1.0);       // the core: lines, hot spots
uniform vec4 edge_color : source_color = vec4(0.4, 0.3, 1.0, 1.0);   // the glow round them
uniform float energy : hint_range(0.0, 4.0) = 1.2;   // over 1 blooms under an Environment's glow
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float grow : hint_range(0.0, 1.0) = 1.0;     // 0 to 1 as the effect forms
uniform float age = 0.0;                             // seconds, times the node's speed
uniform float seed = 0.0;
uniform float sides : hint_range(3.0, 8.0, 1.0) = 6.0;   // points of the circle's star, cells of the dome
uniform float turbulence : hint_range(0.0, 1.0) = 0.3;
// 0 smooth, 1 dither (the PS1's 4x4 ordered dither, as solid pixels), 2 cutout
uniform int transparency : hint_range(0, 2) = 0;
uniform float dither_size : hint_range(1.0, 8.0, 1.0) = 1.0;   // screen pixels per dither cell

// Integer hash: a float hash of large coordinates tears noise into steps on some GPUs.
float area_hash_i(ivec2 i) {
	uvec2 q = uvec2(i) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

float area_hash(float x) {
	return area_hash_i(ivec2(int(floor(x)), int(seed * 37.0) + 11));
}

// i wrapped into 0..n-1, safe for negatives (% on negative ints is undefined in shaders).
int area_wrap(int i, float n) {
	return i - int(n) * int(floor((float(i) + 0.5) / n));
}

// Value noise; with period > 0 it tiles across x every `period` units, for round meshes' seams.
float area_noise(vec2 p, float period) {
	vec2 fl = floor(p);
	vec2 f = p - fl;
	f = f * f * (3.0 - 2.0 * f);
	int x0 = int(fl.x);
	int x1 = x0 + 1;
	int y0 = int(fl.y) + int(seed * 37.0) * 101;
	if (period > 0.0) {
		x0 = area_wrap(x0, period);
		x1 = area_wrap(x1, period);
	}
	return mix(mix(area_hash_i(ivec2(x0, y0)), area_hash_i(ivec2(x1, y0)), f.x),
			mix(area_hash_i(ivec2(x0, y0 + 1)), area_hash_i(ivec2(x1, y0 + 1)), f.x), f.y);
}

// 0..1, spread to cover the range.
float area_fbm(vec2 p, float period) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * area_noise(p, period);
		p = p * 2.0 + vec2(0.0, 17.0);
		period *= 2.0;
		a *= 0.5;
	}
	return clamp((v - 0.12) / 0.68, 0.0, 1.0);
}

float area_line(float d, float w) {
	return smoothstep(w, w * 0.35, abs(d));
}

// One rune: up to five strokes picked by h, in a cell q (x across, y outwards, both 0..1).
float area_rune(vec2 q, float h, float w) {
	float bits = floor(h * 31.0) + 1.0;
	float s = 0.0;
	s += step(0.5, mod(bits, 2.0)) * area_line(q.x - 0.5, w) * step(abs(q.y - 0.5), 0.36);
	s += step(0.5, mod(floor(bits / 2.0), 2.0)) * area_line(q.y - 0.84, w) * step(abs(q.x - 0.5), 0.26);
	s += step(0.5, mod(floor(bits / 4.0), 2.0)) * area_line(q.y - 0.16, w) * step(abs(q.x - 0.5), 0.26);
	s += step(0.5, mod(floor(bits / 8.0), 2.0)) * area_line((q.y - 0.5) - (q.x - 0.5) * 1.3, w)
			* step(abs(q.x - 0.5), 0.26);
	s += step(0.5, mod(floor(bits / 16.0), 2.0)) * area_line(length(q - vec2(0.5, 0.5)) - 0.2, w);
	return clamp(s, 0.0, 1.0);
}

float area_bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float area_bayer4(vec2 a) {
	return area_bayer2(0.5 * a) * 0.25 + area_bayer2(a);
}

// heat 1 is the core colour, 0 the edge's; a is how much covers the pixel.
vec4 area_color(float heat, float a, vec2 frag) {
	vec4 c = mix(edge_color, color, clamp(heat, 0.0, 1.0));
	a = clamp(a * c.a * intensity, 0.0, 1.0);
	if (transparency == 1) {
		a = a > area_bayer4(frag / dither_size) * 0.94 + 0.03 ? 1.0 : -1.0;
	} else if (transparency == 2) {
		a = a >= 0.5 ? 1.0 : -1.0;
	}
	return vec4(c.rgb * energy, a);
}
