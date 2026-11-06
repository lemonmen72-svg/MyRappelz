shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Rings that keep spreading out from the centre over the ground and fade at the edge, broken into
// arcs; they reach further as it grows.
#include "area.gdshaderinc"

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float turn = fract(atan(p.y, p.x) / TAU + 0.5);
	float w = max(fwidth(r), 0.006);
	float wob = (area_noise(vec2(turn * 12.0, r * 4.0 - age), 12.0) - 0.5) * turbulence * 0.12;
	float rings = 0.0;
	for (int i = 0; i < 4; i++) {
		float ph = fract(age * 0.45 + float(i) * 0.25);
		float width = 0.012 + ph * 0.05;
		rings += smoothstep(width + w, 0.0, abs(r + wob - ph * grow)) * (1.0 - ph) * smoothstep(0.0, 0.12, ph);
	}
	float arcs = mix(1.0, smoothstep(0.3, 0.6, area_noise(vec2(turn * 10.0, age * 0.3 + r), 10.0)), 0.6);
	float shape = clamp(rings * arcs * 1.3, 0.0, 1.0);
	float centre = exp(-r * 6.0) * (0.55 + 0.2 * sin(age * 4.0 + seed));
	float rim = area_line(r - 0.96, w * 1.5) * 0.35 * grow;
	float a = (shape + centre + rim) * smoothstep(1.0, 0.97, r);
	vec4 o = area_color(shape + centre * 0.8, a, FRAGCOORD.xy);
	if (o.a < 0.0) {
		discard;
	}
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
