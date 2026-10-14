shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// An afterimage of the ship as it dashes: one colour, brightest at its edges, fading out.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.5, 1.0, 0.7);
uniform float alpha = 0.5;

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint * alpha * (0.35 + 0.65 * edge);
}