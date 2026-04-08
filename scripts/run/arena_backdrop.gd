extends Node2D
class_name ArenaBackdrop

var arena_center: Vector2 = Vector2.ZERO
var arena_radius: float = 260.0
var wave_number: int = 1
var active_enemy_count: int = 0
var _accent_primary: Color = Color(0.2, 0.78, 0.72, 0.08)
var _accent_secondary: Color = Color(0.31, 0.74, 1.0, 0.06)

var _rng := RandomNumberGenerator.new()
var _particles: Array[Dictionary] = []
var _time: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_build_particles()
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func set_arena_layout(new_center: Vector2, new_radius: float) -> void:
	arena_center = new_center
	arena_radius = new_radius
	_build_particles()
	queue_redraw()

func set_combat_state(new_wave: int, enemy_count: int) -> void:
	wave_number = max(new_wave, 1)
	active_enemy_count = max(enemy_count, 0)
	queue_redraw()

func set_theme_palette(primary: Color, secondary: Color) -> void:
	_accent_primary = primary
	_accent_secondary = secondary
	queue_redraw()

func _build_particles() -> void:
	_particles.clear()
	var particle_count := 10 if SettingsManager.use_mobile_safe_visuals() else 18
	for index in range(particle_count):
		_particles.append({
			"angle": _rng.randf_range(0.0, TAU),
			"distance": _rng.randf_range(0.18, 1.06),
			"radius": _rng.randf_range(2.0, 6.0),
			"speed": _rng.randf_range(0.06, 0.28),
			"phase": _rng.randf_range(0.0, TAU),
			"color_mix": _rng.randf()
		})

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var safe_visuals := SettingsManager.use_mobile_safe_visuals()
	draw_rect(rect, Color(0.018, 0.02, 0.045, 1.0), true)
	_draw_ambient_field(rect)

	var threat: float = clamp((float(active_enemy_count) / 18.0) + (float(wave_number) * 0.015), 0.0, 1.0)
	_draw_glow(arena_center, arena_radius * 1.3, Color(_accent_secondary.r, _accent_secondary.g, _accent_secondary.b, 0.05))
	_draw_glow(arena_center, arena_radius * 0.82, Color(_accent_primary.r, _accent_primary.g, _accent_primary.b, 0.05))
	_draw_glow(arena_center + Vector2(-42.0, 30.0), arena_radius * 0.62, Color(1.0, 0.49, 0.43, 0.03 + threat * 0.04))

	draw_circle(arena_center, arena_radius + 28.0, Color(0.04, 0.05, 0.08, 0.96))
	draw_circle(arena_center, arena_radius, Color(0.03, 0.05, 0.09, 0.98))

	var outer_rim_color := Color(0.34 + threat * 0.18, 0.7 - threat * 0.08, 0.93 - threat * 0.12, 0.78)
	draw_arc(arena_center, arena_radius, 0.0, TAU, 96, outer_rim_color, 4.0)
	draw_arc(arena_center, arena_radius * 0.52, 0.0, TAU, 72, Color(0.33, 0.86, 0.95, 0.18), 2.0)

	if not safe_visuals:
		var hex_points := PackedVector2Array()
		for hex_index in range(6):
			var angle: float = (_time * 0.08) + TAU * float(hex_index) / 6.0
			hex_points.append(arena_center + Vector2.RIGHT.rotated(angle) * (arena_radius * 0.12))
		hex_points.append(hex_points[0])
		draw_polyline(hex_points, Color(0.44, 0.82, 1.0, 0.44), 2.0)

	if not safe_visuals:
		for segment_index in range(10):
			var angle: float = TAU * float(segment_index) / 10.0 + (_time * 0.035)
			draw_arc(
				arena_center,
				arena_radius * 0.98,
				angle - 0.12,
				angle + 0.12,
				10,
				Color(0.55, 0.95, 0.9, 0.18),
				3.0
			)

	for particle in _particles:
		var angle: float = float(particle["angle"]) + (_time * float(particle["speed"]))
		var distance_ratio: float = float(particle["distance"])
		var particle_position := arena_center + Vector2.RIGHT.rotated(angle + sin(_time + float(particle["phase"])) * 0.08) * (arena_radius * distance_ratio)
		var particle_color := Color(0.31, 0.92, 0.84, 0.3).lerp(Color(0.96, 0.72, 0.33, 0.4), float(particle["color_mix"]) * threat)
		var particle_radius: float = float(particle["radius"])
		_draw_glow(particle_position, particle_radius * 2.3, Color(particle_color.r, particle_color.g, particle_color.b, 0.04))
		draw_circle(particle_position, particle_radius, particle_color)

func _draw_ambient_field(rect: Rect2) -> void:
	var safe_visuals := SettingsManager.use_mobile_safe_visuals()
	var glow_anchors := [
		{
			"position": Vector2(rect.size.x * 0.22, rect.size.y * 0.34),
			"radius": rect.size.y * 0.42,
			"color": Color(0.16, 0.54, 0.7, 0.045)
		},
		{
			"position": Vector2(rect.size.x * 0.74, rect.size.y * 0.28),
			"radius": rect.size.y * 0.36,
			"color": Color(0.18, 0.74, 0.65, 0.04)
		},
		{
			"position": Vector2(rect.size.x * 0.68, rect.size.y * 0.78),
			"radius": rect.size.y * 0.48,
			"color": Color(0.08, 0.42, 0.8, 0.03)
		}
	]
	for glow in glow_anchors:
		var glow_position: Vector2 = glow["position"]
		var glow_radius: float = float(glow["radius"])
		var glow_color: Color = glow["color"]
		_draw_glow(glow_position, glow_radius, glow_color)

	if safe_visuals:
		return

	for wave_index in range(3):
		var y_base := rect.size.y * (0.18 + wave_index * 0.26)
		var amplitude := 10.0 + wave_index * 5.0
		var phase := (_time * (0.22 + wave_index * 0.05)) + wave_index * 1.3
		var points := PackedVector2Array()
		var samples := 18
		for sample in range(samples):
			var t: float = float(sample) / float(samples - 1)
			var x := rect.size.x * t
			var y := y_base + sin((t * TAU * (1.0 + wave_index * 0.35)) + phase) * amplitude
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.29, 0.78, 0.9, 0.055 - wave_index * 0.008), 2.0, true)
		draw_polyline(points, Color(0.5, 0.95, 0.88, 0.03 - wave_index * 0.004), 1.0, true)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var t: float = float(layer) / 4.0
		draw_circle(center, radius * t, Color(color.r, color.g, color.b, color.a * t))
