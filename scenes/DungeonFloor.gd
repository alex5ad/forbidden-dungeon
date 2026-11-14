extends Node2D
## ACTUL II – Arena unui subsol (-1 ... -50).
## Construiește arena (ziduri + stâlpi pentru ricoșeuri), plasează inamicii/boss-ul după etaj,
## deschide „Puțul Abisal” după ce camera e curățată. La -50: Cufărul Regal + Poțiunea.

const ARENA := Rect2(64, 96, 1024, 480)
const WALL := 16.0
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const POTION_TEX := preload("res://assets/sprites/0x72/flask_big_red.png")
const PLAYER_SPAWN := Vector2(576, 520)
const EXIT_POS := Vector2(576, 170)
const CHEST_POS := Vector2(576, 210)

@onready var camera: ShakeCamera = $Camera2D
@onready var floor_rect: CheckerFloor = $Floor
@onready var walls: Node2D = $Walls
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var player: Player = $Player
@onready var exit_door: Trapdoor = $Exit
@onready var hud: HUD = $HUD
@onready var dialog: DialogBox = $DialogBox

var floor_num := -1
var _alive := 0
var _cleared := false
var _game_over := false
var _leaving := false
var _chest: Actor
var _chest_ready := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	floor_num = GameState.current_floor
	if floor_num >= 0:  # rulare directă a scenei din editor (F6)
		floor_num = -1
		GameState.current_floor = -1
	_rng.seed = absi(floor_num) * 7919 + 17
	floor_rect.position = ARENA.position
	floor_rect.size = ARENA.size
	_build_walls()
	player.position = PLAYER_SPAWN
	player.died.connect(_on_player_died)
	exit_door.visible = false
	exit_door.entered.connect(_on_exit_entered)
	hud.retry_pressed.connect(_retry)
	hud.set_floor(floor_num)
	GameState.hp_changed.emit(GameState.player_hp, GameState.max_hp)
	_spawn_enemies()
	_intro()


func _intro() -> void:
	var z := GameState.zone_index(floor_num)
	if GameState.is_boss_floor(floor_num):
		hud.show_banner(GameState.ZONES[z]["boss"], GameState.COL_MAGENTA, 1.6)
		GameState.play_sfx("magic", false, -4.0)
		GameState.shake(8.0)
	else:
		hud.show_banner(GameState.floor_short(floor_num), GameState.COL_GOLD, 1.0)
	if not GameState.seen_zone_hints.has(z):
		GameState.seen_zone_hints.append(z)
		hud.show_hint(GameState.ZONE_HINTS[z], 8.0)


# =============================================================================
#  Arena
# =============================================================================
func _build_walls() -> void:
	var a := ARENA
	# marginile camerei
	walls.add_child(NeonWall.create(Rect2(a.position.x - WALL, a.position.y - WALL, a.size.x + WALL * 2.0, WALL)))
	walls.add_child(NeonWall.create(Rect2(a.position.x - WALL, a.end.y, a.size.x + WALL * 2.0, WALL)))
	walls.add_child(NeonWall.create(Rect2(a.position.x - WALL, a.position.y, WALL, a.size.y)))
	walls.add_child(NeonWall.create(Rect2(a.end.x, a.position.y, WALL, a.size.y)))
	# stâlpi interiori -> unghiuri pentru ricoșeu (bank shots)
	var pillars: Array[Rect2] = []
	if GameState.is_boss_floor(floor_num):
		for c: Vector2 in [Vector2(256, 340), Vector2(896, 340), Vector2(400, 450), Vector2(752, 450)]:
			pillars.append(Rect2(c - Vector2(20, 20), Vector2(40, 40)))
	else:
		var sizes: Array[Vector2] = [Vector2(32, 32), Vector2(64, 32), Vector2(32, 64), Vector2(48, 48)]
		var wanted := _rng.randi_range(2, 4)
		var attempts := 0
		while pillars.size() < wanted and attempts < 60:
			attempts += 1
			var s := sizes[_rng.randi_range(0, sizes.size() - 1)]
			var c := Vector2(_rng.randf_range(160.0, 992.0), _rng.randf_range(300.0, 430.0))
			var r := Rect2(c - s * 0.5, s)
			var ok := true
			for other in pillars:
				if other.grow(70.0).intersects(r):
					ok = false
					break
			if ok:
				pillars.append(r)
	for r in pillars:
		walls.add_child(NeonWall.create(r))


func _spawn_enemies() -> void:
	if GameState.is_boss_floor(floor_num):
		var boss := ENEMY_SCENE.instantiate() as Enemy
		boss.is_boss = true
		boss.boss_index = GameState.boss_index(floor_num)
		boss.position = Vector2(576, 200)
		_add_enemy(boss)
		hud.show_boss_bar(boss.display_name, boss.max_hp)
		boss.hp_changed.connect(hud.update_boss_bar)
		return
	var types := GameState.enemy_types_for_floor(floor_num)
	types.shuffle()
	var count := GameState.enemy_count_for_floor(floor_num)
	for i in count:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.enemy_type = types[i % types.size()] as Enemy.Type
		var x := 576.0
		if count > 1:
			x = lerpf(ARENA.position.x + 140.0, ARENA.end.x - 140.0, float(i) / float(count - 1))
		e.position = Vector2(x + _rng.randf_range(-30.0, 30.0), _rng.randf_range(150.0, 250.0))
		_add_enemy(e)


func _add_enemy(e: Enemy) -> void:
	e.arena_rect = ARENA.grow(-40.0)
	e.projectile_parent = projectiles
	e.died.connect(_on_enemy_died)
	enemies.add_child(e)
	_alive += 1


# =============================================================================
#  Progres
# =============================================================================
func _on_enemy_died(_e: Enemy) -> void:
	_alive -= 1
	if _alive <= 0 and not _cleared:
		_cleared = true
		# suntem în callback-ul fizicii -> amânăm (adăugăm Area2D-uri noi)
		_on_room_cleared.call_deferred()


func _on_room_cleared() -> void:
	for p in projectiles.get_children():
		if p is Projectile and (p as Projectile).is_hostile():
			(p as Projectile).vanish()
	var boss_floor := GameState.is_boss_floor(floor_num)
	if boss_floor:
		GameState.restore_full_hp()
		GameState.play_sfx("heal", false)
		hud.show_banner("BOSS ÎNVINS!", GameState.COL_MAGENTA, 1.4)
		FX.popup(self, player.global_position + Vector2(0, -50), "HP REFĂCUT", GameState.COL_GOLD, 22)
	else:
		hud.show_banner("CAMERĂ CURĂȚATĂ", GameState.COL_GOLD, 1.0)
	if floor_num <= GameState.DEEPEST_FLOOR:
		await get_tree().create_timer(1.2).timeout
		_spawn_treasure()
		return
	await get_tree().create_timer(0.8).timeout
	var next := GameState.next_floor_down(floor_num)
	exit_door.position = EXIT_POS
	exit_door.caption = "PUȚUL ABISAL  ->  %s" % GameState.floor_short(next)
	exit_door.open_door()
	hud.show_hint("Calcă pe Puțul Abisal ca să cobori mai adânc.", 5.0)


func _on_exit_entered() -> void:
	if _leaving or _game_over:
		return
	_leaving = true
	player.controllable = false
	GameState.play_sfx("swing", false)
	var t := create_tween()
	t.tween_property(player, "global_position", exit_door.global_position, 0.25)
	t.tween_property(player.sprite, "scale", Vector2(0.2, 0.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	GameState.travel_to(GameState.next_floor_down(floor_num))


func _on_player_died() -> void:
	_game_over = true
	await get_tree().create_timer(0.9).timeout
	hud.show_game_over(floor_num)


func _retry() -> void:
	if GameState.is_transitioning():
		return
	GameState.restore_full_hp()
	GameState.change_scene(GameState.SCENE_DUNGEON)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over and event.is_action_pressed("retry"):
		_retry()


# =============================================================================
#  Subsolul -50: Cufărul Regal, Coroana și Poțiunea Vieții Veșnice
# =============================================================================
func _spawn_treasure() -> void:
	var beam := NeonBeam.new()
	beam.beam_color = GameState.COL_GOLD
	beam.intensity = 0.0
	beam.position = Vector2(CHEST_POS.x - 60.0, ARENA.position.y)
	beam.size = Vector2(120, CHEST_POS.y - ARENA.position.y + 20.0)
	enemies.add_child(beam)
	create_tween().tween_property(beam, "intensity", 0.9, 0.8)
	_chest = Actor.new()
	_chest.character_id = "chest"
	_chest.sprite_scale = 4.0
	_chest.position = CHEST_POS
	enemies.add_child(_chest)
	FX.burst(self, CHEST_POS, GameState.COL_GOLD, 40, 240.0, 0.8, 4.0)
	GameState.play_sfx("magic", false)
	GameState.shake(8.0)
	hud.show_banner("CUFĂRUL REGAL", GameState.COL_GOLD, 1.4)
	hud.show_hint("Apropie-te de Cufărul Regal.", 6.0)
	_chest_ready = true


func _physics_process(_delta: float) -> void:
	if _chest_ready and not _game_over and player.global_position.distance_to(CHEST_POS) < 80.0:
		_chest_ready = false
		_open_treasure()


func _open_treasure() -> void:
	player.controllable = false
	_chest.play("open")
	GameState.play_sfx("perfect", false, -4.0)
	await get_tree().create_timer(0.5).timeout
	FX.burst(self, CHEST_POS + Vector2(0, -20), GameState.COL_GOLD, 60, 300.0, 1.0, 4.0)
	# Coroana și Poțiunea se ridică din cufăr
	var crown := Crown.new()
	crown.pixel = 4.0
	crown.position = CHEST_POS
	crown.z_index = 10
	add_child(crown)
	var potion := Sprite2D.new()
	potion.texture = POTION_TEX
	potion.scale = Vector2(3, 3)
	potion.position = CHEST_POS
	potion.z_index = 10
	add_child(potion)
	var t := create_tween().set_parallel()
	t.tween_property(crown, "position", CHEST_POS + Vector2(-50, -70), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(potion, "position", CHEST_POS + Vector2(50, -70), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	var narrator := Color("#ff7bff")
	await dialog.say("", "Cufărul Regal se deschide. Aur cât să umple o sală întreagă... și Coroana Regală!", narrator)
	await dialog.say("", "Pe fundul cufărului pulsează o fiolă roșie: Poțiunea Vieții Veșnice. Tinerețe fără sfârșit... sau viață pentru cel care a murit.", narrator)
	await dialog.say(GameState.player_name, "Nemurirea nu e pentru mine. Regele este cel care merită o a doua șansă. I-o voi duce lui.", Color.WHITE)
	await dialog.say("", "BOUNCE BACK! Cu Poțiunea și Coroana, Cavalerul pornește fulgerător înapoi spre Parter!", GameState.COL_GOLD)
	dialog.close()
	GameState.collect_treasure()
	GameState.restore_full_hp()
	var up := create_tween().set_parallel()
	up.tween_property(crown, "position", player.global_position + Vector2(-16, -40), 0.4)
	up.tween_property(potion, "position", player.global_position + Vector2(16, -40), 0.4)
	await up.finished
	GameState.travel_to(0)
