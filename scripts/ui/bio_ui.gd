extends RefCounted
class_name BioUI

const COLOR_BG := Color(0.03, 0.055, 0.09, 1.0)
const COLOR_BG_ALT := Color(0.05, 0.09, 0.14, 1.0)
const COLOR_PANEL := Color(0.07, 0.12, 0.17, 0.88)
const COLOR_PANEL_ALT := Color(0.1, 0.16, 0.21, 0.9)
const COLOR_BORDER := Color(0.22, 0.61, 0.6, 0.95)
const COLOR_ACCENT := Color(0.35, 0.93, 0.83, 1.0)
const COLOR_ACCENT_WARM := Color(1.0, 0.74, 0.38, 1.0)
const COLOR_TEXT := Color(0.93, 0.99, 0.97, 1.0)
const COLOR_TEXT_MUTED := Color(0.67, 0.83, 0.84, 1.0)
const COLOR_DANGER := Color(1.0, 0.46, 0.44, 1.0)

static var _cached_theme: Theme

static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var theme := Theme.new()
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 20)
	theme.set_font_size("font_size", "TabBar", 18)
	theme.set_font_size("font_size", "ProgressBar", 16)

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.4))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)

	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT)
	theme.set_color("font_disabled_color", "Button", Color(0.48, 0.59, 0.63, 1.0))

	theme.set_stylebox("panel", "PanelContainer", _make_panel_style(COLOR_PANEL, COLOR_BORDER, 26, 18))
	theme.set_stylebox("normal", "Button", _make_button_style(COLOR_PANEL_ALT, COLOR_BORDER))
	theme.set_stylebox("hover", "Button", _make_button_style(Color(0.12, 0.21, 0.28, 0.96), COLOR_ACCENT))
	theme.set_stylebox("pressed", "Button", _make_button_style(Color(0.14, 0.27, 0.32, 0.98), COLOR_ACCENT_WARM))
	theme.set_stylebox("disabled", "Button", _make_button_style(Color(0.08, 0.11, 0.14, 0.86), Color(0.18, 0.24, 0.27, 0.8)))

	theme.set_stylebox("tab_selected", "TabBar", _make_button_style(Color(0.12, 0.22, 0.28, 0.96), COLOR_ACCENT, 18, 14))
	theme.set_stylebox("tab_hovered", "TabBar", _make_button_style(Color(0.1, 0.17, 0.23, 0.92), COLOR_BORDER, 18, 14))
	theme.set_stylebox("tab_unselected", "TabBar", _make_button_style(Color(0.07, 0.1, 0.14, 0.84), Color(0.16, 0.24, 0.27, 0.85), 18, 14))
	theme.set_stylebox("panel", "TabContainer", _make_panel_style(Color(0.05, 0.08, 0.11, 0.74), Color(0.17, 0.31, 0.34, 0.9), 24, 14))
	theme.set_color("font_selected_color", "TabBar", COLOR_TEXT)
	theme.set_color("font_unselected_color", "TabBar", COLOR_TEXT_MUTED)
	theme.set_color("font_hovered_color", "TabBar", COLOR_TEXT)

	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.06, 0.09, 0.12, 0.96)
	progress_bg.set_corner_radius_all(20)
	progress_bg.content_margin_left = 4
	progress_bg.content_margin_right = 4
	progress_bg.content_margin_top = 4
	progress_bg.content_margin_bottom = 4
	theme.set_stylebox("background", "ProgressBar", progress_bg)

	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = COLOR_ACCENT
	progress_fill.set_corner_radius_all(18)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)

	_cached_theme = theme
	return _cached_theme

static func style_root(control: Control) -> void:
	control.theme = get_theme()

static func style_panel(panel: PanelContainer, fill: Color = COLOR_PANEL, border: Color = COLOR_BORDER, radius: int = 26, padding: int = 18) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(fill, border, radius, padding))

static func style_button(button: Button, accent: Color = COLOR_ACCENT, minimum_height: float = 74.0) -> void:
	button.custom_minimum_size.y = minimum_height
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.09, 0.14, 0.19, 0.94), accent))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.21, 0.28, 0.98), accent.lightened(0.14)))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent.darkened(0.45), accent.lightened(0.08)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.07, 0.09, 0.12, 0.86), Color(0.17, 0.22, 0.25, 0.7)))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.56, 0.59, 1.0))

static func style_title(label: Label, size: int = 54, accent: Color = COLOR_TEXT) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)

static func style_heading(label: Label, accent: Color = COLOR_ACCENT_WARM, size: int = 28) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", accent)

static func style_subtitle(label: Label, size: int = 18) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)

static func style_body(label: Label, accent: Color = COLOR_TEXT, size: int = 18) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", accent)

static func style_chip(label: Label, fill: Color = COLOR_PANEL_ALT, accent: Color = COLOR_ACCENT) -> void:
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_stylebox_override("normal", _make_chip_style(fill, accent))

static func style_progress(progress_bar: ProgressBar, accent: Color = COLOR_ACCENT) -> void:
	progress_bar.add_theme_stylebox_override("fill", _make_progress_fill(accent))
	progress_bar.add_theme_stylebox_override("background", _make_progress_background())
	progress_bar.show_percentage = false

static func get_category_accent(category: StringName) -> Color:
	match category:
		&"attack":
			return Color(1.0, 0.53, 0.47, 1.0)
		&"defense":
			return Color(0.37, 0.86, 0.65, 1.0)
		&"utility":
			return Color(0.45, 0.82, 1.0, 1.0)
		&"mutation":
			return Color(1.0, 0.78, 0.39, 1.0)
		_:
			return COLOR_ACCENT

static func _make_panel_style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func _make_button_style(fill: Color, border: Color, radius: int = 24, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func _make_chip_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(999)
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

static func _make_progress_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.12, 0.95)
	style.set_corner_radius_all(999)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func _make_progress_fill(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(999)
	return style
