extends Node3D
class_name CrystalPickup
## A pickable crystal. Spins idly and emits "picked" when collected.

signal picked

var _t: float = 0.0
var _crystal: MeshInstance3D
var _halo: MeshInstance3D


func _ready() -> void:
	ProcGen.build_crystal(self)
	_crystal = find_child("Crystal", false, false) as MeshInstance3D
	_halo = find_child("Halo", false, false) as MeshInstance3D


func _process(delta: float) -> void:
	_t += delta
	rotation.y = _t * 1.5
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	if _crystal:
		_crystal.position.y = 0.18 + sin(_t * 3.2) * 0.07
		var mat: StandardMaterial3D = _crystal.material_override
		if mat:
			mat.emission_energy_multiplier = 0.6 + pulse * 1.4
	if _halo:
		_halo.scale = Vector3.ONE * (0.85 + pulse * 0.45)
		var hmat: StandardMaterial3D = _halo.material_override
		if hmat:
			hmat.albedo_color.a = 0.25 + pulse * 0.45


func pickup() -> void:
	if not is_inside_tree():
		return
	picked.emit()
	queue_free()


func contains_point(world_xz: Vector2, radius: float = 0.5) -> bool:
	var here := Vector2(global_position.x, global_position.z)
	return here.distance_to(world_xz) <= radius
