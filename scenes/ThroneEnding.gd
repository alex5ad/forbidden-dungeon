extends Node2D
## ACTUL IV – Etajul +2, Sala Tronului.
## Regele își pune Coroana și se așază pe tron -> vârtej de lumină absoarbe întunericul
## în Cartea Blestemată -> cartea se trântește și se ferecă, apare titlul „FORBIDDEN REDEMPTION”
## -> fantomele/scheleții redevin oameni, Cavalerii Fantomă îngenunchează,
## jucătorul e numit Generalul Armatei Regale.

const THRONE_POS := Vector2(576, 214)
const COL_NARRATOR := Color("#ff7bff")

## [poziție, aspect blestemat, aspect după transformare]
const SPIRITS := [
	[Vector2(180, 300), "ghost", "villager_1"],
	[Vector2(300, 380), "skeleton", "villager_2"],
	[Vector2(170, 470), "phantom_knight", "royal_knight"],
	[Vector2(330, 540), "ghost", "villager_3"],
	[Vector2(420, 300), "phantom_knight", "royal_knight"],
	[Vector2(972, 300), "ghost", "villager_4"],
	[Vector2(852, 380), "skeleton", "villager_5"],
	[Vector2(982, 470), "phantom_knight", "royal_knight"],
	[Vector2(822, 540), "spirit", "villager_6"],
	[Vector2(732, 300), "phantom_knight", "royal_knight"],
]

@onready var camera: ShakeCamera = $Camera2D
@onready var throne: Throne = $Throne
@onready var spirits_root: Node2D = $Spirits
@onready var king: Actor = $King
@onready var knight: Actor = $Knight
@onready var crown: Crown = $Crown
@onready var vortex: CPUParticles2D = $Vortex
@onready var book: DarkBook = $Book
@onready var dialog: DialogBox = $DialogBox
@onready var title_banner: Label = $UI/TitleBanner
@onready var end_panel: PanelContainer = $UI/EndPanel
@onready var stats_label: Label = $UI/EndPanel/VBox/Stats
@onready var replay_button: Button = $UI/EndPanel/VBox/Replay
@onready var confetti: CPUParticles2D = $UI/Confetti

var _spirits: Array[Actor] = []
var _t := 0.0


func _ready() -> void:
	GameState.current_floor = GameState.TOP_FLOOR
	GameState.checkpoint(GameState.TOP_FLOOR)
	book.visible = false
	book.scale = Vector2.ZERO
	end_panel.visible = false
	title_banner.modulate.a = 0.0
	replay_button.pressed.connect(_on_replay)
	UiKit.style_button(replay_button, GameState.COL_GOLD, 20)
	_spawn_spirits()
	crown.reparent(king)
	crown.position = Vector2(26, -6)
	_sequence()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _spawn_spirits() -> void:
	for entry: Array in SPIRITS:
		var a := Actor.new()
		var look: String = entry[1]
		a.character_id = look
		a.sprite_scale = 2.0
		a.float_bob = look != "skeleton"
		a.tint = Color(0.6, 0.75, 1.0, 0.75) if look != "skeleton" else Color(0.8, 0.8, 0.9, 1.0)
		a.position = entry[0]
		a.face_left = a.position.x > 576.0
		a.set_meta("after", entry[2])
		spirits_root.add_child(a)
		_spirits.append(a)


func _sequence() -> void:
	var pname := GameState.player_name
	# intrarea: Regele și Cavalerul urcă pe covorul roșu
	king.position = Vector2(600, 700)
	knight.position = Vector2(540, 720)
	var k := king.walk_to(Vector2(600, 380), 110.0)
	knight.walk_to(Vector2(536, 400), 110.0)
	await k.finished
	await dialog.say("The King", "The Throne Room... Once full of life. Now haunted by my own people, turned into shadows.", GameState.COL_GOLD)
	await dialog.say("The King", "Let's put an end to the curse, %s." % pname, GameState.COL_GOLD)
	dialog.close()
	# Regele urcă la tron și își pune Coroana pe cap
	await king.walk_to(THRONE_POS + Vector2(0, -14), 90.0).finished
	king.face(1.0)
	king.z_index = 2
	var c := create_tween()
	c.tween_property(crown, "position", Vector2(0, -34), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await c.finished
	crown.glow = false
	GameState.play_sfx("heal", false)
	GameState.shake(6.0)
	FX.burst(self, king.global_position + Vector2(0, -34), GameState.COL_GOLD, 40, 240.0, 0.8, 4.0)
	await dialog.say("", "The King places the Crown on his head and sits upon the Royal Throne.", COL_NARRATOR)
	# vârtejul de lumină
	await _vortex_sequence()
	# transformarea finală
	await _transformation()
	await knight.walk_to(Vector2(650, 260), 100.0).finished
	knight.face(-1.0)
	await dialog.say("The King", "My people live again! %s, you turned darkness against itself." % pname, GameState.COL_GOLD)
	await dialog.say("The King", "From this day forth, I name you GENERAL OF THE ROYAL ARMY!", GameState.COL_GOLD)
	dialog.close()
	_show_general_title()
	await get_tree().create_timer(2.4).timeout
	_show_end_panel()


func _vortex_sequence() -> void:
	book.visible = true
	GameState.play_sfx("magic", false)
	var appear := create_tween().set_parallel()
	appear.tween_property(book, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(book, "vortex", 1.0, 1.2)
	vortex.emitting = true
	for s in _spirits:
		s.set_tremble(1.2)
	var rumble := create_tween().set_loops(6)
	rumble.tween_callback(func(): GameState.shake(4.0))
	rumble.tween_interval(0.35)
	await dialog.say("", "A vortex of light sweeps all the darkness from the castle back into the Cursed Book it came from!", COL_NARRATOR)
	dialog.close()
	for s in _spirits:
		FX.burst(self, s.global_position, Color(0.25, 0.0, 0.35), 16, 120.0, 0.5, 4.0)
	await get_tree().create_timer(1.0).timeout
	# Cartea se trântește...
	vortex.emitting = false
	var slam := create_tween()
	slam.tween_property(book, "vortex", 0.0, 0.2)
	slam.parallel().tween_property(book, "open_amount", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await slam.finished
	GameState.play_sfx("slam", false, 0.0)
	GameState.shake(20.0)
	GameState.hitstop(0.12, 0.05)
	FX.flash_screen(self, Color.WHITE, 0.4)
	for s in _spirits:
		s.set_tremble(0.0)
	await get_tree().create_timer(0.5).timeout
	# ...și se ferecă
	GameState.play_sfx("parry", false)
	var lock := create_tween()
	lock.tween_property(book, "lock_amount", 1.0, 0.8)
	await lock.finished
	GameState.play_sfx("perfect", false)
	# titlul jocului apare cu litere aurii pe copertă
	await book.engrave(2.6).finished
	await get_tree().create_timer(1.6).timeout
	var shrink := create_tween().set_parallel()
	shrink.tween_property(book, "position", Vector2(1050, 560), 0.8).set_trans(Tween.TRANS_SINE)
	shrink.tween_property(book, "scale", Vector2(0.5, 0.5), 0.8).set_trans(Tween.TRANS_SINE)
	await shrink.finished


func _transformation() -> void:
	GameState.play_sfx("heal", false)
	for s in _spirits:
		var after: String = s.get_meta("after")
		FX.burst(self, s.global_position, GameState.COL_GOLD, 24, 200.0, 0.6, 3.0)
		s.set_character(after, Color.WHITE)
		s.float_bob = false
		s.face(THRONE_POS.x - s.position.x)
		if after == "royal_knight":
			# Cavalerii își recapătă chipul uman și îngenunchează
			var kneel := create_tween()
			kneel.tween_property(s, "scale", Vector2(1.1, 0.78), 0.25).set_trans(Tween.TRANS_BACK)
			kneel.parallel().tween_property(s, "position:y", s.position.y + 6.0, 0.25)
		else:
			var hop := create_tween().set_loops(2)
			hop.tween_property(s, "position:y", s.position.y - 14.0, 0.18).set_ease(Tween.EASE_OUT)
			hop.tween_property(s, "position:y", s.position.y, 0.18).set_ease(Tween.EASE_IN)
		GameState.play_sfx("blip", true, -12.0)
		await get_tree().create_timer(0.12).timeout
	await dialog.say("", "The ghosts and skeletons return to life as the castle's former inhabitants! The Phantom Knights regain their human forms and kneel before the King and %s." % GameState.player_name, COL_NARRATOR)
	dialog.close()


func _show_general_title() -> void:
	title_banner.text = "%s\nGENERAL OF THE ROYAL ARMY" % GameState.player_name.to_upper()
	title_banner.scale = Vector2(1.5, 1.5)
	confetti.emitting = true
	GameState.play_sfx("perfect", false)
	GameState.shake(8.0)
	var t := create_tween()
	t.tween_property(title_banner, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(title_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_end_panel() -> void:
	stats_label.text = "Parries: %d   (Perfect: %d)\nBounce Backs at 1 HP: %d\nShadows Defeated: %d\nDeaths: %d\nCoins earned: %d\nTime: %s" % [
		GameState.parries, GameState.perfect_parries, GameState.bounce_backs,
		GameState.kills, GameState.deaths, GameState.run_coins, GameState.run_time_text()]
	GameState.finish_run()   # povestea s-a terminat: monedele și obiectele rămân
	end_panel.visible = true
	end_panel.modulate.a = 0.0
	create_tween().tween_property(end_panel, "modulate:a", 1.0, 0.4)
	replay_button.grab_focus()


func _on_replay() -> void:
	GameState.reset_run()
	GameState.go_home()


# -----------------------------------------------------------------------------
#  Decor: perete cu arcade neon, covor roșu (podeaua e CheckerFloor)
# -----------------------------------------------------------------------------
func _draw() -> void:
	var mag := GameState.COL_MAGENTA
	var gold := GameState.COL_GOLD
	draw_rect(Rect2(0, 0, 1152, 236), Color("#100820"))
	for i in 7:
		var x := 30.0 + i * 160.0
		if x > 440.0 and x < 700.0:
			continue
		var r := Rect2(x, 60, 100, 176)
		draw_rect(r, Color("#0a0414"))
		draw_rect(r, Color(mag, 0.55), false, 2.0)
		# vitralii aurii
		draw_rect(Rect2(x + 40, 90, 20, 60), Color(gold, 0.15 + 0.1 * sin(_t * 2.0 + i)))
	draw_rect(Rect2(0, 232, 1152, 4), mag)
	draw_rect(Rect2(0, 226, 1152, 16), Color(mag, 0.12))
