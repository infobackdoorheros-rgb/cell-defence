extends Node

signal auth_state_changed

const SUPPORT_EMAIL := "info.backdoorheros@gmail.com"
const GOOGLE_SIGNIN_URL := "https://accounts.google.com/"
const BACKEND_CONFIG_PATH := "res://data/config/auth_backend.json"
const DEFAULT_BACKEND_CONFIG := {
	"mode": "remote",
	"base_url": "",
	"public_base_url": "",
	"request_timeout_seconds": 75.0,
	"google_device_flow_enabled": false,
	"allow_local_fallback": false
}

var _auth_state: Dictionary = {}
var _backend_config: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _backend_ready_until_msec: int = 0

func _ready() -> void:
	_rng.randomize()
	load_state()
	reload_backend_config()

func reload_backend_config() -> void:
	_backend_config = DEFAULT_BACKEND_CONFIG.duplicate(true)
	if not FileAccess.file_exists(BACKEND_CONFIG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BACKEND_CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in (parsed as Dictionary).keys():
		_backend_config[key] = parsed[key]

func load_state() -> void:
	var save_data := SaveManager.get_save()
	var stored := (save_data.get("account_auth", {}) as Dictionary).duplicate(true)
	_auth_state = _merge_defaults(stored)
	auth_state_changed.emit()

func get_state() -> Dictionary:
	return _auth_state.duplicate(true)

func get_backend_config() -> Dictionary:
	return _backend_config.duplicate(true)

func is_remote_backend_enabled() -> bool:
	return String(_backend_config.get("mode", "local")) == "remote" and not String(_backend_config.get("base_url", "")).strip_edges().is_empty()

func is_google_available() -> bool:
	if is_remote_backend_enabled():
		return bool(_backend_config.get("google_device_flow_enabled", false))
	return _allow_local_fallback()

func is_authenticated() -> bool:
	return String(_auth_state.get("status", "guest")) == "authenticated"

func is_pending() -> bool:
	var status := String(_auth_state.get("status", "guest"))
	return status == "pending_google" or status == "pending_backdoor"

func get_status() -> StringName:
	return StringName(_auth_state.get("status", "guest"))

func get_provider() -> StringName:
	return StringName(_auth_state.get("provider", "guest"))

func get_display_name() -> String:
	return String(_auth_state.get("display_name", ""))

func get_email() -> String:
	return String(_auth_state.get("email", ""))

func get_google_device_summary() -> Dictionary:
	return {
		"user_code": String(_auth_state.get("google_user_code", "")),
		"verification_url": String(_auth_state.get("google_verification_url", "")),
		"device_code": String(_auth_state.get("google_device_code", ""))
	}

func start_google_signin() -> Dictionary:
	if is_remote_backend_enabled():
		var warmup := await ping_backend()
		if not bool(warmup.get("ok", false)):
			return warmup
		return await _start_google_signin_remote()
	if not _allow_local_fallback():
		return {
			"ok": false,
			"message_key": "account.backend_not_configured"
		}

	_auth_state["provider"] = "google"
	_auth_state["status"] = "pending_google"
	_save_state()
	OS.shell_open(GOOGLE_SIGNIN_URL)
	return {
		"ok": true,
		"message_key": "account.google_pending"
	}

func start_backdoor_registration(display_name: String, email: String, location: String) -> Dictionary:
	if is_remote_backend_enabled():
		var warmup := await ping_backend()
		if not bool(warmup.get("ok", false)):
			return warmup
		return await _start_backdoor_registration_remote(display_name, email, location)
	if not _allow_local_fallback():
		return {
			"ok": false,
			"message_key": "account.backend_not_configured"
		}

	return _start_backdoor_registration_local(display_name, email, location)

func verify_backdoor_code(code: String) -> Dictionary:
	if is_remote_backend_enabled():
		var warmup := await ping_backend()
		if not bool(warmup.get("ok", false)):
			return warmup
		return await _verify_backdoor_code_remote(code)

	return _verify_backdoor_code_local(code)

func poll_google_status() -> Dictionary:
	if not is_remote_backend_enabled():
		return {
			"ok": false,
			"message_key": "account.google_unavailable"
		}

	var device_code := String(_auth_state.get("google_device_code", ""))
	if device_code.is_empty():
		return {
			"ok": false,
			"message_key": "account.google_unavailable"
		}

	var warmup := await ping_backend()
	if not bool(warmup.get("ok", false)):
		return warmup

	var response := await _request_json(
		HTTPClient.METHOD_GET,
		"/api/auth/google/device/status?deviceCode=%s" % device_code.uri_encode()
	)
	if not bool(response.get("ok", false)):
		return response

	var payload := response.get("payload", {}) as Dictionary
	var status := String(payload.get("status", "pending"))
	if status == "authenticated":
		var profile := payload.get("profile", {}) as Dictionary
		_auth_state["provider"] = "google"
		_auth_state["status"] = "authenticated"
		_auth_state["display_name"] = String(profile.get("displayName", "Google Pilot"))
		_auth_state["email"] = String(profile.get("email", ""))
		_clear_pending_state()
		_save_state()
		return {
			"ok": true,
			"message_key": String(payload.get("messageKey", "account.verified"))
		}
	if status == "expired":
		_clear_pending_state()
		_auth_state["provider"] = "guest"
		_auth_state["status"] = "guest"
		_save_state()
		return {
			"ok": false,
			"message_key": String(payload.get("messageKey", "account.google_expired"))
		}

	return {
		"ok": true,
		"message_key": String(payload.get("messageKey", "account.google_waiting"))
	}

func logout() -> void:
	_auth_state = _merge_defaults({})
	_save_state()

func ping_backend(force: bool = false) -> Dictionary:
	if not is_remote_backend_enabled():
		return {
			"ok": false,
			"message_key": "account.backend_not_configured"
		}
	var now := Time.get_ticks_msec()
	if not force and now < _backend_ready_until_msec:
		return {
			"ok": true,
			"message_key": "account.backend_ready"
		}
	var response := await _request_json(HTTPClient.METHOD_GET, "/api/health")
	if bool(response.get("ok", false)):
		var payload := response.get("payload", {}) as Dictionary
		if bool(payload.get("ok", false)):
			_backend_ready_until_msec = now + 120000
			return {
				"ok": true,
				"message_key": "account.backend_ready"
			}
	return response

func get_pending_summary() -> Dictionary:
	return {
		"display_name": String(_auth_state.get("pending_display_name", "")),
		"email": String(_auth_state.get("pending_email", "")),
		"location": String(_auth_state.get("pending_location", "")),
		"requested_at": String(_auth_state.get("pending_requested_at", ""))
	}

func _start_google_signin_remote() -> Dictionary:
	if not bool(_backend_config.get("google_device_flow_enabled", false)):
		return {
			"ok": false,
			"message_key": "account.google_unavailable"
		}

	var response := await _request_json(HTTPClient.METHOD_POST, "/api/auth/google/device/start", {})
	if not bool(response.get("ok", false)):
		return response

	var payload := response.get("payload", {}) as Dictionary
	_auth_state["provider"] = "google"
	_auth_state["status"] = "pending_google"
	_auth_state["google_device_code"] = String(payload.get("deviceCode", ""))
	_auth_state["google_user_code"] = String(payload.get("userCode", ""))
	_auth_state["google_verification_url"] = String(payload.get("verificationUrl", ""))
	_save_state()

	var verification_url := String(payload.get("verificationUrl", ""))
	if not verification_url.is_empty():
		OS.shell_open(verification_url)

	return {
		"ok": true,
		"message_key": String(payload.get("messageKey", "account.google_device_started"))
	}

func _start_backdoor_registration_remote(display_name: String, email: String, location: String) -> Dictionary:
	var safe_name := display_name.strip_edges()
	var safe_email := email.strip_edges().to_lower()
	var safe_location := location.strip_edges()
	if safe_name.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_name_required"
		}
	if not _is_valid_email(safe_email):
		return {
			"ok": false,
			"message_key": "account.error_invalid_email"
		}
	if safe_location.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_location_required"
		}

	var response := await _request_json(HTTPClient.METHOD_POST, "/api/auth/backdoor/register", {
		"displayName": safe_name,
		"email": safe_email,
		"location": safe_location
	})
	if not bool(response.get("ok", false)):
		return response

	var payload := response.get("payload", {}) as Dictionary
	_auth_state["provider"] = "backdoor"
	_auth_state["status"] = "pending_backdoor"
	_auth_state["pending_display_name"] = safe_name
	_auth_state["pending_email"] = safe_email
	_auth_state["pending_location"] = safe_location
	_auth_state["pending_code"] = ""
	_auth_state["pending_requested_at"] = String(payload.get("requestedAt", Time.get_datetime_string_from_system()))
	_save_state()

	return {
		"ok": true,
		"message_key": String(payload.get("messageKey", "account.backdoor_mail_opened"))
	}

func _verify_backdoor_code_remote(code: String) -> Dictionary:
	var safe_code := code.strip_edges()
	if safe_code.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_code_required"
		}

	var pending_email := String(_auth_state.get("pending_email", ""))
	if not _is_valid_email(pending_email):
		return {
			"ok": false,
			"message_key": "account.error_invalid_email"
		}

	var response := await _request_json(HTTPClient.METHOD_POST, "/api/auth/backdoor/verify", {
		"email": pending_email,
		"code": safe_code
	})
	if not bool(response.get("ok", false)):
		return response

	var payload := response.get("payload", {}) as Dictionary
	var profile := payload.get("profile", {}) as Dictionary
	_auth_state["provider"] = "backdoor"
	_auth_state["status"] = "authenticated"
	_auth_state["player_id"] = String(profile.get("playerId", ""))
	_auth_state["display_name"] = String(profile.get("displayName", _auth_state.get("pending_display_name", "")))
	_auth_state["email"] = String(profile.get("email", pending_email))
	_auth_state["location"] = String(profile.get("location", _auth_state.get("pending_location", "")))
	_auth_state["registered_at"] = String(profile.get("registeredAt", Time.get_datetime_string_from_system()))
	_clear_pending_state()
	_save_state()

	return {
		"ok": true,
		"message_key": String(payload.get("messageKey", "account.verified"))
	}

func _start_backdoor_registration_local(display_name: String, email: String, location: String) -> Dictionary:
	var safe_name := display_name.strip_edges()
	var safe_email := email.strip_edges().to_lower()
	var safe_location := location.strip_edges()
	if safe_name.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_name_required"
		}
	if not _is_valid_email(safe_email):
		return {
			"ok": false,
			"message_key": "account.error_invalid_email"
		}
	if safe_location.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_location_required"
		}

	var verification_code := _generate_code()
	_auth_state["provider"] = "backdoor"
	_auth_state["status"] = "pending_backdoor"
	_auth_state["pending_display_name"] = safe_name
	_auth_state["pending_email"] = safe_email
	_auth_state["pending_location"] = safe_location
	_auth_state["pending_code"] = verification_code
	_auth_state["pending_requested_at"] = Time.get_datetime_string_from_system()
	_save_state()

	var subject := "Cell Defense Account Registration"
	var body := "\n".join([
		"BackDoor Heroes account request",
		"",
		"Display name: %s" % safe_name,
		"Player email: %s" % safe_email,
		"Location: %s" % safe_location,
		"Verification code: %s" % verification_code,
		"Requested at: %s" % String(_auth_state.get("pending_requested_at", "")),
		"",
		"Reply with the same verification code to confirm the account."
	])
	OS.shell_open("mailto:%s?subject=%s&body=%s" % [
		SUPPORT_EMAIL.uri_encode(),
		subject.uri_encode(),
		body.uri_encode()
	])

	return {
		"ok": true,
		"message_key": "account.backdoor_mail_opened"
	}

func _verify_backdoor_code_local(code: String) -> Dictionary:
	var safe_code := code.strip_edges()
	if safe_code.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_code_required"
		}
	if safe_code != String(_auth_state.get("pending_code", "")):
		return {
			"ok": false,
			"message_key": "account.error_invalid_code"
		}

	_auth_state["provider"] = "backdoor"
	_auth_state["status"] = "authenticated"
	_auth_state["player_id"] = "local-%06d" % _rng.randi_range(100000, 999999)
	_auth_state["display_name"] = String(_auth_state.get("pending_display_name", ""))
	_auth_state["email"] = String(_auth_state.get("pending_email", ""))
	_auth_state["location"] = String(_auth_state.get("pending_location", ""))
	_auth_state["registered_at"] = Time.get_datetime_string_from_system()
	_clear_pending_state()
	_save_state()
	return {
		"ok": true,
		"message_key": "account.verified"
	}

func _request_json(method: int, endpoint: String, payload: Dictionary = {}) -> Dictionary:
	var base_url := String(_backend_config.get("base_url", "")).rstrip("/")
	if base_url.is_empty():
		return {
			"ok": false,
			"message_key": "account.error_backend_unreachable"
		}

	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = float(_backend_config.get("request_timeout_seconds", 15.0))

	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json"
	])
	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var error := request.request("%s%s" % [base_url, endpoint], headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"ok": false,
			"message_key": "account.error_backend_unreachable"
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_bytes := result[3] as PackedByteArray
	var parsed: Variant = {}
	if not response_bytes.is_empty():
		parsed = JSON.parse_string(response_bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}
	var payload_dict := parsed as Dictionary

	if request_result != HTTPRequest.RESULT_SUCCESS:
		var timeout_key := "account.error_backend_timeout" if request_result == HTTPRequest.RESULT_TIMEOUT else "account.error_backend_unreachable"
		return {
			"ok": false,
			"message_key": timeout_key,
			"detail": "HTTPRequest result %d" % request_result
		}

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"message_key": String(payload_dict.get("messageKey", "account.error_backend_unreachable")),
			"detail": String(payload_dict.get("detail", ""))
		}

	return {
		"ok": bool(payload_dict.get("ok", true)),
		"payload": payload_dict,
		"detail": String(payload_dict.get("detail", ""))
	}

func _save_state() -> void:
	SaveManager.write_save({
		"account_auth": _auth_state
	})
	auth_state_changed.emit()

func _clear_pending_state() -> void:
	_auth_state["pending_display_name"] = ""
	_auth_state["pending_email"] = ""
	_auth_state["pending_location"] = ""
	_auth_state["pending_code"] = ""
	_auth_state["pending_requested_at"] = ""
	_auth_state["google_device_code"] = ""
	_auth_state["google_user_code"] = ""
	_auth_state["google_verification_url"] = ""

func _merge_defaults(data: Dictionary) -> Dictionary:
	var merged := {
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
	}
	for key in data.keys():
		merged[key] = data[key]
	return merged

func _generate_code() -> String:
	return "%06d" % _rng.randi_range(100000, 999999)

func _allow_local_fallback() -> bool:
	if not bool(_backend_config.get("allow_local_fallback", false)):
		return false
	return OS.has_feature("editor") or OS.is_debug_build()

func _is_valid_email(value: String) -> bool:
	return value.contains("@") and value.contains(".") and value.length() >= 6
