shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// A lake at night: deep blue-black, lighter toward its shore, ripples catching the moon in glints
// that wander about. Bent with the world.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.03, 0.06, 0.14);
uniform vec3 shallow : source_color = vec3(0.08, 0.16, 0.26);
uniform vec3 glint : source_color = vec3(0.75, 0.82, 1.0);

void fragment() {
	vec2 p = world.xz;
	float shore = smoothstep(0.55, 1.0, length(UV - 0.5) * 2.0);
	float ripple = sin(p.x * 1.7 + TIME * 1.1) * sin(p.y * 1.3 - TIME * 0.8) + 0.6 * sin((p.x + p.y) * 2.3 + TIME * 1.6);
	float sparkle = smoothstep(1.25, 1.5, ripple);
	ALBEDO = mix(deep, shallow, shore) + glint * sparkle * 0.5;
}
