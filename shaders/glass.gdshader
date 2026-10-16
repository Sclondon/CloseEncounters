shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
// The ships' canopies: clear glass, so the pilot shows through. Nearly invisible looking straight
// in, bright toward the rim where it turns away (a fresnel edge with a faint rainbow sheen), with
// the night sky and two hard glints of light reflected in it. Bent with the world like everything
// else (see bend.gdshaderinc), but its corners are not snapped to the low-res pixels: glass shows
// every facet.

global uniform vec3 bend_focus;
global uniform float bend_k;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 1.0);

vec3 bent(vec3 w) {
	float d = w.z - bend_focus.z;
	d = d < 0.0 ? d : d * 0.45;
	float s = w.x - bend_focus.x;
	w.y -= bend_k * (d * d + 0.3 * s * s);
	return w;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(bent(world), 1.0));
}

void fragment() {
	// (Godot turns the normal round for the inside, seen when the canopy is open)
	vec3 n = normalize(NORMAL);
	float facing = clamp(dot(n, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	// What the glass reflects, in the world: a dark sky, lighter toward the horizon, and two lights
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, n), 0.0)).xyz;
	vec3 sky = mix(vec3(0.05, 0.1, 0.2), vec3(0.25, 0.4, 0.6), pow(1.0 - clamp(r.y, 0.0, 1.0), 4.0));
	float glint = pow(max(dot(r, normalize(vec3(-0.5, 0.75, 0.45))), 0.0), 90.0)
		+ 0.6 * pow(max(dot(r, normalize(vec3(0.7, 0.35, -0.6))), 0.0), 40.0);
	// (a soft streak across the top, as if from a long light)
	float streak = smoothstep(0.92, 0.99, r.y) * 0.35;
	// (the glints and the streak only on the top of the dome, facing the sky: low on it, where it
	// curves under toward the hull, or inside it with the canopy open, they read as a fault in the
	// glass)
	vec3 up_n = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float top = smoothstep(0.15, 0.45, up_n.y) * (FRONT_FACING ? 1.0 : 0.0);
	glint *= top;
	streak *= top;
	vec3 sheen = 0.5 + 0.5 * cos(6.2832 * (rim * 1.3 + vec3(0.0, 0.33, 0.67)));
	vec3 c = tint * 0.25 + sky * 0.6 + tint * rim * 0.9 + sheen * rim * 0.25;
	ALBEDO = c + vec3(glint + streak);
	ALPHA = clamp(0.06 + 0.75 * rim + glint + streak * 0.5, 0.0, 1.0);
}
