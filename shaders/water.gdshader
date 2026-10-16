shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// A lake at night: deep blue-black in the middle, lighter and greener toward its shore with a pale
// line where it laps the bank, slow rings spreading over it, and ripples catching the moon in glints
// that wander about. Bent with the world.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.03, 0.07, 0.16);
uniform vec3 shallow : source_color = vec3(0.08, 0.2, 0.26);
uniform vec3 glint : source_color = vec3(0.8, 0.86, 1.0);

void fragment() {
	vec2 p = world.xz;
	float out_r = length(UV - 0.5) * 2.0;
	float shore = smoothstep(0.5, 0.95, out_r);
	float lap = smoothstep(0.9, 0.97, out_r) * (0.6 + 0.4 * sin(TIME * 1.3 + atan(UV.y - 0.5, UV.x - 0.5) * 7.0));
	float ripple = sin(p.x * 1.7 + TIME * 1.1) * sin(p.y * 1.3 - TIME * 0.8) + 0.6 * sin((p.x + p.y) * 2.3 + TIME * 1.6);
	float sparkle = smoothstep(1.2, 1.5, ripple);
	// (rings spreading out from a couple of wandering spots, as from something rising to the surface)
	vec2 c1 = vec2(sin(TIME * 0.13) * 3.0, cos(TIME * 0.11) * 3.0);
	float rings = smoothstep(0.85, 1.0, sin(length(p - floor(p / 9.0) * 9.0 - 4.5 - c1 * 0.3) * 4.0 - TIME * 2.2));
	vec3 col = mix(deep, shallow, shore) + glint * sparkle * 0.55 + vec3(0.12, 0.16, 0.2) * rings * (1.0 - shore) * 0.6;
	ALBEDO = col + vec3(0.35, 0.4, 0.38) * lap;
}
