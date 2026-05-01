extends Node

signal event_progress_changed
signal milestone_reached(index: int, target: int)
signal milestone_claimed(index: int, reward_dna: int)
signal objective_claimed(index: int, reward_dna: int)

const CONFIG_PATH := "res://data/config/season_event_live.json"
const DEFAULT_ACTIVE_EVENT_ID: StringName = &"spring_recombination_2026"
const DEFAULT_ACTIVE_OBJECTIVE_COUNT := 5

var progress: int = 0
var claimed_milestones: Array[bool] = []
var reached_milestones: Array[bool] = []
var active_objectives: Array[Dictionary] = []
var objective_day_key: String = ""

var _config: Dictionary = {}
var _milestone_targets: Array = []
var _milestone_rewards: Array = []

func _ready() -> void:
	reload_live_config()
	load_state()

func reload_live_config() -> void:
	_config = _build_default_config()
	_config = _deep_merge(_config, _read_json_dictionary(CONFIG_PATH))
	_rebuild_milestone_cache()

func load_state() -> void:
	if _config.is_empty():
		reload_live_config()
	var save_data := SaveManager.get_save()
	var state := save_data.get("season_event", {}) as Dictionary
	progress = int(state.get("progress", 0))
	objective_day_key = String(state.get("objective_day_key", ""))
	active_objectives.clear()
	claimed_milestones.clear()
	reached_milestones.clear()
	for _index in range(_milestone_targets.size()):
		claimed_milestones.append(false)
		reached_milestones.append(false)

	var claimed_raw := state.get("claimed_milestones", []) as Array
	for index in range(min(claimed_raw.size(), claimed_milestones.size())):
		claimed_milestones[index] = bool(claimed_raw[index])

	for index in range(_milestone_targets.size()):
		reached_milestones[index] = progress >= int(_milestone_targets[index])

	for entry in state.get("active_objectives", []) as Array:
		if entry is Dictionary:
			active_objectives.append((entry as Dictionary).duplicate(true))

	_ensure_active_objectives()
	event_progress_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"season_event": {
			"event_id": String(_get_event_id()),
			"progress": progress,
			"claimed_milestones": claimed_milestones,
			"objective_day_key": objective_day_key,
			"active_objectives": active_objectives
		}
	})

func get_event_overview() -> Dictionary:
	_ensure_active_objectives()
	var milestones: Array[Dictionary] = []
	for index in range(_milestone_targets.size()):
		milestones.append({
			"index": index,
			"target": int(_milestone_targets[index]),
			"reward_dna": int(_milestone_rewards[index]),
			"claimed": claimed_milestones[index],
			"reached": progress >= int(_milestone_targets[index])
		})

	return {
		"event_id": _get_event_id(),
		"display_name": _get_localized(_config, "display_name", SettingsManager.t("season.name")),
		"subtitle": _get_localized(_config, "subtitle", SettingsManager.t("season.subtitle")),
		"currency_name": _get_localized(_config, "currency_name", SettingsManager.t("season.currency")),
		"progress": progress,
		"max_target": int(_milestone_targets[_milestone_targets.size() - 1]) if not _milestone_targets.is_empty() else 0,
		"milestones": milestones,
		"progress_rules": get_progress_rules(),
		"active_objectives": active_objectives.duplicate(true)
	}

func get_progress_rules() -> Dictionary:
	var rules := (_config.get("progress_rules", {}) as Dictionary).duplicate(true)
	if not rules.has("base_enemy"):
		rules["base_enemy"] = 1
	if not rules.has("elite_enemy"):
		rules["elite_enemy"] = 4
	if not rules.has("boss_enemy"):
		rules["boss_enemy"] = 10
	if not rules.has("summary_it"):
		rules["summary_it"] = "Accumuli Spore Evento eliminando nemici durante la partita: base +1, elite +4, boss +10. Il Settore Difesa applica poi il suo moltiplicatore."
	if not rules.has("summary_en"):
		rules["summary_en"] = "You earn Event Spores by defeating enemies during a match: base +1, elite +4, boss +10. The Defense Sector then applies its multiplier."
	if not rules.has("note_it"):
		rules["note_it"] = "Le Operazioni Attive qui sotto sono obiettivi veri: avanzano in tempo reale e rilasciano DNA quando li riscatti."
	if not rules.has("note_en"):
		rules["note_en"] = "The Active Operations below are real objectives: they advance live and award DNA when you claim them."
	return rules

func register_enemy_defeat(enemy_tier: StringName, chapter_multiplier: float = 1.0, family: StringName = &"") -> void:
	var rules := get_progress_rules()
	var amount: int = int(rules.get("base_enemy", 1))
	match enemy_tier:
		&"elite":
			amount = int(rules.get("elite_enemy", 4))
		&"boss":
			amount = int(rules.get("boss_enemy", 10))
	amount = max(1, int(round(float(amount) * max(chapter_multiplier, 0.5))))
	add_progress(amount)

	var changed := false
	changed = _advance_objectives(&"kill_any", 1) or changed
	if enemy_tier == &"elite":
		changed = _advance_objectives(&"kill_elite", 1) or changed
	elif enemy_tier == &"boss":
		changed = _advance_objectives(&"kill_boss", 1) or changed
	else:
		changed = _advance_objectives(&"kill_common", 1) or changed
	if family == &"virus":
		changed = _advance_objectives(&"kill_virus", 1) or changed
	elif family == &"bacteria":
		changed = _advance_objectives(&"kill_bacteria", 1) or changed
	if changed:
		save_state()
		event_progress_changed.emit()

func register_wave_reached(local_wave: int) -> void:
	if local_wave <= 0:
		return
	if _advance_objectives(&"reach_wave", local_wave, true):
		save_state()
		event_progress_changed.emit()

func register_runtime_upgrade_purchase(category: StringName, _upgrade_id: StringName) -> void:
	var changed := _advance_objectives(&"buy_any_upgrade", 1)
	match category:
		&"attack":
			changed = _advance_objectives(&"buy_attack_upgrade", 1) or changed
		&"defense":
			changed = _advance_objectives(&"buy_defense_upgrade", 1) or changed
		&"utility":
			changed = _advance_objectives(&"buy_utility_upgrade", 1) or changed
	if changed:
		save_state()
		event_progress_changed.emit()

func register_mutation_selected() -> void:
	if _advance_objectives(&"pick_mutation", 1):
		save_state()
		event_progress_changed.emit()

func add_progress(amount: int) -> void:
	if amount <= 0:
		return
	progress += amount
	var changed := false
	for index in range(_milestone_targets.size()):
		if reached_milestones[index]:
			continue
		if progress < int(_milestone_targets[index]):
			continue
		reached_milestones[index] = true
		milestone_reached.emit(index, int(_milestone_targets[index]))
		changed = true
	if changed or amount > 0:
		save_state()
		event_progress_changed.emit()

func claim_milestone(index: int) -> int:
	if index < 0 or index >= _milestone_targets.size():
		return 0
	if claimed_milestones[index]:
		return 0
	if progress < int(_milestone_targets[index]):
		return 0
	claimed_milestones[index] = true
	var reward_dna: int = int(_milestone_rewards[index])
	if reward_dna > 0:
		MetaProgression.add_dna(reward_dna)
	AnalyticsManager.track_event(&"season_milestone_claimed", {
		"index": index,
		"reward_dna": reward_dna
	})
	save_state()
	milestone_claimed.emit(index, reward_dna)
	event_progress_changed.emit()
	return reward_dna

func claim_objective(index: int) -> int:
	_ensure_active_objectives()
	if index < 0 or index >= active_objectives.size():
		return 0
	var objective := active_objectives[index] as Dictionary
	if bool(objective.get("claimed", false)):
		return 0
	if int(objective.get("progress", 0)) < int(objective.get("target", 0)):
		return 0
	objective["claimed"] = true
	active_objectives[index] = objective
	var reward_dna := int(objective.get("reward_dna", 0))
	if reward_dna > 0:
		MetaProgression.add_dna(reward_dna)
	AnalyticsManager.track_event(&"season_objective_claimed", {
			"objective_id": String(objective.get("id", "")),
			"reward_dna": reward_dna
		})
	save_state()
	objective_claimed.emit(index, reward_dna)
	event_progress_changed.emit()
	return reward_dna

func _ensure_active_objectives() -> void:
	var today_key := _get_today_key()
	if objective_day_key == today_key and active_objectives.size() == _get_active_objective_count():
		return
	objective_day_key = today_key
	active_objectives = _roll_active_objectives()
	save_state()

func _roll_active_objectives() -> Array[Dictionary]:
	var pool := _build_objective_archive()
	var picked: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%s|%s|%d|%d" % [String(_get_event_id()), _get_today_key(), max(progress, 0), max(MetaProgression.best_wave, 0)]))
	var used_types: Dictionary = {}
	while picked.size() < _get_active_objective_count() and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		var candidate := (pool[index] as Dictionary).duplicate(true)
		pool.remove_at(index)
		var type_key := String(candidate.get("type", ""))
		if used_types.has(type_key):
			continue
		candidate["progress"] = 0
		candidate["claimed"] = false
		used_types[type_key] = true
		picked.append(candidate)
	return picked

func _build_objective_archive() -> Array[Dictionary]:
	var intensity: int = clamp(int(floor(float(max(MetaProgression.best_wave, 1)) / 10.0)), 0, 8)
	var archive: Array[Dictionary] = []
	var templates := _config.get("objective_templates", []) as Array
	for template in templates:
		if template is Dictionary:
			archive.append(_build_objective_from_template(template as Dictionary, intensity))
	if archive.is_empty():
		return _build_fallback_objective_archive(intensity)
	return archive

func _build_objective_from_template(template: Dictionary, intensity: int) -> Dictionary:
	var target_divisor: float = max(1.0, float(template.get("target_divisor", 1.0)))
	var reward_divisor: float = max(1.0, float(template.get("reward_divisor", 1.0)))
	var target_step_count := int(floor(float(intensity) / target_divisor))
	var reward_step_count := int(floor(float(intensity) / reward_divisor))
	var target := int(template.get("target", 0))
	if target <= 0:
		target = int(template.get("target_base", 1)) + (int(template.get("target_step", 0)) * target_step_count)
	var reward_dna := int(template.get("reward_dna", 0))
	if reward_dna <= 0:
		reward_dna = int(template.get("reward_base", 1)) + (int(template.get("reward_step", 0)) * reward_step_count)
	return {
		"id": String(template.get("id", "")),
		"type": String(template.get("type", "")),
		"title_it": String(template.get("title_it", "")),
		"title_en": String(template.get("title_en", "")),
		"description_it": String(template.get("description_it", "")),
		"description_en": String(template.get("description_en", "")),
		"target": max(1, target),
		"reward_dna": max(1, reward_dna)
	}

func _build_fallback_objective_archive(intensity: int) -> Array[Dictionary]:
	var archive: Array[Dictionary] = []
	var wave_step: int = max(5, 4 + intensity)
	var reward_base: int = 8 + (intensity * 2)
	archive.append(_build_objective_entry("operation_kill_common", &"kill_common", "Sterilizza Pattuglie", "Sterilize Patrols", 22 + (intensity * 4), reward_base, "Elimina nemici base per alimentare il tracciato evento.", "Defeat basic enemies to feed the event track."))
	archive.append(_build_objective_entry("operation_kill_any", &"kill_any", "Scarica l'Infezione", "Discharge the Infection", 32 + (intensity * 5), reward_base + 2, "Conta ogni abbattimento: ideale per build ad area e multicolpo.", "Every takedown counts: ideal for area and multishot builds."))
	archive.append(_build_objective_entry("operation_kill_elite", &"kill_elite", "Apri i Bersagli Pesanti", "Break Heavy Targets", 3 + int(floor(float(intensity) / 2.0)), reward_base + 4, "Concentrati sugli elite: valgono piu Spore e accelerano la progressione.", "Focus elites: they yield more Spores and accelerate progression."))
	archive.append(_build_objective_entry("operation_kill_boss", &"kill_boss", "Anatomia del Boss", "Boss Anatomy", 1, reward_base + 8, "Chiudi una wave boss per ottenere il claim piu pesante della rotazione.", "Close a boss wave to secure the heaviest claim in the rotation."))
	archive.append(_build_objective_entry("operation_wave", &"reach_wave", "Spingi il Fronte", "Push the Front", 5 + wave_step, reward_base + 4, "Raggiungi una wave piu alta nella sessione corrente.", "Reach a higher wave in the current session."))
	archive.append(_build_objective_entry("operation_attack", &"buy_attack_upgrade", "Ritmo Offensivo", "Offense Cadence", 4 + int(floor(float(intensity) / 2.0)), reward_base + 1, "Compra upgrade Attacco in partita per accelerare la build.", "Buy Attack upgrades during the run to accelerate the build."))
	archive.append(_build_objective_entry("operation_defense", &"buy_defense_upgrade", "Rinforza la Membrana", "Reinforce the Membrane", 4 + int(floor(float(intensity) / 2.0)), reward_base + 1, "Compra upgrade Difesa per stabilizzare il nucleo.", "Buy Defense upgrades to stabilize the core."))
	archive.append(_build_objective_entry("operation_utility", &"buy_utility_upgrade", "Ottimizza il Metabolismo", "Optimize Metabolism", 4 + int(floor(float(intensity) / 2.0)), reward_base + 1, "Compra upgrade Utility per far crescere economia e raccolta.", "Buy Utility upgrades to grow economy and collection."))
	archive.append(_build_objective_entry("operation_mutation", &"pick_mutation", "Ricomposizione Genica", "Gene Recomposition", 2 + int(floor(float(intensity) / 3.0)), reward_base + 3, "Seleziona mutazioni runtime e sfrutta le finestre di adattamento.", "Select runtime mutations and exploit adaptation windows."))
	archive.append(_build_objective_entry("operation_virus", &"kill_virus", "Bonifica Virale", "Viral Purge", 16 + (intensity * 3), reward_base + 2, "Dai priorita ai virus per chiudere il claim in fretta.", "Prioritize viruses to close the claim quickly."))
	archive.append(_build_objective_entry("operation_bacteria", &"kill_bacteria", "Smonta il Biofilm", "Break the Biofilm", 14 + (intensity * 3), reward_base + 2, "Concentrati sui batteri per liberare le corsie pesanti.", "Focus bacteria to clear the heavy lanes."))
	archive.append(_build_objective_entry("operation_any_upgrade", &"buy_any_upgrade", "Adattamento Continuo", "Continuous Adaptation", 10 + intensity, reward_base + 2, "Ogni upgrade runtime conta: resta aggressivo nel negozio in partita.", "Every runtime upgrade counts: stay active in the in-run shop."))
	return archive

func _build_objective_entry(id_value: String, type_value: StringName, title_it: String, title_en: String, target: int, reward_dna: int, description_it: String, description_en: String) -> Dictionary:
	return {
		"id": id_value,
		"type": String(type_value),
		"title_it": title_it,
		"title_en": title_en,
		"description_it": description_it,
		"description_en": description_en,
		"target": max(1, target),
		"reward_dna": max(1, reward_dna)
	}

func _advance_objectives(type_value: StringName, amount: int, set_absolute: bool = false) -> bool:
	_ensure_active_objectives()
	var changed: bool = false
	for index in range(active_objectives.size()):
		var objective := active_objectives[index] as Dictionary
		if StringName(String(objective.get("type", ""))) != type_value:
			continue
		if bool(objective.get("claimed", false)):
			continue
		var previous_progress := int(objective.get("progress", 0))
		var next_progress: int = max(previous_progress + amount, previous_progress)
		if set_absolute:
			next_progress = max(previous_progress, amount)
		next_progress = min(next_progress, int(objective.get("target", 0)))
		if next_progress == previous_progress:
			continue
		objective["progress"] = next_progress
		active_objectives[index] = objective
		changed = true
	return changed

func _get_today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

func _get_event_id() -> StringName:
	return StringName(String(_config.get("event_id", String(DEFAULT_ACTIVE_EVENT_ID))))

func _get_active_objective_count() -> int:
	return max(1, int(_config.get("active_objective_count", DEFAULT_ACTIVE_OBJECTIVE_COUNT)))

func _get_localized(source: Dictionary, key_prefix: String, fallback: String) -> String:
	var suffix := "it" if SettingsManager.language == &"it" else "en"
	return String(source.get("%s_%s" % [key_prefix, suffix], fallback))

func _rebuild_milestone_cache() -> void:
	_milestone_targets.clear()
	_milestone_rewards.clear()
	for entry in _config.get("milestones", []) as Array:
		if not (entry is Dictionary):
			continue
		var milestone := entry as Dictionary
		_milestone_targets.append(max(1, int(milestone.get("target", 1))))
		_milestone_rewards.append(max(0, int(milestone.get("reward_dna", 0))))
	if _milestone_targets.is_empty():
		_milestone_targets = [20, 55, 110, 180]
		_milestone_rewards = [10, 18, 26, 40]

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in override.keys():
		var base_value: Variant = result.get(key)
		var override_value: Variant = override[key]
		if base_value is Dictionary and override_value is Dictionary:
			result[key] = _deep_merge(base_value as Dictionary, override_value as Dictionary)
		else:
			result[key] = override_value
	return result

func _build_default_config() -> Dictionary:
	return {
		"event_id": String(DEFAULT_ACTIVE_EVENT_ID),
		"display_name_it": "Spring Recombination",
		"display_name_en": "Spring Recombination",
		"subtitle_it": "Evento stagionale a tempo con spore di ricombinazione e milestone DNA.",
		"subtitle_en": "Timed seasonal event with recombination spores and DNA milestones.",
		"currency_name_it": "Spore",
		"currency_name_en": "Spores",
		"active_objective_count": DEFAULT_ACTIVE_OBJECTIVE_COUNT,
		"milestones": [
			{"target": 20, "reward_dna": 10},
			{"target": 55, "reward_dna": 18},
			{"target": 110, "reward_dna": 26},
			{"target": 180, "reward_dna": 40}
		],
		"progress_rules": {
			"base_enemy": 1,
			"elite_enemy": 4,
			"boss_enemy": 10,
			"summary_it": "Accumuli Spore Evento eliminando nemici durante la partita: base +1, elite +4, boss +10. Il Settore Difesa applica poi il suo moltiplicatore.",
			"summary_en": "You earn Event Spores by defeating enemies during a match: base +1, elite +4, boss +10. The Defense Sector then applies its multiplier.",
			"note_it": "Le Operazioni Attive qui sotto sono obiettivi veri: avanzano in tempo reale e rilasciano DNA quando li riscatti.",
			"note_en": "The Active Operations below are real objectives: they advance live and award DNA when you claim them."
		},
		"objective_templates": []
	}
