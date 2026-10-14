shader_type spatial;
// Every lit surface (see scripts/ps1.gd): Cryptlins' PS1 shader, on the bent world.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D tex : source_color, filter_nearest, hint_default_white;
uniform float glow = 0.0;
uniform float rim = 0.0;
// A flash when something is hit or lit up by the beam
uniform vec3 flash : source_color = vec3(0.0);
// Anything standing between the camera and the saucer is drawn in a see-through checker, so the
// saucer is never lost behind a mesa, a peak or a barn
global uniform vec3 saucer_pos;

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 line = saucer_pos - eye;
	float along = dot(world - eye, line) / dot(line, line);
	float off = length(world - eye - line * clamp(along, 0.0, 1.0));
	if (along > 0.0 && along * length(line) < length(line) - 3.5 && off < 4.5) {
		if ((int(FRAGCOORD.x) + int(FRAGCOORD.y)) % 2 == 0) discard;
	}
	// (a merged model carries each part's colour on its corners, and how much it glows in their alpha:
	// see ps1.gd _merged; anything else has white corners)
	vec3 c = tint * COLOR.rgb * texture(tex, affine.xy / affine.z).rgb;
	ALBEDO = c;
	EMISSION = c * (glow + (1.0 - COLOR.a) * 3.2) + flash;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	RIM = rim;
	RIM_TINT = 0.7;
}
