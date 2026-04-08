extends Resource
class_name MutationData

@export var mutation_id: StringName = &"mutation"
@export var display_name: String = "Mutation"
@export_multiline var description: String = ""
@export var rarity: StringName = &"common"
@export var selection_weight: float = 1.0
@export var starts_unlocked: bool = false
@export var damage_vs_virus_bonus: float = 0.0
@export var damage_vs_bacteria_bonus: float = 0.0
@export var splash_chance: float = 0.0
@export var splash_radius: float = 0.0
@export var splash_damage_multiplier: float = 0.0
@export var secondary_projectile_chance: float = 0.0
@export var slow_aura_strength: float = 0.0
@export var slow_aura_radius: float = 0.0
@export var regeneration_bonus: float = 0.0
@export var attack_speed_penalty: float = 0.0
