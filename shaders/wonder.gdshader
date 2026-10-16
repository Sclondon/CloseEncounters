shader_type spatial;
// A question mark over a cop's head, facing the camera, lit from the bottom up as `fill` rises
// (see thing.gd _wonder): grey while they are not sure, coloured once they have seen enough.
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, fog_disabled;

uniform float fill = 0.0;
uniform vec4 lit : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float pop = 0.0;
// (once they are sure: an exclamation mark instead)
uniform bool bang = false;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= 1.0 + pop * 0.5;
}

// How far out of the question mark's shape p is (inside below 0); x -1 to 1, y -1.5 (top) to 1.5
float mark(vec2 p) {
	vec2 c = vec2(0.0, -0.7);
	float ring = abs(length(p - c) - 0.52) - 0.17;
	// (the hook: all of the ring but its lower left)
	if (p.x < 0.0 && p.y > c.y) ring = 9.0;
	vec2 s = vec2(abs(p.x) - 0.17, max(p.y - 0.45, -0.18 - p.y));
	float stem = length(max(s, 0.0)) + min(max(s.x, s.y), 0.0);
	float dot_ = length(p - vec2(0.0, 1.08)) - 0.22;
	return min(min(ring, stem), dot_);
}

// An exclamation mark: a bar tapering down, and its dot
float exclaim(vec2 p) {
	vec2 s = vec2(abs(p.x) - (0.24 - 0.08 * (p.y + 1.4) / 1.9), max(p.y - 0.5, -1.4 - p.y));
	float bar = length(max(s, 0.0)) + min(max(s.x, s.y), 0.0);
	return min(bar, length(p - vec2(0.0, 1.05)) - 0.24);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, 3.0);
	float d = bang ? exclaim(p) : mark(p);
	if (d > 0.1) discard;
	float level = 1.5 - 3.0 * fill;
	vec3 c = p.y > level ? lit.rgb : vec3(0.42, 0.44, 0.46);
	ALBEDO = d > 0.0 ? vec3(0.02) : c;
	ALPHA = 0.95;
}
