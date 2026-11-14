class_name FX
extends RefCounted
## Efecte one-shot reutilizabile: explozii de particule (CPUParticles2D, sigure pe Web)
## și texte plutitoare („PERFECT!”, „BOUNCE BACK!”).


static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 16,
		speed: float = 160.0, lifetime: float = 0.45, size: float = 3.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.z_index = 20
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.4, false).timeout.connect(p.queue_free)


static func popup(parent: Node, pos: Vector2, text: String, color: Color, font_size: int = 22) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 40
	label.size = Vector2(320, 40)
	parent.add_child(label)
	label.global_position = pos - Vector2(160, 40)
	label.pivot_offset = Vector2(160, 20)
	label.scale = Vector2(0.6, 0.6)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "position:y", label.position.y - 36.0, 0.8)
	t.tween_property(label, "modulate:a", 0.0, 0.25)
	t.tween_callback(label.queue_free)


static func flash_screen(parent: Node, color: Color = Color.WHITE, duration: float = 0.5, layer: int = 60) -> Tween:
	## Flash full-screen (ex: Oglinda strălucește orbitor). Returnează tween-ul de fade-out.
	var cl := CanvasLayer.new()
	cl.layer = layer
	parent.add_child(cl)
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	t.tween_callback(cl.queue_free)
	return t
