extends Node2D
## Test automat (temporar) pentru regulile de parry din spec.

const PLAYER_SCENE := preload("res://entities/Player.tscn")
const PROJ_SCENE := preload("res://entities/Projectile.tscn")
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")

var _fails := 0
var player: Player


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + label)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _new_player() -> void:
	if player:
		player.queue_free()
		await _frames(2)
	GameState.max_hp = 3
	GameState.player_hp = 3
	player = PLAYER_SCENE.instantiate() as Player
	player.controllable = false
	player.position = Vector2(576, 400)
	add_child(player)
	await _frames(2)


func _spawn(offset: Vector2, kind: Projectile.Kind, spd: float, unparryable := false) -> Projectile:
	var p := PROJ_SCENE.instantiate() as Projectile
	p.setup(kind, -offset, spd, unparryable)
	p.position = player.global_position + Vector2(0, -4) + offset
	add_child(p)
	return p


func _run() -> void:
	Engine.time_scale = 1.0
	# zid în dreapta pentru testul de ricoșeu
	add_child(NeonWall.create(Rect2(900, 100, 32, 600)))

	print("[1] Perfect parry (proiectil deja în rază la apăsare)")
	await _new_player()
	var p := _spawn(Vector2(0, -25), Projectile.Kind.GLOB, 150.0)
	await _frames(1)
	player.parry()
	await _frames(1)
	_check(p.reflected, "reflectat")
	_check(p.perfect and p.piercing, "perfect -> piercing")
	_check(is_equal_approx(p.speed, 150.0 * 1.8), "viteză x1.8 (%.1f)" % p.speed)
	_check(p.bounces_left == 1, "bounces_left = 1")
	_check(GameState.player_hp == 3, "fără damage")
	p.queue_free()

	print("[2] Normal parry (intră în rază după 0.05s)")
	await _new_player()
	p = _spawn(Vector2(0, -70), Projectile.Kind.ARROW, 340.0)
	player.parry()
	for i in 20:
		await _frames(1)
		if p.reflected:
			break
	_check(p.reflected, "reflectat")
	_check(not p.perfect and not p.piercing, "normal -> fără piercing")
	_check(is_equal_approx(p.speed, 340.0 * 1.2), "viteză x1.2 (%.1f)" % p.speed)
	p.queue_free()

	print("[3] Ratare -> cooldown 0.5s")
	await _new_player()
	player.parry()
	await get_tree().create_timer(0.25).timeout
	_check(not player.parry_active, "fereastra s-a închis după 0.15s")
	player.parry()
	_check(not player.parry_active, "parry blocat în cooldown")
	await get_tree().create_timer(0.45).timeout
	player.parry()
	_check(player.parry_active, "parry disponibil după cooldown")

	print("[4] Bounce Back from death: perfect parry la 1 HP -> +1 HP")
	await _new_player()
	GameState.player_hp = 1
	p = _spawn(Vector2(0, -25), Projectile.Kind.GLOB, 150.0)
	await _frames(1)
	player.parry()
	await _frames(1)
	_check(GameState.player_hp == 2, "HP 1 -> 2 (are %d)" % GameState.player_hp)
	p.queue_free()

	print("[5] Suliță roșie NEREFLECTABILĂ")
	await _new_player()
	p = _spawn(Vector2(0, -40), Projectile.Kind.SPEAR, 300.0, true)
	player.parry()
	for i in 20:
		await _frames(1)
		if not is_instance_valid(p):
			break
	_check(not is_instance_valid(p) or not p.reflected, "nu se reflectă")
	_check(GameState.player_hp == 2, "jucătorul ia damage (HP %d)" % GameState.player_hp)

	print("[6] Ricoșeu din zid (velocity.bounce)")
	await _new_player()
	var b := PROJ_SCENE.instantiate() as Projectile
	b.setup(Projectile.Kind.ORB, Vector2.RIGHT, 300.0)
	b.position = Vector2(700, 200)
	add_child(b)
	await _frames(1)
	b.reflect(Vector2(1000, 200), false)
	for i in 90:
		await _frames(1)
		if not is_instance_valid(b) or b.velocity.x < 0.0:
			break
	_check(is_instance_valid(b) and b.velocity.x < 0.0 and b.bounces_left == 0, "a ricoșat o dată")
	if is_instance_valid(b):
		for i in 120:
			await _frames(1)
			if not is_instance_valid(b) or b.velocity.x > 0.0:
				break
	_check(not is_instance_valid(b) or b.velocity.x < 0.0, "nu ricoșează a doua oară")

	print("[7] Piercing străpunge doi inamici; normal se oprește la primul")
	await _new_player()
	var e1 := ENEMY_SCENE.instantiate() as Enemy
	var e2 := ENEMY_SCENE.instantiate() as Enemy
	e1.position = Vector2(300, 300)
	e2.position = Vector2(200, 300)
	for e: Enemy in [e1, e2]:
		e.max_hp = 3
		e.arena_rect = Rect2(e.position - Vector2.ONE, Vector2(2, 2))
	add_child(e1)
	add_child(e2)
	await _frames(2)
	var pp := PROJ_SCENE.instantiate() as Projectile
	pp.setup(Projectile.Kind.ORB, Vector2.LEFT, 200.0)
	pp.position = Vector2(400, 300)
	add_child(pp)
	await _frames(1)
	pp.reflect(Vector2(0, 300), true)
	await get_tree().create_timer(0.8).timeout
	_check(e1.hp == 2 and e2.hp == 2, "perfect: ambii loviți (%d, %d)" % [e1.hp, e2.hp])
	var pn := PROJ_SCENE.instantiate() as Projectile
	pn.setup(Projectile.Kind.ORB, Vector2.LEFT, 200.0)
	pn.position = Vector2(400, 300)
	add_child(pn)
	await _frames(1)
	pn.reflect(Vector2(0, 300), false)
	await get_tree().create_timer(0.8).timeout
	_check(e1.hp == 1 and e2.hp == 2, "normal: doar primul lovit (%d, %d)" % [e1.hp, e2.hp])

	print("[8] Progresie etaje (floor_step 5)")
	GameState.floor_step = 5
	var seq: Array[int] = []
	var f := 0
	while f > -50:
		f = GameState.next_floor_down(f)
		seq.append(f)
	_check(seq == [-1, -5, -10, -15, -20, -25, -30, -35, -40, -45, -50], "secvență %s" % str(seq))
	_check(GameState.boss_index(-10) == 1 and GameState.boss_index(-50) == 5 and GameState.boss_index(-15) == 0, "boss_index")
	_check(GameState.zone_index(-9) == 0 and GameState.zone_index(-11) == 1 and GameState.zone_index(-49) == 4, "zone_index")
	GameState.floor_step = 1
	_check(GameState.next_floor_down(-7) == -8, "floor_step 1 -> etaj cu etaj")

	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(Engine.time_scale == 1.0, "time_scale revine la 1.0 după hitstop (%.2f)" % Engine.time_scale)
	print("MECHANICS %s (%d eșecuri)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
