extends Node3D
class_name Cell
## A single cemetery plot. Holds state, cost, and renders its visuals on demand.

enum State {
	EMPTY,    # grass, free
	ASSIGNED, # reserved for an active order (player must dig)
	DUG,      # hole, ready for decoration
	GRAVE,    # has tombstone (and maybe flowers); decoration_cost > 0
	COMPLETED,# order finalized, name engraved (immutable)
	PATH,     # path tile
}

const CELL_SIZE: float = 1.4

signal state_changed(cell: Cell)

var coord: Vector2i
var state: int = State.EMPTY
var order_id: int = 0
var tombstone_style: int = -1
var has_flowers: bool = false
var path_tile: bool = false
var decoration_cost: int = 0
var engraved_name: String = ""

var _ground: MeshInstance3D
var _decor_root: Node3D
var _name_label: Label3D
var _highlight: MeshInstance3D
var _order_label: Label3D


func _ready() -> void:
	_decor_root = Node3D.new()
	add_child(_decor_root)
	_build_ground()
	_build_highlight()


func _build_ground() -> void:
	_ground = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE * 0.96, 0.05, CELL_SIZE * 0.96)
	_ground.mesh = mesh
	_ground.material_override = ProcGen.make_material(ProcGen.COLOR_GRASS)
	_ground.position.y = -0.025
	add_child(_ground)


func _build_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL_SIZE * 0.96, CELL_SIZE * 0.96)
	_highlight.mesh = pm
	var mat := ProcGen.tinted_material(Color(1, 1, 0.45), 1.5)
	mat.albedo_color = Color(1, 1, 0.4, 0.40)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = mat
	_highlight.position.y = 0.04
	_highlight.visible = false
	add_child(_highlight)


func set_highlighted(on: bool, color: Color = Color(1, 1, 0.4)) -> void:
	_highlight.visible = on
	if on:
		var mat: StandardMaterial3D = _highlight.material_override
		mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
		mat.emission = color
		mat.emission_energy_multiplier = 1.4


func set_state(new_state: int) -> void:
	state = new_state
	_refresh_visuals()
	state_changed.emit(self)


func _clear_decor() -> void:
	for child in _decor_root.get_children():
		child.queue_free()
	_name_label = null
	_order_label = null


func _refresh_visuals() -> void:
	_clear_decor()
	match state:
		State.EMPTY:
			_set_ground_color(ProcGen.COLOR_GRASS)
		State.ASSIGNED:
			_set_ground_color(ProcGen.COLOR_GRASS_DARK)
			_build_marker(Color(0.95, 0.85, 0.2))
			_build_order_label()
		State.DUG:
			_set_ground_color(ProcGen.COLOR_DIRT_DARK)
			_build_pit()
			_build_order_label()
		State.GRAVE:
			_set_ground_color(ProcGen.COLOR_DIRT)
			_build_mound()
			if tombstone_style >= 0:
				ProcGen.build_tombstone(_decor_root, tombstone_style, _color_for_style(tombstone_style))
			if has_flowers:
				_add_flowers()
			_build_order_label()
		State.COMPLETED:
			_set_ground_color(ProcGen.COLOR_DIRT)
			_build_mound()
			if tombstone_style >= 0:
				ProcGen.build_tombstone(_decor_root, tombstone_style, _color_for_style(tombstone_style))
			if has_flowers:
				_add_flowers()
			if not engraved_name.is_empty():
				_add_name_label()
		State.PATH:
			_set_ground_color(ProcGen.COLOR_PATH)


func _set_ground_color(color: Color) -> void:
	var mat := _ground.material_override as StandardMaterial3D
	mat.albedo_color = color


func _build_marker(color: Color) -> void:
	var marker := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.0
	pm.bottom_radius = 0.18
	pm.height = 0.6
	marker.mesh = pm
	marker.material_override = ProcGen.tinted_material(color, 0.8)
	marker.position.y = 0.30
	_decor_root.add_child(marker)


func _build_pit() -> void:
	var pit := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL_SIZE * 0.8, 0.4, CELL_SIZE * 0.5)
	pit.mesh = bm
	pit.material_override = ProcGen.make_material(Color(0.10, 0.07, 0.04))
	pit.position.y = -0.18
	_decor_root.add_child(pit)


func _build_mound() -> void:
	var mound := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL_SIZE * 0.78, 0.18, CELL_SIZE * 0.55)
	mound.mesh = bm
	mound.material_override = ProcGen.make_material(ProcGen.COLOR_DIRT)
	mound.position = Vector3(0, 0.05, 0.15)
	_decor_root.add_child(mound)


func _color_for_style(style: int) -> Color:
	match style:
		0: return ProcGen.COLOR_STONE
		1: return Color(0.55, 0.40, 0.25)
		2: return Color(0.30, 0.30, 0.32)
	return ProcGen.COLOR_STONE


func _add_flowers() -> void:
	var palette := [
		Color(0.95, 0.30, 0.50),
		Color(0.95, 0.85, 0.30),
		Color(0.40, 0.50, 0.95),
		Color(0.95, 0.55, 0.20),
	]
	for i in 3:
		var f := Node3D.new()
		ProcGen.build_flower(f, palette[i % palette.size()])
		f.position = Vector3(-0.30 + i * 0.30, 0.08, 0.45)
		_decor_root.add_child(f)


func _add_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.text = engraved_name
	_name_label.font_size = 24
	_name_label.outline_size = 4
	_name_label.modulate = Color(0.05, 0.05, 0.05)
	_name_label.outline_modulate = Color(0.95, 0.95, 0.92)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 0.65, -0.2)
	_name_label.pixel_size = 0.005
	_decor_root.add_child(_name_label)


func refresh_order_label() -> void:
	if _order_label:
		_order_label.queue_free()
		_order_label = null
	if state in [State.ASSIGNED, State.DUG, State.GRAVE]:
		_build_order_label()


func _build_order_label() -> void:
	if order_id <= 0:
		return
	var order: Dictionary = OrderManager.get_order_for_cell(self)
	if order.is_empty():
		return
	var days_left: int = order["deadline_day"] - TimeManager.current_day
	var txt := "%s\nдо дня %d" % [order["deceased_short"], order["deadline_day"]]
	if days_left <= 0:
		txt += "  !"
	_order_label = Label3D.new()
	_order_label.text = txt
	_order_label.font_size = 18
	_order_label.outline_size = 6
	_order_label.modulate = Color(1, 0.95, 0.65) if days_left > 1 else Color(1, 0.55, 0.45)
	_order_label.outline_modulate = Color(0, 0, 0, 0.85)
	_order_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_order_label.no_depth_test = true
	_order_label.position = Vector3(0, 1.15, 0)
	_order_label.pixel_size = 0.0045
	_decor_root.add_child(_order_label)


## Reset cell to EMPTY (used by demolish).
func clear_cell() -> void:
	state = State.EMPTY
	order_id = 0
	tombstone_style = -1
	has_flowers = false
	path_tile = false
	decoration_cost = 0
	engraved_name = ""
	_refresh_visuals()
	state_changed.emit(self)
