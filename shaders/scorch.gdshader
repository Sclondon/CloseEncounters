shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A burn the ship's laser leaves on the ground (see main.gd `_scorch`): a soft round mark, glowing
// hot at first and cooling to soot, bending with the world

#include "res://shaders/bend.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.2, 1.0);

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = tint.rgb;
	ALPHA = tint.a * smoothstep(1.0, 0.35, r);
}
