// Fascicul vertical neon (stil "Tomb of the Mask").
// Pune-l pe un ColorRect: UV.x = lățimea fasciculului, UV.y = înălțimea.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float core_width : hint_range(0.0, 1.0) = 0.18;
uniform float intensity = 1.4;
uniform float stripe_speed = 6.0;
uniform float bottom_fade : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;                 // 0 în centru, 1 la margini
	float glow = pow(1.0 - clamp(x, 0.0, 1.0), 2.6);
	float core = 1.0 - smoothstep(core_width * 0.5, core_width, x);
	float stripes = 0.8 + 0.2 * sin(UV.y * 90.0 + TIME * stripe_speed * 4.0);
	float shimmer = 0.9 + 0.1 * sin(TIME * 17.0 + UV.y * 7.0);
	float fade = 1.0 - bottom_fade * smoothstep(0.6, 1.0, UV.y);
	vec3 col = beam_color.rgb * glow * stripes * shimmer + vec3(1.0, 0.85, 1.0) * core * 0.85;
	COLOR = vec4(col * intensity * fade * beam_color.a, 1.0);
}
