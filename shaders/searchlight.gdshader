shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A beam of light from a lamp, drawn as a single strip (a QuadMesh) laid along the beam and turned
// about it to face the camera, so there is no mesh to see: brightest down its middle and at the
// lamp, fading softly to its edges, to nothing along its length, where it meets the ground and close
// to the camera. The lamp is at the mesh's origin and the beam runs along its +Y for `reach`.
// Bent with the world and snapped to the low-res pixels like everything else (bend.gdshaderinc).

global uniform vec3 bend_focus;
global uniform float bend_k;

uniform vec3 tint : source_color = vec3(1.0, 0.95, 0.75);
uniform float power = 0.7;
uniform float reach = 28.0;
// Half its width at the lamp and at its far end
uniform float lamp_width = 0.25;
uniform float far_width = 3.2;
// How far along it has faded right away (1 for a beam that lights its whole length)
uniform float fade_at = 0.7;

varying vec3 world;
varying float across;
varying float along;
varying float facing;

vec3 bent(vec3 w) {
	float d = w.z - bend_focus.z;
	d = d < 0.0 ? d : d * 0.45;
	float s = w.x - bend_focus.x;
	w.y -= bend_k * (d * d + 0.3 * s * s);
	return w;
}

void vertex() {
	float t = VERTEX.y + 0.5;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 point = origin + axis * t * reach;
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - point);
	vec3 side = normalize(cross(axis, to_cam));
	world = point + side * VERTEX.x * 2.0 * mix(lamp_width, far_width, t);
	across = VERTEX.x * 2.0;
	along = t;
	// (seen end on, the strip is a sliver: let it go)
	facing = 1.0 - abs(dot(axis, to_cam));
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(bent(world), 1.0));
	if (clip.w > 0.0) {
		vec2 grid = VIEWPORT_SIZE * 0.5;
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float middle = exp(-across * across * 3.5);
	float fade = clamp(1.0 - along / fade_at, 0.0, 1.0);
	fade = fade * fade;
	float ground = smoothstep(0.0, 2.5, world.y);
	float near = smoothstep(4.0, 14.0, length(VERTEX));
	ALBEDO = tint * power * middle * fade * ground * near * smoothstep(0.0, 0.3, facing);
}
