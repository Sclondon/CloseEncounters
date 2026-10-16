shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// A drive-in's film: a flipbook of `frames` pictures (`across` to a row) played at `fps`, glowing
// out of the dark a little flickery, as a projector throws it. Bent with the world.

#include "res://shaders/bend.gdshaderinc"

uniform sampler2D film : source_color, filter_nearest;
uniform float frames = 80.0;
uniform float across = 8.0;
uniform float down = 10.0;
uniform float fps = 15.0;
uniform float start = 0.0;

void fragment() {
	float f = mod(floor((TIME + start) * fps), frames);
	vec2 cell = vec2(mod(f, across), floor(f / across));
	vec2 uv = (cell + UV) / vec2(across, down);
	float flicker = 0.9 + 0.1 * fract(sin(floor(TIME * 24.0)) * 43758.5);
	ALBEDO = texture(film, uv).rgb * 1.25 * flicker;
}
