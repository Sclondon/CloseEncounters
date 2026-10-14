shader_type spatial;
render_mode unshaded;
// Flat colour that takes no light: the alien's eyes, tracer shots, flashes.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	ALBEDO = tint;
}
