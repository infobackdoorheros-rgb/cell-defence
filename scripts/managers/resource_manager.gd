extends Node
class_name ResourceManager

const EnemyData = preload("res://scripts/data/enemy_data.gd")

signal atp_changed(current_atp: int)
signal dna_projection_changed(projected_dna: int)
signal kill_stats_changed(kills: int, elite_kills: int, boss_kills: int)

var atp: int = 0
var wave_reached: int = 1
var dna_bonus: int = 0
var dna_pickups_collected: int = 0
var dna_gain_multiplier: float = 1.0
var chapter_dna_multiplier: float = 1.0
var kills: int = 0
var elite_kills: int = 0
var boss_kills: int = 0

func reset_run() -> void:
	atp = max(0, RemoteConfigManager.get_int("economy.starting_atp", 0))
	wave_reached = 1
	dna_bonus = 0
	dna_pickups_collected = 0
	dna_gain_multiplier = 1.0
	chapter_dna_multiplier = 1.0
	kills = 0
	elite_kills = 0
	boss_kills = 0
	atp_changed.emit(atp)
	dna_projection_changed.emit(get_projected_dna())
	kill_stats_changed.emit(kills, elite_kills, boss_kills)

func add_atp(amount: int) -> void:
	atp += amount
	atp_changed.emit(atp)

func add_runtime_dna(amount: int) -> void:
	dna_bonus += amount
	dna_pickups_collected += amount
	dna_projection_changed.emit(get_projected_dna())

func set_dna_gain_multiplier(multiplier: float) -> void:
	dna_gain_multiplier = max(multiplier, 0.2)
	dna_projection_changed.emit(get_projected_dna())

func set_chapter_dna_multiplier(multiplier: float) -> void:
	chapter_dna_multiplier = max(multiplier, 0.5)
	dna_projection_changed.emit(get_projected_dna())

func spend_atp(amount: int) -> bool:
	if amount > atp:
		return false
	atp -= amount
	atp_changed.emit(atp)
	return true

func register_enemy_defeat(enemy_data: EnemyData, stats = null) -> void:
	kills += 1
	dna_bonus += enemy_data.dna_reward
	if stats != null:
		dna_bonus += int(round(float(stats.dna_bonus_per_kill)))

	match enemy_data.tier:
		&"elite":
			elite_kills += 1
		&"boss":
			boss_kills += 1

	kill_stats_changed.emit(kills, elite_kills, boss_kills)
	DailyMissionManager.register_enemy_defeat(enemy_data.tier)
	BattlePassManager.register_enemy_defeat(enemy_data.tier)
	var chapter_multiplier: float = 1.0
	var chapter = RunConfigManager.get_selected_chapter()
	if chapter != null:
		chapter_multiplier = chapter.event_point_multiplier
	SeasonEventManager.register_enemy_defeat(enemy_data.tier, chapter_multiplier)
	dna_projection_changed.emit(get_projected_dna())

func grant_wave_clear_rewards(cleared_wave: int, stats) -> Dictionary:
	var base_atp_wave_bonus: int = RemoteConfigManager.get_int("economy.base_atp_per_wave", 0)
	var atp_wave_growth: float = RemoteConfigManager.get_float("economy.atp_per_wave_growth", 0.0)
	var base_dna_wave_bonus: int = RemoteConfigManager.get_int("economy.base_dna_per_wave", 0)
	var dna_wave_growth: float = RemoteConfigManager.get_float("economy.dna_per_wave_growth", 0.0)
	var atp_wave_bonus: int = base_atp_wave_bonus + int(round(float(max(cleared_wave - 1, 0)) * atp_wave_growth))
	var atp_interest_bonus: int = 0
	var dna_wave_bonus: int = base_dna_wave_bonus + int(round(float(max(cleared_wave - 1, 0)) * dna_wave_growth))
	if stats != null:
		atp_wave_bonus += int(round(float(stats.atp_per_wave)))
		atp_interest_bonus = int(round(float(atp) * float(stats.atp_interest_per_wave)))
		dna_wave_bonus += int(round(float(stats.dna_per_wave)))

	var total_atp: int = atp_wave_bonus + atp_interest_bonus
	if total_atp > 0:
		add_atp(total_atp)
	if dna_wave_bonus > 0:
		dna_bonus += dna_wave_bonus
		dna_projection_changed.emit(get_projected_dna())

	return {
		"wave": cleared_wave,
		"atp_wave_bonus": atp_wave_bonus,
		"atp_interest_bonus": atp_interest_bonus,
		"dna_wave_bonus": dna_wave_bonus,
		"total_atp_bonus": total_atp
	}

func set_wave_reached(wave: int) -> void:
	wave_reached = max(wave_reached, wave)
	DailyMissionManager.register_wave_reached(wave_reached)
	BattlePassManager.register_wave_reached(wave_reached)
	dna_projection_changed.emit(get_projected_dna())

func get_projected_dna() -> int:
	var base_dna: int = max(1, (wave_reached * 2) + dna_bonus)
	var remote_scale: float = max(0.2, RemoteConfigManager.get_float("economy.dna_payout_scale", 1.0))
	return max(1, int(round(float(base_dna) * dna_gain_multiplier * chapter_dna_multiplier * remote_scale)))

func commit_run_rewards(multiplier: float = 1.0) -> int:
	var dna_earned: int = max(1, int(round(float(get_projected_dna()) * max(multiplier, 1.0))))
	MetaProgression.add_dna(dna_earned)
	MetaProgression.register_wave_result(wave_reached)
	return dna_earned

func build_run_summary() -> Dictionary:
	return {
		"wave_reached": wave_reached,
		"kills": kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills,
		"dna_pickups": dna_pickups_collected,
		"dna_earned": get_projected_dna(),
		"best_wave": max(MetaProgression.best_wave, wave_reached)
	}

func get_snapshot_state() -> Dictionary:
	return {
		"atp": atp,
		"wave_reached": wave_reached,
		"dna_bonus": dna_bonus,
		"dna_pickups_collected": dna_pickups_collected,
		"dna_gain_multiplier": dna_gain_multiplier,
		"chapter_dna_multiplier": chapter_dna_multiplier,
		"kills": kills,
		"elite_kills": elite_kills,
		"boss_kills": boss_kills
	}

func restore_snapshot_state(data: Dictionary) -> void:
	atp = max(0, int(data.get("atp", atp)))
	wave_reached = max(1, int(data.get("wave_reached", wave_reached)))
	dna_bonus = max(0, int(data.get("dna_bonus", dna_bonus)))
	dna_pickups_collected = max(0, int(data.get("dna_pickups_collected", dna_pickups_collected)))
	dna_gain_multiplier = max(0.2, float(data.get("dna_gain_multiplier", dna_gain_multiplier)))
	chapter_dna_multiplier = max(0.5, float(data.get("chapter_dna_multiplier", chapter_dna_multiplier)))
	kills = max(0, int(data.get("kills", kills)))
	elite_kills = max(0, int(data.get("elite_kills", elite_kills)))
	boss_kills = max(0, int(data.get("boss_kills", boss_kills)))
	atp_changed.emit(atp)
	dna_projection_changed.emit(get_projected_dna())
	kill_stats_changed.emit(kills, elite_kills, boss_kills)
