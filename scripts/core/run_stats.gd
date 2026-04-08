extends RefCounted
class_name RunStats

var max_hp: float = 135.0
var damage: float = 14.0
var attack_speed: float = 1.18
var projectile_count: int = 1
var crit_chance: float = 0.08
var crit_damage: float = 1.75
var projectile_speed: float = 560.0
var pierce_count: int = 0
var projectile_range: float = 320.0
var targeting_range: float = 372.0
var damage_per_meter: float = 0.0
var multishot_targets: int = 0
var rapid_fire_chance: float = 0.0
var rapid_fire_duration: float = 0.0
var bounce_chance: float = 0.0
var bounce_targets: int = 0
var bounce_radius: float = 0.0
var armor: float = 0.0
var absolute_defense: float = 0.0
var regeneration: float = 1.8
var shield_max: float = 0.0
var shield_regeneration: float = 0.0
var contact_damage_reduction: float = 0.0
var contact_retaliation: float = 0.0
var atp_gain_multiplier: float = 1.0
var atp_per_wave: float = 0.0
var atp_interest_per_wave: float = 0.0
var dna_gain_multiplier: float = 1.0
var dna_bonus_per_kill: float = 0.0
var dna_per_wave: float = 0.0
var pickup_radius: float = 112.0
var dna_crystal_spawn_bonus: float = 0.0
var random_attack_upgrade_chance: float = 0.0
var random_defense_upgrade_chance: float = 0.0
var random_utility_upgrade_chance: float = 0.0
var auto_upgrade_interval_reduction: float = 0.0
var damage_vs_virus_bonus: float = 0.0
var damage_vs_bacteria_bonus: float = 0.0
var splash_chance: float = 0.0
var splash_radius: float = 0.0
var splash_multiplier: float = 0.0
var secondary_projectile_chance: float = 0.0
var slow_aura_strength: float = 0.0
var slow_aura_radius: float = 0.0

func clone() -> RunStats:
	var copy: RunStats = get_script().new()
	copy.max_hp = max_hp
	copy.damage = damage
	copy.attack_speed = attack_speed
	copy.projectile_count = projectile_count
	copy.crit_chance = crit_chance
	copy.crit_damage = crit_damage
	copy.projectile_speed = projectile_speed
	copy.pierce_count = pierce_count
	copy.projectile_range = projectile_range
	copy.targeting_range = targeting_range
	copy.damage_per_meter = damage_per_meter
	copy.multishot_targets = multishot_targets
	copy.rapid_fire_chance = rapid_fire_chance
	copy.rapid_fire_duration = rapid_fire_duration
	copy.bounce_chance = bounce_chance
	copy.bounce_targets = bounce_targets
	copy.bounce_radius = bounce_radius
	copy.armor = armor
	copy.absolute_defense = absolute_defense
	copy.regeneration = regeneration
	copy.shield_max = shield_max
	copy.shield_regeneration = shield_regeneration
	copy.contact_damage_reduction = contact_damage_reduction
	copy.contact_retaliation = contact_retaliation
	copy.atp_gain_multiplier = atp_gain_multiplier
	copy.atp_per_wave = atp_per_wave
	copy.atp_interest_per_wave = atp_interest_per_wave
	copy.dna_gain_multiplier = dna_gain_multiplier
	copy.dna_bonus_per_kill = dna_bonus_per_kill
	copy.dna_per_wave = dna_per_wave
	copy.pickup_radius = pickup_radius
	copy.dna_crystal_spawn_bonus = dna_crystal_spawn_bonus
	copy.random_attack_upgrade_chance = random_attack_upgrade_chance
	copy.random_defense_upgrade_chance = random_defense_upgrade_chance
	copy.random_utility_upgrade_chance = random_utility_upgrade_chance
	copy.auto_upgrade_interval_reduction = auto_upgrade_interval_reduction
	copy.damage_vs_virus_bonus = damage_vs_virus_bonus
	copy.damage_vs_bacteria_bonus = damage_vs_bacteria_bonus
	copy.splash_chance = splash_chance
	copy.splash_radius = splash_radius
	copy.splash_multiplier = splash_multiplier
	copy.secondary_projectile_chance = secondary_projectile_chance
	copy.slow_aura_strength = slow_aura_strength
	copy.slow_aura_radius = slow_aura_radius
	return copy

func apply_stat_bonus(stat_key: StringName, value: float) -> void:
	match stat_key:
		&"max_hp":
			max_hp += value
		&"damage":
			damage += value
		&"attack_speed":
			attack_speed += value
		&"projectile_count":
			projectile_count += int(round(value))
		&"crit_chance":
			crit_chance += value
		&"crit_damage":
			crit_damage += value
		&"projectile_speed":
			projectile_speed += value
		&"pierce_count":
			pierce_count += int(round(value))
		&"projectile_range":
			projectile_range += value
		&"targeting_range":
			targeting_range += value
		&"damage_per_meter":
			damage_per_meter += value
		&"multishot_targets":
			multishot_targets += int(round(value))
		&"rapid_fire_chance":
			rapid_fire_chance += value
		&"rapid_fire_duration":
			rapid_fire_duration += value
		&"bounce_chance":
			bounce_chance += value
		&"bounce_targets":
			bounce_targets += int(round(value))
		&"bounce_radius":
			bounce_radius += value
		&"armor":
			armor += value
		&"absolute_defense":
			absolute_defense += value
		&"regeneration":
			regeneration += value
		&"shield_max":
			shield_max += value
		&"shield_regeneration":
			shield_regeneration += value
		&"contact_damage_reduction":
			contact_damage_reduction += value
		&"contact_retaliation":
			contact_retaliation += value
		&"atp_gain_multiplier":
			atp_gain_multiplier += value
		&"atp_per_wave":
			atp_per_wave += value
		&"atp_interest_per_wave":
			atp_interest_per_wave += value
		&"dna_gain_multiplier":
			dna_gain_multiplier += value
		&"dna_bonus_per_kill":
			dna_bonus_per_kill += value
		&"dna_per_wave":
			dna_per_wave += value
		&"pickup_radius":
			pickup_radius += value
		&"dna_crystal_spawn_bonus":
			dna_crystal_spawn_bonus += value
		&"random_attack_upgrade_chance":
			random_attack_upgrade_chance += value
		&"random_defense_upgrade_chance":
			random_defense_upgrade_chance += value
		&"random_utility_upgrade_chance":
			random_utility_upgrade_chance += value
		&"auto_upgrade_interval_reduction":
			auto_upgrade_interval_reduction += value
		&"damage_vs_virus_bonus":
			damage_vs_virus_bonus += value
		&"damage_vs_bacteria_bonus":
			damage_vs_bacteria_bonus += value
		&"secondary_projectile_chance":
			secondary_projectile_chance += value
		&"splash_chance":
			splash_chance += value
		&"splash_radius":
			splash_radius += value
		&"splash_multiplier":
			splash_multiplier += value
		&"slow_aura_strength":
			slow_aura_strength += value
		&"slow_aura_radius":
			slow_aura_radius += value
		_:
			push_warning("Unknown stat key: %s" % stat_key)

func finalize() -> void:
	max_hp = max(max_hp, 1.0)
	damage = max(damage, 1.0)
	attack_speed = max(attack_speed, 0.2)
	projectile_count = max(projectile_count, 1)
	crit_chance = clamp(crit_chance, 0.0, 0.95)
	crit_damage = max(crit_damage, 1.1)
	projectile_speed = max(projectile_speed, 120.0)
	pierce_count = max(pierce_count, 0)
	projectile_range = max(projectile_range, 80.0)
	targeting_range = max(targeting_range, 100.0)
	damage_per_meter = max(damage_per_meter, 0.0)
	multishot_targets = max(multishot_targets, 0)
	rapid_fire_chance = clamp(rapid_fire_chance, 0.0, 1.0)
	rapid_fire_duration = max(rapid_fire_duration, 0.0)
	bounce_chance = clamp(bounce_chance, 0.0, 1.0)
	bounce_targets = max(bounce_targets, 0)
	bounce_radius = max(bounce_radius, 0.0)
	armor = clamp(armor, 0.0, 0.85)
	absolute_defense = max(absolute_defense, 0.0)
	regeneration = max(regeneration, 0.0)
	shield_max = max(shield_max, 0.0)
	shield_regeneration = max(shield_regeneration, 0.0)
	contact_damage_reduction = clamp(contact_damage_reduction, 0.0, 0.8)
	contact_retaliation = max(contact_retaliation, 0.0)
	atp_gain_multiplier = max(atp_gain_multiplier, 0.2)
	atp_per_wave = max(atp_per_wave, 0.0)
	atp_interest_per_wave = clamp(atp_interest_per_wave, 0.0, 1.0)
	dna_gain_multiplier = max(dna_gain_multiplier, 0.2)
	dna_bonus_per_kill = max(dna_bonus_per_kill, 0.0)
	dna_per_wave = max(dna_per_wave, 0.0)
	pickup_radius = max(pickup_radius, 24.0)
	dna_crystal_spawn_bonus = clamp(dna_crystal_spawn_bonus, 0.0, 0.8)
	random_attack_upgrade_chance = clamp(random_attack_upgrade_chance, 0.0, 0.95)
	random_defense_upgrade_chance = clamp(random_defense_upgrade_chance, 0.0, 0.95)
	random_utility_upgrade_chance = clamp(random_utility_upgrade_chance, 0.0, 0.95)
	auto_upgrade_interval_reduction = clamp(auto_upgrade_interval_reduction, 0.0, 0.75)
	splash_chance = clamp(splash_chance, 0.0, 1.0)
	splash_radius = max(splash_radius, 0.0)
	splash_multiplier = max(splash_multiplier, 0.0)
	secondary_projectile_chance = clamp(secondary_projectile_chance, 0.0, 1.0)
	slow_aura_strength = clamp(slow_aura_strength, 0.0, 0.9)
	slow_aura_radius = max(slow_aura_radius, 0.0)

func get_attack_interval() -> float:
	return 1.0 / attack_speed

func get_damage_multiplier_for_family(family: StringName) -> float:
	if family == &"virus":
		return 1.0 + damage_vs_virus_bonus
	if family == &"bacteria":
		return 1.0 + damage_vs_bacteria_bonus
	return 1.0

func get_distance_damage_multiplier(distance_px: float) -> float:
	if damage_per_meter <= 0.0:
		return 1.0
	var meters: float = max(distance_px, 0.0) / 100.0
	return 1.0 + (damage_per_meter * meters)
