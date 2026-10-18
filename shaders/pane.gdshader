shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// A pane of glass (a car's windows, a phone booth's sides...: ps1.gd _pane), pale blue and mostly
// clear, with a sheen toward its edges. Bent with the world and snapped to its pixels like the rest
// of the model it is set in (bend.gdshaderinc): a plain material stayed where the world was before it
// bent, and floated up off its car the further off toward the horizon the car was.

#include "res://shaders/bend.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.7, 0.85, 1.0, 0.3);

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), VIEW)), 0.0, 1.0);
	ALBEDO = colour.rgb;
	ALPHA = clamp(colour.a + (1.0 - facing) * 0.35, 0.0, 0.85);
	ROUGHNESS = 0.1;
	SPECULAR = 0.9;
}
