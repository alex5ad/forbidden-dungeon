class_name DarkBook
extends Node2D
## Cartea Întunericului, în prim-plan la final.
## open_amount 1 = deschisă, 0 = trântită; lock_amount = lanțurile + lacătul;
## vortex = vârtejul de lumină care absoarbe întunericul;
## title_progress = titlul „FORBIDDEN REDEMPTION” scrijelit literă cu literă pe copertă (engrave()).

const W := 200.0
const H := 260.0
const TITLE_LINES: Array[String] = ["FORBIDDEN", "REDEMPTION"]
const TITLE_MARGIN := 26.0      # distanța minimă de la marginea copertei
const TITLE_TOP := -H * 0.5 + 30.0
const LETTER_SPACING := 1.0

@export_range(0.0, 1.0) var open_amount := 1.0
@export_range(0.0, 1.0) var lock_amount := 0.0
@export_range(0.0, 1.0) var vortex := 0.0
@export_range(0.0, 1.0) var title_progress := 0.0

var title_font_size := 24
var _glyphs: Array[Dictionary] = []          # {ch, pos, w}
var _scratches: Array[Array] = []            # zgârieturi per literă (PackedVector2Array)
var _last_carved := -1
var _t := 0.0


func _ready() -> void:
	_layout_title()


func engrave(duration: float = 2.4) -> Tween:
	## Scrijelește titlul pe copertă. Folosire: await book.engrave().finished
	title_progress = 0.0
	_last_carved = -1
	var t := create_tween()
	t.tween_property(self, "title_progress", 1.0, duration)
	return t


func title_rect() -> Rect2:
	## Dreptunghiul ocupat de titlu (local) – trebuie să încapă în copertă.
	if _glyphs.is_empty():
		return Rect2()
	var font := ThemeDB.fallback_font
	var first: Vector2 = _glyphs[0]["pos"]
	var r := Rect2(first, Vector2.ZERO)
	for g in _glyphs:
		var p: Vector2 = g["pos"]
		r = r.expand(p + Vector2(0, -font.get_ascent(title_font_size)))
		r = r.expand(p + Vector2(float(g["w"]), font.get_descent(title_font_size)))
	return r


func cover_rect() -> Rect2:
	## Coperta închisă (local).
	return Rect2(-W * 0.5, -H * 0.5, W, H)


func _layout_title() -> void:
	var font := ThemeDB.fallback_font
	var inner_w := W - TITLE_MARGIN * 2.0
	# cel mai mare font la care ambele rânduri încap între margini
	title_font_size = 30
	while title_font_size > 10:
		var widest := 0.0
		for line in TITLE_LINES:
			widest = maxf(widest, _line_width(font, line, title_font_size))
		if widest <= inner_w:
			break
		title_font_size -= 1
	_glyphs.clear()
	_scratches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var asc := font.get_ascent(title_font_size)
	var line_h := font.get_height(title_font_size) + 2.0
	for li in TITLE_LINES.size():
		var line := TITLE_LINES[li]
		var x := -_line_width(font, line, title_font_size) * 0.5
		var baseline := TITLE_TOP + asc + li * line_h
		for i in line.length():
			var ch := line[i]
			var cw := font.get_char_size(line.unicode_at(i), title_font_size).x
			_glyphs.append({"ch": ch, "pos": Vector2(x, baseline), "w": cw})
			# 2-3 zgârieturi fine, oblice, peste literă
			var marks: Array = []
			for m in rng.randi_range(2, 3):
				var a := Vector2(x + rng.randf_range(0.0, cw * 0.6), baseline - rng.randf_range(2.0, asc - 2.0))
				var b := a + Vector2(rng.randf_range(3.0, cw * 0.6), rng.randf_range(-5.0, 5.0))
				var mid := (a + b) * 0.5 + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				marks.append(PackedVector2Array([a, mid, b]))
			_scratches.append(marks)
			x += cw + LETTER_SPACING


func _line_width(font: Font, line: String, font_size: int) -> float:
	var w := 0.0
	for i in line.length():
		w += font.get_char_size(line.unicode_at(i), font_size).x
	return w + LETTER_SPACING * (line.length() - 1)


func _process(delta: float) -> void:
	_t += delta
	# scântei + sunet la fiecare literă nouă scrijelită
	if title_progress > 0.0 and title_progress < 1.0 and not _glyphs.is_empty():
		var idx := mini(int(title_progress * _glyphs.size()), _glyphs.size() - 1)
		if idx != _last_carved:
			_last_carved = idx
			var g := _glyphs[idx]
			var p: Vector2 = g["pos"] + Vector2(float(g["w"]) * 0.5, -title_font_size * 0.35)
			FX.burst(get_parent(), to_global(p), GameState.COL_GOLD, 7, 110.0, 0.3, 2.0)
			GameState.play_sfx("scratch", true, -10.0)
	queue_redraw()


func _draw() -> void:
	var gold := GameState.COL_GOLD
	# --- vârtejul de lumină ---
	if vortex > 0.0:
		for i in 18:
			var ang := TAU * i / 18.0 + _t * 1.8
			var dir := Vector2.RIGHT.rotated(ang)
			var dir2 := Vector2.RIGHT.rotated(ang + 0.5)
			draw_line(dir * 40.0, dir2 * 900.0 * vortex, Color(1.0, 0.9, 1.0, 0.07 * vortex), 26.0)
		for i in 4:
			var rr := fmod(_t * 220.0 + i * 120.0, 480.0)
			draw_arc(Vector2.ZERO, 480.0 - rr, 0.0, TAU, 48, Color(GameState.COL_MAGENTA, 0.35 * vortex * (rr / 480.0)), 3.0)
	var half_w := lerpf(W * 0.5, W, open_amount)
	# --- pagini (când e deschisă) ---
	if open_amount > 0.05:
		var cover := Color("#1a0b24")
		draw_rect(Rect2(-half_w - 8.0, -H * 0.5 - 8.0, half_w * 2.0 + 16.0, H + 16.0), cover)
		var page := Color("#d9cba6").darkened(0.15)
		draw_rect(Rect2(-half_w, -H * 0.5, half_w - 4.0, H), page)
		draw_rect(Rect2(4.0, -H * 0.5, half_w - 4.0, H), page)
		# rânduri de text „interzis”
		var y := -H * 0.5 + 24.0
		while y < H * 0.5 - 20.0:
			draw_line(Vector2(-half_w + 18.0, y), Vector2(-22.0, y), Color(0.25, 0.05, 0.3, 0.6), 2.0)
			draw_line(Vector2(22.0, y), Vector2(half_w - 18.0, y), Color(0.25, 0.05, 0.3, 0.6), 2.0)
			y += 16.0
		draw_line(Vector2(0, -H * 0.5), Vector2(0, H * 0.5), Color(0, 0, 0, 0.7), 4.0)
		draw_circle(Vector2(0, 0), 26.0 + 6.0 * sin(_t * 5.0), Color(GameState.COL_MAGENTA, 0.35 * open_amount))
	# --- coperta (apare pe măsură ce se închide) ---
	var cover_a := clampf(1.0 - open_amount / 0.2, 0.0, 1.0)
	if cover_a > 0.0:
		var r := Rect2(-half_w, -H * 0.5, half_w * 2.0, H)
		draw_rect(r, Color(0.1, 0.04, 0.14, cover_a))
		draw_rect(r, Color(gold, cover_a), false, 4.0)
		draw_rect(r.grow(-10.0), Color(gold, 0.6 * cover_a), false, 2.0)
		# ochi/emblemă
		draw_circle(Vector2(0, 20), 18.0, Color(GameState.COL_MAGENTA, 0.6 * cover_a))
		draw_circle(Vector2(0, 20), 7.0, Color(0, 0, 0, cover_a))
	if cover_a > 0.0:
		_draw_title(cover_a)
	# --- lanțuri + lacăt ---
	if lock_amount > 0.0:
		var span := half_w + 18.0
		for cy in [44.0, 86.0]:
			var chain_y: float = cy
			var x := -span
			var end_x := lerpf(-span, span, lock_amount)
			var i := 0
			while x < end_x:
				if i % 2 == 0:
					draw_rect(Rect2(x, chain_y - 4.0, 14.0, 8.0), Color("#c9a400"), false, 2.0)
				else:
					draw_rect(Rect2(x, chain_y - 2.0, 14.0, 4.0), Color("#c9a400"))
				x += 12.0
				i += 1
		if lock_amount > 0.95:
			var lock_pos := Vector2(0, 66)
			draw_arc(lock_pos + Vector2(0, -12), 12.0, PI, TAU, 16, gold, 4.0)
			draw_rect(Rect2(lock_pos + Vector2(-16, -12), Vector2(32, 26)), gold)
			draw_circle(lock_pos, 4.0, Color.BLACK)


func _draw_title(alpha: float) -> void:
	if _glyphs.is_empty() or title_progress <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var n := _glyphs.size()
	var k := title_progress * n
	for i in n:
		var c := clampf(k - i, 0.0, 1.0)
		if c <= 0.0:
			break
		var g := _glyphs[i]
		var ch: String = g["ch"]
		var pos: Vector2 = g["pos"]
		# căldura: litera tocmai scrijelită e incandescentă și se răcește în auriu
		var hot := clampf(1.0 - (k - i - 1.0) / 2.5, 0.0, 1.0)
		# șanțul (umbra adâncă a tăieturii) + marginea luminată
		draw_char(font, pos + Vector2(1.5, 1.5), ch, title_font_size, Color(0.1, 0.03, 0.0, alpha * c))
		draw_char(font, pos + Vector2(-0.5, -0.5), ch, title_font_size, Color(1.0, 0.95, 0.75, alpha * c * 0.35))
		var col := GameState.COL_GOLD.lerp(Color(1.0, 1.0, 0.9), hot * 0.85)
		draw_char(font, pos, ch, title_font_size, Color(col, alpha * c))
		# zgârieturile dălții
		for mark: PackedVector2Array in _scratches[i]:
			draw_polyline(mark, Color(1.0, 0.92, 0.6, alpha * c * (0.2 + 0.6 * hot)), 1.0)
	# vârful dălții care taie litera curentă
	if title_progress < 1.0:
		var cur := mini(int(k), n - 1)
		var g := _glyphs[cur]
		var frac := k - cur
		var tip: Vector2 = g["pos"] + Vector2(float(g["w"]) * frac, -title_font_size * (0.35 + 0.3 * sin(_t * 55.0)))
		draw_circle(tip, 8.0, Color(GameState.COL_GOLD, 0.25 * alpha))
		draw_circle(tip, 3.0, Color(1, 1, 1, alpha))
