extends Control
class_name MutationChoicePanel

const MutationData = preload("res://scripts/data/mutation_data.gd")
const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

signal mutation_selected(mutation_id: StringName)

var _list: HFlowContainer
var _chip_label: Label
var _title_label: Label
var _subtitle_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	BioUI.style_root(self)
	visible = false
	_build_ui()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.02, 0.04, 0.06, 0.18)
	backdrop.accent_a = Color(0.37, 0.94, 0.84, 0.12)
	backdrop.accent_b = Color(1.0, 0.77, 0.42, 0.1)
	backdrop.accent_c = Color(0.47, 0.82, 1.0, 0.12)
	backdrop.motion_strength = 0.45
	add_child(backdrop)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.06, 0.82)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.08
	frame.anchor_top = 0.14
	frame.anchor_right = 0.92
	frame.anchor_bottom = 0.86
	BioUI.style_panel(frame, Color(0.08, 0.12, 0.18, 0.95), Color(0.35, 0.95, 0.85, 0.88), 32, 20)
	add_child(frame)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	_chip_label = Label.new()
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_chip_label, Color(0.08, 0.13, 0.18, 0.96), Color(0.36, 0.94, 0.84, 0.86))
	box.add_child(_chip_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 32, Color(0.98, 1.0, 0.99, 1.0))
	box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 18)
	box.add_child(_subtitle_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_list = HFlowContainer.new()
	_list.add_theme_constant_override("h_separation", 12)
	_list.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_list)

	_refresh_texts()

func show_choices(options: Array[MutationData]) -> void:
	for child in _list.get_children():
		child.queue_free()

	for mutation in options:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(250.0, 132.0)
		BioUI.style_button(button, Color(1.0, 0.78, 0.42, 1.0), 116.0)
		button.text = "%s\n%s" % [mutation.display_name, mutation.description]
		button.pressed.connect(_on_mutation_button_pressed.bind(mutation.mutation_id))
		_list.add_child(button)

	visible = true

func hide_panel() -> void:
	visible = false

func _on_mutation_button_pressed(mutation_id: StringName) -> void:
	mutation_selected.emit(mutation_id)

func _refresh_texts() -> void:
	_chip_label.text = SettingsManager.t("mutation.report")
	_title_label.text = SettingsManager.t("mutation.title")
	_subtitle_label.text = SettingsManager.t("mutation.subtitle")
