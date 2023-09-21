shader_type spatial;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

uniform float refraction_scale = 1.0;
uniform float refraction_roughness = 1.0;
uniform float refraction_texture_value = 1.0;
uniform float refraction_alpha = 0.1;

void fragment() {
	vec3 emission_in = EMISSION;
	vec3 albedo_in = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 ref_normal = NORMAL;
	vec2 ref_ofs = SCREEN_UV.xy - ref_normal.xy * refraction_texture_value * refraction_scale;
	float ref_amount = 1.0 - refraction_alpha;
	EMISSION.rgb = emission_in + textureLod(SCREEN_TEXTURE, ref_ofs, refraction_roughness * 8.0).rgb * ref_amount;
	ALBEDO.rgb = albedo_in * vec3(1.0 - ref_amount);
}
