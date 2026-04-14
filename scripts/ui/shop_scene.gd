extends Control
class_name ShopSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _rewarded_summary_label: Label
var _rewarded_button: Button
var _packs_flow: HFlowContainer
var _offers_flow: HFlowContainer
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	AnalyticsManager.track_scene_enter(&"shop")
	if not SettingsManager.language_changed.is_connected(_refresh_ui):
		SettingsManager.language_changed.connect(_refresh_ui)
	if not MetaProgression.profile_changed.is_connected(_refresh_ui):
		MetaProgression.profile_changed.connect(_refresh_ui)
	if not ShopManager.shop_changed.is_connected(_refresh_ui):
		ShopManager.shop_changed.connect(_refresh_ui)
	if not OfferManager.offers_changed.is_connected(_refresh_ui):
		OfferManager.offers_changed.connect(_refresh_ui)
	_refresh_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.03, 0.05, 0.08, 1.0)
	backdrop.accent_a = Color(1.0, 0.76, 0.38, 0.18)
	backdrop.accent_b = Color(0.35, 0.92, 0.83, 0.18)
	backdrop.accent_c = Color(0.45, 0.82, 1.0, 0.14)
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
	BioUI.style_panel(header, Color(0.07, 0.11, 0.18, 0.94), Color(1.0, 0.74, 0.38, 0.84), 30, 18)
	layout.add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 36, Color(0.98, 0.99, 1.0, 1.0))
	header_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_subtitle_label, 16)
	header_box.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_status_label, Color(0.08, 0.11, 0.17, 0.96), Color(0.35, 0.92, 0.83, 0.84))
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

	content.add_child(_build_rewarded_panel())
	content.add_child(_build_packs_panel())
	content.add_child(_build_offers_panel())

	_back_button = Button.new()
	BioUI.style_button(_back_button, Color(0.44, 0.82, 1.0, 1.0), 68.0)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	layout.add_child(_back_button)

func _build_rewarded_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.18, 0.94), Color(0.35, 0.92, 0.83, 0.72), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("shop.rewarded_title")
	BioUI.style_heading(title, Color(0.35, 0.92, 0.83, 1.0), 24)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("shop.rewarded_subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 15)
	box.add_child(subtitle)

	_rewarded_summary_label = Label.new()
	_rewarded_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_rewarded_summary_label, BioUI.COLOR_TEXT, 16)
	box.add_child(_rewarded_summary_label)

	_rewarded_button = Button.new()
	BioUI.style_button(_rewarded_button, Color(0.35, 0.92, 0.83, 1.0), 62.0)
	_rewarded_button.pressed.connect(_on_rewarded_pressed)
	box.add_child(_rewarded_button)

	return panel

func _build_packs_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.18, 0.94), Color(1.0, 0.74, 0.38, 0.72), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("shop.packs_title")
	BioUI.style_heading(title, Color(1.0, 0.78, 0.4, 1.0), 24)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("shop.packs_subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 15)
	box.add_child(subtitle)

	_packs_flow = HFlowContainer.new()
	_packs_flow.add_theme_constant_override("h_separation", 12)
	_packs_flow.add_theme_constant_override("v_separation", 12)
	box.add_child(_packs_flow)

	return panel

func _build_offers_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	BioUI.style_panel(panel, Color(0.07, 0.12, 0.18, 0.94), Color(0.82, 0.62, 1.0, 0.66), 26, 18)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = SettingsManager.t("shop.flash_title")
	BioUI.style_heading(title, Color(0.88, 0.6, 1.0, 1.0), 24)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t("shop.flash_subtitle")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(subtitle, 15)
	box.add_child(subtitle)

	_offers_flow = HFlowContainer.new()
	_offers_flow.add_theme_constant_override("h_separation", 12)
	_offers_flow.add_theme_constant_override("v_separation", 12)
	box.add_child(_offers_flow)

	return panel

func _refresh_ui(_unused = null) -> void:
	_title_label.text = SettingsManager.t("shop.title")
	_subtitle_label.text = SettingsManager.t("shop.subtitle")
	var summary := ShopManager.get_shop_summary()
	var monetization_enabled := ShopManager.is_rewarded_enabled() or ShopManager.are_purchases_enabled() or ShopManager.are_offer_claims_enabled()
	if monetization_enabled:
		_status_label.text = SettingsManager.t("shop.status") % [
			MetaProgression.dna,
			int(summary.get("free_dna_remaining", 0)),
			int(summary.get("offers_available", 0))
		]
	else:
		_status_label.text = SettingsManager.t("shop.beta_locked") % [MetaProgression.dna]
	_back_button.text = SettingsManager.t("common.main_menu")
	_refresh_rewarded()
	_refresh_packs()
	_refresh_offers()

func _refresh_rewarded() -> void:
	var overview := ShopManager.get_rewarded_video_overview()
	if not bool(overview.get("enabled", false)):
		_rewarded_summary_label.text = SettingsManager.t("shop.rewarded_locked")
		_rewarded_button.text = SettingsManager.t("common.coming_soon")
		_rewarded_button.disabled = true
		return
	_rewarded_summary_label.text = SettingsManager.t("shop.rewarded_status") % [
		int(overview.get("reward_amount", 0)),
		int(overview.get("remaining", 0)),
		int(overview.get("limit", 0))
	]
	_rewarded_button.text = SettingsManager.t("shop.rewarded_claim")
	_rewarded_button.disabled = not bool(overview.get("available", false))
	if _rewarded_button.disabled:
		_rewarded_button.text = SettingsManager.t("shop.rewarded_done")

func _refresh_packs() -> void:
	for child in _packs_flow.get_children():
		child.queue_free()

	var purchases_enabled := ShopManager.are_purchases_enabled()
	for pack in ShopManager.get_dna_packs():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(212.0, 208.0)
		BioUI.style_panel(card, Color(0.08, 0.13, 0.18, 0.95), Color(1.0, 0.74, 0.38, 0.44), 22, 14)
		_packs_flow.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var pack_id := String(pack.get("id", ""))
		var title := Label.new()
		title.text = SettingsManager.t("shop.pack.%s.title" % pack_id)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_heading(title, Color(1.0, 0.78, 0.4, 1.0), 20)
		box.add_child(title)

		var body := Label.new()
		body.text = SettingsManager.t("shop.pack.%s.body" % pack_id) % [
			int(pack.get("dna", 0)),
			int(pack.get("bonus", 0)),
			int(pack.get("total_dna", 0))
		]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_body(body, BioUI.COLOR_TEXT, 15)
		box.add_child(body)

		var claims := int(pack.get("claim_count", 0))
		var meta := Label.new()
		if purchases_enabled:
			meta.text = "%s\n%s %d" % [String(pack.get("price_label", "")), SettingsManager.t("shop.purchase_count"), claims]
		else:
			meta.text = "%s\n%s" % [String(pack.get("price_label", "")), SettingsManager.t("shop.packs_locked")]
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_subtitle(meta, 14)
		box.add_child(meta)

		var button := Button.new()
		BioUI.style_button(button, Color(1.0, 0.74, 0.38, 1.0), 56.0)
		button.text = SettingsManager.t("shop.buy_pack") if purchases_enabled else SettingsManager.t("common.coming_soon")
		button.disabled = not purchases_enabled
		if purchases_enabled:
			button.pressed.connect(_on_pack_pressed.bind(StringName(pack_id)))
		box.add_child(button)

func _refresh_offers() -> void:
	for child in _offers_flow.get_children():
		child.queue_free()

	var offers_enabled := ShopManager.are_offer_claims_enabled()
	for offer in ShopManager.get_flash_offers():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(224.0, 188.0)
		BioUI.style_panel(card, Color(0.08, 0.13, 0.18, 0.95), Color(0.82, 0.62, 1.0, 0.4), 22, 14)
		_offers_flow.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var title := Label.new()
		title.text = String(offer.get("display_name", ""))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_heading(title, Color(0.88, 0.6, 1.0, 1.0), 19)
		box.add_child(title)

		var body := Label.new()
		body.text = "%s\n+%d" % [String(offer.get("description", "")), int(offer.get("reward_amount", 0))]
		if not offers_enabled:
			body.text += "\n%s" % SettingsManager.t("shop.offers_locked")
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		BioUI.style_body(body, BioUI.COLOR_TEXT, 15)
		box.add_child(body)

		var button := Button.new()
		BioUI.style_button(button, Color(0.82, 0.62, 1.0, 1.0), 54.0)
		var offer_id := StringName(offer.get("id", ""))
		if offers_enabled and bool(offer.get("available", false)):
			button.text = SettingsManager.t("shop.flash_claim")
			button.pressed.connect(_on_offer_pressed.bind(offer_id))
		else:
			button.text = SettingsManager.t("common.coming_soon") if not offers_enabled else SettingsManager.t("common.claimed")
			button.disabled = true
		box.add_child(button)

func _on_rewarded_pressed() -> void:
	if ShopManager.claim_rewarded_video():
		_status_label.text = SettingsManager.t("shop.rewarded_granted") % [MetaProgression.dna]
	_refresh_ui()

func _on_pack_pressed(pack_id: StringName) -> void:
	if ShopManager.purchase_dna_pack(pack_id):
		_status_label.text = SettingsManager.t("shop.purchase_done") % [MetaProgression.dna]
	_refresh_ui()

func _on_offer_pressed(offer_id: StringName) -> void:
	if ShopManager.claim_flash_offer(offer_id):
		_status_label.text = SettingsManager.t("shop.offer_done") % [MetaProgression.dna]
	_refresh_ui()
