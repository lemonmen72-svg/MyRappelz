shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The magic circle on the ground: rings, a band of runes turning one way and a star the other.
// It draws itself round as it grows.
#include "area.gdshaderinc"

// Distance to the star polygon {n/k} in radius r turned by rot, with a ring round each point.
float star(vec2 p, float n, float k, float r, float rot, float dot_r) {
	float d = 1e3;
	for (int i = 0; i < 8; i++) {
		if (float(i) >= n) {
			break;
		}
		float a0 = rot + TAU * float(i) / n;
		float a1 = rot + TAU * (float(i) + k) / n;
		vec2 a = r * vec2(cos(a0), sin(a0));
		vec2 ba = r * vec2(cos(a1), sin(a1)) - a;
		vec2 pa = p - a;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		d = min(d, length(pa - ba * h));
		if (dot_r > 0.0) {
			d = min(d, abs(length(pa) - dot_r));
		}
	}
	return d;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float turn = fract(ang / TAU + 0.5);
	float w = max(fwidth(r) * 1.3, 0.007);
	float wob = (area_noise(vec2(turn * 24.0, age * 3.0), 24.0) - 0.5) * turbulence * 0.035;
	float rr = r + wob;
	float rings = area_line(rr - 0.955, w * 1.6) + area_line(rr - 0.915, w) + area_line(rr - 0.745, w)
			+ area_line(rr - 0.705, w * 1.5) + area_line(rr - 0.3, w);
	float cells = 28.0;
	float band = fract(turn + age * 0.025);
	float cell = floor(band * cells);
	vec2 q = vec2(fract(band * cells), (r - 0.75) / 0.16);
	float runes = step(abs(r - 0.83), 0.08) * area_rune(q, area_hash(cell + 7.0), 0.09);
	float k = sides >= 7.0 ? 3.0 : (sides >= 5.0 ? 2.0 : 1.0);
	float rot = -age * 0.12 + seed;
	float figure = 0.0;
	if (r < 0.75) {
		figure = area_line(star(p, sides, k, 0.69, rot, 0.0), w * 1.3)
				+ area_line(star(p, sides, 1.0, 0.69, rot, 0.06), w) * 0.7
				+ area_line(star(p, sides, k, 0.3, -rot * 1.6, 0.0), w) * 0.8;
	}
	float centre = area_line(r - 0.11, w) + smoothstep(0.08, 0.0, r) * 0.7;
	float shape = clamp(rings + runes + figure + centre, 0.0, 1.0);
	shape *= 1.0 - turbulence * 0.35 * area_noise(vec2(age * 7.0, 3.0), 0.0);
	float pulse = 0.85 + 0.15 * sin(age * 3.0 + seed);
	float halo = exp(-abs(r - 0.83) * 9.0) * 0.3 + exp(-r * 3.0) * 0.2;
	float reveal = 1.0 - step(grow, fract(turn + 0.25));
	float a = (shape * pulse + halo * (1.0 - shape)) * reveal * smoothstep(1.0, 0.97, r);
	vec4 o = area_color(shape * pulse, a, FRAGCOORD.xy);
	if (o.a < 0.0) {
		discard;
	}
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
