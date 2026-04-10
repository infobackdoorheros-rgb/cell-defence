extends Node

const RunStats = preload("res://scripts/core/run_stats.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")

signal dna_changed(current_dna: int)
signal profile_changed

var dna: int = 0
var best_wave: int = 0
var _meta_levels: Dictionary = {}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var save_data := SaveManager.get_save()
	dna = int(save_data.get("dna", 0))
	best_wave = int(save_data.get("best_wave", 0))
	_meta_levels = (save_data.get("meta_levels", {}) as Dictionary).duplicate(true)
	dna_changed.emit(dna)
	profile_changed.emit()

func save_profile() -> void:
	SaveManager.write_save({
		"dna": dna,
		"best_wave": best_wave,
		"meta_levels": _meta_levels
	})

func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(_meta_levels.get(String(upgrade_id), 0))

func get_cost_for_next_level(upgrade_id: StringName) -> int:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null:
		return 0
	return data.get_cost_for_level(get_upgrade_level(upgrade_id) + 1)

func can_purchase(upgrade_id: StringName) -> bool:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null or data.layer != &"meta":
		return false
	var current_level := get_upgrade_level(upgrade_id)
	if current_level >= data.max_level:
		return false
	return dna >= data.get_cost_for_level(current_level + 1)

func purchase_meta_upgrade(upgrade_id: StringName) -> bool:
	var data := ContentDB.get_upgrade(upgrade_id)
	if data == null or data.layer != &"meta":
		return false

	var current_level := get_upgrade_level(upgrade_id)
	if current_level >= data.max_level:
		return false

	var cost := data.get_cost_for_level(current_level + 1)
	if dna < cost:
		return false

	dna -= cost
	_meta_levels[String(upgrade_id)] = current_level + 1
	AnalyticsManager.track_event(&"meta_upgrade_purchased", {
		"upgrade_id": String(upgrade_id),
		"next_level": current_level + 1,
		"cost": cost
	})
	save_profile()
	dna_changed.emit(dna)
	profile_changed.emit()
	return true

func add_dna(amount: int) -> void:
	dna += amount
	save_profile()
	dna_changed.emit(dna)
	profile_changed.emit()

func reset_progress() -> void:
	SaveManager.reset_game_progress()
	load_profile()
	RunConfigManager.reset_profile()
	DailyMissionManager.load_state()
	SeasonEventManager.load_state()
	BattlePassManager.load_state()
	OfferManager.load_state()
	ShopManager.load_state()
	AnalyticsManager.load_state()

func register_wave_result(wave_reached: int) -> void:
	if wave_reached > best_wave:
		best_wave = wave_reached
		save_profile()
		profile_changed.emit()

func is_mutation_unlocked(mutation_id: StringName) -> bool:
	var mutation := ContentDB.get_mutation(mutation_id)
	if mutation == null:
		return false
	if mutation.starts_unlocked:
		return true

	for upgrade in ContentDB.get_meta_upgrades():
		if upgrade.unlocks_mutation_id == mutation_id and get_upgrade_level(upgrade.upgrade_id) > 0:
			return true
	return false

func get_unlocked_mutation_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for mutation in ContentDB.get_all_mutations():
		if is_mutation_unlocked(mutation.mutation_id):
			ids.append(String(mutation.mutation_id))
	return ids

func build_persistent_run_stats() -> RunStats:
	var stats := RunStats.new()
	for upgrade in ContentDB.get_meta_upgrades():
		if upgrade.stat_key == &"":
			continue
		var level := get_upgrade_level(upgrade.upgrade_id)
		if level <= 0:
			continue
		stats.apply_stat_bonus(upgrade.stat_key, upgrade.get_bonus_for_level(level))
	stats.finalize()
	return stats

func get_upgrade_bonus_text(upgrade: UpgradeData) -> String:
	if upgrade == null:
		return ""
	var level := get_upgrade_level(upgrade.upgrade_id)
	if level <= 0:
		return "Bonus attuale: nessuno"

	var total_bonus := upgrade.get_bonus_for_level(level)
	if upgrade.display_as_percent:
		return "Bonus attuale: +%d%%" % int(round(total_bonus * 100.0))

	if upgrade.stat_key == &"attack_speed":
		return "Bonus attuale: +%.2f colpi/s" % total_bonus
	if upgrade.stat_key == &"regeneration":
		return "Bonus attuale: +%.1f HP/s" % total_bonus
	if upgrade.stat_key == &"damage":
		return "Bonus attuale: +%.1f danni" % total_bonus
	if upgrade.stat_key == &"damage_vs_virus_bonus":
		return "Bonus attuale: +%d%% vs virus" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"damage_vs_bacteria_bonus":
		return "Bonus attuale: +%d%% vs batteri" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"crit_chance":
		return "Bonus attuale: +%d%% crit" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"projectile_speed":
		return "Bonus attuale: +%.0f velocita" % total_bonus
	if upgrade.stat_key == &"max_hp":
		return "Bonus attuale: +%.0f HP" % total_bonus
	if upgrade.stat_key == &"armor":
		return "Bonus attuale: +%d%% riduzione" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"shield_max":
		return "Bonus attuale: +%.0f scudo" % total_bonus
	if upgrade.stat_key == &"shield_regeneration":
		return "Bonus attuale: +%.1f scudo/s" % total_bonus
	if upgrade.stat_key == &"contact_retaliation":
		return "Bonus attuale: +%.0f riflessi" % total_bonus
	if upgrade.stat_key == &"dna_gain_multiplier":
		return "Bonus attuale: +%d%% DNA" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"dna_crystal_spawn_bonus":
		return "Bonus attuale: +%d%% spawn DNA" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"auto_upgrade_interval_reduction":
		return "Bonus attuale: -%d%% intervallo" % int(round(total_bonus * 100.0))
	if upgrade.stat_key == &"pickup_radius" or upgrade.stat_key == &"projectile_range" or upgrade.stat_key == &"targeting_range":
		return "Bonus attuale: +%.0f raggio" % total_bonus

	return "Bonus attuale: +%.2f" % total_bonus
