shader_type canvas_item;

// The supplied ready texture contains both the bull and the electric effect.
// This shader keeps only the green/cyan electric pixels, allowing the normal
// square bull icon to stay perfectly fitted inside the circle underneath.

uniform float effect_alpha : hint_range(0.0, 1.5) = 1.0;
uniform float glow_boost : hint_range(0.5, 2.5) = 1.15;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float green_dominance = tex.g - tex.r;
    float cyan_green_light = max(tex.g, tex.b);

    float color_mask = smoothstep(0.10, 0.28, green_dominance)
        * smoothstep(0.28, 0.68, cyan_green_light);

    float alpha = tex.a * color_mask * effect_alpha;
    vec3 boosted = min(tex.rgb * glow_boost, vec3(1.0));

    COLOR = vec4(boosted, alpha);
}
