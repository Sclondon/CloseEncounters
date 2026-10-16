shader_type spatial;
// The ground, painted from where each point is (before the bend), by region (see world.gd Biome):
// `biomes` holds one texel per chunk round the saucer, and the regions blend across the edges of
// their chunks. Roads run along every `road_every_chunks`-th line of chunks both ways (see `wander`).

#include "res://shaders/bend.gdshaderinc"

uniform sampler2D biomes : filter_nearest;
uniform vec2 biome_corner = vec2(0.0);
uniform float chunk = 48.0;
uniform float road_every_chunks = 5.0;
// From the world's seed (see world.gd reseed)
uniform float road_phase = 0.0;
uniform vec2 dirt_step = vec2(7.0, 11.0);
// Crop circles: (x, z, radius, -) each, pressed into the crop fields only (see world.gd crop_circle)
uniform vec4 circles[24];
// Lines pressed between crop circles near each other: (x, z) to (x, z) each (see world.gd crop_circle)
uniform vec4 links[16];

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// A farm field (one to a chunk, see world.gd Field): its crop in rows, `across` x or along z;
// pressed flat where a crop circle is
vec3 farm(vec2 p, float speck, int kind, bool across) {
	float row = fract((across ? p.x : p.y) / 3.0);
	vec3 grass = mix(vec3(0.2, 0.36, 0.14), vec3(0.26, 0.42, 0.16), speck);
	vec3 c = grass;
	if (kind == 2) {
		// wheat: gold, in rows
		c = mix(vec3(0.62, 0.5, 0.2), vec3(0.75, 0.62, 0.28), smoothstep(0.3, 0.5, row)) * (0.92 + 0.12 * speck);
	} else if (kind == 3) {
		// corn: green rows over dark earth
		c = mix(vec3(0.2, 0.14, 0.08), vec3(0.18, 0.34, 0.12), smoothstep(0.35, 0.55, row)) * (0.9 + 0.15 * speck);
	} else if (kind == 4) {
		// pumpkins: vines along rows of earth
		c = mix(vec3(0.28, 0.18, 0.1), vec3(0.16, 0.3, 0.1), step(0.6, row)) * (0.9 + 0.15 * speck);
	} else if (kind == 5) {
		// ploughed earth
		c = mix(vec3(0.27, 0.17, 0.1), vec3(0.36, 0.24, 0.14), step(0.5, row)) * (0.9 + 0.15 * speck);
	} else if (kind == 6) {
		// young green crops
		c = mix(vec3(0.12, 0.26, 0.08), vec3(0.22, 0.38, 0.12), step(0.45, row)) * (0.9 + 0.15 * speck);
	} else {
		c = mix(vec3(0.3, 0.42, 0.18), vec3(0.36, 0.46, 0.2), speck);
	}
	// The lines joining crop circles, the crop laid flat along them
	for (int i = 0; i < 16; i++) {
		vec4 l = links[i];
		vec2 a = l.xy;
		vec2 ab = l.zw - l.xy;
		float len2 = dot(ab, ab);
		if (len2 < 0.01) continue;
		float h = clamp(dot(p - a, ab) / len2, 0.0, 1.0);
		if (length(p - a - ab * h) < 0.7) {
			c = vec3(0.78, 0.72, 0.5) * (0.95 + 0.1 * speck);
		}
	}
	// A crop circle: the crop (or the grass) laid flat in rings, pale under the moon
	{
		for (int i = 0; i < 24; i++) {
			vec4 cc = circles[i];
			if (cc.z <= 0.0) continue;
			float d = length(p - cc.xy);
			if (d < cc.z) {
				float ring = step(0.5, fract(d / cc.z * 3.0));
				float centre = 1.0 - step(cc.z * 0.18, d);
				c = mix(vec3(0.78, 0.72, 0.5), vec3(0.6, 0.55, 0.36), ring) * (0.95 + 0.1 * speck);
				c = mix(c, vec3(0.85, 0.8, 0.58), centre);
			}
		}
	}
	return c;
}

vec3 paint(int b, vec2 p, float speck, int kind, bool across) {
	float big = vnoise(p * 0.04);
	float mid = vnoise(p * 0.15);
	if (b == 1) {
		// The high plains: golden grass, sage-green in patches
		vec3 c = mix(vec3(0.5, 0.44, 0.22), vec3(0.58, 0.52, 0.28), big);
		c = mix(c, vec3(0.38, 0.42, 0.28), smoothstep(0.55, 0.75, mid) * 0.7);
		return c * (0.9 + 0.2 * speck);
	} else if (b == 2) {
		// Red desert sand, with wind streaks
		vec3 c = mix(vec3(0.6, 0.3, 0.17), vec3(0.74, 0.42, 0.24), big);
		c *= 0.94 + 0.08 * sin(p.x * 0.9 + p.y * 0.3 + mid * 6.0);
		return c * (0.92 + 0.14 * speck);
	} else if (b == 3) {
		// New Mexico: ochre earth and dark scrub
		vec3 c = mix(vec3(0.58, 0.44, 0.28), vec3(0.66, 0.52, 0.34), big);
		c = mix(c, vec3(0.26, 0.3, 0.18), step(0.93, hash(floor(p * 2.5))) * 0.8);
		return c * (0.92 + 0.14 * speck);
	} else if (b == 4) {
		// The mountains: forest floor, bare rock, and snow in the hollows
		vec3 c = mix(vec3(0.1, 0.2, 0.1), vec3(0.16, 0.26, 0.13), mid);
		c = mix(c, vec3(0.4, 0.39, 0.38), smoothstep(0.55, 0.7, big));
		c = mix(c, vec3(0.86, 0.88, 0.92), smoothstep(0.78, 0.84, vnoise(p * 0.07 + 20.0)));
		return c * (0.9 + 0.2 * speck);
	}
	return farm(p, speck, kind, across);
}

// How far a road wanders off its line at `t` along it (world.gd _wander: keep the two the same)
float wander(float line, float t) {
	float spacing = chunk * road_every_chunks;
	float from_crossing = abs(t - round(t / spacing) * spacing);
	float amount = 11.0 * smoothstep(30.0, 90.0, from_crossing);
	return amount * (sin(t * 0.013 + line * 1.7 + road_phase) + 0.45 * sin(t * 0.031 + line * 2.9 + road_phase * 1.3)) / 1.45;
}

// A road's colour, `d` from its middle, `t` along it
vec3 road(bool dirt, float d, float t, float speck) {
	if (dirt) {
		// (two ruts down a dirt track)
		float rut = 1.0 - smoothstep(0.15, 0.35, abs(d - 0.9));
		return mix(vec3(0.42, 0.32, 0.2), vec3(0.3, 0.22, 0.14), rut) * (0.88 + 0.24 * speck);
	}
	vec3 c = vec3(0.16, 0.16, 0.17) * (0.9 + 0.2 * speck);
	if (d < 0.12 && fract(t * 0.25) < 0.5) c = vec3(0.85, 0.7, 0.2);
	return c;
}

int biome_of(vec2 cell) {
	ivec2 size = textureSize(biomes, 0);
	ivec2 i = clamp(ivec2(cell), ivec2(0), size - 1);
	return int(texelFetch(biomes, i, 0).r * 255.0 / 40.0 + 0.5);
}

void fragment() {
	vec2 p = world.xz;
	float speck = hash(floor(p * 3.0));
	vec2 q = (p - biome_corner) / chunk;
	vec2 i = floor(q);
	vec2 f = smoothstep(0.3, 0.7, fract(q));
	// (this point's own chunk's field, see world.gd Field)
	ivec2 size = textureSize(biomes, 0);
	vec3 here = texelFetch(biomes, clamp(ivec2(floor(q + 0.5)), ivec2(0), size - 1), 0).rgb;
	int kind = int(here.g * 255.0 / 20.0 + 0.5);
	bool across = here.b > 0.5;
	int b00 = biome_of(i);
	int b10 = biome_of(i + vec2(1, 0));
	int b01 = biome_of(i + vec2(0, 1));
	int b11 = biome_of(i + vec2(1, 1));
	vec3 c;
	if (b00 == b10 && b00 == b01 && b00 == b11) {
		c = paint(b00, p, speck, kind, across);
	} else {
		// (a ragged edge between regions, not a straight one)
		f = clamp(f + (vnoise(p * 0.2) - 0.5) * 0.5, 0.0, 1.0);
		c = mix(mix(paint(b00, p, speck, kind, across), paint(b10, p, speck, kind, across), f.x), mix(paint(b01, p, speck, kind, across), paint(b11, p, speck, kind, across), f.x), f.y);
	}
	// The roads (see world.gd "the roads"): meandering in open country, straight near crossings;
	// paved ones grey with a dashed line down the middle, dirt ones narrower, brown and rutted
	float spacing = chunk * road_every_chunks;
	float n = round(p.x / spacing) * road_every_chunks;
	float m = round(p.y / spacing) * road_every_chunks;
	float dx = abs(p.x - (n * chunk + wander(n, p.y)));
	float dz = abs(p.y - (m * chunk + wander(m + 0.5, p.x)));
	bool dirt_x = int(mod(floor(n / road_every_chunks + 0.5) * dirt_step.x + 3.0, 5.0) + 0.5) < 2;
	bool dirt_z = int(mod(floor(m / road_every_chunks + 0.5) * dirt_step.y + 3.0, 5.0) + 0.5) < 2;
	if (dx < (dirt_x ? 2.0 : 3.0)) {
		c = road(dirt_x, dx, p.y, speck);
	}
	if (dz < (dirt_z ? 2.0 : 3.0)) {
		c = road(dirt_z, dz, p.x, speck);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
