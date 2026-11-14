class_name GhostGuide
extends Node2D
## Fantoma Regelui: îl însoțește pe Cavaler prin subsoluri și îi dă sfaturi într-un balon.
## Folosire (din DungeonFloor):
##   guide.target = player
##   guide.say("text", prioritate, durată)      # prioritate mare = întrerupe sfatul curent
##   guide.tip_once("first_hit")               # sfat unic pe tură (GameState.seen_tips)

const COL_GHOST := Color("#7ff3ff")
const SCREEN := Rect2(24, 70, 1104, 566)
const BUBBLE_WIDTH := 300.0
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
var _side := -1.0   # -1 = stânga jucătorului, 1 = dreapta
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
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	if target:
		global_position = target.global_position + Vector2(-60, -60)


# -----------------------------------------------------------------------------
#  API
# -----------------------------------------------------------------------------
func say(text: String, priority: int = 1, duration: float = 5.0) -> void:
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
	if GameState.seen_tips.has(key) or not EVENT_TIPS.has(key):
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
func _show(item: Dictionary) -> void:
	_current_prio = int(item["prio"])
	_show_time = float(item["dur"])
	_text.text = String(item["text"])
	_bubble.visible = true
	_bubble.reset_size()
	_bubble.scale = Vector2(0.7, 0.7)
	_bubble.modulate.a = 1.0
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
	_follow(delta)
	if _show_time > 0.0:
		_show_time -= delta
		if _show_time <= 0.6:
			_bubble.modulate.a = clampf(_show_time / 0.6, 0.0, 1.0)
		if _show_time <= 0.0:
			_bubble.visible = false
			_current_prio = -1
			_gap = 0.5
	elif _gap > 0.0:
		_gap -= delta
	elif not _queue.is_empty():
		_show(_queue.pop_front())
	_place_bubble()


func _follow(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var tp := target.global_position
	# trece de partea cealaltă când jucătorul se apropie de margine
	if tp.x < SCREEN.position.x + 140.0:
		_side = 1.0
	elif tp.x > SCREEN.end.x - 140.0:
		_side = -1.0
	var desired := tp + Vector2(62.0 * _side, -58.0)
	desired = desired.clamp(SCREEN.position + Vector2(20, 40), SCREEN.end - Vector2(20, 20))
	global_position = global_position.lerp(desired, 1.0 - exp(-4.0 * delta))
	_actor.face(-_side)


func _place_bubble() -> void:
	if not _bubble.visible:
		return
	var sz := _bubble.size
	var local := Vector2(-sz.x * 0.5, -sz.y - 30.0)
	var g := global_position + local
	# ține balonul pe ecran (sub bara HUD-ului)
	g.x = clampf(g.x, SCREEN.position.x, SCREEN.end.x - sz.x)
	if g.y < SCREEN.position.y:
		g.y = global_position.y + 30.0   # nu încape deasupra -> sub fantomă
	_bubble.position = g - global_position
	_bubble.pivot_offset = Vector2(sz.x * 0.5, sz.y)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.z_index = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 0.92)
	style.border_color = COL_GHOST
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.5, 0.95, 1.0, 0.2)
	style.shadow_size = 6
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_bubble.add_child(vb)
	var who := Label.new()
	who.text = "The King (Ghost)"
	who.add_theme_font_size_override("font_size", 13)
	who.add_theme_color_override("font_color", COL_GHOST)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BUBBLE_WIDTH, 0)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", GameState.COL_TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_text)
	_bubble.visible = false
