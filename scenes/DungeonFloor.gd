extends Node2D
## ACTUL II – Arena unui subsol (-1 ... -50).
## Construiește arena (ziduri + stâlpi pentru ricoșeuri), plasează inamicii capitolului sau boss-ul,
## deschide „Puțul Abisal” după ce camera e curățată. La -50: Cufărul Regal + Poțiunea.
## Fantoma Regelui (GhostGuide) îl însoțește pe jucător și reacționează la ce se întâmplă.

const ARENA := Rect2(64, 96, 1024, 480)
const WALL := 16.0
const ENEMY_SCENE := preload("res://entities/Enemy.tscn")
const POTION_TEX := preload("res://assets/sprites/0x72/flask_big_red.png")
const PLAYER_SPAWN := Vector2(576, 520)
const EXIT_POS := Vector2(576, 170)
const CHEST_POS := Vector2(576, 210)
const NARRATOR := Color("#ff7bff")

@onready var camera: ShakeCamera = $Camera2D
@onready var floor_rect: CheckerFloor = $Floor
@onready var walls: Node2D = $Walls
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var player: Player = $Player
@onready var guide: GhostGuide = $Guide
@onready var exit_door: Trapdoor = $Exit
@onready var hud: HUD = $HUD
@onready var dialog: DialogBox = $DialogBox

var floor_num := -1
var _alive := 0
var _cleared := false
var _game_over := false
var _leaving := false
var _boss: Enemy
var _pillars: Array[Rect2] = []
var _chest: Actor
var _chest_ready := false
var _miss_streak := 0
var _perfects_this_floor := 0
var _was_hit := false            # pentru bonusul „fără lovituri” (+50% monede)
var _low_hp_warned := false
var _phase_warned := false
var _bounce_backs_at_start := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	floor_num = GameState.current_floor
	if floor_num >= 0:  # rulare directă a scenei din editor (F6)
		floor_num = -1
		GameState.current_floor = -1
	if GameState.is_boss_floor(floor_num):
		GameState.play_music("boss")
		if floor_num == GameState.DEEPEST_FLOOR:
			GameState.play_final_boss_sting()
	else:
		GameState.play_music("normal")
	_rng.seed = absi(floor_num) * 7919 + 17
	floor_rect.position = ARENA.position
	floor_rect.size = ARENA.size
	_build_walls()
	player.position = PLAYER_SPAWN
	player.died.connect(_on_player_died)
	player.hurt.connect(_on_player_hurt)
	player.parried.connect(_on_player_parried)
	player.parry_missed.connect(_on_parry_missed)
	guide.target = player
	projectiles.child_entered_tree.connect(_on_projectile_added)
	exit_door.visible = false
	exit_door.entered.connect(_on_exit_entered)
	hud.retry_pressed.connect(_retry)
	hud.set_floor(floor_num)
	_bounce_backs_at_start = GameState.bounce_backs
	# checkpoint: „Continue” de pe ecranul de acasă pornește de la începutul acestui etaj
	GameState.checkpoint(floor_num)
	_spawn_enemies()
	_intro()


func _intro() -> void:
	var z := GameState.zone_index(floor_num)
	var tip := ""
	var prio := 0
	if GameState.is_boss_floor(floor_num):
		hud.show_banner(GameState.ZONES[z]["boss"], GameState.COL_MAGENTA, 1.6)
		GameState.play_sfx("magic", false, -4.0)
		GameState.shake(8.0)
		tip = GhostGuide.BOSS_TIPS[z]
		prio = 2
	elif GameState.is_chapter_start(floor_num):
		hud.show_banner("CHAPTER %d\n%s" % [GameState.chapter_number(floor_num), GameState.ZONES[z]["name"]],
				GameState.COL_GOLD, 1.8)
		GameState.play_sfx("magic", false, -8.0)
		tip = GhostGuide.CHAPTER_TIPS[z]
		prio = 2
	else:
		hud.show_banner(GameState.floor_short(floor_num), GameState.COL_GOLD, 1.0)
		tip = guide.general_tip(absi(floor_num))
	# fantoma vorbește după ce bannerul dispare, ca să nu se suprapună
	await get_tree().create_timer(1.4 if prio > 0 else 0.6).timeout
	if not is_inside_tree() or _game_over:
		return
	if floor_num == -1:
		guide.tip_once("first_floor", 3, 5.0)
	guide.say(tip, prio, 7.0 if prio > 0 else 5.5)


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
	if GameState.is_boss_floor(floor_num):
		for c: Vector2 in [Vector2(256, 340), Vector2(896, 340), Vector2(400, 450), Vector2(752, 450)]:
			_pillars.append(Rect2(c - Vector2(20, 20), Vector2(40, 40)))
	else:
		var sizes: Array[Vector2] = [Vector2(32, 32), Vector2(64, 32), Vector2(32, 64), Vector2(48, 48)]
		var wanted := _rng.randi_range(2, 4)
		var attempts := 0
		while _pillars.size() < wanted and attempts < 60:
			attempts += 1
			var s := sizes[_rng.randi_range(0, sizes.size() - 1)]
			var c := Vector2(_rng.randf_range(160.0, 992.0), _rng.randf_range(300.0, 430.0))
			var r := Rect2(c - s * 0.5, s)
			var ok := true
			for other in _pillars:
				if other.grow(70.0).intersects(r):
					ok = false
					break
			if ok:
				_pillars.append(r)
	for r in _pillars:
		walls.add_child(NeonWall.create(r))


func _spawn_enemies() -> void:
	if GameState.is_boss_floor(floor_num):
		_boss = ENEMY_SCENE.instantiate() as Enemy
		_boss.is_boss = true
		_boss.boss_index = GameState.boss_index(floor_num)
		_boss.position = Vector2(576, 200)
		_add_enemy(_boss)
		hud.show_boss_bar(_boss.display_name, _boss.max_hp)
		_boss.hp_changed.connect(hud.update_boss_bar)
		_boss.summon_requested.connect(_on_summon_requested)
		_boss.special_used.connect(_on_boss_special)
		return
	var types := GameState.enemy_types_for_floor(floor_num)
	types.shuffle()
	var count := GameState.enemy_count_for_floor(floor_num)
	var difficulty := GameState.floor_difficulty(floor_num)
	for i in count:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.enemy_type = types[i % types.size()] as Enemy.Type
		e.difficulty = difficulty
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
#  Ajutoarele boss-ului
# =============================================================================
func _on_summon_requested(enemy_type: int, at: Vector2) -> void:
	# poate veni din callback-ul fizicii -> adăugăm corpul nou amânat
	_spawn_minion.call_deferred(enemy_type, at)


func _spawn_minion(enemy_type: int, at: Vector2) -> void:
	if _cleared or _game_over or _boss == null or _boss.is_dead():
		return
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.enemy_type = clampi(enemy_type, 0, 3) as Enemy.Type
	e.is_minion = true
	e.position = _free_spot_near(at)
	_add_enemy(e)
	FX.burst(self, e.position, GameState.COL_MAGENTA, 24, 180.0, 0.5, 3.0)


func _free_spot_near(at: Vector2) -> Vector2:
	var area := Rect2(ARENA.position.x + 60.0, ARENA.position.y + 40.0, ARENA.size.x - 120.0, ARENA.size.y * 0.45)
	var p := at.clamp(area.position, area.end)
	for i in 12:
		var blocked := false
		for r in _pillars:
			if r.grow(28.0).has_point(p):
				blocked = true
				break
		if not blocked and p.distance_to(player.global_position) > 140.0:
			return p
		p = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
	return p


func _on_boss_special(kind: String) -> void:
	match kind:
		"phase":
			if not _phase_warned:
				_phase_warned = true
				guide.tip_event("boss_phase", 2, 3.5)
		"summon":
			guide.tip_once("summon", 2)
		"charge":
			guide.tip_once("charge", 3, 3.0)
		"blink":
			guide.tip_once("blink", 2, 3.5)


# =============================================================================
#  Reacțiile fantomei la jucător
# =============================================================================
func _on_player_hurt(hp: int) -> void:
	_was_hit = true
	guide.tip_once("first_hit", 2)
	if hp == 1 and not _low_hp_warned:
		_low_hp_warned = true
		guide.tip_event("low_hp", 3, 4.0)


func _on_player_parried(perfect: bool) -> void:
	_miss_streak = 0
	if perfect:
		_perfects_this_floor += 1
	if perfect:
		guide.tip_once("first_perfect", 1, 3.5)
	if GameState.bounce_backs > _bounce_backs_at_start:
		_bounce_backs_at_start = GameState.bounce_backs
		_low_hp_warned = false
		guide.tip_once("bounce_back", 3, 4.0)


func _on_parry_missed() -> void:
	_miss_streak += 1
	if _miss_streak >= 3:
		_miss_streak = 0
		guide.tip_once("too_early", 2)


func _on_projectile_added(node: Node) -> void:
	if node is Projectile and (node as Projectile).unparryable:
		guide.tip_once("first_spear", 3, 4.0)


# =============================================================================
#  Progres
# =============================================================================
func _on_enemy_died(e: Enemy) -> void:
	_alive -= 1
	if e.is_boss:
		# ajutoarele dispar odată cu boss-ul
		for m in get_tree().get_nodes_in_group("minions"):
			if m is Enemy:
				(m as Enemy).dissolve.call_deferred()
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
		GameState.play_music("postfight")
		GameState.restore_full_hp()
		GameState.play_sfx("heal", false)
		hud.show_banner("BOSS DEFEATED!", GameState.COL_MAGENTA, 1.4)
		FX.popup(self, player.global_position + Vector2(0, -50), "HEALTH RESTORED", GameState.COL_GOLD, 22)
		if floor_num > GameState.DEEPEST_FLOOR:
			guide.tip_event("boss_down", 2, 4.0)
	else:
		hud.show_banner("ROOM CLEARED", GameState.COL_GOLD, 1.0)
	_give_coins()
	if floor_num <= GameState.DEEPEST_FLOOR and not GameState.replay_mode:
		await get_tree().create_timer(1.2).timeout
		_spawn_treasure()
		return
	await get_tree().create_timer(0.8).timeout
	exit_door.position = EXIT_POS
	if GameState.replay_mode:
		# rejucare: trapa duce înapoi în meniul de nivele
		exit_door.caption = "LEVEL COMPLETE  ->  LEVELS"
		exit_door.open_door()
		return
	var next := GameState.next_floor_down(floor_num)
	exit_door.caption = "ABYSSAL PIT  ->  %s" % GameState.floor_short(next)
	exit_door.open_door()
	guide.tip_once("first_clear", 2)
	# etajul e câștigat: „Continue” pornește direct de la următorul
	GameState.checkpoint(next)


func _give_coins() -> void:
	## Monede pentru camera curățată (vezi GameState.clear_reward):
	## bază 10 × capitol (boss 100 × capitol) + 2 / PERFECT + 50% fără lovituri;
	## rejucarea unui etaj deja terminat plătește jumătate.
	var repeat := GameState.replay_mode and GameState.is_cleared(floor_num)
	var r := GameState.clear_reward(floor_num, _perfects_this_floor, not _was_hit, repeat)
	GameState.add_coins(int(r["total"]))
	GameState.mark_cleared(floor_num)
	GameState.save_game()
	GameState.play_sfx("coin", false, -6.0)
	FX.popup(self, player.global_position + Vector2(0, -96), "+%d COINS" % int(r["total"]), GameState.COL_GOLD, 26)
	var parts: Array[String] = ["floor %d" % int(r["base"])]
	if int(r["perfect"]) > 0:
		parts.append("perfect +%d" % int(r["perfect"]))
	if int(r["flawless"]) > 0:
		parts.append("flawless +%d" % int(r["flawless"]))
	if repeat:
		parts.append("replay x0.5")
	FX.popup(self, player.global_position + Vector2(0, -66), "  ·  ".join(parts), Color(GameState.COL_GOLD, 0.85), 15)
	FX.burst(self, player.global_position + Vector2(0, -40), GameState.COL_GOLD, 20, 160.0, 0.6, 3.0)


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
	if GameState.replay_mode:
		GameState.go_home(true)
	else:
		GameState.travel_to(GameState.next_floor_down(floor_num))


func _on_player_died() -> void:
	_game_over = true
	guide.hush()
	await get_tree().create_timer(0.9).timeout
	hud.show_game_over(floor_num, guide.general_tip(randi()))


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
	hud.show_banner("ROYAL CHEST", GameState.COL_GOLD, 1.4)
	guide.say("My treasure! Open the chest, %s!" % GameState.player_name, 3, 6.0)
	_chest_ready = true


func _physics_process(_delta: float) -> void:
	if _chest_ready and not _game_over and player.global_position.distance_to(CHEST_POS) < 80.0:
		_chest_ready = false
		_open_treasure()


func _open_treasure() -> void:
	player.controllable = false
	guide.hush()
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
	await dialog.say("", "The Royal Chest opens. Enough gold to fill an entire hall... and the Royal Crown!", NARRATOR)
	await dialog.say("", "At the bottom of the chest pulses a red vial: the Potion of Eternal Life. Endless youth... or life for the one who died.", NARRATOR)
	await dialog.say(GameState.player_name, "Immortality isn't for me. The King deserves a second chance. I'll take it to him.", Color.WHITE)
	await dialog.say("", "BOUNCE BACK! With the Potion and Crown, the Knight dashes back to the Ground Floor!", GameState.COL_GOLD)
	dialog.close()
	GameState.collect_treasure()
	GameState.add_coins(GameState.COINS_TREASURE)
	GameState.play_sfx("coin", false)
	FX.popup(self, player.global_position + Vector2(0, -80), "+%d COINS" % GameState.COINS_TREASURE, GameState.COL_GOLD, 28)
	GameState.restore_full_hp()
	var up := create_tween().set_parallel()
	up.tween_property(crown, "position", player.global_position + Vector2(-16, -40), 0.4)
	up.tween_property(potion, "position", player.global_position + Vector2(16, -40), 0.4)
	await up.finished
	GameState.travel_to(0)
