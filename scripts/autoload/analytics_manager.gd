extends Node

signal analytics_changed

const MAX_RECENT_EVENTS := 20

var _session_count: int = 0
var _total_runs: int = 0
var _total_dna_earned: int = 0
var _total_runtime_seconds: int = 0
var _best_wave_seen: int = 0
var _event_counts: Dictionary = {}
var _recent_events: Array[Dictionary] = []
var _current_run_started_at: int = 0
var _current_run_peak_wave: int = 1

func _ready() -> void:
	load_state()
	_register_session()

func load_state() -> void:
	var save_data := SaveManager.get_save()
	var analytics := save_data.get("analytics", {}) as Dictionary
	_session_count = int(analytics.get("session_count", 0))
	_total_runs = int(analytics.get("total_runs", 0))
	_total_dna_earned = int(analytics.get("total_dna_earned", 0))
	_total_runtime_seconds = int(analytics.get("total_runtime_seconds", 0))
	_best_wave_seen = int(analytics.get("best_wave_seen", 0))
	_event_counts = (analytics.get("event_counts", {}) as Dictionary).duplicate(true)
	_recent_events.clear()
	for item in analytics.get("recent_events", []) as Array:
		if item is Dictionary:
			_recent_events.append((item as Dictionary).duplicate(true))
	_current_run_started_at = 0
	_current_run_peak_wave = 1
	analytics_changed.emit()

func save_state() -> void:
	SaveManager.write_save({
		"analytics": {
			"session_count": _session_count,
			"total_runs": _total_runs,
			"total_dna_earned": _total_dna_earned,
			"total_runtime_seconds": _total_runtime_seconds,
			"best_wave_seen": _best_wave_seen,
			"event_counts": _event_counts,
			"recent_events": _recent_events
		}
	})

func track_scene_enter(scene_id: StringName) -> void:
	track_event(&"scene_enter", {"scene_id": String(scene_id)})

func start_run(archetype_id: StringName, chapter_id: StringName) -> void:
	_current_run_started_at = Time.get_unix_time_from_system()
	_current_run_peak_wave = 1
	track_event(&"run_start", {
		"archetype_id": String(archetype_id),
		"chapter_id": String(chapter_id)
	})

func note_wave_reached(wave: int) -> void:
	if wave <= _current_run_peak_wave:
		return
	_current_run_peak_wave = wave
	_best_wave_seen = max(_best_wave_seen, wave)
	track_event(&"wave_reached", {"wave": wave})

func complete_run(summary: Dictionary) -> void:
	_total_runs += 1
	_best_wave_seen = max(_best_wave_seen, int(summary.get("wave_reached", 1)))
	_total_dna_earned += int(summary.get("dna_earned", 0))

	var duration_seconds: int = 0
	if _current_run_started_at > 0:
		duration_seconds = max(0, Time.get_unix_time_from_system() - _current_run_started_at)
	_total_runtime_seconds += duration_seconds
	_current_run_started_at = 0

	track_event(&"run_end", {
		"wave_reached": int(summary.get("wave_reached", 1)),
		"kills": int(summary.get("kills", 0)),
		"boss_kills": int(summary.get("boss_kills", 0)),
		"dna_earned": int(summary.get("dna_earned", 0)),
		"duration_seconds": duration_seconds
	})
	save_state()
	analytics_changed.emit()

func track_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_key := String(event_name)
	_event_counts[event_key] = int(_event_counts.get(event_key, 0)) + 1
	_recent_events.push_front({
		"name": event_key,
		"payload": payload.duplicate(true),
		"timestamp": Time.get_datetime_string_from_system(false, true)
	})
	while _recent_events.size() > MAX_RECENT_EVENTS:
		_recent_events.pop_back()
	save_state()
	analytics_changed.emit()

func get_snapshot() -> Dictionary:
	var average_runtime: float = 0.0
	if _total_runs > 0:
		average_runtime = float(_total_runtime_seconds) / float(_total_runs)

	var top_events: Array[Dictionary] = []
	for key in _event_counts.keys():
		top_events.append({
			"name": String(key),
			"count": int(_event_counts[key])
		})
	top_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	if top_events.size() > 5:
		top_events.resize(5)

	return {
		"session_count": _session_count,
		"total_runs": _total_runs,
		"total_dna_earned": _total_dna_earned,
		"total_runtime_seconds": _total_runtime_seconds,
		"average_runtime_seconds": average_runtime,
		"best_wave_seen": _best_wave_seen,
		"top_events": top_events,
		"recent_events": _recent_events.duplicate(true)
	}

func _register_session() -> void:
	_session_count += 1
	track_event(&"session_start", {"session_count": _session_count})
