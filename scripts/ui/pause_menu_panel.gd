extends Control
class_name PauseMenuPanel

const BioUI = preload("res://scripts/ui/bio_ui.gd")

signal continue_requested
signal save_requested
signal exit_requested

var _title_label: Label
var _subtitle_label: Label
var _continue_button: Button
var _save_button: Button
var _options_button: Button
var _exit_button: Button
var _options_box: VBoxContainer
var _audio_button: Button
var _graphics_button: Button
var _language_buttons: Dictionary = {}
var _status_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	BioUI.style_root(self)
	_build_ui()
	if not SettingsManager.language_changed.is_connected(_refresh_texts):
		SettingsManager.language_changed.connect(_refresh_texts)
	if not SettingsManager.audio_changed.is_connected(_refresh_texts):
		SettingsManager.audio_changed.connect(_refresh_texts)
	if not SettingsManager.graphics_mode_changed.is_connected(_refresh_texts):
		SettingsManager.graphics_mode_changed.connect(_refresh_texts)
	_refresh_texts()

func show_panel() -> void:
	visible = true
	_options_box.visible = false
	_status_label.text = ""
	_refresh_texts()

func hide_panel() -> void:
	visible = false

func show_saved_feedback() -> void:
	_status_label.text = SettingsManager.t("pause.save_done")

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.02, 0.04, 0.74)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(420.0, 0.0)
	BioUI.style_panel(shell, Color(0.05, 0.08, 0.14, 0.96), Color(0.43, 0.84, 1.0, 0.9), 30, 20)
	center.add_child(shell)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	shell.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 34, Color(0.97, 0.99, 1.0, 1.0))
	box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_subtitle_label, 15)
	box.add_child(_subtitle_label)

	_continue_button = _make_action_button(Color(0.36, 0.93, 0.84, 1.0))
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	box.add_child(_continue_button)

	_save_button = _make_action_button(Color(1.0, 0.76, 0.41, 1.0))
	_save_button.pressed.connect(func() -> void: save_requested.emit())
	box.add_child(_save_button)

	_options_button = _make_action_button(Color(0.45, 0.83, 1.0, 1.0))
	_options_button.pressed.connect(_on_options_pressed)
	box.add_child(_options_button)

	_exit_button = _make_action_button(Color(1.0, 0.52, 0.47, 1.0))
	_exit_button.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(_exit_button)

	_options_box = VBoxContainer.new()
	_options_box.visible = false
	_options_box.add_theme_constant_override("separation", 10)
	box.add_child(_options_box)

	var options_panel := PanelContainer.new()
	BioUI.style_panel(options_panel, Color(0.07, 0.11, 0.17, 0.95), Color(0.45, 0.83, 1.0, 0.72), 24, 16)
	_options_box.add_child(options_panel)

	var options_stack := VBoxContainer.new()
	options_stack.add_theme_constant_override("separation", 10)
	options_panel.add_child(options_stack)

	_audio_button = _make_small_button(Color(0.37, 0.93, 0.82, 1.0))
	_audio_button.pressed.connect(func() -> void: SettingsManager.toggle_audio())
	options_stack.add_child(_audio_button)

	_graphics_button = _make_small_button(Color(0.82, 0.62, 1.0, 1.0))
	_graphics_button.pressed.connect(func() -> void: SettingsManager.cycle_graphics_mode())
	options_stack.add_child(_graphics_button)

	var language_flow := HFlowContainer.new()
	language_flow.add_theme_constant_override("h_separation", 8)
	language_flow.add_theme_constant_override("v_separation", 8)
	options_stack.add_child(language_flow)

	for language_id in SettingsManager.get_available_languages():
		var button := _make_small_button(Color(0.45, 0.83, 1.0, 1.0))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(120.0, 48.0)
		button.pressed.connect(_on_language_pressed.bind(language_id))
		language_flow.add_child(button)
		_language_buttons[String(language_id)] = button

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_status_label, 14)
	box.add_child(_status_label)

func _make_action_button(accent: Color) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0.0, 62.0)
	BioUI.style_button(button, accent, 62.0)
	return button

func _make_small_button(accent: Color) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0.0, 52.0)
	BioUI.style_button(button, accent, 52.0)
	return button

func _refresh_texts(_unused = null) -> void:
	_title_label.text = SettingsManager.t("pause.title")
	_subtitle_label.text = SettingsManager.t("pause.subtitle")
	_continue_button.text = SettingsManager.t("pause.continue")
	_save_button.text = SettingsManager.t("pause.save")
	_options_button.text = SettingsManager.t("pause.options")
	_exit_button.text = SettingsManager.t("pause.exit")
	_audio_button.text = SettingsManager.t("options.audio_on") if SettingsManager.audio_enabled else SettingsManager.t("options.audio_off")
	_graphics_button.text = SettingsManager.t("options.graphics_cycle") % [SettingsManager.get_graphics_mode_display_name(SettingsManager.graphics_mode)]

	for language_id in SettingsManager.get_available_languages():
		var button := _language_buttons.get(String(language_id)) as Button
		if button == null:
			continue
		button.text = SettingsManager.get_language_display_name(language_id)
		button.button_pressed = SettingsManager.language == language_id

func _on_options_pressed() -> void:
	_options_box.visible = not _options_box.visible
	if _options_box.visible:
		_status_label.text = SettingsManager.t("pause.options_hint")
	else:
		_status_label.text = ""

func _on_language_pressed(language_id: StringName) -> void:
	SettingsManager.set_language(language_id)
	_status_label.text = SettingsManager.t("pause.language_updated")
