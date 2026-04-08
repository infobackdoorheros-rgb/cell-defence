extends Node

const RUN_SCENE := preload("res://scenes/run_scene.tscn")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const MutationData = preload("res://scripts/data/mutation_data.gd")
const WaveRulesData = preload("res://scripts/data/wave_rules_data.gd")
const RunStats = preload("res://scripts/core/run_stats.gd")

const REPORT_PATH := "res://docs/playtest_report.json"
const TIME_SCALE := 6.0
const MAX_SIM_TIME := 420.0

var _scenarios: Array[Dictionary] = []
var _scenario_index: int = -1
var _current_scenario: Dictionary = {}
var _current_run
var _results: Array[Dictionary] = []

var _saved_meta: Dictionary = {}
var _saved_run_profile: Dictionary = {}
var _saved_reward_state: Dictionary = {}

var _sim_time: float = 0.0
var _wave_start_time: float = 0.0
var _wave_records: Array[Dictionary] = []
var _upgrade_counts: Dictionary = {}
var _mutation_picks: Array[String] = []
var _min_hp_ratio: float = 1.0
var _min_shield_ratio: float = 1.0
var _peak_active_enemies: int = 0
var _upgrade_tick: float = 0.0
var _skill_tick: float = 0.0
var _logged_timeout: bool = false

func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	_snapshot_state()
	_build_scenarios()
	await get_tree().process_frame
	_start_next_scenario()

func _process(delta: float) -> void:
	if _current_run == null or not is_instance_valid(_current_run):
		return

	_sim_time += delta
	_min_hp_ratio = min(_min_hp_ratio, _get_core_hp_ratio())
	_min_shield_ratio = min(_min_shield_ratio, _get_core_shield_ratio())
	_peak_active_enemies = max(_peak_active_enemies, int(_current_run.wave_manager.get_active_enemy_count()))

	if _current_run.run_finished:
		_finish_current_scenario("defeat")
		return

	if _sim_time >= MAX_SIM_TIME:
		if not _logged_timeout:
			_logged_timeout = true
			_finish_current_scenario("timeout")
		return

	if _current_run.gameplay_paused:
		if _current_run.ftue_overlay.visible:
			_current_run._on_ftue_dismissed()
		elif _current_run.mutation_panel.visible:
			_auto_pick_mutation()
		return

	_upgrade_tick -= delta
	if _upgrade_tick <= 0.0:
		_upgrade_tick = 0.18
		_auto_buy_upgrades()

	_skill_tick -= delta
	if _skill_tick <= 0.0:
		_skill_tick = 0.22
		_auto_use_active_skill()

func _build_scenarios() -> void:
	_scenarios = [
		{
			"name": "fresh_sentinel_capillary_balanced",
			"meta_mode": "fresh",
			"core": "sentinel_core",
			"chapter": "chapter_capillary",
			"policy": "balanced",
		},
		{
			"name": "fresh_striker_capillary_aggressive",
			"meta_mode": "fresh",
			"core": "striker_core",
			"chapter": "chapter_capillary",
			"policy": "aggressive",
		},
		{
			"name": "fresh_bastion_capillary_defense",
			"meta_mode": "fresh",
			"core": "bastion_core",
			"chapter": "chapter_capillary",
			"policy": "defensive",
		},
		{
			"name": "fresh_synthesis_capillary_economy",
			"meta_mode": "fresh",
			"core": "synthesis_core",
			"chapter": "chapter_capillary",
			"policy": "economy",
		},
		{
			"name": "fresh_sentinel_synaptic_balanced",
			"meta_mode": "fresh",
			"core": "sentinel_core",
			"chapter": "chapter_synaptic",
			"policy": "balanced",
		},
	]

	var has_current_meta: bool = not _saved_meta.get("meta_levels", {}).is_empty()
	if has_current_meta:
		_scenarios.append({
			"name": "current_profile_sentinel_capillary_balanced",
			"meta_mode": "current",
			"core": "sentinel_core",
			"chapter": "chapter_capillary",
			"policy": "balanced",
		})

func _snapshot_state() -> void:
	_saved_meta = {
		"dna": MetaProgression.dna,
		"best_wave": MetaProgression.best_wave,
		"meta_levels": MetaProgression._meta_levels.duplicate(true),
	}
	_saved_run_profile = {
		"selected_core_archetype": RunConfigManager.selected_core_archetype,
		"selected_chapter": RunConfigManager.selected_chapter,
		"ftue_completed": RunConfigManager.ftue_completed,
	}
	_saved_reward_state = {
		"revive_available": RewardFlowManager.can_use_revive(),
		"dna_boost_available": RewardFlowManager.can_use_dna_boost(),
	}

func _restore_state() -> void:
	MetaProgression.dna = int(_saved_meta.get("dna", 0))
	MetaProgression.best_wave = int(_saved_meta.get("best_wave", 0))
	MetaProgression._meta_levels = (_saved_meta.get("meta_levels", {}) as Dictionary).duplicate(true)
	MetaProgression.dna_changed.emit(MetaProgression.dna)
	MetaProgression.profile_changed.emit()

	RunConfigManager.selected_core_archetype = _saved_run_profile.get("selected_core_archetype", &"sentinel_core")
	RunConfigManager.selected_chapter = _saved_run_profile.get("selected_chapter", &"chapter_capillary")
	RunConfigManager.ftue_completed = bool(_saved_run_profile.get("ftue_completed", false))

	Engine.time_scale = 1.0

func _prepare_profile(meta_mode: String) -> void:
	if meta_mode == "fresh":
		MetaProgression.dna = 0
		MetaProgression.best_wave = 0
		MetaProgression._meta_levels = {}
	else:
		MetaProgression.dna = int(_saved_meta.get("dna", 0))
		MetaProgression.best_wave = int(_saved_meta.get("best_wave", 0))
		MetaProgression._meta_levels = (_saved_meta.get("meta_levels", {}) as Dictionary).duplicate(true)

	MetaProgression.dna_changed.emit(MetaProgression.dna)
	MetaProgression.profile_changed.emit()

func _start_next_scenario() -> void:
	_scenario_index += 1
	if _scenario_index >= _scenarios.size():
		_write_report()
		_restore_state()
		get_tree().quit()
		return

	_current_scenario = _scenarios[_scenario_index]
	_prepare_profile(String(_current_scenario.get("meta_mode", "fresh")))
	RunConfigManager.selected_core_archetype = StringName(_current_scenario.get("core", "sentinel_core"))
	RunConfigManager.selected_chapter = StringName(_current_scenario.get("chapter", "chapter_capillary"))
	RunConfigManager.ftue_completed = true

	_reset_run_metrics()
	_current_run = RUN_SCENE.instantiate()
	add_child(_current_run)

	_current_run.wave_manager.wave_started.connect(_on_wave_started)
	_current_run.wave_manager.wave_cleared.connect(_on_wave_cleared)

	print("PLAYTEST_START ", _current_scenario.get("name", "scenario"))

func _reset_run_metrics() -> void:
	_sim_time = 0.0
	_wave_start_time = 0.0
	_wave_records.clear()
	_upgrade_counts.clear()
	_mutation_picks.clear()
	_min_hp_ratio = 1.0
	_min_shield_ratio = 1.0
	_peak_active_enemies = 0
	_upgrade_tick = 0.15
	_skill_tick = 0.15
	_logged_timeout = false

func _finish_current_scenario(outcome: String) -> void:
	if _current_run == null:
		return

	var summary: Dictionary = {}
	if _current_run.has_method("_refresh_game_over_panel"):
		summary = _current_run._game_over_summary.duplicate(true)
	if summary.is_empty():
		summary = _current_run.resource_manager.build_run_summary()

	var result := {
		"scenario": _current_scenario.get("name", "scenario"),
		"meta_mode": _current_scenario.get("meta_mode", "fresh"),
		"core": _current_scenario.get("core", ""),
		"chapter": _current_scenario.get("chapter", ""),
		"policy": _current_scenario.get("policy", ""),
		"outcome": outcome,
		"sim_time": snapped(_sim_time, 0.01),
		"wave_reached": int(summary.get("wave_reached", _current_run.wave_manager.current_wave)),
		"kills": int(summary.get("kills", _current_run.resource_manager.kills)),
		"elite_kills": int(summary.get("elite_kills", _current_run.resource_manager.elite_kills)),
		"boss_kills": int(summary.get("boss_kills", _current_run.resource_manager.boss_kills)),
		"dna_projection": int(summary.get("dna_earned", _current_run.resource_manager.get_projected_dna())),
		"min_hp_ratio": snapped(_min_hp_ratio, 0.001),
		"min_shield_ratio": snapped(_min_shield_ratio, 0.001),
		"peak_active_enemies": _peak_active_enemies,
		"wave_records": _wave_records.duplicate(true),
		"upgrades": _upgrade_counts.duplicate(true),
		"mutations": _mutation_picks.duplicate(),
		"final_stats": _extract_stats(_current_run.upgrade_manager.get_current_stats()),
	}
	_results.append(result)
	print("PLAYTEST_RESULT ", JSON.stringify(result))

	_current_run.queue_free()
	_current_run = null
	call_deferred("_start_next_scenario")

func _auto_use_active_skill() -> void:
	if _current_run == null:
		return
	if _current_run.core.get_active_skill_cooldown_remaining() > 0.0:
		return
	if _current_run.wave_manager.get_active_enemy_count() < 4:
		return
	_current_run._on_active_skill_requested()

func _auto_buy_upgrades() -> void:
	if _current_run == null:
		return

	var bought: bool = true
	while bought:
		bought = false
		var candidate: UpgradeData = _get_best_affordable_upgrade()
		if candidate == null:
			break
		if _current_run.upgrade_manager.purchase_upgrade(candidate.upgrade_id):
			var key: String = String(candidate.upgrade_id)
			_upgrade_counts[key] = int(_upgrade_counts.get(key, 0)) + 1
			bought = true

func _get_best_affordable_upgrade() -> UpgradeData:
	var best_upgrade: UpgradeData
	var best_score: float = -INF
	for upgrade in ContentDB.get_runtime_upgrades():
		if not _current_run.upgrade_manager.can_purchase(upgrade.upgrade_id):
			continue
		var score: float = _score_upgrade(upgrade)
		if score > best_score:
			best_score = score
			best_upgrade = upgrade
	return best_upgrade

func _score_upgrade(upgrade: UpgradeData) -> float:
	var weights: Dictionary = _get_policy_weights(String(_current_scenario.get("policy", "balanced")))
	var base_weight: float = float(weights.get(String(upgrade.upgrade_id), 0.15))
	var current_level: int = _current_run.upgrade_manager.get_runtime_level(upgrade.upgrade_id)
	var next_cost: int = max(_current_run.upgrade_manager.get_next_cost(upgrade.upgrade_id), 1)
	var hp_ratio: float = _get_core_hp_ratio()
	var wave: int = max(1, _current_run.wave_manager.current_wave)

	if upgrade.category == &"defense" and hp_ratio < 0.55:
		base_weight *= 1.45
	if upgrade.category == &"utility" and wave <= 4:
		base_weight *= 1.18
	if upgrade.category == &"attack" and _current_run.wave_manager.get_active_enemy_count() >= 8:
		if upgrade.stat_key == &"projectile_count" or upgrade.stat_key == &"bounce_targets" or upgrade.stat_key == &"secondary_projectile_chance":
			base_weight *= 1.2

	return base_weight / pow(1.17, current_level) / pow(float(next_cost), 0.62)

func _get_policy_weights(policy: String) -> Dictionary:
	match policy:
		"aggressive":
			return {
				"runtime_damage": 1.0,
				"runtime_attack_speed": 0.98,
				"runtime_projectile_speed": 0.8,
				"runtime_crit_chance": 0.7,
				"runtime_crit_damage": 0.68,
				"runtime_secondary_projectile": 0.82,
				"runtime_projectile_count": 0.86,
				"runtime_rapid_fire_chance": 0.72,
				"runtime_rapid_fire_duration": 0.62,
				"runtime_bounce_chance": 0.64,
				"runtime_bounce_targets": 0.58,
				"runtime_range": 0.44,
				"runtime_max_hp": 0.52,
				"runtime_armor": 0.42,
				"runtime_regeneration": 0.33,
				"runtime_atp_gain": 0.58,
				"runtime_atp_per_wave": 0.54,
				"runtime_targeting_range": 0.42,
			}
		"defensive":
			return {
				"runtime_max_hp": 1.0,
				"runtime_armor": 0.96,
				"runtime_regeneration": 0.88,
				"runtime_shield_max": 0.86,
				"runtime_shield_regeneration": 0.76,
				"runtime_contact_resistance": 0.82,
				"runtime_absolute_defense": 0.82,
				"runtime_contact_retaliation": 0.62,
				"runtime_damage": 0.68,
				"runtime_attack_speed": 0.52,
				"runtime_projectile_speed": 0.34,
				"runtime_atp_gain": 0.44,
				"runtime_atp_per_wave": 0.4,
				"runtime_targeting_range": 0.34,
			}
		"economy":
			return {
				"runtime_atp_gain": 1.0,
				"runtime_atp_per_wave": 0.92,
				"runtime_atp_interest": 0.82,
				"runtime_pickup_radius": 0.76,
				"runtime_targeting_range": 0.66,
				"runtime_random_attack_progress": 0.72,
				"runtime_random_defense_progress": 0.68,
				"runtime_random_utility_progress": 0.74,
				"runtime_auto_evolution_cycle": 0.72,
				"runtime_damage": 0.72,
				"runtime_attack_speed": 0.62,
				"runtime_max_hp": 0.56,
				"runtime_armor": 0.46,
				"runtime_regeneration": 0.4,
				"runtime_dna_gain": 0.54,
				"runtime_dna_crystal_frequency": 0.56,
			}
		_:
			return {
				"runtime_damage": 1.0,
				"runtime_attack_speed": 0.96,
				"runtime_max_hp": 0.86,
				"runtime_armor": 0.78,
				"runtime_regeneration": 0.68,
				"runtime_atp_gain": 0.72,
				"runtime_atp_per_wave": 0.64,
				"runtime_projectile_speed": 0.62,
				"runtime_targeting_range": 0.58,
				"runtime_pickup_radius": 0.48,
				"runtime_crit_chance": 0.56,
				"runtime_crit_damage": 0.48,
				"runtime_secondary_projectile": 0.62,
				"runtime_projectile_count": 0.7,
				"runtime_range": 0.44,
				"runtime_shield_max": 0.5,
				"runtime_shield_regeneration": 0.42,
				"runtime_contact_resistance": 0.46,
				"runtime_absolute_defense": 0.44,
			}

func _auto_pick_mutation() -> void:
	var options: Array = _current_run.mutation_manager._offered_choices
	if options.is_empty():
		return
	var best_mutation: MutationData = options[0]
	var best_score: float = -INF
	for option in options:
		var mutation := option as MutationData
		var score: float = _score_mutation(mutation)
		if score > best_score:
			best_score = score
			best_mutation = mutation
	_mutation_picks.append(String(best_mutation.mutation_id))
	_current_run._on_mutation_selected(best_mutation.mutation_id)

func _score_mutation(mutation: MutationData) -> float:
	var score: float = 0.15
	var band: Dictionary = ContentDB.get_wave_rules().get_band_for_wave(max(1, _current_run.wave_manager.current_wave + 1))
	var weights: Dictionary = band.get("enemy_weights", {}) as Dictionary
	var virus_weight: float = 0.0
	var bacteria_weight: float = 0.0
	for key in weights.keys():
		var enemy_data = ContentDB.get_enemy(StringName(key))
		if enemy_data == null:
			continue
		if enemy_data.family == &"virus":
			virus_weight += float(weights[key])
		elif enemy_data.family == &"bacteria":
			bacteria_weight += float(weights[key])

	score += mutation.damage_vs_virus_bonus * (1.4 + virus_weight)
	score += mutation.damage_vs_bacteria_bonus * (1.35 + bacteria_weight)
	score += mutation.splash_chance * (1.8 + mutation.splash_damage_multiplier)
	score += mutation.secondary_projectile_chance * 2.0
	score += mutation.slow_aura_strength * 1.7
	score += mutation.regeneration_bonus * 0.26
	score -= mutation.attack_speed_penalty * 1.8

	var policy: String = String(_current_scenario.get("policy", "balanced"))
	if policy == "defensive":
		score += mutation.regeneration_bonus * 0.28
		score += mutation.slow_aura_strength * 0.9
	if policy == "aggressive":
		score += mutation.secondary_projectile_chance * 0.9
		score += mutation.splash_chance * 0.6
	if _get_core_hp_ratio() < 0.55:
		score += mutation.regeneration_bonus * 0.35
		score += mutation.slow_aura_strength * 0.75

	return score

func _on_wave_started(_wave: int) -> void:
	_wave_start_time = _sim_time

func _on_wave_cleared(wave: int, rewards: Dictionary) -> void:
	_wave_records.append({
		"wave": wave,
		"clear_time": snapped(_sim_time - _wave_start_time, 0.01),
		"hp_ratio": snapped(_get_core_hp_ratio(), 0.001),
		"shield_ratio": snapped(_get_core_shield_ratio(), 0.001),
		"atp": _current_run.resource_manager.atp,
		"reward_atp": int(rewards.get("total_atp_bonus", 0)),
		"reward_dna": int(rewards.get("dna_wave_bonus", 0)),
	})

func _get_core_hp_ratio() -> float:
	var stats: RunStats = _current_run.core.get_current_stats()
	if stats.max_hp <= 0.0:
		return 0.0
	return _current_run.core.get_current_health() / stats.max_hp

func _get_core_shield_ratio() -> float:
	var stats: RunStats = _current_run.core.get_current_stats()
	if stats.shield_max <= 0.0:
		return 0.0
	return _current_run.core.get_current_shield() / stats.shield_max

func _extract_stats(stats: RunStats) -> Dictionary:
	return {
		"damage": snapped(stats.damage, 0.01),
		"attack_speed": snapped(stats.attack_speed, 0.01),
		"projectile_count": stats.projectile_count,
		"crit_chance": snapped(stats.crit_chance, 0.001),
		"crit_damage": snapped(stats.crit_damage, 0.01),
		"projectile_speed": snapped(stats.projectile_speed, 0.01),
		"range": snapped(stats.projectile_range, 0.01),
		"targeting_range": snapped(stats.targeting_range, 0.01),
		"max_hp": snapped(stats.max_hp, 0.01),
		"armor": snapped(stats.armor, 0.001),
		"regeneration": snapped(stats.regeneration, 0.01),
		"shield_max": snapped(stats.shield_max, 0.01),
		"shield_regeneration": snapped(stats.shield_regeneration, 0.01),
		"atp_gain_multiplier": snapped(stats.atp_gain_multiplier, 0.01),
		"pickup_radius": snapped(stats.pickup_radius, 0.01),
		"damage_vs_virus_bonus": snapped(stats.damage_vs_virus_bonus, 0.01),
		"damage_vs_bacteria_bonus": snapped(stats.damage_vs_bacteria_bonus, 0.01),
		"secondary_projectile_chance": snapped(stats.secondary_projectile_chance, 0.01),
		"splash_chance": snapped(stats.splash_chance, 0.01),
		"slow_aura_strength": snapped(stats.slow_aura_strength, 0.01),
	}

func _write_report() -> void:
	var report := {
		"generated_at": Time.get_datetime_string_from_system(),
		"time_scale": TIME_SCALE,
		"max_sim_time": MAX_SIM_TIME,
		"results": _results,
	}
	var path: String = ProjectSettings.globalize_path(REPORT_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("PLAYTEST_REPORT ", path)
