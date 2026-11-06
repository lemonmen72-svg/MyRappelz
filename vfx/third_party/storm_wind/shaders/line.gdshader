shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;
// Wind lines: a streak running along each path, the path a ribbon turned to the camera. UV.x is
// how far along its path, UV2 (half-width, the line's phase 0 to 1), COLOR.r its own random. Each
// pass sets the path down somewhere new within `scatter` (the node's space), so passes differ.
#include "storm.gdshaderinc"

uniform float period = 1.6;   // seconds a streak takes along its path
uniform float trail : hint_range(0.05, 1.0) = 0.4;   // a streak's length, of its path's
uniform vec3 scatter = vec3(0.0);
uniform float burst = 0.0;    // 1: every line runs once from `fired` instead of looping
uniform float thickness : hint_range(0.0, 4.0) = 1.0;

varying float head;

void vertex() {
	float phase = UV2.y;
	float pass = 0.0;
	if (burst > 0.5) {
		head = ((age - fired) / period - phase * 0.12) * (1.0 + trail);
	} else {
		float p = age / period + phase;
		pass = floor(p);
		head = fract(p) * (1.0 + trail);
	}
	vec4 h = storm_hash4(COLOR.r * 251.0, pass);
	VERTEX += (h.xyz * 2.0 - 1.0) * scatter;
	VERTEX = storm_ribbon(MODELVIEW_MATRIX, VERTEX, NORMAL, UV.y, UV2.x * thickness);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float d = head - UV.x;   // 0 at the streak's head, trail at its tail
	float k = clamp(d / trail, 0.0, 1.0);
	// a wisp: it swells in behind a soft head, thickest a fifth of the way back, and thins away
	float swell = smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.2, 1.0, k));
	float across = abs(UV.y) / max(mix(0.3, 1.0, swell), 0.05);
	float body = smoothstep(1.0, 0.2, across) * step(0.0, d) * swell;
	float ends = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.9, UV.x);
	float a = storm_alpha(body * ends * color.a, FRAGCOORD.xy);
	if (a < 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = a;
}
