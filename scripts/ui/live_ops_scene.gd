extends Control
class_name LiveOpsSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _battle_pass_summary_label: Label
var _battle_pass_bar: ProgressBar
var _battle_pass_flow: HFlowContainer
var _offers_flow: HFlowContainer
var _analytics_label: Label
var _config_label: Label
var _reload_button: Button
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"live_ops")

	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)
	if not BattlePassManager.progress_changed.is_connected(_refresh_ui):
		BattlePassManager.progress_changed.connect(_refresh_ui)
	if not OfferManager.offers_changed.is_connected(_refresh_ui):
		OfferManager.offers_changed.connect(_refresh_ui)
	if not AnalyticsManager.analytics_changed.is_connected(_refresh_ui):
		AnalyticsManager.analytics_changed.connect(_refresh_ui)
	if not RemoteConfigManager.config_reloaded.is_connected(_refresh_ui):
		RemoteConfigManager.config_reloaded.connect(_refresh_ui)
	if not MetaProgression.profile_changed.is_connected(_refresh_ui):
		MetaProgression.profile_changed.connect(_refresh_ui)

	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.027, 0.046, 0.073, 1.0)
	backdrop.accent_a = Color(0.47, 0.9, 0.66, 0.18)
	backdrop.accent_b = Color(0.82, 0.62, 1.0, 0.18)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.14)
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
	BioUI.style_panel(header, Color(0.07, 0.12, 0.18, 0.92), Color(0.47, 0.9, 0.66, 0.82), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 36, Color(0.97, 1.0, 0.98, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 17)
	header_box.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_status_label, Color(0.08, 0.13, 0.18, 0.92), Color(0.47, 0.9, 0.66, 0.82))
	header_box.add_child(_status_label)

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

	content.add_child(_build_battle_pass_panel())
	content.add_child(_build_offers_panel())
	content.add_child(_build_analytics_panel())
	content.add_child(_build_config_panel())

	_back_button = Button.new()
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 70.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layout.add_child(_back_button)

func _build_battle_pass_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(0.47, 0.9, 0.66, 0.56), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("ops.pass.name")
	BioUI.style_heading(title, Color(0.47, 0.9, 0.66, 1.0), 24)
	box.add_child(title)

	_battle_pass_summary_label = Label.new()
	_battle_pass_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_battle_pass_summary_label, BioUI.COLOR_TEXT, 16)
	box.add_child(_battle_pass_summary_label)

	_battle_pass_bar = ProgressBar.new()
	_battle_pass_bar.custom_minimum_size = Vector2(0.0, 24.0)
	BioUI.style_progress(_battle_pass_bar, Color(0.47, 0.9, 0.66, 1.0))
	box.add_child(_battle_pass_bar)

	_battle_pass_flow = HFlowContainer.new()
	_battle_pass_flow.add_theme_constant_override("h_separation", 12)
	_battle_pass_flow.add_theme_constant_override("v_separation", 12)
	box.add_child(_battle_pass_flow)

	return panel

func _build_offers_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(1.0, 0.74, 0.38, 0.52), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("ops.offers.title")
	BioUI.style_heading(title, Color(1.0, 0.77, 0.41, 1.0), 24)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("ops.offers.subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 15)
	box.add_child(subtitle)

	_offers_flow = HFlowContainer.new()
	_offers_flow.add_theme_constant_override("h_separation", 12)
	_offers_flow.add_theme_constant_override("v_separation", 12)
	box.add_child(_offers_flow)

	return panel

func _build_analytics_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(0.44, 0.82, 1.0, 0.54), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("ops.analytics.title")
	BioUI.style_heading(title, Color(0.44, 0.82, 1.0, 1.0), 24)
	box.add_child(title)

	_analytics_label = Label.new()
	_analytics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_analytics_label, BioUI.COLOR_TEXT, 16)
	box.add_child(_analytics_label)

	return panel

func _build_config_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.17, 0.94), Color(0.82, 0.62, 1.0, 0.54), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("ops.config.title")
	BioUI.style_heading(title, Color(0.82, 0.62, 1.0, 1.0), 24)
	box.add_child(title)

	_config_label = Label.new()
	_config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_config_label, BioUI.COLOR_TEXT, 16)
	box.add_child(_config_label)

	_reload_button = Button.new()
	BioUI.style_button(_reload_button, Color(0.82, 0.62, 1.0, 1.0), 60.0)
	_reload_button.pressed.connect(func() -> void: RemoteConfigManager.reload_config())
	box.add_child(_reload_button)

	return panel

func _refresh_ui(_unused = null) -> void:
	_title_label.text = SettingsManager.t("ops.title")
	_subtitle_label.text = SettingsManager.t("ops.subtitle")
	_status_label.text = SettingsManager.t("ops.status") % [
		BattlePassManager.get_claimable_tier_count(),
		OfferManager.get_available_offer_count(),
		MetaProgression.dna
	]
	_reload_button.text = SettingsManager.t("ops.reload")
	_back_button.text = SettingsManager.t("common.main_menu")

	_refresh_battle_pass()
	_refresh_offers()
	_refresh_analytics()
	_refresh_remote_config()

func _refresh_battle_pass() -> void:
	var overview := BattlePassManager.get_overview()
	var next_target := int(overview.get("next_target", 0))
	_battle_pass_summary_label.text = SettingsManager.t("ops.pass.progress") % [
		int(overview.get("progress", 0)),
		int(overview.get("max_target", 0)),
		next_target
	]
	_battle_pass_bar.max_value = max(1, float(overview.get("max_target", 1)))
	_battle_pass_bar.value = float(overview.get("progress", 0))

	for child in _battle_pass_flow.get_children():
		child.queue_free()

	for tier in overview.get("tiers", []) as Array:
		var button := Button.new()
		button.custom_minimum_size = Vector2(178.0, 92.0)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_button(button, Color(0.47, 0.9, 0.66, 1.0), 84.0)
		var tier_dict := tier as Dictionary
		var index := int(tier_dict.get("index", 0))
		if bool(tier_dict.get("claimed", false)):
			button.text = "Tier %d\n%s" % [index + 1, SettingsManager.t("common.claimed")]
			button.disabled = true
		elif bool(tier_dict.get("reached", false)):
			button.text = "Tier %d\n%s %d DNA" % [index + 1, SettingsManager.t("common.claim"), int(tier_dict.get("reward_dna", 0))]
			button.pressed.connect(_on_claim_tier.bind(index))
		else:
			button.text = "Tier %d\n%d XP" % [index + 1, int(tier_dict.get("target", 0))]
			button.disabled = true
		_battle_pass_flow.add_child(button)

func _refresh_offers() -> void:
	for child in _offers_flow.get_children():
		child.queue_free()

	for offer in OfferManager.get_offers():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(244.0, 182.0)
		BioUI.style_panel(card, Color(0.08, 0.13, 0.18, 0.95), Color(1.0, 0.74, 0.38, 0.38), 22, 14)
		_offers_flow.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var title := Label.new()
		title.text = String(offer.get("display_name", ""))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_heading(title, Color(1.0, 0.78, 0.4, 1.0), 20)
		box.add_child(title)

		var description := Label.new()
		description.text = "%s\n+%d" % [String(offer.get("description", "")), int(offer.get("reward_amount", 0))]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_body(description, BioUI.COLOR_TEXT, 15)
		box.add_child(description)

		var button := Button.new()
		BioUI.style_button(button, Color(1.0, 0.74, 0.38, 1.0), 58.0)
		var offer_id := StringName(offer.get("id", ""))
		if bool(offer.get("available", false)):
			button.text = SettingsManager.t("common.claim_reward")
			button.pressed.connect(_on_claim_offer.bind(offer_id))
		else:
			button.text = SettingsManager.t("common.claimed")
			button.disabled = true
		box.add_child(button)

func _refresh_analytics() -> void:
	var snapshot := AnalyticsManager.get_snapshot()
	var lines: Array[String] = [
		SettingsManager.t("ops.analytics.summary") % [
			int(snapshot.get("session_count", 0)),
			int(snapshot.get("total_runs", 0)),
			int(snapshot.get("best_wave_seen", 0)),
			int(snapshot.get("total_dna_earned", 0)),
			int(round(float(snapshot.get("average_runtime_seconds", 0.0))))
		]
	]

	for event_info in snapshot.get("top_events", []) as Array:
		var entry := event_info as Dictionary
		lines.append("%s x%d" % [String(entry.get("name", "")), int(entry.get("count", 0))])

	_analytics_label.text = "\n".join(lines)

func _refresh_remote_config() -> void:
	var snapshot := RemoteConfigManager.get_snapshot()
	var economy := (snapshot.get("economy", {}) as Dictionary)
	var combat := (snapshot.get("combat", {}) as Dictionary)
	var reward_flow := (snapshot.get("reward_flow", {}) as Dictionary)
	_config_label.text = SettingsManager.t("ops.config.summary") % [
		float(economy.get("runtime_atp_scale", 1.0)),
		float(economy.get("dna_payout_scale", 1.0)),
		float(combat.get("enemy_health_scale", 1.0)),
		float(combat.get("enemy_speed_scale", 1.0)),
		float(combat.get("spawn_density_scale", 1.0)),
		int(reward_flow.get("revive_charges", 1)),
		float(reward_flow.get("dna_boost_multiplier", 2.0))
	]

func _on_claim_tier(index: int) -> void:
	BattlePassManager.claim_tier(index)

func _on_claim_offer(offer_id: StringName) -> void:
	OfferManager.claim_offer(offer_id)
