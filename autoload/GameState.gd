extends Node
## Autoload global (Project Settings > Autoload, nume: GameState).
## Ține starea poveștii, progresia etajelor (0 -> -1..-50 -> 0 -> +1 -> +2),
## tranzițiile între scene, hitstop, screen shake și efectele sonore procedurale.
## NOTĂ: nu are class_name (ar intra în conflict cu numele autoload-ului).

signal hp_changed(hp: int, max_hp: int)
signal floor_changed(floor_num: int)
signal coins_changed(total: int)
signal tips_toggled(enabled: bool)

# --- Scene -----------------------------------------------------------------
const SCENE_INTRO := "res://scenes/IntroGates.tscn"
const SCENE_MIRROR := "res://scenes/MirrorRoom.tscn"
const SCENE_MAP := "res://scenes/CastleMap.tscn"
const SCENE_DUNGEON := "res://scenes/DungeonFloor.tscn"
const SCENE_THRONE := "res://scenes/ThroneEnding.tscn"
const SCENE_MENU := "res://scenes/MainMenu.tscn"

# --- Muzică ------------------------------------------------------------------
const MUSIC_NORMAL_PATH := "res://assets/audio/normal_loop.mp3"
const MUSIC_BOSS_PATH := "res://assets/audio/boss_loop.mp3"
const MUSIC_POSTFIGHT_PATH := "res://assets/audio/postfight.mp3"
const MUSIC_FINAL_STING_PATH := "res://assets/audio/final_boss_sting.mp3"

# --- Paletă (Tomb of the Mask + FNaF 4) -------------------------------------
const COL_BG := Color("#07050c")
const COL_MAGENTA := Color("#ff00ff")
const COL_GOLD := Color("#ffe600")
const COL_FLOOR_A := Color("#0e1b33")
const COL_FLOOR_B := Color("#152647")
const COL_WALL := Color("#140a22")
const COL_CYAN := Color("#3df5ff")
const COL_RED := Color("#ff2a4d")
const COL_TEXT := Color("#f2e9ff")

# --- Straturi de fizică (bitmask, vezi Project Settings > Layer Names) ------
const LAYER_PLAYER := 1        # layer 1
const LAYER_ENEMIES := 2       # layer 2
const LAYER_WALLS := 4         # layer 3
const LAYER_PROJECTILES := 8   # layer 4

# --- Etaje -------------------------------------------------------------------
const DEEPEST_FLOOR := -50
const TOP_FLOOR := 2
## Cele 5 capitole (câte 10 subsoluri): 9 etaje cu inamicii capitolului + boss-ul la final.
const ZONES: Array[Dictionary] = [
	{"name": "Ghost Crypt", "enemies": "Ghosts", "boss": "Great Crypt Spirit", "boss_hp": 10},
	{"name": "Spirit Catacombs", "enemies": "Spirits", "boss": "Eyeless Oracle", "boss_hp": 13},
	{"name": "Skeleton Ossuary", "enemies": "Skeleton Archers", "boss": "Bone Commander", "boss_hp": 16},
	{"name": "Corrupted Barracks", "enemies": "Phantom Knights", "boss": "Fallen Royal Guard", "boss_hp": 20},
	{"name": "Book Abyss", "enemies": "All Shadows", "boss": "Book's Dark Avatar", "boss_hp": 25},
]

# --- Magazin (ecranul de acasă) ---------------------------------------------
## Scuturile „țin mai mult”: fereastra de parry e mai lungă și cooldown-ul la ratare mai scurt.
const SHIELDS: Array[Dictionary] = [
	{"id": "shield_wood", "name": "Wooden Shield", "price": 0, "window": 0.15, "perfect": 0.05,
		"cooldown": 0.5, "color": Color("#ffe600"), "desc": "Parry 0.15s · cooldown 0.5s"},
	{"id": "shield_iron", "name": "Iron Shield", "price": 150, "window": 0.18, "perfect": 0.055,
		"cooldown": 0.4, "color": Color("#c8d6e5"), "desc": "Parry 0.18s · cooldown 0.4s"},
	{"id": "shield_gold", "name": "Golden Shield", "price": 600, "window": 0.21, "perfect": 0.06,
		"cooldown": 0.32, "color": Color("#ffb300"), "desc": "Parry 0.21s · cooldown 0.32s · wider PERFECT"},
	{"id": "shield_royal", "name": "King's Shield", "price": 1500, "window": 0.25, "perfect": 0.07,
		"cooldown": 0.25, "color": Color("#7ff3ff"), "desc": "Parry 0.25s · cooldown 0.25s · widest PERFECT"},
]
## Armurile sunt doar cosmetice (nu schimbă nimic în luptă).
const ARMORS: Array[Dictionary] = [
	{"id": "armor_classic", "name": "Classic Armor", "price": 0, "look": "knight", "tint": Color(1, 1, 1),
		"desc": "The armor you arrived in."},
	{"id": "armor_gold", "name": "Golden Armor", "price": 200, "look": "knight", "tint": Color(1.0, 0.85, 0.35),
		"desc": "Shines like the Royal Treasure."},
	{"id": "armor_shadow", "name": "Shadow Armor", "price": 200, "look": "knight", "tint": Color(0.6, 0.5, 0.9),
		"desc": "Forged from a defeated shadow."},
	{"id": "armor_frost", "name": "Frost Armor", "price": 350, "look": "knight", "tint": Color(0.6, 0.95, 1.0),
		"desc": "Cold as the crypt's breath."},
	{"id": "armor_neon", "name": "Neon Armor", "price": 350, "look": "knight", "tint": Color(1.0, 0.45, 1.0),
		"desc": "Glows like the magenta beam."},
	{"id": "armor_valkyrie", "name": "Valkyrie Armor", "price": 800, "look": "knight_f", "tint": Color(1, 1, 1),
		"desc": "A whole new look, with a red ponytail."},
]
const DEFAULT_ITEMS: Array[String] = ["shield_wood", "armor_classic"]
const SAVE_VERSION := 2

# --- Economia monedelor --------------------------------------------------------
## Un etaj curățat plătește 10 × capitol (10 … 50), un boss 100 × capitol (100 … 500).
## Bonusuri: +2 pentru fiecare PERFECT (max. +20), +50% dacă nu ai fost lovit deloc.
## Comoara de la -50: 500. O tură completă aduce ~3 400 – 4 000 de monede;
## tot magazinul costă 4 150, deci o tură + câteva rejucări cumpără tot.
## Rejucarea unui etaj deja terminat plătește jumătate (prima terminare plătește tot).
const COINS_FLOOR := 10
const COINS_BOSS := 100
const COINS_PER_PERFECT := 2
const COINS_PERFECT_CAP := 20
const FLAWLESS_BONUS := 0.5
const COINS_TREASURE := 500
const REPLAY_REPEAT_FACTOR := 0.5

## 1 = toate cele 50 de subsoluri pe rând (-1, -2, -3 ... -50).
## 5 = „Puțuri Abisale” pentru o sesiune scurtă (-1, -5, -10 ... -50).
var floor_step: int = 1

# --- Starea poveștii ---------------------------------------------------------
var player_name: String = "Knight"
var current_floor: int = 0
var target_floor: int = 0
var max_hp: int = 3
var player_hp: int = 3
var mirror_visit: int = 1          # 1 = prima vizită, 2 = întoarcerea cu Poțiunea
var has_potion: bool = false
var has_crown: bool = false
var seen_tips: Array[String] = []   # sfaturile unice ale fantomei deja spuse în această tură

# --- Progres permanent (rămâne între ture) ----------------------------------
var coins: int = 0
var owned_items: Array[String] = ["shield_wood", "armor_classic"]
var equipped_shield: String = "shield_wood"
var equipped_armor: String = "armor_classic"
var tips_enabled: bool = true
var deepest_reached: int = 1          # cel mai adânc subsol atins (1 … 50): deblochează nivelele
var cleared_floors: Array[int] = []   # subsolurile terminate măcar o dată (adâncimi pozitive)

# --- Rejucarea unui nivel (meniul LEVELS) ------------------------------------
## În modul replay se joacă un singur etaj; tura salvată rămâne neatinsă.
var replay_mode: bool = false
var replay_floor: int = 0
var open_levels_on_menu: bool = false
var _replay_snapshot: Dictionary = {}

# --- Salvare -------------------------------------------------------------------
## Fișierul de salvare (pe Web: IndexedDB-ul browserului). Testele folosesc alt fișier.
var save_path: String = "user://forbidden_redemption.save"
var run_active: bool = false   # există o tură începută care poate fi continuată
var resume_floor: int = 0      # de unde continuă tura (începutul etajului)

# --- Statistici (afișate la final) ------------------------------------------
var kills: int = 0
var parries: int = 0
var perfect_parries: int = 0
var bounce_backs: int = 0
var deaths: int = 0
var run_coins: int = 0
var run_start_msec: int = 0

# --- Intern -------------------------------------------------------------------
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning := false
var _hitstop_token := 0
var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_player: AudioStreamPlayer
var _sting_player: AudioStreamPlayer
var _current_music := ""
var _final_sting_played := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_build_fade_layer()
	_build_sfx()
	_build_music()
	run_start_msec = Time.get_ticks_msec()
	load_game()


func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = -14.0
	add_child(_music_player)
	_sting_player = AudioStreamPlayer.new()
	_sting_player.name = "FinalBossStingPlayer"
	_sting_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_sting_player.volume_db = -8.0
	add_child(_sting_player)


func play_music(track: String) -> void:
	if track == _current_music:
		return
	var path := ""
	match track:
		"normal": path = MUSIC_NORMAL_PATH
		"boss": path = MUSIC_BOSS_PATH
		"postfight": path = MUSIC_POSTFIGHT_PATH
		_: return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		push_warning("Could not load music: %s" % path)
		return
	stream.loop = track != "postfight"
	_music_player.stream = stream
	_music_player.play()
	_current_music = track


func play_final_boss_sting() -> void:
	if _final_sting_played:
		return
	var stream := load(MUSIC_FINAL_STING_PATH) as AudioStreamMP3
	if stream == null:
		push_warning("Could not load final boss sting: %s" % MUSIC_FINAL_STING_PATH)
		return
	_final_sting_played = true
	_sting_player.stream = stream
	_sting_player.play()


# =============================================================================
#  Etaje și zone
# =============================================================================
func zone_index(floor_num: int) -> int:
	if floor_num >= 0:
		return -1
	return clampi(floori((absi(floor_num) - 1) / 10.0), 0, ZONES.size() - 1)


func is_boss_floor(floor_num: int) -> bool:
	return floor_num < 0 and absi(floor_num) % 10 == 0


func boss_index(floor_num: int) -> int:
	## 1..5 pentru -10, -20, -30, -40, -50; 0 dacă nu e etaj de boss.
	return zone_index(floor_num) + 1 if is_boss_floor(floor_num) else 0


func next_floor_down(from_floor: int) -> int:
	if from_floor >= 0:
		return -1
	var depth := absi(from_floor)
	var next_depth := (floori(depth / float(floor_step)) + 1) * floor_step
	return -mini(next_depth, absi(DEEPEST_FLOOR))


func enemy_types_for_floor(floor_num: int) -> Array[int]:
	## 0 Fantomă, 1 Spirit, 2 Schelet Arcaș, 3 Cavaler Fantomă (vezi Enemy.Type).
	var z := zone_index(floor_num)
	var types: Array[int] = []
	if z >= 4:
		types.assign([0, 1, 2, 3])
	else:
		types.append(maxi(z, 0))
	return types


func chapter_number(floor_num: int) -> int:
	## 1..5 (capitolul = zona de 10 subsoluri)
	return zone_index(floor_num) + 1


func chapter_floor(floor_num: int) -> int:
	## Al câtelea etaj din capitol: 1..10 (10 = boss).
	return (absi(floor_num) - 1) % 10 + 1


func is_chapter_start(floor_num: int) -> bool:
	return floor_num < 0 and chapter_floor(floor_num) == 1


func enemy_count_for_floor(floor_num: int) -> int:
	## Crește în interiorul capitolului: etajele 1-3 / 4-6 / 7-9.
	if floor_num == -1:
		return 1  # primul etaj = tutorial
	var z := zone_index(floor_num)
	var base: int = [1, 2, 2, 2, 3][z]
	var ramp := floori((chapter_floor(floor_num) - 1) / 3.0)
	return mini(base + ramp, 5)


func floor_difficulty(floor_num: int) -> float:
	## Multiplicator de ritm pentru inamici: 1.0 la începutul capitolului, ~1.3 la etajul 9.
	if floor_num >= 0 or is_boss_floor(floor_num):
		return 1.0
	return 1.0 + 0.035 * (chapter_floor(floor_num) - 1)


func floor_short(floor_num: int) -> String:
	if floor_num > 0:
		return "FLOOR +%d" % floor_num
	if floor_num == 0:
		return "GROUND FLOOR 0"
	return "DUNGEON FLOOR %d" % floor_num


func floor_name(floor_num: int) -> String:
	match floor_num:
		2:
			return "Throne Room"
		1:
			return "Royal Gallery"
		0:
			return "Mirror Hall"
	var z := zone_index(floor_num)
	if is_boss_floor(floor_num):
		return "BOSS: %s" % ZONES[z]["boss"]
	return String(ZONES[z]["name"])


func floor_title(floor_num: int) -> String:
	return "%s  ·  %s" % [floor_short(floor_num), floor_name(floor_num)]


# =============================================================================
#  Fluxul poveștii
# =============================================================================
func travel_to(target: int) -> void:
	## Trece prin harta castelului (CastleMap) spre etajul țintă.
	target_floor = target
	change_scene(SCENE_MAP)


func arrive() -> void:
	## Apelată de CastleMap la finalul animației: intră în scena etajului.
	current_floor = target_floor
	floor_changed.emit(current_floor)
	if current_floor < 0:
		change_scene(SCENE_DUNGEON)
	elif current_floor == 0:
		change_scene(SCENE_MIRROR)
	else:
		change_scene(SCENE_THRONE)


func collect_treasure() -> void:
	has_potion = true
	has_crown = true
	mirror_visit = 2


# =============================================================================
#  Ture: joc nou / continuă / checkpoint (ecranul de acasă + salvare)
# =============================================================================
func new_run() -> void:
	reset_run()
	run_active = true
	resume_floor = 0
	save_game()
	change_scene(SCENE_INTRO)


func continue_scene() -> String:
	## Scena din care continuă tura salvată.
	if resume_floor < 0:
		return SCENE_DUNGEON
	if resume_floor == 0:
		return SCENE_MIRROR
	return SCENE_THRONE


func continue_run() -> void:
	current_floor = resume_floor
	target_floor = resume_floor
	hp_changed.emit(player_hp, max_hp)
	change_scene(continue_scene())


func checkpoint(floor_num: int) -> void:
	## Salvează tura: „Continue” va porni de la începutul acestui etaj.
	mark_reached(floor_num)
	if replay_mode:
		save_game()   # în rejucare se salvează doar monedele / deblocările
		return
	run_active = true
	resume_floor = floor_num
	save_game()


func finish_run() -> void:
	run_active = false
	resume_floor = 0
	save_game()


func go_home(open_levels: bool = false) -> void:
	## Ecranul de acasă (din pauză, Game Over, final sau după o rejucare).
	open_levels_on_menu = open_levels
	end_replay()
	get_tree().paused = false
	change_scene(SCENE_MENU)


# =============================================================================
#  Nivele: deblocare + rejucare
# =============================================================================
func mark_reached(floor_num: int) -> void:
	if floor_num < 0:
		deepest_reached = clampi(maxi(deepest_reached, absi(floor_num)), 1, absi(DEEPEST_FLOOR))


func mark_cleared(floor_num: int) -> void:
	if floor_num < 0 and not cleared_floors.has(absi(floor_num)):
		cleared_floors.append(absi(floor_num))


func is_unlocked(floor_num: int) -> bool:
	return floor_num < 0 and absi(floor_num) <= deepest_reached


func is_cleared(floor_num: int) -> bool:
	return cleared_floors.has(absi(floor_num))


func start_replay(floor_num: int) -> void:
	## Rejoacă un subsol deja atins. Tura salvată se păstrează și revine după.
	if not is_unlocked(floor_num) or is_transitioning():
		return
	if not replay_mode:
		_replay_snapshot = _run_dict()
	replay_mode = true
	replay_floor = floor_num
	current_floor = floor_num
	target_floor = floor_num
	player_hp = max_hp
	hp_changed.emit(player_hp, max_hp)
	change_scene(SCENE_DUNGEON)


func end_replay() -> void:
	if not replay_mode:
		return
	replay_mode = false
	replay_floor = 0
	_apply_run(_replay_snapshot)
	_replay_snapshot = {}
	save_game()


# =============================================================================
#  Monede și magazin
# =============================================================================
func floor_reward(floor_num: int) -> int:
	## Recompensa de bază: 10 × capitol pentru un etaj, 100 × capitol pentru un boss.
	var chapter := maxi(chapter_number(floor_num), 1)
	if is_boss_floor(floor_num):
		return COINS_BOSS * chapter
	return COINS_FLOOR * chapter


func clear_reward(floor_num: int, perfects: int, flawless: bool, repeat: bool) -> Dictionary:
	## Toată recompensa pentru o cameră curățată (bază + PERFECT + fără lovituri),
	## înjumătățită când rejoci un etaj deja terminat.
	var base := floor_reward(floor_num)
	var perfect_bonus := mini(maxi(perfects, 0) * COINS_PER_PERFECT, COINS_PERFECT_CAP)
	var flawless_bonus := roundi(base * FLAWLESS_BONUS) if flawless else 0
	var total := base + perfect_bonus + flawless_bonus
	if repeat:
		total = ceili(total * REPLAY_REPEAT_FACTOR)
	return {"base": base, "perfect": perfect_bonus, "flawless": flawless_bonus, "total": total, "repeat": repeat}


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	run_coins += maxi(amount, 0)
	coins_changed.emit(coins)


func item_data(id: String) -> Dictionary:
	for it in SHIELDS:
		if it["id"] == id:
			return it
	for it in ARMORS:
		if it["id"] == id:
			return it
	return {}


func is_shield(id: String) -> bool:
	return id.begins_with("shield_")


func owns(id: String) -> bool:
	return owned_items.has(id)


func is_equipped(id: String) -> bool:
	return id == equipped_shield or id == equipped_armor


func buy(id: String) -> bool:
	var it := item_data(id)
	if it.is_empty() or owns(id) or coins < int(it["price"]):
		return false
	coins -= int(it["price"])
	owned_items.append(id)
	coins_changed.emit(coins)
	play_sfx("buy", false)
	equip(id)
	return true


func equip(id: String) -> void:
	if not owns(id):
		return
	if is_shield(id):
		equipped_shield = id
	else:
		equipped_armor = id
	save_game()


func shield_stats() -> Dictionary:
	var it := item_data(equipped_shield)
	return it if not it.is_empty() else SHIELDS[0]


func armor_data() -> Dictionary:
	var it := item_data(equipped_armor)
	return it if not it.is_empty() else ARMORS[0]


func set_tips_enabled(enabled: bool) -> void:
	tips_enabled = enabled
	tips_toggled.emit(enabled)
	save_game()


# =============================================================================
#  Salvare / încărcare (JSON în user://)
# =============================================================================
func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"meta": _meta_dict(),
		# în timpul unei rejucări se salvează tura păstrată, nu etajul rejucat
		"run": _replay_snapshot if replay_mode else _run_dict(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: nu pot salva în %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	_apply_meta(d.get("meta", {}))
	_apply_run(d.get("run", {}))
	# salvări vechi (fără „deepest”): deblochează cel puțin etajul din tura salvată
	mark_reached(resume_floor)
	return true


func _meta_dict() -> Dictionary:
	return {
		"coins": coins, "owned": owned_items, "shield": equipped_shield,
		"armor": equipped_armor, "tips": tips_enabled,
		"deepest": deepest_reached, "cleared": cleared_floors,
	}


func _apply_meta(meta: Dictionary) -> void:
	coins = int(meta.get("coins", 0))
	owned_items.clear()
	for id: Variant in meta.get("owned", []):
		if not item_data(String(id)).is_empty() and not owned_items.has(String(id)):
			owned_items.append(String(id))
	for id in DEFAULT_ITEMS:
		if not owned_items.has(id):
			owned_items.append(id)
	equipped_shield = String(meta.get("shield", "shield_wood"))
	equipped_armor = String(meta.get("armor", "armor_classic"))
	if not owns(equipped_shield):
		equipped_shield = "shield_wood"
	if not owns(equipped_armor):
		equipped_armor = "armor_classic"
	tips_enabled = bool(meta.get("tips", true))
	deepest_reached = clampi(int(meta.get("deepest", 1)), 1, absi(DEEPEST_FLOOR))
	cleared_floors.clear()
	for c: Variant in meta.get("cleared", []):
		var depth := int(c)
		if depth >= 1 and depth <= absi(DEEPEST_FLOOR) and not cleared_floors.has(depth):
			cleared_floors.append(depth)


func _run_dict() -> Dictionary:
	return {
		"active": run_active, "name": player_name, "floor": resume_floor, "hp": player_hp,
		"mirror_visit": mirror_visit, "potion": has_potion, "crown": has_crown,
		"floor_step": floor_step, "seen_tips": seen_tips.duplicate(),
		"kills": kills, "parries": parries, "perfect": perfect_parries,
		"bounce_backs": bounce_backs, "deaths": deaths, "coins_earned": run_coins,
		"current": current_floor, "time_ms": Time.get_ticks_msec() - run_start_msec,
	}


func _apply_run(run: Dictionary) -> void:
	run_active = bool(run.get("active", false))
	player_name = String(run.get("name", player_name))
	resume_floor = clampi(int(run.get("floor", 0)), DEEPEST_FLOOR, TOP_FLOOR)
	current_floor = clampi(int(run.get("current", resume_floor)), DEEPEST_FLOOR, TOP_FLOOR)
	target_floor = current_floor
	player_hp = clampi(int(run.get("hp", max_hp)), 1, max_hp)
	mirror_visit = int(run.get("mirror_visit", 1))
	has_potion = bool(run.get("potion", false))
	has_crown = bool(run.get("crown", false))
	floor_step = clampi(int(run.get("floor_step", floor_step)), 1, 10)
	seen_tips.clear()
	for t: Variant in run.get("seen_tips", []):
		seen_tips.append(String(t))
	kills = int(run.get("kills", 0))
	parries = int(run.get("parries", 0))
	perfect_parries = int(run.get("perfect", 0))
	bounce_backs = int(run.get("bounce_backs", 0))
	deaths = int(run.get("deaths", 0))
	run_coins = int(run.get("coins_earned", 0))
	run_start_msec = Time.get_ticks_msec() - int(run.get("time_ms", 0))
	hp_changed.emit(player_hp, max_hp)


func reset_run() -> void:
	current_floor = 0
	target_floor = 0
	player_hp = max_hp
	mirror_visit = 1
	has_potion = false
	has_crown = false
	seen_tips.clear()
	kills = 0
	parries = 0
	perfect_parries = 0
	bounce_backs = 0
	deaths = 0
	run_coins = 0
	run_start_msec = Time.get_ticks_msec()
	hp_changed.emit(player_hp, max_hp)


@warning_ignore("integer_division")
func run_time_text() -> String:
	var secs := (Time.get_ticks_msec() - run_start_msec) / 1000
	return "%02d:%02d" % [secs / 60, secs % 60]


# =============================================================================
#  Viața jucătorului (sursa unică de adevăr, persistă între etaje)
# =============================================================================
func damage_player(amount: int) -> void:
	player_hp = maxi(player_hp - amount, 0)
	hp_changed.emit(player_hp, max_hp)


func heal_player(amount: int) -> void:
	player_hp = mini(player_hp + amount, max_hp)
	hp_changed.emit(player_hp, max_hp)


func restore_full_hp() -> void:
	player_hp = max_hp
	hp_changed.emit(player_hp, max_hp)


# =============================================================================
#  Juice: hitstop + screen shake
# =============================================================================
func hitstop(duration: float, time_scale: float = 0.05) -> void:
	# Token: doar ultimul hitstop pornit readuce timpul la normal (hitstop-uri suprapuse).
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	# ignore_time_scale = true -> timerul curge în timp real
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.call("shake", amount)


# =============================================================================
#  Tranziții între scene (fade negru, peste el rămân scanline-urile CRT)
# =============================================================================
func change_scene(path: String, fade_time: float = 0.35) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", 1.0, fade_time)
	await t.finished
	_hitstop_token += 1
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade_rect, "color:a", 0.0, fade_time)
	await t2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func is_transitioning() -> bool:
	return _transitioning


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 90
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(COL_BG, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


# =============================================================================
#  SFX procedurale (fără fișiere audio; merg și pe Web după primul click)
# =============================================================================
func play_sfx(sfx_name: String, pitch_variation: bool = true, volume_db: float = -8.0) -> void:
	if not _sfx.has(sfx_name) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.pitch_scale = randf_range(0.9, 1.2) if pitch_variation else 1.0
	p.volume_db = volume_db
	p.play()


func _build_sfx() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	#                     f_start f_end  durată  zgomot  undă
	_sfx["swing"] = _tone(520.0, 300.0, 0.06, 0.55, "square")
	_sfx["parry"] = _tone(900.0, 1400.0, 0.09, 0.05, "square")
	_sfx["perfect"] = _tone(1300.0, 2600.0, 0.16, 0.0, "square")
	_sfx["bounce"] = _tone(700.0, 1100.0, 0.05, 0.0, "sine")
	_sfx["shoot"] = _tone(380.0, 220.0, 0.07, 0.25, "saw")
	_sfx["hit"] = _tone(260.0, 90.0, 0.10, 0.45, "square")
	_sfx["hurt"] = _tone(200.0, 60.0, 0.25, 0.6, "saw")
	_sfx["die"] = _tone(320.0, 40.0, 0.35, 0.7, "square")
	_sfx["heal"] = _tone(600.0, 1500.0, 0.3, 0.0, "sine")
	_sfx["gate"] = _tone(90.0, 40.0, 0.9, 0.8, "saw")
	_sfx["magic"] = _tone(400.0, 1800.0, 0.6, 0.1, "sine")
	_sfx["slam"] = _tone(140.0, 30.0, 0.5, 0.9, "square")
	_sfx["blip"] = _tone(880.0, 880.0, 0.025, 0.0, "square")
	_sfx["coin"] = _tone(1200.0, 1900.0, 0.12, 0.0, "square")
	_sfx["buy"] = _tone(500.0, 1500.0, 0.25, 0.0, "sine")
	_sfx["scratch"] = _tone(2600.0, 1400.0, 0.07, 0.85, "saw")


func _tone(f0: float, f1: float, duration: float, noise: float, wave: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += lerpf(f0, f1, t) / float(rate)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				s = fmod(phase, 1.0) * 2.0 - 1.0
			_:
				s = sin(TAU * phase)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := (1.0 - t) * minf(1.0, t * 60.0)
		data.encode_s16(i * 2, int(clampf(s * env * 0.4, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
