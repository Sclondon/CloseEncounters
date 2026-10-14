shader_type spatial;
// The farm country, painted from where each point is (before the bend): a patchwork of fields
// (pasture, wheat, ploughed earth, corn) with hedges between them, the roads (see world.gd ROADS),
// the lawns of the town and the trampled ground of the army camp.

#include "res://shaders/bend.gdshaderinc"

uniform vec4 roads_x = vec4(0.0, 70.0, 9999.0, 9999.0);
uniform vec4 roads_z = vec4(0.0, -70.0, 9999.0, 9999.0);
uniform vec4 town = vec4(40.0, -110.0, 110.0, -40.0);
uniform vec4 camp = vec4(-110.0, -110.0, -50.0, -60.0);
uniform float field = 22.0;
uniform float edge = 118.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

bool inside(vec2 p, vec4 r) {
	return p.x > r.x && p.x < r.z && p.y > r.y && p.y < r.w;
}

void fragment() {
	vec2 p = world.xz;
	vec2 cell = floor(p / field);
	vec2 in_cell = p / field - cell;
	float h = hash(cell);
	float speck = hash(floor(p * 3.0));
	bool across = hash(cell + 7.0) > 0.5;
	float row = fract((across ? p.x : p.y) * 0.8);
	vec3 grass = mix(vec3(0.2, 0.36, 0.14), vec3(0.26, 0.42, 0.16), speck);
	vec3 c = grass;
	if (h < 0.3) {
		c = grass;
	} else if (h < 0.5) {
		c = mix(vec3(0.62, 0.5, 0.2), vec3(0.75, 0.62, 0.28), step(0.4, row)) * (0.92 + 0.12 * speck);
	} else if (h < 0.7) {
		c = mix(vec3(0.27, 0.17, 0.1), vec3(0.36, 0.24, 0.14), step(0.5, row)) * (0.9 + 0.15 * speck);
	} else if (h < 0.85) {
		c = mix(vec3(0.12, 0.26, 0.08), vec3(0.22, 0.38, 0.12), step(0.45, row)) * (0.9 + 0.15 * speck);
	} else {
		c = mix(vec3(0.3, 0.42, 0.18), vec3(0.36, 0.46, 0.2), speck);
	}
	// Hedges between the fields
	float border = min(min(in_cell.x, 1.0 - in_cell.x), min(in_cell.y, 1.0 - in_cell.y)) * field;
	if (border < 0.7) {
		c = vec3(0.1, 0.2, 0.08) * (0.8 + 0.4 * speck);
	}
	if (inside(p, town)) {
		c = mix(vec3(0.24, 0.4, 0.16), vec3(0.28, 0.44, 0.18), speck);
	}
	if (inside(p, camp)) {
		c = mix(vec3(0.32, 0.27, 0.18), vec3(0.38, 0.32, 0.2), speck);
	}
	// The roads, with a dashed line down the middle
	for (int i = 0; i < 4; i++) {
		float dx = abs(p.x - roads_x[i]);
		float dz = abs(p.y - roads_z[i]);
		if (dx < 3.0) {
			c = vec3(0.16, 0.16, 0.17) * (0.9 + 0.2 * speck);
			if (dx < 0.12 && fract(p.y * 0.25) < 0.5) c = vec3(0.85, 0.7, 0.2);
		}
		if (dz < 3.0) {
			c = vec3(0.16, 0.16, 0.17) * (0.9 + 0.2 * speck);
			if (dz < 0.12 && fract(p.x * 0.25) < 0.5) c = vec3(0.85, 0.7, 0.2);
		}
	}
	// Beyond the edge of the map, only the woods
	if (abs(p.x) > edge || abs(p.y) > edge) {
		c = vec3(0.08, 0.16, 0.08) * (0.8 + 0.4 * speck);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
