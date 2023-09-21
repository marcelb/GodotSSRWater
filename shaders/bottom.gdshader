shader_type spatial;

uniform float height_scale = 50.0;
uniform float uv_scale = 400.0;
uniform float texture_scale = 20.0;

uniform sampler2D stone_texture;
uniform sampler2D bottom;

varying vec2 uv; 
varying float height; 

void vertex()
{
	uv = VERTEX.xz / uv_scale;
	height = texture(bottom, uv).x * height_scale;
	VERTEX.y += height;
	
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(
		texture(bottom, uv - e).x * height_scale - texture(bottom, uv + e).x * height_scale, 
		2.0 * e.x, 
		texture(bottom, uv - e.yx).x * height_scale - texture(bottom, uv + e.yx).x * height_scale
		));
	NORMAL = normal;
}

float normalize_float(float value, float min_v, float max_v) {
	float clamped_value = clamp(value, min_v, max_v);
	return  (clamped_value - min_v) / (max_v - min_v);
}

void fragment() {
	float greens = normalize_float(height, 30.0, 60.0);
	ALBEDO.rgb = texture(stone_texture, uv * texture_scale).rgb * vec3(0.2, greens, 0.0);
	
	METALLIC = .5;
	ROUGHNESS = .7;
}
