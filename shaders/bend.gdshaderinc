// The world rolls away from the saucer like the top of a log (the Animal Crossing bend): every point
// is dropped by the square of how far it lies from `bend_focus` (the ground under the saucer), most
// toward the horizon, less to the sides and toward the camera. Then, as in Cryptlins, corners land
// on whole pixels of the low-resolution picture and textures stretch flat across each triangle.
// Everything solid includes this, so the whole world bends together. `world` is the point as it is
// before the bend (for patterns painted on the ground).

global uniform vec3 bend_focus;
global uniform float bend_k;

varying vec3 affine;
varying vec3 world;
// The point in its own model's terms, and which simple texture its material has (ps1.gd PATTERNS)
varying vec3 local;
varying float pattern;
// How much it sways in the wind (a grown tree's leaves: ps1.gd GROWN), and so whether it is leaves
varying float sway;
// A crowd drawn many to a MultiMesh (the arena's audience): how excited they are (0 still), each
// bobbing and swaying to its own beat (its INSTANCE_CUSTOM: r its phase, g its pace)
uniform float cheer = 0.0;

vec3 bent(vec3 w) {
	float d = w.z - bend_focus.z;
	d = d < 0.0 ? d : d * 0.45;
	float s = w.x - bend_focus.x;
	w.y -= bend_k * (d * d + 0.3 * s * s);
	return w;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	pattern = UV2.x;
	sway = UV2.y;
	if (cheer > 0.0) {
		float phase = INSTANCE_CUSTOM.r * 6.2832;
		float pace = (2.2 + INSTANCE_CUSTOM.g * 1.6) * (0.7 + 0.3 * cheer);
		float hop = abs(sin(TIME * pace + phase));
		world.y += hop * 0.06 * cheer;
		world.x += sin(TIME * 1.7 + phase) * 0.035 * cheer * VERTEX.y;
	}
	if (sway > 0.0) {
		// (leaves moving in the wind: a slow lean, gusting through, and a quick flutter)
		float t = TIME + world.x * 0.21 + world.z * 0.13;
		float lean = sin(t * 0.9) * 0.6 + sin(t * 2.3 + 1.7) * 0.3;
		float flutter = sin(TIME * 7.0 + VERTEX.x * 3.1 + VERTEX.y * 2.3 + VERTEX.z * 2.7) * 0.25;
		world.x += (lean + flutter) * 0.13 * sway;
		world.z += (lean * 0.5 - flutter) * 0.08 * sway;
		world.y += flutter * 0.04 * sway;
	}
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(bent(world), 1.0));
	if (clip.w > 0.0) {
		vec2 grid = VIEWPORT_SIZE * 0.5;
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
	affine = vec3(UV * clip.w, clip.w);
}
