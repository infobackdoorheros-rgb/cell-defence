extends Control
class_name SeasonEventSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")
const BioShowcase = preload("res://scripts/ui/bio_showcase.gd")
const SwipeScrollContainer = preload("res://scripts/ui/swipe_scroll_container.gd")

var _title_label: Label
var _subtitle_label: Label
var _summary_label: Label
var _progress_bar: ProgressBar
var _milestone_flow: HFlowContainer
var _objective_list: VBoxContainer
var _rules_title_label: Label
var _rules_summary_label: Label
var _rules_note_label: Label
var _objective_heading_label: Label
var _back_button: Button
var _hero_showcase: BioShowcase

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"season_event")

	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)
	if not SeasonEventManager.event_progress_changed.is_connected(_refresh_ui):
		SeasonEventManager.event_progress_changed.connect(_refresh_ui)
	if not MetaProgression.profile_changed.is_connected(_refresh_ui):
		MetaProgression.profile_changed.connect(_refresh_ui)

	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.028, 0.045, 0.074, 1.0)
	backdrop.accent_a = Color(0.82, 0.62, 1.0, 0.2)
	backdrop.accent_b = Color(0.35, 0.92, 0.84, 0.2)
	backdrop.accent_c = Color(1.0, 0.75, 0.42, 0.16)
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
	BioUI.style_panel(header, Color(0.08, 0.12, 0.18, 0.92), Color(0.82, 0.62, 1.0, 0.78), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 36, Color(0.99, 0.96, 1.0, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 17)
	header_box.add_child(_subtitle_label)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_body(_summary_label, BioUI.COLOR_TEXT, 16)
	header_box.add_child(_summary_label)

	_hero_showcase = BioShowcase.new()
	_hero_showcase.compact = true
	_hero_showcase.custom_minimum_size = Vector2(0.0, 176.0)
	header_box.add_child(_hero_showcase)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 24.0)
	BioUI.style_progress(_progress_bar, Color(0.82, 0.62, 1.0, 1.0))
	header_box.add_child(_progress_bar)

	var scroll := SwipeScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(640.0, 0.0)
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	scroll.register_scroll_tree(content)

	_milestone_flow = HFlowContainer.new()
	_milestone_flow.add_theme_constant_override("h_separation", 12)
	_milestone_flow.add_theme_constant_override("v_separation", 12)
	content.add_child(_milestone_flow)

	var rules_panel := PanelContainer.new()
	BioUI.style_panel(rules_panel, Color(0.08, 0.12, 0.18, 0.94), Color(0.35, 0.92, 0.84, 0.58), 24, 16)
	content.add_child(rules_panel)

	var rules_box := VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 8)
	rules_panel.add_child(rules_box)

	_rules_title_label = Label.new()
	_rules_title_label.text = "Come progredisce l'evento" if SettingsManager.language == &"it" else "How event progress works"
	BioUI.style_heading(_rules_title_label, Color(0.35, 0.92, 0.84, 1.0), 22)
	rules_box.add_child(_rules_title_label)

	_rules_summary_label = Label.new()
	_rules_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_rules_summary_label, BioUI.COLOR_TEXT, 15)
	rules_box.add_child(_rules_summary_label)

	_rules_note_label = Label.new()
	_rules_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_rules_note_label, 14)
	rules_box.add_child(_rules_note_label)

	_objective_heading_label = Label.new()
	_objective_heading_label.text = "Operazioni attive" if SettingsManager.language == &"it" else "Active operations"
	BioUI.style_heading(_objective_heading_label, Color(0.86, 0.68, 1.0, 1.0), 24)
	content.add_child(_objective_heading_label)

	_objective_list = VBoxContainer.new()
	_objective_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_list.add_theme_constant_override("separation", 10)
	content.add_child(_objective_list)

	_back_button = Button.new()
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layout.add_child(_back_button)

func _refresh_ui(_unused = null) -> void:
	var overview := SeasonEventManager.get_event_overview()
	var progress_rules := overview.get("progress_rules", {}) as Dictionary
	_title_label.text = String(overview.get("display_name", SettingsManager.t("season.title")))
	_subtitle_label.text = String(overview.get("subtitle", ""))
	_rules_title_label.text = "Come progredisce l'evento" if SettingsManager.language == &"it" else "How event progress works"
	_objective_heading_label.text = "Operazioni attive" if SettingsManager.language == &"it" else "Active operations"
	_summary_label.text = SettingsManager.t("season.progress") % [
		int(overview.get("progress", 0)),
		int(overview.get("max_target", 0)),
		String(overview.get("currency_name", "")),
		MetaProgression.dna
	]
	_progress_bar.max_value = max(1, float(overview.get("max_target", 1)))
	_progress_bar.value = float(overview.get("progress", 0))
	_back_button.text = SettingsManager.t("common.main_menu")
	_rules_summary_label.text = String(progress_rules.get("summary_it" if SettingsManager.language == &"it" else "summary_en", ""))
	_rules_note_label.text = String(progress_rules.get("note_it" if SettingsManager.language == &"it" else "note_en", ""))

	for child in _milestone_flow.get_children():
		child.queue_free()
	for child in _objective_list.get_children():
		child.queue_free()

	for milestone in overview.get("milestones", []) as Array:
		_milestone_flow.add_child(_build_milestone_card(milestone as Dictionary, String(overview.get("currency_name", ""))))
	for objective in overview.get("active_objectives", []) as Array:
		_objective_list.add_child(_build_objective_card(objective as Dictionary))

func _build_milestone_card(milestone: Dictionary, currency_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(214.0, 144.0)
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(0.82, 0.62, 1.0, 0.42), 24, 14)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "%d %s" % [int(milestone.get("target", 0)), currency_name]
	BioUI.style_heading(title, Color(0.86, 0.68, 1.0, 1.0), 22)
	box.add_child(title)

	var reward := Label.new()
	reward.text = SettingsManager.t("season.reward") % [int(milestone.get("reward_dna", 0))]
	BioUI.style_body(reward, BioUI.COLOR_TEXT, 16)
	box.add_child(reward)

	var button := Button.new()
	BioUI.style_button(button, Color(0.36, 0.94, 0.84, 1.0), 58.0)
	var index := int(milestone.get("index", 0))
	if bool(milestone.get("claimed", false)):
		button.text = SettingsManager.t("common.claimed")
		button.disabled = true
	elif bool(milestone.get("reached", false)):
		button.text = SettingsManager.t("common.claim_reward")
		button.pressed.connect(_on_claim_pressed.bind(index))
	else:
		button.text = SettingsManager.t("common.in_progress")
		button.disabled = true
	box.add_child(button)

	return panel

func _build_objective_card(objective_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.08, 0.11, 0.17, 0.95), Color(0.94, 0.58, 1.0, 0.56), 24, 16)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	box.add_child(header_row)

	var tag := Label.new()
	tag.text = "LIVE"
	BioUI.style_chip(tag, Color(0.09, 0.11, 0.18, 0.96), Color(0.94, 0.58, 1.0, 0.86))
	header_row.add_child(tag)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var reward_chip := Label.new()
	reward_chip.text = ("Reward +%d DNA" % int(objective_data.get("reward_dna", 0))) if SettingsManager.language == &"it" else ("Reward +%d DNA" % int(objective_data.get("reward_dna", 0)))
	BioUI.style_chip(reward_chip, Color(0.08, 0.13, 0.18, 0.96), Color(1.0, 0.77, 0.41, 0.84))
	header_row.add_child(reward_chip)

	var title := Label.new()
	title.text = String(objective_data.get("title_it" if SettingsManager.language == &"it" else "title_en", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_heading(title, Color(0.98, 0.9, 1.0, 1.0), 20)
	box.add_child(title)

	var objective := Label.new()
	var current_progress := int(objective_data.get("progress", 0))
	var target_progress: int = max(1, int(objective_data.get("target", 1)))
	objective.text = ("Progresso %d / %d" % [current_progress, target_progress]) if SettingsManager.language == &"it" else ("Progress %d / %d" % [current_progress, target_progress])
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(objective, BioUI.COLOR_TEXT, 15)
	box.add_child(objective)

	var progress_bar := ProgressBar.new()
	progress_bar.max_value = float(target_progress)
	progress_bar.value = float(current_progress)
	progress_bar.custom_minimum_size = Vector2(0.0, 20.0)
	BioUI.style_progress(progress_bar, Color(0.94, 0.58, 1.0, 1.0))
	box.add_child(progress_bar)

	var description := Label.new()
	description.text = String(objective_data.get("description_it" if SettingsManager.language == &"it" else "description_en", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(description, BioUI.COLOR_TEXT_MUTED, 14)
	box.add_child(description)

	var claim_button := Button.new()
	BioUI.style_button(claim_button, Color(0.94, 0.58, 1.0, 1.0), 56.0)
	var index := active_objectives_find_index(objective_data)
	if bool(objective_data.get("claimed", false)):
		claim_button.text = SettingsManager.t("common.claimed")
		claim_button.disabled = true
	elif current_progress >= target_progress:
		claim_button.text = SettingsManager.t("common.claim_reward")
		claim_button.pressed.connect(_on_claim_objective_pressed.bind(index))
	else:
		claim_button.text = SettingsManager.t("common.in_progress")
		claim_button.disabled = true
	box.add_child(claim_button)

	return panel

func _on_claim_pressed(index: int) -> void:
	SeasonEventManager.claim_milestone(index)

func _on_claim_objective_pressed(index: int) -> void:
	SeasonEventManager.claim_objective(index)

func active_objectives_find_index(objective_data: Dictionary) -> int:
	var objectives := SeasonEventManager.get_event_overview().get("active_objectives", []) as Array
	var objective_id := String(objective_data.get("id", ""))
	for index in range(objectives.size()):
		if String((objectives[index] as Dictionary).get("id", "")) == objective_id:
			return index
	return -1
