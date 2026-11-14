extends Node2D
## PARTER (Etajul 0) – Sala Oglinzii.
##  Vizita 1: Cavalerul înaintează, apare Regele spectral, jucătorul își scrie numele,
##            Regele îl trimite spre Subsolul -50, se deschide trapa spre -1.
##  Vizita 2: Cavalerul toarnă Poțiunea în oglindă, Regele reînvie tânăr, primește Coroana,
##            amândoi urcă scările spre +1 și +2 (Sala Tronului).

const KING_GHOST_TINT := Color(0.55, 0.95, 1.0, 0.85)
const COL_NARRATOR := Color("#ff7bff")
const COL_KING_GHOST := Color("#7ff3ff")

const KING_SPEECH := "Listen to me, %s! While searching for my lost treasure, I unleashed the curse of the Book of Darkness and was trapped in this mirror. I can guide you through the catacombs! Descend to Dungeon Floor -50, face the shadow army by turning their own attacks against them, and find the Royal Treasure!"

@onready var camera: ShakeCamera = $Camera2D
@onready var mirror: MagicMirror = $Mirror
@onready var king_ghost: Actor = $Mirror/KingGhost
@onready var mirror_sparkles: CPUParticles2D = $Mirror/Sparkles
@onready var trapdoor: Trapdoor = $Trapdoor
@onready var stairs: Stairs = $Stairs
@onready var knight: Actor = $Knight
@onready var king: Actor = $King
@onready var crown: Crown = $Crown
@onready var potion: Sprite2D = $Potion
@onready var pour_particles: CPUParticles2D = $Potion/Pour
@onready var dialog: DialogBox = $DialogBox
@onready var ui: CanvasLayer = $UI

signal name_confirmed(player_name: String)

var _name_panel: PanelContainer
var _name_edit: LineEdit
var _t := 0.0


func _ready() -> void:
	GameState.current_floor = 0
	GameState.checkpoint(0)
	king_ghost.modulate.a = 0.0
	king.visible = false
	crown.visible = false
	potion.visible = false
	trapdoor.visible = false
	_build_name_panel()
	if GameState.mirror_visit >= 2 and GameState.has_potion:
		_revival_sequence()
	else:
		_first_visit_sequence()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# =============================================================================
#  VIZITA 1
# =============================================================================
func _first_visit_sequence() -> void:
	knight.position = Vector2(576, 720)
	await knight.walk_to(Vector2(576, 420), 120.0).finished
	await dialog.say("", "The Knight steps onto the checkered floor of the Ground Floor. Before him rises the Cursed Mirror.", COL_NARRATOR)
	# silueta spectrală a Regelui apare în oglindă
	GameState.play_sfx("magic", false, -6.0)
	mirror_sparkles.emitting = true
	var t := create_tween()
	t.tween_property(king_ghost, "modulate:a", 0.3, 0.25)
	t.tween_property(king_ghost, "modulate:a", 0.05, 0.15)
	t.tween_property(king_ghost, "modulate:a", 1.0, 0.8)
	await t.finished
	await dialog.say("", "In the depths of the shattered glass, the spectral silhouette of an old king takes shape.", COL_NARRATOR)
	await dialog.say("The King (in the mirror)", "A living soul... after so long! Tell me, Knight, what is your name?", COL_KING_GHOST)
	dialog.close()
	var entered_name: String = await _ask_name()
	GameState.player_name = entered_name
	await dialog.say("The King (in the mirror)", KING_SPEECH % GameState.player_name, COL_KING_GHOST)
	await dialog.say("The King (in the mirror)", "Attack shadows with P, raise your shield with L just before a projectile hits to reflect it toward the cursor, and press Space to leap over attacks!", COL_KING_GHOST)
	# se deschide trapa către Subsolul -1
	trapdoor.caption = "DUNGEON FLOOR -1"
	await trapdoor.open_door(0.9).finished
	GameState.shake(5.0)
	await dialog.say("The King (in the mirror)", "The trapdoor to Dungeon Floor -1 is open. Go, %s! My kingdom depends on you." % GameState.player_name, COL_KING_GHOST)
	dialog.close()
	await knight.walk_to(trapdoor.position, 120.0).finished
	await _fall_into(trapdoor.position)
	GameState.travel_to(-1)


func _fall_into(pos: Vector2) -> void:
	GameState.play_sfx("swing", false)
	var t := create_tween().set_parallel()
	t.tween_property(knight, "scale", Vector2(0.1, 0.1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(knight, "position", pos + Vector2(0, 10), 0.45)
	t.tween_property(knight, "rotation", TAU, 0.45)
	await t.finished
	knight.visible = false


func _ask_name() -> String:
	_name_panel.visible = true
	_name_edit.text = GameState.player_name if GameState.player_name != "Knight" else ""
	_name_edit.grab_focus()
	var result: String = await name_confirmed
	_name_panel.visible = false
	return result


func _confirm_name(_text: String = "") -> void:
	if not _name_panel.visible:
		return
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		n = "Knight"
	GameState.play_sfx("parry", false)
	name_confirmed.emit(n.substr(0, 16))


# =============================================================================
#  VIZITA 2 – Poțiunea Vieții Veșnice
# =============================================================================
func _revival_sequence() -> void:
	var pname := GameState.player_name
	king_ghost.modulate.a = 0.55
	mirror_sparkles.emitting = true
	# Cavalerul revine prin trapă („Bounce Back”)
	trapdoor.visible = true
	trapdoor.open_amount = 1.0
	knight.position = trapdoor.position
	knight.scale = Vector2(0.1, 0.1)
	var rise := create_tween()
	rise.tween_property(knight, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(knight, "position:y", trapdoor.position.y - 40.0, 0.5)
	await rise.finished
	FX.burst(self, knight.position, GameState.COL_GOLD, 30, 220.0, 0.6, 4.0)
	create_tween().tween_property(trapdoor, "open_amount", 0.0, 0.5)
	await knight.walk_to(Vector2(560, 360), 110.0).finished
	trapdoor.visible = false
	knight.face(1.0)
	await dialog.say("The King (in the mirror)", "%s! You've returned from the depths... I can feel the glow of my treasure upon you!" % pname, COL_KING_GHOST)
	await dialog.say(pname, "I found the Royal Treasure, Your Majesty. Gold, the Crown... and the Potion of Eternal Life.", Color.WHITE)
	await dialog.say(pname, "It could grant me eternal youth. But it doesn't belong to me. It's yours.", Color.WHITE)
	await dialog.say("", "The Knight pours the Potion into the Shattered Mirror...", COL_NARRATOR)
	dialog.close()
	await _pour_potion()
	await _mirror_blaze()
	await dialog.say("The King", "Flesh... blood... I am ALIVE! Young again! The mirror's curse is broken!", GameState.COL_GOLD)
	await dialog.say("", "The Knight gives the King the Royal Crown.", COL_NARRATOR)
	dialog.close()
	await _offer_crown()
	await dialog.say("The King", "You descended into the abyss for me, %s. Come! Let's ascend together to the Throne Room on Floor +2!" % pname, GameState.COL_GOLD)
	dialog.close()
	await _walk_upstairs()
	GameState.travel_to(GameState.TOP_FLOOR)


func _pour_potion() -> void:
	potion.visible = true
	potion.position = knight.position + Vector2(10, -40)
	var mid := Vector2(580, 120)
	var target := Vector2(600, 100)
	GameState.play_sfx("magic", false, -8.0)
	var t := create_tween()
	t.tween_property(potion, "position", mid, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(potion, "position", target, 0.3)
	t.tween_property(potion, "rotation", deg_to_rad(140.0), 0.35)
	await t.finished
	pour_particles.emitting = true
	var glow := create_tween()
	glow.tween_property(mirror, "glow", 0.35, 1.4)
	await glow.finished
	pour_particles.emitting = false
	var hide_t := create_tween()
	hide_t.tween_property(potion, "modulate:a", 0.0, 0.3)
	await hide_t.finished
	potion.visible = false


func _mirror_blaze() -> void:
	# Oglinda strălucește orbitor -> Regele reînvie în carne și oase.
	GameState.play_sfx("heal", false, -2.0)
	var t := create_tween()
	t.tween_property(mirror, "glow", 1.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await t.finished
	GameState.shake(14.0)
	var flash := FX.flash_screen(self, Color.WHITE, 1.6)
	mirror.cracked = false
	king_ghost.visible = false
	mirror_sparkles.emitting = false
	king.visible = true
	king.position = Vector2(620, 300)
	king.face(-1.0)
	FX.burst(self, king.position, GameState.COL_GOLD, 40, 260.0, 0.9, 4.0)
	var fade := create_tween()
	fade.tween_property(mirror, "glow", 0.0, 1.4)
	await flash.finished
	await king.walk_to(Vector2(620, 360), 60.0).finished
	king.face(-1.0)


func _offer_crown() -> void:
	crown.visible = true
	crown.position = knight.position + Vector2(0, -50)
	crown.scale = Vector2(0.2, 0.2)
	GameState.play_sfx("magic", false, -6.0)
	var t := create_tween()
	t.tween_property(crown, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(crown, "position", king.position + Vector2(22, -14), 0.7).set_trans(Tween.TRANS_SINE)
	await t.finished
	# Regele ține coroana; și-o va pune pe cap în Sala Tronului
	crown.reparent(king)


func _walk_upstairs() -> void:
	var foot := stairs.position + Vector2(10, 10)
	var top := stairs.position + Vector2(110, -150)
	var a := king.walk_to(foot + Vector2(30, 0), 120.0)
	knight.walk_to(foot - Vector2(30, -10), 120.0)
	await a.finished
	var up := create_tween().set_parallel()
	up.tween_property(king, "position", top, 1.0)
	up.tween_property(knight, "position", top + Vector2(-40, 20), 1.1)
	up.tween_property(king, "modulate:a", 0.0, 1.0)
	up.tween_property(knight, "modulate:a", 0.0, 1.1)
	await up.finished


# =============================================================================
#  UI: caseta pentru nume (LineEdit)
# =============================================================================
func _build_name_panel() -> void:
	_name_panel = PanelContainer.new()
	_name_panel.position = Vector2(336, 470)
	_name_panel.size = Vector2(480, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.07, 0.95)
	style.border_color = GameState.COL_GOLD
	style.set_border_width_all(3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_name_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(_name_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_name_panel.add_child(vb)
	var title := Label.new()
	title.text = "What is your name, Knight?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameState.COL_GOLD)
	vb.add_child(title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name..."
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(0, 42)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.text_submitted.connect(_confirm_name)
	hb.add_child(_name_edit)
	var btn := Button.new()
	btn.text = "Confirm"
	btn.custom_minimum_size = Vector2(120, 42)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_confirm_name)
	hb.add_child(btn)
	_name_panel.visible = false


# =============================================================================
#  Decor: peretele din spate (neon) – podeaua e CheckerFloor
# =============================================================================
func _draw() -> void:
	var mag := GameState.COL_MAGENTA
	draw_rect(Rect2(0, 0, 1152, 236), Color("#100820"))
	# arcade pe perete
	for i in 6:
		var x := 40.0 + i * 190.0
		if x > 420.0 and x < 720.0:
			continue
		var r := Rect2(x, 70, 110, 166)
		draw_rect(r, Color("#0a0414"))
		draw_rect(r, Color(mag, 0.5), false, 2.0)
	# brâu neon la baza peretelui
	draw_rect(Rect2(0, 232, 1152, 4), mag)
	draw_rect(Rect2(0, 226, 1152, 16), Color(mag, 0.12))
	# puncte aurii (Tomb of the Mask)
	for i in 36:
		var p := Vector2(16 + i * 32, 252)
		draw_rect(Rect2(p, Vector2(3, 3)), Color(GameState.COL_GOLD, 0.25 + 0.2 * sin(_t * 2.0 + i)))
