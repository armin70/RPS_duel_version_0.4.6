shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_test_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    ALBEDO = tex.rgb;
    // Only transparent pixels in the PNG disappear; the card art stays visible.
    ALPHA = tex.a * fade_alpha;
}
