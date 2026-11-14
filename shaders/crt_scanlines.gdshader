// CRT Scanlines (stil "FNaF 4 retro minigames").
// Se aplică pe un ColorRect full-screen dintr-un CanvasLayer de deasupra jocului.
// Doar întunecă (overlay negru) -> ieftin, merge pe Compatibility / Web.
shader_type canvas_item;
render_mode unshaded;

uniform float line_spacing = 3.0;                            // pixeli de ecran între dungi
uniform float line_intensity : hint_range(0.0, 1.0) = 0.30;  // cât de negre sunt dungile
uniform float roll_speed = 0.06;                             // banda luminoasă care „rulează”
uniform float vignette : hint_range(0.0, 2.0) = 0.55;
uniform float flicker : hint_range(0.0, 0.2) = 0.025;

void fragment() {
	// 1 pe dunga întunecată, 0 pe dunga luminoasă
	float scan = 1.0 - step(line_spacing * 0.5, mod(FRAGCOORD.y, line_spacing));
	// bandă mai luminoasă care coboară lent pe ecran
	float band = smoothstep(0.0, 0.12, abs(fract(UV.y - TIME * roll_speed) - 0.5));
	float lines = scan * line_intensity * (0.65 + 0.35 * band);
	vec2 c = UV - vec2(0.5);
	float vig = dot(c, c) * vignette;
	float flick = flicker * (0.5 + 0.5 * sin(TIME * 53.0));
	COLOR = vec4(0.0, 0.0, 0.0, clamp(lines + vig + flick, 0.0, 0.92));
}
