extends Node
class_name UpgradeManager

const ResourceManager = preload("res://scripts/managers/resource_manager.gd")
const MutationManager = preload("res://scripts/managers/mutation_manager.gd")
const MutationData = preload("res://scripts/data/mutation_data.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const RunStats = preload("res://scripts/core/run_stats.gd")

signal stats_updated(stats)
signal upgrades_changed
signal free_upgrade_granted(category: StringName, upgrade_name: String)

const RANDOM_PROGRESS_INTERVAL := 10.0

var resource_manager: ResourceManager
var mutation_manager: MutationManager

var _runtime_levels: Dictionary = {}
var _active_mutations: Array[MutationData] = []
var _current_stats: RunStats = RunStats.new()
var _rng := RandomNumberGenerator.new()
var _attack_progress_timer: float = RANDOM_PROGRESS_INTERVAL
var _defense_progress_timer: float = RANDOM_PROGRESS_INTERVAL
var _utility_progress_timer: float = RANDOM_PROGRESS_INTERVAL

func setup(resource_manager_ref: ResourceManager, mutation_manager_ref: MutationManager) -> void:
	resource_manager = resource_manager_ref
	mutation_manager = mutation_manager_ref
	_rng.randomize()
	if not mutation_manager.mutation_added.is_connected(_on_mutation_added):
		mutation_manager.mutation_added.connect(_on_mutation_added)
	reset_run()

func reset_run() -> void:
	_runtime_levels.clear()
	_active_mutations.clear()
	_attack_progress_timer = RANDOM_PROGRESS_INTERVAL
	_defense_progress_timer = RANDOM_PROGRESS_INTERVAL
	_utility_progress_timer = RANDOM_PROGRESS_INTERVAL
	recompute_stats()
	upgrades_changed.emit()

func get_current_stats() -> RunStats:
	return _current_stats.clone()

func get_runtime_level(upgrade_id: StringName) -> int:
	return int(_runtime_levels.get(String(upgrade_id), 0))

func get_runtime_levels() -> Dictionary:
	return _runtime_levels.duplicate(true)

func can_purchase(upgrade_id: StringName) -> bool:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null or data.layer != &"runtime":
		return false
	var level := get_runtime_level(upgrade_id)
	if level >= data.max_level:
		return false
	if resource_manager == null:
		return false
	return resource_manager.atp >= data.get_cost_for_level(level + 1)

func purchase_upgrade(upgrade_id: StringName) -> bool:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null or data.layer != &"runtime":
		return false

	var current_level := get_runtime_level(upgrade_id)
	if current_level >= data.max_level:
		return false

	var next_cost := data.get_cost_for_level(current_level + 1)
	if not resource_manager.spend_atp(next_cost):
		return false

	_runtime_levels[String(upgrade_id)] = current_level + 1
	DailyMissionManager.register_runtime_upgrade_purchase()
	recompute_stats()
	upgrades_changed.emit()
	return true

func get_next_cost(upgrade_id: StringName) -> int:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null:
		return 0
	return data.get_cost_for_level(get_runtime_level(upgrade_id) + 1)

func get_active_mutations() -> Array[MutationData]:
	return _active_mutations.duplicate()

func update_runtime_systems(delta: float, is_paused: bool) -> void:
	if is_paused:
		return

	var interval: float = _get_auto_progress_interval()
	_attack_progress_timer -= delta
	if _attack_progress_timer <= 0.0:
		_attack_progress_timer += interval
		if _current_stats.random_attack_upgrade_chance > 0.0 and _rng.randf() <= _current_stats.random_attack_upgrade_chance:
			_grant_random_free_upgrade(&"attack")

	_defense_progress_timer -= delta
	if _defense_progress_timer <= 0.0:
		_defense_progress_timer += interval
		if _current_stats.random_defense_upgrade_chance > 0.0 and _rng.randf() <= _current_stats.random_defense_upgrade_chance:
			_grant_random_free_upgrade(&"defense")

	_utility_progress_timer -= delta
	if _utility_progress_timer <= 0.0:
		_utility_progress_timer += interval
		if _current_stats.random_utility_upgrade_chance > 0.0 and _rng.randf() <= _current_stats.random_utility_upgrade_chance:
			_grant_random_free_upgrade(&"utility")

func recompute_stats() -> void:
	var stats := RunStats.new()
	var archetype = RunConfigManager.get_selected_core_archetype()

	if archetype != null:
		for stat_key in archetype.stat_bonuses.keys():
			stats.apply_stat_bonus(StringName(stat_key), float(archetype.stat_bonuses[stat_key]))

	for upgrade in ContentDB.get_meta_upgrades():
		var level := MetaProgression.get_upgrade_level(upgrade.upgrade_id)
		if level > 0 and upgrade.stat_key != &"":
			stats.apply_stat_bonus(upgrade.stat_key, upgrade.get_bonus_for_level(level))

	for upgrade in ContentDB.get_runtime_upgrades():
		var level := get_runtime_level(upgrade.upgrade_id)
		if level > 0:
			stats.apply_stat_bonus(upgrade.stat_key, upgrade.get_bonus_for_level(level))

	for mutation in _active_mutations:
		stats.damage_vs_virus_bonus += mutation.damage_vs_virus_bonus
		stats.damage_vs_bacteria_bonus += mutation.damage_vs_bacteria_bonus
		stats.splash_chance += mutation.splash_chance
		stats.splash_radius = max(stats.splash_radius, mutation.splash_radius)
		stats.splash_multiplier = max(stats.splash_multiplier, mutation.splash_damage_multiplier)
		stats.secondary_projectile_chance += mutation.secondary_projectile_chance
		stats.slow_aura_strength = max(stats.slow_aura_strength, mutation.slow_aura_strength)
		stats.slow_aura_radius = max(stats.slow_aura_radius, mutation.slow_aura_radius)
		stats.regeneration += mutation.regeneration_bonus
		stats.attack_speed -= mutation.attack_speed_penalty

	stats.finalize()
	_current_stats = stats
	stats_updated.emit(_current_stats.clone())

func _on_mutation_added(mutation: MutationData) -> void:
	_active_mutations.append(mutation)
	recompute_stats()
	upgrades_changed.emit()

func _grant_random_free_upgrade(category: StringName) -> void:
	var eligible: Array[UpgradeData] = []
	for upgrade in ContentDB.get_runtime_upgrades_by_category(category):
		var current_level := get_runtime_level(upgrade.upgrade_id)
		if current_level >= upgrade.max_level:
			continue
		eligible.append(upgrade)

	if eligible.is_empty():
		return

	var picked: int = _rng.randi_range(0, eligible.size() - 1)
	var selected: UpgradeData = eligible[picked]
	_runtime_levels[String(selected.upgrade_id)] = get_runtime_level(selected.upgrade_id) + 1
	recompute_stats()
	upgrades_changed.emit()
	free_upgrade_granted.emit(category, selected.display_name)

func _get_auto_progress_interval() -> float:
	return max(3.0, RANDOM_PROGRESS_INTERVAL * (1.0 - _current_stats.auto_upgrade_interval_reduction))

func get_snapshot_state() -> Dictionary:
	return {
		"runtime_levels": _runtime_levels.duplicate(true),
		"attack_progress_timer": _attack_progress_timer,
		"defense_progress_timer": _defense_progress_timer,
		"utility_progress_timer": _utility_progress_timer
	}

func restore_snapshot_state(data: Dictionary) -> void:
	_runtime_levels = (data.get("runtime_levels", {}) as Dictionary).duplicate(true)
	_attack_progress_timer = max(0.05, float(data.get("attack_progress_timer", RANDOM_PROGRESS_INTERVAL)))
	_defense_progress_timer = max(0.05, float(data.get("defense_progress_timer", RANDOM_PROGRESS_INTERVAL)))
	_utility_progress_timer = max(0.05, float(data.get("utility_progress_timer", RANDOM_PROGRESS_INTERVAL)))
	_active_mutations = mutation_manager.get_active_mutations()
	recompute_stats()
	upgrades_changed.emit()
