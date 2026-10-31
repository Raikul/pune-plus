shader_type canvas_item;
render_mode blend_add;

// Water's twin: a pale, shimmering ghost trail (additive, so it glows over the floor).
// A slow wave of color runs along it, so it never reads as a solid snake.

uniform float wave_speed = 4.0;
uniform float wave_length = 0.035;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// The wave shifts the color towards a pale violet instead of fading to black, so the trail
// never looks like a hole
uniform vec3 shimmer_color : source_color = vec3(0.72, 0.68, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float wave = 0.5 + 0.5 * sin(TIME * wave_speed - (world_position.x + world_position.y) * wave_length);
	COLOR = vec4(mix(color.rgb, shimmer_color, wave * 0.7), color.a * (0.75 + 0.2 * wave));
}
