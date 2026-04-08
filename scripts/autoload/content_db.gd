extends Node

const EnemyData = preload("res://scripts/data/enemy_data.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const MutationData = preload("res://scripts/data/mutation_data.gd")
const WaveRulesData = preload("res://scripts/data/wave_rules_data.gd")
const CoreArchetypeData = preload("res://scripts/data/core_archetype_data.gd")
const ChapterData = preload("res://scripts/data/chapter_data.gd")

const _ENEMY_RESOURCE_PATHS := [
	"res://data/enemies/bacteria_armored.tres",
	"res://data/enemies/bacteria_base.tres",
	"res://data/enemies/bacteria_regen.tres",
	"res://data/enemies/boss_parasite_queen.tres",
	"res://data/enemies/elite_spore_titan.tres",
	"res://data/enemies/virus_base.tres",
	"res://data/enemies/virus_dash.tres",
	"res://data/enemies/virus_divider.tres",
	"res://data/enemies/virus_mini.tres",
]

const _UPGRADE_RESOURCE_PATHS := [
	"res://data/upgrades/meta_armor.tres",
	"res://data/upgrades/meta_atp_gain.tres",
	"res://data/upgrades/meta_attack_speed.tres",
	"res://data/upgrades/meta_crit_chance.tres",
	"res://data/upgrades/meta_damage.tres",
	"res://data/upgrades/meta_dna_gain.tres",
	"res://data/upgrades/meta_max_hp.tres",
	"res://data/upgrades/meta_pickup_radius.tres",
	"res://data/upgrades/meta_projectile_speed.tres",
	"res://data/upgrades/meta_regeneration.tres",
	"res://data/upgrades/meta_shield_max.tres",
	"res://data/upgrades/meta_targeting_range.tres",
	"res://data/upgrades/runtime_absolute_defense.tres",
	"res://data/upgrades/runtime_antibacterial_focus.tres",
	"res://data/upgrades/runtime_antiviral_focus.tres",
	"res://data/upgrades/runtime_armor.tres",
	"res://data/upgrades/runtime_atp_gain.tres",
	"res://data/upgrades/runtime_atp_interest.tres",
	"res://data/upgrades/runtime_atp_per_wave.tres",
	"res://data/upgrades/runtime_attack_speed.tres",
	"res://data/upgrades/runtime_auto_evolution_cycle.tres",
	"res://data/upgrades/runtime_bounce_chance.tres",
	"res://data/upgrades/runtime_bounce_radius.tres",
	"res://data/upgrades/runtime_bounce_targets.tres",
	"res://data/upgrades/runtime_contact_resistance.tres",
	"res://data/upgrades/runtime_contact_retaliation.tres",
	"res://data/upgrades/runtime_crit_chance.tres",
	"res://data/upgrades/runtime_crit_damage.tres",
	"res://data/upgrades/runtime_damage.tres",
	"res://data/upgrades/runtime_damage_per_meter.tres",
	"res://data/upgrades/runtime_dna_crystal_frequency.tres",
	"res://data/upgrades/runtime_dna_gain.tres",
	"res://data/upgrades/runtime_dna_per_kill.tres",
	"res://data/upgrades/runtime_dna_per_wave.tres",
	"res://data/upgrades/runtime_max_hp.tres",
	"res://data/upgrades/runtime_multishot_targets.tres",
	"res://data/upgrades/runtime_pickup_radius.tres",
	"res://data/upgrades/runtime_pierce.tres",
	"res://data/upgrades/runtime_projectile_count.tres",
	"res://data/upgrades/runtime_projectile_speed.tres",
	"res://data/upgrades/runtime_random_attack_progress.tres",
	"res://data/upgrades/runtime_random_defense_progress.tres",
	"res://data/upgrades/runtime_random_utility_progress.tres",
	"res://data/upgrades/runtime_range.tres",
	"res://data/upgrades/runtime_rapid_fire_chance.tres",
	"res://data/upgrades/runtime_rapid_fire_duration.tres",
	"res://data/upgrades/runtime_regeneration.tres",
	"res://data/upgrades/runtime_secondary_projectile.tres",
	"res://data/upgrades/runtime_shield_max.tres",
	"res://data/upgrades/runtime_shield_regeneration.tres",
	"res://data/upgrades/runtime_targeting_range.tres",
	"res://data/upgrades/unlock_adaptive_homeostasis.tres",
	"res://data/upgrades/unlock_caustic_cascade.tres",
	"res://data/upgrades/unlock_cryogenic_halo.tres",
	"res://data/upgrades/unlock_explosive_antibodies.tres",
	"res://data/upgrades/unlock_hyper_secretion.tres",
	"res://data/upgrades/unlock_secondary_secretion.tres",
]

const _MUTATION_RESOURCE_PATHS := [
	"res://data/mutations/mutation_adaptive_homeostasis.tres",
	"res://data/mutations/mutation_antibacterial_response.tres",
	"res://data/mutations/mutation_antiviral_response.tres",
	"res://data/mutations/mutation_caustic_cascade.tres",
	"res://data/mutations/mutation_cryogenic_halo.tres",
	"res://data/mutations/mutation_explosive_antibodies.tres",
	"res://data/mutations/mutation_hyper_secretion.tres",
	"res://data/mutations/mutation_secondary_secretion.tres",
	"res://data/mutations/mutation_slowing_aura.tres",
]

const _CORE_ARCHETYPE_RESOURCE_PATHS := [
	"res://data/core_archetypes/bastion_core.tres",
	"res://data/core_archetypes/sentinel_core.tres",
	"res://data/core_archetypes/striker_core.tres",
	"res://data/core_archetypes/synthesis_core.tres",
]

const _CHAPTER_RESOURCE_PATHS := [
	"res://data/chapters/chapter_bronchial.tres",
	"res://data/chapters/chapter_capillary.tres",
	"res://data/chapters/chapter_synaptic.tres",
]

var _enemy_catalog: Dictionary = {}
var _upgrade_catalog: Dictionary = {}
var _mutation_catalog: Dictionary = {}
var _core_archetype_catalog: Dictionary = {}
var _chapter_catalog: Dictionary = {}
var _wave_rules: WaveRulesData
var _loaded: bool = false

func _ready() -> void:
	reload_content()

func reload_content() -> void:
	_enemy_catalog = _load_catalog("res://data/enemies", _ENEMY_RESOURCE_PATHS)
	_upgrade_catalog = _load_catalog("res://data/upgrades", _UPGRADE_RESOURCE_PATHS)
	_mutation_catalog = _load_catalog("res://data/mutations", _MUTATION_RESOURCE_PATHS)
	_core_archetype_catalog = _load_catalog("res://data/core_archetypes", _CORE_ARCHETYPE_RESOURCE_PATHS)
	_chapter_catalog = _load_catalog("res://data/chapters", _CHAPTER_RESOURCE_PATHS)
	_wave_rules = load("res://data/waves/wave_rules.tres") as WaveRulesData
	if _wave_rules == null:
		var wave_candidates := _scan_catalog_paths_recursive("res://data/waves")
		if not wave_candidates.is_empty():
			_wave_rules = load(wave_candidates[0]) as WaveRulesData
	_loaded = true

func get_enemy(enemy_id: StringName) -> EnemyData:
	_ensure_loaded()
	return _enemy_catalog.get(enemy_id) as EnemyData

func get_upgrade(upgrade_id: StringName) -> UpgradeData:
	_ensure_loaded()
	return _upgrade_catalog.get(upgrade_id) as UpgradeData

func get_mutation(mutation_id: StringName) -> MutationData:
	_ensure_loaded()
	return _mutation_catalog.get(mutation_id) as MutationData

func get_all_enemies() -> Array[EnemyData]:
	_ensure_loaded()
	var result: Array[EnemyData] = []
	for value in _enemy_catalog.values():
		result.append(value as EnemyData)
	return result

func get_runtime_upgrades() -> Array[UpgradeData]:
	_ensure_loaded()
	return _filter_upgrades_by_layer(&"runtime")

func get_meta_upgrades() -> Array[UpgradeData]:
	_ensure_loaded()
	return _filter_upgrades_by_layer(&"meta")

func get_runtime_upgrades_by_category(category: StringName) -> Array[UpgradeData]:
	var upgrades: Array[UpgradeData] = []
	for item in get_runtime_upgrades():
		if item.category == category:
			upgrades.append(item)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return String(a.display_name) < String(b.display_name))
	return upgrades

func get_meta_upgrades_by_category(category: StringName) -> Array[UpgradeData]:
	var upgrades: Array[UpgradeData] = []
	for item in get_meta_upgrades():
		if item.category == category:
			upgrades.append(item)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return String(a.display_name) < String(b.display_name))
	return upgrades

func get_all_mutations() -> Array[MutationData]:
	_ensure_loaded()
	var result: Array[MutationData] = []
	for value in _mutation_catalog.values():
		result.append(value as MutationData)
	result.sort_custom(func(a: MutationData, b: MutationData) -> bool: return String(a.display_name) < String(b.display_name))
	return result

func get_wave_rules() -> WaveRulesData:
	_ensure_loaded()
	return _wave_rules

func get_core_archetype(archetype_id: StringName) -> CoreArchetypeData:
	_ensure_loaded()
	return _core_archetype_catalog.get(archetype_id) as CoreArchetypeData

func get_core_archetypes() -> Array[CoreArchetypeData]:
	_ensure_loaded()
	var result: Array[CoreArchetypeData] = []
	for value in _core_archetype_catalog.values():
		result.append(value as CoreArchetypeData)
	result.sort_custom(func(a: CoreArchetypeData, b: CoreArchetypeData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name
	)
	return result

func get_chapter(chapter_id: StringName) -> ChapterData:
	_ensure_loaded()
	return _chapter_catalog.get(chapter_id) as ChapterData

func get_chapters() -> Array[ChapterData]:
	_ensure_loaded()
	var result: Array[ChapterData] = []
	for value in _chapter_catalog.values():
		result.append(value as ChapterData)
	result.sort_custom(func(a: ChapterData, b: ChapterData) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.display_name < b.display_name
	)
	return result

func _load_catalog(folder_path: String, explicit_paths: Array) -> Dictionary:
	var catalog: Dictionary = {}
	var resource_paths := _collect_catalog_paths(folder_path, explicit_paths)

	for resource_path in resource_paths:
		var resource := load(resource_path)
		if resource == null:
			push_warning("Unable to load resource: %s" % resource_path)
			continue

		if resource is EnemyData:
			var enemy := resource as EnemyData
			if catalog.has(enemy.enemy_id):
				push_warning("Duplicate enemy id '%s' from %s" % [String(enemy.enemy_id), resource_path])
				continue
			catalog[enemy.enemy_id] = enemy
		elif resource is UpgradeData:
			var upgrade := resource as UpgradeData
			if catalog.has(upgrade.upgrade_id):
				push_warning("Duplicate upgrade id '%s' from %s" % [String(upgrade.upgrade_id), resource_path])
				continue
			catalog[upgrade.upgrade_id] = upgrade
		elif resource is MutationData:
			var mutation := resource as MutationData
			if catalog.has(mutation.mutation_id):
				push_warning("Duplicate mutation id '%s' from %s" % [String(mutation.mutation_id), resource_path])
				continue
			catalog[mutation.mutation_id] = mutation
		elif resource is CoreArchetypeData:
			var archetype := resource as CoreArchetypeData
			if catalog.has(archetype.archetype_id):
				push_warning("Duplicate archetype id '%s' from %s" % [String(archetype.archetype_id), resource_path])
				continue
			catalog[archetype.archetype_id] = archetype
		elif resource is ChapterData:
			var chapter := resource as ChapterData
			if catalog.has(chapter.chapter_id):
				push_warning("Duplicate chapter id '%s' from %s" % [String(chapter.chapter_id), resource_path])
				continue
			catalog[chapter.chapter_id] = chapter

	if catalog.is_empty():
		push_warning("Content catalog is empty for folder %s" % folder_path)

	return catalog

func _scan_catalog_paths(folder_path: String) -> Array[String]:
	return _scan_catalog_paths_recursive(folder_path)

func _collect_catalog_paths(folder_path: String, explicit_paths: Array) -> Array[String]:
	var unique_paths: Dictionary = {}
	for discovered_path in _scan_catalog_paths_recursive(folder_path):
		unique_paths[discovered_path] = true
	for item in explicit_paths:
		var explicit_path := String(item)
		if not explicit_path.is_empty():
			unique_paths[explicit_path] = true

	var result: Array[String] = []
	for resource_path in unique_paths.keys():
		result.append(String(resource_path))
	result.sort()
	return result

func _scan_catalog_paths_recursive(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_warning("Missing content folder: %s" % folder_path)
		return result

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			if file_name.begins_with("."):
				continue
			result.append_array(_scan_catalog_paths_recursive("%s/%s" % [folder_path, file_name]))
			continue
		if not file_name.ends_with(".tres"):
			continue
		result.append("%s/%s" % [folder_path, file_name])
	dir.list_dir_end()
	result.sort()
	return result

func _filter_upgrades_by_layer(layer: StringName) -> Array[UpgradeData]:
	_ensure_loaded()
	var result: Array[UpgradeData] = []
	for value in _upgrade_catalog.values():
		var upgrade := value as UpgradeData
		if upgrade.layer == layer:
			result.append(upgrade)
	result.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return String(a.display_name) < String(b.display_name))
	return result

func _ensure_loaded() -> void:
	if _loaded and _wave_rules != null:
		return
	reload_content()
