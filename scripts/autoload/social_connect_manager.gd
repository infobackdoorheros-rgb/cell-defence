extends Node

signal connections_changed

const PROVIDERS := {
	&"instagram": {
		"display_name": "Instagram",
		"url": "https://www.instagram.com/",
		"accent": Color(0.98, 0.56, 0.42, 1.0)
	},
	&"discord": {
		"display_name": "Discord",
		"url": "https://discord.com/",
		"accent": Color(0.48, 0.57, 1.0, 1.0)
	},
	&"x": {
		"display_name": "X",
		"url": "https://x.com/",
		"accent": Color(0.84, 0.92, 1.0, 1.0)
	},
	&"facebook": {
		"display_name": "Facebook",
		"url": "https://www.facebook.com/",
		"accent": Color(0.33, 0.58, 0.98, 1.0)
	}
}

var _connections: Dictionary = {}

func _ready() -> void:
	load_connections()

func load_connections() -> void:
	var save_data := SaveManager.get_save()
	_connections = (save_data.get("social_connections", {}) as Dictionary).duplicate(true)
	for provider_id in PROVIDERS.keys():
		var key := String(provider_id)
		if not _connections.has(key):
			_connections[key] = "unlinked"
	connections_changed.emit()

func get_provider_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for provider_id in PROVIDERS.keys():
		result.append(provider_id)
	return result

func is_enabled() -> bool:
	return RemoteConfigManager.get_bool("features.social_links_enabled", false)

func get_provider_info(provider_id: StringName) -> Dictionary:
	return (PROVIDERS.get(provider_id, {}) as Dictionary).duplicate(true)

func get_status(provider_id: StringName) -> StringName:
	return StringName(_connections.get(String(provider_id), "unlinked"))

func get_connected_count() -> int:
	if not is_enabled():
		return 0
	var total: int = 0
	for provider_id in PROVIDERS.keys():
		if get_status(provider_id) == &"linked":
			total += 1
	return total

func cycle_connection(provider_id: StringName) -> StringName:
	if not is_enabled():
		return &"disabled"
	var status := get_status(provider_id)
	match status:
		&"unlinked":
			request_link(provider_id)
			return &"pending"
		&"pending":
			confirm_link(provider_id)
			return &"linked"
		&"linked":
			unlink(provider_id)
			return &"unlinked"
		_:
			request_link(provider_id)
			return &"pending"

func request_link(provider_id: StringName) -> void:
	if not is_enabled():
		return
	var info := get_provider_info(provider_id)
	if info.is_empty():
		return
	OS.shell_open(String(info.get("url", "")))
	_connections[String(provider_id)] = "pending"
	_save_connections()

func confirm_link(provider_id: StringName) -> void:
	if not is_enabled():
		return
	_connections[String(provider_id)] = "linked"
	_save_connections()

func unlink(provider_id: StringName) -> void:
	if not is_enabled():
		return
	_connections[String(provider_id)] = "unlinked"
	_save_connections()

func _save_connections() -> void:
	SaveManager.write_save({
		"social_connections": _connections
	})
	connections_changed.emit()
