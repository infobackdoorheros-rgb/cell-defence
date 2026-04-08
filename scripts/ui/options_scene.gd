extends Control
class_name OptionsSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _profile_label: Label
var _audio_title_label: Label
var _audio_button: Button
var _graphics_title_label: Label
var _graphics_note_label: Label
var _graphics_button: Button
var _language_title_label: Label
var _language_note_label: Label
var _language_buttons: Dictionary = {}
var _reset_title_label: Label
var _reset_desc_label: Label
var _reset_button: Button
var _reset_status_label: Label
var _back_button: Button
var _reset_confirm_pending: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"options")
	if not SettingsManager.language_changed.is_connected(_refresh_texts):
		SettingsManager.language_changed.connect(_refresh_texts)
	if not SettingsManager.audio_changed.is_connected(_refresh_texts):
		SettingsManager.audio_changed.connect(_refresh_texts)
	if not SettingsManager.graphics_mode_changed.is_connected(_refresh_texts):
		SettingsManager.graphics_mode_changed.connect(_refresh_texts)
	if not MetaProgression.profile_changed.is_connected(_refresh_texts):
		MetaProgression.profile_changed.connect(_refresh_texts)
	_refresh_texts()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.024, 0.045, 0.07, 1.0)
	backdrop.accent_a = Color(0.35, 0.92, 0.84, 0.28)
	backdrop.accent_b = Color(1.0, 0.72, 0.42, 0.18)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.2)
	add_child(backdrop)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 22)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 22)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	root.add_child(layout)

	var header := PanelContainer.new()
	BioUI.style_panel(header, Color(0.06, 0.1, 0.15, 0.9), Color(0.37, 0.92, 0.84, 0.88), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 38, Color(0.98, 1.0, 0.99, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 18)
	header_box.add_child(_subtitle_label)

	_profile_label = Label.new()
	_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_profile_label, Color(0.08, 0.13, 0.18, 0.92), Color(1.0, 0.77, 0.41, 0.86))
	header_box.add_child(_profile_label)

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	layout.add_child(content_scroll)

	var content_box := VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 14)
	content_scroll.add_child(content_box)

	var audio_panel := PanelContainer.new()
	BioUI.style_panel(audio_panel, Color(0.07, 0.12, 0.17, 0.92), Color(0.35, 0.93, 0.84, 0.72), 24, 16)
	content_box.add_child(audio_panel)

	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 10)
	audio_panel.add_child(audio_box)

	_audio_title_label = Label.new()
	BioUI.style_heading(_audio_title_label, Color(0.35, 0.93, 0.84, 1.0), 24)
	audio_box.add_child(_audio_title_label)

	_audio_button = Button.new()
	BioUI.style_button(_audio_button, Color(0.35, 0.93, 0.84, 1.0), 72.0)
	_audio_button.pressed.connect(_on_audio_pressed)
	audio_box.add_child(_audio_button)

	var graphics_panel := PanelContainer.new()
	BioUI.style_panel(graphics_panel, Color(0.07, 0.11, 0.17, 0.92), Color(0.93, 0.56, 1.0, 0.7), 24, 16)
	content_box.add_child(graphics_panel)

	var graphics_box := VBoxContainer.new()
	graphics_box.add_theme_constant_override("separation", 10)
	graphics_panel.add_child(graphics_box)

	_graphics_title_label = Label.new()
	BioUI.style_heading(_graphics_title_label, Color(0.93, 0.56, 1.0, 1.0), 24)
	graphics_box.add_child(_graphics_title_label)

	_graphics_note_label = Label.new()
	_graphics_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_graphics_note_label, 16)
	graphics_box.add_child(_graphics_note_label)

	_graphics_button = Button.new()
	BioUI.style_button(_graphics_button, Color(0.93, 0.56, 1.0, 1.0), 72.0)
	_graphics_button.pressed.connect(_on_graphics_pressed)
	graphics_box.add_child(_graphics_button)

	var language_panel := PanelContainer.new()
	BioUI.style_panel(language_panel, Color(0.08, 0.12, 0.18, 0.92), Color(0.46, 0.82, 1.0, 0.76), 24, 16)
	content_box.add_child(language_panel)

	var language_box := VBoxContainer.new()
	language_box.add_theme_constant_override("separation", 10)
	language_panel.add_child(language_box)

	_language_title_label = Label.new()
	BioUI.style_heading(_language_title_label, Color(0.46, 0.82, 1.0, 1.0), 24)
	language_box.add_child(_language_title_label)

	_language_note_label = Label.new()
	_language_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_language_note_label, 16)
	language_box.add_child(_language_note_label)

	var language_flow := HFlowContainer.new()
	language_flow.add_theme_constant_override("h_separation", 10)
	language_flow.add_theme_constant_override("v_separation", 10)
	language_box.add_child(language_flow)

	for language_id in SettingsManager.get_available_languages():
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150.0, 66.0)
		BioUI.style_button(button, Color(0.46, 0.82, 1.0, 1.0), 66.0)
		button.pressed.connect(_on_language_pressed.bind(language_id))
		language_flow.add_child(button)
		_language_buttons[String(language_id)] = button

	var reset_panel := PanelContainer.new()
	BioUI.style_panel(reset_panel, Color(0.12, 0.08, 0.1, 0.92), Color(1.0, 0.5, 0.45, 0.76), 24, 16)
	content_box.add_child(reset_panel)

	var reset_box := VBoxContainer.new()
	reset_box.add_theme_constant_override("separation", 10)
	reset_panel.add_child(reset_box)

	_reset_title_label = Label.new()
	BioUI.style_heading(_reset_title_label, Color(1.0, 0.5, 0.45, 1.0), 24)
	reset_box.add_child(_reset_title_label)

	_reset_desc_label = Label.new()
	_reset_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_reset_desc_label, 16)
	reset_box.add_child(_reset_desc_label)

	_reset_button = Button.new()
	BioUI.style_button(_reset_button, Color(1.0, 0.5, 0.45, 1.0), 74.0)
	_reset_button.pressed.connect(_on_reset_pressed)
	reset_box.add_child(_reset_button)

	_reset_status_label = Label.new()
	_reset_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_reset_status_label, BioUI.COLOR_TEXT, 15)
	reset_box.add_child(_reset_status_label)

	_back_button = Button.new()
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layout.add_child(_back_button)

func _refresh_texts(_unused = null) -> void:
	_title_label.text = SettingsManager.t("options.title")
	_subtitle_label.text = SettingsManager.t("options.subtitle")
	_profile_label.text = SettingsManager.t("options.profile") % [MetaProgression.dna, MetaProgression.best_wave]
	_audio_title_label.text = SettingsManager.t("options.audio_title")
	_graphics_title_label.text = SettingsManager.t("options.graphics_title")
	_graphics_note_label.text = SettingsManager.t("options.graphics_note")
	_language_title_label.text = SettingsManager.t("options.language_title")
	_language_note_label.text = SettingsManager.t("options.language_note")
	_reset_title_label.text = SettingsManager.t("options.reset_title")
	_reset_desc_label.text = SettingsManager.t("options.reset_desc")
	_back_button.text = SettingsManager.t("common.main_menu")
	_audio_button.text = SettingsManager.t("options.audio_on") if SettingsManager.audio_enabled else SettingsManager.t("options.audio_off")
	_graphics_button.text = SettingsManager.t("options.graphics_cycle") % [SettingsManager.get_graphics_mode_display_name(SettingsManager.graphics_mode)]
	_reset_button.text = SettingsManager.t("options.reset_button")

	if _reset_confirm_pending:
		_reset_status_label.text = SettingsManager.t("options.reset_confirm")
	elif _reset_status_label.text != "":
		_reset_status_label.text = SettingsManager.t("options.reset_done")

	for language_id in SettingsManager.get_available_languages():
		var button := _language_buttons.get(String(language_id)) as Button
		if button == null:
			continue
		button.text = SettingsManager.get_language_display_name(language_id)
		button.button_pressed = SettingsManager.language == language_id

func _on_audio_pressed() -> void:
	SettingsManager.toggle_audio()

func _on_graphics_pressed() -> void:
	SettingsManager.cycle_graphics_mode()
	_refresh_texts()

func _on_language_pressed(language_id: StringName) -> void:
	SettingsManager.set_language(language_id)
	_refresh_texts()

func _on_reset_pressed() -> void:
	if not _reset_confirm_pending:
		_reset_confirm_pending = true
		_reset_status_label.text = SettingsManager.t("options.reset_confirm")
		return

	_reset_confirm_pending = false
	MetaProgression.reset_progress()
	_reset_status_label.text = SettingsManager.t("options.reset_done")
	_refresh_texts()
