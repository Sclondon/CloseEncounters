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

// A simple texture over a material's colour, in the model's own terms (so a little house has little
// boards): 1 clapboard siding, 2 roof shingles, 3 brick, 4 planks
vec3 patterned(vec3 c, vec3 q) {
	if (pattern < 0.5) return c;
	if (pattern < 1.5) {
		// boards lapped one over the next, a dark line under each
		return c * (1.0 - 0.16 * step(0.78, fract(q.y / 0.32)));
	}
	if (pattern < 2.5) {
		// rows of shingles, each row's joints halfway along the last's, each shingle a shade apart
		float row = floor(q.y / 0.34);
		float along = (q.x + q.z) / 0.55 + row * 0.5;
		float edge = max(step(0.8, fract(q.y / 0.34)), step(0.88, fract(along)) * 0.8);
		float shade = fract(sin(dot(vec2(row, floor(along)), vec2(12.9898, 78.233))) * 43758.5453);
		return c * (1.0 - 0.2 * edge) * (0.92 + 0.14 * shade);
	}
	if (pattern < 3.5) {
		// courses of brick in pale mortar
		float row = floor(q.y / 0.2);
		float along = (q.x + q.z) / 0.42 + row * 0.5;
		float mortar = max(step(0.82, fract(q.y / 0.2)), step(0.9, fract(along)));
		return mix(c, vec3(0.62, 0.6, 0.56), mortar * 0.6);
	}
	// planks side by side
	return c * (1.0 - 0.18 * step(0.86, fract((q.x + q.z) / 0.28)));
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 line = saucer_pos - eye;
	float along = dot(world - eye, line) / dot(line, line);
	float off = length(world - eye - line * clamp(along, 0.0, 1.0));
	// (never the ship itself: nothing within 4 m of it, which a close camera, as on the moon, would
	// otherwise catch)
	if (along > 0.0 && along * length(line) < length(line) - 3.5 && off < 4.5 && length(world - saucer_pos) > 4.0) {
		if ((int(FRAGCOORD.x) + int(FRAGCOORD.y)) % 2 == 0) discard;
	}
	// (a merged model carries each part's colour on its corners, and how much it glows in their alpha:
	// see ps1.gd _merged; anything else has white corners)
	vec3 c = patterned(tint * COLOR.rgb * texture(tex, affine.xy / affine.z).rgb, local);
	ALBEDO = c;
	EMISSION = c * (glow + (1.0 - COLOR.a) * 3.2) + flash;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	RIM = rim;
	RIM_TINT = 0.7;
}
