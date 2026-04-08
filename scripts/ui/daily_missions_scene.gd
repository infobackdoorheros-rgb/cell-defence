extends Control
class_name DailyMissionsSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _mission_list: VBoxContainer
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"daily_missions")

	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)
	if not DailyMissionManager.missions_changed.is_connected(_refresh_ui):
		DailyMissionManager.missions_changed.connect(_refresh_ui)
	if not MetaProgression.profile_changed.is_connected(_refresh_ui):
		MetaProgression.profile_changed.connect(_refresh_ui)

	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.026, 0.046, 0.072, 1.0)
	backdrop.accent_a = Color(1.0, 0.77, 0.41, 0.18)
	backdrop.accent_b = Color(0.35, 0.92, 0.84, 0.22)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.16)
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
	BioUI.style_panel(header, Color(0.08, 0.12, 0.18, 0.92), Color(1.0, 0.77, 0.41, 0.84), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 36, Color(1.0, 0.98, 0.94, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 17)
	header_box.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_status_label, Color(0.08, 0.13, 0.18, 0.92), Color(1.0, 0.77, 0.41, 0.86))
	header_box.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	layout.add_child(scroll)

	_mission_list = VBoxContainer.new()
	_mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_list.custom_minimum_size = Vector2(640.0, 0.0)
	_mission_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_mission_list)

	_back_button = Button.new()
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layout.add_child(_back_button)

func _refresh_ui(_unused = null) -> void:
	_title_label.text = SettingsManager.t("daily.title")
	_subtitle_label.text = SettingsManager.t("daily.subtitle")
	_back_button.text = SettingsManager.t("common.main_menu")

	var ready_rewards := 0
	for mission in DailyMissionManager.get_missions():
		if bool(mission.get("completed", false)) and not bool(mission.get("claimed", false)):
			ready_rewards += 1

	_status_label.text = SettingsManager.t("daily.status") % [MetaProgression.dna, ready_rewards]

	for child in _mission_list.get_children():
		child.queue_free()

	for mission in DailyMissionManager.get_missions():
		_mission_list.add_child(_build_mission_card(mission))

func _build_mission_card(mission: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(1.0, 0.77, 0.41, 0.38), 24, 16)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = _build_mission_title(mission)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_heading(title, Color(1.0, 0.82, 0.51, 1.0), 22)
	box.add_child(title)

	var progress_line := Label.new()
	progress_line.text = SettingsManager.t("daily.progress") % [
		int(mission.get("progress", 0)),
		int(mission.get("target", 1)),
		int(mission.get("reward_dna", 0))
	]
	BioUI.style_body(progress_line, BioUI.COLOR_TEXT, 16)
	box.add_child(progress_line)

	var progress_bar := ProgressBar.new()
	progress_bar.max_value = max(1, float(mission.get("target", 1)))
	progress_bar.value = float(mission.get("progress", 0))
	progress_bar.custom_minimum_size = Vector2(0.0, 20.0)
	BioUI.style_progress(progress_bar, Color(1.0, 0.77, 0.41, 1.0))
	box.add_child(progress_bar)

	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_button(button, Color(0.36, 0.94, 0.84, 1.0), 60.0)
	var mission_id := StringName(mission.get("id", ""))
	if bool(mission.get("claimed", false)):
		button.text = SettingsManager.t("common.claimed")
		button.disabled = true
	elif bool(mission.get("completed", false)):
		button.text = SettingsManager.t("common.claim_reward")
		button.pressed.connect(_on_claim_pressed.bind(mission_id))
	else:
		button.text = SettingsManager.t("common.in_progress")
		button.disabled = true
	box.add_child(button)

	return panel

func _build_mission_title(mission: Dictionary) -> String:
	var target := int(mission.get("target", 1))
	match StringName(mission.get("kind", "")):
		&"kills":
			return SettingsManager.t("mission.kills") % [target]
		&"wave":
			return SettingsManager.t("mission.wave") % [target]
		&"runtime_upgrades":
			return SettingsManager.t("mission.runtime_upgrades") % [target]
		&"mutations":
			return SettingsManager.t("mission.mutations") % [target]
		&"bosses":
			return SettingsManager.t("mission.bosses") % [target]
		_:
			return SettingsManager.t("daily.fallback")

func _on_claim_pressed(mission_id: StringName) -> void:
	DailyMissionManager.claim_reward(mission_id)
