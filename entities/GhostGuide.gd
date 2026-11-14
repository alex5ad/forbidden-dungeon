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
	"Scutul (L / Click) întoarce proiectilul spre CURSOR. Țintește înainte să parezi!",
	"Parează în ultima clipă: primele 0.05 secunde dau un PERFECT, mai rapid și care străpunge tot.",
	"Proiectilele întoarse ricoșează o dată din pereți. Folosește stâlpii pentru lovituri din unghi!",
	"Dacă ridici scutul degeaba, îți trebuie o jumătate de secundă până îl ridici din nou.",
	"Cu o singură inimă, un PERFECT îți dă o viață înapoi. Asta înseamnă BOUNCE BACK!",
	"Înainte să atace, umbrele se înroșesc și trag o linie spre tine. Fii atent la semn.",
	"Sabia (P) lovește doar de aproape. Scutul lovește de la distanță: alege bine.",
	"Saltul (Space) te face invulnerabil cât ești în aer. Bun pentru sulițele roșii!",
	"Un PERFECT trece prin toți dușmanii aliniați. Așază-te ca să prinzi mai mulți deodată.",
	"După fiecare boss învins îți recapeți toată viața. Nu te grăbi.",
	"Stai în mișcare: proiectilele țintesc locul în care erai când au fost trase.",
]

## Primul etaj din fiecare capitol: cine sunt dușmanii și cum îi învingi.
const CHAPTER_TIPS: Array[String] = [
	"Capitolul 1, Cripta Fantomelor. Fantomele trag câte un glob lent. Exersează aici momentul scutului!",
	"Capitolul 2, Catacombele Spiritelor. Spiritele trag câte trei odată: parează-l pe cel care vine spre tine.",
	"Capitolul 3, Osuarul Scheleților. Arcașii fug de tine și trag repede. Urmărește linia de ochire!",
	"Capitolul 4, Cazarma Coruptă. Soldații mei, Cavalerii Fantomă: sabia albastră se parează, sulița ROȘIE nu!",
	"Capitolul 5, Abisul Cărții. Toate umbrele deodată. Ține-te în mișcare și alege-ți țintele.",
]

## Etajele de boss: puterea specială a fiecăruia.
const BOSS_TIPS: Array[String] = [
	"Marele Duh dispare și reapare în alt loc. Când cheamă fantome, globurile lor sunt muniție pentru tine!",
	"Oracolul trage evantaie triple. Parează proiectilul din mijloc și trimite-l înapoi spre el.",
	"Comandantul de Os aruncă ploi de săgeți. Parează prima săgeată, apoi ieși din evantai.",
	"Garda mea Regală! Când linia e roșie, se aruncă spre tine: sari (Space) peste șarjă!",
	"Avatarul Cărții are toate puterile umbrelor: teleport, șarjă, sulițe. Respiră și parează doar ce poți.",
]

const EVENT_TIPS := {
	"first_floor": "Sunt eu, Regele! Spiritul meu te va însoți prin catacombe și îți voi da sfaturi.",
	"first_hit": "Au! Ridică scutul chiar înainte ca lovitura să te atingă, nu după.",
	"low_hp": "O singură inimă! Un PERFECT acum îți dă o viață înapoi!",
	"too_early": "Prea devreme! Așteaptă până când proiectilul e aproape de tine.",
	"first_perfect": "Asta e! Lovitura perfectă e mai rapidă și străpunge tot.",
	"bounce_back": "Ai revenit din pragul morții! Așa se face: BOUNCE BACK!",
	"first_spear": "Atenție! Sulița ROȘIE nu se poate para. Ferește-te sau sari peste ea!",
	"first_clear": "Camera e liberă. Calcă pe Puțul Abisal ca să cobori.",
	"boss_phase": "S-a înfuriat! Atacurile vin mai des acum.",
	"summon": "A chemat ajutoare! Loviturile lor sunt muniție pentru scutul tău.",
	"charge": "Șarjă! Sari (Space) sau fugi într-o parte!",
	"blink": "A dispărut! Caută fumul magenta: acolo reapare.",
	"boss_down": "L-ai învins! Viața ți-a revenit. Mergem mai departe.",
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
	who.text = "Regele (fantoma)"
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
