extends Node
## Test automat (temporar): parcurge tot jocul headless și raportează.

var _t := 0.0
var _scene_t := 0.0
var _last_scene := ""
var _accept_t := 0.0
var _visited: Array[String] = []
var _floors: Array[int] = []
var _died_once := false
var _death_test_armed := false
var _kills_spawned := 0.0
var _end_seen := -1.0
var _shots_dir := ""
var _taken: Dictionary = {}
## [scenă, etaj (-99 = oricare), secunde în scenă, nume fișier]
const SHOTS := [
	["IntroGates", -99, 3.2, "01_intro"],
	["IntroGates", -99, 5.6, "02_intro_beam"],
	["MirrorRoom", 0, 4.0, "03_mirror_king"],
	["CastleMap", -1, 1.0, "04_map"],
	["DungeonFloor", -1, 2.9, "05_floor_1"],
	["DungeonFloor", -11, 1.2, "05b_chapter2"],
	["DungeonFloor", -27, 2.3, "05c_skeletons"],
	["DungeonFloor", -10, 2.4, "06_boss1"],
	["DungeonFloor", -15, 2.3, "07_spirits"],
	["DungeonFloor", -20, 2.4, "08_boss2"],
	["DungeonFloor", -35, 2.4, "09_phantoms"],
	["DungeonFloor", -40, 2.4, "10_boss4"],
	["DungeonFloor", -50, 2.4, "11_boss5"],
	["CastleMap", 0, 0.9, "12_bounce_back"],
	["ThroneEnding", -99, 3.0, "13_throne"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_isolate_save()
	GameState.floor_step = 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
		elif a.begins_with("--step="):
			GameState.floor_step = int(a.substr(7))
	(func():
		# rămânem copil al root-ului (ca un autoload), iar jocul pornește ca scenă curentă
		get_tree().current_scene = null
		get_tree().change_scene_to_file(GameState.SCENE_MENU)
	).call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if Engine.time_scale == 1.0:
		Engine.time_scale = 2.5
	if _t > 1600.0:
		print("SMOKE FAIL: timeout. visited=", _visited, " floors=", _floors)
		get_tree().quit(1)
		return
	var scene := get_tree().current_scene
	if scene == null or scene == self:
		return
	var sname := scene.name
	if sname != _last_scene:
		_last_scene = sname
		_scene_t = 0.0
		_visited.append(sname)
		print("[smoke] scene: ", sname, "  floor=", GameState.current_floor, "  t=", snappedf(_t, 0.1))
		if sname == "DungeonFloor":
			_floors.append(GameState.current_floor)
	_scene_t += delta
	_accept_t += delta
	_maybe_shot(sname)
	match sname:
		"MainMenu":
			_drive_menu(scene)
		"IntroGates", "CastleMap":
			_press_accept_every(0.4)
		"MirrorRoom":
			var panel: PanelContainer = scene.get("_name_panel")
			if panel and panel.visible:
				var edit: LineEdit = scene.get("_name_edit")
				edit.text = "Tester"
				scene.call("_confirm_name")
			_press_accept_every(0.15)
		"DungeonFloor":
			_drive_dungeon(scene)
		"ThroneEnding":
			var book: DarkBook = scene.get("book")
			if book and book.title_progress > 0.55 and not _taken.has("13b_book"):
				_taken["13b_book"] = true
				_save_shot("13b_book")
			var panel: PanelContainer = scene.get("end_panel")
			if panel and not panel.visible:
				_press_accept_every(0.15)  # nu apăsa „JOACĂ DIN NOU” (are focus)
			if panel and panel.visible and _end_seen < 0.0:
				_end_seen = _scene_t
			if panel and panel.visible and _scene_t - _end_seen > 0.8:
				_shoot_end()
				if GameState.run_active or GameState.coins <= 0:
					print("SMOKE FAIL: run_active=", GameState.run_active, " coins=", GameState.coins)
					get_tree().quit(1)
					return
				print("SMOKE OK: coins=", GameState.coins, " visited=", _visited, " floors=", _floors, " kills=", GameState.kills,
						" parries=", GameState.parries, " deaths=", GameState.deaths, " name=", GameState.player_name)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
				get_tree().quit(0)


func _maybe_shot(sname: String) -> void:
	if _shots_dir == "":
		return
	for s in SHOTS:
		var key: String = s[3]
		if _taken.has(key) or s[0] != sname or _scene_t < float(s[2]):
			continue
		var fl: int = s[1]
		var cur := GameState.target_floor if sname == "CastleMap" else GameState.current_floor
		if fl != -99 and fl != cur:
			continue
		_taken[key] = true
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shots_dir + "/" + key + ".png")
		print("[smoke] shot ", key)


func _shoot_end() -> void:
	if _shots_dir != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shots_dir + "/14_end.png")


func _isolate_save() -> void:
	## Testul nu are voie să strice salvarea reală a jucătorului.
	GameState.save_path = "user://smoke_test.save"
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	GameState.coins = 0
	GameState.owned_items.assign(GameState.DEFAULT_ITEMS)
	GameState.equipped_shield = "shield_wood"
	GameState.equipped_armor = "armor_classic"
	GameState.tips_enabled = true
	GameState.run_active = false


var _menu_step := 0


func _drive_menu(scene: Node) -> void:
	## Ecranul de acasă -> magazin (cumpără o armură) -> NEW GAME.
	match _menu_step:
		0:
			if _scene_t > 0.8:
				_save_shot("00_menu")
				GameState.add_coins(400)
				scene.call("_on_shop")
				_menu_step = 1
		1:
			if _scene_t > 1.6:
				var shop: ShopPanel = scene.get("_shop")
				shop.call("_on_item_pressed", "shield_iron")
				shop.call("_on_item_pressed", "armor_neon")
				_save_shot("00b_shop")
				shop.close()
				_menu_step = 2
		2:
			if _scene_t > 2.2:
				_menu_step = 3
				scene.call("_on_new_game")


func _save_shot(key: String) -> void:
	if _shots_dir == "":
		return
	get_viewport().get_texture().get_image().save_png(_shots_dir + "/" + key + ".png")
	print("[smoke] shot ", key)


func _press_accept_every(interval: float) -> void:
	if _accept_t < interval:
		return
	_accept_t = 0.0
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = "ui_accept"
	up.pressed = false
	Input.parse_input_event(up)


func _drive_dungeon(scene: Node) -> void:
	var player: Player = scene.get("player")
	var dialog: DialogBox = scene.get("dialog")
	if dialog and dialog.is_open():
		_press_accept_every(0.15)
		return
	if player == null:
		return
	# Testul de moarte + retry, o singură dată, la -5
	if GameState.current_floor == -5 and not _died_once:
		if _scene_t > 1.5 and not _death_test_armed:
			_death_test_armed = true
			GameState.player_hp = 1
			player.take_damage(1)
		if player.is_dead() and _scene_t > 3.0:
			_died_once = true
			var ev := InputEventAction.new()
			ev.action = "retry"
			ev.pressed = true
			Input.parse_input_event(ev)
		return
	# Pauza (PLAY / HOME) la etajul -3
	if GameState.current_floor == -1 and not _taken.has("05d_pause") and _scene_t > 3.2:
		var pm: PauseMenu = scene.get_node("PauseMenu")
		pm.pause()
		_taken["05d_pause"] = true
		await get_tree().process_frame
		await get_tree().process_frame
		_save_shot("05d_pause")
		if not get_tree().paused:
			print("SMOKE FAIL: pauza nu a oprit jocul")
			get_tree().quit(1)
		pm.resume()
		return
	# Jucătorul nu moare în restul testului
	GameState.player_hp = GameState.max_hp
	# lasă inamicii să tragă puțin, încearcă parry-uri
	if _scene_t < 2.5:
		if int(_scene_t * 10.0) % 4 == 0:
			player.parry()
		return
	var enemies: Node = scene.get("enemies")
	var projectiles: Node = scene.get("projectiles")
	_kills_spawned += get_process_delta_time()
	if _kills_spawned > 0.35:
		_kills_spawned = 0.0
		for e in enemies.get_children():
			if e is Enemy and not (e as Enemy).is_dead():
				var p := (Enemy.PROJECTILE_SCENE.instantiate() as Projectile)
				var from := (e as Enemy).global_position + Vector2(0, 70)
				p.setup(Projectile.Kind.ORB, Vector2.UP, 150.0)
				p.position = from
				projectiles.add_child(p)
				p.reflect((e as Enemy).global_position, randf() < 0.5)
	var exit_door: Trapdoor = scene.get("exit_door")
	if exit_door and exit_door.active:
		player.global_position = exit_door.global_position
	if bool(scene.get("_chest_ready")):
		player.global_position = Vector2(576, 270)
