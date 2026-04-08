extends Control
class_name BootLoadingSceneUI

const BioUI = preload("res://scripts/ui/bio_ui.gd")
const BioBackdrop = preload("res://scripts/ui/bio_backdrop.gd")

const TARGET_SCENE_PATH := "res://scenes/main_menu.tscn"
const LOGO_PATH := "res://BackDoorHerosLogo.png"
const MIN_DISPLAY_TIME := 1.85
const PROGRESS_LERP_SPEED := 4.8
const FALLBACK_TIMEOUT := 10.0
const _LOADING_MESSAGES := [
	"Calibrazione delle membrane cellulari",
	"Sincronizzazione del codice immunitario",
	"Attivazione delle difese del nucleo",
	"Apertura dell'hub di risposta immune"
]

var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _progress_value_label: Label
var _tip_label: Label

var _elapsed: float = 0.0
var _target_progress: float = 0.0
var _display_progress: float = 0.0
var _switch_queued: bool = false

func _ready() -> void:
	_enforce_mobile_orientation()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BioUI.style_root(self)
	_build_ui()
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	_update_target_progress()
	_update_progress_visual(delta)
	_update_loading_text()

	if _switch_queued:
		return

	if _elapsed >= MIN_DISPLAY_TIME and _display_progress >= 0.995:
		_open_target_scene()
		return

	if _elapsed >= FALLBACK_TIMEOUT:
		_open_target_scene()

func _build_ui() -> void:
	var backdrop := BioBackdrop.new()
	backdrop.base_color = Color(0.018, 0.038, 0.06, 1.0)
	backdrop.accent_a = Color(0.08, 0.96, 0.73, 0.26)
	backdrop.accent_b = Color(0.96, 0.91, 0.46, 0.12)
	backdrop.accent_c = Color(0.16, 0.52, 0.58, 0.2)
	backdrop.motion_strength = 0.72
	add_child(backdrop)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_top", 26)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_bottom", 26)
	add_child(root)

	var frame := VBoxContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_theme_constant_override("separation", 16)
	root.add_child(frame)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(top_spacer)

	var signature_label := Label.new()
	signature_label.text = "BACKDOOR HEROES"
	signature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_heading(signature_label, Color(0.08, 0.95, 0.72, 1.0), 24)
	frame.add_child(signature_label)

	var stage_label := Label.new()
	stage_label.text = "PRESENTS"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_subtitle(stage_label, 15)
	frame.add_child(stage_label)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 760.0)
	BioUI.style_panel(card, Color(0.04, 0.08, 0.11, 0.94), Color(0.12, 0.86, 0.73, 0.78), 34, 18)
	frame.add_child(card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 14)
	card.add_child(card_box)

	var logo_frame := PanelContainer.new()
	BioUI.style_panel(logo_frame, Color(0.03, 0.06, 0.08, 0.98), Color(0.96, 0.86, 0.46, 0.42), 28, 14)
	card_box.add_child(logo_frame)

	var logo_texture := _load_logo_texture()
	var logo := TextureRect.new()
	logo.texture = logo_texture
	logo.custom_minimum_size = Vector2(0.0, 420.0)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo_frame.add_child(logo)

	_title_label = Label.new()
	_title_label.text = "CELL DEFENSE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_title(_title_label, 40, Color(0.94, 1.0, 0.97, 1.0))
	card_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Core Immunity"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_heading(_subtitle_label, Color(0.94, 0.86, 0.46, 1.0), 24)
	card_box.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_body(_status_label, BioUI.COLOR_TEXT, 17)
	card_box.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, 28.0)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	BioUI.style_progress(_progress_bar, Color(0.08, 0.96, 0.73, 1.0))
	card_box.add_child(_progress_bar)

	_progress_value_label = Label.new()
	_progress_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BioUI.style_chip(_progress_value_label, Color(0.06, 0.1, 0.14, 0.95), Color(0.08, 0.96, 0.73, 0.82))
	card_box.add_child(_progress_value_label)

	_tip_label = Label.new()
	_tip_label.text = "Sincronizzazione protocolli immunitari e inizializzazione interfaccia biologica."
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BioUI.style_subtitle(_tip_label, 15)
	card_box.add_child(_tip_label)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(bottom_spacer)

func _update_target_progress() -> void:
	_target_progress = clamp(_elapsed / MIN_DISPLAY_TIME, 0.0, 1.0)

func _update_progress_visual(delta: float) -> void:
	var minimum_progress: float = min((_elapsed / MIN_DISPLAY_TIME) * 0.82, 0.82)
	_target_progress = max(_target_progress, minimum_progress)
	_display_progress = lerpf(_display_progress, _target_progress, clamp(delta * PROGRESS_LERP_SPEED, 0.0, 1.0))
	if absf(_display_progress - _target_progress) < 0.003:
		_display_progress = _target_progress

	_progress_bar.value = _display_progress * 100.0
	_progress_value_label.text = "LOAD %d%%" % int(round(_display_progress * 100.0))

func _update_loading_text() -> void:
	var pulse_stage: int = int(floor(_elapsed * 2.0)) % 4
	var suffix := ".".repeat(pulse_stage)
	var message_index: int = min(int(floor(_display_progress * float(_LOADING_MESSAGES.size()))), _LOADING_MESSAGES.size() - 1)
	_status_label.text = "%s%s" % [_LOADING_MESSAGES[message_index], suffix]

func _open_target_scene() -> void:
	if _switch_queued:
		return
	_switch_queued = true
	get_tree().change_scene_to_file(TARGET_SCENE_PATH)

func _load_logo_texture() -> Texture2D:
	var imported_texture := load(LOGO_PATH)
	if imported_texture is Texture2D:
		return imported_texture as Texture2D

	var image := Image.load_from_file(ProjectSettings.globalize_path(LOGO_PATH))
	if image == null or image.is_empty():
		push_warning("Unable to load logo from %s" % LOGO_PATH)
		var fallback := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.08, 0.96, 0.73, 1.0))
		return ImageTexture.create_from_image(fallback)
	return ImageTexture.create_from_image(image)

func _enforce_mobile_orientation() -> void:
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
