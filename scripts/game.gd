extends Node3D
class_name Game
## Main world controller. Builds the cemetery, camera, player, dog and routes
## input from the HUD into the grid.

signal log_message(text: String)

const DAILY_UPKEEP: int = 30
const PATH_BONUS_PER_TILE: int = 5
const PATH_COST: int = 20

const TOOL_NONE := "none"
const TOOL_ASSIGN := "assign"
const TOOL_DIG := "dig"
const TOOL_TOMBSTONE_0 := "tomb0"
const TOOL_TOMBSTONE_1 := "tomb1"
const TOOL_TOMBSTONE_2 := "tomb2"
const TOOL_FLOWERS := "flowers"
const TOOL_NAME := "name"
const TOOL_PATH := "path"
const TOOL_DEMOLISH := "demolish"

const TOMBSTONE_COSTS := {
	0: 80,
	1: 180,
	2: 350,
}
const FLOWER_COST := 40

@export var grid_dimensions: Vector2i = Vector2i(14, 10)

@onready var camera_rig: CameraRig = $CameraRig
@onready var grid: Grid = $Grid
@onready var player: Player = $Player
@onready var dog: Dog = $Dog
@onready var environment: WorldEnvironment = $WorldEnvironment

signal tool_changed(tool_id: String)
signal hint_message(text: String)

var current_tool: String = TOOL_NONE
var pending_assign_order_id: int = 0
var pending_name_for_cell: Cell = null
var crystals_in_world: Array[CrystalPickup] = []
var _last_hover_screen_pos: Vector2 = Vector2.ZERO
var _hover_active: bool = false


func _ready() -> void:
	# Build environment programmatically.
	_build_environment()
	# Configure grid.
	grid.grid_size = grid_dimensions
	# After Grid built, set dog target source.
	dog.setup(grid)
	dog.crystal_found.connect(_on_dog_crystal_found)
	# Connect global signals.
	OrderManager.order_offered.connect(_on_order_offered)
	OrderManager.order_accepted.connect(_on_order_accepted)
	OrderManager.order_completed.connect(_on_order_completed)
	OrderManager.order_failed.connect(_on_order_failed)
	TimeManager.day_changed.connect(_on_day_changed_refresh_labels)
	# Place player and dog at sensible visible spots.
	var player_cell: Cell = grid.cell_at(Vector2i(grid_dimensions.x / 2, grid_dimensions.y - 1))
	if player_cell:
		player.global_position = player_cell.global_position + Vector3(0, 0, 1.6)
	dog.position = Vector3(-grid_dimensions.x * Cell.CELL_SIZE * 0.25, 0, grid_dimensions.y * Cell.CELL_SIZE * 0.25)


func _build_environment() -> void:
	# Grass arena (slightly larger than grid) to hide the seam.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	ground.material_override = ProcGen.make_material(Color(0.32, 0.45, 0.25))
	ground.position.y = -0.05
	add_child(ground)

	# Stone wall border around the cemetery.
	var bx := grid_dimensions.x * Cell.CELL_SIZE * 0.5 + 1.2
	var by := grid_dimensions.y * Cell.CELL_SIZE * 0.5 + 1.2
	for side in [Vector3(0, 0, by), Vector3(0, 0, -by)]:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(bx * 2.0, 0.6, 0.18)
		wall.mesh = bm
		wall.material_override = ProcGen.make_material(Color(0.50, 0.48, 0.45))
		wall.position = side + Vector3(0, 0.30, 0)
		add_child(wall)
	for side in [Vector3(bx, 0, 0), Vector3(-bx, 0, 0)]:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.6, by * 2.0)
		wall.mesh = bm
		wall.material_override = ProcGen.make_material(Color(0.50, 0.48, 0.45))
		wall.position = side + Vector3(0, 0.30, 0)
		add_child(wall)

	# A simple gate marker.
	var gate := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.0, 1.4, 0.15)
	gate.mesh = gm
	gate.material_override = ProcGen.make_material(Color(0.38, 0.26, 0.18))
	gate.position = Vector3(0, 0.7, by + 0.05)
	add_child(gate)

	# Some scattered "trees" via cylinders + spheres.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 18:
		var tx := rng.randf_range(-bx - 6.0, bx + 6.0)
		var tz := rng.randf_range(-by - 6.0, by + 6.0)
		# Skip if inside grid bounds.
		if absf(tx) < bx + 0.5 and absf(tz) < by + 0.5:
			continue
		var trunk := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.22
		cm.height = 1.4
		trunk.mesh = cm
		trunk.material_override = ProcGen.make_material(Color(0.32, 0.20, 0.10))
		trunk.position = Vector3(tx, 0.7, tz)
		add_child(trunk)
		var leaves := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.7, 1.1)
		sm.height = sm.radius * 2.0
		leaves.mesh = sm
		leaves.material_override = ProcGen.make_material(Color(0.18, 0.42, 0.20))
		leaves.position = Vector3(tx, 1.6, tz)
		add_child(leaves)


# ---------- Input plumbing from HUD ----------

func set_tool(tool_id: String) -> void:
	current_tool = tool_id
	tool_changed.emit(tool_id)

func clear_tool() -> void:
	set_tool(TOOL_NONE)


func update_hover_from_screen(screen_pos: Vector2, active: bool) -> void:
	_last_hover_screen_pos = screen_pos
	_hover_active = active
	if not active or current_tool == TOOL_NONE:
		grid.clear_hovered()
		return
	var ground: Variant = camera_rig.ground_point_from_screen(screen_pos)
	if ground == null:
		grid.clear_hovered()
		return
	var world: Vector3 = ground
	var cell := grid.cell_from_world(world)
	if cell == null:
		grid.clear_hovered()
		return
	grid.set_hovered(cell)


func handle_world_click(screen_pos: Vector2) -> void:
	var ground: Variant = camera_rig.ground_point_from_screen(screen_pos)
	if ground == null:
		return
	var world: Vector3 = ground
	# First, see if a crystal was tapped (in priority).
	var click_xz := Vector2(world.x, world.z)
	for c in crystals_in_world.duplicate():
		if c == null or not is_instance_valid(c):
			continue
		if c.contains_point(click_xz, 0.6):
			c.pickup()
			Economy.add_crystals(1)
			log_message.emit("Собака нашла кристалл! +1 кристалл")
			return
	var cell := grid.cell_from_world(world)
	if cell == null:
		return
	_apply_tool_to_cell(cell)


func _apply_tool_to_cell(cell: Cell) -> void:
	match current_tool:
		TOOL_ASSIGN:
			_try_assign(cell)
		TOOL_DIG:
			_try_dig(cell)
		TOOL_TOMBSTONE_0, TOOL_TOMBSTONE_1, TOOL_TOMBSTONE_2:
			var style := int(current_tool.right(1))
			_try_place_tombstone(cell, style)
		TOOL_FLOWERS:
			_try_place_flowers(cell)
		TOOL_NAME:
			_try_open_name(cell)
		TOOL_PATH:
			_try_place_path(cell)
		TOOL_DEMOLISH:
			_try_demolish(cell)
		_:
			# No tool selected — show info via log.
			_describe_cell(cell)


func _try_assign(cell: Cell) -> void:
	if pending_assign_order_id == 0:
		log_message.emit("Сначала выбери заказ из списка справа.")
		return
	if cell.state != Cell.State.EMPTY:
		log_message.emit("Можно занять только свободное место.")
		return
	if not OrderManager.accept_order(pending_assign_order_id, cell):
		log_message.emit("Заказ уже неактуален.")
		pending_assign_order_id = 0
		set_tool(TOOL_NONE)
		return
	cell.order_id = pending_assign_order_id
	cell.set_state(Cell.State.ASSIGNED)
	pending_assign_order_id = 0
	# Auto-progress: walk over and dig the grave straight away.
	set_tool(TOOL_DIG)
	log_message.emit("Место отведено. Мистер Юпитер идёт копать.")
	_try_dig(cell)


func _try_dig(cell: Cell) -> void:
	if cell.state != Cell.State.ASSIGNED:
		log_message.emit("Копать можно только на отведённом месте.")
		return
	player.walk_to_cell(cell)
	await player.arrived
	cell.set_state(Cell.State.DUG)
	log_message.emit("Могила выкопана. Теперь выбери надгробие.")
	hint_message.emit("Выбери надгробие на панели ниже")


func _try_place_tombstone(cell: Cell, style: int) -> void:
	if cell.state != Cell.State.DUG and cell.state != Cell.State.GRAVE:
		log_message.emit("Надгробие ставится на выкопанную могилу.")
		return
	var cost: int = TOMBSTONE_COSTS[style]
	if cell.tombstone_style >= 0:
		cell.decoration_cost -= TOMBSTONE_COSTS[cell.tombstone_style]
		Economy.add_money(int(TOMBSTONE_COSTS[cell.tombstone_style] * 0.5), "Возврат за надгробие")
	if not Economy.spend(cost, "Надгробие"):
		log_message.emit("Недостаточно денег.")
		return
	cell.tombstone_style = style
	cell.decoration_cost += cost
	cell.set_state(Cell.State.GRAVE)
	# Auto-progress hint towards engraving the name.
	if cell.engraved_name.is_empty():
		set_tool(TOOL_NAME)
		hint_message.emit("Надгробие выбрано. Кликни по могиле и выбей имя на нёй.")


func _try_place_flowers(cell: Cell) -> void:
	if cell.state != Cell.State.DUG and cell.state != Cell.State.GRAVE:
		log_message.emit("Цветы только на могиле.")
		return
	if cell.has_flowers:
		log_message.emit("Цветы уже стоят.")
		return
	if not Economy.spend(FLOWER_COST, "Цветы"):
		log_message.emit("Недостаточно денег на цветы.")
		return
	cell.has_flowers = true
	cell.decoration_cost += FLOWER_COST
	cell.set_state(cell.state if cell.state == Cell.State.GRAVE else Cell.State.GRAVE)


func _try_open_name(cell: Cell) -> void:
	if cell.state != Cell.State.GRAVE:
		log_message.emit("Сначала установи надгробие.")
		return
	if cell.tombstone_style < 0:
		log_message.emit("Без надгробия имя не выбьешь.")
		return
	pending_name_for_cell = cell
	$"/root/Main".open_name_dialog(cell)


func confirm_name(cell: Cell, name_text: String) -> void:
	cell.engraved_name = name_text
	cell.set_state(Cell.State.COMPLETED)
	var order_id: int = cell.order_id
	if order_id > 0:
		var result: Dictionary = OrderManager.try_complete_order(order_id, cell.decoration_cost)
		if result["success"]:
			log_message.emit("Заказ выполнен! +%d ₽ прибыли" % int(result["profit"]))
		else:
			log_message.emit("Заказ провален: %s" % result["reason"])
	else:
		log_message.emit("Имя выбито.")


func _try_place_path(cell: Cell) -> void:
	if cell.state != Cell.State.EMPTY:
		log_message.emit("Дорожку можно класть только на пустые клетки.")
		return
	if not Economy.spend(PATH_COST, "Дорожка"):
		log_message.emit("Недостаточно денег на дорожку.")
		return
	cell.set_state(Cell.State.PATH)


func _try_demolish(cell: Cell) -> void:
	if cell.state == Cell.State.COMPLETED:
		log_message.emit("Завершённую могилу нельзя сносить.")
		return
	if cell.state == Cell.State.EMPTY:
		return
	cell.clear_cell()
	log_message.emit("Клетка очищена.")


func _describe_cell(cell: Cell) -> void:
	var s := ""
	match cell.state:
		Cell.State.EMPTY: s = "Пустая клетка"
		Cell.State.ASSIGNED: s = "Отведено под заказ"
		Cell.State.DUG: s = "Выкопанная могила"
		Cell.State.GRAVE: s = "Декорированная могила (₽%d)" % cell.decoration_cost
		Cell.State.COMPLETED: s = "Завершённая могила: %s" % cell.engraved_name
		Cell.State.PATH: s = "Дорожка"
	log_message.emit(s)


# ---------- Order signals ----------

func _on_order_offered(order: Dictionary) -> void:
	log_message.emit("Новый заказ: %s, бюджет %s." % [order["deceased_short"], format_money(order["budget"])])


func _on_order_accepted(_order: Dictionary) -> void:
	pass


func _on_order_completed(order: Dictionary, profit: int) -> void:
	log_message.emit("Заказ %s выполнен. Прибыль: %s." % [order["deceased_short"], format_money(profit)])


func _on_order_failed(order: Dictionary, reason: String) -> void:
	log_message.emit("Заказ %s провален: %s" % [order["deceased_short"], reason])


func _on_day_changed_refresh_labels(_day: int) -> void:
	for row in grid.cells:
		for cell in row:
			if cell != null:
				(cell as Cell).refresh_order_label()


# ---------- Day cycle ----------

func advance_day() -> void:
	# Daily upkeep.
	var upkeep_paid: int = 0
	if Economy.money >= DAILY_UPKEEP:
		Economy.spend(DAILY_UPKEEP, "Расходы дня")
		upkeep_paid = DAILY_UPKEEP
	else:
		upkeep_paid = Economy.money
		Economy.spend(Economy.money, "Расходы дня")
		log_message.emit("Не хватило денег на содержание!")
	# Path bonus per tile adjacent to completed graves.
	var bonus: int = grid.count_paths_adjacent_to_completed() * PATH_BONUS_PER_TILE
	if bonus > 0:
		Economy.add_money(bonus, "Доход с дорожек")
	TimeManager.advance_day()
	var parts: Array[String] = []
	parts.append("День %d. Расходы: %s" % [TimeManager.current_day, format_money(upkeep_paid)])
	if bonus > 0:
		parts.append("Дорожки: +%s" % format_money(bonus))
	log_message.emit("   ·   ".join(parts))


# ---------- Crystals ----------

func _on_dog_crystal_found(world_position: Vector3) -> void:
	var crystal: CrystalPickup = preload("res://scripts/crystal.gd").new()
	crystal.global_position = world_position + Vector3(0, 0, 0)
	add_child(crystal)
	crystals_in_world.append(crystal)
	crystal.tree_exited.connect(func() -> void: crystals_in_world.erase(crystal))
	log_message.emit("Собака что-то нашла!")


static func format_money(value: int) -> String:
	var abs_val := absi(value)
	var s := str(abs_val)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "\u202f" + out
			count = 0
	if value < 0:
		out = "-" + out
	return out + " ₽"


# ---------- Order acceptance flow ----------

func start_assign_for_order(order_id: int) -> void:
	pending_assign_order_id = order_id
	current_tool = TOOL_ASSIGN
	log_message.emit("Кликни на свободную клетку, чтобы отвести место.")
