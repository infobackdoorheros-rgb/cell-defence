extends Control
class_name MainMenuUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")
const MenuCoreDisplay = preload("res://scripts/ui/menu_core_display.gd")

var _root_margin: MarginContainer
var _top_dna_label: Label
var _top_best_label: Label
var _top_live_label: Label
var _top_network_label: Label

var _status_chip_label: Label
var _hero_title_label: Label
var _hero_subtitle_label: Label
var _hero_note_label: Label
var _core_display: MenuCoreDisplay

var _loadout_title_label: Label
var _loadout_value_label: Label
var _loadout_meta_label: Label
var _live_title_label: Label
var _live_value_label: Label
var _live_meta_label: Label

var _play_button: Button
var _play_hint_label: Label

var _combat_row: HBoxContainer
var _left_rail: VBoxContainer
var _right_rail: VBoxContainer
var _module_cards: Dictionary = {}

var _social_summary_label: Label
var _social_feedback_label: Label
var _social_buttons: Dictionary = {}
var _social_flow: HFlowContainer
var _account_status_label: Label
var _account_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"main_menu")

	if not resized.is_connected(_update_responsive_layout):
		resized.connect(_update_responsive_layout)
	if not MetaProgression.profile_changed.is_connected(_refresh_all):
		MetaProgression.profile_changed.connect(_refresh_all)
	if not SocialConnectManager.connections_changed.is_connected(_refresh_social_hub):
		SocialConnectManager.connections_changed.connect(_refresh_social_hub)
	if not AccountAuthManager.auth_state_changed.is_connected(_refresh_all):
		AccountAuthManager.auth_state_changed.connect(_refresh_all)
	if not SettingsManager.language_changed.is_connected(_refresh_all):
		SettingsManager.language_changed.connect(_refresh_all)
	if not SettingsManager.audio_changed.is_connected(_refresh_all):
		SettingsManager.audio_changed.connect(_refresh_all)
	if not RunConfigManager.core_archetype_changed.is_connected(_refresh_all):
		RunConfigManager.core_archetype_changed.connect(_refresh_all)
	if not RunConfigManager.chapter_changed.is_connected(_refresh_all):
		RunConfigManager.chapter_changed.connect(_refresh_all)
	if not DailyMissionManager.missions_changed.is_connected(_refresh_all):
		DailyMissionManager.missions_changed.connect(_refresh_all)
	if not SeasonEventManager.event_progress_changed.is_connected(_refresh_all):
		SeasonEventManager.event_progress_changed.connect(_refresh_all)
	if not BattlePassManager.progress_changed.is_connected(_refresh_all):
		BattlePassManager.progress_changed.connect(_refresh_all)
	if not OfferManager.offers_changed.is_connected(_refresh_all):
		OfferManager.offers_changed.connect(_refresh_all)

	_refresh_all()
	call_deferred("_update_responsive_layout")

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.04, 0.05, 0.11, 1.0)
	backdrop.accent_a = Color(0.29, 0.94, 0.84, 0.24)
	backdrop.accent_b = Color(0.96, 0.47, 0.83, 0.16)
	backdrop.accent_c = Color(0.42, 0.62, 1.0, 0.18)
	backdrop.motion_strength = 0.72
	add_child(backdrop)

	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_root_margin.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.custom_minimum_size = Vector2(360.0, 0.0)
	layout.add_theme_constant_override("separation", 18)
	scroll.add_child(layout)

	layout.add_child(_build_top_bar())
	layout.add_child(_build_battle_stage())
	layout.add_child(_build_social_strip())

func _build_top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	_apply_panel_style(panel, Color(0.12, 0.1, 0.24, 0.94), Color(0.45, 0.36, 0.88, 0.92), 26, 12, 20)

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	panel.add_child(flow)

	_top_dna_label = _make_top_chip(Color(1.0, 0.78, 0.38, 1.0))
	flow.add_child(_top_dna_label)
	_top_best_label = _make_top_chip(Color(0.46, 0.87, 1.0, 1.0))
	flow.add_child(_top_best_label)
	_top_live_label = _make_top_chip(Color(0.92, 0.48, 1.0, 1.0))
	flow.add_child(_top_live_label)
	_top_network_label = _make_top_chip(Color(0.37, 0.95, 0.77, 1.0))
	flow.add_child(_top_network_label)

	return panel

func _build_battle_stage() -> PanelContainer:
	var panel := PanelContainer.new()
	_apply_panel_style(panel, Color(0.05, 0.08, 0.13, 0.94), Color(0.28, 0.93, 0.85, 0.86), 34, 16, 28)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	_status_chip_label = Label.new()
	_status_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_status_chip_label, Color(0.11, 0.11, 0.18, 0.96), Color(0.48, 0.84, 1.0, 0.9))
	root.add_child(_status_chip_label)

	_hero_title_label = Label.new()
	_hero_title_label.text = "CELL DEFENSE"
	_hero_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_hero_title_label, 52, Color(0.97, 0.99, 1.0, 1.0))
	root.add_child(_hero_title_label)

	_hero_subtitle_label = Label.new()
	_hero_subtitle_label.text = "CORE IMMUNITY"
	_hero_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_heading(_hero_subtitle_label, Color(1.0, 0.77, 0.42, 1.0), 24)
	root.add_child(_hero_subtitle_label)

	_hero_note_label = Label.new()
	_hero_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_hero_note_label, 15)
	root.add_child(_hero_note_label)

	_combat_row = HBoxContainer.new()
	_combat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_row.add_theme_constant_override("separation", 12)
	root.add_child(_combat_row)

	_left_rail = VBoxContainer.new()
	_left_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_rail.add_theme_constant_override("separation", 12)
	_combat_row.add_child(_left_rail)

	_left_rail.add_child(_create_rail_button(
		&"laboratory",
		Color(0.15, 0.1, 0.06, 0.98),
		Color(1.0, 0.78, 0.4, 1.0),
		func() -> void: get_tree().change_scene_to_file("res://scenes/laboratory_scene.tscn")
	))
	_left_rail.add_child(_create_rail_button(
		&"daily",
		Color(0.07, 0.11, 0.18, 0.98),
		Color(0.45, 0.83, 1.0, 1.0),
		func() -> void: get_tree().change_scene_to_file("res://scenes/daily_missions_scene.tscn")
	))
	_left_rail.add_child(_create_rail_button(
		&"season",
		Color(0.11, 0.08, 0.18, 0.98),
		Color(0.86, 0.62, 1.0, 1.0),
		func() -> void: get_tree().change_scene_to_file("res://scenes/season_event_scene.tscn")
	))

	var center_stack := VBoxContainer.new()
	center_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_stack.add_theme_constant_override("separation", 12)
	_combat_row.add_child(center_stack)

	var display_shell := PanelContainer.new()
	display_shell.custom_minimum_size = Vector2(0.0, 300.0)
	_apply_panel_style(display_shell, Color(0.06, 0.07, 0.14, 0.98), Color(0.48, 0.31, 0.94, 0.68), 28, 10, 20)
	center_stack.add_child(display_shell)

	_core_display = MenuCoreDisplay.new()
	_core_display.custom_minimum_size = Vector2(0.0, 280.0)
	display_shell.add_child(_core_display)

	var loadout_card := _create_info_card(Color(0.38, 0.88, 1.0, 1.0))
	center_stack.add_child(loadout_card.get("panel") as PanelContainer)
	_loadout_title_label = loadout_card.get("title") as Label
	_loadout_value_label = loadout_card.get("value") as Label
	_loadout_meta_label = loadout_card.get("meta") as Label

	var live_card := _create_info_card(Color(0.88, 0.58, 1.0, 1.0))
	center_stack.add_child(live_card.get("panel") as PanelContainer)
	_live_title_label = live_card.get("title") as Label
	_live_value_label = live_card.get("value") as Label
	_live_meta_label = live_card.get("meta") as Label

	var battle_wrap := CenterContainer.new()
	battle_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_stack.add_child(battle_wrap)

	_play_button = Button.new()
	_play_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_button.custom_minimum_size = Vector2(230.0, 84.0)
	_play_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/prep_bay_scene.tscn"))
	_apply_battle_button_style(_play_button)
	battle_wrap.add_child(_play_button)

	_play_hint_label = Label.new()
	_play_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_play_hint_label, 14)
	center_stack.add_child(_play_hint_label)

	_right_rail = VBoxContainer.new()
	_right_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_right_rail.add_theme_constant_override("separation", 12)
	_combat_row.add_child(_right_rail)

	_right_rail.add_child(_create_rail_button(
		&"ops",
		Color(0.06, 0.12, 0.12, 0.98),
		Color(0.41, 0.95, 0.68, 1.0),
		func() -> void: get_tree().change_scene_to_file("res://scenes/live_ops_scene.tscn")
	))
	_right_rail.add_child(_create_rail_button(
		&"options",
		Color(0.06, 0.1, 0.16, 0.98),
		Color(0.56, 0.8, 1.0, 1.0),
		func() -> void: get_tree().change_scene_to_file("res://scenes/options_scene.tscn")
	))
	_right_rail.add_child(_create_rail_button(
		&"exit",
		Color(0.12, 0.07, 0.09, 0.98),
		Color(1.0, 0.49, 0.45, 1.0),
		func() -> void: get_tree().quit()
	))

	return panel

func _build_social_strip() -> PanelContainer:
	var panel := PanelContainer.new()
	_apply_panel_style(panel, Color(0.05, 0.07, 0.12, 0.92), Color(0.24, 0.4, 0.49, 0.8), 24, 14, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	box.add_child(header_row)

	var title := Label.new()
	title.text = SettingsManager.t("main.social.ribbon")
	BioUI.style_heading(title, Color(0.9, 0.96, 1.0, 1.0), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_social_summary_label = Label.new()
	_social_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	BioUI.style_subtitle(_social_summary_label, 14)
	header_row.add_child(_social_summary_label)

	var account_row := HBoxContainer.new()
	account_row.add_theme_constant_override("separation", 10)
	box.add_child(account_row)

	_account_status_label = Label.new()
	_account_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_chip(_account_status_label, Color(0.08, 0.11, 0.17, 0.96), Color(1.0, 0.77, 0.41, 0.82))
	account_row.add_child(_account_status_label)

	_account_button = Button.new()
	_account_button.custom_minimum_size = Vector2(184.0, 56.0)
	_account_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	BioUI.style_button(_account_button, Color(0.35, 0.93, 0.84, 1.0), 56.0)
	_account_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/account_scene.tscn"))
	account_row.add_child(_account_button)

	_social_flow = HFlowContainer.new()
	_social_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_social_flow.add_theme_constant_override("h_separation", 10)
	_social_flow.add_theme_constant_override("v_separation", 10)
	box.add_child(_social_flow)

	for provider_id in SocialConnectManager.get_provider_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(68.0, 54.0)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_social_button_pressed.bind(provider_id))
		_social_flow.add_child(button)
		_social_buttons[String(provider_id)] = button

	_social_feedback_label = Label.new()
	_social_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_social_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_social_feedback_label, 13)
	box.add_child(_social_feedback_label)

	return panel

func _create_rail_button(card_id: StringName, fill: Color, accent: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(96.0, 124.0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_rail_button_style(button, fill, accent)
	button.pressed.connect(callback)

	var shell := MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left", 10)
	shell.add_theme_constant_override("margin_top", 10)
	shell.add_theme_constant_override("margin_right", 10)
	shell.add_theme_constant_override("margin_bottom", 10)
	button.add_child(shell)

	var stack := VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	shell.add_child(stack)

	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(0.0, 28.0)
	BioUI.style_chip(tag, Color(0.08, 0.1, 0.16, 0.96), accent)
	stack.add_child(tag)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_heading(title, Color(0.97, 1.0, 0.99, 1.0), 20)
	stack.add_child(title)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(badge, 13)
	badge.add_theme_color_override("font_color", accent.lightened(0.12))
	stack.add_child(badge)

	_module_cards[String(card_id)] = {
		"button": button,
		"tag": tag,
		"title": title,
		"badge": badge,
		"fill": fill,
		"accent": accent
	}
	return button

func _create_info_card(accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	_apply_panel_style(panel, Color(0.08, 0.11, 0.18, 0.94), Color(accent.r, accent.g, accent.b, 0.84), 22, 14, 16)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	BioUI.style_heading(title, accent.lightened(0.12), 15)
	box.add_child(title)

	var value := Label.new()
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_heading(value, Color(0.96, 1.0, 0.99, 1.0), 20)
	box.add_child(value)

	var meta := Label.new()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(meta, 14)
	box.add_child(meta)

	return {
		"panel": panel,
		"title": title,
		"value": value,
		"meta": meta
	}

func _make_top_chip(accent: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(144.0, 42.0)
	BioUI.style_chip(label, Color(0.09, 0.1, 0.18, 0.96), accent)
	return label

func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, radius: int, padding: int, shadow_size: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.shadow_color = Color(border.r, border.g, border.b, 0.24)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)

func _apply_rail_button_style(button: Button, fill: Color, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(fill, accent, 26, 12, 16))
	button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.06), accent.lightened(0.12), 26, 12, 22))
	button.add_theme_stylebox_override("pressed", _make_button_style(fill.darkened(0.12), accent.lightened(0.18), 26, 12, 14))
	button.add_theme_stylebox_override("disabled", _make_button_style(fill.darkened(0.2), Color(accent.r, accent.g, accent.b, 0.4), 26, 12, 8))

func _apply_battle_button_style(button: Button) -> void:
	var base_fill := Color(0.1, 0.05, 0.18, 0.98)
	var accent := Color(0.93, 0.43, 1.0, 1.0)
	button.add_theme_stylebox_override("normal", _make_button_style(base_fill, accent, 16, 16, 26))
	button.add_theme_stylebox_override("hover", _make_button_style(base_fill.lightened(0.08), accent.lightened(0.12), 16, 18, 32))
	button.add_theme_stylebox_override("pressed", _make_button_style(base_fill.darkened(0.18), Color(1.0, 0.83, 0.56, 1.0), 16, 16, 22))
	button.add_theme_color_override("font_color", Color(0.99, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.95, 1.0))
	button.add_theme_font_size_override("font_size", 30)

func _make_button_style(fill: Color, border: Color, radius: int, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.shadow_color = Color(border.r, border.g, border.b, 0.28)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _apply_social_button_style(button: Button, accent: Color, status: StringName) -> void:
	var fill := Color(0.08, 0.11, 0.17, 0.94)
	var border := accent
	match status:
		&"linked":
			fill = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.98)
			border = accent.lightened(0.12)
		&"pending":
			fill = Color(0.16, 0.12, 0.06, 0.96)
			border = Color(1.0, 0.78, 0.44, 1.0)
	button.add_theme_stylebox_override("normal", _make_button_style(fill, border, 20, 2, 14))
	button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.06), border.lightened(0.12), 20, 2, 18))
	button.add_theme_stylebox_override("pressed", _make_button_style(fill.darkened(0.14), border.lightened(0.08), 20, 2, 12))

func _update_responsive_layout() -> void:
	var width := size.x
	var compact := width < 480.0
	var micro := width < 400.0
	var rail_width := 84.0 if micro else (94.0 if compact else 110.0)
	var rail_height := 118.0 if micro else (126.0 if compact else 138.0)

	if _root_margin != null:
		_root_margin.add_theme_constant_override("margin_left", 12 if micro else 18)
		_root_margin.add_theme_constant_override("margin_top", 12 if micro else 18)
		_root_margin.add_theme_constant_override("margin_right", 12 if micro else 18)
		_root_margin.add_theme_constant_override("margin_bottom", 12 if micro else 18)

	if _hero_title_label != null:
		BioUI.style_title(_hero_title_label, 42 if compact else 52, Color(0.97, 0.99, 1.0, 1.0))
	if _hero_subtitle_label != null:
		BioUI.style_heading(_hero_subtitle_label, Color(1.0, 0.77, 0.42, 1.0), 20 if compact else 24)
	if _hero_note_label != null:
		BioUI.style_subtitle(_hero_note_label, 13 if compact else 15)
	if _combat_row != null:
		_combat_row.add_theme_constant_override("separation", 8 if micro else 12)

	for data in _module_cards.values():
		var button := data.get("button") as Button
		var title := data.get("title") as Label
		var badge := data.get("badge") as Label
		if button != null:
			button.custom_minimum_size = Vector2(rail_width, rail_height)
		if title != null:
			BioUI.style_heading(title, Color(0.97, 1.0, 0.99, 1.0), 17 if compact else 20)
		if badge != null:
			BioUI.style_subtitle(badge, 12 if compact else 13)

	if _top_dna_label != null:
		var chip_width := 128.0 if micro else 146.0
		_top_dna_label.custom_minimum_size.x = chip_width
		_top_best_label.custom_minimum_size.x = chip_width
		_top_live_label.custom_minimum_size.x = chip_width
		_top_network_label.custom_minimum_size.x = chip_width

	if _play_button != null:
		_play_button.custom_minimum_size = Vector2(210.0 if compact else 240.0, 76.0 if compact else 84.0)
		_play_button.add_theme_font_size_override("font_size", 26 if compact else 30)

	if _social_buttons.size() > 0:
		var provider_width := 62.0 if micro else 70.0
		for button in _social_buttons.values():
			var social_button := button as Button
			if social_button != null:
				social_button.custom_minimum_size.x = provider_width
	if _account_button != null:
		_account_button.custom_minimum_size.x = 146.0 if micro else (164.0 if compact else 184.0)

func _refresh_all(_unused = null) -> void:
	_status_chip_label.text = SettingsManager.t("main.status_chip")
	_hero_note_label.text = SettingsManager.t("main.hero_brief")
	_loadout_title_label.text = SettingsManager.t("main.panel.loadout")
	_live_title_label.text = SettingsManager.t("main.panel.live")
	_play_button.text = SettingsManager.t("main.battle_button")
	_play_hint_label.text = SettingsManager.t("main.battle_hint")

	_refresh_signals()
	_refresh_module_cards()
	_refresh_social_hub()
	_refresh_account_state()

func _refresh_signals() -> void:
	var archetype = RunConfigManager.get_selected_core_archetype()
	var chapter = RunConfigManager.get_selected_chapter()
	var archetype_name: String = archetype.display_name if archetype != null else "Core"
	var skill_name: String = archetype.active_skill_name if archetype != null else "Immune Pulse"
	var chapter_name: String = chapter.display_name if chapter != null else "Sector"

	var daily_ready := 0
	for mission in DailyMissionManager.get_missions():
		if bool(mission.get("completed", false)) and not bool(mission.get("claimed", false)):
			daily_ready += 1

	var event_overview := SeasonEventManager.get_event_overview()
	var event_progress := int(event_overview.get("progress", 0))
	var event_target := int(event_overview.get("max_target", 0))
	var event_ready := 0
	for milestone in event_overview.get("milestones", []) as Array:
		var milestone_data := milestone as Dictionary
		if bool(milestone_data.get("reached", false)) and not bool(milestone_data.get("claimed", false)):
			event_ready += 1

	_top_dna_label.text = SettingsManager.t("main.signal.dna") % [MetaProgression.dna]
	_top_best_label.text = SettingsManager.t("main.signal.best") % [MetaProgression.best_wave]
	_top_live_label.text = SettingsManager.t("main.signal.live") % [
		BattlePassManager.get_claimable_tier_count(),
		OfferManager.get_available_offer_count()
	]
	_top_network_label.text = SettingsManager.t("main.signal.network") % [
		SocialConnectManager.get_connected_count(),
		SocialConnectManager.get_provider_ids().size()
	]

	_loadout_value_label.text = archetype_name
	_loadout_meta_label.text = "%s\n%s" % [skill_name, chapter_name]

	_live_value_label.text = SettingsManager.t("main.badge.ready") % [daily_ready]
	_live_meta_label.text = "%s   %s\n%s" % [
		SettingsManager.t("main.badge.progress") % [event_progress, event_target],
		SettingsManager.t("main.badge.ready") % [event_ready],
		SettingsManager.t("main.signal.live") % [
			BattlePassManager.get_claimable_tier_count(),
			OfferManager.get_available_offer_count()
		]
	]

	if _core_display != null:
		if archetype != null:
			_core_display.primary_color = archetype.accent_color
		if chapter != null:
			_core_display.secondary_color = chapter.accent_color
		_core_display.queue_redraw()

func _refresh_module_cards() -> void:
	var daily_ready := 0
	for mission in DailyMissionManager.get_missions():
		if bool(mission.get("completed", false)) and not bool(mission.get("claimed", false)):
			daily_ready += 1

	var event_overview := SeasonEventManager.get_event_overview()
	var event_progress := int(event_overview.get("progress", 0))
	var event_target := int(event_overview.get("max_target", 0))

	var language_code := String(SettingsManager.language).to_upper()
	var audio_code := "ON" if SettingsManager.audio_enabled else "OFF"

	_set_module_content(
		&"laboratory",
		SettingsManager.t("main.rail.lab_tag"),
		SettingsManager.t("main.rail.lab_title"),
		SettingsManager.t("main.signal.dna") % [MetaProgression.dna],
		SettingsManager.t("main.card.lab_subtitle")
	)
	_set_module_content(
		&"daily",
		SettingsManager.t("main.rail.daily_tag"),
		SettingsManager.t("main.rail.daily_title"),
		SettingsManager.t("main.badge.ready") % [daily_ready],
		SettingsManager.t("main.card.daily_subtitle")
	)
	_set_module_content(
		&"season",
		SettingsManager.t("main.rail.event_tag"),
		SettingsManager.t("main.rail.event_title"),
		SettingsManager.t("main.badge.progress") % [event_progress, event_target],
		SettingsManager.t("main.card.season_subtitle")
	)
	_set_module_content(
		&"ops",
		SettingsManager.t("main.rail.ops_tag"),
		SettingsManager.t("main.rail.ops_title"),
		"P%d  O%d" % [BattlePassManager.get_claimable_tier_count(), OfferManager.get_available_offer_count()],
		SettingsManager.t("main.card.ops_subtitle")
	)
	_set_module_content(
		&"options",
		SettingsManager.t("main.rail.system_tag"),
		SettingsManager.t("main.rail.system_title"),
		"%s  %s" % [audio_code, language_code],
		SettingsManager.t("main.card.options_subtitle")
	)
	_set_module_content(
		&"exit",
		SettingsManager.t("main.rail.exit_tag"),
		SettingsManager.t("main.rail.exit_title"),
		SettingsManager.t("main.exit_note"),
		SettingsManager.t("common.exit")
	)

func _set_module_content(card_id: StringName, tag_text: String, title_text: String, badge_text: String, tooltip_text: String) -> void:
	var data := _module_cards.get(String(card_id), {}) as Dictionary
	var button := data.get("button") as Button
	var tag := data.get("tag") as Label
	var title := data.get("title") as Label
	var badge := data.get("badge") as Label
	if tag != null:
		tag.text = tag_text
	if title != null:
		title.text = title_text
	if badge != null:
		badge.text = badge_text
	if button != null:
		button.tooltip_text = tooltip_text

func _refresh_social_hub() -> void:
	_social_summary_label.text = SettingsManager.t("main.social.summary") % [
		SocialConnectManager.get_connected_count(),
		SocialConnectManager.get_provider_ids().size()
	]
	if _social_feedback_label.text.is_empty():
		_social_feedback_label.text = SettingsManager.t("main.social.note_compact")

	for provider_id in SocialConnectManager.get_provider_ids():
		var button := _social_buttons.get(String(provider_id)) as Button
		if button == null:
			continue
		var info: Dictionary = SocialConnectManager.get_provider_info(provider_id)
		var status := SocialConnectManager.get_status(provider_id)
		var accent: Color = info.get("accent", Color(0.46, 0.82, 1.0, 1.0))
		_apply_social_button_style(button, accent, status)

		var short_name := _get_provider_short_name(provider_id)
		match status:
			&"pending":
				button.text = "%s ?" % short_name
			&"linked":
				button.text = "%s OK" % short_name
			_:
				button.text = "%s +" % short_name
		button.tooltip_text = String(info.get("display_name", provider_id))

func _refresh_account_state() -> void:
	if _account_button != null:
		_account_button.text = SettingsManager.t("main.account_button")
	var status := AccountAuthManager.get_status()
	match status:
		&"authenticated":
			var display_name := AccountAuthManager.get_display_name()
			_account_status_label.text = SettingsManager.t("main.account_linked") % [display_name]
		&"pending_google", &"pending_backdoor":
			_account_status_label.text = SettingsManager.t("main.account_pending")
		_:
			_account_status_label.text = SettingsManager.t("main.account_guest")

func _get_provider_short_name(provider_id: StringName) -> String:
	match provider_id:
		&"instagram":
			return "IG"
		&"discord":
			return "DS"
		&"facebook":
			return "FB"
		_:
			return String(provider_id).to_upper()

func _on_social_button_pressed(provider_id: StringName) -> void:
	var status := SocialConnectManager.cycle_connection(provider_id)
	var provider_name := String(SocialConnectManager.get_provider_info(provider_id).get("display_name", provider_id))
	match status:
		&"pending":
			_social_feedback_label.text = SettingsManager.t("main.social.pending_compact") % [provider_name]
		&"linked":
			_social_feedback_label.text = SettingsManager.t("main.social.linked_compact") % [provider_name]
		_:
			_social_feedback_label.text = SettingsManager.t("main.social.note_compact")
