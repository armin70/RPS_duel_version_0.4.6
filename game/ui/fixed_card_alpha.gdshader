shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	float final_alpha = tex.a * fade_alpha;

	if (final_alpha <= 0.001) {
		discard;
	}

	ALBEDO = tex.rgb;
	ALPHA = final_alpha;
}
