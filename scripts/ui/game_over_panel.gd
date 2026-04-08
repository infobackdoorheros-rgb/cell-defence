extends Control
class_name GameOverPanel

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

signal restart_requested
signal meta_requested
signal menu_requested
signal revive_requested
signal dna_boost_requested

var _summary_label: Label
var _chip_label: Label
var _title_label: Label
var _revive_button: Button
var _dna_boost_button: Button
var _restart_button: Button
var _lab_button: Button
var _menu_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	BioUI.style_root(self)
	visible = false
	_build_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.02, 0.035, 0.055, 0.2)
	backdrop.accent_a = Color(0.32, 0.9, 0.82, 0.14)
	backdrop.accent_b = Color(1.0, 0.54, 0.42, 0.12)
	backdrop.accent_c = Color(0.44, 0.82, 1.0, 0.14)
	backdrop.motion_strength = 0.4
	add_child(backdrop)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.06, 0.86)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.1
	frame.anchor_top = 0.17
	frame.anchor_right = 0.9
	frame.anchor_bottom = 0.83
	BioUI.style_panel(frame, Color(0.08, 0.12, 0.17, 0.95), Color(1.0, 0.76, 0.41, 0.9), 32, 22)
	add_child(frame)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)

	_chip_label = Label.new()
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_chip_label, Color(0.09, 0.14, 0.19, 0.96), Color(1.0, 0.77, 0.41, 0.84))
	box.add_child(_chip_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 34, Color(0.98, 0.99, 0.97, 1.0))
	box.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_summary_label, BioUI.COLOR_TEXT, 19)
	box.add_child(_summary_label)

	_revive_button = Button.new()
	BioUI.style_button(_revive_button, Color(0.35, 0.93, 0.84, 1.0), 74.0)
	_revive_button.pressed.connect(func() -> void: revive_requested.emit())
	box.add_child(_revive_button)

	_dna_boost_button = Button.new()
	BioUI.style_button(_dna_boost_button, Color(0.45, 0.82, 1.0, 1.0), 72.0)
	_dna_boost_button.pressed.connect(func() -> void: dna_boost_requested.emit())
	box.add_child(_dna_boost_button)

	_restart_button = Button.new()
	BioUI.style_button(_restart_button, Color(0.35, 0.95, 0.84, 1.0), 76.0)
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(_restart_button)

	_lab_button = Button.new()
	BioUI.style_button(_lab_button, Color(1.0, 0.77, 0.41, 1.0), 76.0)
	_lab_button.pressed.connect(func() -> void: meta_requested.emit())
	box.add_child(_lab_button)

	_menu_button = Button.new()
	BioUI.style_button(_menu_button, Color(0.46, 0.82, 1.0, 1.0), 70.0)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	box.add_child(_menu_button)

	_refresh_texts()

func show_summary(summary: Dictionary) -> void:
	_refresh_texts()
	_summary_label.text = SettingsManager.t("game_over.summary") % [
		int(summary.get("wave_reached", 1)),
		int(summary.get("kills", 0)),
		int(summary.get("elite_kills", 0)),
		int(summary.get("boss_kills", 0)),
		int(summary.get("dna_pickups", 0)),
		int(summary.get("dna_earned", 0)),
		int(summary.get("best_wave", 0))
	]
	visible = true

func hide_panel() -> void:
	visible = false

func set_reward_states(can_revive: bool, can_dna_boost: bool) -> void:
	_revive_button.disabled = not can_revive
	_dna_boost_button.disabled = not can_dna_boost

func _refresh_texts() -> void:
	_chip_label.text = SettingsManager.t("game_over.report")
	_title_label.text = SettingsManager.t("game_over.title")
	_revive_button.text = "Stimolo di Emergenza"
	_dna_boost_button.text = "DNA x2"
	_restart_button.text = SettingsManager.t("common.restart")
	_lab_button.text = SettingsManager.t("common.laboratory")
	_menu_button.text = SettingsManager.t("common.main_menu")
