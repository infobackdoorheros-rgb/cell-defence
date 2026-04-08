extends Control
class_name BioShowcase

@export var compact: bool = false

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center := Vector2(size.x * 0.5, size.y * 0.56)
	var scale: float = min(size.x, size.y) * (0.19 if compact else 0.24)

	_draw_glow(center + Vector2(-scale * 0.9, -scale * 0.8), scale * 1.6, Color(0.24, 0.9, 0.75, 0.08))
	_draw_glow(center + Vector2(scale * 1.1, -scale * 0.5), scale * 1.3, Color(1.0, 0.53, 0.47, 0.06))
	_draw_glow(center, scale * 1.9, Color(0.32, 0.72, 1.0, 0.08))

	var membrane_t: float = 0.5 + (sin(_time * 1.6) * 0.5)
	var outer_color := Color(0.49, 0.97, 0.85, 0.95)
	var membrane_color := outer_color.lerp(Color(0.76, 1.0, 0.96, 1.0), membrane_t * 0.22)
	draw_circle(center, scale * 1.18, Color(0.1, 0.2, 0.25, 0.42))
	draw_circle(center, scale, membrane_color)
	draw_circle(center, scale * 0.56, Color(0.95, 1.0, 0.98, 1.0))
	draw_circle(center + Vector2(scale * 0.14, -scale * 0.12), scale * 0.22, Color(0.62, 0.98, 0.88, 0.92))

	for ring_index in range(3):
		var radius: float = scale * (1.16 + (ring_index * 0.26) + (sin(_time * (0.7 + ring_index * 0.25)) * 0.03))
		var ring_color := Color(0.34, 0.9, 0.8, 0.2 - (ring_index * 0.04))
		draw_arc(center, radius, 0.0, TAU, 64, ring_color, 2.0)

	for satellite_index in range(4):
		var angle: float = (_time * (0.7 + satellite_index * 0.15)) + (TAU * float(satellite_index) / 4.0)
		var orbit_radius: float = scale * (1.36 + (satellite_index % 2) * 0.18)
		var position := center + Vector2.RIGHT.rotated(angle) * orbit_radius
		draw_circle(position, scale * 0.11, Color(0.82, 0.98, 1.0, 0.95))
		draw_circle(position, scale * 0.05, Color(0.27, 0.88, 1.0, 0.92))

	for virus_index in range(3):
		var angle := (-0.9 + (virus_index * 0.78)) + sin(_time * 0.8 + virus_index) * 0.15
		var position := center + Vector2.RIGHT.rotated(angle) * scale * (2.0 + virus_index * 0.16)
		_draw_virus(position, scale * (0.26 + virus_index * 0.03), virus_index == 1)

	for bacteria_index in range(2):
		var angle := (1.5 + (bacteria_index * 0.56)) + cos(_time * 0.65 + bacteria_index) * 0.15
		var position := center + Vector2.RIGHT.rotated(angle) * scale * (1.8 + bacteria_index * 0.2)
		_draw_bacteria(position, scale * (0.42 + bacteria_index * 0.08))

	var strand_points := PackedVector2Array()
	for index in range(14):
		var t: float = float(index) / 13.0
		var point := Vector2(size.x * t, size.y * 0.16 + sin((_time * 0.55) + (t * TAU * 2.0)) * scale * 0.18)
		strand_points.append(point)
	draw_polyline(strand_points, Color(0.38, 0.87, 0.84, 0.22), 3.0)

func _draw_virus(position: Vector2, radius: float, elite: bool) -> void:
	var body_color := Color(1.0, 0.52, 0.48, 0.88) if not elite else Color(1.0, 0.78, 0.35, 0.92)
	draw_circle(position, radius, body_color)
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0 + (_time * 0.2)
		var inner: Vector2 = position + Vector2.RIGHT.rotated(angle) * (radius - 2.0)
		var outer: Vector2 = position + Vector2.RIGHT.rotated(angle) * (radius + radius * 0.42)
		draw_line(inner, outer, body_color.lightened(0.2), 2.4)
	draw_circle(position, radius * 0.28, Color(1.0, 0.96, 0.94, 0.88))
	if elite:
		draw_arc(position, radius + 6.0, 0.0, TAU, 20, Color(1.0, 0.88, 0.45, 0.82), 3.0)

func _draw_bacteria(position: Vector2, radius: float) -> void:
	draw_circle(position, radius, Color(0.33, 0.86, 0.7, 0.9))
	draw_circle(position + Vector2(radius * 0.1, 0.0), radius * 0.58, Color(0.17, 0.48, 0.45, 0.88))
	draw_arc(position, radius + 4.0, 0.0, TAU, 20, Color(0.54, 0.96, 0.8, 0.22), 2.0)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var t: float = float(layer) / 4.0
		draw_circle(center, radius * t, Color(color.r, color.g, color.b, color.a * t))
