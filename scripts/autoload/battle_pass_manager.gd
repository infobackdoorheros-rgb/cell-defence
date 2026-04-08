extends Node

signal progress_changed
signal tier_completed(index: int, target: int)
signal tier_claimed(index: int, reward_dna: int)

var _season_id: StringName = &"adaptive_response_alpha"
var _display_name: String = ""
var _subtitle: String = ""
var _progress: int = 0
var _kill_xp: int = 1
var _elite_xp: int = 4
var _boss_xp: int = 10
var _wave_xp: int = 3
var _mutation_xp: int = 6
var _tier_targets: Array[int] = []
var _tier_rewards: Array[int] = []
var _claimed_tiers: Array[bool] = []

func _ready() -> void:
	if not RemoteConfigManager.config_reloaded.is_connected(_on_config_reloaded):
		RemoteConfigManager.config_reloaded.connect(_on_config_reloaded)
	_apply_config()
	load_state()

func load_state() -> void:
	var save_data := SaveManager.get_save()
	var state := save_data.get("battle_pass", {}) as Dictionary
	var saved_season := StringName(state.get("season_id", String(_season_id)))

	_progress = 0
	_claimed_tiers.clear()
	for _index in range(_tier_targets.size()):
		_claimed_tiers.append(false)

	if saved_season == _season_id:
		_progress = int(state.get("progress", 0))
		var raw_claims := state.get("claimed_tiers", []) as Array
		for index in range(min(raw_claims.size(), _claimed_tiers.size())):
			_claimed_tiers[index] = bool(raw_claims[index])

	progress_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"battle_pass": {
			"season_id": String(_season_id),
			"progress": _progress,
			"claimed_tiers": _claimed_tiers
		}
	})

func register_enemy_defeat(enemy_tier: StringName) -> void:
	match enemy_tier:
		&"elite":
			add_progress(_elite_xp)
		&"boss":
			add_progress(_boss_xp)
		_:
			add_progress(_kill_xp)

func register_wave_reached(_wave: int) -> void:
	add_progress(_wave_xp)

func register_mutation_selected() -> void:
	add_progress(_mutation_xp)

func add_progress(amount: int) -> void:
	if amount <= 0:
		return
	var previous_progress := _progress
	_progress += amount
	for index in range(_tier_targets.size()):
		var target := _tier_targets[index]
		if previous_progress < target and _progress >= target:
			tier_completed.emit(index, target)
	save_state()
	progress_changed.emit()

func claim_tier(index: int) -> int:
	if index < 0 or index >= _tier_targets.size():
		return 0
	if _claimed_tiers[index]:
		return 0
	if _progress < _tier_targets[index]:
		return 0

	_claimed_tiers[index] = true
	var reward_dna := _tier_rewards[index]
	if reward_dna > 0:
		MetaProgression.add_dna(reward_dna)
	AnalyticsManager.track_event(&"battle_pass_claimed", {
		"tier_index": index,
		"reward_dna": reward_dna
	})
	save_state()
	progress_changed.emit()
	tier_claimed.emit(index, reward_dna)
	return reward_dna

func get_overview() -> Dictionary:
	var tiers: Array[Dictionary] = []
	for index in range(_tier_targets.size()):
		tiers.append({
			"index": index,
			"target": _tier_targets[index],
			"reward_dna": _tier_rewards[index],
			"claimed": _claimed_tiers[index],
			"reached": _progress >= _tier_targets[index]
		})

	var next_target := 0
	for target in _tier_targets:
		if _progress < target:
			next_target = target
			break

	return {
		"season_id": _season_id,
		"display_name": _display_name,
		"subtitle": _subtitle,
		"progress": _progress,
		"max_target": 0 if _tier_targets.is_empty() else _tier_targets[_tier_targets.size() - 1],
		"next_target": next_target,
		"tiers": tiers
	}

func get_claimable_tier_count() -> int:
	var total := 0
	for index in range(_tier_targets.size()):
		if _claimed_tiers[index]:
			continue
		if _progress >= _tier_targets[index]:
			total += 1
	return total

func _on_config_reloaded() -> void:
	var previous_season := _season_id
	_apply_config()
	if previous_season != _season_id:
		load_state()
		return

	var previous_claims := _claimed_tiers.duplicate()
	_claimed_tiers.clear()
	for index in range(_tier_targets.size()):
		var claimed := index < previous_claims.size() and bool(previous_claims[index])
		_claimed_tiers.append(claimed)
	save_state()
	progress_changed.emit()

func _apply_config() -> void:
	var section := RemoteConfigManager.get_dictionary("battle_pass")
	_season_id = StringName(section.get("season_id", "adaptive_response_alpha"))
	_display_name = SettingsManager.t("ops.pass.name")
	_subtitle = SettingsManager.t("ops.pass.subtitle")
	_kill_xp = max(1, int(section.get("kill_xp", 1)))
	_elite_xp = max(_kill_xp, int(section.get("elite_xp", 4)))
	_boss_xp = max(_elite_xp, int(section.get("boss_xp", 10)))
	_wave_xp = max(1, int(section.get("wave_xp", 3)))
	_mutation_xp = max(1, int(section.get("mutation_xp", 6)))

	_tier_targets.clear()
	_tier_rewards.clear()
	for value in section.get("tier_targets", []) as Array:
		_tier_targets.append(int(value))
	for value in section.get("tier_rewards", []) as Array:
		_tier_rewards.append(int(value))
	while _tier_rewards.size() < _tier_targets.size():
		_tier_rewards.append(10)
