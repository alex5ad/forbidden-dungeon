class_name Actor
extends Node2D
## Personaj de cutscene (Cavaler, Rege, fantome, săteni) – fără fizică.
## Folosit în IntroGates, MirrorRoom și ThroneEnding.

@export var character_id := "knight":
	set(v):
		character_id = v
		if sprite:
			_apply_frames()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		if sprite:
			sprite.modulate = tint
@export var sprite_scale := 2.0
@export var float_bob := false       # fantomele plutesc
@export var face_left := false

var sprite: AnimatedSprite2D
var _t := 0.0
var _tremble := 0.0


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.modulate = tint
	_t = randf() * TAU
	_apply_frames()


func _process(delta: float) -> void:
	_t += delta
	var off := Vector2.ZERO
	if float_bob:
		off.y = sin(_t * 3.0) * 3.0
	if _tremble > 0.0:
		off.x = sin(_t * 70.0) * _tremble
	sprite.position = off


func set_character(id: String, new_tint: Color = Color.WHITE) -> void:
	character_id = id
	tint = new_tint


func play(anim: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		sprite.play("idle")


func face(direction_x: float) -> void:
	if absf(direction_x) > 0.5:
		sprite.flip_h = direction_x < 0.0


func set_tremble(amount: float) -> void:
	_tremble = amount


func walk_to(target: Vector2, speed: float = 110.0) -> Tween:
	## Mers animat spre `target`. Folosește: await actor.walk_to(p).finished
	face(target.x - position.x)
	play("run")
	var t := create_tween()
	t.tween_property(self, "position", target, maxf(position.distance_to(target) / speed, 0.05))
	t.tween_callback(play.bind("idle"))
	return t


func _apply_frames() -> void:
	if character_id == "knight":
		# Cavalerul poartă armura echipată din magazin (doar cosmetic)
		var armor := GameState.armor_data()
		sprite.sprite_frames = SpriteLib.frames(String(armor["look"]))
		sprite.self_modulate = armor["tint"]
	else:
		sprite.sprite_frames = SpriteLib.frames(character_id)
		sprite.self_modulate = Color.WHITE
	sprite.flip_h = face_left
	play("idle")
