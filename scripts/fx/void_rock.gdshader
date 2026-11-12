shader_type canvas_item;

// Void's borrowed rocks (Player.start_fissure): Earth's rock art turned to its brightness
// and recolored in Void's purple, keeping the rocks' shading.
uniform vec4 tint : source_color = vec4(0.83, 0.36, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float light = dot(color.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(tint.rgb * light * 1.8, color.a);
}
