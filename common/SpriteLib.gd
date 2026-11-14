class_name SpriteLib
extends RefCounted
## Construiește SpriteFrames din PNG-urile 16x16 din assets/sprites.
## 0x72 Dungeon Tileset II (CC0) + Kenney Tiny Dungeon (CC0). Vezi CREDITS.md.
## Fiecare personaj are cel puțin animațiile "idle" și "run".

const X72 := "res://assets/sprites/0x72/"
const KEN := "res://assets/sprites/kenney/"

const VILLAGERS: Array[String] = ["villager_1", "villager_2", "villager_3", "villager_4", "villager_5", "villager_6"]

static var _cache: Dictionary = {}


static func frames(character_id: String) -> SpriteFrames:
	if _cache.has(character_id):
		return _cache[character_id]
	var sf: SpriteFrames
	match character_id:
		"knight":
			sf = _build({
				"idle": _seq("knight_m_idle_anim", 4),
				"run": _seq("knight_m_run_anim", 4),
				"hit": [X72 + "knight_m_hit_anim_f0.png"],
			}, 9.0)
		"skeleton":
			sf = _build({"idle": _seq("skelet_idle_anim", 4), "run": _seq("skelet_run_anim", 4)}, 8.0)
		"necromancer":
			sf = _build({"idle": _seq("necromancer_anim", 4), "run": _seq("necromancer_anim", 4)}, 7.0)
		"demon":
			sf = _build({"idle": _seq("big_demon_idle_anim", 4), "run": _seq("big_demon_run_anim", 4)}, 7.0)
		"chest":
			sf = _build({"idle": [X72 + "chest_full_open_anim_f0.png"], "open": _seq("chest_full_open_anim", 3)}, 6.0)
			sf.set_animation_loop("open", false)
		"coin":
			sf = _build({"idle": _seq("coin_anim", 4), "run": _seq("coin_anim", 4)}, 10.0)
		"ghost":
			sf = _single(KEN + "tile_0121.png")
		"spirit":
			sf = _single(KEN + "tile_0108.png")
		"phantom_knight", "royal_knight_visor":
			sf = _single(KEN + "tile_0097.png")
		"royal_knight":
			sf = _single(KEN + "tile_0096.png")
		"king_old":
			sf = _single(KEN + "tile_0084.png")
		"king_young":
			sf = _single(KEN + "tile_0085.png")
		"villager_1":
			sf = _single(KEN + "tile_0086.png")
		"villager_2":
			sf = _single(KEN + "tile_0087.png")
		"villager_3":
			sf = _single(KEN + "tile_0088.png")
		"villager_4":
			sf = _single(KEN + "tile_0098.png")
		"villager_5":
			sf = _single(KEN + "tile_0099.png")
		"villager_6":
			sf = _single(KEN + "tile_0100.png")
		_:
			push_warning("SpriteLib: personaj necunoscut '%s', folosesc knight" % character_id)
			return frames("knight")
	_cache[character_id] = sf
	return sf


static func texture(file_name: String) -> Texture2D:
	## file_name relativ la assets/sprites/, ex: "0x72/flask_big_red.png"
	return load("res://assets/sprites/" + file_name) as Texture2D


static func _seq(base: String, count: int) -> Array[String]:
	var out: Array[String] = []
	for i in count:
		out.append("%s%s_f%d.png" % [X72, base, i])
	return out


static func _single(path: String) -> SpriteFrames:
	return _build({"idle": [path], "run": [path]}, 1.0)


static func _build(anims: Dictionary, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim_name: String in anims:
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, true)
		for path: String in anims[anim_name]:
			var tex := load(path) as Texture2D
			if tex:
				sf.add_frame(anim_name, tex)
			else:
				push_error("SpriteLib: lipsește %s" % path)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	return sf
