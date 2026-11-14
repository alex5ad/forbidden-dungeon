class_name Projectile
extends Area2D
## Proiectil inamic. Jucătorul îl poate reflecta cu parry():
##  - Perfect Parry: viteză x1.8, piercing (străpunge toți inamicii), spre cursor.
##  - Normal Parry:  viteză x1.2, dispare la primul inamic lovit.
##  - Orice proiectil reflectat ricoșează O DATĂ din ziduri (velocity.bounce(normal)).
## Sulițele roșii (unparryable = true) nu pot fi reflectate.

enum Kind { GLOB, ORB, ARROW, SWORD, SPEAR, BOSS_ORB }

const RADIUS := 6.0
const LIFETIME := 7.0
const PERFECT_SPEED_MULT := 1.8
const NORMAL_SPEED_MULT := 1.2

@export var kind: Kind = Kind.GLOB
@export var speed := 150.0
@export var damage := 1
@export var unparryable := false

var velocity := Vector2.ZERO
var reflected := false
var piercing := false
var perfect := false
var bounces_left := 0

var _age := 0.0
var _dead := false
var _color := Color.WHITE
var _hit_bodies: Array[Node] = []

@onready var trail: CPUParticles2D = $Trail


func setup(p_kind: Kind, direction: Vector2, p_speed: float, p_unparryable: bool = false) -> void:
	## Apelează ÎNAINTE de add_child().
	kind = p_kind
	speed = p_speed
	unparryable = p_unparryable
	velocity = direction.normalized() * speed
	rotation = velocity.angle()


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = GameState.LAYER_PROJECTILES
	collision_mask = GameState.LAYER_PLAYER | GameState.LAYER_ENEMIES
	body_entered.connect(_on_body_entered)
	if velocity == Vector2.ZERO:
		velocity = Vector2.RIGHT * speed
	_color = _base_color()
	_apply_trail()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if _age > LIFETIME:
		vanish()
		return
	var motion := velocity * delta
	# Raycast pe layer-ul de ziduri -> obținem normala pentru ricoșeu.
	var from := global_position
	var to := from + motion + velocity.normalized() * RADIUS
	var query := PhysicsRayQueryParameters2D.create(from, to, GameState.LAYER_WALLS)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector2 = hit["normal"]
		var point: Vector2 = hit["position"]
		if reflected and bounces_left > 0:
			bounces_left -= 1
			velocity = velocity.bounce(normal)
			global_position = point + normal * (RADIUS + 1.0)
			rotation = velocity.angle()
			FX.burst(get_parent(), point, GameState.COL_GOLD, 10, 140.0, 0.3, 2.5)
			GameState.play_sfx("bounce")
			return
		vanish(point)
		return
	global_position += motion
	rotation = velocity.angle()


func reflect(target: Vector2, is_perfect: bool) -> void:
	## Apelată de Player.try_parry(). Trimite proiectilul spre `target` (cursorul).
	if reflected or unparryable or _dead:
		return
	reflected = true
	perfect = is_perfect
	piercing = is_perfect
	bounces_left = 1
	_age = 0.0
	var dir := target - global_position
	if dir.length() < 4.0:
		dir = -velocity
	speed *= PERFECT_SPEED_MULT if is_perfect else NORMAL_SPEED_MULT
	velocity = dir.normalized() * speed
	rotation = velocity.angle()
	_color = Color.WHITE if is_perfect else GameState.COL_GOLD
	_apply_trail()
	queue_redraw()


func vanish(at: Vector2 = Vector2.INF) -> void:
	if _dead:
		return
	_dead = true
	var pos := global_position if at == Vector2.INF else at
	FX.burst(get_parent(), pos, _color, 8, 110.0, 0.25, 2.5)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()


func is_hostile() -> bool:
	return not reflected and not _dead


func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body is Player:
		if reflected:
			return
		var player := body as Player
		# Parry-ul are prioritate față de damage (dacă fereastra e activă).
		if not unparryable and player.try_parry(self):
			return
		if player.take_damage(damage):
			vanish()
	elif body is Enemy:
		if not reflected or body in _hit_bodies:
			return
		_hit_bodies.append(body)
		(body as Enemy).take_hit(damage, velocity.normalized())
		if not piercing:
			vanish()


func _base_color() -> Color:
	if unparryable:
		return GameState.COL_RED
	match kind:
		Kind.GLOB:
			return Color("#7dffb0")
		Kind.ORB:
			return Color("#c77dff")
		Kind.ARROW:
			return Color("#f4ead2")
		Kind.SWORD:
			return GameState.COL_CYAN
		Kind.BOSS_ORB:
			return GameState.COL_MAGENTA
	return Color.WHITE


func _apply_trail() -> void:
	if trail == null:
		return
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_color, 0.8))
	ramp.set_color(1, Color(_color, 0.0))
	trail.color_ramp = ramp
	trail.amount = 28 if perfect else 14
	trail.scale_amount_max = 4.0 if reflected else 3.0
	trail.emitting = true


func _draw() -> void:
	# Desenat orientat spre +X (rotation = direcția de zbor).
	var c := _color
	var glow := Color(c, 0.25)
	match kind:
		Kind.GLOB:
			draw_circle(Vector2.ZERO, RADIUS + 4.0, glow)
			draw_circle(Vector2.ZERO, RADIUS, c)
			draw_circle(Vector2(1, -2), 2.5, Color(1, 1, 1, 0.8))
		Kind.ORB:
			draw_circle(Vector2.ZERO, RADIUS + 3.0, glow)
			draw_circle(Vector2.ZERO, RADIUS - 1.0, c)
			draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
		Kind.BOSS_ORB:
			draw_circle(Vector2.ZERO, RADIUS + 6.0, glow)
			draw_circle(Vector2.ZERO, RADIUS + 1.0, c)
			draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
		Kind.ARROW:
			draw_line(Vector2(-12, 0), Vector2(8, 0), glow, 6.0)
			draw_line(Vector2(-12, 0), Vector2(8, 0), c, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(6, -4), Vector2(6, 4)]), c)
			draw_line(Vector2(-12, 0), Vector2(-16, -4), c, 2.0)
			draw_line(Vector2(-12, 0), Vector2(-16, 4), c, 2.0)
		Kind.SWORD:
			draw_line(Vector2(-10, 0), Vector2(14, 0), glow, 9.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(16, 0), Vector2(8, -3), Vector2(-6, -3), Vector2(-6, 3), Vector2(8, 3)]), c)
			draw_line(Vector2(-6, -7), Vector2(-6, 7), Color.WHITE, 3.0)
			draw_line(Vector2(-6, 0), Vector2(-13, 0), Color.WHITE, 3.0)
		Kind.SPEAR:
			draw_line(Vector2(-20, 0), Vector2(12, 0), glow, 8.0)
			draw_line(Vector2(-20, 0), Vector2(10, 0), c, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(8, -5), Vector2(8, 5)]), c)
	if reflected:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 16, Color(GameState.COL_GOLD, 0.6), 2.0)
