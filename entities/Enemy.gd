class_name Enemy
extends CharacterBody2D
## Un singur script pentru toți inamicii și boșii (configurați din Enemy.tscn / DungeonFloor).
##  enemy_type 0 = Fantomă         (Subsol -1..-9)   1 glob ectoplasmic lent
##  enemy_type 1 = Spirit          (Subsol -11..-19) evantai de 3 proiectile
##  enemy_type 2 = Schelet Arcaș   (Subsol -21..-29) săgeți rapide
##  enemy_type 3 = Cavaler Fantomă (Subsol -31..-49) săbii spectrale / sulițe roșii NEREFLECTABILE
##  is_boss = true + boss_index 1..5 -> boșii de la -10, -20, -30, -40, -50 (10..25 HP, faze).
## Fiecare boss e o variantă mai puternică a inamicilor din capitolul lui, cu aceleași puteri:
##  1 Marele Duh      -> globuri + TELEPORT (dispare și reapare)
##  2 Oracolul        -> evantaie TRIPLE + spirale
##  3 Comandantul     -> salve + PLOAIE DE SĂGEȚI
##  4 Garda Căzută    -> săbii, sulițe roșii + ȘARJĂ (damage la contact, se evită cu saltul)
##  5 Avatarul Cărții -> toate puterile de mai sus
## Din faza 2, boșii cheamă ajutoare din capitolul lor (summon_requested -> DungeonFloor).

signal died(enemy: Enemy)
signal hp_changed(hp: int, max_hp: int)
signal summon_requested(enemy_type: int, at: Vector2)
signal special_used(kind: String)   # "blink", "charge", "summon", "phase"

enum Type { GHOST, SPIRIT, SKELETON_ARCHER, PHANTOM_KNIGHT }
enum State { COOLDOWN, TELEGRAPH, FIRING }

const PROJECTILE_SCENE := preload("res://entities/Projectile.tscn")
const CHARGE_SPEED := 560.0
const CHARGE_TIME := 0.5
const MAX_MINIONS := 3

const TYPE_DATA := {
	Type.GHOST: {"name": "Ghost", "look": "ghost", "tint": Color(0.75, 1.0, 0.95, 0.85),
		"cooldown": Vector2(1.8, 3.0), "move": 35.0, "float": true},
	Type.SPIRIT: {"name": "Spirit", "look": "spirit", "tint": Color(0.85, 0.7, 1.0, 0.9),
		"cooldown": Vector2(2.0, 3.2), "move": 45.0, "float": true},
	Type.SKELETON_ARCHER: {"name": "Skeleton Archer", "look": "skeleton", "tint": Color(1, 1, 1, 1),
		"cooldown": Vector2(1.6, 2.6), "move": 55.0, "float": false},
	Type.PHANTOM_KNIGHT: {"name": "Phantom Knight", "look": "phantom_knight", "tint": Color(0.55, 0.75, 1.0, 0.8),
		"cooldown": Vector2(1.5, 2.5), "move": 50.0, "float": true},
}

## Aspectul boșilor (numele și HP-ul vin din GameState.ZONES).
const BOSS_LOOK := [
	{},
	{"look": "ghost", "scale": 4.0, "tint": Color(1.0, 0.65, 1.0, 0.9), "float": true},
	{"look": "spirit", "scale": 5.0, "tint": Color(0.8, 0.55, 1.0, 0.95), "float": true},
	{"look": "skeleton", "scale": 4.0, "tint": Color(1.0, 0.95, 0.75, 1.0), "float": false},
	{"look": "phantom_knight", "scale": 4.0, "tint": Color(1.0, 0.45, 0.5, 0.85), "float": true},
	{"look": "demon", "scale": 3.0, "tint": Color(0.85, 0.6, 1.0, 1.0), "float": false},
]

@export var enemy_type: Type = Type.GHOST
@export var is_boss := false
@export_range(0, 5) var boss_index := 0
@export var max_hp := 1
## Ritmul inamicului (GameState.floor_difficulty): cooldown mai scurt, proiectile mai rapide.
@export var difficulty := 1.0
## Ajutor chemat de un boss (dispare când boss-ul moare).
@export var is_minion := false
## Zona în care se plimbă (setată de DungeonFloor).
@export var arena_rect := Rect2(112, 128, 928, 448)

var hp := 1
var display_name := ""
var projectile_parent: Node

var _state := State.COOLDOWN
var _timer := 0.0
var _telegraph_total := 0.6
var _telegraph_aimed := true
var _telegraph_danger := false
var _queue: Array[Dictionary] = []
var _fire_clock := 0.0
var _attack_count := 0
var _phase := 1
var _move_speed := 40.0
var _floats := false
var _base_tint := Color.WHITE
var _sprite_scale := 2.0
var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
var _flash := 0.0
var _knockback := Vector2.ZERO
var _charge_time := 0.0
var _charge_dir := Vector2.ZERO
var _charge_contact := false
var _alpha_mult := 1.0
var _anim_t := 0.0
var _dead := false
var _player: Player

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if is_minion:
		add_to_group("minions")
	_configure()
	hp = max_hp
	_timer = randf_range(1.0, 1.8) if is_boss else randf_range(0.7, 1.8)
	_anim_t = randf() * TAU
	_pick_wander_target()
	if projectile_parent == null:
		projectile_parent = get_parent()


func _configure() -> void:
	collision.shape = collision.shape.duplicate()  # nu modifica resursa partajată
	var look := "ghost"
	if is_boss:
		boss_index = clampi(boss_index, 1, 5)
		var b: Dictionary = BOSS_LOOK[boss_index]
		var zone: Dictionary = GameState.ZONES[boss_index - 1]
		display_name = String(zone["boss"])
		max_hp = int(zone["boss_hp"])
		look = String(b["look"])
		_sprite_scale = float(b["scale"])
		_base_tint = b["tint"]
		_floats = bool(b["float"])
		_move_speed = 30.0
		(collision.shape as CircleShape2D).radius = 7.0 * _sprite_scale
	else:
		var d: Dictionary = TYPE_DATA[enemy_type]
		display_name = String(d["name"])
		max_hp = maxi(max_hp, 1)
		look = String(d["look"])
		_base_tint = d["tint"]
		_floats = bool(d["float"])
		_move_speed = float(d["move"])
		(collision.shape as CircleShape2D).radius = 12.0
	sprite.sprite_frames = SpriteLib.frames(look)
	sprite.scale = Vector2.ONE * _sprite_scale
	sprite.modulate = _base_tint
	sprite.play("idle")


# =============================================================================
#  Bucla principală
# =============================================================================
func _physics_process(delta: float) -> void:
	if _dead:
		return
	_anim_t += delta
	_flash = maxf(_flash - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var can_fight := _player != null and not _player.is_dead()
	_move(delta, can_fight)
	if can_fight:
		_update_attack(delta)
	elif _state != State.COOLDOWN:
		_state = State.COOLDOWN
		_queue.clear()
		_timer = 1.0
	_update_visuals()
	queue_redraw()


func _move(delta: float, can_fight: bool) -> void:
	if _charge_time > 0.0:
		_charge_step(delta)
		return
	var moving_allowed := _state == State.COOLDOWN
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 8.0:
		_pick_wander_target()
	# Scheleții arcași păstrează distanța față de jucător.
	if can_fight and enemy_type == Type.SKELETON_ARCHER and not is_boss:
		if global_position.distance_to(_player.global_position) < 200.0:
			var away := (global_position - _player.global_position).normalized()
			_wander_target = _clamp_to_arena(global_position + away * 120.0)
	if moving_allowed:
		velocity = (_wander_target - global_position).normalized() * _move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()


func _pick_wander_target() -> void:
	_wander_timer = randf_range(2.0, 4.0)
	var r := arena_rect
	if is_boss:
		r = Rect2(arena_rect.position.x + arena_rect.size.x * 0.25, arena_rect.position.y,
				arena_rect.size.x * 0.5, arena_rect.size.y * 0.35)
	_wander_target = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


func _clamp_to_arena(p: Vector2) -> Vector2:
	return p.clamp(arena_rect.position, arena_rect.end)


func _update_attack(delta: float) -> void:
	match _state:
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				_begin_attack()
		State.TELEGRAPH:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.FIRING
				_fire_clock = 0.0
		State.FIRING:
			_fire_clock += delta
			while not _queue.is_empty() and float(_queue[0]["t"]) <= _fire_clock:
				var item: Dictionary = _queue.pop_front()
				var fn: Callable = item["fn"]
				fn.call()
				if _dead:
					return
			if _queue.is_empty():
				_state = State.COOLDOWN
				_timer = _next_cooldown()


func _next_cooldown() -> float:
	if is_boss:
		match _phase:
			1:
				return randf_range(1.4, 2.0)
			2:
				return randf_range(1.1, 1.6)
			_:
				return randf_range(0.9, 1.3)
	var cd: Vector2 = TYPE_DATA[enemy_type]["cooldown"]
	return randf_range(cd.x, cd.y) / maxf(difficulty, 0.5)


# =============================================================================
#  Pattern-uri de atac (coada _queue: {t = secunde de la start, fn = Callable})
# =============================================================================
func _begin_attack() -> void:
	_queue.clear()
	_telegraph_total = 0.6
	_telegraph_aimed = true
	_telegraph_danger = false
	var pre_delay := 0.0
	if is_boss:
		if _wants_summon():
			_summon(1)
		if _wants_blink():
			_blink()
			pre_delay = 0.5
		_build_boss_attack()
	else:
		_build_regular_attack()
	_attack_count += 1
	_telegraph_total += pre_delay
	_state = State.TELEGRAPH
	_timer = _telegraph_total


func _build_regular_attack() -> void:
	match enemy_type:
		Type.GHOST:
			_add(0.0, func(): _fire_aimed(Projectile.Kind.GLOB, 150.0))
		Type.SPIRIT:
			_add(0.0, func(): _fire_fan(3, 32.0, Projectile.Kind.ORB, 170.0))
		Type.SKELETON_ARCHER:
			_add(0.0, func(): _fire_aimed(Projectile.Kind.ARROW, 340.0))
		Type.PHANTOM_KNIGHT:
			if _attack_count % 2 == 0:
				_add(0.0, func(): _fire_aimed(Projectile.Kind.SWORD, 250.0))
			else:
				_telegraph_danger = true
				_telegraph_total = 0.8
				_add(0.0, func(): _fire_aimed(Projectile.Kind.SPEAR, 300.0, true))


func _build_boss_attack() -> void:
	var alt := _attack_count % 2 == 0
	match boss_index:
		1:  # Marele Duh al Criptei – o fantomă uriașă: globuri + teleport
			if _phase == 1:
				if alt:
					for i in 3:
						_add(i * 0.25, func(): _fire_aimed(Projectile.Kind.GLOB, 170.0))
				else:
					_ring(10, Projectile.Kind.GLOB, 120.0)
			else:
				if alt:
					_add(0.0, func(): _fire_fan(5, 50.0, Projectile.Kind.GLOB, 170.0))
					_add(0.4, func(): _fire_aimed(Projectile.Kind.GLOB, 200.0))
				else:
					_ring(12, Projectile.Kind.GLOB, 130.0)
					_add(0.45, func(): _fire_aimed(Projectile.Kind.GLOB, 190.0))
		2:  # Oracolul Fără Ochi – un spirit uriaș: evantaie triple
			if _phase == 1:
				if alt:
					for i in 3:
						_add(i * 0.28, func(): _fire_fan(3, 32.0, Projectile.Kind.ORB, 180.0))
				else:
					_spiral(16, 1, 0.07, 25.0, Projectile.Kind.ORB, 150.0)
			else:
				if alt:
					_add(0.0, func(): _fire_fan(5, 60.0, Projectile.Kind.ORB, 190.0))
					_add(0.3, func(): _fire_fan(3, 32.0, Projectile.Kind.ORB, 200.0))
					_add(0.6, func(): _fire_fan(5, 60.0, Projectile.Kind.ORB, 190.0))
				else:
					_spiral(20, 2, 0.06, 21.0, Projectile.Kind.ORB, 160.0)
					_add(1.25, func(): _fire_fan(3, 32.0, Projectile.Kind.ORB, 210.0))
		3:  # Comandantul de Os – scheletul-șef: salve + ploaie de săgeți
			if _phase == 1:
				if alt:
					for i in 3:
						_add(i * 0.18, func(): _fire_aimed(Projectile.Kind.ARROW, 360.0))
				else:
					_add(0.0, func(): _fire_fan(7, 70.0, Projectile.Kind.ARROW, 300.0))
					_add(0.4, func(): _fire_fan(6, 60.0, Projectile.Kind.ARROW, 320.0))
			else:
				if alt:
					for i in 5:
						_add(i * 0.14, func(): _fire_aimed(Projectile.Kind.ARROW, 380.0))
				else:
					_ring(12, Projectile.Kind.ARROW, 260.0)
					_add(0.3, func(): _fire_fan(7, 70.0, Projectile.Kind.ARROW, 320.0))
					_add(0.6, func(): _fire_aimed(Projectile.Kind.ARROW, 380.0))
		4:  # Garda Regală Căzută – cavalerul-fantomă suprem: săbii, sulițe, șarjă
			if _attack_count % 3 == 2:
				_charge_attack()
				_add(CHARGE_TIME + 0.1, func(): _fire_fan(3, 36.0, Projectile.Kind.SWORD, 250.0))
			elif _phase == 1:
				if alt:
					_add(0.0, func(): _fire_fan(3, 30.0, Projectile.Kind.SWORD, 260.0))
				else:
					_telegraph_danger = true
					_telegraph_total = 0.8
					_add(0.0, func(): _fire_aimed(Projectile.Kind.SPEAR, 330.0, true))
					_add(0.35, func(): _fire_fan(2, 24.0, Projectile.Kind.SWORD, 250.0))
			else:
				if alt:
					_spiral(14, 1, 0.07, 26.0, Projectile.Kind.SWORD, 220.0)
					_add(1.0, func(): _fire_aimed(Projectile.Kind.SWORD, 260.0))
				else:
					_telegraph_danger = true
					_telegraph_total = 0.8
					_add(0.0, func(): _fire_fan(3, 40.0, Projectile.Kind.SPEAR, 300.0, true))
					_add(0.4, func(): _fire_aimed(Projectile.Kind.SWORD, 270.0))
		5:  # Avatarul Cărții Întunericului – toate puterile umbrelor
			if _phase >= 2 and _attack_count % 3 == 2:
				_charge_attack()
				_add(CHARGE_TIME + 0.1, func(): _ring_now(12, Projectile.Kind.BOSS_ORB, 150.0))
				return
			match _phase:
				1:
					if alt:
						_spiral(18, 2, 0.07, 20.0, Projectile.Kind.BOSS_ORB, 150.0)
						_add(1.3, func(): _fire_fan(3, 32.0, Projectile.Kind.ORB, 200.0))
					else:
						_add(0.0, func(): _fire_fan(5, 56.0, Projectile.Kind.ORB, 190.0))
						_add(0.45, func(): _fire_aimed(Projectile.Kind.SPEAR, 320.0, true))
				2:
					if alt:
						_ring(14, Projectile.Kind.BOSS_ORB, 140.0)
						_add(0.35, func(): _fire_aimed(Projectile.Kind.SWORD, 260.0))
						_add(0.65, func(): _fire_fan(5, 50.0, Projectile.Kind.ARROW, 320.0))
					else:
						_telegraph_danger = true
						_spiral(20, 2, 0.06, 19.0, Projectile.Kind.BOSS_ORB, 160.0)
						_add(0.6, func(): _fire_fan(3, 36.0, Projectile.Kind.SPEAR, 300.0, true))
						_add(1.2, func(): _fire_aimed(Projectile.Kind.GLOB, 220.0))
				_:
					if alt:
						_spiral(24, 3, 0.05, 17.0, Projectile.Kind.BOSS_ORB, 175.0)
						_add(1.25, func(): _fire_fan(3, 30.0, Projectile.Kind.SWORD, 270.0))
					else:
						_ring(16, Projectile.Kind.BOSS_ORB, 150.0)
						_add(0.3, func(): _fire_fan(7, 70.0, Projectile.Kind.ARROW, 330.0))
						_add(0.7, func(): _fire_aimed(Projectile.Kind.SPEAR, 340.0, true))


# =============================================================================
#  Puterile boșilor: teleport, șarjă, ajutoare
# =============================================================================
func _wants_blink() -> bool:
	if boss_index == 1:
		return _attack_count % 3 == 2
	if boss_index == 5:
		return _phase >= 2 and _attack_count % 4 == 1
	return false


func _wants_summon() -> bool:
	return _phase >= 2 and _attack_count % 4 == 3 and _minion_count() < 2


func _minion_count() -> int:
	return get_tree().get_nodes_in_group("minions").size()


func _blink() -> void:
	## Fantoma dispare și reapare în alt colț al camerei.
	special_used.emit("blink")
	var target := _random_boss_spot()
	GameState.play_sfx("magic", false, -10.0)
	var t := create_tween()
	t.tween_property(self, "_alpha_mult", 0.0, 0.2)
	t.tween_callback(_teleport_to.bind(target))
	t.tween_property(self, "_alpha_mult", 1.0, 0.25)


func _teleport_to(target: Vector2) -> void:
	if _dead:
		return
	FX.burst(get_parent(), global_position, GameState.COL_MAGENTA, 18, 140.0, 0.4, 3.0)
	global_position = target
	FX.burst(get_parent(), target, GameState.COL_MAGENTA, 18, 140.0, 0.4, 3.0)


func _random_boss_spot() -> Vector2:
	var r := Rect2(arena_rect.position.x + 60.0, arena_rect.position.y + 10.0,
			arena_rect.size.x - 120.0, arena_rect.size.y * 0.35)
	for i in 10:
		var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
		if _player == null or not is_instance_valid(_player) or p.distance_to(_player.global_position) > 220.0:
			return p
	return r.get_center()


func _charge_attack() -> void:
	## Telegraph roșu (linia arată direcția), apoi se aruncă spre jucător.
	_telegraph_aimed = true
	_telegraph_danger = true
	_telegraph_total = 0.75
	_add(0.0, _start_charge)


func _start_charge() -> void:
	_charge_dir = _aim_dir()
	_charge_time = CHARGE_TIME
	_charge_contact = false
	special_used.emit("charge")
	GameState.play_sfx("hurt", false, -8.0)
	GameState.shake(5.0)


func _charge_step(delta: float) -> void:
	_charge_time -= delta
	velocity = _charge_dir * CHARGE_SPEED
	move_and_slide()
	# damage la contact, verificat O SINGURĂ DATĂ pe șarjă: dacă jucătorul e în salt
	# (invulnerabil) la primul contact, a sărit peste șarjă – chiar dacă e împins.
	if not _charge_contact and _player and is_instance_valid(_player) and not _player.is_dead():
		var reach := (collision.shape as CircleShape2D).radius + 14.0
		if global_position.distance_to(_player.global_position) < reach:
			_charge_contact = true
			_player.take_damage(1)
	if get_slide_collision_count() > 0 or _charge_time <= 0.0:
		_charge_time = 0.0
		velocity = Vector2.ZERO
		GameState.shake(6.0)
		FX.burst(get_parent(), global_position, Color(0.8, 0.8, 1.0), 16, 160.0, 0.4, 3.0)


func _summon(count: int) -> void:
	## Cheamă ajutoare din capitolul boss-ului (Avatarul cheamă orice tip).
	var n := mini(count, MAX_MINIONS - _minion_count())
	if n <= 0 or _dead or not is_boss:
		return
	for i in n:
		var t := boss_index - 1 if boss_index <= 4 else randi_range(0, 3)
		var at := global_position + Vector2.RIGHT.rotated(randf() * TAU) * (7.0 * _sprite_scale + 70.0)
		summon_requested.emit(t, at)
	special_used.emit("summon")
	GameState.play_sfx("magic", false, -6.0)
	FX.popup(get_parent(), global_position + Vector2(0, -70), "AJUTOARE!", GameState.COL_MAGENTA, 22)


func _ring_now(count: int, kind: Projectile.Kind, spd: float) -> void:
	## Inel de proiectile tras imediat (folosit după șarjă).
	var offset := randf() * TAU
	for i in count:
		_shoot(Vector2.RIGHT.rotated(offset + TAU * i / count), kind, spd)


func _add(t: float, fn: Callable) -> void:
	_queue.append({"t": t, "fn": fn})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func _ring(count: int, kind: Projectile.Kind, spd: float) -> void:
	_telegraph_aimed = false
	var offset := randf() * TAU
	_add(0.0, func():
		for i in count:
			_shoot(Vector2.RIGHT.rotated(offset + TAU * i / count), kind, spd)
	)


func _spiral(steps: int, arms: int, interval: float, step_deg: float, kind: Projectile.Kind, spd: float) -> void:
	_telegraph_aimed = false
	var start := randf() * TAU
	for s in steps:
		var ang := start + deg_to_rad(step_deg) * s
		_add(s * interval, func():
			for a in arms:
				_shoot(Vector2.RIGHT.rotated(ang + TAU * a / arms), kind, spd)
		)


func _aim_dir() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.DOWN
	return (_player.global_position + Vector2(0, -4) - global_position).normalized()


func _fire_aimed(kind: Projectile.Kind, spd: float, unparryable: bool = false) -> void:
	_shoot(_aim_dir(), kind, spd, unparryable)


func _fire_fan(count: int, spread_deg: float, kind: Projectile.Kind, spd: float, unparryable: bool = false) -> void:
	var base := _aim_dir()
	for i in count:
		var k := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		_shoot(base.rotated(deg_to_rad(spread_deg) * k), kind, spd, unparryable)


func _shoot(dir: Vector2, kind: Projectile.Kind, spd: float, unparryable: bool = false) -> void:
	if _dead or projectile_parent == null or not is_instance_valid(projectile_parent):
		return
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	p.setup(kind, dir, spd * (1.0 + (difficulty - 1.0) * 0.6), unparryable)
	var muzzle := 6.0 * _sprite_scale
	p.position = global_position + dir.normalized() * muzzle
	projectile_parent.add_child(p)
	GameState.play_sfx("shoot", true, -16.0)


# =============================================================================
#  Damage / moarte
# =============================================================================
func take_hit(amount: int, from_dir: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.12
	hp_changed.emit(maxi(hp, 0), max_hp)
	GameState.play_sfx("hit")
	FX.burst(get_parent(), global_position, Color.WHITE, 10, 150.0, 0.3, 3.0)
	# Knockback aplicat în _move() (suntem în callback-ul fizicii -> fără move_and_collide aici).
	_knockback = from_dir * (90.0 if is_boss else 320.0)
	_update_phase()
	if hp <= 0:
		_die()


func _update_phase() -> void:
	if not is_boss:
		return
	var ratio := float(hp) / float(max_hp)
	var new_phase := 1
	if boss_index == 5:
		new_phase = 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	elif ratio <= 0.5:
		new_phase = 2
	if new_phase != _phase and hp > 0:
		_phase = new_phase
		GameState.shake(10.0)
		GameState.play_sfx("magic", false)
		FX.popup(get_parent(), global_position + Vector2(0, -60), "FAZA %d" % _phase, GameState.COL_MAGENTA, 26)
		special_used.emit("phase")
		_summon.call_deferred(2)


func is_dead() -> bool:
	return _dead


func dissolve() -> void:
	## Ajutoarele dispar când boss-ul lor e învins.
	if not _dead:
		_die(false)


func _die(count_kill: bool = true) -> void:
	_dead = true
	_queue.clear()
	_charge_time = 0.0
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if count_kill:
		GameState.kills += 1
	GameState.play_sfx("die")
	var col := GameState.COL_MAGENTA if is_boss else Color(0.85, 0.4, 1.0)
	FX.burst(get_parent(), global_position, col, 40 if is_boss else 22, 260.0 if is_boss else 180.0, 0.7, 4.0)
	FX.burst(get_parent(), global_position, GameState.COL_RED, 14, 140.0, 0.5, 3.0)
	if is_boss:
		GameState.shake(16.0)
		GameState.hitstop(0.15, 0.1)
	died.emit(self)
	var t := create_tween()
	t.tween_property(sprite, "scale", sprite.scale * 1.4, 0.25)
	t.parallel().tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.35)
	t.tween_callback(queue_free)


# =============================================================================
#  Vizual: telegraph (se înroșește + linie de ochire), flash la lovitură, plutire
# =============================================================================
func _update_visuals() -> void:
	if _floats:
		sprite.position.y = sin(_anim_t * 3.0) * 3.0
	if _player and is_instance_valid(_player):
		sprite.flip_h = _player.global_position.x < global_position.x
	sprite.play("run" if velocity.length() > 5.0 else "idle")
	var c := _base_tint
	if _state == State.TELEGRAPH:
		var k := 1.0 - _timer / _telegraph_total
		c = c.lerp(Color(1.0, 0.25, 0.3, c.a), k * 0.85)
	if _flash > 0.0:
		c = Color(4.0, 4.0, 4.0, 1.0)
	c.a *= _alpha_mult
	sprite.modulate = c


func _draw() -> void:
	if _dead:
		return
	var aura_r := 5.0 * _sprite_scale
	if is_boss:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 4.0)
		draw_circle(Vector2(0, aura_r * 0.9), aura_r * 1.2, Color(GameState.COL_MAGENTA, 0.08 + 0.06 * pulse))
		draw_arc(Vector2(0, aura_r * 0.9), aura_r * 1.2, 0.0, TAU, 40, Color(GameState.COL_MAGENTA, 0.5), 2.0)
	else:
		draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _charge_time > 0.0:
		# dâră în urma șarjei
		for i in 4:
			var back := -_charge_dir * (18.0 + i * 16.0)
			draw_circle(back, aura_r * (0.9 - i * 0.18), Color(GameState.COL_RED, 0.35 - i * 0.08))
	if _state != State.TELEGRAPH or _player == null or not is_instance_valid(_player):
		return
	var k := 1.0 - _timer / _telegraph_total
	var col := GameState.COL_RED if _telegraph_danger else Color(1.0, 0.9, 0.9)
	if _telegraph_aimed:
		var to := to_local(_player.global_position + Vector2(0, -4))
		draw_line(Vector2.ZERO, to, Color(col, 0.12 + 0.5 * k), 3.0 if _telegraph_danger else 1.5)
	else:
		var r := lerpf(aura_r * 4.0, aura_r, k)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(GameState.COL_MAGENTA, k), 3.0)
		if _telegraph_danger:
			draw_arc(Vector2.ZERO, r + 6.0, 0.0, TAU, 40, Color(GameState.COL_RED, k * 0.7), 2.0)
