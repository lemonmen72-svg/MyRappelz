// Контур растительности и камней (вывернутая оболочка, как outline.gdshader), но раздувание вдоль
// нормали вершины, а не от центра меша: деревья, кусты и камни слиты в один меш на участок
// (IslandVegetation), и центр меша у них общий. Толщина почти постоянна на экране.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.1, 0.16, 0.08, 1.0);
// Толщина контура в метрах на расстоянии 10 м от камеры.
uniform float width = 0.02;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 n = length(NORMAL) > 0.0001 ? normalize(NORMAL) : vec3(0.0, 1.0, 0.0);
	VERTEX += n * width * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
}

void fragment() {
	ALBEDO = color.rgb;
}
