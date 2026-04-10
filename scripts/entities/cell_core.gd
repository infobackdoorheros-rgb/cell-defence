extends Node2D
class_name CellCore

const RunStats = preload("res://scripts/core/run_stats.gd")
const TargetingRules = preload("res://scripts/core/targeting_rules.gd")
const CoreArchetypeData = preload("res://scripts/data/core_archetype_data.gd")

signal health_changed(current_hp: float, max_hp: float)
signal shield_changed(current_shield: float, max_shield: float)
signal stats_changed(stats)
signal core_destroyed
signal active_skill_state_changed(cooldown_remaining: float, cooldown_total: float)

const CORE_RADIUS := 34.0
const RAPID_FIRE_MULTIPLIER := 2.15

var wave_manager
var run_scene
var projectile_container: Node2D

var _projectile_scene: PackedScene = preload("res://scenes/entities/projectile_antibody.tscn")
var _current_stats: RunStats = RunStats.new()
var _current_health: float = 0.0
var _current_shield: float = 0.0
var _attack_cooldown: float = 0.0
var _active_skill_cooldown_remaining: float = 0.0
var _damage_flash_timer: float = 0.0
var _attack_pulse_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _rapid_fire_timer: float = 0.0
var _visual_time: float = 0.0
var _orbit_phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _current_archetype: CoreArchetypeData

var target_priority: int = TargetingRules.Priority.NEAREST_TO_CORE

func _ready() -> void:
	_rng.randomize()
	_orbit_phase = _rng.randf_range(0.0, TAU)
	set_process(true)

func _process(delta: float) -> void:
	_visual_time += delta
	if _damage_flash_timer > 0.0:
		_damage_flash_timer = max(_damage_flash_timer - delta, 0.0)
	if _attack_pulse_timer > 0.0:
		_attack_pulse_timer = max(_attack_pulse_timer - delta, 0.0)
	queue_redraw()

func setup(run_scene_ref, wave_manager_ref, projectile_parent: Node2D) -> void:
	run_scene = run_scene_ref
	wave_manager = wave_manager_ref
	projectile_container = projectile_parent

func reset_run() -> void:
	_attack_cooldown = 0.0
	_active_skill_cooldown_remaining = 0.0
	_damage_flash_timer = 0.0
	_attack_pulse_timer = 0.0
	_invulnerability_timer = 0.0
	_rapid_fire_timer = 0.0
	_current_shield = 0.0
	active_skill_state_changed.emit(_active_skill_cooldown_remaining, get_active_skill_cooldown_total())

func configure_archetype(archetype: CoreArchetypeData) -> void:
	_current_archetype = archetype
	_active_skill_cooldown_remaining = 0.0
	active_skill_state_changed.emit(_active_skill_cooldown_remaining, get_active_skill_cooldown_total())

func apply_stats(stats: RunStats) -> void:
	var previous_max_hp: float = _current_stats.max_hp
	var missing_health: float = max(previous_max_hp - _current_health, 0.0)
	var previous_max_shield: float = _current_stats.shield_max
	var missing_shield: float = max(previous_max_shield - _current_shield, 0.0)
	_current_stats = stats.clone()
	if _current_health <= 0.0:
		_current_health = _current_stats.max_hp
	else:
		_current_health = clamp(_current_stats.max_hp - missing_health, 0.0, _current_stats.max_hp)
	if _current_stats.shield_max <= 0.0:
		_current_shield = 0.0
	elif _current_shield <= 0.0 and previous_max_shield <= 0.0:
		_current_shield = _current_stats.shield_max
	else:
		_current_shield = clamp(_current_stats.shield_max - missing_shield, 0.0, _current_stats.shield_max)
	health_changed.emit(_current_health, _current_stats.max_hp)
	shield_changed.emit(_current_shield, _current_stats.shield_max)
	stats_changed.emit(_current_stats.clone())
	queue_redraw()

func _physics_process(delta: float) -> void:
	if run_scene == null or run_scene.is_gameplay_paused() or is_dead():
		return

	if _invulnerability_timer > 0.0:
		_invulnerability_timer = max(_invulnerability_timer - delta, 0.0)
	if _active_skill_cooldown_remaining > 0.0:
		_active_skill_cooldown_remaining = max(_active_skill_cooldown_remaining - delta, 0.0)
		active_skill_state_changed.emit(_active_skill_cooldown_remaining, get_active_skill_cooldown_total())

	if _current_health < _current_stats.max_hp:
		_current_health = min(_current_stats.max_hp, _current_health + (_current_stats.regeneration * delta))
		health_changed.emit(_current_health, _current_stats.max_hp)
	if _current_shield < _current_stats.shield_max and _current_stats.shield_regeneration > 0.0:
		_current_shield = min(_current_stats.shield_max, _current_shield + (_current_stats.shield_regeneration * delta))
		shield_changed.emit(_current_shield, _current_stats.shield_max)
	if _rapid_fire_timer > 0.0:
		_rapid_fire_timer = max(_rapid_fire_timer - delta, 0.0)

	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return

	var volley_count: int = _current_stats.projectile_count
	if _current_stats.secondary_projectile_chance > 0.0 and _rng.randf() <= _current_stats.secondary_projectile_chance:
		volley_count += max(1, _current_stats.multishot_targets)

	var targets: Array = wave_manager.get_targets_for_volley(volley_count, target_priority, _current_stats.targeting_range)
	if targets.is_empty():
		_attack_cooldown = 0.08
		return

	_fire_volley(targets)
	if _current_stats.rapid_fire_chance > 0.0 and _rng.randf() <= _current_stats.rapid_fire_chance:
		_rapid_fire_timer = max(_rapid_fire_timer, _current_stats.rapid_fire_duration)
	_attack_cooldown = _get_current_attack_interval()

func take_damage(raw_damage: float, is_contact_hit: bool = false, source_enemy = null) -> void:
	if is_dead():
		return
	if _invulnerability_timer > 0.0:
		return

	var final_damage: float = maxf(raw_damage - _current_stats.absolute_defense, 0.0)
	final_damage *= (1.0 - _current_stats.armor)
	if is_contact_hit:
		final_damage *= 1.0 - _current_stats.contact_damage_reduction
		if source_enemy != null and is_instance_valid(source_enemy) and _current_stats.contact_retaliation > 0.0:
			source_enemy.take_damage(_current_stats.contact_retaliation, false)

	if _current_shield > 0.0:
		var absorbed: float = min(_current_shield, final_damage)
		_current_shield -= absorbed
		final_damage -= absorbed
		shield_changed.emit(_current_shield, _current_stats.shield_max)

	_current_health = max(0.0, _current_health - final_damage)
	_damage_flash_timer = 0.18
	health_changed.emit(_current_health, _current_stats.max_hp)
	queue_redraw()

	if _current_health <= 0.0:
		core_destroyed.emit()

func is_dead() -> bool:
	return _current_health <= 0.0

func get_pickup_radius() -> float:
	return _current_stats.pickup_radius

func get_core_radius() -> float:
	return CORE_RADIUS

func get_enemy_speed_multiplier(enemy_position: Vector2) -> float:
	if _current_stats.slow_aura_strength <= 0.0 or _current_stats.slow_aura_radius <= 0.0:
		return 1.0
	if global_position.distance_to(enemy_position) > _current_stats.slow_aura_radius:
		return 1.0
	return 1.0 - _current_stats.slow_aura_strength

func get_current_health() -> float:
	return _current_health

func get_current_shield() -> float:
	return _current_shield

func get_current_stats() -> RunStats:
	return _current_stats.clone()

func activate_active_skill() -> bool:
	if _current_archetype == null or _active_skill_cooldown_remaining > 0.0 or is_dead():
		return false

	var pulse_damage: float = _current_stats.damage * _current_archetype.active_skill_damage_multiplier
	wave_manager.apply_area_damage(global_position, _current_archetype.active_skill_radius, pulse_damage, _current_stats)
	if _current_archetype.active_skill_shield_restore_ratio > 0.0 and _current_stats.shield_max > 0.0:
		var restored_shield := _current_stats.shield_max * _current_archetype.active_skill_shield_restore_ratio
		_current_shield = min(_current_stats.shield_max, _current_shield + restored_shield)
		shield_changed.emit(_current_shield, _current_stats.shield_max)
	_attack_pulse_timer = 0.42
	_active_skill_cooldown_remaining = get_active_skill_cooldown_total()
	active_skill_state_changed.emit(_active_skill_cooldown_remaining, get_active_skill_cooldown_total())
	queue_redraw()
	return true

func revive(health_ratio: float = 0.55, shield_ratio: float = 0.3) -> void:
	_current_health = max(_current_stats.max_hp * health_ratio, _current_stats.max_hp * 0.25)
	if _current_stats.shield_max > 0.0:
		_current_shield = _current_stats.shield_max * shield_ratio
	else:
		_current_shield = 0.0
	_invulnerability_timer = 2.2
	_damage_flash_timer = 0.0
	_attack_pulse_timer = 0.3
	health_changed.emit(_current_health, _current_stats.max_hp)
	shield_changed.emit(_current_shield, _current_stats.shield_max)
	queue_redraw()

func get_active_skill_name() -> String:
	if _current_archetype == null:
		return ""
	return _current_archetype.active_skill_name

func get_active_skill_description() -> String:
	if _current_archetype == null:
		return ""
	return _current_archetype.active_skill_description

func get_active_skill_cooldown_total() -> float:
	if _current_archetype == null:
		return 0.0
	return max(_current_archetype.active_skill_cooldown, 0.0)

func get_active_skill_cooldown_remaining() -> float:
	return _active_skill_cooldown_remaining

func get_snapshot_state() -> Dictionary:
	return {
		"current_health": _current_health,
		"current_shield": _current_shield,
		"attack_cooldown": _attack_cooldown,
		"active_skill_cooldown_remaining": _active_skill_cooldown_remaining,
		"rapid_fire_timer": _rapid_fire_timer,
		"invulnerability_timer": _invulnerability_timer
	}

func restore_snapshot_state(data: Dictionary) -> void:
	_current_health = clamp(float(data.get("current_health", _current_stats.max_hp)), 0.0, _current_stats.max_hp)
	_current_shield = clamp(float(data.get("current_shield", _current_stats.shield_max)), 0.0, _current_stats.shield_max)
	_attack_cooldown = max(0.0, float(data.get("attack_cooldown", 0.0)))
	_active_skill_cooldown_remaining = max(0.0, float(data.get("active_skill_cooldown_remaining", 0.0)))
	_rapid_fire_timer = max(0.0, float(data.get("rapid_fire_timer", 0.0)))
	_invulnerability_timer = max(0.0, float(data.get("invulnerability_timer", 0.0)))
	health_changed.emit(_current_health, _current_stats.max_hp)
	shield_changed.emit(_current_shield, _current_stats.shield_max)
	active_skill_state_changed.emit(_active_skill_cooldown_remaining, get_active_skill_cooldown_total())
	queue_redraw()

func _fire_volley(targets: Array) -> void:
	_attack_pulse_timer = 0.16
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		_spawn_projectile(target, (target.global_position - global_position).normalized())

func _spawn_projectile(target, direction: Vector2) -> void:
	var projectile := _projectile_scene.instantiate()
	projectile_container.add_child(projectile)
	projectile.initialize(global_position, target, direction, _current_stats, wave_manager, run_scene)

func _get_current_attack_interval() -> float:
	var interval: float = _current_stats.get_attack_interval()
	if _rapid_fire_timer > 0.0:
		interval /= RAPID_FIRE_MULTIPLIER
	return max(interval, 0.04)

func _draw() -> void:
	var pulse: float = 1.0 + (sin(_visual_time * 2.0 + _orbit_phase) * 0.035)
	var health_ratio: float = 0.0
	var shield_ratio: float = 0.0
	if _current_stats.max_hp > 0.0:
		health_ratio = _current_health / _current_stats.max_hp
	if _current_stats.shield_max > 0.0:
		shield_ratio = _current_shield / _current_stats.shield_max

	if _current_stats.targeting_range > CORE_RADIUS + 36.0:
		_draw_segment_ring(_current_stats.targeting_range, 22, 0.26, Color(0.45, 0.82, 1.0, 0.08), 2.0, 0.0)
	if _current_stats.pickup_radius > CORE_RADIUS + 20.0:
		_draw_segment_ring(_current_stats.pickup_radius, 18, 0.22, Color(1.0, 0.76, 0.42, 0.12), 2.0, 0.16)

	if _current_stats.slow_aura_strength > 0.0 and _current_stats.slow_aura_radius > 0.0:
		var aura_strength: float = _current_stats.slow_aura_strength
		_draw_glow(Vector2.ZERO, _current_stats.slow_aura_radius, Color(0.21, 0.78, 0.68, 0.04 + (aura_strength * 0.04)))
		_draw_segment_ring(_current_stats.slow_aura_radius, 28, 0.22, Color(0.33, 0.93, 0.8, 0.16 + (aura_strength * 0.12)), 2.0, _visual_time * 0.08)

	_draw_glow(Vector2(0.0, 6.0), (CORE_RADIUS + 18.0) * pulse, Color(0.0, 0.0, 0.0, 0.16))
	_draw_glow(Vector2.ZERO, (CORE_RADIUS + 26.0) * pulse, Color(0.29, 0.88, 0.82, 0.08 + (_attack_pulse_timer * 0.12)))
	draw_circle(Vector2.ZERO, (CORE_RADIUS + 12.0) * pulse, Color(0.09, 0.18, 0.23, 0.82))

	var shell_color := Color(0.72, 0.95, 0.84, 1.0)
	if _damage_flash_timer > 0.0:
		shell_color = shell_color.lerp(Color(1.0, 0.72, 0.72, 1.0), 0.65)

	draw_circle(Vector2.ZERO, CORE_RADIUS * pulse, shell_color)
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.82, Color(0.54, 0.96, 0.86, 0.32))
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.58, Color(0.97, 1.0, 0.99, 1.0))
	draw_circle(Vector2(6.0, -5.0), CORE_RADIUS * 0.2, Color(0.68, 1.0, 0.9, 0.92))
	draw_arc(Vector2.ZERO, CORE_RADIUS + 2.0, 0.0, TAU, 32, Color(0.31, 0.92, 0.84, 0.85), 4.0)

	for organelle_index in range(4):
		var angle: float = (_visual_time * (0.55 + (organelle_index * 0.12))) + _orbit_phase + (TAU * float(organelle_index) / 4.0)
		var organelle_position := Vector2.RIGHT.rotated(angle) * (CORE_RADIUS * 0.34)
		draw_circle(organelle_position, 4.5 + sin(_visual_time * 2.4 + organelle_index) * 0.6, Color(0.4, 0.93, 0.86, 0.8))

	for satellite_index in range(3):
		var orbit_angle: float = (_visual_time * (0.95 + (satellite_index * 0.12))) + _orbit_phase + (TAU * float(satellite_index) / 3.0)
		var orbit_radius: float = CORE_RADIUS + 14.0 + (satellite_index * 7.0)
		var satellite_position := Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
		draw_circle(satellite_position, 4.0 + (satellite_index * 0.9), Color(0.85, 0.99, 1.0, 0.86))
		draw_circle(satellite_position, 2.0 + (satellite_index * 0.4), Color(0.28, 0.86, 1.0, 0.9))

	if _current_stats.armor > 0.0:
		var armor_alpha: float = 0.15 + (_current_stats.armor * 0.35)
		_draw_segment_ring(CORE_RADIUS + 18.0, 14, 0.36, Color(0.44, 0.82, 1.0, armor_alpha), 3.0, -_visual_time * 0.25)
	if _current_stats.shield_max > 0.0:
		var shield_alpha: float = 0.18 + (shield_ratio * 0.3)
		_draw_glow(Vector2.ZERO, CORE_RADIUS + 16.0, Color(0.45, 0.82, 1.0, 0.05 + (shield_ratio * 0.06)))
		_draw_segment_ring(CORE_RADIUS + 24.0, 18, 0.32, Color(0.52, 0.84, 1.0, shield_alpha), 3.0, _visual_time * 0.18)
	if _invulnerability_timer > 0.0:
		_draw_segment_ring(CORE_RADIUS + 30.0, 20, 0.28, Color(1.0, 0.9, 0.52, 0.45), 3.0, -_visual_time * 0.2)
	if _rapid_fire_timer > 0.0:
		_draw_segment_ring(CORE_RADIUS + 14.0, 16, 0.38, Color(1.0, 0.76, 0.42, 0.42), 3.0, _visual_time * 0.4)

	var attack_interval: float = max(_current_stats.get_attack_interval(), 0.001)
	var charge_ratio: float = 1.0 - clamp(_attack_cooldown / attack_interval, 0.0, 1.0)
	draw_arc(Vector2.ZERO, CORE_RADIUS + 10.0, -PI * 0.5, -PI * 0.5 + (TAU * charge_ratio), 36, Color(1.0, 0.77, 0.42, 0.88), 5.0)

	if _current_stats.regeneration > 0.0:
		for regen_index in range(5):
			var regen_angle: float = (TAU * float(regen_index) / 5.0) - (_visual_time * 0.8)
			var regen_radius: float = CORE_RADIUS + 24.0 + sin(_visual_time * 2.2 + regen_index) * 3.0
			var regen_position := Vector2.RIGHT.rotated(regen_angle) * regen_radius
			draw_circle(regen_position, 2.8, Color(0.4, 0.97, 0.68, 0.38))

	var bar_origin := Vector2(-52.0, CORE_RADIUS + 22.0)
	var bar_size := Vector2(104.0, 9.0)
	draw_rect(Rect2(bar_origin, bar_size), Color(0.07, 0.11, 0.14, 0.95), true)
	draw_rect(Rect2(bar_origin, Vector2(bar_size.x * health_ratio, bar_size.y)), Color(0.25, 0.96, 0.62, 0.98), true)
	draw_rect(Rect2(bar_origin - Vector2(2.0, 2.0), bar_size + Vector2(4.0, 4.0)), Color(0.28, 0.9, 0.78, 0.2), false, 2.0)
	if _current_stats.shield_max > 0.0:
		var shield_bar_origin := Vector2(-52.0, CORE_RADIUS + 35.0)
		var shield_bar_size := Vector2(104.0, 6.0)
		draw_rect(Rect2(shield_bar_origin, shield_bar_size), Color(0.06, 0.09, 0.13, 0.95), true)
		draw_rect(Rect2(shield_bar_origin, Vector2(shield_bar_size.x * shield_ratio, shield_bar_size.y)), Color(0.45, 0.82, 1.0, 0.98), true)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var layer_t: float = float(layer) / 4.0
		draw_circle(center, radius * layer_t, Color(color.r, color.g, color.b, color.a * layer_t))

func _draw_segment_ring(radius: float, segment_count: int, segment_ratio: float, color: Color, thickness: float, angle_offset: float) -> void:
	for segment_index in range(segment_count):
		var start_angle: float = angle_offset + (TAU * float(segment_index) / float(segment_count))
		var end_angle: float = start_angle + ((TAU / float(segment_count)) * segment_ratio)
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 10, color, thickness)
