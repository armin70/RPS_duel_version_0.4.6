shader_type spatial;

render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);

    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}