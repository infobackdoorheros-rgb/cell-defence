extends Control
class_name PrepBaySceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _summary_label: Label
var _briefing_panel: PanelContainer
var _briefing_title_label: Label
var _briefing_body_label: Label
var _core_buttons: Dictionary = {}
var _chapter_buttons: Dictionary = {}
var _launch_button: Button
var _back_button: Button

func _ready() -> void:
	ContentDB.reload_content()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"prep_bay")

	if not RunConfigManager.core_archetype_changed.is_connected(_refresh_ui):
		RunConfigManager.core_archetype_changed.connect(_refresh_ui)
	if not RunConfigManager.chapter_changed.is_connected(_refresh_ui):
		RunConfigManager.chapter_changed.connect(_refresh_ui)
	if not RunConfigManager.menu_tutorial_state_changed.is_connected(_refresh_ui):
		RunConfigManager.menu_tutorial_state_changed.connect(_refresh_ui)
	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)

	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.026, 0.046, 0.072, 1.0)
	backdrop.accent_a = Color(0.35, 0.92, 0.84, 0.28)
	backdrop.accent_b = Color(1.0, 0.73, 0.42, 0.18)
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
	BioUI.style_title(_title_label, 38, Color(0.98, 1.0, 0.99, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 17)
	header_box.add_child(_subtitle_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_summary_label, BioUI.COLOR_TEXT, 17)
	header_box.add_child(_summary_label)

	_briefing_panel = PanelContainer.new()
	BioUI.style_panel(_briefing_panel, Color(0.09, 0.1, 0.16, 0.94), Color(1.0, 0.77, 0.41, 0.74), 24, 14)
	header_box.add_child(_briefing_panel)

	var briefing_box := VBoxContainer.new()
	briefing_box.add_theme_constant_override("separation", 8)
	_briefing_panel.add_child(briefing_box)

	_briefing_title_label = Label.new()
	BioUI.style_heading(_briefing_title_label, Color(1.0, 0.77, 0.41, 1.0), 20)
	briefing_box.add_child(_briefing_title_label)

	_briefing_body_label = Label.new()
	_briefing_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_briefing_body_label, BioUI.COLOR_TEXT, 15)
	briefing_box.add_child(_briefing_body_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(640.0, 0.0)
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	content.add_child(_build_core_section())
	content.add_child(_build_chapter_section())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	_back_button = Button.new()
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	footer.add_child(_back_button)

	_launch_button = Button.new()
	_launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_launch_button, Color(0.37, 0.94, 0.84, 1.0), 74.0)
	_launch_button.pressed.connect(_on_launch_pressed)
	footer.add_child(_launch_button)

func _build_core_section() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.08, 0.12, 0.18, 0.92), Color(1.0, 0.56, 0.47, 0.74), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("prep.core_title")
	BioUI.style_heading(title, Color(1.0, 0.56, 0.47, 1.0), 24)
	box.add_child(title)

	var note := Label.new()
	note.text = SettingsManager.t("prep.core_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(note, 15)
	box.add_child(note)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	box.add_child(flow)

	for archetype in ContentDB.get_core_archetypes():
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(286.0, 132.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_button(button, archetype.accent_color, 120.0)
		button.pressed.connect(_on_core_selected.bind(archetype.archetype_id))
		flow.add_child(button)
		_core_buttons[String(archetype.archetype_id)] = button

	return panel

func _build_chapter_section() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.08, 0.12, 0.18, 0.92), Color(0.45, 0.82, 1.0, 0.76), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("prep.chapter_title")
	BioUI.style_heading(title, Color(0.45, 0.82, 1.0, 1.0), 24)
	box.add_child(title)

	var note := Label.new()
	note.text = SettingsManager.t("prep.chapter_note")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(note, 15)
	box.add_child(note)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	box.add_child(flow)

	for chapter in ContentDB.get_chapters():
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(286.0, 132.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_button(button, chapter.accent_color, 120.0)
		button.pressed.connect(_on_chapter_selected.bind(chapter.chapter_id))
		flow.add_child(button)
		_chapter_buttons[String(chapter.chapter_id)] = button

	return panel

func _refresh_ui(_unused = null) -> void:
	_title_label.text = SettingsManager.t("prep.title")
	_subtitle_label.text = SettingsManager.t("prep.subtitle")
	_briefing_title_label.text = SettingsManager.t("prep.briefing_title")
	_briefing_body_label.text = SettingsManager.t("prep.briefing_body")
	_back_button.text = SettingsManager.t("common.main_menu")
	_launch_button.text = SettingsManager.t("common.launch_run")
	_briefing_panel.visible = not RunConfigManager.menu_tutorial_completed

	var selected_archetype = RunConfigManager.get_selected_core_archetype()
	var selected_chapter = RunConfigManager.get_selected_chapter()
	if selected_archetype != null and selected_chapter != null:
		_summary_label.text = SettingsManager.t("prep.summary") % [
			selected_archetype.display_name,
			selected_archetype.active_skill_name,
			selected_chapter.display_name,
			selected_chapter.dna_multiplier,
			selected_chapter.atp_multiplier
		]

	for key in _core_buttons.keys():
		var button := _core_buttons[key] as Button
		var archetype = ContentDB.get_core_archetype(StringName(key))
		if button == null or archetype == null:
			continue
		button.button_pressed = key == String(RunConfigManager.selected_core_archetype)
		button.text = "%s\n%s\nSkill: %s" % [
			archetype.display_name,
			archetype.description,
			archetype.active_skill_name
		]

	for key in _chapter_buttons.keys():
		var button := _chapter_buttons[key] as Button
		var chapter = ContentDB.get_chapter(StringName(key))
		if button == null or chapter == null:
			continue
		button.button_pressed = key == String(RunConfigManager.selected_chapter)
		button.text = "%s\n%s\nDNA x%.2f | ATP x%.2f" % [
			chapter.display_name,
			chapter.short_blurb,
			chapter.dna_multiplier,
			chapter.atp_multiplier
		]

func _on_core_selected(archetype_id: StringName) -> void:
	RunConfigManager.set_selected_core_archetype(archetype_id)

func _on_chapter_selected(chapter_id: StringName) -> void:
	RunConfigManager.set_selected_chapter(chapter_id)

func _on_launch_pressed() -> void:
	if not RunConfigManager.menu_tutorial_completed:
		RunConfigManager.mark_menu_tutorial_completed()
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
