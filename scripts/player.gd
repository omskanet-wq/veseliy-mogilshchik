extends Node3D
class_name Player
## Mr Jupiter — the gravedigger. Walks toward a target cell and emits "arrived"
## when close enough.

signal arrived(cell: Cell)

@export var move_speed: float = 4.5
@export var dig_duration: float = 1.2

var _target: Vector3 = Vector3.ZERO
var _target_cell: Cell = null
var _is_moving: bool = false
var _shovel_pivot: Node3D
var _dig_timer: float = 0.0
var _walk_phase: float = 0.0


func _ready() -> void:
	ProcGen.build_player(self)
	_shovel_pivot = find_child("ShovelPivot", false, false) as Node3D


func _process(delta: float) -> void:
	if _is_moving:
		var to := _target - global_position
		to.y = 0
		if to.length() < 0.05:
			_is_moving = false
			_dig_timer = dig_duration
		else:
			var step := to.normalized() * move_speed * delta
			if step.length() > to.length():
				step = to
			global_position += step
			# Face direction.
			if step.length_squared() > 0.0001:
				var look_target := global_position + Vector3(step.x, 0, step.z)
				look_at(look_target, Vector3.UP)
			# Walk bob.
			_walk_phase += delta * 10.0
			position.y = abs(sin(_walk_phase)) * 0.04
	elif _dig_timer > 0.0:
		_dig_timer -= delta
		if _shovel_pivot:
			# Sway the shovel back-and-forth ~120deg as if scooping dirt.
			var t := dig_duration - _dig_timer
			_shovel_pivot.rotation.x = sin(t * 9.0) * 0.9
		if _dig_timer <= 0.0:
			if _shovel_pivot:
				_shovel_pivot.rotation = Vector3.ZERO
			if _target_cell:
				arrived.emit(_target_cell)
				_target_cell = null
	else:
		# Idle bob.
		position.y = lerp(position.y, 0.0, delta * 6.0)


func walk_to_cell(cell: Cell) -> void:
	_target_cell = cell
	_target = cell.global_position
	_is_moving = true


func is_busy() -> bool:
	return _is_moving or _dig_timer > 0.0
