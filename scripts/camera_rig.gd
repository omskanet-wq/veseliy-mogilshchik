extends Node3D
class_name CameraRig
## Top-down 3D camera rig with smooth zoom and pan.
##
## Zoom: hooked to "+" / "-" actions, mouse wheel, or pinch gesture.
## Pan: WASD/arrow keys, or middle-mouse drag, or 1-finger drag on touch.

@export var min_zoom: float = 6.0
@export var max_zoom: float = 28.0
@export var default_zoom: float = 16.0
@export var pan_speed: float = 12.0
@export var pivot_bounds: Vector2 = Vector2(40.0, 40.0)
@export var look_angle_deg: float = 55.0

@onready var camera: Camera3D = $Camera3D

var _target_zoom: float = default_zoom
var _current_zoom: float = default_zoom
var _is_dragging: bool = false
var _drag_last_pos: Vector2 = Vector2.ZERO
var _pinch_last_distance: float = 0.0
var _active_touches: Dictionary = {}


func _ready() -> void:
	if camera == null:
		camera = Camera3D.new()
		add_child(camera)
	_apply_zoom(true)


func _process(delta: float) -> void:
	# Smooth zoom interpolation.
	if abs(_current_zoom - _target_zoom) > 0.01:
		_current_zoom = lerp(_current_zoom, _target_zoom, clamp(delta * 8.0, 0.0, 1.0))
		_apply_zoom()
	# Keyboard pan.
	var pan := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_left"):
		pan.x -= 1
	if Input.is_action_pressed("camera_pan_right"):
		pan.x += 1
	if Input.is_action_pressed("camera_pan_up"):
		pan.y -= 1
	if Input.is_action_pressed("camera_pan_down"):
		pan.y += 1
	if pan != Vector2.ZERO:
		_pan_pivot(pan.normalized() * pan_speed * delta)
	# Held +/- keys for zoom.
	if Input.is_action_pressed("zoom_in"):
		zoom_by(-delta * 12.0)
	if Input.is_action_pressed("zoom_out"):
		zoom_by(delta * 12.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(-1.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(1.5)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = mb.pressed
			_drag_last_pos = mb.position
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var delta := mm.relative
		_pan_screen(delta * 0.04)
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_active_touches[t.index] = t.position
		else:
			_active_touches.erase(t.index)
		if _active_touches.size() == 2:
			var positions: Array = _active_touches.values()
			_pinch_last_distance = (positions[0] as Vector2).distance_to(positions[1] as Vector2)
		else:
			_pinch_last_distance = 0.0
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_active_touches[d.index] = d.position
		if _active_touches.size() == 1:
			_pan_screen(d.relative * 0.05)
		elif _active_touches.size() == 2:
			var positions: Array = _active_touches.values()
			var dist := (positions[0] as Vector2).distance_to(positions[1] as Vector2)
			if _pinch_last_distance > 0.0:
				var diff := dist - _pinch_last_distance
				zoom_by(-diff * 0.06)
			_pinch_last_distance = dist


func zoom_by(amount: float) -> void:
	_target_zoom = clamp(_target_zoom + amount, min_zoom, max_zoom)


func zoom_to(value: float) -> void:
	_target_zoom = clamp(value, min_zoom, max_zoom)


func get_zoom() -> float:
	return _current_zoom


func _apply_zoom(snap: bool = false) -> void:
	if snap:
		_current_zoom = _target_zoom
	# Position camera back & up along its forward axis at angle look_angle_deg.
	var rad := deg_to_rad(look_angle_deg)
	var horizontal := cos(rad) * _current_zoom
	var vertical := sin(rad) * _current_zoom
	camera.position = Vector3(0, vertical, horizontal)
	camera.look_at(global_position, Vector3.UP)


func _pan_pivot(world_offset: Vector2) -> void:
	var p := position
	p.x = clamp(p.x + world_offset.x, -pivot_bounds.x, pivot_bounds.x)
	p.z = clamp(p.z + world_offset.y, -pivot_bounds.y, pivot_bounds.y)
	position = p


func _pan_screen(screen_delta: Vector2) -> void:
	# Convert screen-space delta to world-space pan, scaled by zoom level.
	var scale := _current_zoom * 0.1
	_pan_pivot(Vector2(-screen_delta.x, -screen_delta.y) * scale)


## Project a screen position onto the world ground plane (y=0).
func ground_point_from_screen(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return null
	var t := -origin.y / direction.y
	if t < 0:
		return null
	return origin + direction * t
