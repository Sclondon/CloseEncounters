shader_type canvas_item;
// The dark laid over the picture while the Moon Market is open (see main.gd _picker_dim), with a soft
// hole in it where the market's saucer hangs, so the saucer stays lit, not dimmed

uniform float dark = 0.55;
// Where the saucer is, in the dark's own terms, and how big a hole round it
uniform vec2 hole = vec2(-10000.0, -10000.0);
uniform float radius = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float d = distance(local, hole);
	COLOR = vec4(0.0, 0.0, 0.0, dark * smoothstep(radius * 0.55, radius * 1.25, d));
}
