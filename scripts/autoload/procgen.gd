extends Node
## ProcGen — procedural mesh + material helpers so the game ships without art assets.

const COLOR_GRASS := Color(0.36, 0.55, 0.28)
const COLOR_GRASS_DARK := Color(0.28, 0.42, 0.22)
const COLOR_DIRT := Color(0.34, 0.22, 0.13)
const COLOR_DIRT_DARK := Color(0.20, 0.13, 0.07)
const COLOR_STONE := Color(0.62, 0.62, 0.66)
const COLOR_STONE_DARK := Color(0.40, 0.40, 0.42)
const COLOR_FLOWER := Color(0.95, 0.30, 0.50)
const COLOR_LEAF := Color(0.20, 0.55, 0.25)
const COLOR_PATH := Color(0.55, 0.50, 0.42)
const COLOR_SKIN := Color(0.94, 0.78, 0.62)
const COLOR_COAT := Color(0.18, 0.16, 0.20)
const COLOR_DOG := Color(0.55, 0.36, 0.20)
const COLOR_DOG_BELLY := Color(0.78, 0.62, 0.45)
const COLOR_CRYSTAL := Color(0.55, 0.85, 0.95)


func make_material(color: Color, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func tinted_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := make_material(color)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Build a simple "Mr Jupiter" model — capsule body, sphere head, top hat.
func build_player(parent: Node3D) -> void:
	var skin_mat := make_material(COLOR_SKIN)
	var coat_mat := make_material(COLOR_COAT)
	var hat_mat := make_material(Color(0.05, 0.05, 0.05))

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 0.9
	body.mesh = capsule
	body.material_override = coat_mat
	body.position.y = 0.55
	parent.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	head.mesh = sphere
	head.material_override = skin_mat
	head.position.y = 1.15
	parent.add_child(head)

	var hat_brim := MeshInstance3D.new()
	var brim := CylinderMesh.new()
	brim.top_radius = 0.30
	brim.bottom_radius = 0.30
	brim.height = 0.04
	hat_brim.mesh = brim
	hat_brim.material_override = hat_mat
	hat_brim.position.y = 1.31
	parent.add_child(hat_brim)

	var hat_top := MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.18
	top.bottom_radius = 0.18
	top.height = 0.30
	hat_top.mesh = top
	hat_top.material_override = hat_mat
	hat_top.position.y = 1.48
	parent.add_child(hat_top)

	# Shovel pivot — children rotate together for the digging animation.
	var shovel := Node3D.new()
	shovel.name = "ShovelPivot"
	shovel.position = Vector3(0.0, 0.95, 0.0)
	parent.add_child(shovel)
	var shovel_handle := MeshInstance3D.new()
	var sh := CylinderMesh.new()
	sh.top_radius = 0.025
	sh.bottom_radius = 0.025
	sh.height = 0.9
	shovel_handle.mesh = sh
	shovel_handle.material_override = make_material(Color(0.55, 0.36, 0.18))
	shovel_handle.position = Vector3(0.28, 0.0, -0.05)
	shovel_handle.rotation_degrees = Vector3(0, 0, -25)
	shovel.add_child(shovel_handle)
	var shovel_blade := MeshInstance3D.new()
	var bl := BoxMesh.new()
	bl.size = Vector3(0.18, 0.22, 0.03)
	shovel_blade.mesh = bl
	shovel_blade.material_override = make_material(Color(0.7, 0.7, 0.72), 0.6, 0.4)
	shovel_blade.position = Vector3(0.46, -0.35, -0.05)
	shovel_blade.rotation_degrees = Vector3(0, 0, -25)
	shovel.add_child(shovel_blade)


## Build a simple dog model.
func build_dog(parent: Node3D) -> void:
	var fur := make_material(COLOR_DOG)
	var belly := make_material(COLOR_DOG_BELLY)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.28, 0.22)
	body.mesh = box
	body.material_override = fur
	body.position.y = 0.28
	parent.add_child(body)

	var head := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(0.22, 0.22, 0.22)
	head.mesh = hbox
	head.material_override = fur
	head.position = Vector3(0.32, 0.36, 0)
	parent.add_child(head)

	var snout := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(0.12, 0.10, 0.14)
	snout.mesh = sbox
	snout.material_override = belly
	snout.position = Vector3(0.46, 0.32, 0)
	parent.add_child(snout)

	# 4 legs.
	for x in [-0.18, 0.18]:
		for z in [-0.08, 0.08]:
			var leg := MeshInstance3D.new()
			var lbox := BoxMesh.new()
			lbox.size = Vector3(0.08, 0.22, 0.08)
			leg.mesh = lbox
			leg.material_override = fur
			leg.position = Vector3(x, 0.11, z)
			parent.add_child(leg)

	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var tbox := BoxMesh.new()
	tbox.size = Vector3(0.16, 0.06, 0.06)
	tail.mesh = tbox
	tail.material_override = fur
	tail.position = Vector3(-0.32, 0.34, 0)
	tail.rotation_degrees = Vector3(0, 0, 25)
	parent.add_child(tail)


## Build a tombstone of given style index.
func build_tombstone(parent: Node3D, style: int = 0, color: Color = COLOR_STONE) -> void:
	var mat := make_material(color)
	var dark := make_material(color.darkened(0.25))
	match style:
		0:
			# Classic round-top slab.
			var slab := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.7, 0.12)
			slab.mesh = bm
			slab.material_override = mat
			slab.position = Vector3(0, 0.45, -0.2)
			parent.add_child(slab)
			var top := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.30
			cyl.bottom_radius = 0.30
			cyl.height = 0.12
			top.mesh = cyl
			top.material_override = mat
			top.position = Vector3(0, 0.80, -0.2)
			top.rotation_degrees = Vector3(90, 0, 0)
			parent.add_child(top)
		1:
			# Cross.
			var vert := MeshInstance3D.new()
			var vm := BoxMesh.new()
			vm.size = Vector3(0.12, 0.95, 0.12)
			vert.mesh = vm
			vert.material_override = mat
			vert.position = Vector3(0, 0.55, -0.2)
			parent.add_child(vert)
			var horiz := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.45, 0.12, 0.12)
			horiz.mesh = hm
			horiz.material_override = mat
			horiz.position = Vector3(0, 0.75, -0.2)
			parent.add_child(horiz)
		2:
			# Obelisk.
			var base := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.5, 0.18, 0.5)
			base.mesh = bb
			base.material_override = dark
			base.position = Vector3(0, 0.10, -0.2)
			parent.add_child(base)
			var col := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.25, 0.85, 0.25)
			col.mesh = cm
			col.material_override = mat
			col.position = Vector3(0, 0.60, -0.2)
			parent.add_child(col)
			var cap := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.30, 0.20, 0.30)
			cap.mesh = pm
			cap.material_override = mat
			cap.position = Vector3(0, 1.10, -0.2)
			parent.add_child(cap)
		_:
			pass


## Build a small flower decoration.
func build_flower(parent: Node3D, color: Color = COLOR_FLOWER) -> void:
	var stem_mat := make_material(COLOR_LEAF)
	var petal_mat := make_material(color)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.02
	sm.bottom_radius = 0.02
	sm.height = 0.18
	stem.mesh = sm
	stem.material_override = stem_mat
	stem.position.y = 0.09
	parent.add_child(stem)
	var bud := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.14
	bud.mesh = bm
	bud.material_override = petal_mat
	bud.position.y = 0.22
	parent.add_child(bud)


## Build a single crystal with a halo glow plate underneath.
func build_crystal(parent: Node3D) -> void:
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	halo.mesh = qm
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(COLOR_CRYSTAL.r, COLOR_CRYSTAL.g, COLOR_CRYSTAL.b, 0.55)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true
	halo_mat.emission = COLOR_CRYSTAL
	halo_mat.emission_energy_multiplier = 1.4
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo.material_override = halo_mat
	halo.rotation_degrees = Vector3(-90, 0, 0)
	halo.position.y = 0.05
	parent.add_child(halo)
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var pm := PrismMesh.new()
	pm.size = Vector3(0.18, 0.32, 0.18)
	crystal.mesh = pm
	var mat := tinted_material(COLOR_CRYSTAL, 0.6)
	mat.metallic = 0.4
	mat.roughness = 0.2
	crystal.material_override = mat
	crystal.position.y = 0.16
	parent.add_child(crystal)
