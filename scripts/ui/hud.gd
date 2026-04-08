extends Control
class_name HUD

const UpgradeManager = preload("res://scripts/managers/upgrade_manager.gd")
const UpgradeData = preload("res://scripts/data/upgrade_data.gd")
const MutationData = preload("res://scripts/data/mutation_data.gd")
const BioUI = preload("res://scripts/ui/bio_ui.gd")

signal upgrade_requested(upgrade_id: StringName)
signal active_skill_requested

var _top_left_stack: VBoxContainer
var _top_right_stack: VBoxContainer
var _event_label: Label

var _resource_chip: Label
var _dna_chip: Label
var _wave_chip: Label
var _combat_chip: Label
var _core_status_chip: Label
var _engagement_chip: Label

var _bottom_margin: MarginContainer
var _bottom_overlay: VBoxContainer
var _info_row: GridContainer
var _status_panel: PanelContainer
var _battle_panel: PanelContainer
var _bottom_panel: PanelContainer

var _hp_chip: Label
var _shield_chip: Label
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _battle_wave_label: Label
var _battle_status_label: Label
var _mutation_brief_label: Label
var _active_skill_button: Button
var _shop_title_label: Label
var _shop_hint_label: Label

var _category_buttons: Dictionary = {}
var _category_sections: Dictionary = {}
var _section_grids: Dictionary = {}
var _section_scrolls: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _upgrade_data_by_id: Dictionary = {}
var _mutation_label: Label
var _selected_category: StringName = &"attack"
var _event_timer: float = 0.0
var _active_skill_name: String = ""
var _portrait_layout: bool = false

func _ready() -> void:
	ContentDB.reload_content()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	BioUI.style_root(self)
	_build_ui()
	set_process(true)
	if not resized.is_connected(_update_responsive_layout):
		resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")

func _process(delta: float) -> void:
	if _event_timer <= 0.0:
		return

	_event_timer = max(_event_timer - delta, 0.0)
	var alpha: float = min(_event_timer / 1.6, 1.0)
	_event_label.visible = _event_timer > 0.0
	_event_label.modulate = Color(1.0, 1.0, 1.0, alpha)

func get_playfield_rect(viewport_size: Vector2) -> Rect2:
	var top_limit: float = 56.0
	if _event_label != null and _event_label.visible:
		var event_rect: Rect2 = _event_label.get_global_rect()
		top_limit = max(top_limit, event_rect.position.y + event_rect.size.y + 10.0)

	var bottom_limit: float = viewport_size.y * 0.62
	if _bottom_margin != null:
		bottom_limit = _bottom_margin.get_global_rect().position.y - 12.0

	return Rect2(
		Vector2(viewport_size.x * 0.08, top_limit),
		Vector2(viewport_size.x * 0.84, max(bottom_limit - top_limit, 180.0))
	)

func _build_ui() -> void:
	var top_margin := MarginContainer.new()
	top_margin.anchor_left = 0.02
	top_margin.anchor_top = 0.02
	top_margin.anchor_right = 0.98
	top_margin.anchor_bottom = 0.22
	add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_row)

	_top_left_stack = VBoxContainer.new()
	_top_left_stack.add_theme_constant_override("separation", 8)
	top_row.add_child(_top_left_stack)

	_resource_chip = _make_corner_chip(Color(0.1, 0.15, 0.22, 0.96), Color(1.0, 0.76, 0.4, 0.94))
	_top_left_stack.add_child(_resource_chip)
	_dna_chip = _make_corner_chip(Color(0.12, 0.1, 0.2, 0.96), Color(0.93, 0.55, 1.0, 0.92))
	_top_left_stack.add_child(_dna_chip)
	_wave_chip = _make_corner_chip(Color(0.08, 0.14, 0.21, 0.96), Color(0.38, 0.91, 0.84, 0.92))
	_top_left_stack.add_child(_wave_chip)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	_top_right_stack = VBoxContainer.new()
	_top_right_stack.add_theme_constant_override("separation", 8)
	top_row.add_child(_top_right_stack)

	_combat_chip = _make_corner_chip(Color(0.09, 0.12, 0.17, 0.96), Color(0.46, 0.84, 1.0, 0.92))
	_top_right_stack.add_child(_combat_chip)

	_core_status_chip = _make_corner_chip(Color(0.06, 0.11, 0.15, 0.95), Color(0.27, 0.91, 0.8, 0.78))
	_core_status_chip.custom_minimum_size = Vector2(174.0, 42.0)
	_top_right_stack.add_child(_core_status_chip)

	_engagement_chip = _make_corner_chip(Color(0.08, 0.1, 0.18, 0.95), Color(0.96, 0.74, 0.4, 0.74))
	_engagement_chip.custom_minimum_size = Vector2(174.0, 52.0)
	_engagement_chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_top_right_stack.add_child(_engagement_chip)

	var top_skill_button := Button.new()
	top_skill_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_skill_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_skill_button.custom_minimum_size = Vector2(174.0, 62.0)
	_apply_skill_button_style(top_skill_button, true)
	top_skill_button.pressed.connect(func() -> void: active_skill_requested.emit())
	_top_right_stack.add_child(top_skill_button)
	_active_skill_button = top_skill_button

	_event_label = Label.new()
	_event_label.anchor_left = 0.22
	_event_label.anchor_top = 0.035
	_event_label.anchor_right = 0.78
	_event_label.anchor_bottom = 0.085
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_label.visible = false
	_apply_strip_chip_style(_event_label, Color(0.12, 0.11, 0.19, 0.94), Color(1.0, 0.78, 0.42, 0.88), 20)
	add_child(_event_label)

	_bottom_margin = MarginContainer.new()
	_bottom_margin.anchor_left = 0.02
	_bottom_margin.anchor_top = 0.69
	_bottom_margin.anchor_right = 0.98
	_bottom_margin.anchor_bottom = 0.985
	add_child(_bottom_margin)

	_bottom_overlay = VBoxContainer.new()
	_bottom_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_overlay.add_theme_constant_override("separation", 10)
	_bottom_margin.add_child(_bottom_overlay)

	_info_row = GridContainer.new()
	_info_row.columns = 2
	_info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_row.add_theme_constant_override("h_separation", 10)
	_info_row.add_theme_constant_override("v_separation", 10)
	_info_row.visible = false
	_bottom_overlay.add_child(_info_row)

	_status_panel = PanelContainer.new()
	_status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_panel.custom_minimum_size = Vector2(0.0, 122.0)
	_apply_hud_panel_style(_status_panel, Color(0.06, 0.11, 0.15, 0.95), Color(0.27, 0.91, 0.8, 0.78), 26)
	_info_row.add_child(_status_panel)

	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 8)
	_status_panel.add_child(status_box)

	var status_title := Label.new()
	status_title.text = "CORE STATUS"
	BioUI.style_heading(status_title, Color(0.86, 0.98, 0.97, 1.0), 16)
	status_box.add_child(status_title)

	_hp_chip = Label.new()
	BioUI.style_heading(_hp_chip, Color(0.97, 0.99, 1.0, 1.0), 18)
	status_box.add_child(_hp_chip)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0.0, 20.0)
	BioUI.style_progress(_hp_bar, Color(0.29, 0.93, 0.68, 1.0))
	status_box.add_child(_hp_bar)

	_shield_chip = Label.new()
	BioUI.style_subtitle(_shield_chip, 14)
	status_box.add_child(_shield_chip)

	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(0.0, 16.0)
	BioUI.style_progress(_shield_bar, Color(0.44, 0.84, 1.0, 1.0))
	status_box.add_child(_shield_bar)

	_battle_panel = PanelContainer.new()
	_battle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_panel.custom_minimum_size = Vector2(0.0, 122.0)
	_apply_hud_panel_style(_battle_panel, Color(0.08, 0.1, 0.18, 0.95), Color(0.96, 0.74, 0.4, 0.74), 26)
	_info_row.add_child(_battle_panel)

	var battle_row := HBoxContainer.new()
	battle_row.add_theme_constant_override("separation", 12)
	_battle_panel.add_child(battle_row)

	var battle_text_box := VBoxContainer.new()
	battle_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_text_box.add_theme_constant_override("separation", 6)
	battle_row.add_child(battle_text_box)

	var battle_title := Label.new()
	battle_title.text = "ENGAGEMENT"
	BioUI.style_heading(battle_title, Color(1.0, 0.8, 0.45, 1.0), 16)
	battle_text_box.add_child(battle_title)

	_battle_wave_label = Label.new()
	BioUI.style_heading(_battle_wave_label, Color(0.98, 0.99, 1.0, 1.0), 28)
	battle_text_box.add_child(_battle_wave_label)

	_battle_status_label = Label.new()
	_battle_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_battle_status_label, 14)
	battle_text_box.add_child(_battle_status_label)

	_mutation_brief_label = Label.new()
	_mutation_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_mutation_brief_label, 12)
	battle_text_box.add_child(_mutation_brief_label)

	var skill_wrap := VBoxContainer.new()
	skill_wrap.custom_minimum_size = Vector2(132.0, 0.0)
	skill_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_row.add_child(skill_wrap)

	var skill_title := Label.new()
	skill_title.text = "ACTIVE"
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_heading(skill_title, Color(0.37, 0.91, 0.84, 1.0), 14)
	skill_wrap.add_child(skill_title)

	var skill_proxy := Button.new()
	skill_proxy.alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_proxy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_proxy.custom_minimum_size = Vector2(132.0, 84.0)
	_apply_skill_button_style(skill_proxy, true)
	skill_proxy.pressed.connect(func() -> void: active_skill_requested.emit())
	skill_wrap.add_child(skill_proxy)
	_bottom_panel = PanelContainer.new()
	_bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_hud_panel_style(_bottom_panel, Color(0.045, 0.075, 0.12, 0.93), Color(0.24, 0.45, 0.54, 0.7), 28)
	_bottom_overlay.add_child(_bottom_panel)

	var bottom_box := VBoxContainer.new()
	bottom_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_box.add_theme_constant_override("separation", 10)
	_bottom_panel.add_child(bottom_box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	bottom_box.add_child(header_row)

	_shop_title_label = Label.new()
	_shop_title_label.text = SettingsManager.t("hud.shop_title")
	_shop_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_heading(_shop_title_label, Color(0.48, 0.9, 1.0, 1.0), 18)
	header_row.add_child(_shop_title_label)

	_shop_hint_label = Label.new()
	_shop_hint_label.text = SettingsManager.t("hud.shop_hint")
	_apply_strip_chip_style(_shop_hint_label, Color(0.11, 0.12, 0.19, 0.95), Color(0.92, 0.47, 1.0, 0.88), 18)
	header_row.add_child(_shop_hint_label)

	var category_row := HFlowContainer.new()
	category_row.add_theme_constant_override("h_separation", 8)
	category_row.add_theme_constant_override("v_separation", 8)
	bottom_box.add_child(category_row)

	_add_category_button(category_row, &"attack", SettingsManager.t("hud.attack"))
	_add_category_button(category_row, &"defense", SettingsManager.t("hud.defense"))
	_add_category_button(category_row, &"utility", SettingsManager.t("hud.utility"))
	_add_category_button(category_row, &"mutation", SettingsManager.t("hud.mutations"))

	var content_box := VBoxContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	bottom_box.add_child(content_box)

	_build_upgrade_section(content_box, &"attack", SettingsManager.t("hud.attack"), SettingsManager.t("hud.subtitle.attack"))
	_build_upgrade_section(content_box, &"defense", SettingsManager.t("hud.defense"), SettingsManager.t("hud.subtitle.defense"))
	_build_upgrade_section(content_box, &"utility", SettingsManager.t("hud.utility"), SettingsManager.t("hud.subtitle.utility"))
	_build_mutation_section(content_box)
	_set_selected_category(_selected_category)

	_hp_chip.text = SettingsManager.t("hud.hp") % [0.0, 0.0]
	_shield_chip.text = SettingsManager.t("hud.shield") % [0.0, 0.0]
	_resource_chip.text = "ATP 0"
	_wave_chip.text = "%s 1" % SettingsManager.t("common.wave")
	_dna_chip.text = "DNA 0"
	_combat_chip.text = SettingsManager.t("hud.arena_ready")
	_core_status_chip.text = SettingsManager.t("hud.hp") % [0.0, 0.0]
	_engagement_chip.text = "%s 1\n%s" % [SettingsManager.t("common.wave"), SettingsManager.t("hud.arena_ready")]
	_battle_wave_label.text = "%s 1" % SettingsManager.t("common.wave")
	_battle_status_label.text = SettingsManager.t("hud.arena_ready")
	_mutation_brief_label.text = SettingsManager.t("hud.no_mutations")
	_active_skill_button.text = "Immune Pulse\nREADY"
	_update_bars(0.0, 1.0, 0.0, 0.0)

func _build_upgrade_section(parent: VBoxContainer, category: StringName, title: String, subtitle_text: String) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	_category_sections[String(category)] = section

	var heading := Label.new()
	heading.text = title
	BioUI.style_heading(heading, BioUI.get_category_accent(category), 16)
	section.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 12)
	section.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	section.add_child(scroll)
	_section_scrolls[String(category)] = scroll

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_section_grids[String(category)] = grid

	for upgrade in ContentDB.get_runtime_upgrades_by_category(category):
		_upgrade_data_by_id[String(upgrade.upgrade_id)] = upgrade
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 102.0)
		_apply_upgrade_button_style(button, BioUI.get_category_accent(category))
		button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade.upgrade_id))
		grid.add_child(button)
		_upgrade_buttons[String(upgrade.upgrade_id)] = button

func _build_mutation_section(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	_category_sections[String(&"mutation")] = section

	var heading := Label.new()
	heading.text = SettingsManager.t("hud.mutations")
	BioUI.style_heading(heading, Color(1.0, 0.78, 0.42, 1.0), 16)
	section.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("hud.subtitle.mutation")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 12)
	section.add_child(subtitle)

	var mutation_panel := PanelContainer.new()
	mutation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_hud_panel_style(mutation_panel, Color(0.09, 0.11, 0.18, 0.94), Color(1.0, 0.76, 0.42, 0.66), 22)
	section.add_child(mutation_panel)

	_mutation_label = Label.new()
	_mutation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mutation_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	BioUI.style_body(_mutation_label, BioUI.COLOR_TEXT, 14)
	_mutation_label.text = SettingsManager.t("hud.no_mutations")
	mutation_panel.add_child(_mutation_label)

func _add_category_button(parent: HFlowContainer, category: StringName, title: String) -> void:
	var button := Button.new()
	button.text = title
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(92.0, 40.0)
	_apply_category_button_style(button, BioUI.get_category_accent(category))
	button.pressed.connect(_on_category_button_pressed.bind(category))
	parent.add_child(button)
	_category_buttons[String(category)] = button

func update_run_status(current_hp: float, max_hp: float, current_shield: float, max_shield: float, atp: int, wave: int, dna_preview: int, active_enemies: int) -> void:
	_hp_chip.text = SettingsManager.t("hud.hp") % [current_hp, max_hp]
	_shield_chip.visible = max_shield > 0.0
	_shield_bar.visible = max_shield > 0.0
	_shield_chip.text = SettingsManager.t("hud.shield") % [current_shield, max_shield]
	_update_bars(current_hp, max_hp, current_shield, max_shield)

	_resource_chip.text = "ATP %d" % atp
	_wave_chip.text = "%s %d" % [SettingsManager.t("common.wave"), wave]
	_dna_chip.text = "DNA %d" % dna_preview
	_battle_wave_label.text = "%s %d" % [SettingsManager.t("common.wave"), wave]
	_core_status_chip.text = SettingsManager.t("hud.hp") % [current_hp, max_hp]
	if max_shield > 0.0:
		_core_status_chip.text += " | %.0f/%.0f" % [current_shield, max_shield]

	if wave % 10 == 0:
		_combat_chip.text = SettingsManager.t("hud.boss_wave") % active_enemies
		_battle_status_label.text = "BOSS CONTACT   %d" % active_enemies
		_engagement_chip.text = "%s %d\nBoss attivo" % [SettingsManager.t("common.wave"), wave]
	else:
		var waves_to_boss: int = 10 - (wave % 10)
		_combat_chip.text = SettingsManager.t("hud.boss_in") % [active_enemies, waves_to_boss]
		_battle_status_label.text = "Minacce %d   Boss tra %d" % [active_enemies, waves_to_boss]
		_engagement_chip.text = "%s %d\nMinacce %d" % [SettingsManager.t("common.wave"), wave, active_enemies]

func refresh_shop(upgrade_manager: UpgradeManager) -> void:
	for key in _upgrade_buttons.keys():
		var upgrade := _upgrade_data_by_id[key] as UpgradeData
		var button := _upgrade_buttons[key] as Button
		var level := upgrade_manager.get_runtime_level(upgrade.upgrade_id)
		var can_buy := upgrade_manager.can_purchase(upgrade.upgrade_id)
		var bonus_text := _build_upgrade_bonus_text(upgrade, level)
		var next_text := _build_upgrade_next_hint(upgrade, level)
		if level >= upgrade.max_level:
			button.text = "%s\nLv.%d/%d | MAX\nAttivo: %s" % [upgrade.display_name, level, upgrade.max_level, bonus_text]
			button.disabled = true
			continue

		var cost := upgrade.get_cost_for_level(level + 1)
		button.text = "%s\nLv.%d/%d | %d ATP\nAttivo: %s\n%s" % [upgrade.display_name, level, upgrade.max_level, cost, bonus_text, next_text]
		button.disabled = not can_buy

func set_active_mutations(mutations: Array[MutationData]) -> void:
	if mutations.is_empty():
		_mutation_label.text = SettingsManager.t("hud.no_mutations")
		_mutation_brief_label.text = SettingsManager.t("hud.no_mutations")
		return

	var lines: Array[String] = []
	var brief: Array[String] = []
	for mutation in mutations:
		lines.append("%s\n%s" % [mutation.display_name.to_upper(), mutation.description])
		if brief.size() < 2:
			brief.append(mutation.display_name)
	_mutation_label.text = "\n\n".join(lines)
	_mutation_brief_label.text = " | ".join(brief)

func show_runtime_event(message: String) -> void:
	_event_label.text = message
	_event_label.visible = true
	_event_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_event_timer = 2.0

func configure_active_skill(skill_name: String, skill_description: String = "") -> void:
	_active_skill_name = skill_name
	if skill_name.is_empty():
		_active_skill_button.visible = false
		return
	_active_skill_button.visible = true
	_active_skill_button.tooltip_text = skill_description
	update_active_skill(0.0, 0.0)

func update_active_skill(cooldown_remaining: float, cooldown_total: float) -> void:
	if _active_skill_name.is_empty():
		return
	if cooldown_total <= 0.0 or cooldown_remaining <= 0.0:
		_active_skill_button.disabled = false
		_apply_skill_button_style(_active_skill_button, true)
		_active_skill_button.text = "%s\nREADY" % _active_skill_name
		return

	_active_skill_button.disabled = true
	_apply_skill_button_style(_active_skill_button, false)
	var remaining_text := "%.1fs" % cooldown_remaining
	var ratio: float = 1.0 - clamp(cooldown_remaining / cooldown_total, 0.0, 1.0)
	_active_skill_button.text = "%s\n%s  %d%%" % [_active_skill_name, remaining_text, int(round(ratio * 100.0))]

func _update_bars(current_hp: float, max_hp: float, current_shield: float, max_shield: float) -> void:
	_hp_bar.max_value = max(max_hp, 1.0)
	_hp_bar.value = clamp(current_hp, 0.0, _hp_bar.max_value)
	_shield_bar.max_value = max(max_shield, 1.0)
	_shield_bar.value = clamp(current_shield, 0.0, _shield_bar.max_value)

func _on_upgrade_button_pressed(upgrade_id: StringName) -> void:
	upgrade_requested.emit(upgrade_id)

func _on_category_button_pressed(category: StringName) -> void:
	_set_selected_category(category)

func _set_selected_category(category: StringName) -> void:
	_selected_category = category
	for key in _category_sections.keys():
		var section := _category_sections[key] as Control
		section.visible = key == String(category)
	for key in _category_buttons.keys():
		var button := _category_buttons[key] as Button
		button.button_pressed = key == String(category)
	if _shop_title_label != null:
		var category_name := ""
		match category:
			&"attack":
				category_name = SettingsManager.t("hud.attack")
			&"defense":
				category_name = SettingsManager.t("hud.defense")
			&"utility":
				category_name = SettingsManager.t("hud.utility")
			_:
				category_name = SettingsManager.t("hud.mutations")
		_shop_title_label.text = "%s | %s" % [SettingsManager.t("hud.shop_title"), category_name.to_upper()]

func _update_responsive_layout() -> void:
	_portrait_layout = size.y >= size.x * 1.25
	var compact := _portrait_layout or size.x < 520.0
	var very_compact := _portrait_layout or size.x < 420.0
	var bottom_top := 0.69 if _portrait_layout else (0.71 if compact else 0.72)
	_bottom_margin.anchor_top = bottom_top

	if _info_row != null:
		_info_row.visible = false
		_info_row.columns = 1 if _portrait_layout else 2
		_info_row.add_theme_constant_override("h_separation", 8 if compact else 10)
		_info_row.add_theme_constant_override("v_separation", 8 if compact else 10)

	_status_panel.custom_minimum_size.y = 82.0 if _portrait_layout else 122.0
	_battle_panel.custom_minimum_size.y = 86.0 if _portrait_layout else 122.0
	_mutation_brief_label.visible = not _portrait_layout
	_shop_hint_label.visible = not _portrait_layout

	if _top_left_stack != null:
		_top_left_stack.add_theme_constant_override("separation", 6 if very_compact else 8)
	if _top_right_stack != null:
		_top_right_stack.add_theme_constant_override("separation", 6 if very_compact else 8)

	for grid in _section_grids.values():
		var section_grid := grid as GridContainer
		if section_grid != null:
			section_grid.columns = 1 if _portrait_layout or very_compact else 2

	for scroll in _section_scrolls.values():
		var section_scroll := scroll as ScrollContainer
		if section_scroll != null:
			section_scroll.custom_minimum_size.y = 340.0 if _portrait_layout else 0.0

	for button in _category_buttons.values():
		var category_button := button as Button
		if category_button != null:
			category_button.custom_minimum_size = Vector2(74.0 if _portrait_layout else (82.0 if very_compact else 92.0), 34.0 if _portrait_layout else (38.0 if very_compact else 40.0))

	for button in _upgrade_buttons.values():
		var upgrade_button := button as Button
		if upgrade_button != null:
			upgrade_button.custom_minimum_size.y = 82.0 if _portrait_layout else (92.0 if compact else 102.0)

	_battle_wave_label.add_theme_font_size_override("font_size", 22 if _portrait_layout else (24 if compact else 28))
	_active_skill_button.custom_minimum_size = Vector2(104.0 if _portrait_layout else (118.0 if compact else 132.0), 60.0 if _portrait_layout else (76.0 if compact else 84.0))
	_apply_strip_chip_style(_resource_chip, Color(0.1, 0.15, 0.22, 0.96), Color(1.0, 0.76, 0.4, 0.94), 16 if compact else 18)
	_apply_strip_chip_style(_dna_chip, Color(0.12, 0.1, 0.2, 0.96), Color(0.93, 0.55, 1.0, 0.92), 16 if compact else 18)
	_apply_strip_chip_style(_wave_chip, Color(0.08, 0.14, 0.21, 0.96), Color(0.38, 0.91, 0.84, 0.92), 16 if compact else 18)
	_apply_strip_chip_style(_combat_chip, Color(0.09, 0.12, 0.17, 0.96), Color(0.46, 0.84, 1.0, 0.92), 16 if compact else 18)
	_resource_chip.custom_minimum_size = Vector2(92.0 if _portrait_layout else 112.0, 34.0)
	_dna_chip.custom_minimum_size = Vector2(92.0 if _portrait_layout else 112.0, 34.0)
	_wave_chip.custom_minimum_size = Vector2(92.0 if _portrait_layout else 112.0, 34.0)
	_combat_chip.custom_minimum_size = Vector2(108.0 if _portrait_layout else 132.0, 34.0)
	_core_status_chip.custom_minimum_size = Vector2(132.0 if _portrait_layout else 168.0, 38.0 if _portrait_layout else 42.0)
	_engagement_chip.custom_minimum_size = Vector2(132.0 if _portrait_layout else 168.0, 46.0 if _portrait_layout else 52.0)

func _make_corner_chip(fill: Color, accent: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(112.0, 34.0)
	_apply_strip_chip_style(label, fill, accent, 18)
	return label

func _apply_strip_chip_style(label: Label, fill: Color, accent: Color, radius: int) -> void:
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.24)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	label.add_theme_stylebox_override("normal", style)

func _apply_hud_panel_style(panel: PanelContainer, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

func _apply_category_button_style(button: Button, accent: Color) -> void:
	var base_fill := Color(0.1, 0.13, 0.19, 0.96)
	button.add_theme_stylebox_override("normal", _make_button_style(base_fill, accent, 18, 2, 10))
	button.add_theme_stylebox_override("hover", _make_button_style(base_fill.lightened(0.06), accent.lightened(0.12), 18, 2, 14))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent.darkened(0.42), accent.lightened(0.08), 18, 2, 12))
	button.add_theme_stylebox_override("disabled", _make_button_style(base_fill.darkened(0.2), Color(accent.r, accent.g, accent.b, 0.4), 18, 2, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

func _apply_upgrade_button_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.1, 0.16, 0.96), accent, 18, 2, 14))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.1, 0.14, 0.22, 0.98), accent.lightened(0.12), 18, 2, 18))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.12, 0.17, 0.24, 1.0), accent.lightened(0.08), 18, 2, 14))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.06, 0.08, 0.12, 0.88), Color(accent.r, accent.g, accent.b, 0.35), 18, 2, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.56, 0.63, 0.7, 1.0))
	button.add_theme_font_size_override("font_size", 15)

func _apply_skill_button_style(button: Button, ready: bool) -> void:
	var accent := Color(0.39, 0.92, 0.86, 1.0) if ready else Color(0.45, 0.73, 0.94, 0.9)
	var fill := Color(0.08, 0.17, 0.18, 0.98) if ready else Color(0.09, 0.11, 0.18, 0.98)
	button.add_theme_stylebox_override("normal", _make_button_style(fill, accent, 20, 3, 18))
	button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.06), accent.lightened(0.12), 20, 3, 24))
	button.add_theme_stylebox_override("pressed", _make_button_style(fill.darkened(0.14), Color(1.0, 0.79, 0.43, 1.0), 20, 3, 18))
	button.add_theme_stylebox_override("disabled", _make_button_style(fill.darkened(0.06), accent.darkened(0.16), 20, 3, 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.98, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.86, 0.92, 1.0, 0.92))
	button.add_theme_font_size_override("font_size", 16)

func _make_button_style(fill: Color, border: Color, radius: int, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.shadow_color = Color(border.r, border.g, border.b, 0.24)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _build_upgrade_bonus_text(upgrade: UpgradeData, level: int) -> String:
	if level <= 0:
		return SettingsManager.t("hud.no_bonus")

	var total_bonus: float = upgrade.get_bonus_for_level(level)
	match upgrade.stat_key:
		&"damage":
			return "+%.1f danni" % total_bonus
		&"attack_speed":
			return "+%.2f colpi/s" % total_bonus
		&"projectile_count":
			return "+%d proiettili" % int(round(total_bonus))
		&"damage_vs_virus_bonus":
			return "%s vs virus" % _format_percent_bonus(total_bonus)
		&"damage_vs_bacteria_bonus":
			return "%s vs batteri" % _format_percent_bonus(total_bonus)
		&"crit_chance", &"random_attack_upgrade_chance", &"random_defense_upgrade_chance":
			return _format_percent_bonus(total_bonus)
		&"crit_damage":
			return "x%.2f crit" % (1.75 + total_bonus)
		&"damage_per_meter":
			return "+%.2f%%/m" % (total_bonus * 100.0)
		&"multishot_targets":
			return "+%d bersagli" % int(round(total_bonus))
		&"rapid_fire_chance":
			return "%s fuoco rapido" % _format_percent_bonus(total_bonus)
		&"rapid_fire_duration":
			return "+%.1fs burst" % total_bonus
		&"bounce_chance":
			return "%s rimbalzo" % _format_percent_bonus(total_bonus)
		&"bounce_targets":
			return "+%d rimbalzi" % int(round(total_bonus))
		&"bounce_radius":
			return "+%.0f raggio bounce" % total_bonus
		&"armor":
			return "%s difesa" % _format_percent_bonus(total_bonus)
		&"projectile_speed":
			return "+%.0f velocita" % total_bonus
		&"pierce_count":
			return "+%d perforazione" % int(round(total_bonus))
		&"secondary_projectile_chance":
			return "%s multicolpo" % _format_percent_bonus(total_bonus)
		&"max_hp":
			return "+%.0f HP" % total_bonus
		&"absolute_defense":
			return "+%.1f difesa" % total_bonus
		&"regeneration":
			return "+%.1f HP/s" % total_bonus
		&"shield_max":
			return "+%.0f scudo" % total_bonus
		&"shield_regeneration":
			return "+%.1f scudo/s" % total_bonus
		&"contact_damage_reduction":
			return "%s anti-impatto" % _format_percent_bonus(total_bonus)
		&"contact_retaliation":
			return "+%.0f riflessi" % total_bonus
		&"dna_gain_multiplier":
			return "%s DNA" % _format_percent_bonus(total_bonus)
		&"dna_bonus_per_kill":
			return "+%.1f DNA/kill" % total_bonus
		&"dna_per_wave":
			return "+%.1f DNA/wave" % total_bonus
		&"dna_crystal_spawn_bonus":
			return "%s spawn DNA" % _format_percent_bonus(total_bonus)
		&"atp_per_wave":
			return "+%.0f ATP/wave" % total_bonus
		&"atp_interest_per_wave":
			return "%s interesse" % _format_percent_bonus(total_bonus)
		&"auto_upgrade_interval_reduction":
			return "%s intervallo auto-upgrade" % _format_percent_bonus(-total_bonus)
		&"random_utility_upgrade_chance":
			return "%s utility free" % _format_percent_bonus(total_bonus)
		&"pickup_radius", &"projectile_range", &"targeting_range":
			return "+%.0f raggio" % total_bonus
		_:
			if upgrade.display_as_percent:
				return _format_percent_bonus(total_bonus)
			return "+%.2f" % total_bonus

func _build_upgrade_next_hint(upgrade: UpgradeData, current_level: int) -> String:
	if current_level >= upgrade.max_level:
		return "Profilo completo"

	var next_level: int = min(current_level + 1, upgrade.max_level)
	var current_preview := _build_upgrade_bonus_text(upgrade, current_level)
	var next_preview := _build_upgrade_bonus_text(upgrade, next_level)
	if next_preview != current_preview:
		return "Prossimo: %s" % next_preview

	for probe_level in range(next_level + 1, upgrade.max_level + 1):
		var probe_preview := _build_upgrade_bonus_text(upgrade, probe_level)
		if probe_preview != current_preview:
			return "Salto a Lv.%d: %s" % [probe_level, probe_preview]

	return "Prossimo: micro-adattamento"

func _format_percent_bonus(value: float) -> String:
	var percent_value: float = value * 100.0
	var sign := "+" if percent_value >= 0.0 else "-"
	var magnitude := absf(percent_value)
	if absf(percent_value) >= 10.0:
		return "%s%.0f%%" % [sign, magnitude]
	if absf(percent_value) >= 1.0:
		return "%s%.1f%%" % [sign, magnitude]
	return "%s%.2f%%" % [sign, magnitude]
