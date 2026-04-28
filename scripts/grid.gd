extends Node3D
class_name Grid
## The cemetery grid. Spawns a NxN array of Cell nodes and exposes lookup helpers.

@export var grid_size: Vector2i = Vector2i(14, 10)

signal cell_clicked(cell: Cell)

var cells: Array = [] # Array[Array[Cell]]
var _hovered: Cell = null


func _ready() -> void:
	_build_grid()


func _build_grid() -> void:
	cells.clear()
	for x in grid_size.x:
		var row: Array = []
		for y in grid_size.y:
			var cell: Cell = preload("res://scripts/cell.gd").new()
			cell.coord = Vector2i(x, y)
			cell.position = _grid_to_world(x, y)
			add_child(cell)
			row.append(cell)
		cells.append(row)


func _grid_to_world(x: int, y: int) -> Vector3:
	var ox := -float(grid_size.x - 1) * 0.5 * Cell.CELL_SIZE
	var oy := -float(grid_size.y - 1) * 0.5 * Cell.CELL_SIZE
	return Vector3(ox + x * Cell.CELL_SIZE, 0, oy + y * Cell.CELL_SIZE)


func world_to_grid(world: Vector3) -> Vector2i:
	var ox := -float(grid_size.x - 1) * 0.5 * Cell.CELL_SIZE
	var oy := -float(grid_size.y - 1) * 0.5 * Cell.CELL_SIZE
	var x := int(round((world.x - ox) / Cell.CELL_SIZE))
	var y := int(round((world.z - oy) / Cell.CELL_SIZE))
	return Vector2i(x, y)


func is_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < grid_size.x and c.y >= 0 and c.y < grid_size.y


func cell_at(c: Vector2i) -> Cell:
	if not is_valid(c):
		return null
	return cells[c.x][c.y]


func cell_from_world(world: Vector3) -> Cell:
	return cell_at(world_to_grid(world))


func neighbors(c: Vector2i) -> Array:
	var out: Array = []
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off in offsets:
		var n: Vector2i = c + off
		if is_valid(n):
			out.append(cell_at(n))
	return out


func count_paths_adjacent_to_completed() -> int:
	var total := 0
	for row in cells:
		for cell in row:
			if cell.state == Cell.State.COMPLETED:
				for n in neighbors(cell.coord):
					if n != null and n.state == Cell.State.PATH:
						total += 1
	return total


func random_empty_cell() -> Cell:
	var pool: Array = []
	for row in cells:
		for cell in row:
			if cell.state == Cell.State.EMPTY:
				pool.append(cell)
	if pool.is_empty():
		return null
	return pool.pick_random()


func set_hovered(cell: Cell) -> void:
	if _hovered == cell:
		return
	if _hovered:
		_hovered.set_highlighted(false)
	_hovered = cell
	if _hovered:
		_hovered.set_highlighted(true)


func clear_hovered() -> void:
	if _hovered:
		_hovered.set_highlighted(false)
	_hovered = null
