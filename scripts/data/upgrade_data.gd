extends Resource
class_name UpgradeData

@export var upgrade_id: StringName = &"upgrade"
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var layer: StringName = &"runtime"
@export var category: StringName = &"attack"
@export var stat_key: StringName = &"damage"
@export var unlocks_mutation_id: StringName = &""
@export var base_cost: int = 10
@export var cost_growth: float = 1.25
@export var value_per_level: float = 1.0
@export var max_level: int = 10
@export var display_as_percent: bool = false

func get_cost_for_level(level: int) -> int:
	var exponent: int = max(level - 1, 0)
	return int(round(base_cost * pow(cost_growth, exponent)))

func get_bonus_for_level(level: int) -> float:
	return value_per_level * level

func is_mutation_unlock() -> bool:
	return unlocks_mutation_id != &""
