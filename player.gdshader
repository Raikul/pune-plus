shader_type canvas_item;

uniform float blue = 1.0; // you can assign a default value to uniforms

void fragment(){
  COLOR = texture(TEXTURE, UV); //read from texture
  COLOR.b = blue;
}

void vertex() {
  // Animate Sprite2D moving in big circle around its location
  VERTEX += vec2(cos(TIME*5.0)*100.0, sin(TIME*5.0)*100.0);
}
