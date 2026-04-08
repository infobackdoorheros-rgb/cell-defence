extends Control
class_name LaboratorySceneUI

const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")
const BioShowcase = preload("res://scripts/ui/bio_showcase.gd")

var _dna_label: Label
var _summary_label: Label
var _scroll: ScrollContainer
var _scroll_content_root: MarginContainer
var _scroll_content: VBoxContainer
var _top_panel: HFlowContainer
var _hero_showcase: BioShowcase
var _category_grids: Array[GridContainer] = []
var _buttons: Dictionary = {}
var _data_by_id: Dictionary = {}

func _ready() -> void:
	ContentDB.reload_content()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"laboratory")
	if not resized.is_connected(_sync_layout):
		resized.connect(_sync_layout)
	if _scroll != null and not _scroll.resized.is_connected(_sync_layout):
		_scroll.resized.connect(_sync_layout)
	if not MetaProgression.profile_changed.is_connected(_refresh_ui):
		MetaProgression.profile_changed.connect(_refresh_ui)
	_sync_layout()
	call_deferred("_sync_layout")
	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.027, 0.05, 0.075, 1.0)
	backdrop.accent_a = Color(0.36, 0.94, 0.84, 0.34)
	backdrop.accent_b = Color(1.0, 0.74, 0.4, 0.18)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.22)
	backdrop.motion_strength = 0.65
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
	layout.add_theme_constant_override("separation", 16)
	root.add_child(layout)

	var header_panel := PanelContainer.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_panel(header_panel, Color(0.06, 0.1, 0.14, 0.88), Color(0.37, 0.92, 0.82, 0.9), 30, 18)
	layout.add_child(header_panel)

	var header_box := VBoxContainer.new()
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_theme_constant_override("separation", 8)
	header_panel.add_child(header_box)

	var title := Label.new()
	title.text = SettingsManager.t("lab.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(title, 38, Color(0.96, 1.0, 0.98, 1.0))
	header_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("lab.subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(subtitle, 18)
	header_box.add_child(subtitle)

	_hero_showcase = BioShowcase.new()
	_hero_showcase.compact = true
	_hero_showcase.custom_minimum_size = Vector2(0.0, 210.0)
	header_box.add_child(_hero_showcase)

	_top_panel = HFlowContainer.new()
	_top_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_panel.add_theme_constant_override("h_separation", 14)
	_top_panel.add_theme_constant_override("v_separation", 14)
	layout.add_child(_top_panel)

	var dna_panel := PanelContainer.new()
	dna_panel.custom_minimum_size = Vector2(290.0, 0.0)
	BioUI.style_panel(dna_panel, Color(0.09, 0.14, 0.2, 0.88), Color(1.0, 0.75, 0.42, 0.88), 26, 18)
	_top_panel.add_child(dna_panel)

	_dna_label = Label.new()
	_dna_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_dna_label, BioUI.COLOR_TEXT, 19)
	dna_panel.add_child(_dna_label)

	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(290.0, 0.0)
	BioUI.style_panel(summary_panel, Color(0.08, 0.14, 0.19, 0.9), Color(0.35, 0.89, 0.84, 0.82), 26, 18)
	_top_panel.add_child(summary_panel)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_summary_label, BioUI.COLOR_TEXT, 17)
	summary_panel.add_child(_summary_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	layout.add_child(_scroll)

	_scroll_content_root = MarginContainer.new()
	_scroll_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_content_root.add_theme_constant_override("margin_right", 12)
	_scroll_content_root.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(_scroll_content_root)

	_scroll_content = VBoxContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.add_theme_constant_override("separation", 12)
	_scroll_content_root.add_child(_scroll_content)

	_add_category(_scroll_content, &"attack", SettingsManager.t("lab.category.attack"))
	_add_category(_scroll_content, &"defense", SettingsManager.t("lab.category.defense"))
	_add_category(_scroll_content, &"utility", SettingsManager.t("lab.category.utility"))
	_add_category(_scroll_content, &"mutation", SettingsManager.t("lab.category.mutation"))

	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	var back_button := Button.new()
	back_button.text = SettingsManager.t("common.main_menu")
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	footer.add_child(back_button)

	var run_button := Button.new()
	run_button.text = SettingsManager.t("common.play")
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(run_button, Color(0.37, 0.94, 0.84, 1.0), 70.0)
	run_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/prep_bay_scene.tscn"))
	footer.add_child(run_button)

func _add_category(parent: VBoxContainer, category: StringName, title: String) -> void:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_panel(section, Color(0.07, 0.11, 0.16, 0.9), BioUI.get_category_accent(category), 26, 18)
	parent.add_child(section)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	section.add_child(box)

	var heading := Label.new()
	heading.text = title
	BioUI.style_heading(heading, BioUI.get_category_accent(category), 26)
	box.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = _get_category_blurb(category)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 15)
	box.add_child(subtitle)

	var card_grid := GridContainer.new()
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(card_grid)
	_category_grids.append(card_grid)

	for upgrade in ContentDB.get_meta_upgrades_by_category(category):
		_data_by_id[String(upgrade.upgrade_id)] = upgrade
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 116.0)
		BioUI.style_button(button, BioUI.get_category_accent(category), 108.0)
		button.pressed.connect(_on_lab_upgrade_pressed.bind(upgrade.upgrade_id))
		card_grid.add_child(button)
		_buttons[String(upgrade.upgrade_id)] = button

func _refresh_ui() -> void:
	_dna_label.text = SettingsManager.t("lab.dna_block") % [MetaProgression.dna, MetaProgression.best_wave]
	_summary_label.text = _build_summary_text()

	for key in _buttons.keys():
		var button := _buttons[key] as Button
		var upgrade := _data_by_id[key] as UpgradeData
		var level := MetaProgression.get_upgrade_level(upgrade.upgrade_id)
		var bonus_text := MetaProgression.get_upgrade_bonus_text(upgrade)

		if upgrade.is_mutation_unlock():
			if level >= upgrade.max_level:
				button.text = "%s   SBLOCCATA\n%s" % [upgrade.display_name, upgrade.description]
				button.disabled = true
			else:
				var unlock_cost := upgrade.get_cost_for_level(level + 1)
				button.text = "%s   Costo %d DNA\n%s" % [upgrade.display_name, unlock_cost, upgrade.description]
				button.disabled = not MetaProgression.can_purchase(upgrade.upgrade_id)
			continue

		if level >= upgrade.max_level:
			button.text = "%s   Lv.%d/%d MAX\n%s\n%s" % [upgrade.display_name, level, upgrade.max_level, upgrade.description, bonus_text]
			button.disabled = true
			continue

		var next_cost := upgrade.get_cost_for_level(level + 1)
		button.text = "%s   Lv.%d/%d   Costo %d DNA\n%s\n%s" % [upgrade.display_name, level, upgrade.max_level, next_cost, upgrade.description, bonus_text]
		button.disabled = not MetaProgression.can_purchase(upgrade.upgrade_id)

func _build_summary_text() -> String:
	var stats := MetaProgression.build_persistent_run_stats()
	return SettingsManager.t("lab.summary") % [
		stats.damage,
		stats.attack_speed,
		stats.max_hp,
		stats.shield_max,
		stats.regeneration,
		stats.atp_gain_multiplier,
		stats.dna_gain_multiplier,
		stats.pickup_radius,
		stats.targeting_range
	]

func _on_lab_upgrade_pressed(upgrade_id: StringName) -> void:
	if MetaProgression.purchase_meta_upgrade(upgrade_id):
		_refresh_ui()

func _sync_layout() -> void:
	if _scroll == null or _scroll_content_root == null:
		return

	var target_width: float = max(_scroll.size.x - 14.0, 0.0)
	var compact := size.x < 760.0
	_scroll_content_root.custom_minimum_size = Vector2(target_width, max(size.y * 0.72, 0.0))
	_scroll_content.custom_minimum_size = Vector2(target_width, 0.0)

	if _top_panel != null:
		_top_panel.add_theme_constant_override("h_separation", 12 if compact else 14)
		_top_panel.add_theme_constant_override("v_separation", 12 if compact else 14)
		for child in _top_panel.get_children():
			if child is Control:
				var panel := child as Control
				panel.custom_minimum_size.x = target_width if compact else 290.0

	if _hero_showcase != null:
		_hero_showcase.custom_minimum_size.y = 166.0 if compact else 210.0

	for grid in _category_grids:
		grid.columns = 1 if compact else 2
		grid.custom_minimum_size = Vector2(max(target_width - 36.0, 0.0), 0.0)

	for button_variant in _buttons.values():
		var button := button_variant as Button
		if button != null:
			button.custom_minimum_size.y = 108.0 if compact else 116.0
			button.add_theme_font_size_override("font_size", 14 if compact else 15)

func _get_category_blurb(category: StringName) -> String:
	match category:
		&"attack":
			return SettingsManager.t("lab.blurb.attack")
		&"defense":
			return SettingsManager.t("lab.blurb.defense")
		&"utility":
			return SettingsManager.t("lab.blurb.utility")
		&"mutation":
			return SettingsManager.t("lab.blurb.mutation")
		_:
			return ""
