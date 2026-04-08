extends Node2D
class_name AtpPickup

signal collected(amount: int)

var amount: int = 0
var core
var run_scene
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0

var _rng := RandomNumberGenerator.new()
var _visual_time: float = 0.0
var _spin_speed: float = 0.0

func _ready() -> void:
	_rng.randomize()

func initialize(atp_amount: int, core_ref, run_scene_ref) -> void:
	amount = atp_amount
	core = core_ref
	run_scene = run_scene_ref
	velocity = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(24.0, 64.0)
	_spin_speed = _rng.randf_range(1.4, 2.8)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if run_scene != null and run_scene.is_gameplay_paused():
		return
	if core == null or not is_instance_valid(core):
		queue_free()
		return

	age += delta
	_visual_time += delta
	var to_core: Vector2 = core.global_position - global_position
	var distance: float = to_core.length()
	var should_home: bool = distance <= core.get_pickup_radius() or age >= 2.0
	if should_home and distance > 0.0:
		var desired: Vector2 = to_core.normalized() * 440.0
		velocity = velocity.lerp(desired, 0.2)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.06)

	rotation += delta * _spin_speed
	global_position += velocity * delta
	queue_redraw()
	if distance <= core.get_core_radius() + 16.0:
		collected.emit(amount)
		queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + (sin(_visual_time * 6.0) * 0.08)
	var fill_color := Color(0.98, 0.9, 0.36, 1.0)
	var accent_color := Color(1.0, 0.77, 0.36, 0.94)
	var shadow_color := Color(0.64, 0.48, 0.09, 0.85)
	_draw_glow(Vector2.ZERO, 18.0 * pulse, Color(1.0, 0.8, 0.3, 0.08))

	var points := PackedVector2Array([
		Vector2(0.0, -10.0 * pulse),
		Vector2(7.0, -2.0),
		Vector2(10.0 * pulse, 0.0),
		Vector2(7.0, 2.0),
		Vector2(0.0, 10.0 * pulse),
		Vector2(-7.0, 2.0),
		Vector2(-10.0 * pulse, 0.0),
		Vector2(-7.0, -2.0),
	])
	draw_colored_polygon(points, fill_color)
	draw_polyline(points + PackedVector2Array([points[0]]), shadow_color, 2.0)
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.98, 0.9, 0.96))

	for orbit_index in range(2):
		var orbit_angle: float = (_visual_time * (1.7 + orbit_index * 0.45)) + (PI * orbit_index)
		var orbit_position := Vector2.RIGHT.rotated(orbit_angle) * (11.0 + orbit_index * 3.0)
		draw_circle(orbit_position, 2.2, accent_color)

	draw_line(Vector2(-6.0, -6.0), Vector2(6.0, 6.0), Color(1.0, 0.96, 0.78, 0.34), 1.4)
	draw_line(Vector2(-6.0, 6.0), Vector2(6.0, -6.0), Color(1.0, 0.96, 0.78, 0.34), 1.4)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var layer_t: float = float(layer) / 4.0
		draw_circle(center, radius * layer_t, Color(color.r, color.g, color.b, color.a * layer_t))
