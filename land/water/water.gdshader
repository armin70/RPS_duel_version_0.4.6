shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// ============================================================
// WATER COLOR
// ============================================================

uniform vec4 color : source_color = vec4(0.08, 0.45, 1.0, 1.0);
uniform vec4 deep_water : source_color = vec4(0.015, 0.12, 0.55, 1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;


// ============================================================
// WATER SPEED
// ============================================================

uniform float speed : hint_range(-1.0, 1.0) = 0.02;


// ============================================================
// SCREEN / DEPTH
// ============================================================

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float beer_law_factor = 2.0;
uniform float _distance = 50.0;


// ============================================================
// WATER FOAM / EDGE
// ============================================================

uniform vec4 edge_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);

uniform float edge_scale = 0.1;
uniform float near = 0.1;
uniform float far = 100.0;


// ============================================================
// WATER WAVES
// ============================================================

uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;

uniform float height_scale = 0.15;
uniform float noise_scale = 10.0;


// ============================================================
// WATER TEXTURES
// ============================================================

uniform sampler2D noise1;
uniform sampler2D noise2;

uniform sampler2D wave;

uniform sampler2D normalmap : hint_normal;


// ============================================================
// VARYINGS
// ============================================================

varying float height;
varying vec3 world_pos;


// ============================================================
// DEPTH / RIM
// ============================================================

float rim(float depth) {

	depth = 2.0 * depth - 1.0;

	return near * far /
		(far + depth * (near - far));
}


// ============================================================
// DEPTH FADE
// ============================================================

float calc_depth_fade(
	float depth,
	mat4 projection_matrix,
	vec4 fragcoord,
	float beer_factor,
	float __distance,
	vec3 vertex
) {

	float scene_depth = depth;

	scene_depth = scene_depth * 2.0 - 1.0;

	scene_depth =
		projection_matrix[3][2] /
		(scene_depth + projection_matrix[2][2]);

	scene_depth += vertex.z;

	// Beer-Lambert absorption
	scene_depth =
		exp(-scene_depth * beer_factor);

	float screen_depth = fragcoord.z;

	float depth_fade =
		(scene_depth - screen_depth) /
		__distance;

	depth_fade =
		clamp(depth_fade, 0.0, 1.0);

	return depth_fade;
}


// ============================================================
// VERTEX
// ============================================================

void vertex() {

	// World position
	world_pos =
		(MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Animated wave texture
	height =
		texture(
			wave,
			world_pos.xz / noise_scale
			+ TIME * time_scale
		).r;

	// Move water vertices
	VERTEX.y += height * height_scale;
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment() {

	// --------------------------------------------------------
	// TIME
	// --------------------------------------------------------

	float time = TIME * speed;


	// --------------------------------------------------------
	// MOVING NOISE
	// --------------------------------------------------------

	vec3 n1 =
		texture(
			noise1,
			UV + time
		).rgb;

	vec3 n2 =
		texture(
			noise2,
			UV - time * 0.2
		).rgb;


	// --------------------------------------------------------
	// NORMAL UV MOVEMENT
	// --------------------------------------------------------

	vec2 uv_movement =
		UV * 4.0;

	uv_movement +=
		TIME * speed * 4.0;


	// --------------------------------------------------------
	// COMBINE NOISE
	// --------------------------------------------------------

	float sum =
		(n1.r + n2.r) - 1.0;


	// --------------------------------------------------------
	// DEPTH
	// --------------------------------------------------------

	float z_depth =
		rim(
			texture(
				DEPTH_TEXTURE,
				SCREEN_UV
			).x
		);

	float z_pos =
		rim(FRAGCOORD.z);

	float diff =
		z_depth - z_pos;


	// --------------------------------------------------------
	// DEPTH FADE
	// --------------------------------------------------------

	float z_depth_fade =
		calc_depth_fade(
			texture(
				DEPTH_TEXTURE,
				SCREEN_UV
			).x,

			PROJECTION_MATRIX,

			FRAGCOORD,

			beer_law_factor,

			_distance,

			VERTEX
		);


	// --------------------------------------------------------
	// BLUE WATER GRADIENT
	// --------------------------------------------------------

	vec4 gradientcolor =
		mix(
			color,
			deep_water,
			z_depth_fade
		);


	// --------------------------------------------------------
	// WATER EDGE
	// --------------------------------------------------------

	vec2 displacement =
		vec2(sum * 0.01);

	diff +=
		displacement.x * 15.0;


	vec4 depth_color_adj =
		mix(
			edge_color,
			gradientcolor,
			step(edge_scale, diff)
		);


	// --------------------------------------------------------
	// SCREEN REFLECTION
	// --------------------------------------------------------

	vec4 screen_color =
		texture(
			SCREEN_TEXTURE,
			SCREEN_UV + displacement
		);


	// --------------------------------------------------------
	// STYLIZED WATER COLOR
	// --------------------------------------------------------

	// Base blue water
	vec3 water_color =
		mix(
			color.rgb,
			deep_water.rgb,
			z_depth_fade
		);


	// --------------------------------------------------------
	// FOAM
	// --------------------------------------------------------

	float foam = 0.0;

	if (sum > 0.0 && sum < 0.4) {
		foam = 0.1;
	}

	if (sum > 0.4 && sum < 0.8) {
		foam = 0.0;
	}

	if (sum > 0.8) {
		foam = 1.0;
	}


	// --------------------------------------------------------
	// ADD STYLIZED FOAM
	// --------------------------------------------------------

	water_color =
		mix(
			water_color,
			edge_color.rgb,
			foam * 0.35
		);


	// --------------------------------------------------------
	// ALBEDO
	// --------------------------------------------------------

	ALBEDO =
		water_color;


	// --------------------------------------------------------
	// NORMAL MAP
	// --------------------------------------------------------

	NORMAL_MAP =
		texture(
			normalmap,
			uv_movement
		).rgb;


	// --------------------------------------------------------
	// MATERIAL
	// --------------------------------------------------------

	METALLIC =

		metallic;

	ROUGHNESS =
		roughness;
}