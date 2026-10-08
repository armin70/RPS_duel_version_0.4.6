class_name SpecialChargeRing
extends Control

# Circular special-energy meter. It starts at the top and fills clockwise.
# The filled arc runs red -> yellow -> green, matching the reference style.

@export_range(0.05, 0.20, 0.005)
var ring_width_ratio: float = 0.085

@export_range(0.1, 10.0, 0.1)
var fill_animation_speed: float = 3.2

@export var empty_ring_color: Color = Color(0.18, 0.18, 0.18, 0.78)
@export var ring_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.42)

var _target_progress: float = 0.0
var _display_progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func set_progress_ratio(value: float) -> void:
	_target_progress = clampf(value, 0.0, 1.0)
	# Snap downward after spending the special; animate normal charging upward.
	if _target_progress < _display_progress:
		_display_progress = _target_progress
		queue_redraw()


func _process(delta: float) -> void:
	if is_equal_approx(_display_progress, _target_progress):
		return

	_display_progress = move_toward(
		_display_progress,
		_target_progress,
		delta * fill_animation_speed
	)
	queue_redraw()


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	if diameter <= 2.0:
		return

	var center := size * 0.5
	var width: float = clampf(
		diameter * ring_width_ratio,
		7.0,
		18.0
	)
	var radius: float = diameter * 0.5 - width * 0.60 - 2.0
	if radius <= 1.0:
		return

	var start_angle: float = -PI * 0.5
	var full_end: float = start_angle + TAU
	var points: int = 128

	# Soft dark edge gives the ring separation from bright board textures.
	draw_arc(
		center + Vector2(0.0, 2.0),
		radius,
		start_angle,
		full_end,
		points,
		ring_shadow_color,
		width + 5.0,
		true
	)

	# Empty track stays visible behind the charge.
	draw_arc(
		center,
		radius,
		start_angle,
		full_end,
		points,
		empty_ring_color,
		width,
		true
	)

	if _display_progress <= 0.001:
		return

	# Draw many tiny arc pieces so the circle has a real red-yellow-green
	# gradient instead of changing the whole ring to one flat color.
	var segment_count: int = maxi(1, int(120.0 * _display_progress))
	for index: int in range(segment_count):
		var t0: float = float(index) / 120.0
		var t1: float = minf(
			float(index + 1) / 120.0,
			_display_progress
		)
		if t1 <= t0:
			continue

		var a0: float = start_angle + TAU * t0
		var a1: float = start_angle + TAU * t1 + 0.006
		var color: Color = _charge_color((t0 + t1) * 0.5)

		draw_arc(
			center,
			radius,
			a0,
			a1,
			4,
			color,
			width,
			true
		)

	# Bright cap at the live end makes the progress edge easier to read.
	var end_angle: float = start_angle + TAU * _display_progress
	var cap_position := center + Vector2(cos(end_angle), sin(end_angle)) * radius
	var cap_color := _charge_color(_display_progress)
	draw_circle(cap_position, width * 0.47, cap_color)


func _charge_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t <= 0.5:
		return Color(
			1.0,
			lerpf(0.08, 0.92, t / 0.5),
			0.02,
			1.0
		)

	var green_t: float = (t - 0.5) / 0.5
	return Color(
		lerpf(1.0, 0.05, green_t),
		1.0,
		lerpf(0.02, 0.30, green_t),
		1.0
	)
