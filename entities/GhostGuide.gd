class_name GhostGuide
extends Node2D
## Fantoma Regelui: îl însoțește pe Cavaler prin subsoluri și îi dă sfaturi într-un balon.
## Stă într-un colț departe de Cavaler; balonul devine transparent când acoperă acțiunea.
## Tasta X ascunde / arată sfaturile (setare salvată în GameState.tips_enabled).
## Folosire (din DungeonFloor):
##   guide.target = player
##   guide.say("text", prioritate, durată)      # prioritate mare = întrerupe sfatul curent
##   guide.tip_once("first_hit")               # sfat unic pe tură (GameState.seen_tips)

const COL_GHOST := Color("#7ff3ff")
const SCREEN := Rect2(24, 70, 1104, 566)
const BUBBLE_WIDTH := 250.0
## Colțurile camerei în care stă fantoma (departe de Cavaler, ca să nu blocheze vederea).
const PERCHES: Array[Vector2] = [Vector2(104, 130), Vector2(1048, 130), Vector2(104, 548), Vector2(1048, 548)]
const MAX_QUEUE := 3

## Sfaturi generale, prin rotație pe etajele obișnuite.
const GENERAL_TIPS: Array[String] = [
	"Shield (L / Click) reflects projectiles toward the CURSOR. Aim before you parry!",
	"Parry at the last moment: the first 0.05s gives a PERFECT, faster and piercing.",
	"Reflected projectiles bounce once off walls. Use pillars for angled shots!",
	"If you raise your shield in vain, it takes half a second before you can raise it again.",
	"With one heart left, a PERFECT gives you a life back. That's BOUNCE BACK!",
	"Before attacking, shadows turn red and draw a line toward you. Watch for the tell.",
	"The sword (P) only hits up close. The shield can parry from a distance: choose wisely.",
	"Jump (Space) makes you invulnerable while airborne. Great against red spears!",
	"A PERFECT pierces every enemy in a line. Position yourself to hit several at once.",
	"After each boss, you regain all your health. Don't rush.",
	"Keep moving: projectiles aim for where you were when they were fired.",
]

## Primul etaj din fiecare capitol: cine sunt dușmanii și cum îi învingi.
const CHAPTER_TIPS: Array[String] = [
	"Chapter 1, Ghost Crypt. Ghosts fire single slow orbs. Practice your shield timing here!",
	"Chapter 2, Spirit Catacombs. Spirits fire three at once: parry the one coming at you.",
	"Chapter 3, Skeleton Ossuary. Archers flee and shoot fast. Watch the aim line!",
	"Chapter 4, Corrupted Barracks. My soldiers, the Phantom Knights: parry the blue sword, but not the RED SPEAR!",
	"Chapter 5, Book Abyss. All shadows at once. Keep moving and choose your targets.",
]

## Etajele de boss: puterea specială a fiecăruia.
const BOSS_TIPS: Array[String] = [
	"The Great Spirit vanishes and reappears elsewhere. When it summons ghosts, their orbs are ammo for you!",
	"The Oracle fires triple spreads. Parry the middle projectile and send it back!",
	"The Bone Commander unleashes arrow barrages. Parry the first arrow, then dodge the spread.",
	"My Royal Guard! When the line turns red, they charge at you: jump (Space) over the charge!",
	"The Book Avatar has every shadow power: teleport, charge, and spears. Breathe, and parry what you can.",
]

const EVENT_TIPS := {
	"first_floor": "It's me, the King! My spirit will accompany you through the catacombs and offer advice.",
	"first_hit": "Ouch! Raise your shield just before the hit lands, not after.",
	"low_hp": "One heart left! A PERFECT now gives you a life back!",
	"too_early": "Too early! Wait until the projectile is close.",
	"first_perfect": "That's it! A perfect parry is faster and pierces through everything.",
	"bounce_back": "You came back from death's door! That's how you BOUNCE BACK!",
	"first_spear": "Watch out! The RED SPEAR cannot be parried. Dodge or jump over it!",
	"first_clear": "The room is clear. Step onto the Abyssal Pit to descend.",
	"boss_phase": "It's enraged! Attacks are coming faster now.",
	"summon": "It called for help! Their projectiles are ammo for your shield.",
	"charge": "Charge! Jump (Space) or run to the side!",
	"blink": "It vanished! Look for the magenta smoke: that's where it reappears.",
	"boss_down": "You defeated it! Your health is restored. Let's move on.",
}

var target: Node2D

var _actor: Actor
var _bubble: PanelContainer
var _text: Label
var _queue: Array[Dictionary] = []
var _current_prio := -1
var _show_time := 0.0
var _gap := 0.0
var _perch := 0                 # colțul în care stă fantoma (index în PERCHES)
var _occlusion := 1.0           # 1 = vizibil, scade când balonul acoperă acțiunea
var _text_tween: Tween


func _ready() -> void:
	z_index = 45
	_actor = Actor.new()
	_actor.character_id = "king_old"
	_actor.tint = Color(0.55, 0.95, 1.0, 0.8)
	_actor.sprite_scale = 2.0
	_actor.float_bob = true
	add_child(_actor)
	_build_bubble()
	_perch = _best_perch()
	global_position = PERCHES[_perch]
	modulate.a = 0.0
	if GameState.tips_enabled:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	GameState.tips_toggled.connect(_on_tips_toggled)


# -----------------------------------------------------------------------------
#  API
# -----------------------------------------------------------------------------
func say(text: String, priority: int = 1, duration: float = 5.0) -> void:
	if not GameState.tips_enabled:
		return
	var item := {"text": text, "prio": priority, "dur": duration}
	if _show_time > 0.0 and priority > _current_prio:
		_show(item)  # întrerupe sfatul mai puțin important
		return
	if _show_time <= 0.0 and _gap <= 0.0 and _queue.is_empty():
		_show(item)
		return
	_queue.append(item)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) > int(b["prio"]))
	while _queue.size() > MAX_QUEUE:
		_queue.pop_back()


func tip_once(key: String, priority: int = 2, duration: float = 4.5) -> void:
	## Sfat de eveniment spus o singură dată pe tură.
	if not GameState.tips_enabled or GameState.seen_tips.has(key) or not EVENT_TIPS.has(key):
		return
	GameState.seen_tips.append(key)
	say(String(EVENT_TIPS[key]), priority, duration)


func tip_event(key: String, priority: int = 2, duration: float = 4.0) -> void:
	## Sfat de eveniment care se poate repeta.
	if EVENT_TIPS.has(key):
		say(String(EVENT_TIPS[key]), priority, duration)


func general_tip(index: int) -> String:
	return GENERAL_TIPS[posmod(index, GENERAL_TIPS.size())]


func hush() -> void:
	## Ascunde balonul (ex.: în timpul dialogurilor).
	_queue.clear()
	_show_time = 0.0
	_bubble.visible = false


# -----------------------------------------------------------------------------
#  Tasta X: ascunde / arată sfaturile
# -----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tips"):
		get_viewport().set_input_as_handled()
		GameState.set_tips_enabled(not GameState.tips_enabled)


func _on_tips_toggled(enabled: bool) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0 if enabled else 0.0, 0.25)
	if enabled:
		FX.popup(get_parent(), Vector2(576, 130), "KING'S TIPS ON  (X)", COL_GHOST, 20)
		say("Tips are back! Press X anytime to hide them.", 1, 3.5)
	else:
		hush()
		FX.popup(get_parent(), Vector2(576, 130), "KING'S TIPS OFF  (X)", Color(0.7, 0.7, 0.8), 20)


# -----------------------------------------------------------------------------
func _show(item: Dictionary) -> void:
	_current_prio = int(item["prio"])
	_show_time = float(item["dur"])
	_text.text = String(item["text"])
	_bubble.visible = true
	_bubble.reset_size()
	_bubble.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _text_tween:
		_text_tween.kill()
	_text.visible_ratio = 0.0
	_text_tween = create_tween()
	_text_tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / 70.0)
	var pulse := create_tween()
	pulse.tween_property(_actor, "scale", Vector2(1.25, 1.25), 0.1)
	pulse.tween_property(_actor, "scale", Vector2.ONE, 0.2)
	GameState.play_sfx("blip", false, -20.0)


func _process(delta: float) -> void:
	_move_to_perch(delta)
	var life := 1.0
	if _show_time > 0.0:
		_show_time -= delta
		life = clampf(_show_time / 0.6, 0.0, 1.0)
		if _show_time <= 0.0:
			_bubble.visible = false
			_current_prio = -1
			_gap = 0.5
	elif _gap > 0.0:
		_gap -= delta
	elif not _queue.is_empty():
		_show(_queue.pop_front())
	_place_bubble()
	# balonul devine aproape transparent când acoperă jucătorul, inamicii sau proiectilele
	var target_alpha := 0.15 if _covers_action() else 1.0
	_occlusion = lerpf(_occlusion, target_alpha, 1.0 - exp(-10.0 * delta))
	_bubble.modulate.a = _occlusion * life
	_actor.modulate.a = lerpf(0.35, 1.0, _occlusion)


# -----------------------------------------------------------------------------
#  Poziție: fantoma stă într-un colț al camerei, departe de Cavaler,
#  ca să nu blocheze vederea. Se mută doar când Cavalerul se apropie.
# -----------------------------------------------------------------------------
func _best_perch() -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var best := 0
	var best_d := -1.0
	for i in PERCHES.size():
		var d := PERCHES[i].distance_to(target.global_position)
		if d > best_d:
			best_d = d
			best = i
	return best


func _move_to_perch(delta: float) -> void:
	if target and is_instance_valid(target):
		if PERCHES[_perch].distance_to(target.global_position) < 300.0:
			_perch = _best_perch()
	global_position = global_position.lerp(PERCHES[_perch], 1.0 - exp(-3.0 * delta))
	_actor.face(1.0 if PERCHES[_perch].x < 576.0 else -1.0)


func _place_bubble() -> void:
	if not _bubble.visible:
		return
	var sz := _bubble.size
	var p := PERCHES[_perch]
	var left := p.x < 576.0
	var top := p.y < 324.0
	# balonul stă lângă fantomă, spre interiorul ecranului, lipit de colț
	var g := Vector2(p.x + 26.0 if left else p.x - 26.0 - sz.x, p.y - 22.0 if top else p.y + 22.0 - sz.y)
	g.x = clampf(g.x, SCREEN.position.x, SCREEN.end.x - sz.x)
	g.y = clampf(g.y, SCREEN.position.y, SCREEN.end.y - sz.y)
	_bubble.position = g - global_position
	_bubble.pivot_offset = Vector2(0.0 if left else sz.x, 0.0 if top else sz.y)


func bubble_rect() -> Rect2:
	return Rect2(_bubble.global_position, _bubble.size)


func _covers_action() -> bool:
	if not _bubble.visible:
		return false
	var r := bubble_rect().grow(26.0)
	if target and is_instance_valid(target) and r.has_point(target.global_position):
		return true
	for n in get_tree().get_nodes_in_group("enemies"):
		if r.has_point((n as Node2D).global_position):
			return true
	for n in get_tree().get_nodes_in_group("projectiles"):
		if r.has_point((n as Node2D).global_position):
			return true
	return false


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.z_index = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.88)
	style.border_color = COL_GHOST
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.5, 0.95, 1.0, 0.2)
	style.shadow_size = 6
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 1)
	_bubble.add_child(vb)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	var who := Label.new()
	who.text = "The King (Ghost)"
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_font_size_override("font_size", 12)
	who.add_theme_color_override("font_color", COL_GHOST)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	var hint := Label.new()
	hint.text = "[X] hide tips"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(GameState.COL_TEXT, 0.5))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hint)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BUBBLE_WIDTH, 0)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_font_size_override("font_size", 14)
	_text.add_theme_color_override("font_color", GameState.COL_TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text)
	_bubble.visible = false
