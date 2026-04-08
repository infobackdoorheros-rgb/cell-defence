extends Node

signal event_progress_changed
signal milestone_reached(index: int, target: int)
signal milestone_claimed(index: int, reward_dna: int)

const ACTIVE_EVENT_ID: StringName = &"spring_recombination_2026"
const MILESTONE_TARGETS := [20, 55, 110, 180]
const MILESTONE_REWARDS := [10, 18, 26, 40]

var progress: int = 0
var claimed_milestones: Array[bool] = []
var reached_milestones: Array[bool] = []

func _ready() -> void:
	load_state()

func load_state() -> void:
	var save_data := SaveManager.get_save()
	var state := save_data.get("season_event", {}) as Dictionary
	progress = int(state.get("progress", 0))
	claimed_milestones = []
	reached_milestones = []
	for index in range(MILESTONE_TARGETS.size()):
		claimed_milestones.append(false)
		reached_milestones.append(false)

	var claimed_raw := state.get("claimed_milestones", []) as Array
	for index in range(min(claimed_raw.size(), claimed_milestones.size())):
		claimed_milestones[index] = bool(claimed_raw[index])

	for index in range(MILESTONE_TARGETS.size()):
		reached_milestones[index] = progress >= int(MILESTONE_TARGETS[index])

	event_progress_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"season_event": {
			"event_id": String(ACTIVE_EVENT_ID),
			"progress": progress,
			"claimed_milestones": claimed_milestones
		}
	})

func get_event_overview() -> Dictionary:
	var milestones: Array[Dictionary] = []
	for index in range(MILESTONE_TARGETS.size()):
		milestones.append({
			"index": index,
			"target": int(MILESTONE_TARGETS[index]),
			"reward_dna": int(MILESTONE_REWARDS[index]),
			"claimed": claimed_milestones[index],
			"reached": progress >= int(MILESTONE_TARGETS[index])
		})

	return {
		"event_id": ACTIVE_EVENT_ID,
		"display_name": SettingsManager.t("season.name"),
		"subtitle": SettingsManager.t("season.subtitle"),
		"currency_name": SettingsManager.t("season.currency"),
		"progress": progress,
		"max_target": int(MILESTONE_TARGETS[MILESTONE_TARGETS.size() - 1]),
		"milestones": milestones
	}

func register_enemy_defeat(enemy_tier: StringName, chapter_multiplier: float = 1.0) -> void:
	var amount: int = 1
	match enemy_tier:
		&"elite":
			amount = 4
		&"boss":
			amount = 10
	amount = max(1, int(round(float(amount) * max(chapter_multiplier, 0.5))))
	add_progress(amount)

func add_progress(amount: int) -> void:
	if amount <= 0:
		return
	progress += amount
	var changed := false
	for index in range(MILESTONE_TARGETS.size()):
		if reached_milestones[index]:
			continue
		if progress < int(MILESTONE_TARGETS[index]):
			continue
		reached_milestones[index] = true
		milestone_reached.emit(index, int(MILESTONE_TARGETS[index]))
		changed = true
	if changed or amount > 0:
		save_state()
		event_progress_changed.emit()

func claim_milestone(index: int) -> int:
	if index < 0 or index >= MILESTONE_TARGETS.size():
		return 0
	if claimed_milestones[index]:
		return 0
	if progress < int(MILESTONE_TARGETS[index]):
		return 0
	claimed_milestones[index] = true
	var reward_dna: int = int(MILESTONE_REWARDS[index])
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
