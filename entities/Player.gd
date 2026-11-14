class_name Player
extends CharacterBody2D
## Cavalerul. NU are atac direct: doar parry() (Click Stânga / Space).
##  - fereastră activă 0.15s; primele 0.05s = PERFECT
##  - ratare -> cooldown 0.5s
##  - Perfect Parry la 1 HP (din 3) -> +1 HP („Bounce Back from death”)
## Viața este ținută în GameState ca să persiste între etaje.

signal parried(perfect: bool)
signal died

const SPEED := 220.0
const PARRY_ACTIVE_TIME := 0.15
const PERFECT_WINDOW := 0.05
const MISS_COOLDOWN := 0.5
const PERFECT_HITSTOP := 0.05
const INVULN_TIME := 0.9
const PARRY_RADIUS := 34.0

@export var controllable := true

var parry_active := false
var _parry_time := 0.0
var _parry_success := false
var _cooldown := 0.0
var _invuln := 0.0
var _dead := false
var _parry_flash := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var parry_area: Area2D = $ParryArea2D
@onready var parry_sparks: CPUParticles2D = $ParrySparks


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = SpriteLib.frames("knight")
	sprite.play("idle")
	parry_area.area_entered.connect(_on_parry_area_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timers(delta)
	if controllable:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * SPEED
		if Input.is_action_just_pressed("parry"):
			parry()
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if parry_active:
		_scan_parry_area()
	_update_visuals()
	queue_redraw()


# -----------------------------------------------------------------------------
#  PARRY
# -----------------------------------------------------------------------------
func parry() -> void:
	if parry_active or _cooldown > 0.0 or _dead:
		return
	parry_active = true
	_parry_time = 0.0
	_parry_success = false
	GameState.play_sfx("swing", true, -14.0)
	# Proiectilele aflate deja în rază sunt prinse instant (perfect).
	_scan_parry_area()


func try_parry(projectile: Projectile) -> bool:
	## Returnează true dacă proiectilul a fost reflectat.
	if not parry_active or _dead:
		return false
	if not is_instance_valid(projectile) or not projectile.is_hostile() or projectile.unparryable:
		return false
	var perfect := _parry_time <= PERFECT_WINDOW
	_parry_success = true
	projectile.reflect(get_global_mouse_position(), perfect)
	GameState.parries += 1
	_parry_flash = 0.18
	parry_sparks.color = Color.WHITE if perfect else GameState.COL_GOLD
	parry_sparks.global_position = projectile.global_position
	parry_sparks.restart()
	if perfect:
		GameState.perfect_parries += 1
		GameState.hitstop(PERFECT_HITSTOP)
		GameState.shake(7.0)
		GameState.play_sfx("perfect", false)
		FX.popup(get_parent(), global_position + Vector2(0, -34), "PERFECT!", Color.WHITE, 24)
		# BOUNCE BACK from death: 1 HP din 3 -> +1 HP
		if GameState.player_hp == 1 and GameState.max_hp == 3:
			GameState.heal_player(1)
			GameState.bounce_backs += 1
			GameState.play_sfx("heal", false)
			FX.popup(get_parent(), global_position + Vector2(0, -64), "BOUNCE BACK! +1 HP", GameState.COL_GOLD, 26)
			FX.burst(get_parent(), global_position, GameState.COL_GOLD, 30, 220.0, 0.6, 4.0)
	else:
		GameState.shake(3.0)
		GameState.play_sfx("parry")
		FX.popup(get_parent(), global_position + Vector2(0, -34), "PARRY", GameState.COL_GOLD, 18)
	parried.emit(perfect)
	return true


func _scan_parry_area() -> void:
	for area in parry_area.get_overlapping_areas():
		if area is Projectile:
			try_parry(area as Projectile)


func _on_parry_area_entered(area: Area2D) -> void:
	if parry_active and area is Projectile:
		try_parry(area as Projectile)


# -----------------------------------------------------------------------------
#  DAMAGE
# -----------------------------------------------------------------------------
func take_damage(amount: int) -> bool:
	## Returnează true dacă lovitura a contat (nu eram invulnerabil).
	if _dead or _invuln > 0.0:
		return false
	GameState.damage_player(amount)
	_invuln = INVULN_TIME
	GameState.shake(9.0)
	GameState.play_sfx("hurt")
	FX.burst(get_parent(), global_position, GameState.COL_RED, 18, 180.0, 0.4, 3.0)
	sprite.play("hit")
	if GameState.player_hp <= 0:
		_die()
	return true


func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	parry_active = false
	velocity = Vector2.ZERO
	GameState.deaths += 1
	GameState.play_sfx("die", false)
	sprite.play("hit")
	sprite.modulate = GameState.COL_RED
	var t := create_tween()
	t.tween_property(sprite, "rotation", PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(sprite, "modulate:a", 0.45, 0.6)
	died.emit()


# -----------------------------------------------------------------------------
#  Timere + vizual
# -----------------------------------------------------------------------------
func _tick_timers(delta: float) -> void:
	if parry_active:
		_parry_time += delta
		if _parry_time >= PARRY_ACTIVE_TIME:
			parry_active = false
			if not _parry_success:
				_cooldown = MISS_COOLDOWN
	_cooldown = maxf(_cooldown - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_parry_flash = maxf(_parry_flash - delta, 0.0)


func _update_visuals() -> void:
	var aim := get_global_mouse_position() - global_position
	sprite.flip_h = aim.x < 0.0
	if _invuln > 0.0:
		sprite.modulate.a = 0.35 if int(_invuln * 20.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	if _invuln > INVULN_TIME - 0.25:
		return  # lasă animația „hit” să se vadă
	if velocity.length() > 5.0:
		sprite.play("run")
	else:
		sprite.play("idle")


func _draw() -> void:
	if _dead:
		return
	var center := Vector2(0, -4)
	var aim := (get_global_mouse_position() - global_position).normalized()
	# indicator de țintire (scutul): mic arc auriu spre cursor
	var a := aim.angle()
	draw_arc(center, PARRY_RADIUS - 8.0, a - 0.5, a + 0.5, 10, Color(GameState.COL_GOLD, 0.35), 2.0)
	if parry_active:
		var in_perfect := _parry_time <= PERFECT_WINDOW
		var k := 1.0 - _parry_time / PARRY_ACTIVE_TIME
		var col := Color.WHITE if in_perfect else GameState.COL_GOLD
		draw_circle(center, PARRY_RADIUS, Color(col, 0.10 * k))
		draw_arc(center, PARRY_RADIUS, 0.0, TAU, 32, Color(col, 0.9 * k), 3.0)
	elif _cooldown > 0.0:
		var frac := _cooldown / MISS_COOLDOWN
		draw_arc(center, PARRY_RADIUS - 14.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(0.6, 0.6, 0.7, 0.6), 2.0)
	if _parry_flash > 0.0:
		draw_arc(center, PARRY_RADIUS + 6.0 * (1.0 - _parry_flash / 0.18), 0.0, TAU, 32,
				Color(1, 1, 1, _parry_flash / 0.18), 2.0)
