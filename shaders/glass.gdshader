shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// The saucer's dome: clear in the middle, frosted and bright at the rim, so the pilot shows through.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.6, 0.85, 1.0);

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint;
	EMISSION = tint * edge * 0.5;
	ALPHA = 0.12 + 0.6 * pow(edge, 2.0);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
