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

vec3 bent(vec3 w) {
	float d = w.z - bend_focus.z;
	d = d < 0.0 ? d : d * 0.45;
	float s = w.x - bend_focus.x;
	w.y -= bend_k * (d * d + 0.3 * s * s);
	return w;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(bent(world), 1.0));
	if (clip.w > 0.0) {
		vec2 grid = VIEWPORT_SIZE * 0.5;
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
	affine = vec3(UV * clip.w, clip.w);
}
