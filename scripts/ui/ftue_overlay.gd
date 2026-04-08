extends Control
class_name FTUEOverlay

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

signal dismissed

var _title_label: Label
var _subtitle_label: Label
var _progress_label: Label
var _page_title_label: Label
var _page_body_label: Label
var _back_button: Button
var _next_button: Button
var _skip_button: Button

var _pages: Array[Dictionary] = []
var _page_index: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	BioUI.style_root(self)
	visible = false
	_build_ui()

func show_ftue(core_name: String, chapter_name: String, active_skill_name: String) -> void:
	_title_label.text = SettingsManager.t("ftue.title")
	_subtitle_label.text = "%s\nCore: %s   Sector: %s" % [
		SettingsManager.t("ftue.subtitle"),
		core_name,
		chapter_name
	]
	_pages = [
		{
			"title": SettingsManager.t("ftue.page1.title"),
			"body": SettingsManager.t("ftue.page1.body")
		},
		{
			"title": SettingsManager.t("ftue.page2.title"),
			"body": SettingsManager.t("ftue.page2.body")
		},
		{
			"title": SettingsManager.t("ftue.page3.title"),
			"body": SettingsManager.t("ftue.page3.body")
		},
		{
			"title": SettingsManager.t("ftue.page4.title"),
			"body": SettingsManager.t("ftue.page4.body") % [active_skill_name]
		}
	]
	_page_index = 0
	_refresh_page()
	visible = true

func hide_overlay() -> void:
	visible = false

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.02, 0.04, 0.06, 0.18)
	backdrop.accent_a = Color(0.37, 0.94, 0.84, 0.12)
	backdrop.accent_b = Color(1.0, 0.77, 0.42, 0.1)
	backdrop.accent_c = Color(0.47, 0.82, 1.0, 0.12)
	backdrop.motion_strength = 0.35
	add_child(backdrop)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.06, 0.86)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.06
	frame.anchor_top = 0.1
	frame.anchor_right = 0.94
	frame.anchor_bottom = 0.9
	BioUI.style_panel(frame, Color(0.08, 0.12, 0.18, 0.95), Color(0.35, 0.95, 0.85, 0.88), 32, 20)
	add_child(frame)

	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 32, Color(0.98, 1.0, 0.99, 1.0))
	box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(_subtitle_label, 17)
	box.add_child(_subtitle_label)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_progress_label, Color(0.07, 0.1, 0.16, 0.96), Color(1.0, 0.77, 0.41, 0.82))
	box.add_child(_progress_label)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	BioUI.style_panel(content_panel, Color(0.07, 0.11, 0.16, 0.94), Color(1.0, 0.77, 0.41, 0.44), 24, 18)
	box.add_child(content_panel)

	var content_box := VBoxContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 12)
	content_panel.add_child(content_box)

	_page_title_label = Label.new()
	_page_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_heading(_page_title_label, Color(1.0, 0.77, 0.41, 1.0), 26)
	content_box.add_child(_page_title_label)

	_page_body_label = Label.new()
	_page_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_body(_page_body_label, BioUI.COLOR_TEXT, 20)
	content_box.add_child(_page_body_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	box.add_child(footer)

	_back_button = Button.new()
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_back_button, Color(0.44, 0.83, 1.0, 1.0), 68.0)
	_back_button.pressed.connect(_on_back_pressed)
	footer.add_child(_back_button)

	_skip_button = Button.new()
	_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_skip_button, Color(1.0, 0.5, 0.45, 1.0), 68.0)
	_skip_button.pressed.connect(_finish_ftue)
	footer.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BioUI.style_button(_next_button, Color(0.35, 0.93, 0.84, 1.0), 72.0)
	_next_button.pressed.connect(_on_next_pressed)
	footer.add_child(_next_button)

func _refresh_page() -> void:
	if _pages.is_empty():
		return
	var page := _pages[_page_index]
	_progress_label.text = SettingsManager.t("ftue.progress") % [_page_index + 1, _pages.size()]
	_page_title_label.text = String(page.get("title", ""))
	_page_body_label.text = String(page.get("body", ""))
	_back_button.text = SettingsManager.t("ftue.back")
	_skip_button.text = SettingsManager.t("ftue.skip")
	_next_button.text = SettingsManager.t("ftue.start") if _page_index == _pages.size() - 1 else SettingsManager.t("ftue.next")
	_back_button.disabled = _page_index == 0

func _on_back_pressed() -> void:
	_page_index = max(0, _page_index - 1)
	_refresh_page()

func _on_next_pressed() -> void:
	if _page_index >= _pages.size() - 1:
		_finish_ftue()
		return
	_page_index += 1
	_refresh_page()

func _finish_ftue() -> void:
	hide_overlay()
	dismissed.emit()
