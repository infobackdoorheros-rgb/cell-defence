extends Node

signal rewards_reset

var revive_uses_this_run: int = 0
var dna_boost_uses_this_run: int = 0

func reset_run() -> void:
	revive_uses_this_run = 0
	dna_boost_uses_this_run = 0
	rewards_reset.emit()

func can_use_revive() -> bool:
	return revive_uses_this_run < get_revive_charges()

func can_use_dna_boost() -> bool:
	return dna_boost_uses_this_run < get_dna_boost_charges()

func consume_revive() -> bool:
	if not can_use_revive():
		return false
	revive_uses_this_run += 1
	return true

func consume_dna_boost() -> bool:
	if not can_use_dna_boost():
		return false
	dna_boost_uses_this_run += 1
	return true

func get_revive_charges() -> int:
	return max(0, RemoteConfigManager.get_int("reward_flow.revive_charges", 1))

func get_dna_boost_charges() -> int:
	return max(0, RemoteConfigManager.get_int("reward_flow.dna_boost_charges", 1))

func get_dna_boost_multiplier() -> float:
	return max(1.0, RemoteConfigManager.get_float("reward_flow.dna_boost_multiplier", 2.0))
