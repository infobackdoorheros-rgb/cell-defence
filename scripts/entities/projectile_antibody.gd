extends Node2D
class_name ProjectileAntibody

const Enemy = preload("res://scripts/entities/enemy.gd")
const RunStats = preload("res://scripts/core/run_stats.gd")

var target: Enemy
var wave_manager
var run_scene
var stats_snapshot: RunStats
var direction: Vector2 = Vector2.RIGHT
var speed: float = 560.0
var distance_traveled: float = 0.0
var radius: float = 7.0
var remaining_pierce: int = 0
var remaining_bounces: int = 0

var _rng := RandomNumberGenerator.new()
var _trail_points: Array[Vector2] = []
var _hit_instance_ids: Array[int] = []
var _visual_time: float = 0.0

func _ready() -> void:
	_rng.randomize()

func initialize(start_position: Vector2, target_ref: Enemy, initial_direction: Vector2, stats: RunStats, wave_manager_ref, run_scene_ref) -> void:
	global_position = start_position
	target = target_ref
	wave_manager = wave_manager_ref
	run_scene = run_scene_ref
	stats_snapshot = stats.clone()
	speed = stats_snapshot.projectile_speed
	remaining_pierce = stats_snapshot.pierce_count
	remaining_bounces = stats_snapshot.bounce_targets
	if initial_direction.length() > 0.0:
		direction = initial_direction.normalized()
	elif target != null and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
	_trail_points.clear()
	_hit_instance_ids.clear()
	_record_trail_point()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if run_scene != null and run_scene.is_gameplay_paused():
		return
	if stats_snapshot == null:
		queue_free()
		return

	if target != null and is_instance_valid(target):
		var desired_direction: Vector2 = (target.global_position - global_position).normalized()
		if desired_direction.length() > 0.0:
			direction = direction.lerp(desired_direction, 0.16).normalized()

	_visual_time += delta
	var step := direction * speed * delta
	global_position += step
	distance_traveled += step.length()
	_record_trail_point()
	queue_redraw()

	if target != null and is_instance_valid(target):
		if _hit_instance_ids.has(target.get_instance_id()):
			target = null
		elif global_position.distance_to(target.global_position) <= target.get_collision_radius() + radius:
			_hit_enemy(target)
			return
	else:
		var fallback_target: Enemy = wave_manager.find_enemy_in_radius(global_position, radius + 10.0, _hit_instance_ids)
		if fallback_target != null:
			_hit_enemy(fallback_target)
			return

	if distance_traveled >= stats_snapshot.projectile_range:
		queue_free()

func _hit_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		queue_free()
		return

	var is_critical: bool = _rng.randf() <= stats_snapshot.crit_chance
	var final_damage: float = stats_snapshot.damage * stats_snapshot.get_damage_multiplier_for_family(enemy.get_family())
	final_damage *= stats_snapshot.get_distance_damage_multiplier(distance_traveled)
	if is_critical:
		final_damage *= stats_snapshot.crit_damage
	_hit_instance_ids.append(enemy.get_instance_id())
	enemy.take_damage(final_damage, is_critical)

	if stats_snapshot.splash_chance > 0.0 and _rng.randf() <= stats_snapshot.splash_chance:
		var splash_damage: float = stats_snapshot.damage * stats_snapshot.splash_multiplier
		wave_manager.apply_area_damage(global_position, stats_snapshot.splash_radius, splash_damage, stats_snapshot, enemy)

	if remaining_bounces > 0 and stats_snapshot.bounce_chance > 0.0 and _rng.randf() <= stats_snapshot.bounce_chance:
		var bounce_target: Enemy = wave_manager.find_enemy_in_radius(global_position, stats_snapshot.bounce_radius, _hit_instance_ids)
		if bounce_target != null:
			remaining_bounces -= 1
			target = bounce_target
			var next_direction: Vector2 = bounce_target.global_position - global_position
			if next_direction.length() > 0.0:
				direction = next_direction.normalized()
			return

	if remaining_pierce > 0:
		remaining_pierce -= 1
		target = null
		return

	queue_free()

func _draw() -> void:
	var trail_size: int = _trail_points.size()
	if trail_size >= 2:
		for point_index in range(1, trail_size):
			var from_point: Vector2 = _trail_points[point_index - 1] - global_position
			var to_point: Vector2 = _trail_points[point_index] - global_position
			var trail_alpha: float = float(point_index) / float(trail_size)
			draw_line(from_point, to_point, Color(0.46, 0.91, 1.0, 0.1 + (trail_alpha * 0.18)), 1.8 + (trail_alpha * 1.8))

	var glow_radius: float = radius * (2.4 + (sin(_visual_time * 14.0) * 0.12))
	_draw_glow(Vector2.ZERO, glow_radius, Color(0.42, 0.92, 1.0, 0.08))
	if stats_snapshot != null and stats_snapshot.splash_chance > 0.0:
		_draw_glow(Vector2.ZERO, glow_radius * 0.74, Color(1.0, 0.72, 0.42, 0.08))

	var forward := direction
	if forward.length() <= 0.0:
		forward = Vector2.RIGHT
	var right := forward.orthogonal()

	var stem_back: Vector2 = -forward * radius * 1.4
	var stem_joint: Vector2 = forward * radius * 0.15
	var left_elbow: Vector2 = forward * radius * 0.52 + right * radius * 0.62
	var right_elbow: Vector2 = forward * radius * 0.52 - right * radius * 0.62
	var left_tip: Vector2 = forward * radius * 1.1 + right * radius * 1.22
	var right_tip: Vector2 = forward * radius * 1.1 - right * radius * 1.22
	var antibody_color := Color(0.9, 0.99, 1.0, 1.0)
	var edge_color := Color(0.46, 0.92, 1.0, 0.92)

	draw_line(stem_back, stem_joint, antibody_color, 4.2, true)
	draw_line(stem_joint, left_elbow, antibody_color, 4.0, true)
	draw_line(stem_joint, right_elbow, antibody_color, 4.0, true)
	draw_line(left_elbow, left_tip, antibody_color, 3.8, true)
	draw_line(right_elbow, right_tip, antibody_color, 3.8, true)

	draw_line(stem_back, stem_joint, edge_color, 1.8, true)
	draw_line(stem_joint, left_elbow, edge_color, 1.6, true)
	draw_line(stem_joint, right_elbow, edge_color, 1.6, true)
	draw_line(left_elbow, left_tip, edge_color, 1.6, true)
	draw_line(right_elbow, right_tip, edge_color, 1.6, true)

	draw_circle(stem_back, radius * 0.34, Color(0.72, 0.95, 1.0, 0.94))
	draw_circle(stem_joint, radius * 0.38, Color(0.28, 0.86, 1.0, 0.98))
	draw_circle(left_tip, radius * 0.42, Color(0.98, 1.0, 1.0, 0.98))
	draw_circle(right_tip, radius * 0.42, Color(0.98, 1.0, 1.0, 0.98))
	draw_circle(left_tip, radius * 0.2, Color(0.31, 0.88, 1.0, 0.92))
	draw_circle(right_tip, radius * 0.2, Color(0.31, 0.88, 1.0, 0.92))

	if stats_snapshot != null and stats_snapshot.splash_chance > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 18, Color(1.0, 0.76, 0.42, 0.7), 2.0)
	if remaining_bounces > 0:
		draw_arc(Vector2.ZERO, radius + 11.0, 0.0, TAU, 18, Color(0.96, 0.56, 1.0, 0.72), 2.0)
	if remaining_pierce > 0:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 18, Color(0.98, 0.9, 0.44, 0.78), 2.0)

func _record_trail_point() -> void:
	_trail_points.append(global_position)
	while _trail_points.size() > 6:
		_trail_points.pop_front()

func _draw_glow(center: Vector2, glow_radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var layer_t: float = float(layer) / 4.0
		draw_circle(center, glow_radius * layer_t, Color(color.r, color.g, color.b, color.a * layer_t))
