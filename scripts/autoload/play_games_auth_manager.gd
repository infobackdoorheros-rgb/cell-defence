extends Node

signal availability_changed(available: bool)

const PlayGamesSignInClientScript = preload("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd")
const PlayGamesPlayersClientScript = preload("res://addons/GodotPlayGameServices/scripts/players/players_client.gd")

const FLOW_TIMEOUT_SECONDS := 25.0

var _sign_in_client: Node
var _players_client: Node
var _available: bool = false
var _flow_active: bool = false
var _requested_interactive_sign_in: bool = false
var _require_server_code: bool = false
var _pending_server_client_id: String = ""
var _pending_force_refresh_token: bool = false
var _pending_player_profile: Dictionary = {}
var _pending_server_auth_code: String = ""
var _last_flow_result: Dictionary = {}

func _ready() -> void:
	call_deferred("_initialize_runtime")

func _initialize_runtime() -> void:
	_refresh_availability()
	if not _available:
		return
	_ensure_clients()

func is_available() -> bool:
	_refresh_availability()
	return _available

func start_authentication(server_client_id: String, force_refresh_token: bool = false) -> Dictionary:
	_refresh_availability()
	if not _available:
		var missing_key := "account.play_games_android_only"
		if OS.get_name() == "Android":
			missing_key = "account.play_games_plugin_missing"
		return {
			"ok": false,
			"message_key": missing_key
		}

	_ensure_clients()
	_flow_active = true
	_requested_interactive_sign_in = false
	_require_server_code = not server_client_id.strip_edges().is_empty()
	_pending_server_client_id = server_client_id.strip_edges()
	_pending_force_refresh_token = force_refresh_token
	_pending_player_profile.clear()
	_pending_server_auth_code = ""
	_last_flow_result.clear()

	_sign_in_client.is_authenticated()

	var deadline_msec := Time.get_ticks_msec() + int(FLOW_TIMEOUT_SECONDS * 1000.0)
	while _flow_active and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame

	if _flow_active:
		_complete_flow({
			"ok": false,
			"message_key": "account.play_games_timed_out"
		})

	return _last_flow_result.duplicate(true)

func _ensure_clients() -> void:
	if _sign_in_client == null:
		_sign_in_client = PlayGamesSignInClientScript.new()
		add_child(_sign_in_client)
		_sign_in_client.user_authenticated.connect(_on_user_authenticated)
		_sign_in_client.server_side_access_requested.connect(_on_server_side_access_requested)

	if _players_client == null:
		_players_client = PlayGamesPlayersClientScript.new()
		add_child(_players_client)
		_players_client.current_player_loaded.connect(_on_current_player_loaded)

func _refresh_availability() -> void:
	var previous := _available
	_available = _initialize_plugin()
	if previous != _available:
		availability_changed.emit(_available)

func _initialize_plugin() -> bool:
	if OS.get_name() != "Android":
		return false
	var plugin := get_node_or_null("/root/GodotPlayGameServices")
	if plugin == null:
		return false

	var result = plugin.initialize()
	return result == plugin.PlayGamesPluginError.OK and plugin.android_plugin != null

func _on_user_authenticated(is_authenticated: bool) -> void:
	if not _flow_active:
		return

	if not is_authenticated:
		if not _requested_interactive_sign_in:
			_requested_interactive_sign_in = true
			_sign_in_client.sign_in()
			return

		_complete_flow({
			"ok": false,
			"message_key": "account.play_games_signin_cancelled"
		})
		return

	_players_client.load_current_player(false)
	if _require_server_code:
		_sign_in_client.request_server_side_access(_pending_server_client_id, _pending_force_refresh_token)
	_try_finalize_flow()

func _on_current_player_loaded(current_player) -> void:
	if not _flow_active:
		return

	if current_player == null or String(current_player.player_id).strip_edges().is_empty():
		_complete_flow({
			"ok": false,
			"message_key": "account.play_games_player_unavailable"
		})
		return

	_pending_player_profile = {
		"playGamesPlayerId": String(current_player.player_id),
		"displayName": String(current_player.display_name),
		"title": String(current_player.title),
		"iconImageUri": String(current_player.icon_image_uri),
		"hiResImageUri": String(current_player.hi_res_image_uri)
	}
	_try_finalize_flow()

func _on_server_side_access_requested(token: String) -> void:
	if not _flow_active:
		return

	_pending_server_auth_code = token.strip_edges()
	if _require_server_code and _pending_server_auth_code.is_empty():
		_complete_flow({
			"ok": false,
			"message_key": "account.play_games_missing_server_code"
		})
		return

	_try_finalize_flow()

func _try_finalize_flow() -> void:
	if not _flow_active:
		return
	if _pending_player_profile.is_empty():
		return
	if _require_server_code and _pending_server_auth_code.is_empty():
		return

	_complete_flow({
		"ok": true,
		"player_profile": _pending_player_profile.duplicate(true),
		"server_auth_code": _pending_server_auth_code
	})

func _complete_flow(result: Dictionary) -> void:
	_last_flow_result = result.duplicate(true)
	_flow_active = false
	_requested_interactive_sign_in = false
	_require_server_code = false
	_pending_server_client_id = ""
	_pending_force_refresh_token = false
