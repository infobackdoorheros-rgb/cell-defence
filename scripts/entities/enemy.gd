extends Node2D
class_name Enemy

const EnemyData = preload("res://scripts/data/enemy_data.gd")

signal defeated(enemy, enemy_data, world_position: Vector2)
signal escaped(enemy, damage: float)
signal despawned(enemy)
signal children_requested(child_ids: PackedStringArray, world_position: Vector2)

var data: EnemyData
var core
var run_scene

var current_health: float = 1.0
var max_health: float = 1.0
var current_speed: float = 0.0

var _dash_cooldown_timer: float = 0.0
var _dash_time_remaining: float = 0.0
var _contact_cooldown_timer: float = 0.0
var _spawn_timer: float = 0.0
var _flash_timer: float = 0.0
var _is_dead: bool = false
var _visual_time: float = 0.0
var _visual_seed: float = 0.0

func initialize(enemy_data: EnemyData, core_ref, run_scene_ref, health_multiplier: float, speed_multiplier: float) -> void:
	data = enemy_data
	core = core_ref
	run_scene = run_scene_ref
	max_health = data.max_health * health_multiplier
	current_health = max_health
	current_speed = data.speed * speed_multiplier
	_dash_cooldown_timer = data.dash_cooldown
	_spawn_timer = data.spawn_children_interval
	_visual_seed = randf() * TAU
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _is_dead or run_scene == null or run_scene.is_gameplay_paused():
		return
	if core == null or not is_instance_valid(core) or core.is_dead():
		return

	_visual_time += delta
	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		queue_redraw()

	if data.regeneration_per_sec > 0.0 and current_health < max_health:
		current_health = min(max_health, current_health + (data.regeneration_per_sec * delta))

	if data.spawn_children_interval > 0.0 and data.spawn_children_count > 0 and not data.spawn_children_ids.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = data.spawn_children_interval
			var child_ids := PackedStringArray()
			for index in range(data.spawn_children_count):
				var child_id: String = data.spawn_children_ids[index % data.spawn_children_ids.size()]
				child_ids.append(child_id)
			children_requested.emit(child_ids, global_position)

	if _contact_cooldown_timer > 0.0:
		_contact_cooldown_timer -= delta

	var to_core: Vector2 = core.global_position - global_position
	var distance_to_core: float = to_core.length()
	var contact_distance: float = core.get_core_radius() + data.collision_radius
	if distance_to_core <= contact_distance:
		if _contact_cooldown_timer <= 0.0:
			_contact_cooldown_timer = data.contact_tick_cooldown
			escaped.emit(self, data.contact_damage)
			if data.contact_self_destruct:
				_despawn_without_rewards()
				return
		queue_redraw()
		return

	if data.dash_cooldown > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer <= 0.0:
			_dash_cooldown_timer = data.dash_cooldown
			_dash_time_remaining = data.dash_duration

	var move_speed: float = get_current_speed()
	if _dash_time_remaining > 0.0:
		_dash_time_remaining -= delta
		move_speed *= data.dash_multiplier

	move_speed *= core.get_enemy_speed_multiplier(global_position)
	if distance_to_core > 0.0:
		global_position += to_core.normalized() * move_speed * delta
		queue_redraw()

func take_damage(amount: float, is_critical: bool = false) -> void:
	if _is_dead:
		return

	current_health -= amount
	_flash_timer = 0.08 if is_critical else 0.04
	if current_health <= 0.0:
		_die()
	queue_redraw()

func get_current_speed() -> float:
	return current_speed

func get_collision_radius() -> float:
	return data.collision_radius

func get_family() -> StringName:
	return data.family

func get_tier() -> StringName:
	return data.tier

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clamp(current_health / max_health, 0.0, 1.0)

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if not data.split_children.is_empty():
		children_requested.emit(data.split_children, global_position)
	defeated.emit(self, data, global_position)
	queue_free()

func _despawn_without_rewards() -> void:
	if _is_dead:
		return
	_is_dead = true
	despawned.emit(self)
	queue_free()

func _draw() -> void:
	if data == null:
		return

	var base_radius: float = data.collision_radius * data.scale_multiplier
	var enemy_id: String = String(data.enemy_id)
	var pulse: float = 1.0 + (sin(_visual_time * 2.2 + _visual_seed) * 0.035)
	var body_color: Color = data.display_color
	if _flash_timer > 0.0:
		body_color = body_color.lightened(0.35)

	_draw_glow(Vector2(0.0, 4.0), base_radius * 1.65, Color(0.0, 0.0, 0.0, 0.12))

	if data.family == &"virus":
		var virus_radius: float = base_radius * pulse
		_draw_glow(Vector2.ZERO, virus_radius * 1.55, Color(body_color.r, body_color.g, body_color.b, 0.1))
		draw_circle(Vector2.ZERO, virus_radius, body_color)
		draw_circle(Vector2.ZERO, virus_radius * 0.72, body_color.lightened(0.14))
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var spike_length: float = base_radius + 7.0 + (sin((_visual_time * 5.0) + _visual_seed + index) * 1.8)
			var inner: Vector2 = Vector2.RIGHT.rotated(angle) * (virus_radius - 2.0)
			var outer: Vector2 = Vector2.RIGHT.rotated(angle) * spike_length
			draw_line(inner, outer, body_color.lightened(0.22), 3.0)
		draw_circle(Vector2.ZERO, virus_radius * 0.26, Color(1.0, 0.96, 0.94, 0.92))
		if enemy_id.contains("divider"):
			draw_circle(Vector2(-base_radius * 0.2, 1.0), base_radius * 0.15, Color(0.95, 0.9, 0.86, 0.8))
			draw_circle(Vector2(base_radius * 0.22, -1.0), base_radius * 0.15, Color(0.95, 0.9, 0.86, 0.8))
		if enemy_id.contains("dash"):
			var core_direction := Vector2.DOWN
			if core != null and is_instance_valid(core):
				core_direction = (core.global_position - global_position).normalized()
			var dash_tip := core_direction * (base_radius + 10.0)
			draw_line(Vector2.ZERO, dash_tip, Color(1.0, 0.88, 0.5, 0.65 + (_dash_time_remaining * 0.3)), 3.0)
	else:
		var left := Vector2(-base_radius * 0.58, 0.0)
		var right := Vector2(base_radius * 0.58, 0.0)
		var capsule_width: float = base_radius * 1.32 * pulse
		_draw_glow(Vector2.ZERO, base_radius * 1.75, Color(body_color.r, body_color.g, body_color.b, 0.08))
		draw_line(left, right, body_color, capsule_width)
		draw_circle(left, capsule_width * 0.5, body_color)
		draw_circle(right, capsule_width * 0.5, body_color)
		draw_line(left * 0.78, right * 0.78, body_color.darkened(0.2), capsule_width * 0.52)
		draw_circle(left * 0.78, capsule_width * 0.26, body_color.darkened(0.2))
		draw_circle(right * 0.78, capsule_width * 0.26, body_color.darkened(0.2))
		if enemy_id.contains("armored"):
			for armor_index in range(4):
				var stripe_x: float = lerp(left.x * 0.6, right.x * 0.6, float(armor_index) / 3.0)
				draw_line(Vector2(stripe_x, -base_radius * 0.56), Vector2(stripe_x, base_radius * 0.56), Color(0.86, 0.95, 0.92, 0.32), 2.0)
		if enemy_id.contains("regen"):
			draw_arc(Vector2.ZERO, base_radius + 5.0, 0.0, TAU, 20, Color(0.46, 0.98, 0.7, 0.28 + (sin(_visual_time * 4.0) * 0.08)), 2.0)
			draw_circle(Vector2.ZERO, 3.8, Color(0.6, 1.0, 0.8, 0.82))

	if data.tier == &"elite":
		draw_arc(Vector2.ZERO, base_radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.88, 0.45, 0.92), 4.0)
		for elite_index in range(6):
			var elite_angle: float = _visual_time * 0.55 + (TAU * float(elite_index) / 6.0)
			var elite_position := Vector2.RIGHT.rotated(elite_angle) * (base_radius + 8.0)
			draw_circle(elite_position, 2.1, Color(1.0, 0.87, 0.42, 0.62))
	elif data.tier == &"boss":
		_draw_glow(Vector2.ZERO, base_radius * 2.0, Color(0.74, 0.66, 1.0, 0.08))
		draw_arc(Vector2.ZERO, base_radius + 8.0, 0.0, TAU, 32, Color(0.72, 0.66, 1.0, 0.95), 5.0)
		draw_arc(Vector2.ZERO, base_radius + 15.0, 0.0, TAU, 32, Color(1.0, 0.56, 0.52, 0.3), 2.0)

	var ratio: float = get_health_ratio()
	var bar_width: float = base_radius * 2.25
	var bar_position := Vector2(-bar_width * 0.5, -base_radius - 16.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 5.0)), Color(0.1, 0.14, 0.18, 0.9), true)
	draw_rect(Rect2(bar_position, Vector2(bar_width * ratio, 5.0)), Color(0.35, 0.95, 0.62, 0.95), true)
	draw_rect(Rect2(bar_position - Vector2(1.5, 1.5), Vector2(bar_width + 3.0, 8.0)), Color(0.28, 0.9, 0.78, 0.16), false, 1.0)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var layer_t: float = float(layer) / 4.0
		draw_circle(center, radius * layer_t, Color(color.r, color.g, color.b, color.a * layer_t))
