extends Node

const SAVE_PATH := "user://cell_defense_save.json"
const CURRENT_SAVE_VERSION := 5

var _cached_save: Dictionary = {}
var _pending_resume_saved_run: bool = false

func _ready() -> void:
	_cached_save = load_save()

func get_default_save() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"dna": 0,
		"best_wave": 0,
		"meta_levels": {},
		"analytics": {},
		"run_profile": {
			"selected_core_archetype": "sentinel_core",
			"selected_chapter": "chapter_capillary",
			"ftue_completed": false,
			"menu_tutorial_completed": false,
			"ftue_version": 0
		},
		"daily_missions": {},
		"season_event": {},
		"battle_pass": {},
		"offers": {},
		"shop_state": {
			"rewarded_day": "",
			"rewarded_claims_today": 0,
			"iap_test_claims": {}
		},
		"social_connections": {},
		"account_auth": {
			"provider": "guest",
			"status": "guest",
			"player_id": "",
			"display_name": "",
			"email": "",
			"location": "",
			"registered_at": "",
			"pending_display_name": "",
			"pending_email": "",
			"pending_location": "",
			"pending_code": "",
			"pending_requested_at": "",
			"deletion_pending_email": "",
			"deletion_pending_provider": "",
			"deletion_pending_code": "",
			"deletion_requested_at": "",
			"google_device_code": "",
			"google_user_code": "",
			"google_verification_url": "",
			"play_games_player_id": "",
			"play_games_title": "",
			"play_games_icon_uri": ""
		},
		"settings": {
			"audio_enabled": true,
			"language": "it",
			"graphics_mode": "auto"
		},
		"run_snapshot": {}
	}

func get_save() -> Dictionary:
	return _cached_save.duplicate(true)

func load_save() -> Dictionary:
	var defaults: Dictionary = get_default_save()
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return defaults

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults

	return _prepare_save_state(parsed as Dictionary)

func write_save(data: Dictionary) -> void:
	var merged: Dictionary = _deep_merge_dicts(_cached_save, data)
	_cached_save = _prepare_save_state(merged)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write save file at %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_cached_save, "\t"))

func _prepare_save_state(data: Dictionary) -> Dictionary:
	var migrated := _migrate_save(data)
	var merged := _deep_merge_dicts(get_default_save(), migrated)
	merged["save_version"] = CURRENT_SAVE_VERSION
	return merged

func _migrate_save(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var save_version := int(migrated.get("save_version", 0))

	if save_version < 1:
		var run_profile := (migrated.get("run_profile", {}) as Dictionary).duplicate(true)
		if bool(run_profile.get("ftue_completed", false)) and int(run_profile.get("ftue_version", 0)) <= 0:
			run_profile["ftue_version"] = 1
		migrated["run_profile"] = run_profile

	if save_version < 2:
		var settings := (migrated.get("settings", {}) as Dictionary).duplicate(true)
		if not settings.has("graphics_mode"):
			settings["graphics_mode"] = "auto"
		migrated["settings"] = settings

	if save_version < 3:
		var account_auth := (migrated.get("account_auth", {}) as Dictionary).duplicate(true)
		if not account_auth.has("player_id"):
			account_auth["player_id"] = ""
		if not account_auth.has("location"):
			account_auth["location"] = ""
		if not account_auth.has("registered_at"):
			account_auth["registered_at"] = ""
		if not account_auth.has("pending_location"):
			account_auth["pending_location"] = ""
		migrated["account_auth"] = account_auth

	if save_version < 4:
		var analytics: Variant = migrated.get("analytics", {})
		if typeof(analytics) != TYPE_DICTIONARY:
			migrated["analytics"] = {}

	if save_version < 5:
		var shop_state: Variant = migrated.get("shop_state", {})
		if typeof(shop_state) != TYPE_DICTIONARY:
			migrated["shop_state"] = {}
		var run_snapshot: Variant = migrated.get("run_snapshot", {})
		if typeof(run_snapshot) != TYPE_DICTIONARY:
			migrated["run_snapshot"] = {}

	migrated["save_version"] = CURRENT_SAVE_VERSION
	return migrated

func _deep_merge_dicts(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in overrides.keys():
		var override_value: Variant = overrides[key]
		var base_value: Variant = merged.get(key)
		if typeof(base_value) == TYPE_DICTIONARY and typeof(override_value) == TYPE_DICTIONARY:
			merged[key] = _deep_merge_dicts(base_value as Dictionary, override_value as Dictionary)
		else:
			merged[key] = override_value
	return merged

func reset_game_progress() -> void:
	var preserved_social: Dictionary = (_cached_save.get("social_connections", {}) as Dictionary).duplicate(true)
	var preserved_account: Dictionary = (_cached_save.get("account_auth", {}) as Dictionary).duplicate(true)
	var preserved_settings: Dictionary = (_cached_save.get("settings", {}) as Dictionary).duplicate(true)
	_cached_save = get_default_save()
	_cached_save["social_connections"] = preserved_social
	_cached_save["account_auth"] = preserved_account
	_cached_save["settings"] = preserved_settings
	write_save(_prepare_save_state(_cached_save))

func reset_for_account_deletion() -> void:
	var preserved_settings: Dictionary = (_cached_save.get("settings", {}) as Dictionary).duplicate(true)
	_cached_save = get_default_save()
	_cached_save["settings"] = preserved_settings
	write_save(_prepare_save_state(_cached_save))

func get_run_snapshot() -> Dictionary:
	return (_cached_save.get("run_snapshot", {}) as Dictionary).duplicate(true)

func has_run_snapshot() -> bool:
	return not get_run_snapshot().is_empty()

func save_run_snapshot(snapshot: Dictionary) -> void:
	write_save({
		"run_snapshot": snapshot
	})

func clear_run_snapshot() -> void:
	write_save({
		"run_snapshot": {}
	})

func request_resume_saved_run() -> void:
	_pending_resume_saved_run = true

func consume_resume_saved_run_request() -> bool:
	var should_resume := _pending_resume_saved_run
	_pending_resume_saved_run = false
	return should_resume
