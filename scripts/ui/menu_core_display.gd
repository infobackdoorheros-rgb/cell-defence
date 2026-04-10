extends Control
class_name MenuCoreDisplay

@export var primary_color: Color = Color(0.36, 0.93, 0.84, 1.0)
@export var secondary_color: Color = Color(0.9, 0.46, 1.0, 1.0)

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.use_mobile_safe_visuals())
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var canvas_size := size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return

	var center: Vector2 = canvas_size * Vector2(0.5, 0.52)
	var radius: float = minf(canvas_size.x, canvas_size.y) * 0.23
	var rotation: float = (_time * 0.12) + (PI / 6.0)
	var safe_visuals := SettingsManager.use_mobile_safe_visuals()

	if not safe_visuals:
		_draw_scan_lines(canvas_size)
	_draw_glow(center + Vector2(-radius * 1.1, radius * 0.2), radius * 1.8, Color(primary_color.r, primary_color.g, primary_color.b, 0.08))
	_draw_glow(center + Vector2(radius * 1.2, -radius * 0.35), radius * 1.5, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.07))

	for ring_index in range(3):
		var ring_radius: float = radius * (1.45 + ring_index * 0.32 + sin(_time * (0.6 + ring_index * 0.15)) * 0.03)
		var ring_points := _hex_points(center, ring_radius, rotation + ring_index * 0.08)
		var closed_ring := ring_points.duplicate()
		closed_ring.append(ring_points[0])
		draw_polyline(closed_ring, Color(0.42, 0.84, 1.0, 0.12 - ring_index * 0.02), 2.0, true)

	var outer_hex := _hex_points(center, radius * 1.12, rotation)
	draw_colored_polygon(outer_hex, Color(primary_color.r, primary_color.g, primary_color.b, 0.08))
	var outer_closed := outer_hex.duplicate()
	outer_closed.append(outer_hex[0])
	draw_polyline(outer_closed, primary_color.lightened(0.15), 3.0, true)

	var inner_hex := _hex_points(center, radius * 0.62, rotation + 0.28)
	draw_colored_polygon(inner_hex, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.08))
	var inner_closed := inner_hex.duplicate()
	inner_closed.append(inner_hex[0])
	draw_polyline(inner_closed, secondary_color.lightened(0.12), 2.0, true)

	draw_circle(center, radius * 0.52, Color(0.08, 0.14, 0.22, 0.94))
	draw_circle(center, radius * 0.36, Color(primary_color.r, primary_color.g, primary_color.b, 0.95))
	draw_circle(center, radius * 0.18, Color(0.97, 1.0, 0.99, 1.0))

	for node_index in range(6):
		var node_angle: float = rotation + TAU * float(node_index) / 6.0
		var node_pos: Vector2 = center + Vector2.RIGHT.rotated(node_angle) * radius * 1.12
		draw_circle(node_pos, radius * 0.08, Color(0.95, 0.98, 1.0, 0.96))
		draw_circle(node_pos, radius * 0.05, secondary_color.lightened(0.12))
		if not safe_visuals:
			draw_line(center, node_pos, Color(secondary_color.r, secondary_color.g, secondary_color.b, 0.2), 1.6, true)

	for orbit_index in range(4):
		var orbit_angle: float = (_time * (0.7 + orbit_index * 0.18)) + TAU * float(orbit_index) / 4.0
		var orbit_distance: float = radius * (1.78 + (orbit_index % 2) * 0.2)
		var orbit_pos: Vector2 = center + Vector2.RIGHT.rotated(orbit_angle) * orbit_distance
		var orbit_color: Color = primary_color if orbit_index % 2 == 0 else secondary_color
		draw_circle(orbit_pos, radius * 0.12, Color(orbit_color.r, orbit_color.g, orbit_color.b, 0.9))
		draw_circle(orbit_pos, radius * 0.05, Color(0.98, 1.0, 1.0, 0.96))

	if not safe_visuals:
		var wave := PackedVector2Array()
		for index in range(20):
			var t: float = float(index) / 19.0
			var x: float = canvas_size.x * t
			var y: float = canvas_size.y * 0.18 + sin((_time * 0.8) + t * TAU * 1.8) * radius * 0.22
			wave.append(Vector2(x, y))
		draw_polyline(wave, Color(primary_color.r, primary_color.g, primary_color.b, 0.24), 2.0, true)

func _hex_points(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := rotation + TAU * float(index) / 6.0
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return points

func _draw_scan_lines(canvas_size: Vector2) -> void:
	for index in range(6):
		var y := canvas_size.y * (0.14 + index * 0.12)
		draw_line(Vector2(0.0, y), Vector2(canvas_size.x, y), Color(0.4, 0.82, 1.0, 0.04), 1.0, true)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(5, 0, -1):
		var t := float(layer) / 5.0
		draw_circle(center, radius * t, Color(color.r, color.g, color.b, color.a * t))
