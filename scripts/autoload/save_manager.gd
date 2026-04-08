extends Node

const SAVE_PATH := "user://cell_defense_save.json"
const CURRENT_SAVE_VERSION := 4

var _cached_save: Dictionary = {}

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
			"google_device_code": "",
			"google_user_code": "",
			"google_verification_url": ""
		},
		"settings": {
			"audio_enabled": true,
			"language": "it",
			"graphics_mode": "auto"
		}
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
