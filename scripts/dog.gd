extends Node3D
class_name Dog
## The gravedigger's dog — wanders the cemetery and digs up crystals.
##
## Behaviour:
##   1. Pick a random EMPTY cell.
##   2. Walk to it.
##   3. Sniff for ~1 second.
##   4. Roll dice — chance to spawn a Crystal at that cell.
##   5. Repeat.

signal crystal_found(world_position: Vector3)

@export var move_speed: float = 3.0
@export var crystal_spawn_chance: float = 0.35

var grid: Grid
var _state: String = "idle" # idle | walking | sniffing
var _target_cell: Cell = null
var _target: Vector3 = Vector3.ZERO
var _sniff_timer: float = 0.0
var _tail: MeshInstance3D
var _tail_phase: float = 0.0


func _ready() -> void:
	ProcGen.build_dog(self)
	_tail = find_child("Tail", false, false) as MeshInstance3D


func setup(g: Grid) -> void:
	grid = g
	_pick_new_target()


func _process(delta: float) -> void:
	# Tail wag, faster when sniffing.
	if _tail:
		var freq: float = 7.0 if _state == "sniffing" else 3.5
		_tail_phase += delta * freq
		_tail.rotation.y = sin(_tail_phase) * 0.55
	match _state:
		"walking":
			var to := _target - global_position
			to.y = 0
			if to.length() < 0.1:
				_state = "sniffing"
				_sniff_timer = 1.2
				return
			var step := to.normalized() * move_speed * delta
			if step.length() > to.length():
				step = to
			global_position += step
			rotation.y = atan2(step.x, step.z)
		"sniffing":
			_sniff_timer -= delta
			# Bobbing animation (head down sniff).
			position.y = abs(sin(_sniff_timer * 6.0)) * 0.06
			if _sniff_timer <= 0.0:
				if randf() < crystal_spawn_chance and _target_cell != null:
					crystal_found.emit(_target_cell.global_position)
				_pick_new_target()


func _pick_new_target() -> void:
	if grid == null:
		_state = "idle"
		return
	var cell := grid.random_empty_cell()
	if cell == null:
		_state = "idle"
		return
	_target_cell = cell
	_target = cell.global_position
	_state = "walking"
	position.y = 0.0
