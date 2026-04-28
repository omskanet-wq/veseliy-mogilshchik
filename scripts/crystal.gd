extends Node3D
class_name CrystalPickup
## A pickable crystal. Spins idly and emits "picked" when collected.

signal picked

var _t: float = 0.0


func _ready() -> void:
	ProcGen.build_crystal(self)


func _process(delta: float) -> void:
	_t += delta
	rotation.y = _t * 1.5
	# Hover animation.
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).position.y = 0.16 + sin(_t * 3.0) * 0.06


func pickup() -> void:
	if not is_inside_tree():
		return
	picked.emit()
	queue_free()


func contains_point(world_xz: Vector2, radius: float = 0.5) -> bool:
	var here := Vector2(global_position.x, global_position.z)
	return here.distance_to(world_xz) <= radius
