// Podea în tablă de șah (stil "FNaF 4 retro minigames").
// rect_size trebuie să fie dimensiunea ColorRect-ului (o setează CheckerFloor.gd).
shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.0549, 0.1059, 0.2, 1.0);   // #0e1b33
uniform vec4 color_b : source_color = vec4(0.0824, 0.149, 0.2784, 1.0); // #152647
uniform vec2 rect_size = vec2(1024.0, 544.0);
uniform float tile_size = 32.0;
uniform float bevel : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 p = UV * rect_size;
	vec2 cell = floor(p / tile_size);
	float checker = mod(cell.x + cell.y, 2.0);
	vec4 col = mix(color_a, color_b, checker);
	// muchie de 2px întunecată sus/stânga -> aspect de dală pixel-art
	vec2 f = p - cell * tile_size;
	float edge = max(step(f.x, 2.0), step(f.y, 2.0));
	col.rgb *= 1.0 - bevel * edge;
	COLOR = col;
}
