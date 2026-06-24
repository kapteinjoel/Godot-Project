extends Control

@export var particle_colors: Array[Color] = [
	Color(0.6, 0.0, 1.0, 1.0),
	Color(0.809, 0.444, 1.0, 1.0),
	Color(1.0, 0.302, 1.0, 1.0)
]
@export var spawn_rate: float = 0.1
@export var max_particles: int = 1000
@export var drift_speed: float = 25.0
@export var lifetime: float = 4.0
@export var particle_size: float = 4.0

var _spawn_timer: float = 0.0

var _light_texture: GradientTexture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_light_texture = GradientTexture2D.new()
	_light_texture.gradient = gradient
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5, 0.5)
	_light_texture.fill_to = Vector2(1.0, 0.5)
	_light_texture.width = 13
	_light_texture.height = 13

func _process(delta: float) -> void:
	if spawn_rate == 0.0:
		# Fill up to max every frame
		while get_child_count() < max_particles:
			_spawn_particle()
	else:
		_spawn_timer += delta
		while _spawn_timer >= spawn_rate and get_child_count() < max_particles:
			_spawn_timer -= spawn_rate
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			_spawn_particle()
			

func _spawn_particle() -> void:
	var particle = Node2D.new()
	var chosen_color = particle_colors[randi() % particle_colors.size()]

	# Large soft glow halo
	var glow = Sprite2D.new()
	glow.texture = _light_texture
	glow.scale = Vector2(particle_size * 0.3, particle_size * 0.3)
	var glow_mat = CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_mat
	glow.modulate = Color(chosen_color.r, chosen_color.g, chosen_color.b, 0.0)
	particle.add_child(glow)
	
	# Small bright core
	var core = Sprite2D.new()
	var square_img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	square_img.fill(Color(1, 1, 1, 1))
	core.texture = ImageTexture.create_from_image(square_img)
	core.scale = Vector2(particle_size * 0.15, particle_size * 0.15)
	var core_mat = CanvasItemMaterial.new()
	core_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core.material = core_mat
	core.modulate = Color(chosen_color.r, chosen_color.g, chosen_color.b, 0.0)
	particle.add_child(core)
	
	add_child(particle)
	
	var this_lifetime = randf_range(lifetime * 0.5, lifetime * 1.5)
	
	var viewport_size = get_viewport().get_visible_rect().size
	particle.position = Vector2(
		randf_range(0, viewport_size.x),
		randf_range(0, viewport_size.y)
	)
	
	var drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var end_pos = particle.position + drift_dir * drift_speed * this_lifetime
	
	var perp = Vector2(-drift_dir.y, drift_dir.x)
	var bob_speed = randf_range(0.8, 2.0)
	var bob_tween = create_tween().set_loops()
	bob_tween.tween_property(particle, "position", particle.position + perp * 15.0, bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(particle, "position", particle.position - perp * 15.0, bob_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.05, this_lifetime * 0.3)
	tween.tween_property(glow, "modulate:a", 0.0, this_lifetime * 0.4).set_delay(this_lifetime * 0.6)
	tween.tween_property(core, "modulate:a", 1.0, this_lifetime * 0.3)
	tween.tween_property(core, "modulate:a", 0.0, this_lifetime * 0.4).set_delay(this_lifetime * 0.6)
	tween.tween_property(particle, "position", end_pos, this_lifetime)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_SINE)
	
	var on_expire = func():
		if is_instance_valid(bob_tween):
			bob_tween.kill()
		if is_instance_valid(particle):
			particle.queue_free()
	get_tree().create_timer(this_lifetime + 0.1).timeout.connect(on_expire)
