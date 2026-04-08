extends Resource
class_name CoreArchetypeData

@export var archetype_id: StringName = &"core"
@export var display_name: String = "Core"
@export_multiline var description: String = ""
@export var sort_order: int = 0
@export var accent_color: Color = Color(0.35, 0.93, 0.84, 1.0)
@export var stat_bonuses: Dictionary = {}
@export var active_skill_name: String = "Immune Pulse"
@export_multiline var active_skill_description: String = ""
@export var active_skill_cooldown: float = 24.0
@export var active_skill_damage_multiplier: float = 3.0
@export var active_skill_radius: float = 150.0
@export var active_skill_shield_restore_ratio: float = 0.0
