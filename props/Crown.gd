class_name Crown
extends Node2D
## Coroana Regală, desenată pixel cu pixel (aur #ffe600 + pietre prețioase).

const PATTERN: Array[String] = [
	"#...#...#",
	"##.###.##",
	"#########",
	"#r##b##r#",
	"#########",
]

@export var pixel := 3.0
@export var glow := true

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if glow:
		queue_redraw()


func _draw() -> void:
	var w := PATTERN[0].length() * pixel
	var h := PATTERN.size() * pixel
	var origin := Vector2(-w * 0.5, -h * 0.5)
	if glow:
		draw_circle(Vector2.ZERO, w * 0.9, Color(GameState.COL_GOLD, 0.10 + 0.05 * sin(_t * 4.0)))
	# contur întunecat
	draw_rect(Rect2(origin + Vector2(-pixel * 0.5, pixel * 0.5), Vector2(w + pixel, h)), Color(0.2, 0.1, 0.0, 0.6))
	for y in PATTERN.size():
		var row := PATTERN[y]
		for x in row.length():
			var ch := row[x]
			var c := Color.TRANSPARENT
			match ch:
				"#":
					c = GameState.COL_GOLD if y > 0 else Color("#fff27a")
				"r":
					c = GameState.COL_RED
				"b":
					c = GameState.COL_CYAN
			if c.a > 0.0:
				draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2(pixel, pixel)), c)
	# sclipire
	var s := 0.5 + 0.5 * sin(_t * 6.0)
	draw_rect(Rect2(origin + Vector2(1, 2) * pixel, Vector2(pixel, pixel)), Color(1, 1, 1, s))
