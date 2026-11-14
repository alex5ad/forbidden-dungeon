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


func _boss(index: int, pos: Vector2) -> Enemy:
	var b := ENEMY_SCENE.instantiate() as Enemy
	b.is_boss = true
	b.boss_index = index
	b.position = pos
	add_child(b)
	b._timer = 999.0  # fără atacuri obișnuite în test
	return b


func _spawn(offset: Vector2, kind: Projectile.Kind, spd: float, unparryable := false) -> Projectile:
	var p := PROJ_SCENE.instantiate() as Projectile
	p.setup(kind, -offset, spd, unparryable)
	p.position = player.global_position + Vector2(0, -4) + offset
	add_child(p)
	return p


func _run() -> void:
	Engine.time_scale = 1.0
	# testul nu atinge salvarea reală a jucătorului și pornește cu scutul de bază
	GameState.save_path = "user://mechanics_test.save"
	GameState.owned_items.assign(GameState.DEFAULT_ITEMS)
	GameState.equipped_shield = "shield_wood"
	GameState.equipped_armor = "armor_classic"
	GameState.tips_enabled = true
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


	print("[9] 50 de etaje: capitole, număr de inamici, ritm")
	GameState.floor_step = 1
	_check(GameState.chapter_number(-12) == 2 and GameState.chapter_floor(-12) == 2, "capitolul 2, etajul 2/10")
	_check(GameState.is_chapter_start(-21) and not GameState.is_chapter_start(-22), "începutul capitolului 3")
	var counts: Array[int] = []
	for d in range(1, 10):
		counts.append(GameState.enemy_count_for_floor(-d))
	_check(counts == [1, 1, 1, 2, 2, 2, 3, 3, 3], "capitolul 1: %s" % str(counts))
	_check(GameState.enemy_count_for_floor(-49) == 5, "abisul: 5 inamici la -49")
	_check(GameState.floor_difficulty(-31) == 1.0 and GameState.floor_difficulty(-39) > 1.25, "ritmul crește în capitol")
	_check(GameState.enemy_types_for_floor(-35) == [3], "Cazarma: Cavaleri Fantomă")

	print("[10] Boss 4: șarjă cu damage la contact, evitată prin salt")
	await _new_player()
	var b4 := _boss(4, Vector2(576, 250))
	await _frames(2)
	b4._start_charge()
	await get_tree().create_timer(0.6).timeout
	_check(GameState.player_hp == 2, "șarja lovește (HP %d)" % GameState.player_hp)
	b4.queue_free()
	await _new_player()
	b4 = _boss(4, Vector2(576, 250))
	await _frames(2)
	player.jump()
	b4._start_charge()
	await get_tree().create_timer(0.6).timeout
	_check(GameState.player_hp == 3, "saltul evită șarja (HP %d)" % GameState.player_hp)
	b4.queue_free()

	print("[11] Boss 1: teleport; faza 2 cheamă ajutoare; ajutoarele dispar")
	await _new_player()
	var b1 := _boss(1, Vector2(576, 200))
	await _frames(2)
	var before := b1.global_position
	b1._blink()
	await get_tree().create_timer(0.6).timeout
	_check(b1.global_position.distance_to(before) > 1.0, "s-a teleportat")
	var summons: Array[int] = []
	b1.summon_requested.connect(func(t: int, _at: Vector2): summons.append(t))
	for i in 5:
		b1.take_hit(1)
	await _frames(2)
	_check(b1._phase == 2, "faza 2 la jumătate de HP")
	_check(summons == [0, 0], "a chemat 2 fantome (%s)" % str(summons))
	var minion := ENEMY_SCENE.instantiate() as Enemy
	minion.is_minion = true
	minion.position = Vector2(300, 200)
	add_child(minion)
	await _frames(1)
	_check(minion.is_in_group("minions"), "ajutorul e în grupul minions")
	var kills_before := GameState.kills
	minion.dissolve()
	_check(minion.is_dead() and GameState.kills == kills_before, "dissolve() fără kill")
	b1.queue_free()

	print("[12] Fantoma Regelui: sfaturi unice și prioritate")
	var guide := GhostGuide.new()
	guide.target = player
	add_child(guide)
	await _frames(1)
	GameState.seen_tips.clear()
	guide.tip_once("first_hit")
	guide.tip_once("first_hit")
	_check(GameState.seen_tips.count("first_hit") == 1, "sfatul unic e spus o singură dată")
	_check(guide._bubble.visible and guide._text.text == String(GhostGuide.EVENT_TIPS["first_hit"]), "balonul arată sfatul")
	guide.say("normal", 1)
	guide.say("urgent", 5)
	_check(guide._text.text == "urgent", "prioritatea mare întrerupe")
	_check(guide._queue.size() == 1, "sfatul normal așteaptă la rând")
	guide.queue_free()


	print("[13] Monede și magazin: scuturi care țin mai mult, armuri cosmetice")
	GameState.coins = 0
	GameState.owned_items.assign(GameState.DEFAULT_ITEMS)
	GameState.equipped_shield = "shield_wood"
	GameState.equipped_armor = "armor_classic"
	_check(GameState.floor_reward(-3) == 5 and GameState.floor_reward(-23) == 9, "recompensă etaj (cap. 1: 5, cap. 3: 9)")
	_check(GameState.floor_reward(-10) == 25 and GameState.floor_reward(-50) == 65, "recompensă boss (25 / 65)")
	_check(not GameState.buy("shield_iron"), "fără bani nu cumperi")
	GameState.add_coins(130)
	_check(GameState.buy("shield_iron") and GameState.coins == 10, "cumpără Iron Shield (rămân 10)")
	_check(GameState.equipped_shield == "shield_iron", "scutul cumpărat e echipat")
	_check(not GameState.buy("shield_iron"), "nu îl cumperi de două ori")
	await _new_player()
	_check(is_equal_approx(player.parry_window, 0.18) and is_equal_approx(player.miss_cooldown, 0.4), "Iron Shield: parry 0.18s, cooldown 0.4s")
	player.parry()
	await get_tree().create_timer(0.16).timeout
	_check(player.parry_active, "scutul ține încă ridicat la 0.16s")
	GameState.equip("shield_wood")
	GameState.add_coins(250)
	_check(GameState.buy("armor_valkyrie"), "cumpără Valkyrie Armor")
	await _new_player()
	_check(is_equal_approx(player.parry_window, 0.15), "armura nu schimbă lupta")
	_check(player.sprite.sprite_frames == SpriteLib.frames("knight_f"), "armura schimbă aspectul")

	print("[14] Salvare și continuare")
	GameState.save_path = "user://mechanics_test.save"
	GameState.coins = 77
	GameState.run_active = true
	GameState.resume_floor = -12
	GameState.player_hp = 2
	GameState.player_name = "Tester"
	GameState.tips_enabled = false
	GameState.save_game()
	GameState.coins = 0
	GameState.resume_floor = 0
	GameState.player_name = "X"
	GameState.tips_enabled = true
	_check(GameState.load_game(), "load_game() reușește")
	_check(GameState.coins == 77 and GameState.resume_floor == -12 and GameState.player_hp == 2, "monede, etaj și HP restaurate")
	_check(GameState.player_name == "Tester" and not GameState.tips_enabled, "nume și setarea sfaturilor restaurate")
	_check(GameState.owns("armor_valkyrie") and GameState.equipped_armor == "armor_valkyrie", "obiectele cumpărate rămân")
	_check(GameState.continue_scene() == GameState.SCENE_DUNGEON, "Continue -> subsolul salvat")
	GameState.resume_floor = 0
	GameState.mirror_visit = 2
	_check(GameState.continue_scene() == GameState.SCENE_MIRROR, "Continue -> Oglinda (vizita 2)")
	GameState.mirror_visit = 1
	GameState.tips_enabled = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	print("[15] Cartea: titlul încape pe copertă și se scrijelește")
	var book := DarkBook.new()
	book.position = Vector2(576, 300)
	book.open_amount = 0.0
	add_child(book)
	await _frames(1)
	var inner := book.cover_rect().grow(-20.0)
	_check(inner.encloses(book.title_rect()), "titlul în interiorul copertei (font %d)" % book.title_font_size)
	await book.engrave(0.4).finished
	_check(is_equal_approx(book.title_progress, 1.0), "scrijelirea se termină")
	book.queue_free()

	print("[16] Fantoma: nu blochează vederea, X ascunde sfaturile")
	var g2 := GhostGuide.new()
	g2.target = player
	add_child(g2)
	await _frames(2)
	GameState.set_tips_enabled(false)
	g2.say("nu trebuie să apară", 5)
	_check(not g2._bubble.visible, "cu sfaturile oprite nu apare nimic")
	GameState.set_tips_enabled(true)
	await _frames(1)
	_check(g2._bubble.visible, "pornite la loc -> mesaj de confirmare")
	var corner: Vector2 = g2.PERCHES[g2._perch]
	_check(corner.distance_to(player.global_position) > 300.0, "fantoma stă într-un colț departe de Cavaler")
	await _frames(3)
	# un inamic sub balon -> balonul devine aproape transparent
	var under := ENEMY_SCENE.instantiate() as Enemy
	under.position = g2.bubble_rect().get_center()
	under.arena_rect = Rect2(under.position - Vector2.ONE, Vector2(2, 2))
	add_child(under)
	under._timer = 999.0
	await get_tree().create_timer(0.4).timeout
	_check(g2._bubble.modulate.a < 0.5, "balonul devine transparent peste acțiune (%.2f)" % g2._bubble.modulate.a)
	under.queue_free()
	# Cavalerul se apropie de colțul fantomei -> fantoma se mută în alt colț
	var old_perch: int = g2._perch
	player.global_position = g2.PERCHES[old_perch] + Vector2(60, 60)
	await _frames(2)
	_check(g2._perch != old_perch, "fantoma se mută când vine Cavalerul")
	g2.queue_free()
	player.global_position = Vector2(576, 400)

	print("[17] Pauză: PLAY / HOME")
	var pm := PauseMenu.new()
	add_child(pm)
	await _frames(1)
	pm.pause()
	_check(get_tree().paused and pm.is_open(), "pauza oprește jocul")
	pm.resume()
	_check(not get_tree().paused and not pm.is_open(), "PLAY continuă jocul")
	pm.queue_free()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(Engine.time_scale == 1.0, "time_scale revine la 1.0 după hitstop (%.2f)" % Engine.time_scale)
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("MECHANICS %s (%d eșecuri)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
