shader_type spatial;
// Every lit surface (see scripts/ps1.gd): Cryptlins' PS1 shader, on the bent world.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D tex : source_color, filter_nearest, hint_default_white;
uniform float glow = 0.0;
uniform float rim = 0.0;
// A flash when something is hit or lit up by the beam
uniform vec3 flash : source_color = vec3(0.0);

void fragment() {
	vec3 c = tint * texture(tex, affine.xy / affine.z).rgb;
	ALBEDO = c;
	EMISSION = c * glow + flash;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	RIM = rim;
	RIM_TINT = 0.7;
}
