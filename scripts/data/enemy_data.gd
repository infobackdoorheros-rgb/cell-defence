extends Resource
class_name EnemyData

@export var enemy_id: StringName = &"enemy"
@export var display_name: String = "Enemy"
@export var family: StringName = &"virus"
@export var tier: StringName = &"normal"
@export var max_health: float = 20.0
@export var speed: float = 70.0
@export var contact_damage: float = 10.0
@export var collision_radius: float = 18.0
@export var atp_reward: int = 5
@export var dna_reward: int = 0
@export var display_color: Color = Color(0.9, 0.3, 0.3, 1.0)
@export var scale_multiplier: float = 1.0
@export var split_children: PackedStringArray = PackedStringArray()
@export var dash_cooldown: float = 0.0
@export var dash_duration: float = 0.0
@export var dash_multiplier: float = 1.0
@export var regeneration_per_sec: float = 0.0
@export var contact_self_destruct: bool = true
@export var contact_tick_cooldown: float = 1.0
@export var spawn_children_interval: float = 0.0
@export var spawn_children_count: int = 0
@export var spawn_children_ids: PackedStringArray = PackedStringArray()
