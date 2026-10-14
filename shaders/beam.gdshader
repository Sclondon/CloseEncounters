shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// The tractor beam: a cone of green light from the saucer's belly to the ground, brightest along
// its edges, with rings of light running up it. `power` fades it in and out.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.55, 1.0, 0.65);
uniform float power = 1.0;

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float up = UV.y;
	float rings = 0.5 + 0.5 * sin(up * 40.0 + TIME * 9.0);
	float a = (0.12 + 0.55 * pow(edge, 3.0) + 0.12 * rings) * power;
	ALBEDO = tint * a * mix(1.0, 0.5, up);
}
