shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// The ship's shield: hardly there at rest, only a faint line of light sweeping up the bubble now and
// then; a hit flares the whole bubble. `strength` (how much shield is left) dims the line.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.4, 0.85, 1.0);
uniform float strength = 1.0;
uniform float hit = 0.0;

void fragment() {
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	// (the line runs bottom to top over 2.5 s, then rests for a moment)
	float sweep = fract(TIME * 0.3) * 1.3 - 0.15;
	float line = exp(-pow((1.0 - UV.y - sweep) * 28.0, 2.0));
	vec3 c = mix(tint, vec3(1.0, 0.45, 0.35), hit);
	ALBEDO = c * (line * (0.12 + 0.35 * edge) * strength + hit * (0.15 + edge * 0.8));
}