// Контур в аниме-стиле (метод «вывернутой оболочки»): второй проход материала рисует
// чуть раздутую копию меша только задними гранями, однотонным тёмным цветом.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.09, 0.14, 1.0);
// Толщина контура в метрах на расстоянии 10 м от камеры (дальше — пропорционально толще,
// чтобы на экране контур был примерно одинаковым).
uniform float width = 0.02;

void vertex() {
	// Раздуваем от центра меша: у примитивов (бокс, сфера, капсула) центр в нуле,
	// поэтому у углов бокса не будет разрывов, как при сдвиге по нормали.
	vec3 dir = length(VERTEX) > 0.0001 ? normalize(VERTEX) : NORMAL;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += dir * width * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
}

void fragment() {
	ALBEDO = color.rgb;
}
