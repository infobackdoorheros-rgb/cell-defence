extends Node2D
class_name DnaPickup

signal collected(amount: int)

var amount: int = 1
var core
var run_scene
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0

var _rng := RandomNumberGenerator.new()
var _visual_time: float = 0.0
var _spin_speed: float = 0.0

func _ready() -> void:
	_rng.randomize()
	add_to_group("dna_pickups")

func initialize(dna_amount: int, core_ref, run_scene_ref) -> void:
	amount = dna_amount
	core = core_ref
	run_scene = run_scene_ref
	velocity = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(12.0, 32.0)
	_spin_speed = _rng.randf_range(0.8, 1.8)
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
	var should_home: bool = distance <= core.get_pickup_radius() or age >= 3.5
	if should_home and distance > 0.0:
		var desired: Vector2 = to_core.normalized() * 340.0
		velocity = velocity.lerp(desired, 0.14)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.06)

	rotation += delta * _spin_speed
	global_position += velocity * delta
	queue_redraw()
	if distance <= core.get_core_radius() + 18.0:
		collected.emit(amount)
		queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + (sin(_visual_time * 5.0) * 0.06)
	_draw_glow(Vector2.ZERO, 23.0 * pulse, Color(0.88, 0.5, 1.0, 0.1))
	_draw_glow(Vector2.ZERO, 16.0 * pulse, Color(0.46, 0.78, 1.0, 0.08))

	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	for index in range(9):
		var t: float = float(index) / 8.0
		var y: float = lerpf(-15.0, 15.0, t)
		var helix_phase: float = (_visual_time * 2.0) + (t * PI * 2.0)
		var x_offset: float = sin(helix_phase) * 4.8 * pulse
		left_points.append(Vector2(x_offset - 4.2, y))
		right_points.append(Vector2(-x_offset + 4.2, y))

	draw_polyline(left_points, Color(0.48, 0.83, 1.0, 0.95), 2.3, true)
	draw_polyline(right_points, Color(0.98, 0.56, 1.0, 0.95), 2.3, true)

	for rung_index in range(1, 8):
		var left_point: Vector2 = left_points[rung_index]
		var right_point: Vector2 = right_points[rung_index]
		var rung_color := Color(0.88, 0.96, 1.0, 0.8) if rung_index % 2 == 0 else Color(1.0, 0.82, 0.5, 0.78)
		draw_line(left_point, right_point, rung_color, 1.6, true)
		draw_circle(left_point, 1.8, Color(0.72, 0.95, 1.0, 0.9))
		draw_circle(right_point, 1.8, Color(1.0, 0.78, 0.96, 0.9))

	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.98, 1.0, 0.9))

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for layer in range(4, 0, -1):
		var layer_t: float = float(layer) / 4.0
		draw_circle(center, radius * layer_t, Color(color.r, color.g, color.b, color.a * layer_t))
