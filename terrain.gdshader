// Земля мира: луг с мягкими пятнами, тропинки с камешками от площадки к краям карты,
// каменная площадка в центре (кольца плит, бордюр, золотистая инкрустация), toon-свет.
shader_type spatial;
render_mode cull_back;

#include "res://world_common.gdshaderinc"

uniform vec3 dirt_light : source_color = vec3(0.70, 0.56, 0.38);
uniform vec3 dirt_dark : source_color = vec3(0.56, 0.42, 0.28);
uniform vec3 pebble_color : source_color = vec3(0.74, 0.70, 0.62);
uniform vec3 stone_light : source_color = vec3(0.62, 0.60, 0.58);
uniform vec3 stone_dark : source_color = vec3(0.46, 0.46, 0.48);
uniform vec3 border_stone : source_color = vec3(0.44, 0.46, 0.56);
uniform vec3 grout_color : source_color = vec3(0.40, 0.40, 0.38);
uniform vec3 inlay_color : source_color = vec3(0.88, 0.70, 0.36);
uniform float plaza_rings = 8.0;
// Дальше этого «квадратного радиуса» тропинки растворяются в лугу.
uniform float path_fade_start = 90.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Плиты площадки: концентрические кольца, в каждом кольце плиты длиной ~1.3 м.
vec3 plaza_color(vec2 p, float r, float px) {
	float ring_w = plaza_radius / plaza_rings;
	float rr = r / ring_w;
	float ri = floor(rr);
	float rf = fract(rr);
	float circ = TAU * (ri + 0.5) * ring_w;
	float nseg = max(3.0, floor(circ / 1.3));
	float a01 = fract(atan(p.y, p.x) / TAU + wc_hash(vec2(ri, 4.7)));
	float sa = a01 * nseg;
	float si = floor(sa);
	float sf = fract(sa);
	float d_ring = min(rf, 1.0 - rf) * ring_w;
	float d_seg = min(sf, 1.0 - sf) * circ / nseg;
	float d = ri < 1.0 ? (1.0 - rf) * ring_w : min(d_ring, d_seg);
	float g = 0.045;
	float grout = 1.0 - smoothstep(g - px, g + px, d);
	float th = wc_hash(vec2(ri * 3.1 + 0.7, si * 1.7 + ri));
	vec3 stone = mix(stone_dark, stone_light, 0.3 + 0.7 * th);
	if (ri >= plaza_rings - 1.0) {
		stone = border_stone * (0.9 + 0.18 * th);
	}
	stone *= 0.94 + 0.1 * wc_noise(p * 2.5);
	// Края плит чуть темнее: читается объём
	stone *= 0.9 + 0.1 * smoothstep(g, g + 0.18, d);
	// Золотистое кольцо в центре площадки
	float inlay = 1.0 - smoothstep(0.05 - px, 0.05 + px, abs(r - ring_w * 0.55));
	stone = mix(stone, inlay_color, inlay);
	return mix(stone, grout_color, grout);
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = length(p);
	float px = max(length(fwidth(p)), 0.002);

	// Луг
	vec3 col = wc_meadow(p);
	col *= 0.93 + 0.12 * wc_noise(p * 0.8 + 11.0);

	// Тропинки
	float pd = wc_path_dist(p) + (wc_noise(p * 0.55 + 3.1) - 0.5) * 0.8;
	float hw = path_width * 0.5;
	float sq = max(abs(p.x), abs(p.y));
	float fade = smoothstep(plaza_radius - 0.3, plaza_radius + 0.3, r)
		* (1.0 - smoothstep(path_fade_start, path_fade_start + 10.0, sq));
	float path_m = (1.0 - smoothstep(hw - px, hw + px, pd)) * fade;
	float rim = (1.0 - smoothstep(hw, hw + 0.5, pd)) * fade;
	// Притоптанная кромка травы у тропинки: чуть желтее
	col = mix(col, col * vec3(1.06, 1.02, 0.82), rim * (1.0 - path_m));
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.35, 0.65, wc_noise(p * 0.4 + 5.0)));
	vec2 cp = p * 2.4;
	vec2 cell = floor(cp);
	vec2 off = vec2(wc_hash(cell + 13.1), wc_hash(cell + 27.9)) * 0.5 + 0.25;
	float pr = 0.12 + 0.1 * wc_hash(cell + 41.3);
	float pe = px * 2.4;
	float peb = (1.0 - smoothstep(pr - pe, pr + pe, length(fract(cp) - off))) * step(0.7, wc_hash(cell));
	dirt = mix(dirt, pebble_color, peb);
	col = mix(col, dirt, path_m);

	// Площадка
	float plaza_m = 1.0 - smoothstep(plaza_radius - px, plaza_radius + px, r);
	if (plaza_m > 0.0) {
		col = mix(col, plaza_color(p, r, px), plaza_m);
	}
	ALBEDO = col;
}

void light() {
	DIFFUSE_LIGHT += wc_toon(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR);
}
