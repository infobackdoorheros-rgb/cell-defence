extends Node

signal missions_changed
signal mission_completed(mission_id: StringName)
signal reward_claimed(mission_id: StringName, reward_dna: int)

const DAILY_MISSION_COUNT := 3

const _MISSION_POOL := [
	{"id": "kill_swarm", "kind": "kills", "target": 30, "reward_dna": 10},
	{"id": "reach_wave_8", "kind": "wave", "target": 8, "reward_dna": 12},
	{"id": "buy_runtime_upgrades", "kind": "runtime_upgrades", "target": 5, "reward_dna": 9},
	{"id": "choose_mutations", "kind": "mutations", "target": 2, "reward_dna": 8},
	{"id": "clear_boss_wave", "kind": "bosses", "target": 1, "reward_dna": 14}
]

var _date_key: String = ""
var _missions: Array[Dictionary] = []

func _ready() -> void:
	load_state()

func load_state() -> void:
	var save_data := SaveManager.get_save()
	var mission_state := save_data.get("daily_missions", {}) as Dictionary
	_date_key = String(mission_state.get("date_key", ""))
	var raw_missions := mission_state.get("missions", []) as Array
	_missions.clear()
	for item in raw_missions:
		if item is Dictionary:
			_missions.append((item as Dictionary).duplicate(true))
	_sync_date(true)

func _sync_date(emit_signal: bool = false) -> void:
	var today_key := _get_today_key()
	if _date_key == today_key and not _missions.is_empty():
		return

	_date_key = today_key
	_missions = _generate_missions(today_key)
	save_state()
	if emit_signal:
		missions_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"daily_missions": {
			"date_key": _date_key,
			"missions": _missions
		}
	})

func get_missions() -> Array[Dictionary]:
	_sync_date()
	var result: Array[Dictionary] = []
	for mission in _missions:
		result.append(mission.duplicate(true))
	return result

func claim_reward(mission_id: StringName) -> int:
	for mission in _missions:
		if StringName(mission.get("id", "")) != mission_id:
			continue
		if not bool(mission.get("completed", false)) or bool(mission.get("claimed", false)):
			return 0
		mission["claimed"] = true
		var reward_dna: int = int(mission.get("reward_dna", 0))
		if reward_dna > 0:
			MetaProgression.add_dna(reward_dna)
		AnalyticsManager.track_event(&"daily_reward_claimed", {
			"mission_id": String(mission_id),
			"reward_dna": reward_dna
		})
		save_state()
		reward_claimed.emit(mission_id, reward_dna)
		missions_changed.emit()
		return reward_dna
	return 0

func register_enemy_defeat(enemy_tier: StringName) -> void:
	_increment(&"kills", 1)
	if enemy_tier == &"boss":
		_increment(&"bosses", 1)

func register_wave_reached(wave: int) -> void:
	_set_highest(&"wave", wave)

func register_runtime_upgrade_purchase() -> void:
	_increment(&"runtime_upgrades", 1)

func register_mutation_selected() -> void:
	_increment(&"mutations", 1)

func _generate_missions(date_key: String) -> Array[Dictionary]:
	var seed_value: int = int(hash(date_key))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var pool := _MISSION_POOL.duplicate(true)
	var generated: Array[Dictionary] = []
	while generated.size() < DAILY_MISSION_COUNT and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		var template := pool[index] as Dictionary
		generated.append({
			"id": template.get("id", ""),
			"kind": template.get("kind", ""),
			"target": template.get("target", 1),
			"progress": 0,
			"reward_dna": template.get("reward_dna", 0),
			"completed": false,
			"claimed": false
		})
		pool.remove_at(index)
	return generated

func _increment(kind: StringName, amount: int) -> void:
	var changed := false
	for mission in _missions:
		if StringName(mission.get("kind", "")) != kind:
			continue
		if bool(mission.get("claimed", false)):
			continue
		var previous_progress: int = int(mission.get("progress", 0))
		var next_progress: int = min(int(mission.get("target", 1)), previous_progress + amount)
		if next_progress == previous_progress:
			continue
		mission["progress"] = next_progress
		_update_completion(mission)
		changed = true
	if changed:
		save_state()
		missions_changed.emit()

func _set_highest(kind: StringName, value: int) -> void:
	var changed := false
	for mission in _missions:
		if StringName(mission.get("kind", "")) != kind:
			continue
		if bool(mission.get("claimed", false)):
			continue
		var previous_progress: int = int(mission.get("progress", 0))
		var next_progress: int = min(int(mission.get("target", 1)), max(previous_progress, value))
		if next_progress == previous_progress:
			continue
		mission["progress"] = next_progress
		_update_completion(mission)
		changed = true
	if changed:
		save_state()
		missions_changed.emit()

func _update_completion(mission: Dictionary) -> void:
	if bool(mission.get("completed", false)):
		return
	if int(mission.get("progress", 0)) < int(mission.get("target", 1)):
		return
	mission["completed"] = true
	mission_completed.emit(StringName(mission.get("id", "")))

func _get_today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]
