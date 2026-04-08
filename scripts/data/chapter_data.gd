extends Resource
class_name ChapterData

@export var chapter_id: StringName = &"chapter"
@export var display_name: String = "Chapter"
@export_multiline var description: String = ""
@export_multiline var short_blurb: String = ""
@export var sort_order: int = 0
@export var accent_color: Color = Color(0.35, 0.93, 0.84, 1.0)
@export var dna_multiplier: float = 1.0
@export var atp_multiplier: float = 1.0
@export var event_point_multiplier: float = 1.0
@export var enemy_health_multiplier: float = 1.0
@export var enemy_speed_multiplier: float = 1.0
@export var spawn_count_bonus: int = 0
@export var boss_support_bonus: int = 0
@export var virus_weight_bonus: float = 0.0
@export var bacteria_weight_bonus: float = 0.0
@export var arena_primary: Color = Color(0.18, 0.78, 0.72, 0.12)
@export var arena_secondary: Color = Color(0.31, 0.74, 1.0, 0.08)
