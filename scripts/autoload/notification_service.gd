extends Node

signal availability_changed(available: bool)

const CONFIG_PATH := "res://data/config/notification_campaigns.json"

var _bridge_class = null
var _available: bool = false
var _config: Dictionary = {}
var _campaigns: Array[Dictionary] = []

func _ready() -> void:
	if not SettingsManager.notifications_changed.is_connected(_on_notifications_changed):
		SettingsManager.notifications_changed.connect(_on_notifications_changed)
	reload_campaigns()
	_initialize_runtime()
	call_deferred("_cancel_standard_reminders")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_cancel_standard_reminders()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_schedule_standard_reminders()

func is_available() -> bool:
	return _available

func schedule_standard_reminders() -> void:
	_schedule_standard_reminders()

func cancel_standard_reminders() -> void:
	_cancel_standard_reminders()

func reload_campaigns() -> void:
	_config = _build_default_config()
	_config = _deep_merge(_config, _read_json_dictionary(CONFIG_PATH))
	_campaigns.clear()
	for campaign in _config.get("campaigns", []) as Array:
		if campaign is Dictionary:
			_campaigns.append((campaign as Dictionary).duplicate(true))

func _initialize_runtime() -> void:
	if not OS.has_feature("android"):
		_available = false
		availability_changed.emit(false)
		return
	_bridge_class = JavaClassWrapper.wrap("com.godot.game.LocalNotificationBridge")
	_available = _bridge_class != null and bool(_bridge_class.initialize())
	availability_changed.emit(_available)
	if _available:
		_bridge_class.requestPermissionIfNeeded()

func _schedule_standard_reminders() -> void:
	if not SettingsManager.notifications_enabled:
		_cancel_standard_reminders()
		return
	if not _available or _bridge_class == null:
		return
	_bridge_class.requestPermissionIfNeeded()
	for campaign in _campaigns:
		if not bool(campaign.get("enabled", true)):
			continue
		_bridge_class.scheduleReminder(
			String(campaign.get("id", "")),
			max(60, int(campaign.get("delay_seconds", 3600))),
			_resolve_campaign_text(campaign, "title", SettingsManager.t("notify.title")),
			_resolve_campaign_text(campaign, "body", SettingsManager.t("notify.body.short"))
		)

func _cancel_standard_reminders() -> void:
	if not _available or _bridge_class == null:
		return
	for campaign in _campaigns:
		var reminder_id := String(campaign.get("id", ""))
		if reminder_id.is_empty():
			continue
		_bridge_class.cancelReminder(reminder_id)

func _on_notifications_changed(enabled: bool) -> void:
	if enabled:
		_schedule_standard_reminders()
	else:
		_cancel_standard_reminders()

func _resolve_campaign_text(campaign: Dictionary, prefix: String, fallback: String) -> String:
	var language_suffix := "it" if SettingsManager.language == &"it" else "en"
	var direct_key := String(campaign.get("%s_%s" % [prefix, language_suffix], ""))
	if not direct_key.is_empty():
		return direct_key
	var translation_key := String(campaign.get("%s_key" % prefix, ""))
	if not translation_key.is_empty():
		return SettingsManager.t(translation_key)
	return fallback

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
		"channel_id": "cell_defense_reengage",
		"campaigns": [
			{
				"id": "reengage_short",
				"enabled": true,
				"delay_seconds": 28800,
				"title_key": "notify.title",
				"body_key": "notify.body.short"
			},
			{
				"id": "reengage_daily",
				"enabled": true,
				"delay_seconds": 86400,
				"title_key": "notify.title",
				"body_key": "notify.body.daily"
			},
			{
				"id": "reengage_long",
				"enabled": true,
				"delay_seconds": 259200,
				"title_key": "notify.title",
				"body_key": "notify.body.long"
			}
		]
	}
