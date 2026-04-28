extends Node3D
class_name Player
## Mr Jupiter — the gravedigger. Walks toward a target cell and emits "arrived"
## when close enough.

signal arrived(cell: Cell)

@export var move_speed: float = 4.5

var _target: Vector3 = Vector3.ZERO
var _target_cell: Cell = null
var _is_moving: bool = false


func _ready() -> void:
	ProcGen.build_player(self)


func _process(delta: float) -> void:
	if not _is_moving:
		return
	var to := _target - global_position
	to.y = 0
	if to.length() < 0.05:
		_is_moving = false
		if _target_cell:
			arrived.emit(_target_cell)
		return
	var step := to.normalized() * move_speed * delta
	if step.length() > to.length():
		step = to
	global_position += step
	# Face direction.
	if step.length_squared() > 0.0001:
		var look_target := global_position + Vector3(step.x, 0, step.z)
		look_at(look_target, Vector3.UP)


func walk_to_cell(cell: Cell) -> void:
	_target_cell = cell
	_target = cell.global_position
	_is_moving = true


func is_busy() -> bool:
	return _is_moving
