shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// The ship's shield: hardly there at rest, only a faint line of light sweeping up the bubble now and
// then. A hit flashes where it struck and sends a ring of light rippling out round the bubble from
// there. `strength` (how much shield is left) dims the line.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.4, 0.85, 1.0);
uniform float strength = 1.0;
// Where the last hit struck (a direction from the bubble's middle, in its own terms), and how long
// ago (seconds; large when none)
uniform vec3 hit_dir = vec3(0.0, 0.0, 1.0);
uniform float hit_age = 9.0;

void fragment() {
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	// (the line runs bottom to top over 2.5 s, then rests for a moment)
	float sweep = fract(TIME * 0.3) * 1.3 - 0.15;
	float line = exp(-pow((1.0 - UV.y - sweep) * 28.0, 2.0));
	vec3 c = tint * line * (0.12 + 0.35 * edge) * strength;
	// the ripple: a ring running out from the hit round the bubble, fading as it goes, and a flash
	// at the very spot
	float apart = acos(clamp(dot(normalize(local), normalize(hit_dir)), -1.0, 1.0));
	float front = hit_age * 4.2;
	float fade = clamp(1.0 - hit_age / 0.75, 0.0, 1.0);
	float ring = exp(-pow((apart - front) * 7.0, 2.0)) * fade;
	float spot = exp(-apart * apart * 18.0) * clamp(1.0 - hit_age * 5.0, 0.0, 1.0);
	c += mix(tint, vec3(1.0, 0.55, 0.4), 0.5) * (ring * (0.6 + edge * 0.8) + spot * 1.6);
	ALBEDO = c;
}
