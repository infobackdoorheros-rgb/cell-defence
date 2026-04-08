extends Node

signal config_reloaded

const CONFIG_PATH := "res://data/config/remote_config.json"
const OVERRIDE_PATH := "user://remote_config_override.json"

var _config: Dictionary = {}

func _ready() -> void:
	reload_config()

func reload_config() -> void:
	var merged: Dictionary = _get_default_config()
	merged = _deep_merge(merged, _read_json_dictionary(CONFIG_PATH))
	merged = _deep_merge(merged, _read_json_dictionary(OVERRIDE_PATH))
	_config = merged
	config_reloaded.emit()

func get_snapshot() -> Dictionary:
	return _config.duplicate(true)

func get_dictionary(path: String, default_value: Dictionary = {}) -> Dictionary:
	var value: Variant = _get_value(path, default_value)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return default_value.duplicate(true)

func get_array(path: String, default_value: Array = []) -> Array:
	var value: Variant = _get_value(path, default_value)
	if value is Array:
		return (value as Array).duplicate(true)
	return default_value.duplicate(true)

func get_float(path: String, default_value: float = 0.0) -> float:
	return float(_get_value(path, default_value))

func get_int(path: String, default_value: int = 0) -> int:
	return int(_get_value(path, default_value))

func get_bool(path: String, default_value: bool = false) -> bool:
	return bool(_get_value(path, default_value))

func get_string(path: String, default_value: String = "") -> String:
	return String(_get_value(path, default_value))

func _get_value(path: String, default_value: Variant) -> Variant:
	if path.is_empty():
		return _config

	var cursor: Variant = _config
	for segment in path.split("."):
		if not (cursor is Dictionary):
			return default_value
		var dictionary := cursor as Dictionary
		if not dictionary.has(segment):
			return default_value
		cursor = dictionary[segment]
	return cursor

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in override.keys():
		var base_value: Variant = result.get(key)
		var override_value: Variant = override[key]
		if base_value is Dictionary and override_value is Dictionary:
			result[key] = _deep_merge(base_value as Dictionary, override_value as Dictionary)
		else:
			result[key] = override_value
	return result

func _get_default_config() -> Dictionary:
	return {
		"economy": {
			"runtime_atp_scale": 1.08,
			"dna_payout_scale": 1.0,
			"starting_atp": 13,
			"base_atp_per_wave": 4,
			"atp_per_wave_growth": 1.0,
			"base_dna_per_wave": 0,
			"dna_per_wave_growth": 0.0
		},
		"combat": {
			"enemy_health_scale": 1.0,
			"enemy_speed_scale": 1.0,
			"spawn_density_scale": 1.0
		},
		"reward_flow": {
			"revive_charges": 1,
			"dna_boost_charges": 1,
			"dna_boost_multiplier": 2.0
		},
		"battle_pass": {
			"season_id": "adaptive_response_alpha",
			"kill_xp": 1,
			"elite_xp": 4,
			"boss_xp": 10,
			"wave_xp": 3,
			"mutation_xp": 6,
			"tier_targets": [20, 42, 68, 98, 132, 170, 212, 258],
			"tier_rewards": [6, 8, 10, 12, 14, 18, 22, 28]
		},
		"offers": {
			"cards": [
				{
					"id": "starter_sample_kit",
					"reward_type": "dna",
					"reward_amount": 30,
					"refresh": "once"
				},
				{
					"id": "response_drop",
					"reward_type": "dna",
					"reward_amount": 14,
					"refresh": "daily"
				},
				{
					"id": "spore_exchange",
					"reward_type": "season_event_points",
					"reward_amount": 18,
					"refresh": "daily"
				},
				{
					"id": "pass_booster",
					"reward_type": "battle_pass_xp",
					"reward_amount": 22,
					"refresh": "daily"
				}
			]
		}
	}
