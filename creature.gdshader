// Тело зверя или питомца (CreatureModels): все детали модели слиты в один меш, цвет детали —
// в цвете вершин. Свет как у Util.mat (StandardMaterial3D): toon-свет, toon-блик, подсветка края.
// UV.x = 1 — деталь освещается; 0 — без освещения (глаза, блики, руны, светящиеся детали).
// UV.y — есть ли у детали контур (читает creature_outline.gdshader).
// flash — белая вспышка при ударе (CreatureModels.flash), только у освещаемых деталей.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Цвета вершин записаны в sRGB (как vertex_color_is_srgb у StandardMaterial3D)
	if (!OUTPUT_IS_SRGB) {
		vec3 c = COLOR.rgb;
		COLOR.rgb = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	}
}

void fragment() {
	float lit = step(0.5, UV.x);
	vec3 c = mix(COLOR.rgb, vec3(1.0), flash * lit);
	ALBEDO = c * lit;
	EMISSION = c * (1.0 - lit);
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.25 * lit;
	RIM = 0.3 * lit;
	RIM_TINT = 0.7;
}
