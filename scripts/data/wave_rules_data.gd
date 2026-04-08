extends Resource
class_name WaveRulesData

@export var boss_interval: int = 10
@export var mutation_interval: int = 4
@export var initial_spawn_count: int = 8
@export var spawn_count_per_wave: float = 1.8
@export var base_spawn_interval: float = 0.72
@export var min_spawn_interval: float = 0.22
@export var health_scale_per_wave: float = 0.12
@export var speed_scale_per_wave: float = 0.02
@export var elite_start_wave: int = 6
@export var elite_base_chance: float = 0.06
@export var elite_chance_per_wave: float = 0.01
@export var boss_id: StringName = &"boss_parasite_queen"
@export var boss_support_count: int = 6
@export var bands: Array[Dictionary] = []

func get_band_for_wave(wave: int) -> Dictionary:
	for band in bands:
		var start_wave: int = int(band.get("start_wave", 1))
		var end_wave: int = int(band.get("end_wave", 9999))
		if wave >= start_wave and wave <= end_wave:
			return band
	if bands.is_empty():
		return {}
	return bands[bands.size() - 1]
