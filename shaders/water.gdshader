shader_type spatial;

render_mode depth_draw_always;

const float EPSILON = 1e-5;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

uniform vec3 color_shallow : source_color = vec3(0.01, 0.2, 0.3);
uniform vec3 color_deep : source_color = vec3(0.3, 0.5, 0.6);

uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.25;

uniform float max_visible_depth : hint_range(0.1, 100.0, 0.1) = 20.0;

uniform sampler2D wave_a;
uniform sampler2D wave_b;
uniform vec2 wave_move_direction_a = vec2(-1.0, 0.0);
uniform vec2 wave_move_direction_b = vec2(0.0, 1.0);
uniform float wave_noise_scale_a = 15.0;
uniform float wave_noise_scale_b = 15.0;
uniform float wave_time_scale_a = 0.15;
uniform float wave_time_scale_b = 0.15;
uniform float wave_height_scale = 1.0;
uniform float wave_normal_flatness : hint_range(0.1, 100.0, 0.1) = 50.0;

uniform sampler2D surface_normals_a;
uniform sampler2D surface_normals_b;
uniform vec2 surface_normals_move_direction_a = vec2(-1.0, 0.2);
uniform vec2 surface_normals_move_direction_b = vec2(0.2, 1.0);
uniform float surface_texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float surface_texture_scale : hint_range(0.001, 2.0, 0.001) = 0.1;
uniform float surface_texture_time_scale : hint_range(0.001, 2.0, 0.001) = 0.06;

uniform float ssr_resolution   : hint_range(0.01, 10.0, 0.1)	= 1.0;
uniform float ssr_max_travel   : hint_range(0.0, 200.0, 0.1) 	= 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;
uniform float ssr_screen_border_fadeout: hint_range(0.0, 1.0, 0.1)	= 0.3;

uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.4; 

uniform vec3  border_color : source_color = vec3(1.0);
uniform float border_scale : hint_range(0.0, 5.0, 0.01) = 2.0;
uniform float border_near = 0.5;
uniform float border_far = 300.0;

uniform float cut_out_x = 0.0;
uniform float cut_out_z = 0.0;

varying vec2 vertex_uv; 
varying vec3 local_position;

float get_wave_height(vec2 uv_a, vec2 uv_b)
{
	float height1 = texture(wave_a, uv_a).y;
	float height2 = texture(wave_b, uv_b).y;
	return (height1 + height2) / 2.0;
}

vec3 get_mixed_normals(vec3 color1, vec3 color2) 
{
    vec3 normal1 = normalize(color1 * 2.0 - 1.0);
    vec3 normal2 = normalize(color2 * 2.0 - 1.0);
    vec3 up = vec3(0.0, 0.0, 1.0);
    vec3 tangent = normalize(normal1 + normal2);
    vec3 binormal = normalize(cross(up, tangent));
    vec3 mixedNormal = normalize(cross(tangent, binormal));
    return mixedNormal * 0.5;
}

void vertex()
{
	local_position = VERTEX;
	
	vertex_uv = (MODEL_MATRIX * vec4(local_position, 1.0)).xz;
	vec2 uv_a = vertex_uv / wave_noise_scale_a + (wave_move_direction_a * TIME * wave_time_scale_a);
	vec2 uv_b = vertex_uv / wave_noise_scale_b + (wave_move_direction_b * TIME * wave_time_scale_b);
	VERTEX.y += get_wave_height(uv_a, uv_b) * wave_height_scale;
	
	float normal_height_scale = wave_height_scale / wave_normal_flatness;
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(
		get_wave_height(uv_a - e, uv_b - e) * normal_height_scale - get_wave_height(uv_a + e, uv_a + e) * normal_height_scale, 
		2.0 * e.x, 
		get_wave_height(uv_a - e.yx, uv_b - e.yx) * normal_height_scale - get_wave_height(uv_a + e.yx, uv_b + e.yx) * normal_height_scale
		));
	NORMAL = normal;
}

bool is_within_screen_boundaries(vec2 position) 
{
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

bool is_zero(float value) 
{
    return abs(value) < EPSILON;
}

float get_screen_border_alpha(vec2 screen_position)
{
    vec2 shifted_screen_position = 4.0 * screen_position * (1.0 - screen_position);
	float mask = shifted_screen_position.x * shifted_screen_position.y; // ranging from 0.0 at the edges to 1.0 in the center 

	// An offset in the [0.0, 0.5] range for ssr_screen_border_fadeout values > 0.75
	// which is subtracted from the result of smoothstep.
	// This ensure alpha smoothly transitions to zero when ssr_screen_border_fadeout is approaching 1.0.	
	float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0)-0.75) / 0.25);
	float alpha = clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);

	return is_zero(ssr_screen_border_fadeout) ? 1.0 : alpha;
}

vec4 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	if (ssr_max_travel < EPSILON)
	{
		return vec4(0);
	}
	
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));
	
	vec2 current_screen_position = vec2(0.0);
	
	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

		float depth_texture_probe_raw = texture(DEPTH_TEXTURE, current_screen_position).x;
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);
		
		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;
		
		vec3 ssr_screen_color = texture(SCREEN_TEXTURE, current_screen_position.xy).rgb;
		resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? ssr_screen_color : vec3(-1.0);
	}

	float alpha = get_screen_border_alpha(current_screen_position);
	return vec4(resulting_color,alpha);
}

float linear_depth(float cur_depth)
{
    return border_far * border_near / (border_near + cur_depth * (border_far - border_near));
}

float normalize_float(float min_v, float max_v, float value) 
{
	float clamped_value = clamp(value, min_v, max_v);
	return  (clamped_value - min_v) / (max_v - min_v);
}

vec2 get_refracted_uv(vec2 raw_screen_uv, float screen_depth_raw, vec3 view, vec3 normal, mat4 proj_m, mat4 inv_proj_m)
{
		vec3 screen_view_position_original = get_view_position_from_uv(raw_screen_uv, screen_depth_raw, inv_proj_m);
		float screen_center_distance = clamp(abs(length(raw_screen_uv - vec2(0.5, 0.5))) * 2.0, 0.0, 1.0);
		float refraction_intensity_deglitched = mix(1.0 - refraction_intensity, 1.0, screen_center_distance);
		vec3 refraction_position_view_space = screen_view_position_original + normalize(refract(view, -normal, refraction_intensity_deglitched));
		vec2 refraction_uv = get_uv_from_view_position(refraction_position_view_space, proj_m);
		return refraction_uv;
}

void fragment() 
{
	vec3 normal = NORMAL;
	
	float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	
	vec2 refraction_uv = refraction_intensity > 0.0 ? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, normal, PROJECTION_MATRIX, INV_PROJECTION_MATRIX) : SCREEN_UV;
	
	float screen_depth = texture(DEPTH_TEXTURE, refraction_uv).x;
	float surface_depth = FRAGCOORD.z;
	
	float border_diff = linear_depth(screen_depth_raw) - linear_depth(surface_depth);
	
	vec2 time_vector = (TIME * surface_normals_move_direction_a) * surface_texture_time_scale;
	vec2 time_vector2 = (TIME * surface_normals_move_direction_b) * surface_texture_time_scale;
	
	vec3 normal_texture_blend 	= get_mixed_normals(texture(surface_normals_a, vertex_uv * surface_texture_scale + time_vector).xyz, texture(surface_normals_b, vertex_uv * surface_texture_scale + time_vector2).xyz);
	vec3 normal_blend 			= mix(normal, normal_texture_blend, surface_texture_roughness);
	
	vec3 screen_view_position 	= get_view_position_from_uv(refraction_uv, screen_depth, INV_PROJECTION_MATRIX);
	vec3 surface_view_position 	= get_view_position_from_uv(SCREEN_UV, surface_depth, INV_PROJECTION_MATRIX);
	float depth_visibility 		= 1.0 - normalize_float(0.0, max_visible_depth, length(surface_view_position - screen_view_position));
	
	vec3 screen_color 				= texture(SCREEN_TEXTURE, refraction_uv).rgb;
	vec4 ssr_color 					= get_ssr_color(surface_view_position, normal, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	vec3 surface_color_transparency	= mix(color_shallow, screen_color, transparency);
	vec3 surface_depth_color_mix 	= mix(color_deep, surface_color_transparency, depth_visibility);
	vec3 surface_color_ssr_mix		= (ssr_max_travel > EPSILON) ? mix(surface_depth_color_mix, ssr_color.rgb, ssr_mix_strength * ssr_color.a) : vec3(0);
	vec3 water_color 				= (ssr_color.x >= 0.0) ? surface_color_ssr_mix : surface_depth_color_mix;
	vec3 final_color				= mix(border_color, water_color, step(border_scale, border_diff));
	
	float cut_out_x_half = cut_out_x / 2.0;
	float cut_out_z_half = cut_out_z / 2.0;
	
	if((local_position.x < cut_out_x_half && local_position.x > -cut_out_x_half) &&
	(local_position.z < cut_out_z_half && local_position.z > -cut_out_z_half)) 
	{
		discard;
	}
	
	ALBEDO.rgb = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL = normal_blend;
}
