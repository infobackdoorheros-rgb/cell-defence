extends Control
class_name BioBackdrop

@export var base_color: Color = Color(0.025, 0.05, 0.08, 1.0)
@export var accent_a: Color = Color(0.23, 0.9, 0.78, 0.45)
@export var accent_b: Color = Color(1.0, 0.55, 0.44, 0.32)
@export var accent_c: Color = Color(0.41, 0.76, 1.0, 0.32)
@export var motion_strength: float = 1.0

var _rng := RandomNumberGenerator.new()
var _motes: Array[Dictionary] = []
var _fibers: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _time: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	if not resized.is_connected(_rebuild_field):
		resized.connect(_rebuild_field)
	_rebuild_field()
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _rebuild_field() -> void:
	var viewport_size: Vector2 = get_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_motes.clear()
	_fibers.clear()
	_clouds.clear()
	var safe_visuals := SettingsManager.use_mobile_safe_visuals()

	for index in range(14 if safe_visuals else 24):
		_motes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"radius": _rng.randf_range(3.0, 12.0),
			"speed": _rng.randf_range(0.14, 0.55),
			"phase": _rng.randf_range(0.0, TAU),
			"depth": _rng.randf_range(0.35, 1.0),
			"color_mix": _rng.randf()
		})

	if not safe_visuals:
		for index in range(7):
			_fibers.append({
				"y": _rng.randf(),
				"amplitude": _rng.randf_range(14.0, 34.0),
				"speed": _rng.randf_range(0.08, 0.26),
				"phase": _rng.randf_range(0.0, TAU),
				"thickness": _rng.randf_range(1.5, 3.2),
				"alpha": _rng.randf_range(0.1, 0.22)
			})

	for index in range(4 if safe_visuals else 6):
		_clouds.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"radius": _rng.randf_range(min(viewport_size.x, viewport_size.y) * 0.18, min(viewport_size.x, viewport_size.y) * 0.36),
			"speed": _rng.randf_range(0.04, 0.12),
			"phase": _rng.randf_range(0.0, TAU),
			"mix": _rng.randf()
		})

	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, get_size())
	draw_rect(rect, base_color, true)
	_draw_ambient_field(rect)

	for cloud in _clouds:
		var center := Vector2(
			rect.size.x * float(cloud["x"]) + sin((_time * float(cloud["speed"]) * motion_strength) + float(cloud["phase"])) * 24.0,
			rect.size.y * float(cloud["y"]) + cos((_time * float(cloud["speed"]) * motion_strength) + float(cloud["phase"])) * 16.0
		)
		var cloud_color := accent_a.lerp(accent_c, float(cloud["mix"]))
		_draw_glow(center, float(cloud["radius"]), Color(cloud_color.r, cloud_color.g, cloud_color.b, 0.08))
		_draw_glow(center + Vector2(40.0, -28.0), float(cloud["radius"]) * 0.65, Color(accent_b.r, accent_b.g, accent_b.b, 0.05))

	for fiber in _fibers:
		var points := PackedVector2Array()
		var samples: int = 18
		for step_index in range(samples + 1):
			var sample_t: float = float(step_index) / float(samples)
			var x: float = rect.size.x * sample_t
			var base_y: float = rect.size.y * float(fiber["y"])
			var y: float = base_y + sin((sample_t * 5.6) + (_time * float(fiber["speed"]) * motion_strength) + float(fiber["phase"])) * float(fiber["amplitude"])
			points.append(Vector2(x, y))
		var fiber_color := Color(accent_c.r, accent_c.g, accent_c.b, float(fiber["alpha"]))
		draw_polyline(points, fiber_color, float(fiber["thickness"]))
		draw_polyline(points, Color(accent_a.r, accent_a.g, accent_a.b, float(fiber["alpha"]) * 0.45), max(float(fiber["thickness"]) - 1.0, 1.0))

	for mote in _motes:
		var base_position := Vector2(rect.size.x * float(mote["x"]), rect.size.y * float(mote["y"]))
		var drift := Vector2(
			sin((_time * float(mote["speed"]) * motion_strength) + float(mote["phase"])) * 16.0 * float(mote["depth"]),
			cos((_time * float(mote["speed"]) * motion_strength * 0.7) + float(mote["phase"])) * 12.0 * float(mote["depth"])
		)
		var center := base_position + drift
		var radius: float = float(mote["radius"])
		var mote_color := accent_a.lerp(accent_b, float(mote["color_mix"]))
		mote_color.a = 0.55
		_draw_glow(center, radius * 3.4, Color(mote_color.r, mote_color.g, mote_color.b, 0.06 * float(mote["depth"])))
		draw_circle(center, radius, mote_color)
		draw_circle(center, radius * 0.38, Color(1.0, 1.0, 1.0, 0.75))

func _draw_ambient_field(rect: Rect2) -> void:
	var safe_visuals := SettingsManager.use_mobile_safe_visuals()
	var gradient_clouds := [
		{
			"position": Vector2(rect.size.x * 0.16, rect.size.y * 0.2),
			"radius": rect.size.y * 0.42,
			"color": Color(accent_c.r, accent_c.g, accent_c.b, 0.04)
		},
		{
			"position": Vector2(rect.size.x * 0.78, rect.size.y * 0.16),
			"radius": rect.size.y * 0.34,
			"color": Color(accent_a.r, accent_a.g, accent_a.b, 0.05)
		},
		{
			"position": Vector2(rect.size.x * 0.5, rect.size.y * 0.78),
			"radius": rect.size.y * 0.48,
			"color": Color(accent_b.r, accent_b.g, accent_b.b, 0.03)
		}
	]
	for cloud in gradient_clouds:
		var cloud_position: Vector2 = cloud["position"]
		var cloud_radius: float = float(cloud["radius"])
		var cloud_color: Color = cloud["color"]
		_draw_glow(cloud_position, cloud_radius, cloud_color)

	if safe_visuals:
		return

	for wave_index in range(4):
		var base_y := rect.size.y * (0.14 + wave_index * 0.22)
		var amplitude := 10.0 + (wave_index * 4.5)
		var phase := (_time * (0.12 + wave_index * 0.03) * motion_strength) + wave_index * 1.1
		var points := PackedVector2Array()
		var samples := 16
		for sample in range(samples):
			var t: float = float(sample) / float(samples - 1)
			var x := rect.size.x * t
			var y := base_y + sin((t * TAU * (1.0 + wave_index * 0.18)) + phase) * amplitude
			points.append(Vector2(x, y))
		draw_polyline(points, Color(accent_c.r, accent_c.g, accent_c.b, 0.05 - wave_index * 0.008), 1.6, true)
		draw_polyline(points, Color(accent_a.r, accent_a.g, accent_a.b, 0.03 - wave_index * 0.004), 1.0, true)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	var layers: int = 4
	for layer in range(layers, 0, -1):
		var layer_t: float = float(layer) / float(layers)
		var layer_color := Color(color.r, color.g, color.b, color.a * layer_t)
		draw_circle(center, radius * layer_t, layer_color)
