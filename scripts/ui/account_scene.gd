extends Control
class_name AccountSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _status_chip: Label
var _message_label: Label

var _play_games_title: Label
var _play_games_note: Label
var _play_games_button: Button

var _google_title: Label
var _google_note: Label
var _google_button: Button
var _google_check_button: Button

var _backdoor_title: Label
var _backdoor_note: Label
var _name_input: LineEdit
var _email_input: LineEdit
var _location_input: LineEdit
var _send_request_button: Button
var _code_input: LineEdit
var _verify_button: Button
var _helper_label: Label
var _logout_button: Button
var _back_button: Button
var _backend_warmup_running := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"account_center")

	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)
	if not AccountAuthManager.auth_state_changed.is_connected(_refresh_ui):
		AccountAuthManager.auth_state_changed.connect(_refresh_ui)

	_refresh_ui()
	if AccountAuthManager.is_remote_backend_enabled():
		_warm_backend()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.025, 0.042, 0.07, 1.0)
	backdrop.accent_a = Color(0.34, 0.92, 0.84, 0.26)
	backdrop.accent_b = Color(1.0, 0.74, 0.4, 0.18)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.2)
	add_child(backdrop)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	root.add_child(layout)

	var header := PanelContainer.new()
	BioUI.style_panel(header, Color(0.06, 0.1, 0.15, 0.92), Color(0.37, 0.92, 0.84, 0.88), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 36, Color(0.98, 1.0, 0.99, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 16)
	header_box.add_child(_subtitle_label)

	_status_chip = Label.new()
	_status_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_status_chip, Color(0.08, 0.13, 0.18, 0.92), Color(1.0, 0.77, 0.41, 0.86))
	header_box.add_child(_status_chip)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_body(_message_label, BioUI.COLOR_TEXT, 15)
	header_box.add_child(_message_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var play_games_panel := PanelContainer.new()
	BioUI.style_panel(play_games_panel, Color(0.07, 0.14, 0.1, 0.94), Color(0.42, 0.96, 0.56, 0.82), 24, 16)
	content.add_child(play_games_panel)

	var play_games_box := VBoxContainer.new()
	play_games_box.add_theme_constant_override("separation", 10)
	play_games_panel.add_child(play_games_box)

	_play_games_title = Label.new()
	BioUI.style_heading(_play_games_title, Color(0.42, 0.96, 0.56, 1.0), 24)
	play_games_box.add_child(_play_games_title)

	_play_games_note = Label.new()
	_play_games_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_play_games_note, 16)
	play_games_box.add_child(_play_games_note)

	_play_games_button = Button.new()
	BioUI.style_button(_play_games_button, Color(0.42, 0.96, 0.56, 1.0), 70.0)
	_play_games_button.pressed.connect(_on_play_games_pressed)
	play_games_box.add_child(_play_games_button)

	var google_panel := PanelContainer.new()
	BioUI.style_panel(google_panel, Color(0.08, 0.12, 0.18, 0.92), Color(0.46, 0.82, 1.0, 0.76), 24, 16)
	content.add_child(google_panel)

	var google_box := VBoxContainer.new()
	google_box.add_theme_constant_override("separation", 10)
	google_panel.add_child(google_box)

	_google_title = Label.new()
	BioUI.style_heading(_google_title, Color(0.46, 0.82, 1.0, 1.0), 24)
	google_box.add_child(_google_title)

	_google_note = Label.new()
	_google_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_google_note, 16)
	google_box.add_child(_google_note)

	_google_button = Button.new()
	BioUI.style_button(_google_button, Color(0.46, 0.82, 1.0, 1.0), 70.0)
	_google_button.pressed.connect(_on_google_pressed)
	google_box.add_child(_google_button)

	_google_check_button = Button.new()
	BioUI.style_button(_google_check_button, Color(0.35, 0.93, 0.84, 1.0), 64.0)
	_google_check_button.pressed.connect(_on_google_check_pressed)
	google_box.add_child(_google_check_button)

	var backdoor_panel := PanelContainer.new()
	BioUI.style_panel(backdoor_panel, Color(0.09, 0.11, 0.16, 0.94), Color(1.0, 0.77, 0.41, 0.8), 24, 16)
	content.add_child(backdoor_panel)

	var backdoor_box := VBoxContainer.new()
	backdoor_box.add_theme_constant_override("separation", 10)
	backdoor_panel.add_child(backdoor_box)

	_backdoor_title = Label.new()
	BioUI.style_heading(_backdoor_title, Color(1.0, 0.77, 0.41, 1.0), 24)
	backdoor_box.add_child(_backdoor_title)

	_backdoor_note = Label.new()
	_backdoor_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_backdoor_note, 16)
	backdoor_box.add_child(_backdoor_note)

	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(0.0, 56.0)
	backdoor_box.add_child(_name_input)

	_email_input = LineEdit.new()
	_email_input.custom_minimum_size = Vector2(0.0, 56.0)
	_email_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	backdoor_box.add_child(_email_input)

	_location_input = LineEdit.new()
	_location_input.custom_minimum_size = Vector2(0.0, 56.0)
	backdoor_box.add_child(_location_input)

	_send_request_button = Button.new()
	BioUI.style_button(_send_request_button, Color(1.0, 0.77, 0.41, 1.0), 70.0)
	_send_request_button.pressed.connect(_on_send_request_pressed)
	backdoor_box.add_child(_send_request_button)

	_code_input = LineEdit.new()
	_code_input.custom_minimum_size = Vector2(0.0, 56.0)
	_code_input.max_length = 6
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	backdoor_box.add_child(_code_input)

	_verify_button = Button.new()
	BioUI.style_button(_verify_button, Color(0.35, 0.93, 0.84, 1.0), 70.0)
	_verify_button.pressed.connect(_on_verify_pressed)
	backdoor_box.add_child(_verify_button)

	_helper_label = Label.new()
	_helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_helper_label, BioUI.COLOR_TEXT, 15)
	backdoor_box.add_child(_helper_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	_logout_button = Button.new()
	_logout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_logout_button, Color(1.0, 0.5, 0.45, 1.0), 68.0)
	_logout_button.pressed.connect(_on_logout_pressed)
	footer.add_child(_logout_button)

	_back_button = Button.new()
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 68.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	footer.add_child(_back_button)

func _refresh_ui(_unused = null) -> void:
	_title_label.text = SettingsManager.t("account.title")
	_subtitle_label.text = SettingsManager.t("account.subtitle")
	_play_games_title.text = SettingsManager.t("account.play_games_title")
	_play_games_button.text = SettingsManager.t("account.play_games_button")
	_google_title.text = SettingsManager.t("account.google_title")
	_google_note.text = SettingsManager.t("account.google_note")
	_google_button.text = SettingsManager.t("account.google_button")
	_google_check_button.text = SettingsManager.t("account.google_check_status")
	_backdoor_title.text = SettingsManager.t("account.backdoor_title")
	_backdoor_note.text = SettingsManager.t("account.backdoor_note")
	_name_input.placeholder_text = SettingsManager.t("account.name_placeholder")
	_email_input.placeholder_text = SettingsManager.t("account.email_placeholder")
	_location_input.placeholder_text = SettingsManager.t("account.location_placeholder")
	_code_input.placeholder_text = SettingsManager.t("account.code_placeholder")
	_send_request_button.text = SettingsManager.t("account.send_request")
	_verify_button.text = SettingsManager.t("account.verify_code")
	_logout_button.text = SettingsManager.t("account.logout")
	_back_button.text = SettingsManager.t("common.main_menu")

	var state := AccountAuthManager.get_state()
	var provider := String(state.get("provider", "guest"))
	var display_name := String(state.get("display_name", ""))
	var email := String(state.get("email", ""))
	var status := AccountAuthManager.get_status()

	match status:
		&"pending_google":
			_status_chip.text = SettingsManager.t("account.status_pending_google")
			var google_summary := AccountAuthManager.get_google_device_summary()
			var user_code := String(google_summary.get("user_code", ""))
			var verification_url := String(google_summary.get("verification_url", ""))
			if not user_code.is_empty() and not verification_url.is_empty():
				_message_label.text = SettingsManager.t("account.google_device_hint") % [user_code, verification_url]
			else:
				_message_label.text = SettingsManager.t("account.google_pending")
		&"pending_backdoor":
			_status_chip.text = SettingsManager.t("account.status_pending_backdoor")
			var pending := AccountAuthManager.get_pending_summary()
			_message_label.text = SettingsManager.t("account.pending_hint") % [
				String(pending.get("display_name", "")),
				String(pending.get("email", "")),
				String(pending.get("location", "")),
				String(pending.get("requested_at", ""))
		]
		&"authenticated":
			var provider_name := _get_provider_display_name(provider)
			_status_chip.text = SettingsManager.t("account.status_authenticated") % [provider_name]
			_message_label.text = SettingsManager.t("account.authenticated_hint") % [
				display_name,
				email,
				String(state.get("location", ""))
			]
		_:
			_status_chip.text = SettingsManager.t("account.status_guest")
			if _message_label.text.is_empty():
				_message_label.text = ""

	var play_games_note := SettingsManager.t("account.play_games_note")
	if not AccountAuthManager.is_play_games_enabled():
		play_games_note = SettingsManager.t("account.play_games_unavailable")
	elif OS.get_name() != "Android":
		play_games_note = SettingsManager.t("account.play_games_android_only")
	elif not AccountAuthManager.has_play_games_server_client_id():
		play_games_note = SettingsManager.t("account.play_games_missing_server_client_id")
	elif not AccountAuthManager.is_play_games_runtime_available():
		play_games_note = SettingsManager.t("account.play_games_plugin_missing")
	_play_games_note.text = play_games_note

	_logout_button.visible = status != &"guest"
	_verify_button.disabled = status != &"pending_backdoor"
	_google_check_button.visible = status == &"pending_google" and AccountAuthManager.is_remote_backend_enabled()
	_play_games_button.disabled = not AccountAuthManager.can_start_play_games_signin()
	_google_button.disabled = AccountAuthManager.is_remote_backend_enabled() and not AccountAuthManager.is_google_available()

	if status == &"pending_backdoor":
		var pending := AccountAuthManager.get_pending_summary()
		if _name_input.text.is_empty():
			_name_input.text = String(pending.get("display_name", ""))
		if _email_input.text.is_empty():
			_email_input.text = String(pending.get("email", ""))
		if _location_input.text.is_empty():
			_location_input.text = String(pending.get("location", ""))
		_helper_label.text = SettingsManager.t("account.pending_hint") % [
			String(pending.get("display_name", "")),
			String(pending.get("email", "")),
			String(pending.get("location", "")),
			String(pending.get("requested_at", ""))
		]
	elif status == &"authenticated":
		_helper_label.text = SettingsManager.t("account.authenticated_hint") % [
			display_name,
			email,
			String(state.get("location", ""))
		]
	elif status == &"pending_google":
		var google_summary := AccountAuthManager.get_google_device_summary()
		var user_code := String(google_summary.get("user_code", ""))
		var verification_url := String(google_summary.get("verification_url", ""))
		if not user_code.is_empty() and not verification_url.is_empty():
			_helper_label.text = SettingsManager.t("account.google_device_hint") % [user_code, verification_url]
		else:
			_helper_label.text = SettingsManager.t("account.google_pending")
	else:
		_helper_label.text = _google_note.text

func _get_provider_display_name(provider: String) -> String:
	match provider:
		"backdoor":
			return "BackDoor Heroes"
		"play_games":
			return "Play Giochi"
		_:
			return "Google"

func _warm_backend() -> void:
	if _backend_warmup_running:
		return
	_backend_warmup_running = true
	_message_label.text = SettingsManager.t("account.backend_warming")
	var result := await AccountAuthManager.ping_backend()
	_backend_warmup_running = false
	if not bool(result.get("ok", false)):
		_apply_message_result(result)
	elif AccountAuthManager.get_status() == &"guest":
		_message_label.text = SettingsManager.t("account.backend_ready")

func _on_play_games_pressed() -> void:
	_play_games_button.disabled = true
	_message_label.text = SettingsManager.t("account.backend_warming")
	var result := await AccountAuthManager.start_play_games_signin()
	_play_games_button.disabled = not AccountAuthManager.can_start_play_games_signin()
	_apply_message_result(result)

func _on_google_pressed() -> void:
	_google_button.disabled = true
	var result := await AccountAuthManager.start_google_signin()
	_google_button.disabled = AccountAuthManager.is_remote_backend_enabled() and not AccountAuthManager.is_google_available()
	_apply_message_result(result)

func _on_send_request_pressed() -> void:
	_send_request_button.disabled = true
	var result := await AccountAuthManager.start_backdoor_registration(_name_input.text, _email_input.text, _location_input.text)
	_send_request_button.disabled = false
	_apply_message_result(result)

func _on_verify_pressed() -> void:
	_verify_button.disabled = true
	var result := await AccountAuthManager.verify_backdoor_code(_code_input.text)
	if bool(result.get("ok", false)):
		_code_input.text = ""
	_verify_button.disabled = AccountAuthManager.get_status() != &"pending_backdoor"
	_apply_message_result(result)

func _on_google_check_pressed() -> void:
	_google_check_button.disabled = true
	var result := await AccountAuthManager.poll_google_status()
	_google_check_button.disabled = false
	_apply_message_result(result)

func _on_logout_pressed() -> void:
	AccountAuthManager.logout()
	_name_input.text = ""
	_email_input.text = ""
	_location_input.text = ""
	_code_input.text = ""
	_message_label.text = ""
	_helper_label.text = ""

func _apply_message_result(result: Dictionary) -> void:
	var key := String(result.get("message_key", ""))
	if not key.is_empty():
		var text := SettingsManager.t(key)
		var detail := String(result.get("detail", "")).strip_edges()
		if not detail.is_empty() and (OS.has_feature("editor") or OS.is_debug_build()):
			text += "\n%s" % detail
		_message_label.text = text
	_refresh_ui()
