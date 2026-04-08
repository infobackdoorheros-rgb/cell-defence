extends Node
class_name WaveManager

const ResourceManager = preload("res://scripts/managers/resource_manager.gd")
const UpgradeManager = preload("res://scripts/managers/upgrade_manager.gd")
const WaveRulesData = preload("res://scripts/data/wave_rules_data.gd")
const Enemy = preload("res://scripts/entities/enemy.gd")
const RunStats = preload("res://scripts/core/run_stats.gd")
const EnemyData = preload("res://scripts/data/enemy_data.gd")
const AtpPickup = preload("res://scripts/entities/atp_pickup.gd")
const TargetingRules = preload("res://scripts/core/targeting_rules.gd")

signal wave_started(wave: int)
signal wave_cleared(wave: int, rewards: Dictionary)
signal mutation_milestone_reached(wave: int)
signal enemy_counts_changed(active_count: int, pending_count: int)

var core
var run_scene
var enemy_container: Node2D
var pickup_container: Node2D
var resource_manager: ResourceManager
var upgrade_manager: UpgradeManager

var _enemy_scene: PackedScene = preload("res://scenes/entities/enemy.tscn")
var _pickup_scene: PackedScene = preload("res://scenes/entities/atp_pickup.tscn")
var _wave_rules: WaveRulesData
var _rng := RandomNumberGenerator.new()

var current_wave: int = 0
var _spawn_queue: Array[StringName] = []
var _active_enemies: Array[Enemy] = []
var _spawn_timer: float = 0.0
var _intermission_timer: float = 0.0
var _wave_in_progress: bool = false
var _awaiting_mutation_choice: bool = false

func _ready() -> void:
	_rng.randomize()
	ContentDB.reload_content()
	_wave_rules = ContentDB.get_wave_rules()

func setup(core_ref, run_scene_ref, enemy_parent: Node2D, pickup_parent: Node2D, resource_manager_ref: ResourceManager, upgrade_manager_ref: UpgradeManager) -> void:
	core = core_ref
	run_scene = run_scene_ref
	enemy_container = enemy_parent
	pickup_container = pickup_parent
	resource_manager = resource_manager_ref
	upgrade_manager = upgrade_manager_ref

func reset_run() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_spawn_queue.clear()
	current_wave = 0
	_spawn_timer = 0.0
	_intermission_timer = 0.6
	_wave_in_progress = false
	_awaiting_mutation_choice = false
	enemy_counts_changed.emit(0, 0)

func _physics_process(delta: float) -> void:
	if run_scene == null or run_scene.is_gameplay_paused():
		return

	_cleanup_enemies()
	if _awaiting_mutation_choice:
		return

	if not _wave_in_progress:
		_intermission_timer -= delta
		if _intermission_timer <= 0.0:
			_start_next_wave()
		return

	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _get_spawn_interval()
			_spawn_enemy(_spawn_queue.pop_front())
			enemy_counts_changed.emit(_active_enemies.size(), _spawn_queue.size())

	if _spawn_queue.is_empty() and _active_enemies.is_empty():
		_complete_wave()

func get_targets_for_volley(count: int, priority: int, targeting_range: float) -> Array[Enemy]:
	var available := _get_targets_in_range(targeting_range)
	if available.is_empty():
		return []

	var ordered := _sort_targets(available, priority)
	var targets: Array[Enemy] = []
	for index in range(count):
		targets.append(ordered[index % ordered.size()])
	return targets

func get_secondary_target(primary_target: Enemy, priority: int, targeting_range: float):
	var available: Array[Enemy] = []
	for item in _get_targets_in_range(targeting_range):
		if item != primary_target:
			available.append(item)
	if available.is_empty():
		return null
	return _sort_targets(available, priority)[0]

func find_enemy_in_radius(world_position: Vector2, radius: float, excluded_instance_ids: Array[int] = []) -> Enemy:
	var nearest_enemy: Enemy
	var nearest_distance: float = INF
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		if excluded_instance_ids.has(enemy.get_instance_id()):
			continue
		var distance: float = enemy.global_position.distance_to(world_position)
		if distance > enemy.get_collision_radius() + radius:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func apply_area_damage(origin: Vector2, radius: float, damage: float, stats_snapshot: RunStats, ignore_enemy: Enemy = null) -> void:
	if radius <= 0.0 or damage <= 0.0:
		return

	for enemy in _active_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy == ignore_enemy:
			continue
		if enemy.global_position.distance_to(origin) > radius + enemy.get_collision_radius():
			continue
		var final_damage := damage * stats_snapshot.get_damage_multiplier_for_family(enemy.get_family())
		enemy.take_damage(final_damage, false)

func resume_after_mutation_choice() -> void:
	_awaiting_mutation_choice = false
	_intermission_timer = 1.25

func get_active_enemy_count() -> int:
	return _active_enemies.size()

func _start_next_wave() -> void:
	current_wave += 1
	resource_manager.set_wave_reached(current_wave)
	_spawn_queue = _build_wave_plan(current_wave)
	_wave_in_progress = true
	_spawn_timer = 0.0
	wave_started.emit(current_wave)
	enemy_counts_changed.emit(_active_enemies.size(), _spawn_queue.size())

func _complete_wave() -> void:
	_wave_in_progress = false
	var rewards := resource_manager.grant_wave_clear_rewards(current_wave, upgrade_manager.get_current_stats())
	wave_cleared.emit(current_wave, rewards)
	if current_wave % _wave_rules.mutation_interval == 0:
		_awaiting_mutation_choice = true
		mutation_milestone_reached.emit(current_wave)
	else:
		_intermission_timer = 1.25

func _build_wave_plan(wave: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if _wave_rules == null:
		return result
	var chapter = RunConfigManager.get_selected_chapter()

	if wave % _wave_rules.boss_interval == 0:
		result.append(_wave_rules.boss_id)
		var support_band: Dictionary = _wave_rules.get_band_for_wave(max(1, wave - 1))
		var support_weights := _apply_chapter_weights(support_band.get("enemy_weights", {}) as Dictionary, chapter)
		var support_count := _wave_rules.boss_support_count + int(wave / 10.0)
		if chapter != null:
			support_count += chapter.boss_support_bonus
		for index in range(support_count):
			result.append(_roll_weighted_enemy_id(support_weights))
		return result

	var band: Dictionary = _wave_rules.get_band_for_wave(wave)
	var enemy_weights: Dictionary = _apply_chapter_weights(band.get("enemy_weights", {}) as Dictionary, chapter)
	var spawn_count: int = _wave_rules.initial_spawn_count + int(round((wave - 1) * _wave_rules.spawn_count_per_wave)) + int(band.get("spawn_count_bonus", 0))
	if chapter != null:
		spawn_count += chapter.spawn_count_bonus
	var spawn_density_scale: float = max(0.5, RemoteConfigManager.get_float("combat.spawn_density_scale", 1.0))
	spawn_count = max(1, int(round(float(spawn_count) * spawn_density_scale)))
	for index in range(spawn_count):
		result.append(_roll_weighted_enemy_id(enemy_weights))

	if wave >= _wave_rules.elite_start_wave:
		var elite_chance: float = _wave_rules.elite_base_chance + (_wave_rules.elite_chance_per_wave * wave) + float(band.get("elite_chance_bonus", 0.0))
		if _rng.randf() <= elite_chance and not result.is_empty():
			result[_rng.randi_range(0, result.size() - 1)] = &"elite_spore_titan"
		if wave >= (_wave_rules.elite_start_wave + 8) and _rng.randf() <= elite_chance * 0.55 and result.size() >= 3:
			result[_rng.randi_range(0, result.size() - 1)] = &"elite_spore_titan"
	return result

func _roll_weighted_enemy_id(weights: Dictionary) -> StringName:
	var total := 0.0
	for value in weights.values():
		total += float(value)

	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for key in weights.keys():
		cursor += float(weights[key])
		if roll <= cursor:
			return StringName(key)

	return StringName(weights.keys()[0])

func _spawn_enemy(enemy_id: StringName, custom_position: Vector2 = Vector2.ZERO, use_custom_position: bool = false) -> void:
	var enemy_data := ContentDB.get_enemy(enemy_id)
	if enemy_data == null:
		return
	var chapter = RunConfigManager.get_selected_chapter()

	var enemy := _enemy_scene.instantiate() as Enemy
	enemy_container.add_child(enemy)
	var wave_health_scale := 1.0 + ((current_wave - 1) * _wave_rules.health_scale_per_wave)
	var wave_speed_scale := 1.0 + ((current_wave - 1) * _wave_rules.speed_scale_per_wave)
	if chapter != null:
		wave_health_scale *= chapter.enemy_health_multiplier
		wave_speed_scale *= chapter.enemy_speed_multiplier
	wave_health_scale *= max(0.5, RemoteConfigManager.get_float("combat.enemy_health_scale", 1.0))
	wave_speed_scale *= max(0.5, RemoteConfigManager.get_float("combat.enemy_speed_scale", 1.0))
	var spawn_position: Vector2 = custom_position if use_custom_position else run_scene.get_random_spawn_position()

	enemy.global_position = spawn_position
	enemy.initialize(enemy_data, core, run_scene, wave_health_scale, wave_speed_scale)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.escaped.connect(_on_enemy_escaped)
	enemy.despawned.connect(_on_enemy_despawned)
	enemy.children_requested.connect(_on_enemy_children_requested)
	_active_enemies.append(enemy)
	enemy_counts_changed.emit(_active_enemies.size(), _spawn_queue.size())

func _on_enemy_defeated(enemy: Enemy, enemy_data: EnemyData, world_position: Vector2) -> void:
	_remove_enemy(enemy)
	var current_stats: RunStats = upgrade_manager.get_current_stats()
	resource_manager.register_enemy_defeat(enemy_data, current_stats)
	var chapter_atp_multiplier: float = 1.0
	var chapter = RunConfigManager.get_selected_chapter()
	if chapter != null:
		chapter_atp_multiplier = chapter.atp_multiplier
	var atp_scale: float = max(0.25, RemoteConfigManager.get_float("economy.runtime_atp_scale", 1.0))
	var atp_reward := int(round(enemy_data.atp_reward * current_stats.atp_gain_multiplier * chapter_atp_multiplier * atp_scale))
	if atp_reward > 0:
		var pickup := _pickup_scene.instantiate() as AtpPickup
		pickup_container.add_child(pickup)
		pickup.global_position = world_position
		pickup.initialize(atp_reward, core, run_scene)
		pickup.collected.connect(resource_manager.add_atp)

func _on_enemy_escaped(enemy: Enemy, damage: float) -> void:
	if core != null and is_instance_valid(core):
		core.take_damage(damage, true, enemy)

func _on_enemy_despawned(enemy: Enemy) -> void:
	_remove_enemy(enemy)

func _on_enemy_children_requested(child_ids: PackedStringArray, world_position: Vector2) -> void:
	for child_id in child_ids:
		var offset := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(6.0, 24.0)
		_spawn_enemy(StringName(child_id), world_position + offset, true)

func _remove_enemy(enemy: Enemy) -> void:
	_active_enemies.erase(enemy)
	enemy_counts_changed.emit(_active_enemies.size(), _spawn_queue.size())

func _cleanup_enemies() -> void:
	var cleaned: Array[Enemy] = []
	for item in _active_enemies:
		if is_instance_valid(item):
			cleaned.append(item)
	_active_enemies = cleaned

func _get_targets_in_range(targeting_range: float) -> Array[Enemy]:
	var candidates: Array[Enemy] = []
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(core.global_position) <= targeting_range:
			candidates.append(enemy)
	return candidates

func _sort_targets(candidates: Array[Enemy], priority: int) -> Array[Enemy]:
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		match priority:
			TargetingRules.Priority.LOWEST_HP:
				if not is_equal_approx(a.current_health, b.current_health):
					return a.current_health < b.current_health
			TargetingRules.Priority.HIGHEST_HP:
				if not is_equal_approx(a.current_health, b.current_health):
					return a.current_health > b.current_health
			TargetingRules.Priority.FASTEST:
				if not is_equal_approx(a.get_current_speed(), b.get_current_speed()):
					return a.get_current_speed() > b.get_current_speed()
			TargetingRules.Priority.VIRUS_FIRST:
				if a.get_family() != b.get_family():
					return a.get_family() == &"virus"
			TargetingRules.Priority.BACTERIA_FIRST:
				if a.get_family() != b.get_family():
					return a.get_family() == &"bacteria"
		return a.global_position.distance_to(core.global_position) < b.global_position.distance_to(core.global_position)
	)
	return candidates

func _get_spawn_interval() -> float:
	return max(_wave_rules.min_spawn_interval, _wave_rules.base_spawn_interval - (current_wave * 0.012))

func _apply_chapter_weights(weights: Dictionary, chapter) -> Dictionary:
	var adjusted: Dictionary = {}
	for key in weights.keys():
		var weighted_value: float = float(weights[key])
		if chapter != null:
			var enemy_data := ContentDB.get_enemy(StringName(key))
			if enemy_data != null:
				if enemy_data.family == &"virus":
					weighted_value *= 1.0 + chapter.virus_weight_bonus
				elif enemy_data.family == &"bacteria":
					weighted_value *= 1.0 + chapter.bacteria_weight_bonus
		adjusted[key] = weighted_value
	return adjusted
